%% exp03_full_vs_ori_search.m
% Xu et al., JSTARS 2025
% "Adaptive Fast Refocusing for Ship Targets With Complex Motion in SAR Images"
%
% Experiment 03:
%   Full FrAc order search vs ORI-constrained FrAc order search.
%
% Purpose:
%   Isolate the computational benefit of the ORI prior while keeping the
%   signal model, FrAc implementation, search step, and evaluated data fixed.
%
% This experiment does NOT yet include adjacent-line tracking. Therefore,
% it measures only parameter-domain pruning from ORI, not the complete
% acceleration of AFRA.
%
% Directory:
%   papers/
%     Xu2025_Adaptive_Fast_Refocusing/
%       code/
%         exp03_full_vs_ori_search/
%           exp03_full_vs_ori_search.m
%         functions/
%           compute_frac_energy_map.m
%           velocity_to_order.m
%       results/
%         exp03_full_vs_ori_search/
%
% Reproducibility:
%   rng(42) is fixed.
%   The synthetic signal model follows EXP02 so the two experiments are
%   directly comparable.
%
% MATLAB R2021b+ recommended. No toolbox required.

clear; clc; close all;

%% 0. Resolve project paths
this_file = mfilename('fullpath');
exp_code_dir = fileparts(this_file);
code_dir = fileparts(exp_code_dir);
paper_dir = fileparts(code_dir);

functions_dir = fullfile(code_dir, 'functions');
result_dir = fullfile(paper_dir, 'results', 'exp03_full_vs_ori_search');

addpath(functions_dir);

if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

%% 1. Reproducibility
rng(42, 'twister');

%% 2. Paper/Table-III target settings
target_names = {'P1','P2','P3','P4','P5'};
p_gt_center = [-0.415, -0.457, -0.500, -0.534, -0.583];
v_true = [-10, -5, 0, 5, 10];

%% 3. Synthetic data: identical mechanism-level setup to EXP02
N_az = 128;
N_range = 60;

target_centers = [10, 20, 30, 40, 50];
target_half_width = 2;

snr_db = 18;
background_level_db = -35;
kappa = 0.50;
intra_target_order_span = 0.008;

n = (-(N_az-1)/2 : (N_az-1)/2).';

X = 10^(background_level_db/20) * ...
    (randn(N_az, N_range) + 1j*randn(N_az, N_range)) / sqrt(2);

true_order_per_cell = nan(1, N_range);
target_id_per_cell = zeros(1, N_range);

for it = 1:numel(target_centers)

    cells = (target_centers(it)-target_half_width) : ...
            (target_centers(it)+target_half_width);

    local_offset = linspace(-intra_target_order_span/2, ...
                             intra_target_order_span/2, ...
                             numel(cells));

    for ic = 1:numel(cells)

        col = cells(ic);
        p_true = p_gt_center(it) + local_offset(ic);

        alpha_true = p_true * pi/2;
        a_norm = kappa * tan(alpha_true);

        b_norm = -0.12 + 0.24*rand;

        amp = exp(-0.5 * ((col-target_centers(it)) / ...
             (target_half_width+0.5))^2);

        s = amp * exp(1j*pi*a_norm*(n.^2)/N_az + ...
                      1j*2*pi*b_norm*n);

        sig_power = mean(abs(s).^2);
        noise_power = sig_power / 10^(snr_db/10);

        noise = sqrt(noise_power/2) * ...
                (randn(N_az,1) + 1j*randn(N_az,1));

        X(:, col) = X(:, col) + s + noise;

        true_order_per_cell(col) = p_true;
        target_id_per_cell(col) = it;
    end
end

active_cells = find(target_id_per_cell > 0);

%% 4. Full-search configuration
search_step = 0.001;
p_full = -0.75 : search_step : -0.30;

%% 5. ORI derived from the paper's velocity-to-order relation
c = 3e8;
fc = 3e9;
lambda = c / fc;

PRF = 300;
Vsar = 200;
H = 10e3;
inc_deg = 45;
R0 = H / cosd(inc_deg);

% Na is not reported by the paper; EXP01 used this calibrated working value.
Na = 1200;

% Use the same +/-10 m/s velocity envelope as the five-target experiment.
v_bound = [-10, 10];

[~, ~, p_bound_model] = velocity_to_order( ...
    v_bound, Vsar, lambda, R0, PRF, Na);

% Small guard margin for modeling error and unknown exact Na.
ori_guard = 0.015;

ori_low = min(p_bound_model) - ori_guard;
ori_high = max(p_bound_model) + ori_guard;

% Snap to the same search grid used by the full search.
ori_low = floor(ori_low/search_step) * search_step;
ori_high = ceil(ori_high/search_step) * search_step;

p_ori = ori_low : search_step : ori_high;

%% 6. Sanity check: does the ORI contain all active-cell ground truths?
gt_min = min(true_order_per_cell(active_cells));
gt_max = max(true_order_per_cell(active_cells));

