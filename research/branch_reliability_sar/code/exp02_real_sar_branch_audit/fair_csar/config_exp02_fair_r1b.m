function cfg = config_exp02_fair_r1b(research_dir,repo_root)
%CONFIG_EXP02_FAIR_R1B
% Frozen configuration for EXP02-FAIR-R1B Full Frozen-Pool Occurrence Audit.
%
% R1B expands occurrence auditing from the 8 R0-matched dominant-component
% states to the ENTIRE pre-registered Wang-selected ship-line pool from R0.
%
% Critical scientific rule:
%   A branch audit is run ONLY for component-line states that independently
%   pass the same corrected Eq.(31) + phase-permutation max-statistic local-
%   peak gate used in the R0 component-consistency analysis.
%
% R1B DOES NOT:
%   - change the ship/crop;
%   - force p=0.78 onto lines that did not support it;
%   - tune the FrAc grid, p=1 guard, surrogate count, N3 radius, local
%     search halfwidth, branch-match tolerance, or catastrophic threshold;
%   - run Proposed / Refined-LR / FiveBin;
%   - inverse-focus / re-focus;
%   - inspect a second FAIR-CSAR target.
%
% This is still an occurrence audit, not an image-quality experiment.

base = config_exp02_fair_r0();

cfg = struct();

%% Identity
cfg.experiment_id = "EXP02_FAIR_R1B_FULL_FROZEN_POOL_OCCURRENCE";
cfg.experiment_name = "FAIR_CSAR_R1B_Full_Frozen_Pool_Occurrence";
cfg.stem = base.stem;

%% Paths
cfg.data_root = fullfile(repo_root,'data','fair_csar','pilot_candidate_B');
cfg.mat_path = fullfile(cfg.data_root,'SLCMats',[cfg.stem '.mat']);

cfg.r0_workspace = fullfile( ...
    research_dir,'results','exp02_real_sar_branch_audit', ...
    'fair_csar','r0_mclfm_compatibility', ...
    'EXP02_FAIR_R0_workspace.mat');

cfg.results_dir = fullfile( ...
    research_dir,'results','exp02_real_sar_branch_audit', ...
    'fair_csar','r1b_full_frozen_pool_occurrence');

%% Frozen component-screening semantics
% Reuse the exact corrected-R0 p-grid.
cfg.phase_rng_seed = 20260917;
cfg.n_surrogates = 32;

cfg.phase_blind_order = 1.0;
cfg.phase_guard_halfwidth = 0.06;

% Line-wise family-wise / look-elsewhere control:
% threshold is the 95th percentile of each surrogate's maximum
% nondegenerate Eq.(31) energy.
cfg.surrogate_max_percentile = 95;

% Same within-line component separation used in R0 component consistency.
cfg.within_line_nms_tolerance = 0.04;

%% p_beta -> sampled quadratic coefficient
cfg.tnorm_full_span = 8;

%% Frozen branch semantics inherited from R1A / EXP010
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

%% Reporting
cfg.figure_resolution = 180;
cfg.max_landscape_examples = 4;

end
