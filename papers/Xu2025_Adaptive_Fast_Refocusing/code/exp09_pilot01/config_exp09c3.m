function cfg = config_exp09c3()
%CONFIG_EXP09C3 Configuration for EXP009-C3.
%
% History-Aware Adaptive Computation
%
% C2.2 showed that the strongest instantaneous practical observables
% mostly reveal the underlying risk STATE rather than the fate of a single
% realization. C3 therefore asks whether causal temporal/spatial history
% can estimate that persistent state more reliably than one-shot scores.
%
% IMPORTANT:
% This first C3 is a sequence-level bootstrap proof-of-concept using the
% already validated C1/C2.1 trial bank. It does NOT yet claim continuous
% physical SAR motion. A later C3-B should return to signal-level
% continuously varying azimuth states if this experiment passes.

%% Inputs
cfg.c2_1_result_dir = '';
cfg.c1_result_dir = '';
cfg.c2_2_result_dir = '';

%% Reproducibility
cfg.seed = 20260909;

%% Train/test trial-pool split
% odd trial IDs -> train pool, even trial IDs -> test pool
cfg.train_trial_parity = 1;

%% Synthetic sequential bootstrap
cfg.sequence_length = 300;
cfg.num_train_sequences_per_regime = 40;
cfg.num_test_sequences_per_regime = 100;

% Smooth latent-state Markov dynamics in utility-ranked state space.
cfg.p_stay = 0.90;

% Abrupt regime: inject occasional far-state jumps.
cfg.p_jump = 0.04;
cfg.min_jump_rank_distance = 3;

%% Instantaneous practical risk
% Primary C3 score deliberately stays simple:
%   low prominence -> high risk
%   high entropy   -> high risk
cfg.instant_features = {'cheap_prominence','cheap_entropy'};

%% EMA history
cfg.alpha_grid = [0.05 0.10 0.15 0.20 0.30 0.40 0.60 0.80 1.00];

% Innovation-reset quantile grid. Threshold is estimated from TRAINING
% innovation magnitudes only.
cfg.reset_quantile_grid = [0.80 0.85 0.90 0.95 0.975];

% Tune history hyperparameters on TRAIN sequences at this budget.
cfg.tune_budget = 0.25;

%% Evaluation budget grid
cfg.budget_grid = (0:0.05:1).';
cfg.report_budgets = [0.10 0.25 0.50];

%% Figures
cfg.figure_visible = 'off';

%% Output
cfg.output_dir = '';

end
