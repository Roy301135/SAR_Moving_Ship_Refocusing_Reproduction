function cfg = config_exp09b1()
%CONFIG_EXP09B1 Configuration for EXP009-B1: Failure / Mechanism Map.
%
% B1 validates whether the residual-induced weak-q failure mechanism found
% in A1-A4 remains stable across a parameter region.
%
% Main variables:
%   - weak/strong amplitude ratio
%   - SIGNED q separation (A4 showed that |separation| alone is insufficient)
%   - SNR
%
% IMPORTANT:
%   SNR is referenced to the original strong-component power, not the total
%   mixture power. Therefore changing A_weak/A_strong does not change the
%   noise variance itself.

%% Reproducibility
cfg.seed = 20260908;
cfg.num_mc = 50;     % Pilot map. Increase later only in transition cells.

%% Signal
cfg.N = 512;

cfg.q_ref = 1.44;
cfg.mu_scale = 180;

cfg.q_weak = 1.470;

cfg.A_strong = 1.0;
cfg.weak_ratio_list = [0.20 0.30 0.40 0.50 0.60];

cfg.f_strong = 12.3;
cfg.f_weak   = 30.3;

cfg.phi_strong = 0.20;
cfg.phi_weak   = -0.70;

%% Signed separation
% A4 showed phase-sensitive coherent interference; therefore do not collapse
% the map to |q_s-q_w| yet.
cfg.signed_separation_list = ...
    [-0.060 -0.050 -0.040 -0.030 -0.020 ...
      0.020  0.030  0.040  0.050  0.060];

%% SNR list
% Strong-referenced SNR:
%   noise_var = mean(|s_strong|^2) / 10^(SNR/10)
cfg.snr_db_list = [0 3 6];

%% CLEAN
cfg.notch_halfwidth_bins = 1;

%% Operational q search
cfg.q_search_min = 1.380;
cfg.q_search_max = 1.560;
cfg.q_search_step = 0.001;

%% Fine local geometry grid for mechanism diagnostics
cfg.q_geom_halfwidth = 0.020;
cfg.q_geom_step = 0.0001;
cfg.deriv_offset = 0.0005;

%% Recovery thresholds
cfg.tau_q = 0.003;
cfg.success_tol = 1e-12;

% "Catastrophic" is intentionally a reporting threshold, not a theorem.
% It flags gross peak replacement / large mode switching.
cfg.catastrophic_error_q = 0.010;

%% Figures
cfg.figure_visible = 'off';
cfg.figure_snr_db = 3;   % Main heat-map slice.

%% Output
% Leave empty to automatically create:
% <paper_root>/results/exp09_pilot01/exp09b1_failure_mechanism_map/
cfg.output_dir = '';

end
