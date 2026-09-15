function cfg = config_exp09_pa5jb3r1_dense_b1()
%CONFIG_EXP09_PA5JB3R1_DENSE_B1
% EXP009 / PA5J-B3-R1
% Dense Single-Stage Comparator Audit
%
% Purpose:
%   Replace the coarse 11-budget B1 comparator with every attainable
%   deterministic tie-inclusive threshold set for each frozen B1 policy.
%   Then re-evaluate whether PA5J-B3 staged policies create genuinely new
%   cost-reliability Pareto points.

cfg.experiment_id = "EXP009_PA5JB3R1";
cfg.experiment_name = "Dense_Single_Stage_Comparator_Audit";

%% Primary groups
cfg.sources = ["original_grid","dense_risk"];
cfg.aperture_modes = ["Paper1s","BeamDerived"];

%% Frozen B1 policy family
cfg.policy_names = [ ...
    "G2_FiveBin", ...
    "G3_Entropy", ...
    "G4_Cost0_MaxRank", ...
    "G5_RefinedLR", ...
    "G6_All3_MaxRank"];

cfg.policy_uses_refined = [false,false,false,true,true];
cfg.refined_lr_extra_evals = 2;

%% Frozen risk directions
cfg.fivebin_direction = "low";
cfg.entropy_direction = "high";
cfg.refined_lr_direction = "high";

%% Expected placement
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
cfg.code_dir = this_dir;
cfg.paper_root = fileparts(fileparts(this_dir));
cfg.results_root = fullfile(cfg.paper_root,"results","exp09_physical_validation");

%% Inputs
cfg.b1_dir = fullfile(cfg.results_root,"exp09_pa5jb1_selective_n3_pareto");
cfg.input_trials = fullfile(cfg.b1_dir,"pa5jb1_canonical_trials.csv");
cfg.input_b1_sampled = fullfile(cfg.b1_dir,"pa5jb1_policy_sweep.csv");
cfg.input_baselines = fullfile(cfg.b1_dir,"pa5jb1_baselines.csv");

cfg.b3_dir = fullfile(cfg.results_root,"exp09_pa5jb3_staged_gate");
cfg.input_b3 = fullfile(cfg.b3_dir,"pa5jb3_staged_sweep.csv");

%% Output
cfg.output_dir = fullfile(cfg.results_root,"exp09_pa5jb3r1_dense_b1_audit");
cfg.figure_dir = fullfile(cfg.output_dir,"figures");

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

cfg.req_b3 = [ ...
    "source","aperture_mode","stage2_signal", ...
    "stage1_nominal_budget","stage2_conditional_nominal_budget", ...
    "total_actual_fallback_fraction","mean_objective_evals", ...
    "final_failure_count","n_trials","final_failure_probability", ...
    "stage1_induced_count","stage2_induced_count", ...
    "persistent_after_fallback_count", ...
    "gain_vs_best_b1_at_no_more_cost"];

%% Numerical tolerances
cfg.audit_tol = 1e-10;
cfg.gain_tol = 1e-12;

%% Reporting normalized-cost caps
% Reporting only; not operating-point selection.
cfg.report_normalized_cost_caps = [0.10,0.25,0.50,0.75,1.00];

end
