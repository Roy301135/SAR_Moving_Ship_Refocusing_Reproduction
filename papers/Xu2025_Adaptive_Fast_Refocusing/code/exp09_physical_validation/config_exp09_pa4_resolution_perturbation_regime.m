function cfg = config_exp09_pa4_resolution_perturbation_regime()
%CONFIG_EXP09_PA4_PHYSICAL_TWO_COMPONENT_RESOLUTION_PERTURBATION_REGIME
% EXP009 / Physical Validation Track / PA4
%
% Physical Two-Component Resolution-Perturbation Regime Validation
%
% This is NOT a mechanical rerun of normalized A4.
%
% P1/P1B/P1C showed that under Wang-like short apertures, component
% identifiability can fail before "peak shift" is even well-defined.
%
% PA4 therefore asks:
%
%   How does strong-weak interaction evolve as physical component
%   separation crosses the intrinsic FrAc resolution boundary?
%
% No noise. No CLEAN. Two components only.

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

%% Representative geometry
% Exact R0 for Wang's five-point experiment was not reported.
% Inherited controlled representative geometry from P1/P1B/P1C.
cfg.slant_range_factor = sqrt(2);

%% Aperture modes
cfg.paper_aperture_time_s = 1.0;
cfg.beamwidth_scale = 1.0;

%% Two-component physical geometry
% Fix the WEAK component at a Wang-listed velocity.
cfg.weak_velocity_mps = 15;

% Place the STRONG component symmetrically in VELOCITY on either side.
% Values <=10 m/s stay inside Wang's [5,25] m/s five-point span.
% 15 and 20 m/s are controlled extensions to probe the resolution boundary.
cfg.delta_velocity_mps = [2.5, 5, 7.5, 10, 15, 20];

%% Amplitude contrast
% Strong amplitude is fixed to 1.
% Weak/strong amplitude ratio is a controlled sweep because Wang does not
% report a unique scattering-amplitude ratio for the five-point experiment.
cfg.A_strong = 1.0;
cfg.weak_to_strong_ratio = [0.10, 0.20, 0.30, 0.50, 0.80];

%% Relative phase
% Deterministic phase sweep; no random Monte Carlo is needed in PA4.
cfg.num_relative_phases = 16;
cfg.relative_phase_rad = ...
    (0:cfg.num_relative_phases-1) * ...
    (2*pi/cfg.num_relative_phases);

%% Center frequency
% P1C showed b_i separation is not the primary resolution bottleneck.
% PA4 fixes equal center frequency to isolate chirp-rate / FrAc interaction.
cfg.center_frequency_cycles_per_sample = 0;

%% FrAc statistic
cfg.max_lag_fraction = 0.40;
cfg.frac_fft_oversample = 32;

%% Intrinsic weak-response width calibration
cfg.width_grid_halfspan_rad = 8e-4;
cfg.width_grid_points = 1601;

%% Scenario beta grid
cfg.beta_margin_widths = 2.5;
cfg.beta_step_width_fraction = 1/120;
cfg.beta_step_separation_fraction = 1/40;
cfg.beta_step_min_width_fraction = 1/400;

%% Peak association
cfg.min_peak_prominence_fraction = 0.02;
cfg.peak_association_fraction_of_separation = 0.45;
cfg.peak_association_min_width_fraction = 0.20;

%% First-order perturbation validity
cfg.firstorder_max_abs_shift_widths = 1.0;
cfg.perturbative_measured_shift_widths = 0.50;
cfg.min_firstorder_samples = 20;

%% Regime labels (diagnostic boundaries, not literature constants)
cfg.gamma_unresolved_max = 0.50;
cfg.gamma_partial_max = 1.50;

%% Decision heuristics
cfg.high_gamma_resolved_rate_gate = 0.70;
cfg.firstorder_corr_gate = 0.80;
cfg.mirror_sign_gate = 0.75;

%% Figures/output
cfg.figure_visible = 'off';
cfg.output_dir = '';

end
