function cfg = config_exp09c2()
%CONFIG_EXP09C2 Configuration for EXP009-C2.
%
% Benefit-Aware Computation Allocation
%
% C1.1 showed that ~90% of the remaining Practical-vs-Oracle gap is
% allocation loss. C2 therefore changes the target from:
%
%   "Will the cheap branch fail?"
%
% to:
%
%   "Will spending extra computation actually improve the result?"
%
% No signal-level Monte Carlo is rerun. C2 uses C1 branch-level trials.

%% Input
% Leave empty for automatic relative-path discovery.
cfg.c1_result_dir = '';

%% Practical pre-fallback observables
% Only cheap-branch observables are used by the primary models.
cfg.primary_features = { ...
    'cheap_prominence', ...
    'cheap_entropy', ...
    'cheap_second_to_first'};

%% Value model
% Net expected recall gain of fallback:
%
%   V(x) = P(Beneficial|x) - lambda_harm * P(Harmful|x)
%
% Beneficial = cheap fail, fallback success.
% Harmful    = cheap success, fallback fail.
%
% lambda_harm = 1 corresponds exactly to +/-1 change in binary recovery.
cfg.lambda_harm = 1.0;

%% Logistic regularization
cfg.logit_l2 = 0.05;

%% Budget grid for LOCO policy curves
cfg.budget_grid = (0:0.05:1).';

%% Highlighted operating budgets
cfg.report_budgets = [0.10 0.25 0.50];

%% Calibration bins for value-score diagnostics
cfg.num_value_bins = 10;

%% Figures
cfg.figure_visible = 'off';

%% Output
cfg.output_dir = '';

end
