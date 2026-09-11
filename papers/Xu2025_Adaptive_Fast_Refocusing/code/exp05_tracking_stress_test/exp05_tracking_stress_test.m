%% exp05_tracking_stress_test.m
% Xu et al., JSTARS 2025
% "Adaptive Fast Refocusing for Ship Targets With Complex Motion in SAR Images"
%
% Experiment 05:
%   Stress-test the AFRA-style adjacent-line ORO tracking mechanism.
%
% Motivation from EXP04:
%   Under a smooth ORO field, all tested Delta values produced essentially
%   the same ORO RMSE. Therefore EXP04 verified the efficiency of adjacent-
%   line reuse, but it did NOT yet expose the robustness-cost trade-off.
%
% EXP05 deliberately introduces:
%   1) an abrupt ORO jump;
%   2) a low-energy region around the jump;
%   3) noise;
% and sweeps both jump amplitude and tracking-window half width Delta.
%
% Main questions:
%   - When does the true next-line ORO leave the local tracking window?
%   - How large is the resulting estimation error?
%   - Does the error propagate for several neighboring lines?
%   - How does larger Delta trade computation for robustness?
%
% Directory:
%   papers/
%     Xu2025_Adaptive_Fast_Refocusing/
%       code/
%         exp05_tracking_stress_test/
%           exp05_tracking_stress_test.m
%         functions/
%           compute_frac_energy_map.m
%           track_oro_adjacent_lines.m
%       results/
%         exp05_tracking_stress_test/
%
% MATLAB R2021b+ recommended. No toolbox required.

clear; clc; close all;

%% 0. Resolve project paths
this_file = mfilename('fullpath');
exp_code_dir = fileparts(this_file);
code_dir = fileparts(exp_code_dir);
paper_dir = fileparts(code_dir);

functions_dir = fullfile(code_dir, 'functions');
result_dir = fullfile(paper_dir, 'results', 'exp05_tracking_stress_test');

addpath(functions_dir);

if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

%% 1. Global reproducibility / signal setup
rng(42, 'twister');

N_az = 128;
N_line = 81;
n = (-(N_az-1)/2 : (N_az-1)/2).';
line_idx = 1:N_line;
x = linspace(-1, 1, N_line);

kappa = 0.50;
max_lag = 16;

search_step = 0.0025;
p_full = -0.75 : search_step : -0.30;

% Smooth baseline ORO field.
p_base = -0.5037 ...
       + 0.045 * sin(0.85*pi*x) ...
       + 0.014 * x;

% Ship-like line-energy envelope.
amp_base = 0.20 + 0.80 * exp(-(x/0.52).^2);

% Abrupt change location is placed to the right of the strongest line so
% tracking propagates from the strong center toward the discontinuity.
jump_idx = 61;

% Deliberately weaken lines around the jump.
weak_half_width = 2;
weak_factor = 0.28;

% Noise is referenced to the strongest line.
snr_center_db = 15;
noise_power = 1 / 10^(snr_center_db/10);

background_level_db = -35;

%% 2. Sweep parameters
delta_list = [0.005, 0.010, 0.020, 0.040, 0.080];
jump_list  = [0.000, 0.010, 0.020, 0.040, 0.060];

n_delta = numel(delta_list);
n_jump = numel(jump_list);

rmse_map = zeros(n_jump, n_delta);
mae_map = zeros(n_jump, n_delta);
maxerr_map = zeros(n_jump, n_delta);
boundary_map = zeros(n_jump, n_delta);
eval_map = zeros(n_jump, n_delta);
reduction_map = zeros(n_jump, n_delta);
recovery_map = nan(n_jump, n_delta);

% Store representative cases for plotting.
example_success = struct();
example_failure = struct();

%% 3. Full-search evaluation count baseline
eval_full = numel(p_full) * N_line;

fprintf('============================================================\n');
fprintf('EXP05 TRACKING STRESS TEST\n');
fprintf('N_line = %d, search step = %.4f\n', N_line, search_step);
fprintf('Jump location = line %d\n', jump_idx);
fprintf('Weak-region factor = %.2f\n', weak_factor);
fprintf('Center-line SNR = %.1f dB\n', snr_center_db);
fprintf('============================================================\n\n');

