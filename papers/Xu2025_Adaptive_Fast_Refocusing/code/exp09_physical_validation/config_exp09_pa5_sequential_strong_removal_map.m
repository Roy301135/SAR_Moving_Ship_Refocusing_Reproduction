function cfg = config_exp09_pa5_sequential_strong_removal_map()
%CONFIG_EXP09_PA5_SEQUENTIAL_STRONG_REMOVAL_MAP
% EXP009 / Physical Validation Track / PA5
%
% Physical Sequential Strong-Removal Recovery Map
%
% PA4 established that weak-component observability is jointly controlled
% by resolution, amplitude contrast, and coherent phase. PA5 now asks:
%
%   Can sequential strong removal reveal a weak component that was hidden
%   in the pre-removal FrAc landscape?
%
% No noise in PA5. This isolates deterministic strong-removal behavior.

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

%% Representative geometry inherited from P1/P1B/P1C/PA4
cfg.slant_range_factor = sqrt(2);

%% Aperture modes inherited from PA4
cfg.paper_aperture_time_s = 1.0;
cfg.beamwidth_scale = 1.0;

%% Two-component geometry inherited from PA4
cfg.weak_velocity_mps = 15;
cfg.delta_velocity_mps = [2.5, 5, 7.5, 10, 15, 20];

%% Amplitude contrast inherited from PA4
cfg.A_strong = 1.0;
cfg.weak_to_strong_ratio = [0.10, 0.20, 0.30, 0.50, 0.80];

%% Relative phase inherited from PA4
cfg.num_relative_phases = 16;
cfg.relative_phase_rad = ...
    (0:cfg.num_relative_phases-1) * ...
    (2*pi/cfg.num_relative_phases);

%% Center frequency
% P1C showed b_i is not the primary short-aperture resolution bottleneck.
% Keep b_s=b_w=0 to isolate strong-removal mechanics.
cfg.center_frequency_cycles_per_sample = 0;

%% FrAc statistic
cfg.max_lag_fraction = 0.40;
cfg.frac_fft_oversample = 32;

%% Weak-only intrinsic-width calibration
cfg.width_grid_halfspan_rad = 8e-4;
cfg.width_grid_points = 1601;

%% Scenario beta grid
cfg.beta_margin_widths = 2.5;
cfg.beta_step_width_fraction = 1/120;
cfg.beta_step_separation_fraction = 1/40;
cfg.beta_step_min_width_fraction = 1/400;

%% Peak detection / association
cfg.min_peak_prominence_fraction = 0.02;
cfg.peak_association_fraction_of_separation = 0.45;
cfg.peak_association_min_width_fraction = 0.20;

%% Practical strong estimation
% Strong beta is estimated by the GLOBAL FrAc-energy maximum of the full
% mixture. Grid-point estimation is intentionally used so that pair
% responses for repeated beta_hat values can be cached exactly.
cfg.strong_estimation_success_widths = 0.50;

%% Recovery definitions
% "Hidden" means there is no observable LOCAL weak-associated peak before
% strong removal.
%
% A post-removal recovery is strongest when the residual GLOBAL maximum is
% associated with the true weak component.
cfg.post_weak_global_tolerance_widths = 0.50;
cfg.post_weak_local_tolerance_widths = 0.50;

%% Error / distortion metrics
cfg.small_norm_floor = 1e-12;

%% Diagnostic regime labels retained from PA4
cfg.gamma_unresolved_max = 0.50;
cfg.gamma_partial_max = 1.50;

%% Decision heuristics
% These are analysis thresholds, not literature constants.
cfg.practical_rescue_gate = 0.70;
cfg.oracle_operator_rescue_gate = 0.90;
cfg.max_median_practical_error_ratio = 0.50;

%% Figures/output
cfg.figure_visible = 'off';
cfg.output_dir = '';

end
