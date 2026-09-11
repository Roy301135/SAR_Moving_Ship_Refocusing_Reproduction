function cfg = config_exp09_pa5f_subbin_recenter_removal()
%CONFIG_EXP09_PA5F_SUBBIN_RECENTER_REMOVAL
% EXP009 / PA5F
%
% Sub-Bin Recentered / Fence-Aware Strong Removal
%
% PA5E-R1 closed the implementation audit:
%   - numerical tie handling changes the exact support;
%   - but the finite-window off-grid recoverability floor persists.
%
% PA5F is the first mechanism-to-method experiment.
%
% Core chain:
%
%   eta -> eta_hat -> epsilon = eta-eta_hat
%       -> Dirichlet leakage -> L0 -> r_min
%
% Groups:
%   G0 Baseline
%      true strong chirp rate, no frequency recentering.
%
%   G1 OracleRecenter
%      true strong chirp rate, true eta.
%
%   G2 StrongOnlyEstimate
%      true strong chirp rate, eta estimated from the strong-only
%      dechirped spectrum by a fixed 3-point log-power parabola.
%
%   G3 PracticalEstimate
%      true strong chirp rate, eta estimated from the strong+weak mixture
%      by the same estimator.
%
% Important isolation:
%   PA5F intentionally keeps beta_s / chirp-rate estimation perfect.
%   The only new variable is sub-bin frequency recentering.
%   Noise is still OFF.
%
% Two complementary tracks are produced:
%
%   A) floor track:
%      G0/G1/G2, strong-only mask selection, zero-mismatch L0/D0/r_min.
%
%   B) practical-mixture track:
%      G0/G1/G2/G3, mixture mask selection, all contrasts/phases.
%
% Peak semantics are FIXED to PlateauAwareTol from PA5E-R1.

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

%% Representative geometry inherited from PA5E-R1
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

%% Fence offsets
cfg.fractional_bin_offsets = [0, 0.125, 0.25, 0.375, 0.5];

%% Removal windows
cfg.filter_window_length_bins = [1, 3, 5, 9, 17];

%% Fixed peak semantics
cfg.peak_semantics = 'PlateauAwareTol';
cfg.frac_domain_peak_gate = 0.70;
cfg.tie_eps_multiplier = 100;

%% Sub-bin estimator
% Fixed in advance: 3-point log-power parabolic interpolation.
cfg.subbin_estimator = 'LogPowerParabolic3';
cfg.subbin_delta_clip = 0.5;
cfg.log_power_floor = 1e-15;

%% Weak-stage diagnostic
cfg.weak_stage_peak_gate = 0.70;
cfg.weak_stage_center_tolerance_bins = 1;

%% Error / feasibility
cfg.error_feasible_threshold = 1.0;
cfg.small_norm_floor = 1e-12;

%% Analytic Dirichlet validation
cfg.dirichlet_identity_gate = 1e-10;
cfg.oracle_leakage_gate = 1e-10;

%% Decision-only diagnostics
% These do not select the operating point.
cfg.estimator_good_rmse_bins = 0.05;
cfg.practical_halfbin_improvement_ratio_gate = 0.90;

%% Output
cfg.figure_visible = 'off';
cfg.output_dir = '';

end