%% 4. Jump-amplitude x Delta sweep
for ij = 1:n_jump

    jump_amp = jump_list(ij);

    % Positive step after jump_idx.
    p_true = p_base;
    p_true(jump_idx:end) = p_true(jump_idx:end) + jump_amp;

    % Line amplitude with a local weak-energy notch around the jump.
    amp = amp_base;
    weak_cells = max(1,jump_idx-weak_half_width) : ...
                 min(N_line,jump_idx+weak_half_width);
    amp(weak_cells) = amp(weak_cells) * weak_factor;

    % Generate one deterministic dataset per jump amplitude.
    % Reset RNG so Delta comparisons use EXACTLY the same signal realization.
    rng(1000 + ij, 'twister');

    X = 10^(background_level_db/20) * ...
        (randn(N_az,N_line) + 1j*randn(N_az,N_line)) / sqrt(2);

    for iline = 1:N_line

        alpha_true = p_true(iline) * pi/2;
        a_norm = kappa * tan(alpha_true);

        b_norm = -0.05 + 0.035*sin(1.2*pi*x(iline));

        s = amp(iline) * ...
            exp(1j*pi*a_norm*(n.^2)/N_az + 1j*2*pi*b_norm*n);

        noise = sqrt(noise_power/2) * ...
            (randn(N_az,1) + 1j*randn(N_az,1));

        X(:,iline) = X(:,iline) + s + noise;
    end

    line_energy = sum(abs(X).^2, 1);
    [~, init_idx] = max(line_energy);

    % Full independent search for reference.
    E_full = compute_frac_energy_map(X, p_full, n, kappa, max_lag);
    [~, idx_full] = max(E_full, [], 1);
    p_est_full = p_full(idx_full);

    for id = 1:n_delta

        delta = delta_list(id);

        [p_est, eval_count, boundary_hit] = ...
            track_oro_adjacent_lines( ...
            X, p_full, search_step, delta, ...
            n, kappa, max_lag, init_idx);

        err = p_est - p_true;

        rmse_map(ij,id) = sqrt(mean(err.^2));
        mae_map(ij,id) = mean(abs(err));
        maxerr_map(ij,id) = max(abs(err));

        boundary_map(ij,id) = 100 * mean(boundary_hit);
        eval_map(ij,id) = eval_count;
        reduction_map(ij,id) = 100 * (1 - eval_count/eval_full);

        recovery_map(ij,id) = estimate_recovery_length( ...
            p_est, p_true, jump_idx, search_step);

        % Representative "safe" case.
        if abs(jump_amp-0.020) < 1e-12 && abs(delta-0.040) < 1e-12
            example_success.p_true = p_true;
            example_success.p_est = p_est;
            example_success.p_full = p_est_full;
            example_success.line_energy = line_energy;
            example_success.init_idx = init_idx;
            example_success.jump_amp = jump_amp;
            example_success.delta = delta;
            example_success.boundary_hit = boundary_hit;
        end

        % Representative "failure / recovery" case.
        if abs(jump_amp-0.060) < 1e-12 && abs(delta-0.010) < 1e-12
            example_failure.p_true = p_true;
            example_failure.p_est = p_est;
            example_failure.p_full = p_est_full;
            example_failure.line_energy = line_energy;
            example_failure.init_idx = init_idx;
            example_failure.jump_amp = jump_amp;
            example_failure.delta = delta;
            example_failure.boundary_hit = boundary_hit;
        end
    end
end

%% 5. Tabular summary
rows = n_jump * n_delta;

JumpAmplitude = zeros(rows,1);
Delta = zeros(rows,1);
ORO_RMSE = zeros(rows,1);
ORO_MAE = zeros(rows,1);
MaxAbsError = zeros(rows,1);
BoundaryHitRate_pct = zeros(rows,1);
FrAcEvaluations = zeros(rows,1);
EvaluationReduction_pct = zeros(rows,1);
RecoveryLength_lines = zeros(rows,1);

ir = 0;

for ij = 1:n_jump
    for id = 1:n_delta
        ir = ir + 1;

        JumpAmplitude(ir) = jump_list(ij);
        Delta(ir) = delta_list(id);

        ORO_RMSE(ir) = rmse_map(ij,id);
        ORO_MAE(ir) = mae_map(ij,id);
        MaxAbsError(ir) = maxerr_map(ij,id);

        BoundaryHitRate_pct(ir) = boundary_map(ij,id);
        FrAcEvaluations(ir) = eval_map(ij,id);
        EvaluationReduction_pct(ir) = reduction_map(ij,id);
        RecoveryLength_lines(ir) = recovery_map(ij,id);
    end
