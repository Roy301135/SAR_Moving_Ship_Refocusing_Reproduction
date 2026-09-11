function cfg = config_exp09_pa5e_peak_support_pareto_audit()
%CONFIG_EXP09_PA5E_PEAK_SUPPORT_PARETO_AUDIT
% EXP009 / Physical Validation Track / PA5E
%
% Peak-Support / Resolution-Cell / Pareto Audit
%
% PA5D showed that off-grid focusing can create a nonzero strong-leakage
% floor and can destroy the simple on-grid linear tolerance fit.
%
% Before adding noise, PA5E audits three possible confounders:
%
%   1) Peak-extraction semantics:
%        LocalMax        : legacy PA5C/PA5D implementation
%        ConnectedSupport: literal supra-threshold connected support
%        PlateauAware    : local maxima with plateau/twin-bin handling
%
%   2) Window coordinate:
%        l
%        l/N
%        l/W_focus,3dB   (number of focused resolution cells)
%
%   3) Operating-point selection:
%        no arbitrary "90% balanced" rule;
%        use Pareto fronts and the E<=1 feasible region directly.
%
% PA5E also computes the exact zero-mismatch recoverability floor:
%
%   E0^2 = (L0/r_A)^2 + D0^2
%
% and
%
%   r_min = L0 / sqrt(1-D0^2)
%
% whenever D0 < 1.
%
% No noise.

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

%% Representative geometry inherited from P1-PA5D
cfg.slant_range_factor = sqrt(2);

%% Aperture modes
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

%% Fence-effect factor
cfg.fractional_bin_offsets = [0, 0.125, 0.25, 0.375, 0.5];

%% Peak semantics to audit
cfg.peak_semantics = ...
    ["LocalMax","ConnectedSupport","PlateauAware"];

%% Wang Algorithm-2 gate
cfg.frac_domain_peak_gate = 0.70;
cfg.weak_stage_peak_gate = 0.70;
cfg.weak_stage_center_tolerance_bins = 1;

%% Actual removal-window sweep
% PA5E does NOT build a second "equal-Hz" operator family.
% Instead, the SAME actual windows are expressed in three coordinates:
%   l, l/N, l/Wfocus.
% This avoids changing the operator while auditing its natural scale.
cfg.filter_window_length_bins = [1, 3, 5, 9, 17];

%% Oversampled focused-spectrum calibration
cfg.focus_spectrum_oversample = 128;
cfg.focus_width_power_fraction = 0.5;  % 3-dB power width

%% FrAc strong-order estimation
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

%% Resolution-regime thresholds inherited from PA4-PA5D
cfg.gamma_unresolved_max = 0.50;
cfg.gamma_partial_max = 1.50;

%% Error / feasibility
cfg.error_feasible_threshold = 1.0;
cfg.identity_max_abs_error_gate = 1e-10;
cfg.small_norm_floor = 1e-12;

%% Recoverability-floor sweep
% Use all physical separation geometries; the floor is geometry-dependent.
cfg.floor_use_all_delta_velocity = true;

%% Coordinate-collapse audit
cfg.collapse_grid_points = 201;
cfg.collapse_metrics = ...
    ["median_practical_error_ratio", ...
     "median_strong_leak_ratio", ...
     "median_weak_projection_loss_ratio"];

%% Decision-only diagnostic thresholds
% These thresholds classify outcomes; they do not define the Pareto front.
cfg.semantic_floor_reduction_ratio_gate = 0.50;
cfg.persistent_floor_rmin_gate = 0.05;

%% Representative figure case
cfg.figure_case_aperture = 'BeamDerived';
cfg.figure_case_delta_velocity_mps = 10;
cfg.figure_case_side = 'HighV';
cfg.figure_case_eta = 0.5;
cfg.figure_case_window_bins = 1;

%% Output
cfg.figure_visible = 'off';
cfg.output_dir = '';

end
