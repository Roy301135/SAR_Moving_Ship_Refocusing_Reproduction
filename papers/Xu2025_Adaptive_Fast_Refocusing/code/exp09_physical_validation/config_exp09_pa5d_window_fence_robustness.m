function cfg = config_exp09_pa5d_window_fence_robustness()
%CONFIG_EXP09_PA5D_WINDOW_FENCE_ROBUSTNESS
% EXP009 / Physical Validation Track / PA5D
%
% Window-Normalized and Fence-Effect Robustness of Strong Removal
%
% PA5C established, under the Wang-style transform-domain removal bridge:
%
%   E^2 = (L_s/r_A)^2 + D_w^2
%
% where:
%   L_s : residual strong leakage relative to strong norm
%   D_w : weak projection loss relative to weak norm
%   r_A : A_w/A_s
%
% PA5D tests whether this mechanism survives:
%   1) bandwidth-normalized window comparison across apertures;
%   2) off-grid / fractional-bin focused peaks (fence effect);
%   3) adaptive, non-clipped subtraction-tolerance estimation.
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

%% Representative geometry inherited from P1-PA5C
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

%% New PA5D factor: fractional focused-bin offset
% b = eta/N cycles/sample, so eta is the focused FFT-bin offset.
% 0.5 is the classical worst fence-effect position.
% Positive offsets are sufficient for the primary robustness test because
% the ideal DFT leakage envelope is sign-symmetric. Directional asymmetry
% is separately measured in the beta-mismatch tolerance stage.
cfg.fractional_bin_offsets = [0, 0.125, 0.25, 0.375, 0.5];

%% FrAc strong-order estimation (same as PA5C)
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

%% Wang Algorithm-2 peak gate
cfg.frac_domain_peak_gate = 0.70;
cfg.weak_stage_peak_gate = 0.70;
cfg.weak_stage_center_tolerance_bins = 1;

%% Window families
% Family A: exactly the PA5C fixed-bin sweep.
cfg.fixed_window_bins = [1, 3, 5, 9, 17];

% Family B: equal physical/norm bandwidth across apertures.
% Target fractions are defined by the Paper1s reference aperture:
%
%       l/N_ref
%
% For each actual aperture N, these fractions are converted to the nearest
% positive odd number of bins. Since PRF is fixed, equal l/N also means
% equal transform-domain physical bandwidth l*PRF/N.
cfg.bandwidth_reference_mode = 'Paper1s';

%% Resolution labels
cfg.gamma_unresolved_max = 0.50;
cfg.gamma_partial_max = 1.50;

%% Exact fixed-mask identity gate
cfg.identity_max_abs_error_gate = 1e-10;
cfg.small_norm_floor = 1e-12;

%% Balanced-window selection
% Among windows with success >= this fraction of the best success,
% select the minimum-error window.
cfg.balanced_success_fraction = 0.90;

%% Adaptive tolerance stage
% Representative physical geometry: same bridge used in PA5C.
cfg.tolerance_delta_velocity_mps = 10;
cfg.tolerance_side = 'HighV';

% Use a subset of fence offsets in the expensive tolerance stage.
cfg.tolerance_fractional_bin_offsets = [0, 0.25, 0.5];

cfg.tolerance_error_threshold = 1.0;

% Adaptive beta-mismatch search:
cfg.tolerance_initial_abs_delta_over_width = 0.30;
cfg.tolerance_max_abs_delta_over_width = 2.00;
cfg.tolerance_grid_step_over_width = 0.0025;

%% Linear scaling-law fit
% Fit connected-safe tolerance versus r_A through origin:
%
%       delta_tol ~= alpha * r_A
%
% Report alpha and R^2, but do not treat alpha as universal.
cfg.fit_tolerance_through_origin = true;

%% Output
cfg.figure_visible = 'off';
cfg.output_dir = '';

end
