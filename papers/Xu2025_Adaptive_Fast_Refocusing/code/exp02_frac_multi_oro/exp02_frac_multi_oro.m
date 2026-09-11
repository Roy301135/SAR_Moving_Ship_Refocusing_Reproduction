%% exp02_frac_multi_oro.m
% Xu et al., JSTARS 2025
% "Adaptive Fast Refocusing for Ship Targets With Complex Motion in SAR Images"
%
% Experiment 02:
%   Mechanism-level reproduction of the FrAc multi-ORO detection behind Fig. 7.
%
% Main question:
%   The five OROs occupy only a narrow interval. Can FrAc still resolve them?
%
% Important:
%   This is NOT an exact pixel-by-pixel reproduction of Fig. 7 because the
%   paper does not provide the original complex simulated SAR data or all
%   discrete implementation details of FrAc.

clear; clc; close all;

%% 0. Resolve project paths
this_file = mfilename('fullpath');
exp_code_dir = fileparts(this_file);
code_dir = fileparts(exp_code_dir);
paper_dir = fileparts(code_dir);

functions_dir = fullfile(code_dir, 'functions');
result_dir = fullfile(paper_dir, 'results', 'exp02_frac_multi_oro');

addpath(functions_dir);
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

%% 1. Reproducibility
rng(42, 'twister');

%% 2. Ground-truth OROs from Table III
target_names = {'P1','P2','P3','P4','P5'};
p_gt_center = [-0.415, -0.457, -0.500, -0.534, -0.583];
v_true = [-10, -5, 0, 5, 10];

%% 3. Synthetic range-cell / azimuth-signal setup
N_az = 128;
N_range = 60;

target_centers = [10, 20, 30, 40, 50];
target_half_width = 2;

snr_db = 18;
background_level_db = -35;

% Normalized chirp-slope scale. The same mapping is used for synthesis and
% scanning, preserving the ORO peak positions while avoiding aliasing.
kappa = 0.50;

intra_target_order_span = 0.008;

n = (-(N_az-1)/2 : (N_az-1)/2).';

%% 4. Build synthetic defocused LFM signals
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

%% 5. FrAc order search
% Deliberately wider than the true five-target interval.
p_search = -0.75 : 0.0025 : -0.30;
max_lag = 16;

fprintf('Computing FrAc energy map...\n');
tic;
E = compute_frac_energy_map(X, p_search, n, kappa, max_lag);
elapsed_s = toc;

E_global = E / (max(E(:)) + eps);
E_column = E ./ (max(E, [], 1) + eps);

%% 6. Estimate ORO of each range cell
[~, idx_peak] = max(E, [], 1);
p_est_per_cell = p_search(idx_peak);

cell_error = p_est_per_cell(active_cells) - ...
             true_order_per_cell(active_cells);

rmse_active = sqrt(mean(cell_error.^2));
mae_active = mean(abs(cell_error));

%% 7. Target-level estimates
p_est_target = nan(1, numel(target_centers));
target_rmse = nan(1, numel(target_centers));

for it = 1:numel(target_centers)
    cells = find(target_id_per_cell == it);

    p_est_target(it) = median(p_est_per_cell(cells));

    target_rmse(it) = sqrt(mean( ...
        (p_est_per_cell(cells) - true_order_per_cell(cells)).^2));
end

T = table( ...
    target_names.', ...
    v_true.', ...
    p_gt_center.', ...
    p_est_target.', ...
    (p_est_target-p_gt_center).', ...
    target_rmse.', ...
    'VariableNames', { ...
    'Target', 'TrueVelocity_mps', 'PaperTableIII_ORO', ...
    'EstimatedORO', 'ORO_Error', 'WithinTarget_RMSE'});

disp(' ');
disp('================ EXP02 TARGET RESULTS ================');
disp(T);

fprintf('\n================ EXP02 INTERPRETATION ================\n');
fprintf('Search interval                = [%.4f, %.4f]\n', ...
    p_search(1), p_search(end));
