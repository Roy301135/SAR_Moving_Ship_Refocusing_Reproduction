function cfg = config_exp09_pa5h_bias_regret_audit()
%CONFIG_EXP09_PA5H_BIAS_REGRET_AUDIT
% EXP009 / PA5H
%
% Mixture-Induced Bias Law and Gate-Regret Audit
%
% Purpose
% -------
% PA5G established that:
%   1) continuous ML/LS removes the deterministic interpolation bias;
%   2) the remaining practical error is dominated by structured
%      strong+weak coherent mixture bias;
%   3) the evidence gate is useful but not yet optimal.
%
% PA5H is the FINAL deterministic closure before re-introducing:
%   - strong-order estimation error,
%   - noise,
%   - clutter / realistic perturbations.
%
% PA5H has two goals:
%
% A) derive and validate a first-order perturbation law
%
%        delta_mix ~= - Jcross'(0) / Jstrong''(0)
%
%    for the continuous ML frequency bias, and test:
%      - linearity vs Aw/As;
%      - phase structure vs phi;
%      - collapse across true eta;
%      - dependence on delta-a / velocity separation / aperture.
%
% B) evaluate gate DECISION REGRET per trial:
%
%        R = E_gate - min(E_no_recenter, E_always_recenter)
%
%    together with:
%      - false-recenter rate,
%      - missed-recenter rate,
%      - action agreement with per-trial oracle,
%      - regret distributions.
%
% No new estimator is introduced in PA5H.
% No threshold tuning is performed.

%% Constants
cfg.c = 3.0e8;

%% Wang-2023 paper-grounded SAR parameters
cfg.fc_hz = 3.0e9;
cfg.prf_hz = 188;
cfg.bandwidth_hz = 150e6;
cfg.platform_height_m = 3000;
cfg.antenna_length_m = 2;
cfg.platform_velocity_mps = 150;
cfg.pulse_width_s = 1.5e-6;

%% Geometry
cfg.slant_range_factor = sqrt(2);

%% Apertures
cfg.paper_aperture_time_s = 1.0;
cfg.beamwidth_scale = 1.0;

%% Physical two-component grid
cfg.weak_velocity_mps = 15;
cfg.delta_velocity_mps = [2.5, 5, 7.5, 10, 15, 20];

cfg.A_strong = 1.0;
cfg.weak_to_strong_ratio = [0.10, 0.20, 0.30, 0.50, 0.80];

cfg.num_relative_phases = 16;
cfg.relative_phase_rad = ...
    (0:cfg.num_relative_phases-1) * ...
    (2*pi/cfg.num_relative_phases);

%% True common fractional-bin offsets
cfg.fractional_bin_offsets = [0, 0.125, 0.25, 0.375, 0.5];

%% Removal windows
cfg.filter_window_length_bins = [1, 3, 5, 9, 17];

%% Fixed peak semantics
cfg.peak_semantics = 'PlateauAwareTol';
cfg.frac_domain_peak_gate = 0.70;
cfg.tie_eps_multiplier = 100;

%% Continuous ML / LS estimator
cfg.ml_search_halfwidth_bins = 0.75;
cfg.ml_bracket_points = 33;
cfg.ml_tolx_bins = 1e-11;
cfg.ml_max_fun_evals = 200;

%% Gate inherited from PA5G
cfg.bic_k_integer = 2;
cfg.bic_k_continuous = 3;
cfg.bic_eps_multiplier = 100;
cfg.split_min_samples = 32;

%% First-order bias law
% Numerical derivative step in DFT-bin coordinate.
% This is a numerical differentiation setting, not a physical threshold.
cfg.bias_derivative_step_bins = 1e-4;

% Small contrast subset for strict first-order goodness checks.
cfg.first_order_small_contrast_max = 0.30;

%% Weak-stage diagnostic
cfg.weak_stage_peak_gate = 0.70;
cfg.weak_stage_center_tolerance_bins = 1;

%% Error / feasibility
cfg.error_feasible_threshold = 1.0;
cfg.small_norm_floor = 1e-12;

%% Regret definitions
% Per-trial oracle action:
%   0 = no recenter
%   1 = recenter with continuous mixture estimate
%
% Tie handling is numerical only.
cfg.action_tie_tolerance = 1e-12;

%% Numerical checks
cfg.identity_gate = 1e-10;
cfg.eta_translation_collapse_gate_bins = 1e-5;

%% Output
cfg.figure_visible = 'off';
cfg.output_dir = '';

end
