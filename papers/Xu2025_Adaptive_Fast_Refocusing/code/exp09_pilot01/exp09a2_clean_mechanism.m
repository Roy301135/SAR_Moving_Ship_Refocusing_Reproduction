function results = exp09a2_clean_mechanism()
%EXP09A2_CLEAN_MECHANISM
% EXP009 / Pilot-01 / Experiment A2
%
% Research question:
%   Why does practical CLEAN reduce weak-component recovery?
%
% Part I: C0/C1/C2 mechanism ladder
%
%   C0 Exact subtraction
%      true strong component is subtracted exactly.
%
%   C1 Practical CLEAN + true q_strong
%      practical notch-based CLEAN is applied using the TRUE strong q.
%      Difference C1-C0 isolates the CLEAN/operator penalty itself.
%
%   C2 Practical CLEAN + estimated q_strong
%      same practical CLEAN, but using q_hat_strong estimated from mixture.
%      Difference C2-C1 measures the additional interaction with q error.
%
% Part II: CLEAN width sweep
%
%   h in {0,1,2,3,5} FFT bins.
%
% For every h we measure:
%   - weak recovery rate
%   - weak q bias / RMSE
%   - eta_s: strong-template retention in residual
%   - eta_w: weak-template retention in residual
%   - normalized strong/weak residual correlations
%   - residual energy ratio
%
% Definitions:
%
%   eta_s = |<r,s_strong>|^2 / ||s_strong||^4
%   eta_w = |<r,s_weak>|^2   / ||s_weak||^4
%
% If r contains exactly one unchanged template component plus orthogonal
% content, eta behaves like the squared retained amplitude coefficient.
% It is therefore more suitable here than normalized correlation alone for
% distinguishing "strong suppression" from "weak preservation".
%
% IMPORTANT:
%   This uses the same controlled matched-chirp concentration backend as
%   EXP009-A. It does NOT claim exact Xu 2025 AFRA reproduction.
%
% Run:
%   results = exp09a2_clean_mechanism;

cfg = config_exp09a2();

%% Paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);

if isempty(cfg.output_dir)
    code_dir = fileparts(this_dir);
    paper_root = fileparts(code_dir);
    out_dir = fullfile(paper_root, 'results', 'exp09_pilot01', ...
        'exp09a2_clean_mechanism');
else
    out_dir = cfg.output_dir;
end

if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

fprintf('\n============================================================\n');
fprintf(' EXP009-A2 / CLEAN Mechanism Dissection\n');
fprintf('============================================================\n');
fprintf('Output: %s\n', out_dir);

%% Reproducibility and signal
rng(cfg.seed, 'twister');

N = cfg.N;
n = 0:N-1;
t = (n - N/2) / N;

q_full = cfg.q_min : cfg.q_step : cfg.q_max;
D_full = build_dechirp_dictionary(q_full, t, cfg);

s_strong = synth_lfm(cfg.A_strong, cfg.q_strong, cfg.f_strong, ...
    cfg.phi_strong, t, cfg);
s_weak = synth_lfm(cfg.A_weak, cfg.q_weak, cfg.f_weak, ...
    cfg.phi_weak, t, cfg);

x_clean = s_strong + s_weak;
signal_power = mean(abs(x_clean).^2);
noise_var = signal_power / (10^(cfg.snr_db/10));

M = cfg.num_mc;
H = cfg.notch_halfwidth_list;
nH = numel(H);

fprintf('MC trials                     = %d\n', M);
fprintf('SNR                           = %.2f dB\n', cfg.snr_db);
fprintf('q strong / weak               = %.4f / %.4f\n', ...
    cfg.q_strong, cfg.q_weak);
fprintf('A weak / A strong             = %.3f\n', cfg.A_weak_ratio);
fprintf('Default CLEAN halfwidth       = %d bins\n', ...
    cfg.default_notch_halfwidth_bins);
fprintf('Width sweep                   = [%s]\n\n', ...
    num2str(cfg.notch_halfwidth_list));

%% Pre-generate noise so every method/width uses exactly the same realizations
noise_bank = sqrt(noise_var/2) * ...
    (randn(M,N) + 1j*randn(M,N));

