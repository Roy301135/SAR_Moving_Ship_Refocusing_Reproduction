function cfg = config_exp09c3b1()
%CONFIG_EXP09C3B1 Configuration for EXP009-C3-B1.
%
% Signal-Level Continuous Azimuth-State Validation
%
% Purpose:
%   Replace the C3-A Markov/bootstrap latent state with an actual
%   signal-generated continuous azimuth-line sequence.
%
% Controlled boundary:
%   - q_strong is still oracle/known at each line.
%   - weak q is fixed; the relative q separation varies continuously.
%   - weak/strong amplitude ratio varies continuously.
%   - SNR is fixed in B1.
%   - Cheap and parametric-refit branches match the C1 controlled
%     weak-stage signal chain.
%
% C3-B2 can later add practical q_strong estimation/tracking.

%% Reproducibility
cfg.seed = 20260909;

%% Signal model -- match B/C controlled chain
cfg.N = 512;

cfg.q_ref = 1.44;
cfg.mu_scale = 180;

cfg.q_weak = 1.470;

cfg.A_strong = 1.0;

cfg.f_strong = 12.3;
cfg.f_weak   = 30.3;

cfg.phi_strong = 0.20;
cfg.phi_weak   = -0.70;

%% Strong-referenced SNR -- fixed in C3-B1
cfg.snr_db = 3.0;

%% Cheap fixed-notch strong residual
cfg.notch_halfwidth_bins = 1;

%% Parametric refit fallback -- match C1
% C1 README used zero-padded FFT NFFT = 8N.
cfg.refit_nfft_factor = 8;

%% Weak q search
cfg.q_search_min = 1.380;
cfg.q_search_max = 1.560;
cfg.q_search_step = 0.001;

cfg.tau_q = 0.003;
cfg.success_tol = 1e-12;

% Batch search reduces MATLAB runtime while preserving the exact same
% q-grid concentration metric.
cfg.q_search_block_lines = 16;

%% Continuous azimuth-state sequence
cfg.num_lines = 121;

% Smooth baseline trajectory:
%   weak_ratio(k) and signed_sep(k)=q_s(k)-q_w vary continuously.
cfg.weak_ratio_center = 0.34;
cfg.weak_ratio_sin1 = 0.10;
cfg.weak_ratio_sin2 = 0.035;
cfg.weak_ratio_min = 0.18;
cfg.weak_ratio_max = 0.52;

cfg.sep_center = -0.010;
cfg.sep_sin1 = 0.038;
cfg.sep_sin2 = 0.014;
cfg.sep_min = -0.060;
cfg.sep_max =  0.060;

% Abrupt regime:
% Start from the same continuous baseline, then introduce one physical
% motion/scattering-state change. The chosen jump moves the signal toward
% a weaker-component / more-negative-separation region that was difficult
% in the earlier B/C experiments.
cfg.jump_fraction = 0.45;
cfg.jump_weak_ratio_step = -0.14;
cfg.jump_sep_step = -0.035;

%% Monte Carlo ensembles
% Each Monte-Carlo run is a complete 121-line azimuth-state sequence.
cfg.num_train_mc = 20;
cfg.num_test_mc  = 40;

%% Continuous state-utility target
% Line-level expected fallback utility is estimated from TRAIN outcomes:
%   u(k) = P(Beneficial|k) - P(Harmful|k)
%
% A short moving average reduces finite-MC noise. This is diagnostic
% state information, not a practical feature.
cfg.state_utility_smooth_window = 7;

%% Instantaneous practical risk
% low prominence -> high risk
% high entropy   -> high risk
cfg.instant_features = {'cheap_prominence','cheap_entropy'};

%% History
cfg.alpha_grid = [0.05 0.10 0.15 0.20 0.30 0.40 0.50 0.60 0.80 1.00];

% Tune EMA on SMOOTH TRAIN at 25% fallback budget.
cfg.tune_budget = 0.25;

% With best alpha fixed, tune innovation-reset threshold on ABRUPT TRAIN.
cfg.reset_quantile_grid = [0.80 0.85 0.90 0.95 0.975 0.99];

%% Budget evaluation
cfg.budget_grid = (0:0.05:1).';
cfg.report_budgets = [0.10 0.25 0.50];

%% Diagnostic warning thresholds
% These are NOT pass/fail hard-coded conclusions; they only trigger
% warnings when the generated signal-level state is too weak to interpret.
cfg.min_train_test_state_rho_warning = 0.50;
cfg.min_jump_utility_change_warning = 0.08;

%% Figures
cfg.figure_visible = 'off';

%% Output
cfg.output_dir = '';

end
