function cfg = config_exp02_fair_r1d_candidate_c(research_dir,repo_root)
%CONFIG_EXP02_FAIR_R1D_CANDIDATE_C
% Frozen independent replication on FAIR-CSAR Candidate C.
%
% This experiment reuses the already validated Candidate-B pipeline without
% retuning:
%   complex-interface sanity
%   -> Wang-style ship-line selection
%   -> corrected Xu Eq.(31) component screen
%   -> amplitude-preserving phase-permutation max-statistic gate
%   -> G0 / Neighbor-3 / evaluation-only continuous global reference
%   -> failure geometry + local component recurrence
%
% No Proposed scheduler, no inverse focusing, no parameter retuning.

base = config_exp02_fair_r0();

cfg = struct();

%% Identity
cfg.experiment_id = "EXP02_FAIR_R1D_CANDIDATE_C_INDEPENDENT_REPLICATION";
cfg.experiment_name = "FAIR_CSAR_R1D_Candidate_C_Independent_Replication";

cfg.stem = [ ...
    'GF3_KAS_SL_028368_E139.7_N35.5_20211229_' ...
    'L1A_HH_L10000000001_00000_04491'];

%% Paths
cfg.data_root = fullfile(repo_root,'data','fair_csar','pilot_candidate_C');

cfg.mat_path = fullfile(cfg.data_root,'SLCMats',[cfg.stem '.mat']);
cfg.png_path = fullfile(cfg.data_root,'PNGImages',[cfg.stem '.png']);
cfg.xml_path = fullfile(cfg.data_root,'METAXmls',[cfg.stem '.xml']);

cfg.results_dir = fullfile( ...
    research_dir,'results','exp02_real_sar_branch_audit', ...
    'fair_csar','r1d_candidate_c_independent_replication');

%% Interface / crop
cfg.crop_margin_px = 32;
cfg.min_png_corr = 0.85;

%% Component screening: frozen from Candidate B
cfg.p_grid = base.p_grid;

cfg.phase_rng_seed = 20260917;
cfg.n_surrogates = 32;

cfg.phase_blind_order = 1.0;
cfg.phase_guard_halfwidth = 0.06;
cfg.surrogate_max_percentile = 95;
cfg.within_line_nms_tolerance = 0.04;

%% p_beta -> sampled quadratic coefficient
cfg.tnorm_full_span = 8;

%% Frozen branch search: same R1A/R1B semantics
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

%% Failure-component recurrence: same R1C semantics
cfg.component_match_tolerance_order = 0.04;
cfg.local_range_halfwidth_columns = 3;
cfg.min_local_support_lines = 3;
cfg.min_consecutive_range_run = 2;

%% Reporting
cfg.figure_resolution = 180;
cfg.max_failure_landscapes = 4;

end
