function results = exp09a_oracle_ladder()
%EXP09A_ORACLE_LADDER
% EXP009 / Pilot-01 / Experiment A
%
% Purpose:
%   Decompose weak-component failure into progressively less-oracle stages.
%
% Four controlled levels:
%
%   L0 Oracle-Exact
%      True strong component is subtracted exactly.
%      Weak q is searched over the full q interval.
%      -> Measures intrinsic weak detectability under the chosen SNR.
%
%   L1 Q-Error-Only
%      Strong q is estimated from the mixture.
%      Strong amplitude, frequency and phase remain oracle-known.
%      Reconstruct strong component with q_hat and subtract it.
%      Weak q is searched over the full q interval.
%      -> Isolates the penalty caused by strong q estimation error.
%
%   L2 Practical-CLEAN-Full
%      Strong q is estimated from the mixture.
%      A practical narrowband CLEAN-like operation is performed after
%      dechirping at q_hat_strong:
%           dechirp -> FFT -> notch strongest bins -> IFFT -> rechirp
%      Weak q is searched over the full q interval.
%      -> Measures practical extraction/filtering damage and residual
%         contamination.
%
%   L3 Practical-CLEAN-Local-Valid
%      Uses exactly the same L2 residual, but searches weak q only inside a
%      narrow interval around a VALID synthetic prior.
%      -> Tests whether a correct local prior can retain recovery while
%         reducing q-candidate evaluations.
%
% IMPORTANT SCIENTIFIC SCOPE:
%   This file is self-contained and uses a matched-chirp concentration
%   search as a controlled FrFT/FrAc-like mechanism backend. It is NOT a
%   claim that this is Xu 2025 AFRA or the project's exact FrAc code.
%   The point of EXP009-A is failure-source isolation before integrating the
%   exact project FrAc backend.
%
% Run:
%   results = exp09a_oracle_ladder;
%
% Outputs:
%   trial_metrics.csv
%   summary.csv
%   cost_summary.csv
%   exp09a_results.mat
%   summary.txt
%   fig01_recovery_rates.png
%   fig02_weak_q_error.png
%   fig03_residual_correlations.png
%   fig04_example_concentration_curves.png

cfg = config_exp09a();

%% Paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);

if isempty(cfg.output_dir)
    % Expected placement:
    % <paper_root>/code/exp09_pilot01/exp09a_oracle_ladder.m
    code_dir = fileparts(this_dir);
    paper_root = fileparts(code_dir);
    out_dir = fullfile(paper_root, 'results', 'exp09_pilot01', ...
        'exp09a_oracle_ladder');
else
    out_dir = cfg.output_dir;
end

if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

fprintf('\n============================================================\n');
fprintf(' EXP009-A / Pilot-01: Oracle Ladder\n');
fprintf('============================================================\n');
fprintf('Output: %s\n', out_dir);

%% Reproducibility
rng(cfg.seed, 'twister');

%% Time axis
N = cfg.N;
n = 0:N-1;
t = (n - N/2) / N;

%% q grids
q_full = cfg.q_min : cfg.q_step : cfg.q_max;

local_center = cfg.q_weak + cfg.local_prior_bias;
q_local_min = max(cfg.q_min, local_center - cfg.local_halfwidth);
q_local_max = min(cfg.q_max, local_center + cfg.local_halfwidth);
q_local = q_local_min : cfg.q_step : q_local_max;

%% Precompute matched-chirp dechirp dictionaries
D_full = build_dechirp_dictionary(q_full, t, cfg);
D_local = build_dechirp_dictionary(q_local, t, cfg);

%% True components
s_strong = synth_lfm(cfg.A_strong, cfg.q_strong, cfg.f_strong, ...
    cfg.phi_strong, t, cfg);
s_weak = synth_lfm(cfg.A_weak, cfg.q_weak, cfg.f_weak, ...
    cfg.phi_weak, t, cfg);

x_clean = s_strong + s_weak;
signal_power = mean(abs(x_clean).^2);
noise_var = signal_power / (10^(cfg.snr_db / 10));