ori_covers_all_gt = (ori_low <= gt_min) && (ori_high >= gt_max);

if ~ori_covers_all_gt
    warning(['Current ORI does not contain all ground-truth OROs. ' ...
             'This run is intentionally testing an under-covered ORI.']);
end

%% 7. Full FrAc search
fprintf('Computing FULL FrAc search...\n');
tic;
E_full = compute_frac_energy_map(X, p_full, n, kappa, 16);
time_full = toc;

[~, idx_full] = max(E_full, [], 1);
p_est_full = p_full(idx_full);

%% 8. ORI-constrained FrAc search
fprintf('Computing ORI-CONSTRAINED FrAc search...\n');
tic;
E_ori = compute_frac_energy_map(X, p_ori, n, kappa, 16);
time_ori = toc;

[~, idx_ori] = max(E_ori, [], 1);
p_est_ori = p_ori(idx_ori);

%% 9. Accuracy metrics on active target cells
err_full = p_est_full(active_cells) - true_order_per_cell(active_cells);
err_ori = p_est_ori(active_cells) - true_order_per_cell(active_cells);

rmse_full = sqrt(mean(err_full.^2));
rmse_ori = sqrt(mean(err_ori.^2));

mae_full = mean(abs(err_full));
mae_ori = mean(abs(err_ori));

%% 10. Target-level ORO estimates
p_est_target_full = nan(1, numel(target_centers));
p_est_target_ori = nan(1, numel(target_centers));

for it = 1:numel(target_centers)
    cells = find(target_id_per_cell == it);

    p_est_target_full(it) = median(p_est_full(cells));
    p_est_target_ori(it) = median(p_est_ori(cells));
end

T_targets = table( ...
    target_names.', ...
    v_true.', ...
    p_gt_center.', ...
    p_est_target_full.', ...
    p_est_target_ori.', ...
    (p_est_target_full - p_gt_center).', ...
    (p_est_target_ori - p_gt_center).', ...
    'VariableNames', { ...
    'Target', ...
    'TrueVelocity_mps', ...
    'TrueORO', ...
    'FullSearchORO', ...
    'ORISearchORO', ...
    'FullSearchError', ...
    'ORISearchError'});

%% 11. Computational-cost metrics
n_orders_full = numel(p_full);
n_orders_ori = numel(p_ori);

order_reduction_pct = 100 * (1 - n_orders_ori / n_orders_full);

% Both strategies evaluate the same N_range range cells.
frac_evals_full = n_orders_full * N_range;
frac_evals_ori = n_orders_ori * N_range;

eval_reduction_pct = 100 * (1 - frac_evals_ori / frac_evals_full);

runtime_reduction_pct = 100 * (1 - time_ori / time_full);
speedup = time_full / max(time_ori, eps);

T_summary = table( ...
    ["Full"; "ORI"], ...
    [p_full(1); p_ori(1)], ...
    [p_full(end); p_ori(end)], ...
    [n_orders_full; n_orders_ori], ...
    [frac_evals_full; frac_evals_ori], ...
    [time_full; time_ori], ...
    [rmse_full; rmse_ori], ...
    [mae_full; mae_ori], ...
    'VariableNames', { ...
    'Method', ...
    'SearchLowerBound', ...
    'SearchUpperBound', ...
    'NumOrders', ...
    'ApproxFrAcEvaluations', ...
    'Runtime_s', ...
    'ORO_RMSE', ...
    'ORO_MAE'});

disp(' ');
disp('================ EXP03 TARGET RESULTS ================');
disp(T_targets);

disp(' ');
disp('================ EXP03 SUMMARY ================');
disp(T_summary);

fprintf('\n================ EXP03 INTERPRETATION ================\n');
fprintf('Full search interval           = [%.4f, %.4f]\n', ...
    p_full(1), p_full(end));
fprintf('ORI search interval            = [%.4f, %.4f]\n', ...
    p_ori(1), p_ori(end));
fprintf('ORI width                      = %.4f\n', p_ori(end)-p_ori(1));
fprintf('All ground-truth OROs covered = %d\n', ori_covers_all_gt);
fprintf('\n');
fprintf('Full searched orders           = %d\n', n_orders_full);
fprintf('ORI searched orders            = %d\n', n_orders_ori);
fprintf('Order-count reduction          = %.2f %%\n', order_reduction_pct);
fprintf('Approx. FrAc eval reduction    = %.2f %%\n', eval_reduction_pct);
fprintf('\n');
fprintf('Full runtime                   = %.4f s\n', time_full);
fprintf('ORI runtime                    = %.4f s\n', time_ori);
fprintf('Runtime reduction              = %.2f %%\n', runtime_reduction_pct);
fprintf('Measured speedup               = %.2f x\n', speedup);
fprintf('\n');
fprintf('Full ORO RMSE                  = %.6e\n', rmse_full);
fprintf('ORI ORO RMSE                   = %.6e\n', rmse_ori);
fprintf('Full ORO MAE                   = %.6e\n', mae_full);
fprintf('ORI ORO MAE                    = %.6e\n', mae_ori);
fprintf('\n');
fprintf(['Interpretation: this experiment isolates the ORI prior only.\n' ...
         'If ORO accuracy is preserved while the number of searched orders\n' ...
         'drops substantially, the result supports AFRA''s parameter-domain\n' ...
         'pruning mechanism. Larger speedups in the paper additionally rely\n' ...
         'on background removal and adjacent-line reuse/tracking.\n']);

