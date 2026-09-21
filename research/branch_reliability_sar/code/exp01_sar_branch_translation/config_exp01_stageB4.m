function cfg = config_exp01_stageB4(research_root)
%CONFIG_EXP01_STAGEB4 EXP01 Stage-B4 literature-anchored 3-D swing audit.
%
% Purpose:
%   Replace the yaw-only motion used in Stage-A/B3 with ONE frozen,
%   literature-anchored rigid-body roll+pitch+yaw motion realization, while
%   keeping the SAR system, aperture, sparse scatterer skeleton, target-line
%   selection, branch taxonomy, G0 and Neighbor-3 semantics unchanged.
%
% This stage does NOT run the frozen Proposed scheduler and does NOT sweep
% motion amplitudes, periods or phases. It is the final simulation-level
% mechanism check before either entering Stage-C or closing the controlled
% physical simulation line for the selective-N3 claim.

if nargin < 1 || isempty(research_root)
    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    code_dir = fileparts(this_dir);
    research_root = fileparts(code_dir);
end

% Inherit the accepted SAR system / scene / branch semantics.
cfg = config_exp01_stageB3(research_root);

%% Literature-anchored 3-D rigid-body swing
% Wang et al. (Remote Sensing 2023) simulated a 3-D swing ship with:
%   double amplitude [roll pitch yaw] = [17.2 3.4 38] deg
%   average period   [roll pitch yaw] = [12.2 6.7 14.2] s
% and an initial phase of 0.5*pi.
%
% As in Stage-A, "double amplitude" is interpreted as peak-to-peak, so the
% sinusoid amplitudes below are half of those reported values.
cfg.stageB4.motion.type = 'literature_anchored_full_3d_rigid_swing';
cfg.stageB4.motion.axes = {'roll_x','pitch_y','yaw_z'};
cfg.stageB4.motion.double_amplitude_deg = [17.2, 3.4, 38.0];
cfg.stageB4.motion.amplitude_rad = 0.5 * cfg.stageB4.motion.double_amplitude_deg * pi/180;
cfg.stageB4.motion.period_s = [12.2, 6.7, 14.2];
cfg.stageB4.motion.phase0_rad = [pi/2, pi/2, pi/2];

% Exact rotation convention follows the matrix printed as Eq. (14) in
% Xu et al. (JSTARS 2025), equivalent to Rx(theta_x)*Ry(theta_y)*Rz(theta_z).
cfg.stageB4.motion.rotation_convention = 'Xu2025 Eq14 = Rx*Ry*Rz';

%% Everything else remains frozen from Stage-B3
cfg.stageB4.line_selection_rule = cfg.stageB3.line_selection_rule;
cfg.stageB4.reference_x_m = cfg.stageB3.reference_x_m;
cfg.stageB4.branch_match_tolerance_bins = cfg.stageB3.branch_match_tolerance_bins;
cfg.stageB4.catastrophic_error_threshold_bins = cfg.stageB3.catastrophic_error_threshold_bins;

% Reporting only. This is NOT an algorithm threshold and does not enter
% classification or branch decisions. It simply highlights unusually poor
% quadratic fits in the feedback bundle for manual interpretation.
cfg.stageB4.lfm_review_nrmse = 0.03;

%% Output settings
cfg.stageB4.figure_visible = 'on';
cfg.stageB4.feedback_bundle_name = 'EXP01_STAGEB4_FEEDBACK_BUNDLE.txt';
cfg.stageB4.save_mat_name = 'exp01_stageB4_outputs.mat';
cfg.stageB4.csv_name = 'stageB4_3d_natural_line_audit.csv';
cfg.stageB4.max_feedback_rows = 12;
cfg.stageB4.landscape_halfwidth_bins = 4.0;
cfg.stageB4.landscape_step_bins = 0.002;

end