fprintf('N                         = %d\n', cfg.N);
fprintf('MC trials                 = %d\n', cfg.num_mc);
fprintf('SNR                        = %.2f dB (mixture referenced)\n', cfg.snr_db);
fprintf('q strong / weak            = %.4f / %.4f\n', cfg.q_strong, cfg.q_weak);
fprintf('|dq|                       = %.4f\n', abs(cfg.q_weak - cfg.q_strong));
fprintf('A weak / A strong          = %.3f\n', cfg.A_weak_ratio);
fprintf('Full q candidates          = %d\n', numel(q_full));
fprintf('Local q candidates         = %d\n', numel(q_local));
fprintf('Local prior bias           = %.4f\n', cfg.local_prior_bias);
fprintf('CLEAN notch halfwidth      = %d FFT bins\n\n', ...
    cfg.clean_notch_halfwidth_bins);

%% Preallocate trial arrays
M = cfg.num_mc;

trial_id = (1:M).';

q_s_hat = nan(M,1);
q_s_err = nan(M,1);

q_w_hat_L0 = nan(M,1);
q_w_hat_L1 = nan(M,1);
q_w_hat_L2 = nan(M,1);
q_w_hat_L3 = nan(M,1);

q_w_err_L0 = nan(M,1);
q_w_err_L1 = nan(M,1);
q_w_err_L2 = nan(M,1);
q_w_err_L3 = nan(M,1);

succ_L0 = false(M,1);
succ_L1 = false(M,1);
succ_L2 = false(M,1);
succ_L3 = false(M,1);

residual_energy_ratio_L2 = nan(M,1);
corr_residual_strong_L2 = nan(M,1);
corr_residual_weak_L2 = nan(M,1);

peak_ratio_L2 = nan(M,1);
peak_prominence_L2 = nan(M,1);
peak_curvature_L2 = nan(M,1);
distance_to_boundary_L3 = nan(M,1);

% Save one representative trial for visualization.
example = struct();

%% Monte Carlo
for imc = 1:M
    noise = sqrt(noise_var/2) * ...
        (randn(1,N) + 1j*randn(1,N));

    % IMPORTANT: The same noisy mixture is used by all ladder levels.
    x = x_clean + noise;

    %% Estimate dominant/strong q once for L1-L3
    [q_s_hat(imc), ~, ~] = search_q_concentration(x, q_full, D_full);
    q_s_err(imc) = abs(q_s_hat(imc) - cfg.q_strong);

    %% L0: Oracle exact strong subtraction
    r0 = x - s_strong;
    [q_w_hat_L0(imc), metric0, ~] = ...
        search_q_concentration(r0, q_full, D_full);

    %% L1: q-error-only subtraction
    % Only q is imperfect. Strong amplitude/frequency/phase are oracle-known.
    s_strong_qonly = synth_lfm(cfg.A_strong, q_s_hat(imc), ...
        cfg.f_strong, cfg.phi_strong, t, cfg);

    r1 = x - s_strong_qonly;
    [q_w_hat_L1(imc), metric1, ~] = ...
        search_q_concentration(r1, q_full, D_full);

    %% L2: practical CLEAN-like extraction + full weak search
    r2 = practical_clean_notch(x, q_s_hat(imc), t, cfg);

    [q_w_hat_L2(imc), metric2, idx2] = ...
        search_q_concentration(r2, q_full, D_full);

    %% L3: same practical residual + VALID local weak search
    [q_w_hat_L3(imc), metric3, idx3] = ...
        search_q_concentration(r2, q_local, D_local);

    %% Weak q errors / recovery
    q_w_err_L0(imc) = abs(q_w_hat_L0(imc) - cfg.q_weak);
    q_w_err_L1(imc) = abs(q_w_hat_L1(imc) - cfg.q_weak);
    q_w_err_L2(imc) = abs(q_w_hat_L2(imc) - cfg.q_weak);
    q_w_err_L3(imc) = abs(q_w_hat_L3(imc) - cfg.q_weak);

    succ_L0(imc) = q_w_err_L0(imc) <= cfg.tau_q;
    succ_L1(imc) = q_w_err_L1(imc) <= cfg.tau_q;
    succ_L2(imc) = q_w_err_L2(imc) <= cfg.tau_q;
    succ_L3(imc) = q_w_err_L3(imc) <= cfg.tau_q;

    %% Residual-layer diagnostics
    residual_energy_ratio_L2(imc) = ...
        sum(abs(r2).^2) / sum(abs(x).^2);

    corr_residual_strong_L2(imc) = normalized_corr(r2, s_strong);
    corr_residual_weak_L2(imc) = normalized_corr(r2, s_weak);

    [peak_ratio_L2(imc), peak_prominence_L2(imc), ...
        peak_curvature_L2(imc)] = ...
        concentration_reliability(metric2, idx2, ...
        cfg.second_peak_guard_bins);

    distance_to_boundary_L3(imc) = min( ...
        q_w_hat_L3(imc) - q_local(1), ...
        q_local(end) - q_w_hat_L3(imc));

    %% Representative example: first realization
    if imc == 1
        example.x = x;
        example.r0 = r0;
        example.r1 = r1;
        example.r2 = r2;
        example.metric0 = metric0;
        example.metric1 = metric1;
        example.metric2 = metric2;
        example.metric3 = metric3;
        example.q_s_hat = q_s_hat(imc);
        example.q_w_hat = [q_w_hat_L0(imc), q_w_hat_L1(imc), ...
            q_w_hat_L2(imc), q_w_hat_L3(imc)];
    end
