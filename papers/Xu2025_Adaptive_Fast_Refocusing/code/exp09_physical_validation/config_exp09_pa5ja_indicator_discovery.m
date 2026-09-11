function cfg = config_exp09_pa5ja_indicator_discovery()
%CONFIG_EXP09_PA5JA_INDICATOR_DISCOVERY
% EXP009 / PA5J-A
%
% Internal unreliability-indicator discovery for the G0 Top-1 estimator.
%
% The experiment deliberately DOES NOT design or tune a final gate.
% It only asks:
%
%   "Before running Neighbor-3, can the estimator itself observe signs
%    that its current Top-1 branch may be unsafe?"
%
% Candidate indicators are restricted to quantities available from:
%   cost class 0: the existing coarse FFT only;
%   cost class 1: the already-computed G0 local refinement;
%   cost class 2: two additional local objective evaluations.
%
% Oracle/global-reference quantities are used ONLY as labels, never as
% candidate gate features.

%% Upstream input locations
cfg.pa5i_folder_name = ...
    'exp09_pa5i_branchsafe_multicandidate_ml';
cfg.pa5i_trials_name = 'pa5i_trials.csv';

cfg.pa5i_r1_folder_name = ...
    'exp09_pa5i_r1_gamma_denseeta_tail_audit';
cfg.pa5i_r1_dense_trials_name = ...
    'pa5i_r1_dense_eta_trials.csv';

% PA5I-R1 keeps chirp-rate physics once per risk state rather than
% duplicating it in every dense-eta trial row.
cfg.pa5i_r1_risk_states_name = ...
    'pa5i_r1_dense_eta_risk_states.csv';

%% PA4-consistent physical coordinate
cfg.pa4_beta_width_paper_rad = 1.70e-4;
cfg.pa4_beta_width_beam_rad  = 8.60e-5;

%% G0 reconstruction -- inherited from PA5I
cfg.local_search_halfwidth_bins = 0.75;
cfg.local_bracket_points = 33;
cfg.local_tolx_bins = 1e-11;
cfg.local_max_fun_evals = 200;

% Reconstruction must agree with upstream G0.
cfg.reconstruction_tolerance_bins = 1e-6;

%% Indicator definitions
% Additional local probe for curvature/asymmetry.
cfg.curvature_probe_bins = 0.05;

% Plateau / support levels relative to coarse top-1 magnitude.
cfg.plateau_levels = [0.90,0.95];

%% Labels -- inherited from PA5I
cfg.branch_match_tolerance_bins = 0.02;
cfg.catastrophic_error_threshold_bins = 0.10;

%% Discovery metrics
cfg.trigger_fractions = [0.01,0.02,0.05,0.10,0.20,0.30,0.40,0.50];

% Screening threshold only. This does NOT become the PA5J-B gate.
cfg.discovery_auc_screen = 0.75;

% A candidate must keep the same risk direction on both original-grid
% and dense-risk data.
cfg.require_direction_consistency = true;

%% Figures / output
cfg.max_features_in_capture_plot = 6;
cfg.figure_visible = 'off';
cfg.output_dir = '';

end
