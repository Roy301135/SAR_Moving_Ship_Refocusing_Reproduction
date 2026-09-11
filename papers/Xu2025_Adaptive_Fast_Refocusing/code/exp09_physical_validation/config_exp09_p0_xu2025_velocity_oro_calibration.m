function cfg = config_exp09_p0_xu2025_velocity_oro_calibration()
%CONFIG_EXP09_P0_XU2025_VELOCITY_ORO_CALIBRATION
% EXP009 / Physical Validation Track / P0
%
% Xu 2025 velocity <-> ORO convention / parameter calibration.
%
% Literature basis:
%   Xu et al., 2025, JSTARS,
%   "Adaptive Fast Refocusing for Ship Targets With Complex Motion in SAR Images"
%
% This configuration intentionally keeps paper-reported values separate
% from quantities inferred by this calibration script.
%
% IMPORTANT:
% Xu Table I does NOT explicitly list N_a (azimuth sampling points).
% Therefore N_a is treated as an effective calibration quantity, not as
% a paper-reported parameter.

%% Constants
cfg.c = 3.0e8;

%% Xu 2025 Table I: target simulation parameters
cfg.fc_hz = 3.0e9;
cfg.bandwidth_hz = 150e6;
cfg.prf_hz = 300;
cfg.platform_velocity_mps = 200;
cfg.pulse_width_s = 4e-6;
cfg.incidence_angle_deg = 45;
cfg.platform_height_m = 10e3;

% Derived slant range used in the P0 audit.
% The paper provides height and incidence angle, but does not explicitly
% list R0 in Table I. We use the standard geometry R0 = H/cos(theta_inc).
cfg.use_slant_range_from_height_incidence = true;

%% Xu 2025 Table II: target azimuth velocities
cfg.target_velocity_mps = [-10, -5, 0, 5, 10];

%% Xu 2025 Table III: published ORO and estimated speed
% Keep these numbers exactly as printed in the paper.
cfg.published_oro = [-0.415, -0.457, -0.500, -0.534, -0.583];
cfg.published_estimated_velocity_mps = [-11.09, -5.36, 0, 4.96, 9.29];

%% Rotation-order convention
% Xu states that "the rotation order was shifted by 0.5 overall".
% In this P0 implementation:
%   p_raw = 2*alpha/pi
%   p_reported = p_raw - 0.5
%
% This makes v_a = 0 correspond to p_reported = -0.5, matching Table III.
cfg.reported_order_shift = -0.5;

%% Effective N_a search
% Xu Eq. (20)-(22) depends on N_a, but Table I does not list it.
% Search a broad range and also infer row-wise N_a from Table III.
cfg.na_search_min = 128;
cfg.na_search_max = 4096;
cfg.na_search_step = 1;

%% Robust consistency rule
cfg.na_relative_consistency_tol = 0.10;  % 10%
cfg.oro_gate_abs_tol = 0.015;

%% Figure/output
cfg.figure_visible = 'off';
cfg.output_dir = '';

end
