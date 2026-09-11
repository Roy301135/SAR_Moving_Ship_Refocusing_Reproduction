function cfg = config_exp09c1_1()
%CONFIG_EXP09C1_1 Configuration for EXP009-C1.1.
%
% Policy Loss Decomposition
%
% This experiment does NOT rerun signal-level Monte Carlo.
% It reads EXP009-C1 branch-level outputs and decomposes the
% Practical-vs-Oracle gap into:
%
%   1) allocation loss:
%      rescuable trials not triggered by the practical gate;
%
%   2) branch-selection loss:
%      trigger was correct, but the prominence selector failed to use the
%      branch that would have produced the correct q estimate.
%
% It also tests whether:
%
%   practical trigger -> always use fallback
%
% is better than the current prominence-based branch selector.

%% Input
% Leave empty for automatic relative-path discovery.
cfg.c1_result_dir = '';

%% Matched-cost operating point
% 'oracle_rate' means choose the prominence threshold whose fallback rate
% is closest to the Oracle minimal useful trigger rate.
cfg.operating_point = 'oracle_rate';

%% Figures
cfg.figure_visible = 'off';

%% Output
cfg.output_dir = '';

end
