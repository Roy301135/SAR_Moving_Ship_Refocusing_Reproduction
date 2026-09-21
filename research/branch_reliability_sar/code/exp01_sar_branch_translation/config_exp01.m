function cfg = config_exp01(research_root)
%CONFIG_EXP01 Configuration for EXP01 SAR branch-translation foundation.
%
% Stage A only builds and audits the SAR physical chain:
%   sparse ship scatterers -> yaw motion -> range-compressed complex data
%   -> stationary-reference backprojection -> static/moving images.
%
% No G0 / Proposed / Neighbor-3 code is used in this stage.

if nargin < 1 || isempty(research_root)
    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    code_dir = fileparts(this_dir);
    research_root = fileparts(code_dir);
end

%% Constants
cfg.c = 299792458;

%% SAR system: literature-anchored simulation parameters
% Wang et al., Remote Sensing 2023 (swing-ship simulation table):
% fc = 3 GHz, PRF = 188 Hz, B = 150 MHz, H = 3000 m,
% antenna length = 2 m, platform velocity = 150 m/s.
cfg.fc = 3.0e9;
cfg.lambda = cfg.c / cfg.fc;
cfg.prf = 188;
cfg.bandwidth = 150e6;
cfg.platform_height = 3000;
cfg.platform_velocity = 150;
cfg.antenna_length = 2.0;

%% Scene center
cfg.ship_center_x = 0;
cfg.ship_center_y = 3000;
cfg.ship_center_z = 0;

% Broadside slant range to scene center.
cfg.R0 = sqrt(cfg.platform_height^2 + cfg.ship_center_y^2);

%% Synthetic aperture
% Approximate stripmap beam footprint L_sa = R0 * lambda / La.
% Use an odd number of pulses centered at eta = 0.
cfg.az_beamwidth = cfg.lambda / cfg.antenna_length;
cfg.synthetic_aperture_length = cfg.R0 * cfg.az_beamwidth;
cfg.synthetic_aperture_time_nominal = ...
    cfg.synthetic_aperture_length / cfg.platform_velocity;

Na_nominal = round(cfg.synthetic_aperture_time_nominal * cfg.prf);
if mod(Na_nominal, 2) == 0
    Na_nominal = Na_nominal + 1;
end
cfg.Na = Na_nominal;
cfg.eta = ((0:cfg.Na-1) - (cfg.Na-1)/2) / cfg.prf;
cfg.synthetic_aperture_time = cfg.eta(end) - cfg.eta(1);

%% Yaw motion
% Wang et al. reported yaw double amplitude 38 deg and average period
% 14.2 s for their simulated 3-D swing ship. Here we interpret double
% amplitude 38 deg as +/-19 deg. The aperture-center phase pi/2 gives a
% locally acceleration-dominated segment, useful for checking the short-
% aperture quadratic-phase / MC-LFM assumption.
cfg.motion.type = 'yaw_only';
cfg.motion.yaw_amplitude_rad = 19 * pi / 180;
cfg.motion.yaw_period_s = 14.2;
cfg.motion.yaw_phase0_rad = pi/2;
cfg.motion.theta_center_rad = cfg.motion.yaw_amplitude_rad * ...
    sin(cfg.motion.yaw_phase0_rad);

%% Sparse ship scatterer skeleton in the ship body frame
% Body axes:
%   x_b: ship longitudinal direction
%   y_b: ship transverse direction
%
% The strong/weak pair is geometrically chosen so that, after the frozen
% aperture-center yaw rotation, the two points have the same ground-range
% coordinate. This prepares a physically meaningful same-range-line pair
% for later branch-translation analysis without yet invoking the branch
% algorithm.
strong_x = -8.0;
strong_y = 0.0;
weak_x = 12.0;
weak_y = strong_y + (strong_x - weak_x) * tan(cfg.motion.theta_center_rad);

cfg.scatterers.body_xy_m = [ ...
    -30.0,   0.0; ...  % 1 bow
    -20.0,  -6.0; ...  % 2 port-side structure
    -20.0,   6.0; ...  % 3 starboard-side structure
    strong_x,strong_y; ...% 4 designated strong scatterer
      0.0,  -7.0; ...  % 5 midship
      0.0,   7.0; ...  % 6 midship
    weak_x, weak_y; ... % 7 designated weak scatterer
     20.0,   6.0; ...  % 8 aft structure
     30.0,   0.0];     % 9 stern

% Deterministic amplitudes. These are amplitude coefficients, not dB.
cfg.scatterers.amplitude = [0.65; 0.55; 0.70; 1.00; 0.50; 0.45; 0.25; 0.60; 0.55];

% Deterministic scatterer phases. Keeping them fixed avoids RNG dependence.
% The branch-level hard-state phase relation is NOT tuned in Stage A.
cfg.scatterers.phase_rad = zeros(9,1);
cfg.scatterers.complex_coeff = cfg.scatterers.amplitude .* ...
    exp(1j * cfg.scatterers.phase_rad);

cfg.scatterers.strong_idx = 4;
cfg.scatterers.weak_idx = 7;
cfg.scatterers.labels = { ...
    'P1_bow','P2_port','P3_starboard','P4_strong', ...
    'P5_mid_port','P6_mid_starboard','P7_weak','P8_aft','P9_stern'};

%% Range-compressed data grid
% Ideal compressed range response: sinc(2B/c * (R - Rp)).
% Sampling at half of the nominal range resolution.
cfg.range_resolution_m = cfg.c / (2 * cfg.bandwidth);
cfg.range_sample_spacing_m = cfg.range_resolution_m / 2;
cfg.range_half_span_m = 40;
Nr_side = ceil(cfg.range_half_span_m / cfg.range_sample_spacing_m);
cfg.range_offset_m = (-Nr_side:Nr_side) * cfg.range_sample_spacing_m;
cfg.range_axis_m = cfg.R0 + cfg.range_offset_m;
cfg.Nr = numel(cfg.range_axis_m);

%% BP image grid
cfg.image.dx_m = 0.5;
cfg.image.dy_m = 0.5;
cfg.image.x_axis_m = -45:cfg.image.dx_m:45;
cfg.image.y_axis_m = (cfg.ship_center_y-20):cfg.image.dy_m:(cfg.ship_center_y+20);

%% Numerical / output settings
cfg.bp.interp_method = 'linear';
cfg.display.dynamic_range_db = 35;
cfg.results_dir = fullfile(research_root, 'results', 'exp01_sar_branch_translation');
cfg.save_mat = true;
cfg.save_png = true;
cfg.close_figures_after_save = false;

% Stage-A policy: report model-fit residuals, but do not impose an
% unvalidated automatic pass/fail threshold. Formal gate will be frozen
% after inspecting the physically generated strong/weak histories.
cfg.model_consistency.auto_threshold_enabled = false;

end
