function cfg = config_exp10b_noiseless_formal_closure()
%CONFIG_EXP10B_NOISELESS_FORMAL_CLOSURE
% EXP010-B — Noiseless Practical Non-Oracle Formal Closure
%
% This config is frozen AFTER EXP010-A smoke-test implementation closure.
% Noise/clutter remain OFF. The purpose is formal deterministic closure of
% Claim 1 / Claim 2 before any SNR/noise-definition audit.
%
% VALIDATION SETS
%   1) OriginalGrid : full PA5 physical grid.
%   2) DenseRisk    : PA5I-R1 frozen risk states x eta=0:0.01:0.5.
%
% IMPORTANT
%   - Proposed policy is NOT retuned here.
%   - DenseRisk selection is evaluation-set construction only; risk-state
%     truth metadata never enters the Proposed decision path.
%   - Current operational semantics remain Option A batch/fixed-compute.

%% Identity
cfg.experiment_id = "EXP010B_NOISELESS_FORMAL_CLOSURE";
cfg.experiment_name = "Noiseless_Practical_NonOracle_Formal_Closure";
cfg.validation_sets = ["OriginalGrid","DenseRisk"];

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

%% Original full physical grid — inherited unchanged
cfg.weak_velocity_mps = 15;
cfg.full_delta_velocity_mps = [2.5, 5, 7.5, 10, 15, 20];
cfg.full_weak_to_strong_ratio = [0.10, 0.20, 0.30, 0.50, 0.80];
cfg.full_relative_phase_rad = (0:15)*(2*pi/16);
cfg.full_fractional_bin_offsets = [0, 0.125, 0.25, 0.375, 0.5];

%% PA5I-R1 frozen DenseRisk stress-set semantics
cfg.dense_eta_step_bins = 0.01;
cfg.dense_eta_bins = 0:cfg.dense_eta_step_bins:0.5;
cfg.require_dense_risk_input = true;
cfg.dense_risk_states_filename = 'pa5i_r1_dense_eta_risk_states.csv';

%% Practical strong-beta / ORO search support — frozen from EXP010-A
cfg.search_velocity_min_mps = -5;
cfg.search_velocity_max_mps = 35;
cfg.pa4_beta_width_paper_rad = 1.70e-4;
cfg.pa4_beta_width_beam_rad = 8.60e-5;
cfg.beta_search_step_width_fraction = 1/120;
cfg.beta_search_margin_widths = 2.5;
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

%% Frozen staged resource scheduler
cfg.stage1_budget = 0.20;              % Refined-LR, high -> risky
cfg.stage2_conditional_budget = 0.10;  % FiveBin, low -> risky
cfg.refined_lr_probe_bins = 0.05;
cfg.refined_lr_extra_evals = 2;

%% Frozen practical removal semantics
cfg.peak_semantics = "PlateauAwareTol";
cfg.frac_domain_peak_gate = 0.70;
cfg.tie_eps_multiplier = 100;
cfg.removal_window_bins = 3;
cfg.error_feasible_threshold = 1.0;
cfg.small_norm_floor = 1e-12;

%% Oracle controls — evaluation only
cfg.run_oracle_controls = true;

%% Formal audit / stop-rule settings
cfg.oracle_firewall_required = true;
cfg.min_auc_positive_cases_for_direction_flag = 5;
cfg.direction_reversal_auc_threshold = 0.50;
cfg.progress_every = 250;

%% Self-test tolerances
cfg.reconstruction_tolerance_bins = 1e-6;
cfg.translation_selftest_gate = 1e-10;
cfg.identity_gate = 1e-10;

%% Output / project paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);

% Expected placement:
% ...\Xu2025_Adaptive_Fast_Refocusing\code\exp10_practical_nonoracle_closure
cfg.code_dir = this_dir;
cfg.paper_root = fileparts(fileparts(this_dir));
cfg.results_root = fullfile(cfg.paper_root,"results");
cfg.exp10_results_root = fullfile(cfg.results_root,"exp10_practical_nonoracle_closure");
cfg.output_dir = fullfile(cfg.exp10_results_root,"exp10b_noiseless_formal_closure");
cfg.figure_dir = fullfile(cfg.output_dir,"figures");
cfg.figure_visible = 'off';

% Frozen upstream PA5I-R1 stress-state source.
cfg.dense_risk_states_path = fullfile( ...
    cfg.results_root,"exp09_physical_validation", ...
    "exp09_pa5i_r1_gamma_denseeta_tail_audit", ...
    cfg.dense_risk_states_filename);

% Single-file feedback bundle requested by the user.
cfg.feedback_bundle_name = 'EXP010B_FEEDBACK_BUNDLE.txt';

end
