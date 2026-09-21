function tracks = sar_build_ship_tracks(cfg, mode)
%SAR_BUILD_SHIP_TRACKS Build static or yawing scatterer trajectories.
%
% tracks.x, tracks.y, tracks.z: [Nscatterer x Na]
% tracks.theta:                [1 x Na]
%
% mode:
%   'static' - freeze ship at the aperture-center orientation.
%   'moving' - apply the configured yaw history.

if nargin < 2
    error('sar_build_ship_tracks requires cfg and mode.');
end
if ~(strcmp(mode, 'static') || strcmp(mode, 'moving'))
    error('mode must be ''static'' or ''moving''.');
end

eta = cfg.eta;
Ns = size(cfg.scatterers.body_xy_m, 1);
Na = numel(eta);

switch mode
    case 'static'
        theta = cfg.motion.theta_center_rad * ones(1, Na);
    case 'moving'
        omega = 2*pi / cfg.motion.yaw_period_s;
        theta = cfg.motion.yaw_amplitude_rad .* ...
            sin(omega .* eta + cfg.motion.yaw_phase0_rad);
end

xb = cfg.scatterers.body_xy_m(:,1);
yb = cfg.scatterers.body_xy_m(:,2);

x = zeros(Ns, Na);
y = zeros(Ns, Na);

for m = 1:Na
    ct = cos(theta(m));
    st = sin(theta(m));
    x(:,m) = cfg.ship_center_x + ct .* xb - st .* yb;
    y(:,m) = cfg.ship_center_y + st .* xb + ct .* yb;
end

tracks.x = x;
tracks.y = y;
tracks.z = cfg.ship_center_z * ones(Ns, Na);
tracks.theta = theta;
tracks.mode = mode;

end
