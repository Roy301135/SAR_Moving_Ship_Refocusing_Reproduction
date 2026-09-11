function cfg = config_exp09c2_1()
%CONFIG_EXP09C2_1 Configuration for EXP009-C2.1.
%
% Mechanism-Aware Pre-Fallback Observable Audit
%
% C2 showed that changing the target from "failure" to "fallback benefit"
% is not enough when the practical input is still limited to the same
% weak-residual curve statistics.
%
% C2.1 therefore returns to the signal-level chain and measures practical,
% pre-fallback observables from the STRONG-CLEAN stage itself.

%% Reproducibility -- match C1 exactly
cfg.seed = 20260909;

%% C1 result folder
% Used only to verify that C2.1 reproduces the exact C1 Cheap/Fallback
% outcomes before analyzing new observables.
% Leave empty for automatic relative-path discovery.
cfg.c1_result_dir = '';

%% Signal model -- must match C1
cfg.N = 512;

cfg.q_ref = 1.44;
cfg.mu_scale = 180;
cfg.q_weak = 1.470;

cfg.A_strong = 1.0;

cfg.f_strong = 12.3;
cfg.f_weak = 30.3;

cfg.phi_strong = 0.20;
cfg.phi_weak = -0.70;

%% Cheap CLEAN
cfg.notch_halfwidth_bins = 1;

%% Strong-stage observable windows
% All are measured on the N-point dechirped FFT that the cheap strong stage
% would already have available.
cfg.strong_local_halfwidth_bins = 8;

% Immediate side-leakage region outside the removed notch.
cfg.strong_side_outer_halfwidth_bins = 5;

%% Fallback -- match C1 exactly
cfg.refit_nfft_factor = 8;

%% Weak q search -- match C1
cfg.q_search_min = 1.380;
cfg.q_search_max = 1.560;
cfg.q_search_step = 0.001;

%% Recovery
cfg.tau_q = 0.003;
cfg.success_tol = 1e-12;

%% Monte Carlo -- match C1
cfg.num_mc = 500;

%% Value model
% V(x) = P(Beneficial|x) - lambda_harm*P(Harmful|x)
cfg.lambda_harm = 1.0;
cfg.logit_l2 = 0.05;

%% Budget curves
cfg.budget_grid = (0:0.05:1).';
cfg.report_budgets = [0.10 0.25 0.50];

%% Figures
cfg.figure_visible = 'off';

%% Output
cfg.output_dir = '';

end