%% ========================================================================
% Part I: C0/C1/C2 at default width
h0 = cfg.default_notch_halfwidth_bins;

q_s_hat = nan(M,1);
q_s_err = nan(M,1);

q_w_C0 = nan(M,1);
q_w_C1 = nan(M,1);
q_w_C2 = nan(M,1);

err_C0 = nan(M,1);
err_C1 = nan(M,1);
err_C2 = nan(M,1);

succ_C0 = false(M,1);
succ_C1 = false(M,1);
succ_C2 = false(M,1);

bias_C0 = nan(M,1);
bias_C1 = nan(M,1);
bias_C2 = nan(M,1);

eta_s_C1 = nan(M,1);
eta_w_C1 = nan(M,1);
eta_s_C2 = nan(M,1);
eta_w_C2 = nan(M,1);

corr_s_C1 = nan(M,1);
corr_w_C1 = nan(M,1);
corr_s_C2 = nan(M,1);
corr_w_C2 = nan(M,1);

resE_C1 = nan(M,1);
resE_C2 = nan(M,1);

peak_ratio_C1 = nan(M,1);
peak_ratio_C2 = nan(M,1);
prom_C1 = nan(M,1);
prom_C2 = nan(M,1);
curv_C1 = nan(M,1);
curv_C2 = nan(M,1);

example = struct();

for imc = 1:M
    noise = noise_bank(imc,:);
    x = x_clean + noise;

    % Strong q estimate for C2
    [q_s_hat(imc), ~, ~] = search_q_concentration(x, q_full, D_full);
    q_s_err(imc) = abs(q_s_hat(imc) - cfg.q_strong);

    % C0: exact subtraction
    r0 = x - s_strong;
    [q_w_C0(imc), metric0, idx0] = ...
        search_q_concentration(r0, q_full, D_full);

    % C1: practical CLEAN, true strong q
    r1 = practical_clean_notch(x, cfg.q_strong, h0, t, cfg);
    [q_w_C1(imc), metric1, idx1] = ...
        search_q_concentration(r1, q_full, D_full);

    % C2: practical CLEAN, estimated strong q
    r2 = practical_clean_notch(x, q_s_hat(imc), h0, t, cfg);
    [q_w_C2(imc), metric2, idx2] = ...
        search_q_concentration(r2, q_full, D_full);

    % Error and recovery
    bias_C0(imc) = q_w_C0(imc) - cfg.q_weak;
    bias_C1(imc) = q_w_C1(imc) - cfg.q_weak;
    bias_C2(imc) = q_w_C2(imc) - cfg.q_weak;

    err_C0(imc) = abs(bias_C0(imc));
    err_C1(imc) = abs(bias_C1(imc));
    err_C2(imc) = abs(bias_C2(imc));

    succ_C0(imc) = is_recovered(err_C0(imc), cfg);
    succ_C1(imc) = is_recovered(err_C1(imc), cfg);
    succ_C2(imc) = is_recovered(err_C2(imc), cfg);

    % Template-retention metrics
    eta_s_C1(imc) = template_retention(r1, s_strong);
    eta_w_C1(imc) = template_retention(r1, s_weak);
    eta_s_C2(imc) = template_retention(r2, s_strong);
    eta_w_C2(imc) = template_retention(r2, s_weak);

    % Normalized correlations
    corr_s_C1(imc) = normalized_corr(r1, s_strong);
    corr_w_C1(imc) = normalized_corr(r1, s_weak);
    corr_s_C2(imc) = normalized_corr(r2, s_strong);
    corr_w_C2(imc) = normalized_corr(r2, s_weak);

    resE_C1(imc) = sum(abs(r1).^2) / sum(abs(x).^2);
    resE_C2(imc) = sum(abs(r2).^2) / sum(abs(x).^2);

    [peak_ratio_C1(imc), prom_C1(imc), curv_C1(imc)] = ...
        concentration_reliability(metric1, idx1, ...
        cfg.second_peak_guard_bins);

    [peak_ratio_C2(imc), prom_C2(imc), curv_C2(imc)] = ...
        concentration_reliability(metric2, idx2, ...
        cfg.second_peak_guard_bins);

    if imc == 1
        example.x = x;
        example.r0 = r0;
        example.r1 = r1;
        example.r2 = r2;
        example.metric0 = metric0;
        example.metric1 = metric1;
        example.metric2 = metric2;
    end
