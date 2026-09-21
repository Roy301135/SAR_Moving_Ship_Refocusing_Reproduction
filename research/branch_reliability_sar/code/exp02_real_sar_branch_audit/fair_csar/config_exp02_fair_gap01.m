function cfg = config_exp02_fair_gap01(research_dir,repo_root)
%CONFIG_EXP02_FAIR_GAP01
% Small Real-vs-Synthetic Gap Audit on FAIR-CSAR Candidate B.
%
% Purpose: diagnose why the synthetic local-branch regime does not persist
% cleanly in the real motion-defocused target, before starting a new method.
%
% A) parameter-support exact synthetic clones
% B) real single-quadratic-LFM adequacy + local p_beta relaxation
% C) paired real/synthetic J(p_beta,nu) landscapes
%
% No N3 retuning, Top-K, new recovery method, or higher-order compensation.

cfg = struct();

cfg.experiment_id = "EXP02_FAIR_GAP01_REAL_VS_SYNTHETIC";
cfg.experiment_name = "FAIR_CSAR_GAP01_Real_vs_Synthetic_Gap_Audit";

cfg.data_root = fullfile(repo_root,'data','fair_csar','pilot_candidate_B');

cfg.r1b_workspace = fullfile( ...
    research_dir,'results','exp02_real_sar_branch_audit', ...
    'fair_csar','r1b_full_frozen_pool_occurrence', ...
    'EXP02_FAIR_R1B_workspace.mat');

cfg.results_dir = fullfile( ...
    research_dir,'results','exp02_real_sar_branch_audit', ...
    'fair_csar','gap01_real_vs_synthetic');

%% Frozen R1 branch semantics
cfg.stage.local_search_halfwidth_bins = 0.75;
cfg.stage.local_bracket_points = 33;
cfg.stage.local_tolx_bins = 1e-11;
cfg.stage.local_max_fun_evals = 200;
cfg.stage.neighbor_radius = 1;

cfg.stage.branch_match_tolerance_bins = 0.02;
cfg.stage.catastrophic_error_threshold_bins = 0.10;

cfg.stage.global_oversample = 1024;
cfg.stage.global_tolx_bins = 1e-12;
cfg.stage.global_max_fun_evals = 300;

%% Same p_beta -> sampled chirp convention used by R1
cfg.tnorm_full_span = 8;

%% Diagnostic B: local p_beta relaxation
cfg.p_relax_halfwidth = 0.04;
cfg.p_relax_step = 0.005;

% Diagnostic full-period nu reference for each p candidate.
cfg.p_relax_nu_oversample = 32;
cfg.p_relax_nu_tolx_bins = 1e-10;
cfg.p_relax_nu_max_fun_evals = 100;

%% Diagnostic C: 2D landscape display only
cfg.landscape_p_halfwidth = 0.06;
cfg.landscape_p_step = 0.01;
cfg.n_landscape_cases = 4;

%% Engineering routing thresholds only; not paper claims
cfg.clone_truth_tolerance_bins = 0.02;
cfg.material_p_relax_gain = 0.02;

%% Reporting
cfg.figure_resolution = 180;

end
