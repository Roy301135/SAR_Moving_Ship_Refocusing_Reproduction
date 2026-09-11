function cfg = config_exp09c2_2()
%CONFIG_EXP09C2_2 Configuration for EXP009-C2.2.
%
% State-vs-Realization Predictability Decomposition
%
% C2.1 showed that simple strong-stage mechanism observables do not
% outperform the weak-response prominence/entropy baselines in LOCO
% allocation. C2.2 asks a more fundamental question:
%
%   Is fallback value mainly predictable at the PARAMETER-STATE / CELL
%   level rather than at the SINGLE-REALIZATION level?
%
% No signal-level Monte Carlo is rerun.

%% Input folders
% Leave empty for automatic relative-path discovery.
cfg.c2_1_result_dir = '';
cfg.c1_result_dir = '';

%% Value definition
% Beneficial = +1
% Harmful    = -lambda_harm
cfg.lambda_harm = 1.0;

%% Budget grid
cfg.budget_grid = (0:0.01:1).';
cfg.report_budgets = [0.10 0.25 0.50];

%% Single-realization features to audit
cfg.features = { ...
    'cheap_prominence', ...
    'cheap_entropy', ...
    'cheap_second_to_first', ...
    'estimated_strong_weak_peak_ratio_db', ...
    'estimated_q_separation_abs', ...
    'strong_global_removed_fraction', ...
    'strong_local_asymmetry', ...
    'strong_local_spectral_width', ...
    'strong_notch_capture_fraction', ...
    'strong_frac_bin_offset_abs', ...
    'strong_peak_concentration', ...
    'strong_side_leakage_to_notch'};

%% Figures
cfg.figure_visible = 'off';

%% Output
cfg.output_dir = '';

end
