function A = sar_effective_observation_geometry(eta,platform_pos,ship_centroid,Rbody2world,cfg)
%SAR_EFFECTIVE_OBSERVATION_GEOMETRY
% Re-analysis of the frozen Stage-B4 trajectory using review-defined
% effective rotation vector (ERV) and image projection plane (IPP).
%
% INPUT
%   eta            1xN slow time [s]
%   platform_pos   3xN platform position in world frame [m]
%   ship_centroid  3xN ship centroid in world frame [m]
%   Rbody2world    3x3xN body-to-world attitude rotation
%
% DEFINITIONS
%   u_LOS points from radar platform to ship centroid.
%
%   omega_SAR is defined as the minimum angular-velocity vector satisfying
%       du_LOS/dt = omega_SAR x u_LOS
%   hence
%       omega_SAR = u_LOS x du_LOS/dt .
%
%   omega_ship is obtained from rotation-matrix kinematics:
%       Omega = Rdot*R^T
%       Omega = skew(omega_ship)
%
%   Following the review:
%       omega_eff = (omega_SAR + omega_ship) x u_LOS
%       u_CR      = normalize(omega_eff x u_LOS)
%       IPP       = span{u_LOS,u_CR}
%       n_IPP     = normalize(u_LOS x u_CR)
%
% Under these definitions n_IPP is theoretically aligned with the
% normalized omega_eff.  Their numerical difference is retained as a
% self-consistency check, not as an independent scientific result.

