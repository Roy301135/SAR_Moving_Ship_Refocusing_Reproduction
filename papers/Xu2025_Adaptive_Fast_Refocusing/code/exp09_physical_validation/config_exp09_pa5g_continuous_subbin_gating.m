function cfg = config_exp09_pa5g_continuous_subbin_gating()
%CONFIG_EXP09_PA5G_CONTINUOUS_SUBBIN_GATING
% EXP009 / PA5G
%
% Continuous Sub-Bin Estimation and Evidence-Gated Recentering
%
% PA5F established:
%   1) exact sub-bin recentering removes the off-grid leakage floor;
%   2) the previous 3-point log-power parabola has deterministic
%      interpolation bias at intermediate fractional-bin offsets;
%   3) blind mixture-based recentering can create false correction
%      when the true fence offset is small or zero.
%
% PA5G therefore addresses two deterministic bottlenecks:
%
%   A) replace local interpolation by a continuous single-tone ML/LS
%      frequency estimate derived directly from the dechirped model;
%
%   B) do not recenter blindly. Use a parameter-free evidence gate:
%
%        BIC prefers continuous-frequency model
%        AND
%        |estimated fractional offset| > split-aperture disagreement.
%
% The second condition uses the data's own split-aperture instability as
% an internal uncertainty scale. No physical threshold is tuned.
%
% IMPORTANT:
%   - strong chirp rate is still TRUE;
%   - no thermal noise;
%   - no clutter;
%   - PlateauAwareTol is fixed;
%   - all physical grids are inherited from PA5F.
%
% Groups:
%   G0 Baseline
%   G1 OracleRecenter
%   G2 ContinuousStrongOnly
%   G3 ContinuousMixtureAlways
%   G4 EvidenceGatedMixture

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

%% Representative geometry
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

%% Fractional-bin offsets
cfg.fractional_bin_offsets = [0, 0.125, 0.25, 0.375, 0.5];

%% Removal windows
cfg.filter_window_length_bins = [1, 3, 5, 9, 17];

%% Fixed peak semantics
cfg.peak_semantics = 'PlateauAwareTol';
cfg.frac_domain_peak_gate = 0.70;
cfg.tie_eps_multiplier = 100;

%% Previous estimator retained only as an audit baseline
cfg.old_subbin_estimator = 'LogPowerParabolic3';
cfg.log_power_floor = 1e-15;
cfg.subbin_delta_clip = 0.5;

%% Continuous ML/LS solver
% Numerical solver settings only; these are not physical tuning parameters.
% A 0.75-bin local search keeps an exact half-bin target away from the
% optimization boundary regardless of which tied integer bin is selected.
cfg.ml_search_halfwidth_bins = 0.75;
cfg.ml_bracket_points = 33;
cfg.ml_tolx_bins = 1e-11;
cfg.ml_max_fun_evals = 200;

%% Evidence gate
% H0: best integer-bin tone + unknown complex amplitude
% H1: continuous-frequency tone + unknown complex amplitude
%
% H1 adds one real frequency parameter:
cfg.bic_k_integer = 2;
cfg.bic_k_continuous = 3;

% Numerical floor only, tied to floating-point precision.
cfg.bic_eps_multiplier = 100;

% Primary gate:
%   delta_BIC > 0
%   AND
%   |fractional estimate| > split-aperture disagreement.
%
% No adjustable physical threshold is used.

%% Split-aperture diagnostic
cfg.split_min_samples = 32;

%% Weak-stage diagnostic
cfg.weak_stage_peak_gate = 0.70;
cfg.weak_stage_center_tolerance_bins = 1;

%% Error / feasibility
cfg.error_feasible_threshold = 1.0;
cfg.small_norm_floor = 1e-12;

%% Numerical decision checks
cfg.continuous_solver_rmse_gate_bins = 1e-5;
cfg.identity_gate = 1e-10;

%% Output
cfg.figure_visible = 'off';
cfg.output_dir = '';

end