end

T = table( ...
    JumpAmplitude, Delta, ...
    ORO_RMSE, ORO_MAE, MaxAbsError, ...
    BoundaryHitRate_pct, ...
    FrAcEvaluations, EvaluationReduction_pct, ...
    RecoveryLength_lines);

disp(' ');
disp('================ EXP05 STRESS-TEST SUMMARY ================');
disp(T);

fprintf('\n================ EXP05 KEY INTERPRETATION ================\n');
fprintf('Full-search evaluations = %d\n', eval_full);
fprintf('\n');

for ij = 1:n_jump
    fprintf('Jump amplitude = %.3f\n', jump_list(ij));

    for id = 1:n_delta
        fprintf(['  Delta=%.3f | RMSE=%8.5f | MaxErr=%8.5f | ' ...
                 'Boundary=%6.2f%% | EvalRed=%6.2f%% | Recovery=%g lines\n'], ...
            delta_list(id), ...
            rmse_map(ij,id), ...
            maxerr_map(ij,id), ...
            boundary_map(ij,id), ...
            reduction_map(ij,id), ...
            recovery_map(ij,id));
    end
end

fprintf('\n');
fprintf(['Expected interpretation:\n' ...
         '  When jump amplitude is comfortably smaller than Delta, tracking\n' ...
         '  should remain close to full search. When the jump exceeds the\n' ...
         '  local window, the estimator tends to hit a window boundary and\n' ...
         '  may need several lines to recover, exposing error propagation.\n']);

%% 6. Figure 1: ground-truth ORO fields for different jump amplitudes
fig1 = figure('Name','exp05 True ORO fields','Color','w');

hold on;
for ij = 1:n_jump
    p_show = p_base;
    p_show(jump_idx:end) = p_show(jump_idx:end) + jump_list(ij);

    plot(line_idx, p_show, 'LineWidth', 1.2);
end

xline(jump_idx, '--', 'Jump location', 'LineWidth', 1.0);

xlabel('Neighboring spatial / range cell');
ylabel('True dominant ORO');
title('Stress-test ORO fields with abrupt line-to-line changes');

legend(arrayfun(@(v) sprintf('Jump=%.3f',v), ...
    jump_list, 'UniformOutput', false), ...
    'Location','best');

grid on;

%% 7. Figure 2: RMSE heat map
fig2 = figure('Name','exp05 RMSE heatmap','Color','w');

imagesc(delta_list, jump_list, rmse_map);
axis xy;
xlabel('Tracking-window half width \Delta');
ylabel('Abrupt ORO jump amplitude');
title('Tracking ORO RMSE under discontinuities');
colorbar;

%% 8. Figure 3: maximum-error heat map
fig3 = figure('Name','exp05 Max error heatmap','Color','w');

imagesc(delta_list, jump_list, maxerr_map);
axis xy;
xlabel('Tracking-window half width \Delta');
ylabel('Abrupt ORO jump amplitude');
title('Maximum absolute ORO error');
colorbar;

%% 9. Figure 4: boundary-hit heat map
fig4 = figure('Name','exp05 Boundary-hit heatmap','Color','w');

imagesc(delta_list, jump_list, boundary_map);
axis xy;
xlabel('Tracking-window half width \Delta');
ylabel('Abrupt ORO jump amplitude');
title('Local-search boundary-hit rate (%)');
colorbar;

%% 10. Figure 5: representative successful case
fig5 = figure('Name','exp05 Success example','Color','w');

plot(line_idx, example_success.p_true, 'LineWidth', 1.5);
hold on;
plot(line_idx, example_success.p_full, '--', 'LineWidth', 1.0);
plot(line_idx, example_success.p_est, '-.', 'LineWidth', 1.2);

xline(jump_idx, '--', 'Jump', 'LineWidth', 1.0);

bh = find(example_success.boundary_hit);
if ~isempty(bh)
    plot(bh, example_success.p_est(bh), 'x', ...
        'MarkerSize', 7, 'LineWidth', 1.2);
end