%% 12. Figure 1: search-space comparison
fig1 = figure('Name','exp03 Search-space comparison','Color','w');

plot(p_full, ones(size(p_full)), '.', 'MarkerSize', 8);
hold on;
plot(p_ori, 1.25*ones(size(p_ori)), '.', 'MarkerSize', 8);

for it = 1:numel(p_gt_center)
    xline(p_gt_center(it), '--', 'LineWidth', 0.9);
end

xlabel('Rotation order');
ylabel('Search strategy');
yticks([1, 1.25]);
yticklabels({'Full','ORI'});
title('Full search vs ORI-constrained search space');
grid on;
xlim([p_full(1), p_full(end)]);

%% 13. Figure 2: true vs estimated ORO
fig2 = figure('Name','exp03 ORO estimates','Color','w');

plot(active_cells, true_order_per_cell(active_cells), ...
    'o-', 'LineWidth', 1.1, 'MarkerSize', 5);
hold on;

plot(active_cells, p_est_full(active_cells), ...
    'x--', 'LineWidth', 1.1, 'MarkerSize', 6);

plot(active_cells, p_est_ori(active_cells), ...
    '+-.', 'LineWidth', 1.1, 'MarkerSize', 6);

xlabel('Active range cell');
ylabel('Rotation order');
title('True ORO vs full-search and ORI-search estimates');
legend('True', 'Full search', 'ORI search', 'Location','best');
grid on;

%% 14. Figure 3: cost comparison
fig3 = figure('Name','exp03 FrAc evaluation count','Color','w');

bar([frac_evals_full, frac_evals_ori]);
set(gca, 'XTick', 1:2, 'XTickLabel', {'Full','ORI'});
ylabel('Approximate FrAc evaluations');
title(sprintf('FrAc evaluation reduction = %.1f%%', eval_reduction_pct));
grid on;

%% 15. Figure 4: quality-cost plane
fig4 = figure('Name','exp03 Quality-cost plane','Color','w');

scatter(frac_evals_full, rmse_full, 80, 'o', 'LineWidth', 1.3);
hold on;
scatter(frac_evals_ori, rmse_ori, 80, 'x', 'LineWidth', 1.3);

text(frac_evals_full, rmse_full, '  Full');
text(frac_evals_ori, rmse_ori, '  ORI');

xlabel('Approximate FrAc evaluations');
ylabel('ORO RMSE');
title('Quality-cost plane: full search vs ORI search');
grid on;

%% 16. Save outputs
writetable(T_targets, ...
    fullfile(result_dir, 'exp03_target_results.csv'));

writetable(T_summary, ...
    fullfile(result_dir, 'exp03_summary.csv'));

save(fullfile(result_dir, 'exp03_summary.mat'), ...
    'p_gt_center', 'v_true', ...
    'p_full', 'p_ori', ...
    'ori_low', 'ori_high', 'ori_guard', ...
    'p_bound_model', 'ori_covers_all_gt', ...
    'p_est_full', 'p_est_ori', ...
    'true_order_per_cell', 'target_id_per_cell', ...
    'rmse_full', 'rmse_ori', 'mae_full', 'mae_ori', ...
    'n_orders_full', 'n_orders_ori', ...
    'frac_evals_full', 'frac_evals_ori', ...
    'order_reduction_pct', 'eval_reduction_pct', ...
    'time_full', 'time_ori', ...
    'runtime_reduction_pct', 'speedup', ...
    'snr_db', 'background_level_db', ...
    'N_az', 'N_range', 'kappa', 'search_step');

exportgraphics(fig1, ...
    fullfile(result_dir, 'fig01_search_space_comparison.png'), ...
    'Resolution', 200);

exportgraphics(fig2, ...
    fullfile(result_dir, 'fig02_true_full_ori_estimates.png'), ...
    'Resolution', 200);

exportgraphics(fig3, ...
    fullfile(result_dir, 'fig03_frac_evaluation_count.png'), ...
    'Resolution', 200);

exportgraphics(fig4, ...
    fullfile(result_dir, 'fig04_quality_cost_plane.png'), ...
    'Resolution', 200);

fprintf('\nOutputs saved to:\n%s\n', result_dir);