fprintf('Search step                    = %.4f\n', p_search(2)-p_search(1));
fprintf('Paper five-target ORO span     = %.6f\n', ...
    max(p_gt_center)-min(p_gt_center));
fprintf('Active-cell ORO RMSE           = %.6e\n', rmse_active);
fprintf('Active-cell ORO MAE            = %.6e\n', mae_active);
fprintf('FrAc computation time          = %.3f s\n', elapsed_s);
fprintf('Number of searched orders      = %d\n', numel(p_search));
fprintf('Number of active range cells   = %d\n', numel(active_cells));
fprintf('\n');
fprintf(['Interpretation: the five target OROs occupy a narrow interval,\n' ...
         'yet their FrAc energy maxima remain individually resolvable.\n']);

%% 8. Figure 1: synthetic signals
fig1 = figure('Name','exp02 Synthetic signals','Color','w');
imagesc(1:N_range, 1:N_az, abs(X));
axis xy;
xlabel('Range cell');
ylabel('Azimuth sample');
title('Synthetic LFM signals for five moving point targets');
colorbar;

%% 9. Figure 2: Fig. 7-like FrAc energy map
fig2 = figure('Name','exp02 FrAc energy map','Color','w');

imagesc(1:N_range, p_search, 10*log10(E_global + 1e-12));
axis xy;
xlabel('Scattering-point range cells');
ylabel('Rotation order');
title('FrAc energy map: five OROs in a narrow interval');
colorbar;
caxis([-35 0]);
hold on;

plot(target_centers, p_gt_center, 'wo', ...
    'MarkerSize', 7, 'LineWidth', 1.2);

%% 10. Figure 3: representative FrAc spectra
fig3 = figure('Name','exp02 FrAc spectra','Color','w');
hold on;

for it = 1:numel(target_centers)
    col = target_centers(it);
    spectrum = E_column(:, col);
    plot(p_search, spectrum, 'LineWidth', 1.2);
end

for it = 1:numel(p_gt_center)
    xline(p_gt_center(it), '--', 'LineWidth', 0.8);
end

xlabel('Rotation order');
ylabel('Normalized FrAc energy');
title('Representative FrAc order spectra of P1-P5');
legend(target_names, 'Location','best');
grid on;
xlim([min(p_search), max(p_search)]);

%% 11. Figure 4: true vs estimated ORO
fig4 = figure('Name','exp02 ORO estimation','Color','w');

plot(active_cells, true_order_per_cell(active_cells), 'o-', ...
    'LineWidth', 1.1, 'MarkerSize', 5);
hold on;

plot(active_cells, p_est_per_cell(active_cells), 'x--', ...
    'LineWidth', 1.1, 'MarkerSize', 6);

xlabel('Active range cell');
ylabel('Rotation order');
title(sprintf('True vs estimated ORO, RMSE = %.4g', rmse_active));
legend('True ORO','Estimated ORO','Location','best');
grid on;

%% 12. Save outputs
writetable(T, fullfile(result_dir, 'exp02_summary.csv'));

save(fullfile(result_dir, 'exp02_summary.mat'), ...
    'p_gt_center', 'v_true', 'p_search', ...
    'E', 'E_global', 'E_column', ...
    'p_est_per_cell', 'true_order_per_cell', 'target_id_per_cell', ...
    'rmse_active', 'mae_active', 'elapsed_s', ...
    'snr_db', 'background_level_db', 'kappa', 'max_lag', ...
    'N_az', 'N_range');

exportgraphics(fig1, ...
    fullfile(result_dir, 'fig01_synthetic_signals.png'), ...
    'Resolution', 200);

exportgraphics(fig2, ...
    fullfile(result_dir, 'fig02_frac_energy_map.png'), ...
    'Resolution', 200);

exportgraphics(fig3, ...
    fullfile(result_dir, 'fig03_frac_spectra.png'), ...
    'Resolution', 200);

exportgraphics(fig4, ...
    fullfile(result_dir, 'fig04_true_vs_estimated_oro.png'), ...
    'Resolution', 200);

fprintf('\nOutputs saved to:\n%s\n', result_dir);
