function cfg = config_exp01_stageB2(research_root)
%CONFIG_EXP01_STAGEB2 Controlled hard-state physical embedding.
%
% This is NOT a new algorithm experiment. It asks whether one already-
% frozen EXP010-B BeamDerived DenseRisk rescue case can be realized by a
% physically generated yawing-ship SAR pair without optimizing the branch
% objective itself.

if nargin < 1 || isempty(research_root)
    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    code_dir = fileparts(this_dir);
    research_root = fileparts(code_dir);
end

cfg = config_exp01_stageB(research_root);

repo_root = fileparts(fileparts(research_root));

%% Frozen upstream source
cfg.stageB2.exp10b_dir = fullfile(repo_root, ...
    'papers','Xu2025_Adaptive_Fast_Refocusing','results', ...
    'exp10_practical_nonoracle_closure','exp10b_noiseless_formal_closure');
cfg.stageB2.exp10b_eval_csv = fullfile(cfg.stageB2.exp10b_dir, ...
    'evaluation_trials_all.csv');

% Deterministic target rule, frozen before this run:
%   DenseRisk / BeamDerived only;
%   G0 catastrophic;
%   Proposed and Always-N3 non-catastrophic;
%   Proposed must actually have fallback_trigger=1;
%   first preference: G0 weak-infeasible -> Proposed weak-feasible;
%   tie-break: smallest trial_id.
cfg.stageB2.target_validation_set = "DenseRisk";
cfg.stageB2.target_aperture_mode = "BeamDerived";

%% Physical inverse family
% Same SAR system, same N=BeamDerived, yaw-only rigid motion.
% The inverse solver may alter only the designated P4/P7 center-frame
% coordinates and three yaw-motion parameters. Other SAR system settings
% and the remaining ship skeleton are unchanged.
cfg.stageB2.bounds.x_strong_center_m = [-28, 28];
cfg.stageB2.bounds.x_weak_center_m   = [-28, 28];
cfg.stageB2.bounds.common_y_offset_m = [-8, 8];
cfg.stageB2.bounds.yaw_amplitude_deg = [8, 25];
cfg.stageB2.bounds.yaw_period_s      = [8, 20];
cfg.stageB2.bounds.yaw_phase0_rad    = [-pi, pi];

% Physical plausibility guards in ship body coordinates.
cfg.stageB2.max_abs_body_x_m = 35;
cfg.stageB2.max_abs_body_y_m = 12;
cfg.stageB2.min_pair_center_separation_m = 3.0;

%% Inverse objective normalization
% IMPORTANT: branch outcome / G0 / N3 never enters the inverse objective.
cfg.stageB2.beta_scale_rad = cfg.stageB.pa4_beta_width_beam_rad;
cfg.stageB2.nu_frac_scale_bins = 0.10;
cfg.stageB2.nu_pair_separation_scale_bins = 0.10;
cfg.stageB2.max_fit_nrmse_soft = 0.01;
cfg.stageB2.min_amp_ratio_soft = 0.40;

% Small literature-anchor regularization, only to prefer less extreme
% solutions when two embeddings have similar parameter mismatch.
cfg.stageB2.reg_motion_weight = 0.01;
cfg.stageB2.reg_y_offset_weight = 0.002;

%% Deterministic numerical optimization
% Multiple starts are numerical solver starts, not experimental states.
cfg.stageB2.u_starts = [ ...
     0,  0,  0,  0,  0,  0; ...
    -1,  1,  0,  0,  0,  0; ...
     1, -1,  0,  0,  0,  0; ...
    -1,  1,  0,  0.8,-0.8, 0.8; ...
     1, -1,  0, -0.8,0.8,-0.8; ...
    -0.5,0.5, 0.8, 0.5,-0.5,1.2; ...
     0.5,-0.5,-0.8,-0.5,0.5,-1.2];
cfg.stageB2.fminsearch_max_iter = 1200;
cfg.stageB2.fminsearch_max_fun_evals = 7000;
cfg.stageB2.fminsearch_tolx = 1e-7;
cfg.stageB2.fminsearch_tolfun = 1e-9;

%% Translation-quality gates (evaluation only)
cfg.stageB2.gate_beta_error_over_W = 0.35;
cfg.stageB2.gate_fractional_nu_error_bins = 0.12;
cfg.stageB2.gate_pair_nu_separation_bins = 0.15;
cfg.stageB2.gate_phase_fit_nrmse = 0.02;

%% Output
cfg.stageB2.feedback_bundle_name = 'EXP01_STAGEB2_FEEDBACK_BUNDLE.txt';
cfg.stageB2.save_mat_name = 'exp01_stageB2_outputs.mat';
cfg.stageB2.figure_visible = 'on';

end
