function cfg = config_exp09b2()
%CONFIG_EXP09B2 Configuration for EXP009-B2.
%
% Regime Boundary Refinement + Physics-Derived Reliability Index Gamma.

cfg.seed = 20260909;
cfg.bootstrap_seed = 20260910;

% Leave empty for automatic discovery of B1 result folder.
cfg.b1_result_dir = '';

% Signal model -- match B1.
cfg.N = 512;
cfg.q_ref = 1.44;
cfg.mu_scale = 180;
cfg.q_weak = 1.470;
cfg.A_strong = 1.0;
cfg.f_strong = 12.3;
cfg.f_weak = 30.3;
cfg.phi_strong = 0.20;
cfg.phi_weak = -0.70;

% CLEAN -- match B1.
cfg.notch_halfwidth_bins = 1;

% Operational q search.
cfg.q_search_min = 1.380;
cfg.q_search_max = 1.560;
cfg.q_search_step = 0.001;

% Recovery / regime definitions.
cfg.tau_q = 0.003;
cfg.success_tol = 1e-12;
cfg.catastrophic_error_q = 0.010;

cfg.feasible_baseline_min = 0.80;
cfg.easy_penalty_max = 0.05;
cfg.perturbative_penalty_min = 0.08;
cfg.perturbative_penalty_max = 0.25;
cfg.perturbative_cat_max = 0.08;
cfg.catastrophic_rate_min = 0.10;

% Dangerous-cell label used only for B2 diagnostic ROC/AUC.
cfg.danger_penalty_threshold = 0.10;

% Aim for one representative cell per SNR for each regime.
cfg.selected_per_regime = 3;

% Refined Monte Carlo.
cfg.refine_num_mc = 500;

% Confidence intervals.
cfg.bootstrap_reps = 2000;
cfg.ci_alpha = 0.05;

cfg.figure_visible = 'off';

% Leave empty for automatic result folder.
cfg.output_dir = '';
end