end

trial_id = (1:M).';

default_trial_table = table( ...
    trial_id, q_s_hat, q_s_err, ...
    q_w_C0, q_w_C1, q_w_C2, ...
    bias_C0, bias_C1, bias_C2, ...
    err_C0, err_C1, err_C2, ...
    succ_C0, succ_C1, succ_C2, ...
    eta_s_C1, eta_w_C1, eta_s_C2, eta_w_C2, ...
    corr_s_C1, corr_w_C1, corr_s_C2, corr_w_C2, ...
    resE_C1, resE_C2, ...
    peak_ratio_C1, peak_ratio_C2, ...
    prom_C1, prom_C2, curv_C1, curv_C2);

writetable(default_trial_table, ...
    fullfile(out_dir, 'default_ladder_trials.csv'));

levels = ["C0_ExactSubtraction"; ...
          "C1_PracticalCLEAN_TrueQ"; ...
          "C2_PracticalCLEAN_EstimatedQ"];

recovery_rate = [mean(succ_C0); mean(succ_C1); mean(succ_C2)];
weak_q_rmse = [sqrt(mean(bias_C0.^2)); ...
               sqrt(mean(bias_C1.^2)); ...
               sqrt(mean(bias_C2.^2))];
weak_q_mae = [mean(err_C0); mean(err_C1); mean(err_C2)];
weak_q_signed_bias = [mean(bias_C0); mean(bias_C1); mean(bias_C2)];

default_summary = table(levels, recovery_rate, weak_q_rmse, ...
    weak_q_mae, weak_q_signed_bias);
writetable(default_summary, ...
    fullfile(out_dir, 'default_ladder_summary.csv'));

%% Paired transition counts
T01 = transition_counts(succ_C0, succ_C1);
T12 = transition_counts(succ_C1, succ_C2);

%% ========================================================================
% Part II: CLEAN width sweep
%
% We evaluate both TRUE-q CLEAN and ESTIMATED-q CLEAN for each width.
method_names = ["TrueQ"; "EstimatedQ"];

nRows = M * nH * 2;
trial_col = zeros(nRows,1);
h_col = zeros(nRows,1);
method_col = strings(nRows,1);

q_s_used_col = nan(nRows,1);
q_w_hat_col = nan(nRows,1);
q_bias_col = nan(nRows,1);
q_err_col = nan(nRows,1);
success_col = false(nRows,1);

eta_s_col = nan(nRows,1);
eta_w_col = nan(nRows,1);
corr_s_col = nan(nRows,1);
corr_w_col = nan(nRows,1);
resE_col = nan(nRows,1);

row = 0;

for ih = 1:nH
    h = H(ih);

    for imc = 1:M
        noise = noise_bank(imc,:);
        x = x_clean + noise;

        % Estimate strong q once per realization for estimated-q branch.
        qsh = q_s_hat(imc);

        for imethod = 1:2
            row = row + 1;

            if imethod == 1
                q_s_used = cfg.q_strong;
            else
                q_s_used = qsh;
            end

            r = practical_clean_notch(x, q_s_used, h, t, cfg);
            [qwh, ~, ~] = search_q_concentration(r, q_full, D_full);

            qb = qwh - cfg.q_weak;
            qe = abs(qb);

            trial_col(row) = imc;
            h_col(row) = h;
            method_col(row) = method_names(imethod);

            q_s_used_col(row) = q_s_used;
            q_w_hat_col(row) = qwh;
            q_bias_col(row) = qb;
            q_err_col(row) = qe;
            success_col(row) = is_recovered(qe, cfg);

            eta_s_col(row) = template_retention(r, s_strong);
            eta_w_col(row) = template_retention(r, s_weak);

            corr_s_col(row) = normalized_corr(r, s_strong);
            corr_w_col(row) = normalized_corr(r, s_weak);

            resE_col(row) = sum(abs(r).^2) / sum(abs(x).^2);
        end
    end
