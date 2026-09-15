function cfg = config_exp09_pa5jb3_staged_gate()
%CONFIG_EXP09_PA5JB3_STAGED_GATE
% Frozen configuration for EXP009 / PA5J-B3.
%
% Research goal:
%   Test whether sequential use of complementary reliability information
%   improves the cost-reliability Pareto:
%
%     Stage 1: Refined-LR on the whole primary group
%     Stage 2: Cost-0 reranking only inside the Stage-1 untriggered pool
%     Recovery: Neighbor-3 on the union of Stage-1 and Stage-2 triggers
%
% No operating point is locked in this experiment.

cfg.experiment_id = "EXP009_PA5JB3";
cfg.experiment_name = "Staged_Reliability_Gate";

%% Primary groups
cfg.sources = ["original_grid","dense_risk"];
cfg.aperture_modes = ["Paper1s","BeamDerived"];

%% Stage-1 Refined-LR nominal budgets
% Includes the low-budget Original-grid regime and B2 dense-risk anchors.
cfg.stage1_budgets = [ ...
    0.005, 0.01, 0.02, 0.05, ...
    0.10, 0.20, 0.30, 0.50];

%% Stage-2 conditional budgets
% Fractions are defined inside the Stage-1 untriggered candidate pool.
cfg.stage2_budgets = [ ...
    0, 0.01, 0.02, 0.05, ...
    0.10, 0.20, 0.30, 0.50, 1.00];

%% Stage-2 Cost-0 score families
% These are all already studied in PA5J-B2. No new indicator is introduced.
cfg.stage2_signals = ["FiveBin","Entropy","Cost0_MaxRank"];

%% Frozen risk directions
cfg.fivebin_direction = "low";
cfg.entropy_direction = "high";
cfg.refined_lr_direction = "high";

%% Diagnostic cost
% Refined-LR is evaluated for all trials because Stage-1 must rank the whole
% primary group before deciding which trials remain for Stage-2.
cfg.refined_lr_extra_evals = 2;

%% Expected placement
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
cfg.code_dir = this_dir;
cfg.paper_root = fileparts(fileparts(this_dir));
cfg.results_root = fullfile(cfg.paper_root, "results", "exp09_physical_validation");

%% Canonical upstream artifacts
cfg.pa5jb1_dir = fullfile(cfg.results_root, "exp09_pa5jb1_selective_n3_pareto");
cfg.input_trials = fullfile(cfg.pa5jb1_dir, "pa5jb1_canonical_trials.csv");
cfg.input_b1_sweep = fullfile(cfg.pa5jb1_dir, "pa5jb1_policy_sweep.csv");
cfg.input_b1_baselines = fullfile(cfg.pa5jb1_dir, "pa5jb1_baselines.csv");

cfg.pa5jb2_dir = fullfile(cfg.results_root, "exp09_pa5jb2_residual_anatomy");
cfg.input_b2_screen = fullfile(cfg.pa5jb2_dir, "pa5jb2_residual_cost0_screen.csv");

%% Output
cfg.output_dir = fullfile(cfg.results_root, "exp09_pa5jb3_staged_gate");
cfg.figure_dir = fullfile(cfg.output_dir, "figures");

%% Required schemas
cfg.req_trials = [ ...
    "source","trial_id","aperture_mode", ...
    "fivebin_peak_fraction","local_entropy5","refined_lr_asymmetry", ...
    "g0_branch_error_bins","g0_catastrophic_failure","g0_objective_evals", ...
    "n3_branch_error_bins","n3_catastrophic_failure","n3_objective_evals"];

cfg.req_b1 = [ ...
    "source","aperture_mode","policy","nominal_budget", ...
    "actual_trigger_fraction","selected_count","mean_objective_evals", ...
    "final_failure_count","n_trials","final_failure_probability"];

cfg.req_base = [ ...
    "source","aperture_mode","method","n_trials","failure_count", ...
    "failure_probability","mean_objective_evals"];

cfg.req_b2 = [ ...
    "source","aperture_mode","g5_nominal_budget","cost0_signal", ...
    "residual_screen_nominal_budget", ...
    "residual_screen_actual_fraction_of_pool","selected_count", ...
    "residual_failures_selected"];

%% Comparators
% "best B1" uses all PA5J-B1 selective policies, not only G5/G6.
cfg.b1_policy_names = [ ...
    "G2_FiveBin","G3_Entropy","G4_Cost0_MaxRank", ...
    "G5_RefinedLR","G6_All3_MaxRank"];

%% Numerical tolerance
cfg.audit_tol = 1e-10;

%% Reporting cost fractions
% Used only to summarize the envelope in RESULTS_EXP009_PA5JB3.txt.
% They are not operating points.
cfg.report_normalized_cost_caps = [0.10,0.25,0.50,0.75,1.00];

end
