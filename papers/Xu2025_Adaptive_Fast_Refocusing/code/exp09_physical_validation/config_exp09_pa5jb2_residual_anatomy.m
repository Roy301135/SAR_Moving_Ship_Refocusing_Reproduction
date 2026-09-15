function cfg = config_exp09_pa5jb2_residual_anatomy()
%CONFIG_EXP09_PA5JB2_RESIDUAL_ANATOMY
% Frozen configuration for EXP009 / PA5J-B2.
%
% Research role:
%   Explain the residual-failure / policy-crossover structure observed in
%   PA5J-B1 without adding new gate features or locking a deployment
%   threshold.

cfg.experiment_id = "EXP009_PA5JB2";
cfg.experiment_name = "Residual_Failure_Policy_Crossover_Anatomy";

%% Primary scope
% B2 is driven by the dense-risk stress test where the G5 plateau and
% G5/G6 policy crossover are visible. Original-grid results remain a B1
% representative reference and are not used for B2 mechanism claims.
cfg.primary_source = "dense_risk";
cfg.aperture_modes = ["Paper1s","BeamDerived"];

%% Frozen G5 anchor budgets
% 0.10 / 0.20 / 0.30 probe the low-to-mid budget regime.
% 0.50 is a pre-registered late-budget reference, not an operating point.
cfg.anchor_budgets = [0.10, 0.20, 0.30, 0.50];
cfg.primary_anchor_budgets = [0.10, 0.20, 0.30];

%% Diagnostic second-stage screen inside the G5-untriggered pool
% This is an information audit only. It does not create a new B1 policy.
cfg.residual_screen_budgets = [0.05, 0.10, 0.20, 0.30];

%% Frozen risk directions inherited from PA5J-A/B0/B1
cfg.fivebin_direction = "low";
cfg.entropy_direction = "high";
cfg.refined_lr_direction = "high";

%% Physical variables allowed only for post-hoc anatomy
cfg.physics_vars = { ...
    'relative_phase_rad', ...
    'Gamma_PA4', ...
    'true_eta_bins', ...
    'weak_to_strong_ratio', ...
    'delta_velocity_mps', ...
    'strong_velocity_side'};

%% Expected placement
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
cfg.code_dir = this_dir;
cfg.paper_root = fileparts(fileparts(this_dir));
cfg.results_root = fullfile(cfg.paper_root, "results", "exp09_physical_validation");

%% Canonical inputs
cfg.pa5ja_dir = fullfile(cfg.results_root, "exp09_pa5ja_indicator_discovery");
cfg.input_dense = fullfile(cfg.pa5ja_dir, "pa5ja_indicator_trials_dense_risk.csv");

cfg.pa5jb1_dir = fullfile(cfg.results_root, "exp09_pa5jb1_selective_n3_pareto");
cfg.input_b1_sweep = fullfile(cfg.pa5jb1_dir, "pa5jb1_policy_sweep.csv");

%% Output
cfg.output_dir = fullfile(cfg.results_root, "exp09_pa5jb2_residual_anatomy");
cfg.figure_dir = fullfile(cfg.output_dir, "figures");

%% Required schemas
cfg.req_dense = [ ...
    "source", "trial_id", "aperture_mode", ...
    "catastrophic_branch_failure", ...
    "fivebin_peak_fraction", "local_entropy5", "refined_lr_asymmetry", ...
    "relative_phase_rad", "Gamma_PA4", "true_eta_bins", ...
    "weak_to_strong_ratio", "delta_velocity_mps", ...
    "strong_velocity_side"];

cfg.req_b1 = [ ...
    "source", "aperture_mode", "policy", "nominal_budget", ...
    "actual_trigger_fraction", "selected_count", ...
    "final_failure_count", "missed_g0_failure_count", ...
    "persistent_after_fallback_count"];

%% Numerical tolerance
cfg.audit_tol = 1e-12;

end