end

width_trial_table = table( ...
    trial_col, h_col, method_col, ...
    q_s_used_col, q_w_hat_col, q_bias_col, q_err_col, success_col, ...
    eta_s_col, eta_w_col, corr_s_col, corr_w_col, resE_col, ...
    'VariableNames', { ...
    'trial_id','notch_halfwidth_bins','method', ...
    'q_strong_used','q_weak_hat','q_weak_signed_bias','q_weak_abs_error', ...
    'weak_recovered','eta_strong','eta_weak', ...
    'corr_residual_strong','corr_residual_weak','residual_energy_ratio'});

writetable(width_trial_table, ...
    fullfile(out_dir, 'width_sweep_trials.csv'));

%% Width-sweep summary
sum_method = strings(nH*2,1);
sum_h = zeros(nH*2,1);
sum_recall = nan(nH*2,1);
sum_rmse = nan(nH*2,1);
sum_mae = nan(nH*2,1);
sum_bias = nan(nH*2,1);
sum_eta_s = nan(nH*2,1);
sum_eta_w = nan(nH*2,1);
sum_corr_s = nan(nH*2,1);
sum_corr_w = nan(nH*2,1);
sum_resE = nan(nH*2,1);

row = 0;
for imethod = 1:2
    for ih = 1:nH
        row = row + 1;
        mask = width_trial_table.notch_halfwidth_bins == H(ih) & ...
            width_trial_table.method == method_names(imethod);

        sum_method(row) = method_names(imethod);
        sum_h(row) = H(ih);

        qb = width_trial_table.q_weak_signed_bias(mask);
        qe = width_trial_table.q_weak_abs_error(mask);
        succ = width_trial_table.weak_recovered(mask);

        sum_recall(row) = mean(succ);
        sum_rmse(row) = sqrt(mean(qb.^2));
        sum_mae(row) = mean(qe);
        sum_bias(row) = mean(qb);

        sum_eta_s(row) = mean(width_trial_table.eta_strong(mask));
        sum_eta_w(row) = mean(width_trial_table.eta_weak(mask));
        sum_corr_s(row) = mean(width_trial_table.corr_residual_strong(mask));
        sum_corr_w(row) = mean(width_trial_table.corr_residual_weak(mask));
        sum_resE(row) = mean(width_trial_table.residual_energy_ratio(mask));
    end
end

width_summary = table( ...
    sum_method, sum_h, sum_recall, sum_rmse, sum_mae, sum_bias, ...
    sum_eta_s, sum_eta_w, sum_corr_s, sum_corr_w, sum_resE, ...
    'VariableNames', { ...
    'method','notch_halfwidth_bins','weak_recovery_rate', ...
    'weak_q_rmse','weak_q_mae','weak_q_signed_bias', ...
    'mean_eta_strong','mean_eta_weak', ...
    'mean_corr_residual_strong','mean_corr_residual_weak', ...
    'mean_residual_energy_ratio'});

writetable(width_summary, ...
    fullfile(out_dir, 'width_sweep_summary.csv'));

%% Console summary
fprintf('================ A2 DEFAULT LADDER ================\n');
for k = 1:numel(levels)
    fprintf('%-30s Recall = %.3f  RMSE = %.5f  MAE = %.5f  Bias = %+0.5f\n', ...
        levels(k), recovery_rate(k), weak_q_rmse(k), ...
        weak_q_mae(k), weak_q_signed_bias(k));
end

fprintf('\nC0 -> C1 transitions: SS=%d SF=%d FS=%d FF=%d\n', ...
    T01.SS, T01.SF, T01.FS, T01.FF);
fprintf('C1 -> C2 transitions: SS=%d SF=%d FS=%d FF=%d\n', ...
    T12.SS, T12.SF, T12.FS, T12.FF);