eta = double(eta(:).');
N = numel(eta);
assert(N >= 5,'Stage-B5 requires at least five slow-time samples.');
assert(all(size(platform_pos)==[3,N]),'platform_pos must be 3xN.');
assert(all(size(ship_centroid)==[3,N]),'ship_centroid must be 3xN.');
assert(all(size(Rbody2world)==[3,3,N]),'Rbody2world must be 3x3xN.');

dt = median(diff(eta));
assert(isfinite(dt) && dt>0,'Slow-time sampling is invalid.');

%% LOS
los_vec = ship_centroid - platform_pos;
los_norm = sqrt(sum(los_vec.^2,1));
assert(all(los_norm > cfg.min_vector_norm),'Degenerate platform-to-centroid range.');
u_los = los_vec ./ los_norm;

du = finite_difference_vectors(u_los,dt);
omega_sar = cross(u_los,du,1);

% Kinematic identity: omega_sar x u_los should reconstruct du/dt.
du_recon = cross(omega_sar,u_los,1);
los_recon_err = sqrt(sum((du_recon-du).^2,1));

%% Ship angular velocity from Rdot*R^T
Rdot = finite_difference_rotations(Rbody2world,dt);
omega_ship = zeros(3,N);
rot_orth_err = zeros(1,N);
rot_det_err = zeros(1,N);

for k=1:N
    R = Rbody2world(:,:,k);
    Om = Rdot(:,:,k) * R.';
    Om = 0.5*(Om-Om.');
    omega_ship(:,k) = [Om(3,2); Om(1,3); Om(2,1)];
    rot_orth_err(k) = norm(R.'*R-eye(3),'fro');
    rot_det_err(k) = abs(det(R)-1);
end

%% Review-defined effective observation geometry
omega_total = omega_sar + omega_ship;
omega_eff = cross(omega_total,u_los,1);
erv_mag = sqrt(sum(omega_eff.^2,1));

if any(erv_mag <= cfg.min_vector_norm)
    error('EXP01_STAGEB5:ERVSingularity', ...
        'omega_eff is near zero at %d slow-time samples; IPP is undefined there.', ...
        sum(erv_mag <= cfg.min_vector_norm));
end

u_erv = omega_eff ./ erv_mag;

ucr_raw = cross(omega_eff,u_los,1);
ucr_norm = sqrt(sum(ucr_raw.^2,1));
if any(ucr_norm <= cfg.min_vector_norm)
    error('EXP01_STAGEB5:CrossRangeSingularity', ...
        'Cross-range direction is undefined at %d samples.', ...
        sum(ucr_norm <= cfg.min_vector_norm));
end
u_cr = ucr_raw ./ ucr_norm;

nipp_raw = cross(u_los,u_cr,1);
nipp_norm = sqrt(sum(nipp_raw.^2,1));
u_nipp = nipp_raw ./ nipp_norm;

%% Angular drifts relative to aperture center
ic = floor((N+1)/2);
los_drift = angle_to_reference(u_los,u_los(:,ic));
erv_drift = angle_to_reference(u_erv,u_erv(:,ic));
ucr_drift = angle_to_reference(u_cr,u_cr(:,ic));
ipp_drift = angle_to_reference(u_nipp,u_nipp(:,ic));

ipp_erv_identity = angle_pairwise(u_nipp,u_erv);

%% Magnitudes / ratios
ship_mag = sqrt(sum(omega_ship.^2,1));
sar_mag = sqrt(sum(omega_sar.^2,1));
total_mag = sqrt(sum(omega_total.^2,1));

%% Metrics
M = struct();
M.N = N;
M.dt_s = dt;
M.aperture_time_s = eta(end)-eta(1);
M.center_index = ic;

M.erv_mean_radps = mean(erv_mag);
M.erv_min_radps = min(erv_mag);
M.erv_max_radps = max(erv_mag);
M.erv_center_radps = erv_mag(ic);
M.erv_cv = std(erv_mag,1) / max(mean(erv_mag),eps);
M.erv_max_relative_deviation_from_center = ...
    max(abs(erv_mag-erv_mag(ic))) / max(abs(erv_mag(ic)),eps);

M.erv_direction_max_drift_deg = rad2deg(max(erv_drift));
M.erv_direction_rms_drift_deg = rad2deg(sqrt(mean(erv_drift.^2)));

M.los_max_drift_deg = rad2deg(max(los_drift));
M.los_rms_drift_deg = rad2deg(sqrt(mean(los_drift.^2)));

M.cross_range_max_drift_deg = rad2deg(max(ucr_drift));
M.cross_range_rms_drift_deg = rad2deg(sqrt(mean(ucr_drift.^2)));

M.ipp_normal_max_drift_deg = rad2deg(max(ipp_drift));
M.ipp_normal_rms_drift_deg = rad2deg(sqrt(mean(ipp_drift.^2)));

M.mean_ship_angular_speed_radps = mean(ship_mag);
M.max_ship_angular_speed_radps = max(ship_mag);
M.mean_sar_los_angular_speed_radps = mean(sar_mag);
M.max_sar_los_angular_speed_radps = max(sar_mag);
M.mean_ship_to_sar_angular_speed_ratio = mean(ship_mag ./ max(sar_mag,eps));

M.max_rotation_orthogonality_error = max(rot_orth_err);
M.max_rotation_determinant_error = max(rot_det_err);
M.max_los_kinematic_reconstruction_error = max(los_recon_err);
M.max_ipp_erv_direction_identity_error_deg = rad2deg(max(ipp_erv_identity));

%% Guards: implementation/coordinate consistency only
if M.max_rotation_orthogonality_error > cfg.rotation_orthogonality_guard || ...
        M.max_rotation_determinant_error > cfg.rotation_determinant_guard
    error('EXP01_STAGEB5:RotationGuard', ...
        'Rotation-matrix self-consistency guard failed.');
end
if M.max_los_kinematic_reconstruction_error > cfg.los_kinematics_guard
    error('EXP01_STAGEB5:LOSSelfCheck', ...
        'LOS angular-velocity reconstruction guard failed.');
end
if M.max_ipp_erv_direction_identity_error_deg > cfg.ipp_erv_identity_guard_deg
    error('EXP01_STAGEB5:IPPERVIdentity', ...
        'IPP normal and ERV direction are inconsistent with the frozen definitions.');
end

%% Output bundle
A = struct();
A.eta_s = eta;
A.platform_pos_m = platform_pos;
A.ship_centroid_m = ship_centroid;
A.Rbody2world = Rbody2world;

A.u_los = u_los;
A.omega_sar = omega_sar;
A.omega_ship = omega_ship;
A.omega_total = omega_total;
A.omega_eff = omega_eff;
A.erv_magnitude_radps = erv_mag;
A.u_erv = u_erv;
A.u_cross_range = u_cr;
A.u_ipp_normal = u_nipp;

A.los_drift_rad = los_drift;
A.erv_direction_drift_rad = erv_drift;
A.cross_range_drift_rad = ucr_drift;
A.ipp_normal_drift_rad = ipp_drift;
A.ship_angular_speed_radps = ship_mag;
A.sar_los_angular_speed_radps = sar_mag;
A.total_angular_speed_radps = total_mag;

A.metrics = M;

end

%% ========================================================================
function dX = finite_difference_vectors(X,dt)
N=size(X,2);
dX=zeros(size(X));
dX(:,2:N-1)=(X(:,3:N)-X(:,1:N-2))/(2*dt);
dX(:,1)=(-3*X(:,1)+4*X(:,2)-X(:,3))/(2*dt);
dX(:,N)=(3*X(:,N)-4*X(:,N-1)+X(:,N-2))/(2*dt);
end

function dR = finite_difference_rotations(R,dt)
N=size(R,3);
dR=zeros(size(R));
dR(:,:,2:N-1)=(R(:,:,3:N)-R(:,:,1:N-2))/(2*dt);
dR(:,:,1)=(-3*R(:,:,1)+4*R(:,:,2)-R(:,:,3))/(2*dt);
dR(:,:,N)=(3*R(:,:,N)-4*R(:,:,N-1)+R(:,:,N-2))/(2*dt);
end

function a = angle_to_reference(U,u0)
dots=sum(U.*u0,1);
dots=max(-1,min(1,dots));
a=acos(dots);
end

function a = angle_pairwise(A,B)
% Robust pairwise angle for nearly parallel unit vectors.
% Using acos(dot) is numerically ill-conditioned when the true angle is
% extremely close to zero: tiny floating-point errors in dot ~= 1 can be
% magnified into an apparent ~1e-6 deg mismatch.  atan2(||a x b||, a.b)
% remains well-conditioned in this regime.
dots = sum(A.*B,1);
C = cross(A,B,1);
sins = sqrt(sum(C.^2,1));
a = atan2(sins,dots);
end