end

%% Trial table
trial_table = table( ...
    trial_id, ...
    q_s_hat, q_s_err, ...
    q_w_hat_L0, q_w_hat_L1, q_w_hat_L2, q_w_hat_L3, ...
    q_w_err_L0, q_w_err_L1, q_w_err_L2, q_w_err_L3, ...
    succ_L0, succ_L1, succ_L2, succ_L3, ...
    residual_energy_ratio_L2, ...
    corr_residual_strong_L2, corr_residual_weak_L2, ...
    peak_ratio_L2, peak_prominence_L2, peak_curvature_L2, ...
    distance_to_boundary_L3);

writetable(trial_table, fullfile(out_dir, 'trial_metrics.csv'));

%% Summary
levels = ["L0_OracleExact"; "L1_QErrorOnly"; ...
          "L2_PracticalCLEANFull"; "L3_PracticalCLEANLocalValid"];

recovery_rate = [mean(succ_L0); mean(succ_L1); ...
                 mean(succ_L2); mean(succ_L3)];

weak_q_rmse = [sqrt(mean((q_w_hat_L0 - cfg.q_weak).^2)); ...
               sqrt(mean((q_w_hat_L1 - cfg.q_weak).^2)); ...
               sqrt(mean((q_w_hat_L2 - cfg.q_weak).^2)); ...
               sqrt(mean((q_w_hat_L3 - cfg.q_weak).^2))];

weak_q_mae = [mean(q_w_err_L0); mean(q_w_err_L1); ...
              mean(q_w_err_L2); mean(q_w_err_L3)];

summary_table = table(levels, recovery_rate, weak_q_rmse, weak_q_mae);
writetable(summary_table, fullfile(out_dir, 'summary.csv'));

%% Candidate-evaluation cost
n_full = numel(q_full);
n_local = numel(q_local);

% q-candidate evaluations only; practical CLEAN FFT cost is reported
% separately in the text summary and is not disguised as a q candidate.
candidate_evals_per_trial = [ ...
    n_full; ...             % L0: weak full only (oracle strong)
    n_full + n_full; ...    % L1: strong full + weak full
    n_full + n_full; ...    % L2: strong full + weak full
    n_full + n_local];      % L3: strong full + weak local

cost_table = table(levels, candidate_evals_per_trial);
writetable(cost_table, fullfile(out_dir, 'cost_summary.csv'));

%% Console summary
fprintf('================ EXP009-A SUMMARY ================\n');
for k = 1:numel(levels)
    fprintf('%-28s  Recall = %.3f   RMSE = %.5f   MAE = %.5f   q-evals/trial = %d\n', ...
        levels(k), recovery_rate(k), weak_q_rmse(k), weak_q_mae(k), ...
        candidate_evals_per_trial(k));