fprintf('\n================ A2 WIDTH SWEEP ====================\n');
for row = 1:height(width_summary)
    fprintf('%-10s h=%d  Recall=%.3f  Bias=%+0.5f  eta_s=%.4f  eta_w=%.4f\n', ...
        width_summary.method(row), ...
        width_summary.notch_halfwidth_bins(row), ...
        width_summary.weak_recovery_rate(row), ...
        width_summary.weak_q_signed_bias(row), ...
        width_summary.mean_eta_strong(row), ...
        width_summary.mean_eta_weak(row));
end
fprintf('==================================================\n');

%% Text summary
fid = fopen(fullfile(out_dir, 'summary.txt'), 'w');

fprintf(fid, 'EXP009-A2 CLEAN Mechanism Dissection\n');
fprintf(fid, '====================================\n\n');

fprintf(fid, 'MC trials: %d\n', cfg.num_mc);
fprintf(fid, 'SNR: %.3f dB\n', cfg.snr_db);
fprintf(fid, 'q strong / weak: %.6f / %.6f\n', ...
    cfg.q_strong, cfg.q_weak);
fprintf(fid, 'A weak / A strong: %.6f\n', cfg.A_weak_ratio);
fprintf(fid, 'Default notch halfwidth: %d bins\n\n', h0);

for k = 1:numel(levels)
    fprintf(fid, '%s\n', levels(k));
    fprintf(fid, '  Recovery: %.6f\n', recovery_rate(k));
    fprintf(fid, '  q RMSE:   %.8f\n', weak_q_rmse(k));
    fprintf(fid, '  q MAE:    %.8f\n', weak_q_mae(k));
    fprintf(fid, '  q bias:   %+.8f\n\n', weak_q_signed_bias(k));
end

fprintf(fid, 'C0 -> C1: SS=%d SF=%d FS=%d FF=%d\n', ...
    T01.SS, T01.SF, T01.FS, T01.FF);
fprintf(fid, 'C1 -> C2: SS=%d SF=%d FS=%d FF=%d\n\n', ...
    T12.SS, T12.SF, T12.FS, T12.FF);

fprintf(fid, 'Width sweep\n');
fprintf(fid, '-----------\n');
for row = 1:height(width_summary)
    fprintf(fid, '%s, h=%d: Recall=%.6f, Bias=%+.8f, eta_s=%.8f, eta_w=%.8f\n', ...
        width_summary.method(row), ...
        width_summary.notch_halfwidth_bins(row), ...
        width_summary.weak_recovery_rate(row), ...
        width_summary.weak_q_signed_bias(row), ...
        width_summary.mean_eta_strong(row), ...
        width_summary.mean_eta_weak(row));
end
fclose(fid);

%% Figures
make_figures(out_dir, cfg, q_full, H, ...
    recovery_rate, bias_C0, bias_C1, bias_C2, ...
    width_summary, width_trial_table, example);

%% Save MAT
results = struct();
results.cfg = cfg;
results.default_trial_table = default_trial_table;
results.default_summary = default_summary;
results.transition_C0_C1 = T01;
results.transition_C1_C2 = T12;
results.width_trial_table = width_trial_table;
results.width_summary = width_summary;
results.example = example;

save(fullfile(out_dir, 'exp09a2_results.mat'), 'results', '-v7.3');

fprintf('\nSaved EXP009-A2 outputs to:\n%s\n\n', out_dir);

end

%% ========================================================================
function D = build_dechirp_dictionary(q_grid, t, cfg)
mu = cfg.mu_scale * (q_grid(:) - cfg.q_ref);
D = exp(-1j*pi * (mu * (t.^2)));
end

%% ========================================================================
function s = synth_lfm(A, q, f0, phi0, t, cfg)
mu = cfg.mu_scale * (q - cfg.q_ref);
s = A .* exp(1j * (pi*mu*t.^2 + 2*pi*f0*t + phi0));
end

%% ========================================================================
function [q_hat, metric, idx] = search_q_concentration(x, q_grid, D)
Y = fft(D .* x, [], 2);
metric = max(abs(Y).^2, [], 2);
[~, idx] = max(metric);
q_hat = q_grid(idx);
end

%% ========================================================================
function r = practical_clean_notch(x, q_used, halfwidth_bins, t, cfg)
mu_used = cfg.mu_scale * (q_used - cfg.q_ref);

