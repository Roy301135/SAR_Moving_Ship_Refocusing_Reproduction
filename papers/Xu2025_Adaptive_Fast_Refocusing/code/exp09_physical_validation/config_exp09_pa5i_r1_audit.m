function cfg = config_exp09_pa5i_r1_audit()
%CONFIG_EXP09_PA5I_R1_AUDIT
% EXP009 / PA5I-R1
%
% Gamma-consistency + dense-fence + rare-tail audit.
%
% This is a revision/audit experiment, not a new main method stage.
%
% R1-A:
%   Restore the exact PA4 physical resolution coordinate:
%
%       a_i    = K_res,i / PRF^2
%       beta_i = atan(a_i)
%       Gamma  = |beta_s-beta_w| / W_beta,3dB
%
%   with the PA4 single-component 3-dB widths:
%       Paper1s     W_beta,3dB = 1.70e-4 rad
%       BeamDerived W_beta,3dB = 8.60e-5 rad
%
% R1-B:
%   Dense eta sweep on the exact physical/phase states that generated
%   G0 catastrophic failures in PA5I.  eta = 0:0.01:0.5 by default.
%
% R1-C:
%   Replace p95-only tail reporting by
%   p95 / p99 / p99.5 / p99.9 / max / catastrophic probability.
%
% No gate is tuned.
% No removal-window length is selected.
% No estimator is changed relative to PA5I.
%
% IMPORTANT:
% The dense global reference uses a moderate grid followed by local
% refinement. A deterministic subset is cross-checked against the
% original high-resolution global grid before the dense audit proceeds.

%% PA4 physical anchors
cfg.pa4_beta_width_paper_rad = 1.70e-4;
cfg.pa4_beta_width_beam_rad  = 8.60e-5;

% PA4 anchor values used only as a consistency audit.
cfg.pa4_anchor_dv_mps = [5,20];
cfg.pa4_anchor_paper_high = [0.32798,1.36499];
cfg.pa4_anchor_beam_high  = [0.64834,2.69824];
cfg.pa4_anchor_relative_tolerance = 0.02;

%% Dense eta audit
cfg.dense_eta_step_bins = 0.01;
cfg.dense_eta_bins = 0:cfg.dense_eta_step_bins:0.5;

%% Local continuous refinement -- inherited from PA5I
cfg.local_search_halfwidth_bins = 0.75;
cfg.local_bracket_points = 33;
cfg.local_tolx_bins = 1e-11;
cfg.local_max_fun_evals = 200;
cfg.neighbor_radius = 1;
cfg.coarse_candidate_use_localmax = true;

%% Global reference for dense audit
% Moderate grid for all dense-risk states:
cfg.global_search_halfwidth_bins = 1.5;
cfg.global_grid_step_bins = 0.01;
cfg.global_tolx_bins = 1e-12;
cfg.global_max_fun_evals = 300;

% High-resolution cross-check:
cfg.global_validation_step_bins = 0.001;
cfg.global_validation_n_states = 24;
cfg.global_validation_tolerance_bins = 1e-5;

%% Branch metrics -- inherited from PA5I
cfg.branch_match_tolerance_bins = 0.02;
cfg.catastrophic_error_threshold_bins = 0.10;
cfg.objective_loss_floor = 1e-15;

%% Rare-tail percentiles
cfg.tail_percentiles = [95,99,99.5,99.9];

%% Input/output
cfg.prior_pa5i_folder_name = ...
    'exp09_pa5i_branchsafe_multicandidate_ml';

cfg.prior_pa5i_trials_name = 'pa5i_trials.csv';

cfg.figure_visible = 'off';
cfg.output_dir = '';

end
