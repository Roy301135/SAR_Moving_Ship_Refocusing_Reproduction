function cfg = config_exp10c_noise_robustness(run_mode)
%CONFIG_EXP10C_NOISE_ROBUSTNESS
% EXP010-C — Frozen-Policy Additive-Noise Robustness
%
% Source of truth:
%   EXP010C_NOISE_PROTOCOL_FREEZE_v1.0
%
% RUN MODES
%   "smoke"           : implementation-only smoke test; no scientific claims.
%   "dense_formal"    : DenseRisk primary noise-validation set.
%   "original_anchor" : broad OriginalGrid sanity anchors.
%   "all_formal"      : DenseRisk + OriginalGrid anchor in one invocation.
%
% IMPORTANT POLICY SEMANTICS
%   - The Refined-LR/FiveBin rank-budget scheduler is applied once over the
%     entire validation-set x aperture processing pool.
%   - The scheduler NEVER receives SNR, truth eta, Gamma, contrast, phase,
%     regime labels, or future N3 outcomes.
%   - In particular, we DO NOT re-rank separately at each true SNR.
%
% EXP010-C models additive circular complex Gaussian noise only.
% It does NOT claim to model sea clutter.

if nargin < 1 || strlength(string(run_mode))==0
    run_mode = "smoke";
end
run_mode = string(run_mode);

%% Identity / protocol
cfg.experiment_id = "EXP010C_NOISE_ROBUSTNESS";
cfg.experiment_name = "Frozen_Policy_Additive_Noise_Robustness";
cfg.protocol_version = "EXP010C_NOISE_PROTOCOL_FREEZE_v1.0";
cfg.run_mode = run_mode;

%% Constants / Wang-2023 physical anchor — inherited unchanged
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

%% OriginalGrid physical states — inherited unchanged
cfg.weak_velocity_mps = 15;
cfg.full_delta_velocity_mps = [2.5, 5, 7.5, 10, 15, 20];
cfg.full_weak_to_strong_ratio = [0.10, 0.20, 0.30, 0.50, 0.80];
cfg.full_relative_phase_rad = (0:15)*(2*pi/16);
cfg.full_fractional_bin_offsets = [0, 0.125, 0.25, 0.375, 0.5];

%% PA5I-R1 DenseRisk stress-state semantics — inherited unchanged
cfg.dense_eta_step_bins = 0.01;
cfg.dense_eta_bins = 0:cfg.dense_eta_step_bins:0.5;
cfg.require_dense_risk_input = true;
cfg.dense_risk_states_filename = 'pa5i_r1_dense_eta_risk_states.csv';

%% Noise protocol — FROZEN
cfg.noise_model = "circular_complex_AWGN";
cfg.snr_reference = "strong_component_per_sample_input_power";
cfg.snr_grid_dense_db = [-10, -5, 0, 5, 10, 15, 20];
cfg.snr_grid_original_db = [-10, 0, 10, 20];
cfg.mc_dense = 10;
cfg.mc_original = 5;
cfg.base_seed = uint64(2026091201);

% Smoke mode is an engineering self-check only. It changes neither the
% formal SNR grid nor any scientific method parameter.
cfg.smoke_snr_db = [-10, 0, 20];
cfg.smoke_mc = 1;
cfg.smoke_physical_cap_per_job = 12;

%% Practical strong-beta / ORO search support — frozen from EXP010-A/B
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

%% Noise-validation statistics
cfg.wilson_z = 1.959963984540054;
cfg.min_auc_positive_cases_for_direction_flag = 5;
cfg.direction_reversal_auc_threshold = 0.50;

%% Execution / checkpointing
cfg.resume = true;
cfg.checkpoint_block_size = 1000;
cfg.beta_vector_chunk_size = 64;
cfg.progress_every = 250;
cfg.keep_checkpoints = true;
cfg.write_case_level_csv = true;

% Noise formal validation uses only mandatory practical comparators.
% The noiseless oracle ladder was already closed in EXP010-B.
cfg.run_oracle_controls = false;

%% Self-test tolerances
cfg.translation_selftest_gate = 1e-10;
cfg.identity_gate = 1e-10;
cfg.batch_beta_equivalence_rel_tol = 5e-10;
cfg.seed_repeatability_tol = 0;

%% Run-mode allocation
switch run_mode
    case "smoke"
        cfg.validation_sets = ["DenseRisk"];
        cfg.aperture_modes = ["Paper1s","BeamDerived"];
    case "dense_formal"
        cfg.validation_sets = ["DenseRisk"];
        cfg.aperture_modes = ["Paper1s","BeamDerived"];
    case "original_anchor"
        cfg.validation_sets = ["OriginalGrid"];
        cfg.aperture_modes = ["Paper1s","BeamDerived"];
    case "all_formal"
        cfg.validation_sets = ["DenseRisk","OriginalGrid"];
        cfg.aperture_modes = ["Paper1s","BeamDerived"];
    otherwise
        error('EXP010C:UnknownRunMode', ...
            'run_mode must be smoke, dense_formal, original_anchor, or all_formal.');
end

%% Output / project paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);

% Expected placement:
% ...\Xu2025_Adaptive_Fast_Refocusing\code\exp10_practical_nonoracle_closure
cfg.code_dir = this_dir;
cfg.paper_root = fileparts(fileparts(this_dir));
cfg.results_root = fullfile(cfg.paper_root,"results");
cfg.exp10_results_root = fullfile(cfg.results_root,"exp10_practical_nonoracle_closure");
cfg.exp10c_root = fullfile(cfg.exp10_results_root,"exp10c_noise_robustness");
cfg.output_dir = fullfile(cfg.exp10c_root,char(run_mode));
cfg.figure_dir = fullfile(cfg.output_dir,"figures");
cfg.checkpoint_root = fullfile(cfg.output_dir,"checkpoints");
cfg.figure_visible = 'off';

cfg.dense_risk_states_path = fullfile( ...
    cfg.results_root,"exp09_physical_validation", ...
    "exp09_pa5i_r1_gamma_denseeta_tail_audit", ...
    cfg.dense_risk_states_filename);

cfg.feedback_bundle_name = sprintf('EXP010C_FEEDBACK_BUNDLE_%s.txt',char(run_mode));

end
