function cfg = config_exp011_tb1_t3a_geometry_audit(run_mode)
%CONFIG_EXP011_TB1_T3A_GEOMETRY_AUDIT
% EXP011-A / Theory Bridge 1 / T3A
% Retrospective Objective-Geometry Audit
%
% IMPORTANT:
%   THIS AUDIT DOES NOT FIT THEORY TO DATA.
%   NO THEORY PARAMETER MAY BE ESTIMATED FROM FAILURE LABELS.
%
% run_mode:
%   "smoke"  - a small deterministic subset for implementation audit
%   "formal" - all frozen PA5I-R1 risk states x eta=0:0.01:0.5

if nargin < 1
    run_mode = "smoke";
end
run_mode = string(run_mode);

if ~ismember(run_mode,["smoke","formal"])
    error('EXP011A:UnknownRunMode', ...
        'run_mode must be "smoke" or "formal".');
end

%% Identity
cfg.experiment_id = "EXP011A_TB1_T3A";
cfg.experiment_name = "TB1_Retrospective_Objective_Geometry_Audit";
cfg.run_mode = run_mode;

%% Theory-integrity guards
cfg.allow_data_fitting = false;
cfg.allow_label_based_parameter_tuning = false;
cfg.use_true_strong_beta_control = true;
cfg.add_noise = false;
cfg.reestimate_beta = false;

%% Frozen PA5I / PA5I-R1 search semantics
cfg.local_search_halfwidth_bins = 0.75;
cfg.local_bracket_points = 33;
cfg.local_tolx_bins = 1e-11;
cfg.local_max_fun_evals = 200;

cfg.global_search_lo_bins = -1.5;
cfg.global_search_hi_bins = +1.5;
cfg.global_grid_step_bins = 1e-3;
cfg.global_tolx_bins = 1e-12;
cfg.global_max_fun_evals = 300;

cfg.branch_match_tolerance_bins = 0.02;
cfg.catastrophic_error_threshold_bins = 0.10;

%% Objective-geometry audit semantics
cfg.geometry_grid_step_bins = 1e-3;
cfg.localmax_merge_tolerance_bins = 5e-4;

% Numerical sign/tie tolerances only; never tune using labels.
cfg.objective_identity_rel_tol = 5e-11;
cfg.margin_zero_rel_tol = 1e-10;
cfg.coarse_tie_rel_tol = 1e-12;
cfg.branch_assignment_tol_bins = cfg.branch_match_tolerance_bins;

% Integer seeds whose local windows can intersect GlobalReference domain.
cfg.seed_min = floor(cfg.global_search_lo_bins - cfg.local_search_halfwidth_bins);
cfg.seed_max = ceil(cfg.global_search_hi_bins + cfg.local_search_halfwidth_bins);

%% Frozen DenseRisk eta semantics
cfg.dense_eta_bins = 0:0.01:0.5;

if run_mode=="smoke"
    cfg.smoke_eta_bins = [0,0.25,0.49,0.50];
    cfg.smoke_states_per_aperture = 3;
else
    cfg.smoke_eta_bins = [];
    cfg.smoke_states_per_aperture = NaN;
end

%% Output controls
cfg.progress_every = 100;
cfg.save_figures = true;
cfg.figure_visible = 'off';

%% Project paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);

% Expected placement:
% ...\Xu2025_Adaptive_Fast_Refocusing\code\exp011_theory_validation
cfg.code_dir = this_dir;
cfg.paper_root = fileparts(fileparts(this_dir));
cfg.results_root = fullfile(cfg.paper_root,"results");

cfg.upstream_dir = fullfile( ...
    cfg.results_root, ...
    "exp09_physical_validation", ...
    "exp09_pa5i_r1_gamma_denseeta_tail_audit");

cfg.risk_states_path = fullfile( ...
    cfg.upstream_dir,"pa5i_r1_dense_eta_risk_states.csv");

% Optional ledger only; no EXP010 file is used.
cfg.upstream_trials_path = fullfile( ...
    cfg.upstream_dir,"pa5i_r1_dense_eta_trials.csv");

cfg.output_root = fullfile( ...
    cfg.results_root,"exp011_theory_validation");
cfg.output_dir = fullfile( ...
    cfg.output_root,"exp011a_tb1_t3a_geometry_audit",char(run_mode));
cfg.figure_dir = fullfile(cfg.output_dir,"figures");

cfg.feedback_bundle_name = "EXP011_TB1_T3A_FEEDBACK_BUNDLE.txt";

end
