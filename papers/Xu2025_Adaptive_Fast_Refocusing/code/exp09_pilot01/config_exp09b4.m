function cfg = config_exp09b4()
%CONFIG_EXP09B4 Configuration for EXP009-B4.
%
% Observable q-Uncertainty / Stability Estimation
%
% B4 focuses on the main unresolved B3 problem:
%   perturbative failure is only moderately observable from one static
%   concentration curve.
%
% The core hypothesis is:
%   a weak-q estimate close to failure should be less stable under small
%   DATA perturbations, even when the main peak still looks plausible.

%% Reproducibility -- match B2/B3
cfg.seed = 20260909;

%% Input folders
% Leave empty for automatic relative-path discovery.
cfg.b2_result_dir = '';
cfg.b3_result_dir = '';

%% Signal model -- match B1/B2/B3
cfg.N = 512;

cfg.q_ref = 1.44;
cfg.mu_scale = 180;
cfg.q_weak = 1.470;

cfg.A_strong = 1.0;

cfg.f_strong = 12.3;
cfg.f_weak = 30.3;

cfg.phi_strong = 0.20;
cfg.phi_weak = -0.70;

%% CLEAN
cfg.notch_halfwidth_bins = 1;

%% q search
cfg.q_search_min = 1.380;
cfg.q_search_max = 1.560;
cfg.q_search_step = 0.001;

%% Recovery labels
cfg.tau_q = 0.003;
cfg.success_tol = 1e-12;
cfg.catastrophic_error_q = 0.010;

%% Monte Carlo
% Match B2/B3 refined protocol.
cfg.num_mc = 500;

%% Data-perturbation stability test
% Use 4 overlapping contiguous sub-apertures, each retaining 75% of the
% original aperture. This keeps most integration gain while perturbing the
% data support enough to test estimator stability.
cfg.subap_fraction = 0.75;
cfg.num_subaps = 4;

%% Curvature/noise uncertainty proxy
% Exclude a neighborhood around the detected peak when estimating the
% concentration-curve fluctuation scale.
cfg.noise_floor_guard_bins = 10;

%% Practical ambiguity observables retained from B3
cfg.second_peak_guard_bins = 4;

%% Transparent diagnostic fusion
% Local model: q-stability observables only.
cfg.local_logit_features = { ...
    'subap_std_norm', ...
    'subap_range_norm', ...
    'subap_full_dev_norm', ...
    'curvature_sigma_q_norm'};

% Two-channel model: local uncertainty + global ambiguity.
cfg.twochannel_logit_features = { ...
    'subap_std_norm', ...
    'curvature_sigma_q_norm', ...
    'prominence', ...
    'curve_entropy'};

cfg.logit_l2 = 0.05;

%% Figures
cfg.figure_visible = 'off';

%% Output
cfg.output_dir = '';

end