end
fprintf('\nStrong q RMSE             = %.6f\n', ...
    sqrt(mean((q_s_hat - cfg.q_strong).^2)));
fprintf('Mean L2 residual energy   = %.4f\n', ...
    mean(residual_energy_ratio_L2));
fprintf('Mean corr(r2,strong)       = %.4f\n', ...
    mean(corr_residual_strong_L2));
fprintf('Mean corr(r2,weak)         = %.4f\n', ...
    mean(corr_residual_weak_L2));
fprintf('Mean L2 peak ratio         = %.4f\n', mean(peak_ratio_L2));
fprintf('Mean L2 peak prominence    = %.4f\n', mean(peak_prominence_L2));
fprintf('==================================================\n');

%% Save text summary
fid = fopen(fullfile(out_dir, 'summary.txt'), 'w');
fprintf(fid, 'EXP009-A / Pilot-01 Oracle Ladder\n');
fprintf(fid, '=================================\n\n');
fprintf(fid, 'Seed: %d\n', cfg.seed);
fprintf(fid, 'MC trials: %d\n', cfg.num_mc);
fprintf(fid, 'N: %d\n', cfg.N);
fprintf(fid, 'SNR: %.3f dB (clean-mixture referenced)\n', cfg.snr_db);
fprintf(fid, 'q strong / weak: %.6f / %.6f\n', ...
    cfg.q_strong, cfg.q_weak);
fprintf(fid, 'A weak / A strong: %.6f\n', cfg.A_weak_ratio);
fprintf(fid, 'Full q candidates: %d\n', n_full);
fprintf(fid, 'Local q candidates: %d\n', n_local);
fprintf(fid, 'Local prior bias: %.6f\n\n', cfg.local_prior_bias);

for k = 1:numel(levels)
    fprintf(fid, '%s\n', levels(k));
    fprintf(fid, '  Recovery rate: %.6f\n', recovery_rate(k));
    fprintf(fid, '  Weak q RMSE:   %.8f\n', weak_q_rmse(k));
    fprintf(fid, '  Weak q MAE:    %.8f\n', weak_q_mae(k));
    fprintf(fid, '  q evals/trial: %d\n\n', candidate_evals_per_trial(k));
end

fprintf(fid, 'Strong q RMSE: %.8f\n', sqrt(mean((q_s_hat - cfg.q_strong).^2)));
fprintf(fid, 'Mean L2 residual energy ratio: %.8f\n', ...
    mean(residual_energy_ratio_L2));
fprintf(fid, 'Mean corr(r2,strong): %.8f\n', ...
    mean(corr_residual_strong_L2));
fprintf(fid, 'Mean corr(r2,weak): %.8f\n', ...
    mean(corr_residual_weak_L2));
fprintf(fid, 'Mean L2 peak ratio: %.8f\n', mean(peak_ratio_L2));
fprintf(fid, 'Mean L2 peak prominence: %.8f\n', ...
    mean(peak_prominence_L2));
fclose(fid);

%% Figures
make_figures(out_dir, cfg, q_full, q_local, ...
    recovery_rate, q_w_err_L0, q_w_err_L1, ...
    q_w_err_L2, q_w_err_L3, ...
    corr_residual_strong_L2, corr_residual_weak_L2, ...
    succ_L2, example);

%% Save MAT
results = struct();
results.cfg = cfg;
results.trial_table = trial_table;
results.summary_table = summary_table;
results.cost_table = cost_table;
results.example = example;
results.q_full = q_full;
results.q_local = q_local;

save(fullfile(out_dir, 'exp09a_results.mat'), 'results', '-v7.3');

fprintf('\nSaved EXP009-A outputs to:\n%s\n\n', out_dir);

end

%% ========================================================================
function D = build_dechirp_dictionary(q_grid, t, cfg)
% Each row is a dechirp atom for one q candidate.
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
% Matched-chirp concentration search.
%
% For each q:
%   dechirp x at q -> FFT -> take the maximum spectral energy.
%
% This is a controlled FrFT/FrAc-like concentration proxy used only for
% failure-source isolation in EXP009-A.
Y = fft(D .* x, [], 2);
metric = max(abs(Y).^2, [], 2);

