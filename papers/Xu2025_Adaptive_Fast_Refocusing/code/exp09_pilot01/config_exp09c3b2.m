function cfg = config_exp09c3b2()
%CONFIG_EXP09C3B2
% EXP009 / Pilot-01 / C3-B2
% Safe-Subset Beneficial Opportunity Audit
%
% Purpose:
%   After C3-B1.3 showed that Harmful fate is observable but perfect
%   harm avoidance explains only a minority of the TrialOracle gap,
%   C3-B2 asks the next bottleneck question:
%
%       among trials that are not harmful,
%       which trials are actually worth rescuing?
%
% A key decomposition is:
%
%   Beneficial
%       = CheapFailure AND FallbackSuccess
%
% so we separately audit:
%   1) Cheap-failure observability;
%   2) Rescueability conditional on CheapFailure;
%   3) direct Beneficial observability;
%   4) factorized Beneficial score
%          pB_factor = p(CheapFailure|X)
%                    * p(FallbackSuccess|CheapFailure,X)
%
% The experiment also evaluates whether combining that factorized
% opportunity score with the already-established Harm veto improves
% matched-budget computation allocation.

%% Reproducibility
cfg.seed = 20260909;

%% Input / output
cfg.input_dir_c3b1_2 = '';
cfg.input_dir_c3b1_3 = '';
cfg.output_dir = '';

%% State prior -- keep identical to C3-B1/C3-B1.2/C3-B1.3
cfg.state_utility_smooth_window = 7;

%% Cross-validation
cfg.num_folds = 5;

%% Models
cfg.ridge_lambda = 0.10;
cfg.irls_max_iter = 100;
cfg.irls_tol = 1e-8;
cfg.prob_clip = 1e-6;

%% Feature groups
cfg.morphology_features = { ...
    'cheap_prominence', ...
    'cheap_entropy', ...
    'peak_second_ratio', ...
    'peak_margin_norm', ...
    'top2_q_separation', ...
    'width50_q', ...
    'local_curvature_norm', ...
    'local_asymmetry', ...
    'peak_robust_z'};

cfg.strong_competition_features = { ...
    'strong_q_response_ratio', ...
    'strong_q_neighborhood_fraction', ...
    'peak_to_strong_q_distance', ...
    'strong_spec_peak_fraction', ...
    'strong_spec_local_fraction', ...
    'strong_spec_entropy'};

cfg.subaperture_features = { ...
    'subap_q_std_norm', ...
    'subap_q_range_norm', ...
    'subap_consensus_fraction', ...
    'subap_prominence_cv'};

cfg.all_observable_features = [ ...
    cfg.morphology_features, ...
    cfg.strong_competition_features, ...
    cfg.subaperture_features];

cfg.feature_group_names = { ...
    'StateOnly', ...
    'MorphologyOnly', ...
    'StrongCompetitionOnly', ...
    'SubapertureOnly', ...
    'AllObservable', ...
    'StateAll'};

%% Harm veto continuity with C3-B1.3
% C3-B2 reads the selected pH threshold from C3-B1.3 instead of retuning
% a new harm veto. This keeps the experiment focused on Beneficial
% opportunity rather than changing two things at once.
cfg.require_c3b1_3_threshold = true;
cfg.veto_rank_penalty = 100;

%% Lambda boundary sanity check requested after C3-B1.3
cfg.lambda_sanity_grid = (0:0.25:20).';

%% Budget
cfg.budget_grid = unique([ ...
    (0:0.025:0.50), ...
    (0.55:0.05:1.00)]).';

cfg.primary_budget = 0.25;
cfg.report_budgets = [0.10 0.25 0.50];

%% Figures
cfg.figure_visible = 'off';

end
