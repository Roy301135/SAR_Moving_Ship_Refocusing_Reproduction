function cfg = config_exp09_pa5jb1_selective_n3()
%CONFIG_EXP09_PA5JB1_SELECTIVE_N3
% Frozen configuration for EXP009 / PA5J-B1.
%
% Scientific role:
%   Convert PA5J-A/B0 unreliability diagnostics into actual selective
%   Neighbor-3 recovery policies and measure final catastrophic failure
%   probability versus objective-evaluation cost.
%
% IMPORTANT:
%   - No threshold is locked here.
%   - Ranking is performed independently inside each primary group.
%   - Cutoff ties are included, never broken by trial_id / row order.
%   - Truth physics are never used as gate features.
%   - Neighbor-3 trial outcome comes from PA5I / PA5I-R1, not from an
%     assumption that "triggered == rescued".

cfg.experiment_id = "EXP009_PA5JB1";
cfg.experiment_name = "Selective_Neighbor3_Cost_Reliability_Pareto";

%% Frozen budgets
cfg.budgets = [0, 0.005, 0.01, 0.02, 0.05, 0.10, ...
               0.20, 0.30, 0.50, 0.75, 1.00];

%% Catastrophic label consistency
% Inherited from PA5I / PA5J-A. This value is documented only for audit;
% B1 reads the stored binary labels and must not re-threshold branch error.
cfg.documented_catastrophic_threshold_bins = 0.10;

%% Diagnostic costs
% refined_lr_asymmetry requires two additional objective evaluations.
% Cost-0 diagnostics require no additional objective evaluation.
cfg.refined_lr_extra_evals = 2;

%% Policy family
% All fusion is parameter-free and based on within-primary-group empirical
% risk percentiles. No learned weights are introduced.
cfg.policy_names = [ ...
    "G2_FiveBin", ...
    "G3_Entropy", ...
    "G4_Cost0_MaxRank", ...
    "G5_RefinedLR", ...
    "G6_All3_MaxRank"];

cfg.policy_uses_refined = [false, false, false, true, true];

%% Exact frozen risk directions inherited from PA5J-A/B0
cfg.fivebin_direction = "low";
cfg.entropy_direction = "high";
cfg.refined_lr_direction = "high";

%% Expected placement
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);

% Expected:
% ...\Xu2025_Adaptive_Fast_Refocusing\code\exp09_physical_validation
cfg.code_dir = this_dir;
cfg.paper_root = fileparts(fileparts(this_dir));
cfg.results_root = fullfile(cfg.paper_root, "results", "exp09_physical_validation");

%% Canonical upstream artifacts
cfg.pa5ja_dir = fullfile(cfg.results_root, "exp09_pa5ja_indicator_discovery");
cfg.pa5ja_original = fullfile(cfg.pa5ja_dir, "pa5ja_indicator_trials_original.csv");
cfg.pa5ja_dense = fullfile(cfg.pa5ja_dir, "pa5ja_indicator_trials_dense_risk.csv");

cfg.pa5i_dir = fullfile(cfg.results_root, "exp09_pa5i_branchsafe_multicandidate_ml");
cfg.pa5i_original = fullfile(cfg.pa5i_dir, "pa5i_trials.csv");

cfg.pa5ir1_dir = fullfile(cfg.results_root, "exp09_pa5i_r1_gamma_denseeta_tail_audit");
cfg.pa5i_dense = fullfile(cfg.pa5ir1_dir, "pa5i_r1_dense_eta_trials.csv");

%% Exact-method names inherited from PA5I / PA5I-R1
cfg.method_g0 = "G0_OriginalTop1";
cfg.method_n3 = "G1_Neighbor3";

%% Output
cfg.output_dir = fullfile(cfg.results_root, "exp09_pa5jb1_selective_n3_pareto");
cfg.figure_dir = fullfile(cfg.output_dir, "figures");

%% Exact physical identity used to connect PA5J-A trials to PA5I rows.
% These fields are present and unique in the uploaded formal artifacts.
cfg.identity_fields = { ...
    'aperture_mode', ...
    'azimuth_samples', ...
    'delta_velocity_mps', ...
    'strong_velocity_side', ...
    'strong_velocity_mps', ...
    'weak_to_strong_ratio', ...
    'relative_phase_rad', ...
    'true_eta_bins'};

%% Required schemas
cfg.req_pa5ja = [ ...
    "source", "trial_id", ...
    "aperture_mode", "azimuth_samples", "delta_velocity_mps", ...
    "strong_velocity_side", "strong_velocity_mps", ...
    "weak_to_strong_ratio", "relative_phase_rad", "true_eta_bins", ...
    "Gamma_PA4", ...
    "branch_error_to_global_bins", "catastrophic_branch_failure", ...
    "fivebin_peak_fraction", "local_entropy5", "refined_lr_asymmetry"];

cfg.req_pa5i = [ ...
    "aperture_mode", "azimuth_samples", "delta_velocity_mps", ...
    "strong_velocity_side", "strong_velocity_mps", ...
    "weak_to_strong_ratio", "relative_phase_rad", "true_eta_bins", ...
    "method", "branch_error_to_global_bins", ...
    "catastrophic_branch_failure", "n_objective_evals"];

%% Numerical audit tolerance
cfg.branch_error_match_tol = 1e-8;

end