[~, idx] = max(metric);
q_hat = q_grid(idx);
end

%% ========================================================================
function r = practical_clean_notch(x, q_hat, t, cfg)
% Practical CLEAN-like extraction:
%   dechirp at q_hat
%   -> FFT
%   -> notch strongest FFT bin +/- halfwidth
%   -> IFFT
%   -> rechirp
%
% This is deliberately simple and interpretable. Its purpose is to produce
% a realistic non-oracle residual whose strong-component leakage / weak
% component damage can be measured.

mu_hat = cfg.mu_scale * (q_hat - cfg.q_ref);

dechirp = exp(-1j*pi*mu_hat*t.^2);
rechirp = conj(dechirp);

z = x .* dechirp;
Z = fft(z);

[~, k0] = max(abs(Z).^2);

mask = ones(1, numel(Z));
h = cfg.clean_notch_halfwidth_bins;

for dk = -h:h
    kk = mod((k0-1) + dk, numel(Z)) + 1;
    mask(kk) = 0;
end

z_res = ifft(Z .* mask);
r = z_res .* rechirp;
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

% Second peak outside a guard interval around the best candidate.
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
function make_figures(out_dir, cfg, q_full, q_local, ...
    recovery_rate, e0, e1, e2, e3, ...
    corr_s, corr_w, succ2, example)

levels = {'L0 Oracle', 'L1 q-only', 'L2 CLEAN Full', 'L3 CLEAN Local'};

% Fig 1: Recovery rates
fig = figure('Visible', cfg.figure_visible);
bar(recovery_rate);
ylim([0 1]);
xticks(1:4);
xticklabels(levels);
ylabel('Weak-component recovery rate');
title('EXP009-A: Oracle Ladder Weak Recovery');
grid on;
exportgraphics(fig, fullfile(out_dir, 'fig01_recovery_rates.png'), ...
    'Resolution', 180);
close(fig);

% Fig 2: q-error distributions
fig = figure('Visible', cfg.figure_visible);
boxchart([ones(size(e0)); 2*ones(size(e1)); 3*ones(size(e2)); ...
    4*ones(size(e3))], [e0; e1; e2; e3]);
xticks(1:4);
xticklabels(levels);
ylabel('|q_{weak}^{hat} - q_{weak}|');
title('EXP009-A: Weak q Error by Ladder Level');
yline(cfg.tau_q, '--', 'Recovery threshold');
grid on;
exportgraphics(fig, fullfile(out_dir, 'fig02_weak_q_error.png'), ...
    'Resolution', 180);
close(fig);

% Fig 3: residual correlations
fig = figure('Visible', cfg.figure_visible);
scatter(corr_s(succ2), corr_w(succ2), 32, 'filled');
hold on;
scatter(corr_s(~succ2), corr_w(~succ2), 42, 'x');
xlabel('corr(r_2, strong)');
ylabel('corr(r_2, weak)');
title('L2 Residual State: Success vs Failure');
legend('Weak recovery success', 'Weak recovery failure', ...
    'Location', 'best');
grid on;
exportgraphics(fig, fullfile(out_dir, 'fig03_residual_correlations.png'), ...
    'Resolution', 180);
close(fig);

% Fig 4: representative concentration curves
fig = figure('Visible', cfg.figure_visible);
plot(q_full, normalize01(example.metric0), 'LineWidth', 1.2);
hold on;
plot(q_full, normalize01(example.metric1), 'LineWidth', 1.2);
plot(q_full, normalize01(example.metric2), 'LineWidth', 1.2);
plot(q_local, normalize01(example.metric3), '--', 'LineWidth', 1.2);
xline(cfg.q_weak, ':', 'True weak q');
xlabel('q candidate');
ylabel('Normalized concentration metric');
title('Representative Weak-Search Concentration Curves');
legend('L0', 'L1', 'L2 Full', 'L3 Local', 'True q_{weak}', ...
    'Location', 'best');
grid on;
exportgraphics(fig, ...
    fullfile(out_dir, 'fig04_example_concentration_curves.png'), ...
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
