%% exp04_adjacent_line_tracking.m
% Xu et al., JSTARS 2025
% "Adaptive Fast Refocusing for Ship Targets With Complex Motion in SAR Images"
%
% Experiment 04:
%   Reproduce the adjacent-line ORO prior / sequential tracking mechanism.
%
% Main questions:
%   1) Can the dominant ORO of the strongest line initialize neighboring
%      lines so that full-order search is avoided for most lines?
%   2) How does tracking-window half width Delta affect cost and ORO error?
%   3) Does a smaller Delta save more FrAc evaluations at the price of
%      higher sensitivity to line-to-line ORO variation?
%
% This experiment isolates adjacent-line reuse. It does NOT yet implement
% multi-component CLEAN refocusing. A later stress-test experiment should
% add abrupt ORO jumps, weak components, and stronger clutter.
%
% Directory:
%   papers/
%     Xu2025_Adaptive_Fast_Refocusing/
%       code/
%         exp04_adjacent_line_tracking/
%           exp04_adjacent_line_tracking.m
%         functions/
%           compute_frac_energy_map.m
%           track_oro_adjacent_lines.m
%       results/
%         exp04_adjacent_line_tracking/
%
% MATLAB R2021b+ recommended. No toolbox required.

clear; clc; close all;

%% 0. Resolve project paths
this_file = mfilename('fullpath');
exp_code_dir = fileparts(this_file);
code_dir = fileparts(exp_code_dir);
paper_dir = fileparts(code_dir);

functions_dir = fullfile(code_dir, 'functions');
result_dir = fullfile(paper_dir, 'results', 'exp04_adjacent_line_tracking');

addpath(functions_dir);

if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

%% 1. Reproducibility
rng(42, 'twister');

%% 2. Synthetic ship-like sequence
% Each column is an azimuth signal from one neighboring spatial/range cell.
N_az = 128;
N_line = 81;

n = (-(N_az-1)/2 : (N_az-1)/2).';
line_idx = 1:N_line;

% Smooth dominant-ORO field:
% deliberately not aligned with the search grid, so RMSE is meaningful.
x = linspace(-1, 1, N_line);
p_true = -0.5037 ...
       + 0.050 * sin(0.85*pi*x) ...
       + 0.016 * x;

% Ship-like line-energy envelope:
% strongest around the center, weaker toward both ends.
amp = 0.18 + 0.82 * exp(-(x/0.52).^2);

% FrAc/LFM controls
kappa = 0.50;
snr_center_db = 20;
background_level_db = -35;

% Constant noise power referenced to the strongest line.
% Therefore weak edge lines naturally have lower effective SNR.
noise_power = 1 / 10^(snr_center_db/10);

X = 10^(background_level_db/20) * ...
    (randn(N_az, N_line) + 1j*randn(N_az, N_line)) / sqrt(2);

for iline = 1:N_line

    alpha_true = p_true(iline) * pi/2;
    a_norm = kappa * tan(alpha_true);

    % Slowly varying center frequency, independent of ORO.
    b_norm = -0.05 + 0.035*sin(1.2*pi*x(iline));

    s = amp(iline) * ...
        exp(1j*pi*a_norm*(n.^2)/N_az + 1j*2*pi*b_norm*n);

    noise = sqrt(noise_power/2) * ...
        (randn(N_az,1) + 1j*randn(N_az,1));

    X(:,iline) = X(:,iline) + s + noise;
end

%% 3. Strongest-line initialization
line_energy = sum(abs(X).^2, 1);
[~, init_idx] = max(line_energy);

%% 4. Full independent search baseline
search_step = 0.0025;
p_full = -0.75 : search_step : -0.30;
max_lag = 16;

fprintf('Computing independent FULL search baseline...\n');
tic;
E_full = compute_frac_energy_map(X, p_full, n, kappa, max_lag);
time_full = toc;

[~, idx_full] = max(E_full, [], 1);
p_est_full = p_full(idx_full);

eval_full = numel(p_full) * N_line;
rmse_full = sqrt(mean((p_est_full - p_true).^2));
mae_full = mean(abs(p_est_full - p_true));

%% 5. Tracking-window sweep
delta_list = [0.005, 0.010, 0.020, 0.040, 0.080];

n_delta = numel(delta_list);

rmse_track = zeros(1, n_delta);
mae_track = zeros(1, n_delta);
eval_track = zeros(1, n_delta);
time_track = zeros(1, n_delta);
reduction_track = zeros(1, n_delta);
speedup_track = zeros(1, n_delta);
boundary_rate = zeros(1, n_delta);

