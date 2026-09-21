function tracks = sar_build_ship_tracks_3d(cfg, mode)
%SAR_BUILD_SHIP_TRACKS_3D Build frozen-or-moving 3-D rigid ship trajectories.
%
% The rotation matrix is the one printed as Eq. (14) in Xu et al. 2025:
%
%   Rot(theta_x,theta_y,theta_z) = Rx(theta_x)*Ry(theta_y)*Rz(theta_z)
%
% where theta_x, theta_y and theta_z are roll, pitch and yaw.
%
% mode:
%   'static' : freeze all three angles at eta=0, so the static reference
%              has exactly the same aperture-center pose as the moving ship.
%   'moving' : use the literature-anchored sinusoidal histories.

if nargin < 2
    error('sar_build_ship_tracks_3d requires cfg and mode.');
end
if ~(strcmp(mode,'static') || strcmp(mode,'moving'))
    error('mode must be ''static'' or ''moving''.');
end
if ~isfield(cfg,'stageB4') || ~isfield(cfg.stageB4,'motion')
    error('sar_build_ship_tracks_3d:MissingMotionConfig', ...
        'cfg.stageB4.motion is required.');
end

eta = cfg.eta(:).';
Ns = size(cfg.scatterers.body_xy_m,1);
Na = numel(eta);

amp = cfg.stageB4.motion.amplitude_rad(:).';
T = cfg.stageB4.motion.period_s(:).';
phi = cfg.stageB4.motion.phase0_rad(:).';
if numel(amp)~=3 || numel(T)~=3 || numel(phi)~=3
    error('sar_build_ship_tracks_3d:MotionShape', ...
        '3-D motion amplitude/period/phase arrays must each contain 3 values.');
end

omega = 2*pi ./ T;
angles = amp(:) .* sin(omega(:).*eta + phi(:)); % [3 x Na]

if strcmp(mode,'static')
    angles = repmat(angles(:,(Na+1)/2),1,Na);
end

theta_x = angles(1,:);
theta_y = angles(2,:);
theta_z = angles(3,:);

body_xyz = [cfg.scatterers.body_xy_m, zeros(Ns,1)];
Pbody = body_xyz.'; % [3 x Ns]

x = zeros(Ns,Na);
y = zeros(Ns,Na);
z = zeros(Ns,Na);
max_orth_error = 0;
max_det_error = 0;

for m = 1:Na
    R = rotation_eq14(theta_x(m),theta_y(m),theta_z(m));
    orth_err = norm(R.'*R-eye(3),'fro');
    det_err = abs(det(R)-1);
    max_orth_error = max(max_orth_error,orth_err);
    max_det_error = max(max_det_error,det_err);

    Prot = R * Pbody;
    x(:,m) = cfg.ship_center_x + Prot(1,:).';
    y(:,m) = cfg.ship_center_y + Prot(2,:).';
    z(:,m) = cfg.ship_center_z + Prot(3,:).';
end

if max_orth_error > 1e-10 || max_det_error > 1e-10
    error('sar_build_ship_tracks_3d:RotationMatrixAuditFailed', ...
        'Rotation self-audit failed: max orth err=%.3g, max det err=%.3g.', ...
        max_orth_error,max_det_error);
end

tracks.x = x;
tracks.y = y;
tracks.z = z;
tracks.theta_x = theta_x;
tracks.theta_y = theta_y;
tracks.theta_z = theta_z;
tracks.mode = mode;
tracks.max_rotation_orthogonality_error = max_orth_error;
tracks.max_rotation_determinant_error = max_det_error;

end

function R = rotation_eq14(tx,ty,tz)
% Exact Eq. (14) form, equivalent to Rx*Ry*Rz.
cx = cos(tx); sx = sin(tx);
cy = cos(ty); sy = sin(ty);
cz = cos(tz); sz = sin(tz);

R = [ ...
    cy*cz,                     -cy*sz,                    sy; ...
    sx*sy*cz + cx*sz,          -sx*sy*sz + cx*cz,       -sx*cy; ...
   -cx*sy*cz + sx*sz,           cx*sy*sz + sx*cz,        cx*cy];
end
