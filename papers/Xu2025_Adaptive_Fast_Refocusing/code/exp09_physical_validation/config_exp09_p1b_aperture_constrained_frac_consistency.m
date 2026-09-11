function cfg = config_exp09_p1b_aperture_constrained_frac_consistency()
%CONFIG_EXP09_P1B_APERTURE_CONSTRAINED_FRAC_CONSISTENCY
% EXP009 / Physical Validation Track / P1B
%
% Aperture-Constrained FrAc Consistency Audit
%
% Wang 2023 paper-grounded inputs are separated from:
%   (1) literature-derived physical quantities;
%   (2) controlled numerical/discrete settings.
%
% P1B does NOT assume that the exact Wang five-point aperture length,
% R0, initial phase, amplitude, or b_i were published.

%% Constants
cfg.c = 3.0e8;

%% Wang 2023 Table 1 — paper-reported
cfg.fc_hz = 3.0e9;
cfg.prf_hz = 188;
cfg.bandwidth_hz = 150e6;
cfg.platform_height_m = 3000;
cfg.antenna_length_m = 2;
cfg.platform_velocity_mps = 150;
cfg.pulse_width_s = 1.5e-6;

%% Wang 2023 Table 2 — paper-reported
cfg.target_velocity_mps = [5, 10, 15, 20, 25];

%% Wang text constraint
% Wang states that the ship swing phase can be approximated by a low-order
% polynomial within a synthetic-aperture time of about one second.
%
% IMPORTANT:
% This is treated as a literature time-scale anchor, NOT as proof that
% the five-point simulation used exactly 1.000 s.
cfg.paper_aperture_time_s = 1.0;

%% Geometry uncertainty retained from P1
% Exact R0 / incidence angle for the five-point experiment is not reported.
cfg.slant_range_factor = [1.0, sqrt(2), 2.0];
cfg.representative_slant_range_factor = sqrt(2);

%% Beam-derived aperture estimate
% First-order azimuth beamwidth scale:
%       beta_az ~= lambda / L_a
% and:
%       T_ap ~= R0 * beta_az / V
%
% This is a literature/engineering-derived estimate, not a Wang table value.
cfg.beamwidth_scale = 1.0;

%% MC-LFM nuisance parameters not reported in Wang five-point experiment
cfg.component_amplitudes = ones(1,5);
cfg.component_center_frequency_cycles_per_sample = zeros(1,5);

% Unknown initial phases are explicitly swept.
cfg.num_phase_mc = 40;
cfg.phase_seed = 20230911;

%% Discrete FrAc statistic
% Wang Eq. (17)-(22):
%   FrAc auto-term peaks when tan(beta) = a_i,
% where Eq. (13) uses:
%   exp{j 2pi [0.5 a_i m^2 + b_i m]}.
%
% Physical residual FM K_res maps to:
%   a_i = K_res / PRF^2.
%
% We evaluate an Eq.(17)-consistent discrete ambiguity statistic:
%
%   R_beta[k] ~= sum_m x[m+k] conj(x[m])
%                 exp{-j2pi m k tan(beta)}
%
%   E(beta) = sum_k |R_beta[k]|^2
%
% Because the relevant beta values are very small here, cos(beta)~1.
cfg.max_lag_fraction = 0.40;
cfg.frac_fft_oversample = 32;
cfg.beta_grid_oversample = 100;
cfg.beta_grid_margin_separations = 3.0;

%% Peak matching / diagnostics
cfg.peak_match_tolerance_fraction = 0.40;
cfg.min_peak_prominence_fraction = 0.02;

% Diagnostic gate only; not a literature number.
cfg.phase_mc_all5_rate_gate = 0.80;

%% Figure/output
cfg.figure_visible = 'off';
cfg.output_dir = '';

end
