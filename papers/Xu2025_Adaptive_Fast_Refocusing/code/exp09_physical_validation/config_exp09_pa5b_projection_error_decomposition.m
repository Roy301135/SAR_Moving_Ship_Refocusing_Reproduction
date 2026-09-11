function cfg = config_exp09_pa5b_projection_error_decomposition()
% EXP009 / PA5B — corrected complex-LS projection audit + tolerance map

cfg.c = 3e8;

% Wang 2023 paper-grounded parameters
cfg.fc_hz = 3e9;
cfg.prf_hz = 188;
cfg.bandwidth_hz = 150e6;
cfg.platform_height_m = 3000;
cfg.antenna_length_m = 2;
cfg.platform_velocity_mps = 150;
cfg.pulse_width_s = 1.5e-6;

% Representative physical setting inherited from P1–PA5
cfg.slant_range_factor = sqrt(2);
cfg.paper_aperture_time_s = 1.0;
cfg.beamwidth_scale = 1.0;

cfg.weak_velocity_mps = 15;
cfg.delta_velocity_mps = [2.5 5 7.5 10 15 20];
cfg.A_strong = 1.0;
cfg.weak_to_strong_ratio = [0.10 0.20 0.30 0.50 0.80];

cfg.num_relative_phases = 16;
cfg.relative_phase_rad = ...
    (0:cfg.num_relative_phases-1)*(2*pi/cfg.num_relative_phases);

cfg.center_frequency_cycles_per_sample = 0;

% FrAc settings
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
cfg.post_weak_global_tolerance_widths = 0.50;

cfg.gamma_unresolved_max = 0.50;
cfg.gamma_partial_max = 1.50;

% Controlled strong-parameter mismatch sweep
cfg.delta_beta_over_width = linspace(-0.30,0.30,121);
cfg.error_thresholds = [0.50 1.00];

% Numerical gate for exact projection identity
cfg.identity_max_abs_error_gate = 1e-10;
cfg.small_norm_floor = 1e-12;

cfg.figure_visible = 'off';
cfg.output_dir = '';
end
