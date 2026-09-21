function cfg = config_exp02_fair_r1a(research_dir,repo_root)
%CONFIG_EXP02_FAIR_R1A
% Frozen configuration for EXP02-FAIR-R1A Real Branch-State Occurrence Audit.
%
% R1A is an occurrence/mechanism audit only:
%   - same FAIR-CSAR Candidate B;
%   - same corrected-R0 crop;
%   - only the dominant recurrent component-line pairs already accepted by
%     the R0 component-consistency gate;
%   - G0 / Neighbor-3 / evaluation-only full-period continuous reference;
%   - NO Proposed scheduler, Refined-LR gate, FiveBin gate, inverse focus,
%     second ship, or parameter retuning.
%
% Search semantics inherit the frozen PA5I / EXP010 values where applicable.

base = config_exp02_fair_r0();

cfg = struct();

%% Identity
cfg.experiment_id = "EXP02_FAIR_R1A_REAL_BRANCH_OCCURRENCE";
cfg.experiment_name = "FAIR_CSAR_R1A_Real_Branch_State_Occurrence";
cfg.stem = base.stem;

%% Frozen input state
cfg.data_root = fullfile(repo_root,'data','fair_csar','pilot_candidate_B');
cfg.mat_path = fullfile(cfg.data_root,'SLCMats',[cfg.stem '.mat']);

cfg.r0_workspace = fullfile( ...
    research_dir,'results','exp02_real_sar_branch_audit', ...
    'fair_csar','r0_mclfm_compatibility', ...
    'EXP02_FAIR_R0_workspace.mat');

cfg.component_workspace = fullfile( ...
    research_dir,'results','exp02_real_sar_branch_audit', ...
    'fair_csar','r0_component_consistency_gate', ...
    'EXP02_FAIR_R0_COMPONENT_workspace.mat');

cfg.results_dir = fullfile( ...
    research_dir,'results','exp02_real_sar_branch_audit', ...
    'fair_csar','r1a_real_branch_occurrence');

%% Exact R1A scope
% Current accepted R0 dominant recurrent family contains 8/12 matched lines.
% Freeze this expected count so accidental workspace drift stops the run.
cfg.expected_matched_lines = 8;

%% p_beta -> sampled quadratic coefficient mapping
% R0 used:
%   t_norm = 8/(N-1) * (m - (N-1)/2)
% and the calibrated convention gives
%   a_norm = tan(pi*p_beta/2).
% Therefore the coefficient multiplying m^2 is:
%   a_sample = a_norm * (8/(N-1))^2.
cfg.tnorm_full_span = 8;

%% Frozen local branch semantics (inherited from EXP010)
cfg.stage.local_search_halfwidth_bins = 0.75;
cfg.stage.local_bracket_points = 33;
cfg.stage.local_tolx_bins = 1e-11;
cfg.stage.local_max_fun_evals = 200;
cfg.stage.neighbor_radius = 1;

cfg.stage.branch_match_tolerance_bins = 0.02;
cfg.stage.catastrophic_error_threshold_bins = 0.10;

%% Evaluation-only full-period reference
% EXP010 used a 1e-3-bin dense-reference scale. For a full-period real-data
% reference, use an FFT oversampling factor of 1024, giving <1e-3 bin grid
% spacing, followed by continuous refinement around the global sampled max.
% This reference NEVER enters G0/N3 decisions.
cfg.stage.global_oversample = 1024;
cfg.stage.global_tolx_bins = 1e-12;
cfg.stage.global_max_fun_evals = 300;

%% Reporting
cfg.figure_resolution = 180;
cfg.max_landscape_examples = 3;

end
