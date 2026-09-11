function cfg = config_exp09_pa5c_wang_filter_removal_bridge()
%CONFIG_EXP09_PA5C_WANG_FILTER_REMOVAL_BRIDGE
% EXP009 / Physical Validation Track / PA5C
%
% Wang-2023 Algorithm-2 Filter-Removal Bridge
%
% Goal:
%   Test whether the PA5B subtraction-sensitivity mechanism survives when
%   the rank-1 LS projector is replaced by a Wang-style transform-domain
%   narrowband removal operator.
%
% IMPORTANT SOURCE DISCIPLINE
% ---------------------------
% Wang 2023 Algorithm 2 specifies:
%   1) FrFT at each component's optimal rotation order;
%   2) detect peaks with magnitude > 0.7 * max magnitude;
%   3) narrowband-window each detected peak;
%   4) accumulate filtered component;
%   5) subtract it in the fractional domain;
%   6) inverse FrFT to obtain the residual.
%
% The paper defines the narrowband window length "l" but does not provide
% a unique numerical value in the algorithm text. Therefore PA5C MUST
% sweep window length rather than invent one fixed "paper value".
%
% Also, the paper does not fully specify the exact discrete FrFT
% implementation/scaling used by the authors. PA5C therefore uses an
% explicitly labelled LFM-matched unitary bridge:
%
%   dechirp at a_hat -> unitary FFT -> narrowband mask -> inverse FFT
%   -> re-chirp.
%
% For the discrete LFM model used throughout EXP009, this produces the
% same functional action required by Algorithm 2: the matched LFM
% component becomes a concentrated impulse-like spectral peak, is
% narrowband-filtered, and is transformed back.
%
% This is an algorithm-fidelity bridge, NOT a claim of bit-exact
% reproduction of the authors' private DFrFT implementation.

%% Constants
cfg.c = 3.0e8;

%% Wang 2023 paper-grounded SAR parameters
cfg.fc_hz = 3.0e9;
cfg.prf_hz = 188;
cfg.bandwidth_hz = 150e6;
cfg.platform_height_m = 3000;
cfg.antenna_length_m = 2;
cfg.platform_velocity_mps = 150;
cfg.pulse_width_s = 1.5e-6;

%% Representative geometry inherited from P1-PA5B
cfg.slant_range_factor = sqrt(2);

%% Apertures inherited from PA4-PA5B
cfg.paper_aperture_time_s = 1.0;
cfg.beamwidth_scale = 1.0;

%% Two-component physical grid
cfg.weak_velocity_mps = 15;
cfg.delta_velocity_mps = [2.5, 5, 7.5, 10, 15, 20];

cfg.A_strong = 1.0;
cfg.weak_to_strong_ratio = [0.10, 0.20, 0.30, 0.50, 0.80];

cfg.num_relative_phases = 16;
cfg.relative_phase_rad = ...
    (0:cfg.num_relative_phases-1) * ...
    (2*pi/cfg.num_relative_phases);

%% Center-frequency control
% P1C showed b_i was not the primary short-aperture bottleneck.
cfg.center_frequency_cycles_per_sample = 0;

%% FrAc strong-order estimation (same as PA5B)
cfg.max_lag_fraction = 0.40;
cfg.frac_fft_oversample = 32;

cfg.width_grid_halfspan_rad = 8e-4;
cfg.width_grid_points = 1601;

cfg.beta_margin_widths = 2.5;
cfg.beta_step_width_fraction = 1/120;
cfg.beta_step_separation_fraction = 1/40;
cfg.beta_step_min_width_fraction = 1/400;

cfg.min_peak_prominence_fraction = 0.02;
cfg.peak_association_fraction_of_separation = 0.45;
cfg.peak_association_min_width_fraction = 0.20;

%% Wang Algorithm-2 source-reported peak gate
cfg.frac_domain_peak_gate = 0.70;

%% Wang narrowband window length l
% Paper defines l but does not report one unique numeric value.
% Controlled sensitivity sweep in fractional-domain bins:
cfg.filter_window_length_bins = [1, 3, 5, 9, 17];

%% Weak-stage Algorithm-2 readiness
% At the TRUE weak order, Wang Algorithm 2 accepts refocused peaks whose
% magnitude exceeds 0.7*max. Since b_w=0 in PA5C, the ideal weak peak is
% at the DC bin after matched dechirp.
cfg.weak_stage_peak_gate = 0.70;
cfg.weak_stage_center_tolerance_bins = 1;

%% PA5B analytic LS reference
cfg.small_norm_floor = 1e-12;

%% Resolution labels
cfg.gamma_unresolved_max = 0.50;
cfg.gamma_partial_max = 1.50;

%% Exact per-mask projection identity gate
cfg.identity_max_abs_error_gate = 1e-10;

%% Controlled mismatch transfer for tolerance-law bridge
cfg.tolerance_delta_beta_over_width = linspace(-0.30,0.30,121);
cfg.tolerance_error_threshold = 1.0;

% Representative geometry only for the controlled transfer law.
cfg.tolerance_delta_velocity_mps = 10;
cfg.tolerance_side = 'HighV';

%% Figure/output
cfg.figure_visible = 'off';
cfg.output_dir = '';

end
