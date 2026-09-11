function cfg = config_exp09b3()
%CONFIG_EXP09B3 Configuration for EXP009-B3.
%
% Observable Reliability Surrogate
%
% B3 asks:
%   Can the oracle mechanism discovered in A1-B2 be recognized from
%   quantities that are actually observable from the residual q-search
%   concentration curve?
%
% Default data source:
%   B2 selected cells, rerun with the same 500-MC protocol.

%% Reproducibility -- match B2 refined MC
cfg.seed = 20260909;

%% Input: B2 result folder
% Leave empty for automatic relative-path discovery.
cfg.b2_result_dir = '';

%% Signal model -- must match B1/B2
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

%% Operational q search
cfg.q_search_min = 1.380;
cfg.q_search_max = 1.560;
cfg.q_search_step = 0.001;

%% Recovery labels
cfg.tau_q = 0.003;
cfg.success_tol = 1e-12;
cfg.catastrophic_error_q = 0.010;

%% Monte Carlo
% Keep equal to B2 refined MC if exact reproduction is desired.
cfg.num_mc = 500;

%% Observable curve-feature definitions
cfg.second_peak_guard_bins = 4;
cfg.local_asymmetry_bins = 5;
cfg.competitor_fraction = 0.80;

%% Transparent diagnostic feature fusion
% This is NOT the proposed final method. It is only a leave-one-cell-out
% diagnostic asking whether multiple observable features contain
% complementary reliability information.
cfg.logit_l2 = 0.05;

cfg.logit_feature_names = { ...
    'second_to_first', ...
    'prominence', ...
    'peak_zscore', ...
    'margin_to_mad', ...
    'local_curvature_1', ...
    'width50_q', ...
    'abs_local_asymmetry', ...
    'curve_entropy', ...
    'competitor_count', ...
    'grid_instability_bins', ...
    'residual_energy_ratio_obs'};

%% Figures
cfg.figure_visible = 'off';

%% Output
% Leave empty for automatic result folder.
cfg.output_dir = '';

end
