function cfg = config_exp09_pa5h_r1_modeswitch_audit()
%CONFIG_EXP09_PA5H_R1_MODESWITCH_AUDIT
% EXP009 / PA5H-R1
%
% Targeted deterministic audit after PA5H.
%
% Research questions:
%   RQ1. Are the large high-contrast eta-collapse outliers caused by
%        estimator branch/mode switching rather than a failure of the
%        translation-invariant signal model?
%   RQ2. Does the previous "best window" summary contain a tie-selection
%        artifact because many windows have median regret exactly zero?
%
% This is NOT a new algorithm stage.
% It does NOT tune the PA5G gate.
% It does NOT introduce a new practical estimator.

%% Constants
cfg.c = 3.0e8;

%% Wang-2023 / PA5H inherited parameters
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

cfg.weak_velocity_mps = 15;
cfg.delta_velocity_mps = [2.5, 5, 7.5, 10, 15, 20];

cfg.A_strong = 1.0;

% Only the contrasts that produced PA5H max-collapse anomalies.
cfg.audit_weak_to_strong_ratio = [0.50, 0.80];

cfg.num_relative_phases = 16;
cfg.relative_phase_rad = ...
    (0:cfg.num_relative_phases-1) * ...
    (2*pi/cfg.num_relative_phases);

cfg.fractional_bin_offsets = [0, 0.125, 0.25, 0.375, 0.5];

%% Same continuous ML estimator as PA5G / PA5H
cfg.ml_search_halfwidth_bins = 0.75;
cfg.ml_bracket_points = 33;
cfg.ml_tolx_bins = 1e-11;
cfg.ml_max_fun_evals = 200;

%% High-contrast collapse audit
% Threshold only separates ~1e-8 numerical collapse from the observed
% ~0.39-0.60 bin anomalies. It is diagnostic, not algorithmic.
cfg.collapse_outlier_threshold_bins = 1e-3;

% Exact translation check after oracle removal of the known common eta.
cfg.translation_signal_error_gate = 1e-12;

%% Global objective audit
% This is oracle diagnostic search in delta = nu - eta.
% It is NOT used as a new practical estimator.
cfg.global_search_halfwidth_bins = 1.5;
cfg.global_grid_step_bins = 1e-3;
cfg.global_top_peak_count = 5;
cfg.branch_match_tolerance_bins = 0.02;

% Near-degeneracy is reported, not used to tune the algorithm.
cfg.near_degenerate_peak_ratio = 0.98;

%% Regret re-tie
cfg.regret_tie_tolerance = 1e-12;

%% Existing PA5H result path
% Leave empty for automatic lookup:
%   <paper root>/results/exp09_physical_validation/
%       exp09_pa5h_bias_regret_audit
cfg.pa5h_results_dir = '';

%% Output
cfg.output_dir = '';
cfg.figure_visible = 'off';

end
