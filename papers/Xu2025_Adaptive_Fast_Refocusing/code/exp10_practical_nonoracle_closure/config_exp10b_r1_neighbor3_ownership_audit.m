function cfg = config_exp10b_r1_neighbor3_ownership_audit()
%CONFIG_EXP10B_R1_NEIGHBOR3_OWNERSHIP_AUDIT
% EXP010-B-R1 — Recovery-Operator Ownership Audit
%
% This is NOT a method-redesign experiment. It is an evaluation-only audit
% triggered by EXP010-B formal closure, where Always-Neighbor3 retained
% deterministic catastrophic branch failures after practical strong-beta
% estimation.
%
% Goal:
%   determine whether the loss of Neighbor-3 branch safety is owned by
%   upstream practical beta-hat mismatch, adjacency/candidate coverage, or
%   local-refinement / implementation transfer.
%
% Truth enters only the audit-control branch. The frozen Proposed method is
% not changed, reranked, or retuned.

%% Identity
cfg.experiment_id = "EXP010B_R1_NEIGHBOR3_OWNERSHIP_AUDIT";
cfg.experiment_name = "Neighbor3_Practical_Beta_Ownership_Audit";

%% Frozen branch semantics — inherited verbatim from EXP010-B / PA5I
cfg.local_search_halfwidth_bins = 0.75;
cfg.local_bracket_points = 33;
cfg.local_tolx_bins = 1e-11;
cfg.local_max_fun_evals = 200;
cfg.neighbor_radius = 1;

cfg.global_search_halfwidth_bins = 1.5;
cfg.global_grid_step_bins = 1e-3;
cfg.global_tolx_bins = 1e-12;
cfg.global_max_fun_evals = 300;
cfg.branch_match_tolerance_bins = 0.02;
cfg.catastrophic_error_threshold_bins = 0.10;

%% Physical constants / aperture context — inherited from EXP010-B
cfg.c = 3.0e8;
cfg.fc_hz = 3.0e9;
cfg.prf_hz = 188;
cfg.platform_height_m = 3000;
cfg.antenna_length_m = 2;
cfg.platform_velocity_mps = 150;
cfg.slant_range_factor = sqrt(2);
cfg.paper_aperture_time_s = 1.0;
cfg.beamwidth_scale = 1.0;
cfg.pa4_beta_width_paper_rad = 1.70e-4;
cfg.pa4_beta_width_beam_rad = 8.60e-5;

%% Audit sampling
% Every current Always-N3 catastrophic failure is audited.
% In addition, a deterministic control sample of current N3 successes is
% reconstructed per validation-set/aperture group to guard against silent
% code drift. This is NOT used to tune any threshold.
cfg.n_success_controls_per_group = 40;
cfg.reconstruction_tolerance_bins = 1e-6;
cfg.branch_error_reconstruction_tolerance = 1e-8;

%% Output paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
cfg.code_dir = this_dir;
cfg.paper_root = fileparts(fileparts(this_dir));
cfg.results_root = fullfile(cfg.paper_root,"results");
cfg.exp10_results_root = fullfile(cfg.results_root,"exp10_practical_nonoracle_closure");
cfg.exp10b_input_dir = fullfile(cfg.exp10_results_root,"exp10b_noiseless_formal_closure");
cfg.output_dir = fullfile(cfg.exp10_results_root,"exp10b_r1_neighbor3_ownership_audit");
cfg.figure_dir = fullfile(cfg.output_dir,"figures");
cfg.figure_visible = 'off';
cfg.feedback_bundle_name = 'EXP010B_R1_FEEDBACK_BUNDLE.txt';

%% Required EXP010-B inputs
cfg.truth_file = fullfile(cfg.exp10b_input_dir,'truth_metadata_all.csv');
cfg.online_file = fullfile(cfg.exp10b_input_dir,'practical_online_outputs_all.csv');
cfg.eval_file = fullfile(cfg.exp10b_input_dir,'evaluation_trials_all.csv');

end
