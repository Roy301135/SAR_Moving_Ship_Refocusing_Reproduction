function cfg = config_exp09_pa5jb3r2_shared_policy()
%CONFIG_EXP09_PA5JB3R2_SHARED_POLICY
% EXP009 / PA5J-B3-R2
% Shared-Policy Cross-Aperture Robustness Audit
%
% Purpose:
%   Test whether the SAME staged configuration:
%
%       (Stage-2 signal, Stage-1 budget, Stage-2 conditional budget)
%
%   has positive dense-B1-audited gain in BOTH Paper1s and BeamDerived.
%
% DenseRisk is the primary robustness domain.
% Original-grid results are post-selection consistency checks only.

cfg.experiment_id = "EXP009_PA5JB3R2";
cfg.experiment_name = "Shared_Policy_Cross_Aperture_Robustness";

%% Frozen sources / apertures
cfg.primary_source = "dense_risk";
cfg.consistency_source = "original_grid";
cfg.apertures = ["Paper1s","BeamDerived"];

%% Frozen staged configuration grid inherited from B3
cfg.stage1_budgets = [ ...
    0.005,0.01,0.02,0.05,0.10,0.20,0.30,0.50];

cfg.stage2_budgets = [ ...
    0,0.01,0.02,0.05,0.10,0.20,0.30,0.50,1.00];

cfg.stage2_signals = ["FiveBin","Entropy","Cost0_MaxRank"];

%% Gain semantics
% Gain = dense-B1 best failure probability at no greater cost
%        - staged B3 failure probability.
cfg.gain_tol = 1e-12;

%% Expected placement
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
cfg.code_dir = this_dir;
cfg.paper_root = fileparts(fileparts(this_dir));
cfg.results_root = fullfile(cfg.paper_root,"results","exp09_physical_validation");

%% Inputs
cfg.b3r1_dir = fullfile(cfg.results_root, ...
    "exp09_pa5jb3r1_dense_b1_audit");
cfg.input_r1 = fullfile(cfg.b3r1_dir, ...
    "pa5jb3r1_b3_vs_dense_b1.csv");

cfg.b3_dir = fullfile(cfg.results_root, ...
    "exp09_pa5jb3_staged_gate");
cfg.input_b3 = fullfile(cfg.b3_dir, ...
    "pa5jb3_staged_sweep.csv");

%% Output
cfg.output_dir = fullfile(cfg.results_root, ...
    "exp09_pa5jb3r2_shared_policy");
cfg.figure_dir = fullfile(cfg.output_dir,"figures");

%% Required schemas
cfg.req_r1 = [ ...
    "source","aperture_mode","stage2_signal", ...
    "stage1_nominal_budget","stage2_conditional_nominal_budget", ...
    "total_actual_fallback_fraction", ...
    "b3_mean_objective_evals","b3_final_failure_probability", ...
    "dense_b1_best_policy","dense_b1_best_mean_cost", ...
    "dense_b1_best_failure_probability", ...
    "old_sampled_b1_gain","new_dense_b1_gain","relation"];

cfg.req_b3 = [ ...
    "source","aperture_mode","stage2_signal", ...
    "stage1_nominal_budget","stage2_conditional_nominal_budget", ...
    "total_actual_fallback_fraction","mean_objective_evals", ...
    "normalized_cost_G0_to_N3","final_failure_count","n_trials", ...
    "final_failure_probability","stage1_induced_count", ...
    "stage2_induced_count","persistent_after_fallback_count"];

%% Reporting
cfg.top_k = 20;

end