p_est_all = cell(1, n_delta);
boundary_all = cell(1, n_delta);

for id = 1:n_delta

    delta = delta_list(id);

    fprintf('Tracking with Delta = %.4f...\n', delta);

    tic;
    [p_est, eval_count, boundary_hit] = ...
        track_oro_adjacent_lines( ...
        X, p_full, search_step, delta, ...
        n, kappa, max_lag, init_idx);
    time_track(id) = toc;

    p_est_all{id} = p_est;
    boundary_all{id} = boundary_hit;

    rmse_track(id) = sqrt(mean((p_est - p_true).^2));
    mae_track(id) = mean(abs(p_est - p_true));

    eval_track(id) = eval_count;
    reduction_track(id) = 100 * (1 - eval_count/eval_full);
    speedup_track(id) = time_full / max(time_track(id), eps);
    boundary_rate(id) = 100 * mean(boundary_hit);
end

%% 6. Choose one representative Delta for detailed visualization
% Delta = 0.02 is wide enough for the present smooth sequence while still
% yielding substantial reduction in local order evaluations.
delta_show = 0.020;
[~, show_id] = min(abs(delta_list - delta_show));

p_est_show = p_est_all{show_id};
boundary_show = boundary_all{show_id};

%% 7. Summary tables
T = table( ...
    delta_list.', ...
    eval_track.', ...
    reduction_track.', ...
    time_track.', ...
    speedup_track.', ...
    rmse_track.', ...
    mae_track.', ...
    boundary_rate.', ...
    'VariableNames', { ...
    'Delta', ...
    'FrAcEvaluations', ...
    'EvaluationReduction_pct', ...
    'Runtime_s', ...
    'Speedup_x', ...
    'ORO_RMSE', ...
    'ORO_MAE', ...
    'BoundaryHitRate_pct'});

T_baseline = table( ...
    eval_full, time_full, rmse_full, mae_full, init_idx, ...
    'VariableNames', { ...
    'FrAcEvaluations', 'Runtime_s', 'ORO_RMSE', ...
    'ORO_MAE', 'StrongestLineIndex'});

disp(' ');
disp('================ EXP04 FULL-SEARCH BASELINE ================');
disp(T_baseline);

disp(' ');
disp('================ EXP04 TRACKING SWEEP ================');
disp(T);

fprintf('\n================ EXP04 INTERPRETATION ================\n');
fprintf('Strongest / initialization line = %d of %d\n', init_idx, N_line);
fprintf('Full search orders per line      = %d\n', numel(p_full));
fprintf('Full-search evaluations          = %d\n', eval_full);
fprintf('Full-search ORO RMSE             = %.6e\n', rmse_full);
fprintf('\n');

for id = 1:n_delta
    fprintf(['Delta = %.4f | eval reduction = %6.2f %% | ' ...
             'speedup = %5.2f x | RMSE = %.6e | ' ...
             'boundary hit = %5.2f %%\n'], ...
        delta_list(id), ...
        reduction_track(id), ...
        speedup_track(id), ...
        rmse_track(id), ...
        boundary_rate(id));
end

fprintf('\n');
fprintf(['Interpretation: AFRA-style adjacent-line reuse replaces repeated\n' ...
         'global searches by local searches centered on the previous line''s\n' ...
         'dominant ORO. Delta controls the cost-robustness trade-off.\n']);

%% 8. Figure 1: line energy and initialization point
fig1 = figure('Name','exp04 Line energy','Color','w');

plot(line_idx, line_energy, 'LineWidth', 1.2);
hold on;
plot(init_idx, line_energy(init_idx), 'o', ...
    'MarkerSize', 8, 'LineWidth', 1.3);

xlabel('Neighboring spatial / range cell');
ylabel('Line energy');
title('Strongest line used to initialize ORO tracking');
grid on;

%% 9. Figure 2: detailed ORO tracking
fig2 = figure('Name','exp04 Tracking example','Color','w');

plot(line_idx, p_true, 'LineWidth', 1.5);
hold on;
plot(line_idx, p_est_full, '--', 'LineWidth', 1.1);
plot(line_idx, p_est_show, '-.', 'LineWidth', 1.1);
plot(init_idx, p_est_show(init_idx), 'o', ...
    'MarkerSize', 8, 'LineWidth', 1.2);

