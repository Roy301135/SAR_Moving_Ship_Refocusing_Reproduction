function cfg = config_exp01_stageB5(research_root)
%CONFIG_EXP01_STAGEB5
% EXP01 Stage-B5 — Frozen 3-D Scene ERV / IPP Quasi-Stationarity Audit.
%
% This stage is a RE-ANALYSIS ONLY:
%   - no motion retuning
%   - no new scene
%   - no aperture change
%   - no branch-search change
%   - no Proposed scheduler
%   - no parameter sweep
%
% The geometry follows the already accepted Stage-B4 scene:
%   world x = SAR azimuth / flight direction
%   world y = ground-range direction
%   world z = up
%   body-to-world rotation = Rx(roll)*Ry(pitch)*Rz(yaw)
%
% The ERV / IPP definitions follow the uploaded review:
%   omega_eff = (omega_SAR + omega_ship) x u_LOS
%   u_CR      = (omega_eff x u_LOS)/||omega_eff x u_LOS||
%   IPP       = span{u_LOS,u_CR}

if nargin < 1 || isempty(research_root)
    this_file = mfilename('fullpath');
    functions_dir = fileparts(this_file);
    research_root = fileparts(functions_dir);
end

cfg = struct();
cfg.experiment_id = "EXP01_STAGEB5_ERV_IPP_AUDIT";
cfg.experiment_name = "Frozen_3D_Scene_ERV_IPP_QuasiStationarity_Audit";

%% Repository-local provenance
cfg.results_dir = fullfile(research_root,'results','exp01_sar_branch_translation');
cfg.stageA_summary = fullfile(cfg.results_dir,'EXP01_STAGEA_SUMMARY.txt');
cfg.stageB4_feedback = fullfile(cfg.results_dir,'EXP01_STAGEB4_FEEDBACK_BUNDLE.txt');

%% Frozen Stage-B4 motion — must match the accepted feedback bundle
cfg.rotation_convention = "Rx*Ry*Rz";

cfg.roll_amplitude_deg = 8.6;
cfg.roll_period_s = 12.2;
cfg.roll_phase0_rad = pi/2;

cfg.pitch_amplitude_deg = 1.7;
cfg.pitch_period_s = 6.7;
cfg.pitch_phase0_rad = pi/2;

cfg.yaw_amplitude_deg = 19.0;
cfg.yaw_period_s = 14.2;
cfg.yaw_phase0_rad = pi/2;

%% Frozen Stage-A/B4 scene geometry
% Stage-A used the sqrt(2)*H slant-range anchor, so the broadside
% scene-center ground range equals H.  The exact H, V, PRF and Na are
% read from EXP01_STAGEA_SUMMARY.txt at runtime and are not re-tuned.
cfg.scene_center_x_m = 0.0;
cfg.scene_center_z_m = 0.0;

%% Numerical guards — implementation only, not scientific thresholds
cfg.min_vector_norm = 1e-12;
cfg.provenance_abs_tol = 1e-10;
cfg.rotation_orthogonality_guard = 1e-9;
cfg.rotation_determinant_guard = 1e-9;
cfg.los_kinematics_guard = 1e-7;
cfg.ipp_erv_identity_guard_deg = 1e-7;

%% Output
cfg.feedback_name = 'EXP01_STAGEB5_FEEDBACK_BUNDLE.txt';
cfg.mat_name = 'exp01_stageB5_outputs.mat';
cfg.fig1_name = '13_stageB5_erv_magnitude.png';
cfg.fig2_name = '14_stageB5_angular_drift.png';

end
