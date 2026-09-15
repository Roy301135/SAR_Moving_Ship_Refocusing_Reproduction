function cfg = config_exp09_practical_nonoracle_closure()
%CONFIG_EXP10_PRACTICAL_NONORACLE_CLOSURE
% EXP010 — Noiseless Practical Non-Oracle Sequential Closure
%
% This configuration freezes the first integration smoke test after
% PA5J-B3-R2 policy freeze + Oracle Ledger v1.1.
%
% IMPORTANT:
%   1) The primary Proposed path receives observed samples only.
%   2) Truth is used only by the simulator/evaluation layer.
%   3) Default run_mode is SMOKE. Do not change to FORMAL until the
%      smoke-test oracle firewall and implementation audits pass.
%   4) Noise/clutter remain OFF. SNR is still PENDING-DEFINITION.

%% Identity
cfg.experiment_id = "EXP010_PRACTICAL_NONORACLE_CLOSURE";
cfg.experiment_name = "Noiseless_Practical_NonOracle_Integration";
cfg.run_mode = "smoke";   % "smoke" or "formal"

%% Constants / Wang-2023 physical anchor
cfg.c = 3.0e8;
cfg.fc_hz = 3.0e9;
cfg.prf_hz = 188;
cfg.bandwidth_hz = 150e6;
cfg.platform_height_m = 3000;
cfg.antenna_length_m = 2;
cfg.platform_velocity_mps = 150;
cfg.pulse_width_s = 1.5e-6;
cfg.slant_range_factor = sqrt(2);
cfg.paper_aperture_time_s = 1.0;
cfg.beamwidth_scale = 1.0;

%% Physical two-component family
cfg.weak_velocity_mps = 15;
cfg.full_delta_velocity_mps = [2.5, 5, 7.5, 10, 15, 20];
cfg.full_weak_to_strong_ratio = [0.10, 0.20, 0.30, 0.50, 0.80];
cfg.full_relative_phase_rad = (0:15)*(2*pi/16);
cfg.full_fractional_bin_offsets = [0, 0.125, 0.25, 0.375, 0.5];

% Smoke grid: intentionally spans low / middle / high difficulty but is
% NOT a paper-ready sampling grid.
cfg.smoke_delta_velocity_mps = [2.5, 10, 20];
cfg.smoke_weak_to_strong_ratio = [0.10, 0.30, 0.80];
cfg.smoke_relative_phase_rad = [0, pi/2, pi, 3*pi/2];
cfg.smoke_fractional_bin_offsets = [0, 0.25, 0.5];

%% Practical strong-beta / ORO search support
% PA5C's old scenario-specific beta grid depended on truth and therefore
% cannot be used in the Proposed path. The closure path uses ONE FIXED
% operational velocity support covering the complete simulated family.
%
% This is a closure implementation support, not a new method claim.
cfg.search_velocity_min_mps = -5;
cfg.search_velocity_max_mps = 35;

% PA4 measured intrinsic beta widths (fixed upstream calibration).
cfg.pa4_beta_width_paper_rad = 1.70e-4;
cfg.pa4_beta_width_beam_rad = 8.60e-5;

% Inherit PA5C grid-resolution logic: step = W_beta / 120 and a 2.5-width
% guard margin around the fixed operational support.
cfg.beta_search_step_width_fraction = 1/120;
cfg.beta_search_margin_widths = 2.5;

% Inherit PA5C FrAc response implementation.
cfg.max_lag_fraction = 0.40;
cfg.frac_fft_oversample = 32;

%% Frozen PA5I / PA5J local continuous-frequency branch semantics
cfg.local_search_halfwidth_bins = 0.75;
cfg.local_bracket_points = 33;
cfg.local_tolx_bins = 1e-11;
cfg.local_max_fun_evals = 200;
cfg.neighbor_radius = 1;

% Evaluation-only global reference; NEVER enters Proposed decisions.
cfg.global_search_halfwidth_bins = 1.5;
cfg.global_grid_step_bins = 1e-3;
cfg.global_tolx_bins = 1e-12;
cfg.global_max_fun_evals = 300;
cfg.branch_match_tolerance_bins = 0.02;
cfg.catastrophic_error_threshold_bins = 0.10;

%% Frozen PA5J staged resource scheduler
cfg.stage1_budget = 0.20;              % Refined-LR, high -> risky
cfg.stage2_conditional_budget = 0.10;  % FiveBin, low -> risky
cfg.refined_lr_probe_bins = 0.05;
cfg.refined_lr_extra_evals = 2;

%% Frozen PA5F/PA5C removal semantics
cfg.peak_semantics = "PlateauAwareTol";
cfg.frac_domain_peak_gate = 0.70;
cfg.tie_eps_multiplier = 100;

% PA5C selected 3 bins as balanced window for both Paper1s and
% BeamDerived. This width is frozen before any noise experiment.
cfg.removal_window_bins = 3;

% PA5B/C feasibility definition for residual waveform error.
cfg.error_feasible_threshold = 1.0;
cfg.small_norm_floor = 1e-12;

%% Oracle controls (evaluation only)
cfg.run_oracle_controls = true;

%% Self-test / firewall tolerances
cfg.oracle_firewall_required = true;
cfg.reconstruction_tolerance_bins = 1e-6;
cfg.translation_selftest_gate = 1e-10;
cfg.identity_gate = 1e-10;

%% Output
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);

% Expected user placement:
% ...\Xu2025_Adaptive_Fast_Refocusing\code\exp09_practical_nonoracle_closure
cfg.code_dir = this_dir;
cfg.paper_root = fileparts(fileparts(this_dir));
cfg.results_root = fullfile(cfg.paper_root,"results");
cfg.output_dir = fullfile(cfg.results_root,"exp10_practical_nonoracle_closure");
cfg.figure_dir = fullfile(cfg.output_dir,"figures");
cfg.figure_visible = 'off';

end