dechirp = exp(-1j*pi*mu_used*t.^2);
rechirp = conj(dechirp);

z = x .* dechirp;
Z = fft(z);

[~, k0] = max(abs(Z).^2);

mask = ones(1, numel(Z));
for dk = -halfwidth_bins:halfwidth_bins
    kk = mod((k0-1) + dk, numel(Z)) + 1;
    mask(kk) = 0;
end

z_res = ifft(Z .* mask);
r = z_res .* rechirp;
end

%% ========================================================================
function tf = is_recovered(abs_error, cfg)
tf = abs_error <= (cfg.tau_q + cfg.success_tol);
end

%% ========================================================================
function eta = template_retention(r, s)
% Squared projection coefficient of residual r onto template s.
%
% If r = a*s + orthogonal_content, then eta = |a|^2.
num = abs(r * s')^2;
den = max(norm(s)^4, eps);
eta = num / den;
end

%% ========================================================================
function c = normalized_corr(a, b)
den = norm(a) * norm(b);
if den <= eps
    c = 0;
else
    c = abs(a * b') / den;
end
end

%% ========================================================================
function [peak_ratio, prominence, curvature] = ...
    concentration_reliability(metric, idx_peak, guard_bins)

metric = metric(:);
M = numel(metric);
peak = metric(idx_peak);

keep = true(M,1);
i1 = max(1, idx_peak - guard_bins);
i2 = min(M, idx_peak + guard_bins);
keep(i1:i2) = false;

if any(keep)
    second_peak = max(metric(keep));
else
    second_peak = eps;
end

peak_ratio = peak / max(second_peak, eps);

baseline = median(metric);
prominence = (peak - baseline) / max(peak, eps);

if idx_peak > 1 && idx_peak < M
    local_mean = 0.5 * (metric(idx_peak-1) + metric(idx_peak+1));
    curvature = (peak - local_mean) / max(peak, eps);
else
    curvature = 0;
end
end

%% ========================================================================
function T = transition_counts(a, b)
T = struct();
T.SS = sum(a & b);
T.SF = sum(a & ~b);
T.FS = sum(~a & b);
T.FF = sum(~a & ~b);
end

%% ========================================================================
function make_figures(out_dir, cfg, q_full, H, ...
    recovery_rate, bias0, bias1, bias2, ...
    width_summary, width_trials, example)

levels = {'C0 Exact', 'C1 CLEAN True-q', 'C2 CLEAN Estimated-q'};

% Fig 1: default ladder recall
fig = figure('Visible', cfg.figure_visible);
bar(recovery_rate);
ylim([0 1]);
xticks(1:3);
xticklabels(levels);
ylabel('Weak-component recovery rate');
title('EXP009-A2: C0/C1/C2 Recovery');
grid on;
exportgraphics(fig, fullfile(out_dir, 'fig01_default_recovery.png'), ...
    'Resolution', 180);
close(fig);

% Fig 2: signed bias distributions
fig = figure('Visible', cfg.figure_visible);
grp = [ones(size(bias0)); 2*ones(size(bias1)); 3*ones(size(bias2))];
vals = [bias0; bias1; bias2];
boxchart(grp, vals);
xticks(1:3);
xticklabels(levels);
yline(0, '--');
ylabel('q_{weak}^{hat} - q_{weak}');
title('EXP009-A2: Signed Weak-q Bias');
grid on;
exportgraphics(fig, fullfile(out_dir, 'fig02_signed_q_bias.png'), ...
    'Resolution', 180);
close(fig);

% Fig 3: width sweep recall
fig = figure('Visible', cfg.figure_visible);
maskT = width_summary.method == "TrueQ";
maskE = width_summary.method == "EstimatedQ";
plot(width_summary.notch_halfwidth_bins(maskT), ...
    width_summary.weak_recovery_rate(maskT), '-o', 'LineWidth', 1.5);
hold on;
plot(width_summary.notch_halfwidth_bins(maskE), ...
    width_summary.weak_recovery_rate(maskE), '-s', 'LineWidth', 1.5);
ylim([0 1]);
xlabel('CLEAN notch halfwidth (FFT bins)');
ylabel('Weak recovery rate');
title('EXP009-A2: CLEAN Width vs Weak Recovery');
legend('True q_{strong}', 'Estimated q_{strong}', 'Location', 'best');
grid on;
exportgraphics(fig, fullfile(out_dir, 'fig03_width_vs_recovery.png'), ...
    'Resolution', 180);
close(fig);

% Fig 4: eta strong/weak vs width for EstimatedQ
fig = figure('Visible', cfg.figure_visible);
plot(width_summary.notch_halfwidth_bins(maskE), ...
    width_summary.mean_eta_strong(maskE), '-o', 'LineWidth', 1.5);
hold on;
plot(width_summary.notch_halfwidth_bins(maskE), ...
    width_summary.mean_eta_weak(maskE), '-s', 'LineWidth', 1.5);
xlabel('CLEAN notch halfwidth (FFT bins)');
ylabel('Mean template retention');
title('Estimated-q CLEAN: Strong Suppression vs Weak Preservation');
legend('\eta_s (strong retention)', '\eta_w (weak retention)', ...
    'Location', 'best');
grid on;
exportgraphics(fig, fullfile(out_dir, 'fig04_eta_tradeoff.png'), ...
    'Resolution', 180);
close(fig);

% Fig 5: signed q bias vs width
fig = figure('Visible', cfg.figure_visible);
plot(width_summary.notch_halfwidth_bins(maskT), ...
    width_summary.weak_q_signed_bias(maskT), '-o', 'LineWidth', 1.5);
hold on;
plot(width_summary.notch_halfwidth_bins(maskE), ...
    width_summary.weak_q_signed_bias(maskE), '-s', 'LineWidth', 1.5);
yline(0, '--');
xlabel('CLEAN notch halfwidth (FFT bins)');
ylabel('Mean signed weak-q bias');
title('EXP009-A2: CLEAN Width vs Weak-q Shift');
legend('True q_{strong}', 'Estimated q_{strong}', 'Location', 'best');
grid on;
exportgraphics(fig, fullfile(out_dir, 'fig05_width_vs_q_bias.png'), ...
    'Resolution', 180);
close(fig);

% Fig 6: eta_s vs eta_w, EstimatedQ branch
mask = width_trials.method == "EstimatedQ";
fig = figure('Visible', cfg.figure_visible);
scatter(width_trials.eta_strong(mask), ...
    width_trials.eta_weak(mask), 24, ...
    width_trials.notch_halfwidth_bins(mask), 'filled');
xlabel('\eta_s: strong retention');
ylabel('\eta_w: weak retention');
title('Estimated-q CLEAN Residual Trade-off');
cb = colorbar;
cb.Label.String = 'Notch halfwidth (FFT bins)';
grid on;
exportgraphics(fig, fullfile(out_dir, 'fig06_eta_scatter.png'), ...
    'Resolution', 180);
close(fig);

% Fig 7: representative concentration curves
fig = figure('Visible', cfg.figure_visible);
plot(q_full, normalize01(example.metric0), 'LineWidth', 1.2);
hold on;
plot(q_full, normalize01(example.metric1), 'LineWidth', 1.2);
plot(q_full, normalize01(example.metric2), 'LineWidth', 1.2);
xline(cfg.q_weak, ':', 'True q_{weak}');
xlabel('q candidate');
ylabel('Normalized concentration metric');
title('Representative C0/C1/C2 Weak-Search Curves');
legend('C0 Exact', 'C1 CLEAN True-q', 'C2 CLEAN Estimated-q', ...
    'True q_{weak}', 'Location', 'best');
grid on;
exportgraphics(fig, ...
    fullfile(out_dir, 'fig07_example_concentration_curves.png'), ...
    'Resolution', 180);
close(fig);

end

%% ========================================================================
function y = normalize01(x)
x = x(:);
xmin = min(x);
xmax = max(x);
if xmax <= xmin
    y = zeros(size(x));
else
    y = (x - xmin) / (xmax - xmin);
end
end