xlabel('Neighboring spatial / range cell');
ylabel('Dominant ORO');
title(sprintf('Robust tracking example: jump=%.3f, \\Delta=%.3f', ...
    example_success.jump_amp, example_success.delta));

legend('True','Full search','Tracking','Location','best');
grid on;

%% 11. Figure 6: representative failure/recovery case
fig6 = figure('Name','exp05 Failure example','Color','w');

plot(line_idx, example_failure.p_true, 'LineWidth', 1.5);
hold on;
plot(line_idx, example_failure.p_full, '--', 'LineWidth', 1.0);
plot(line_idx, example_failure.p_est, '-.', 'LineWidth', 1.2);

xline(jump_idx, '--', 'Jump', 'LineWidth', 1.0);

bh = find(example_failure.boundary_hit);
if ~isempty(bh)
    plot(bh, example_failure.p_est(bh), 'x', ...
        'MarkerSize', 7, 'LineWidth', 1.2);
end

xlabel('Neighboring spatial / range cell');
ylabel('Dominant ORO');
title(sprintf('Tracking failure/recovery: jump=%.3f, \\Delta=%.3f', ...
    example_failure.jump_amp, example_failure.delta));

if isempty(bh)
    legend('True','Full search','Tracking','Location','best');
else
    legend('True','Full search','Tracking','Jump','Boundary hit', ...
        'Location','best');
end

grid on;

%% 12. Figure 7: cost-robustness curves for each jump amplitude
fig7 = figure('Name','exp05 Quality-cost curves','Color','w');

hold on;

for ij = 1:n_jump
    plot(eval_map(ij,:), rmse_map(ij,:), 'o-', ...
        'LineWidth', 1.1);
end

xlabel('FrAc candidate-order evaluations');
ylabel('ORO RMSE');
title('Cost-robustness trade-off under abrupt ORO changes');

legend(arrayfun(@(v) sprintf('Jump=%.3f',v), ...
    jump_list, 'UniformOutput', false), ...
    'Location','best');

grid on;

%% 13. Save outputs
writetable(T, ...
    fullfile(result_dir, 'exp05_stress_test_summary.csv'));

save(fullfile(result_dir, 'exp05_summary.mat'), ...
    'delta_list', 'jump_list', ...
    'rmse_map', 'mae_map', 'maxerr_map', ...
    'boundary_map', 'eval_map', 'reduction_map', ...
    'recovery_map', ...
    'p_base', 'jump_idx', ...
    'weak_half_width', 'weak_factor', ...
    'snr_center_db', ...
    'search_step', 'p_full', 'eval_full', ...
    'example_success', 'example_failure');

exportgraphics(fig1, ...
    fullfile(result_dir, 'fig01_true_oro_jump_fields.png'), ...
    'Resolution', 200);

exportgraphics(fig2, ...
    fullfile(result_dir, 'fig02_rmse_heatmap.png'), ...
    'Resolution', 200);

exportgraphics(fig3, ...
    fullfile(result_dir, 'fig03_max_error_heatmap.png'), ...
    'Resolution', 200);

exportgraphics(fig4, ...
    fullfile(result_dir, 'fig04_boundary_hit_heatmap.png'), ...
    'Resolution', 200);

exportgraphics(fig5, ...
    fullfile(result_dir, 'fig05_robust_tracking_example.png'), ...
    'Resolution', 200);

exportgraphics(fig6, ...
    fullfile(result_dir, 'fig06_failure_recovery_example.png'), ...
    'Resolution', 200);

exportgraphics(fig7, ...
    fullfile(result_dir, 'fig07_quality_cost_curves.png'), ...
    'Resolution', 200);

fprintf('\nOutputs saved to:\n%s\n', result_dir);

%% Local function
function recovery_len = estimate_recovery_length( ...
    p_est, p_true, jump_idx, search_step)
%ESTIMATE_RECOVERY_LENGTH
% Number of post-jump lines required until the tracking error returns below
% approximately one search-grid step for two consecutive lines.
%
% Returns NaN if recovery is not observed before the end of the sequence.

threshold = 1.25 * search_step;
err = abs(p_est - p_true);

recovery_len = NaN;

for k = jump_idx:(numel(err)-1)
    if err(k) <= threshold && err(k+1) <= threshold
        recovery_len = k - jump_idx;
        return;
    end
end

end