bh = find(boundary_show);
if ~isempty(bh)
    plot(bh, p_est_show(bh), 'x', ...
        'MarkerSize', 7, 'LineWidth', 1.2);
end

xlabel('Neighboring spatial / range cell');
ylabel('Dominant ORO');
title(sprintf('Adjacent-line ORO tracking, Delta = %.3f', delta_show));

if isempty(bh)
    legend('True ORO','Full search','Tracking','Initialization', ...
        'Location','best');
else
    legend('True ORO','Full search','Tracking','Initialization', ...
        'Boundary hit','Location','best');
end

grid on;

%% 10. Figure 3: RMSE vs Delta
fig3 = figure('Name','exp04 RMSE vs Delta','Color','w');

plot(delta_list, rmse_track, 'o-', 'LineWidth', 1.2);
hold on;
yline(rmse_full, '--', 'Full-search RMSE', 'LineWidth', 1.0);

xlabel('Tracking-window half width \Delta');
ylabel('ORO RMSE');
title('Tracking accuracy vs local search-window width');
grid on;

%% 11. Figure 4: evaluations vs Delta
fig4 = figure('Name','exp04 Cost vs Delta','Color','w');

plot(delta_list, eval_track, 'o-', 'LineWidth', 1.2);
hold on;
yline(eval_full, '--', 'Full-search cost', 'LineWidth', 1.0);

xlabel('Tracking-window half width \Delta');
ylabel('FrAc candidate-order evaluations');
title('Tracking cost vs local search-window width');
grid on;

%% 12. Figure 5: quality-cost plane
fig5 = figure('Name','exp04 Quality-cost plane','Color','w');

scatter(eval_track, rmse_track, 70, 'o', 'LineWidth', 1.2);
hold on;
scatter(eval_full, rmse_full, 90, 'x', 'LineWidth', 1.4);

for id = 1:n_delta
    text(eval_track(id), rmse_track(id), ...
        sprintf('  \\Delta=%.3f', delta_list(id)));
end

text(eval_full, rmse_full, '  Full');

xlabel('FrAc candidate-order evaluations');
ylabel('ORO RMSE');
title('Quality-cost plane for adjacent-line ORO tracking');
grid on;

%% 13. Figure 6: error vs line energy for representative Delta
fig6 = figure('Name','exp04 Error vs line energy','Color','w');

oro_abs_error = abs(p_est_show - p_true);

scatter(line_energy, oro_abs_error, 45, 'o', 'LineWidth', 1.0);

xlabel('Line energy');
ylabel('|ORO estimation error|');
title(sprintf('Weak-line sensitivity, Delta = %.3f', delta_show));
grid on;

%% 14. Save outputs
writetable(T_baseline, ...
    fullfile(result_dir, 'exp04_baseline_summary.csv'));

writetable(T, ...
    fullfile(result_dir, 'exp04_tracking_sweep.csv'));

save(fullfile(result_dir, 'exp04_summary.mat'), ...
    'p_true', 'p_est_full', 'p_est_all', ...
    'line_energy', 'init_idx', ...
    'delta_list', 'delta_show', ...
    'eval_full', 'eval_track', ...
    'reduction_track', ...
    'time_full', 'time_track', ...
    'speedup_track', ...
    'rmse_full', 'rmse_track', ...
    'mae_full', 'mae_track', ...
    'boundary_rate', 'boundary_all', ...
    'search_step', 'p_full', ...
    'snr_center_db', 'N_az', 'N_line', ...
    'kappa', 'max_lag');

exportgraphics(fig1, ...
    fullfile(result_dir, 'fig01_line_energy_initialization.png'), ...
    'Resolution', 200);

exportgraphics(fig2, ...
    fullfile(result_dir, 'fig02_adjacent_line_tracking.png'), ...
    'Resolution', 200);

exportgraphics(fig3, ...
    fullfile(result_dir, 'fig03_rmse_vs_delta.png'), ...
    'Resolution', 200);

exportgraphics(fig4, ...
    fullfile(result_dir, 'fig04_evaluations_vs_delta.png'), ...
    'Resolution', 200);

exportgraphics(fig5, ...
    fullfile(result_dir, 'fig05_quality_cost_plane.png'), ...
    'Resolution', 200);

exportgraphics(fig6, ...
    fullfile(result_dir, 'fig06_error_vs_line_energy.png'), ...
    'Resolution', 200);

fprintf('\nOutputs saved to:\n%s\n', result_dir);
