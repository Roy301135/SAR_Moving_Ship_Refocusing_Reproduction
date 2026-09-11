function results = exp09a3_peak_shift()
%EXP09A3_PEAK_SHIFT
% EXP009 / Pilot-01 / Experiment A3
%
% Purpose:
%   Explain the persistent negative weak-q bias observed after practical
%   CLEAN in EXP009-A2.
%
% Core decomposition
% ------------------
% Let O_h{.} be a FIXED strong-removal operator:
%
%   dechirp at true q_strong
%   -> FFT
%   -> notch a fixed spectral bin centered on the true strong component
%   -> IFFT
%   -> rechirp
%
% The fixed notch center is determined ONCE from the noiseless strong-only
% signal. This makes O_h linear and allows a clean decomposition.
%
% Noiseless branches
% ------------------
% P0: s_w
% P1: O_h{s_w}
%     -> direct operator effect on weak component only
%
% P2: s_w + O_h{s_s}
%     -> filtered strong residual is added to untouched weak component
%
% P3: O_h{s_w} + O_h{s_s} = O_h{s_s+s_w}
%     -> combined fixed-operator residual
%
% Monte-Carlo branches
% --------------------
% D0: s_w + n
% D1: O_h{s_w+n}
%     -> operator-only effect on weak+noise
%
% D2: s_w+n + O_h{s_s}
%     -> strong-residual-only effect
%
% D3: O_h{s_w+n} + O_h{s_s}
%     -> combined fixed operator
%
% D4: practical adaptive-notch CLEAN on s_s+s_w+n using true q_strong
%     -> checks whether the fixed-mask mechanism matches the actual A2
%        practical CLEAN implementation.
%
% Interpretation
% --------------
% If D1 ~= D0 but D2/D3 shift:
%   the persistent bias is NOT caused by direct weak filtering alone.
%   It is mainly caused by the FILTERED STRONG RESIDUAL.
%
% If D1 itself shifts strongly:
%   the notch operator directly reshapes the weak component / noise.
%
% If D4 ~= D3:
%   adaptive notch-center selection is not the main cause.
%
% IMPORTANT:
%   This remains a controlled mechanism experiment and does NOT claim exact
%   Xu 2025 AFRA reproduction.
%
% Run:
%   results = exp09a3_peak_shift;

cfg = config_exp09a3();

%% Paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);

if isempty(cfg.output_dir)
    code_dir = fileparts(this_dir);
    paper_root = fileparts(code_dir);
    out_dir = fullfile(paper_root, 'results', 'exp09_pilot01', ...
        'exp09a3_peak_shift');
else
    out_dir = cfg.output_dir;
end

if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

fprintf('\n============================================================\n');
fprintf(' EXP009-A3 / Operator-Induced Peak-Shift Test\n');
fprintf('============================================================\n');
fprintf('Output: %s\n', out_dir);

%% Reproducibility
rng(cfg.seed, 'twister');

%% Signal and search dictionary
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

% Determine the strong notch center ONCE from the pure strong signal
% after exact dechirping at q_strong.
k_strong_fixed = get_strong_notch_bin(s_strong, cfg.q_strong, t, cfg);

fprintf('MC trials                     = %d\n', cfg.num_mc);
fprintf('SNR                           = %.2f dB\n', cfg.snr_db);
fprintf('q strong / weak               = %.4f / %.4f\n', ...
    cfg.q_strong, cfg.q_weak);
fprintf('A weak / A strong             = %.3f\n', cfg.A_weak_ratio);
fprintf('Fixed strong FFT bin          = %d (MATLAB index)\n', ...
    k_strong_fixed);
fprintf('Default notch halfwidth       = %d bins\n', ...
    cfg.default_notch_halfwidth_bins);
fprintf('Width sweep                   = [%s]\n\n', ...
    num2str(cfg.notch_halfwidth_list));

%% Pre-generate the same noise bank for all branches
M = cfg.num_mc;
noise_bank = sqrt(noise_var/2) * ...
    (randn(M,N) + 1j*randn(M,N));

H = cfg.notch_halfwidth_list;
nH = numel(H);

%% ========================================================================
% PART 0: NOISELESS MECHANISM ANATOMY
%
% This is the cleanest test of whether the notch operator itself shifts the
% weak q peak before any noise is introduced.

p_branch = strings(nH*4,1);
p_h = zeros(nH*4,1);
p_qhat = nan(nH*4,1);
p_bias = nan(nH*4,1);
p_centroid = nan(nH*4,1);
p_asym = nan(nH*4,1);
p_curve_deform = nan(nH*4,1);

strong_residual_energy_ratio = nan(nH,1);
strong_residual_to_weak_energy = nan(nH,1);
weak_energy_removed_fraction = nan(nH,1);

row = 0;

[qhat_P0_ref, metric_P0_ref, ~] = ...
    search_q_concentration(s_weak, q_full, D_full);
metric_P0_ref_n = normalize01(metric_P0_ref);

for ih = 1:nH
    h = H(ih);

    strong_residual = apply_fixed_notch_operator( ...
        s_strong, cfg.q_strong, k_strong_fixed, h, t, cfg);

    weak_filtered = apply_fixed_notch_operator( ...
        s_weak, cfg.q_strong, k_strong_fixed, h, t, cfg);

    strong_residual_energy_ratio(ih) = ...
        sum(abs(strong_residual).^2) / sum(abs(s_strong).^2);

    strong_residual_to_weak_energy(ih) = ...
        sum(abs(strong_residual).^2) / sum(abs(s_weak).^2);

    weak_energy_removed_fraction(ih) = ...
        1 - sum(abs(weak_filtered).^2) / sum(abs(s_weak).^2);

    signals = { ...
        s_weak, ...
        weak_filtered, ...
        s_weak + strong_residual, ...
        weak_filtered + strong_residual};

    names = ["P0_WeakOnly"; ...
             "P1_FilteredWeakOnly"; ...
             "P2_WeakPlusStrongResidual"; ...
             "P3_CombinedFixedOperator"];

    for ib = 1:4
        row = row + 1;

        [qhat, metric, ~] = ...
            search_q_concentration(signals{ib}, q_full, D_full);

        [centroid, asym] = ...
            local_curve_shape(metric, q_full, cfg.q_weak, ...
            cfg.shape_halfwidth);

        metric_n = normalize01(metric);

        p_branch(row) = names(ib);
        p_h(row) = h;
        p_qhat(row) = qhat;
        p_bias(row) = qhat - cfg.q_weak;
        p_centroid(row) = centroid;
        p_asym(row) = asym;
        p_curve_deform(row) = ...
            norm(metric_n - metric_P0_ref_n) / sqrt(numel(metric_n));
    end
end

noiseless_table = table( ...
    p_branch, p_h, p_qhat, p_bias, p_centroid, p_asym, ...
    p_curve_deform, ...
    'VariableNames', { ...
    'branch','notch_halfwidth_bins','q_weak_hat','q_weak_signed_bias', ...
    'local_q_centroid','local_left_right_asymmetry', ...
    'normalized_curve_deformation'});

writetable(noiseless_table, ...
    fullfile(out_dir, 'noiseless_branch_results.csv'));

energy_table = table( ...
    H(:), strong_residual_energy_ratio, ...
    strong_residual_to_weak_energy, weak_energy_removed_fraction, ...
    'VariableNames', { ...
    'notch_halfwidth_bins', ...
    'strong_residual_energy_over_original_strong', ...
    'strong_residual_energy_over_weak', ...
    'weak_energy_removed_fraction'});

writetable(energy_table, ...
    fullfile(out_dir, 'operator_energy_results.csv'));

%% ========================================================================
% PART I: DEFAULT-WIDTH MONTE CARLO DECOMPOSITION

h0 = cfg.default_notch_halfwidth_bins;

strong_residual_h0 = apply_fixed_notch_operator( ...
    s_strong, cfg.q_strong, k_strong_fixed, h0, t, cfg);

branches_default = ["D0_WeakNoise"; ...
                    "D1_FilteredWeakNoise"; ...
                    "D2_WeakNoisePlusStrongResidual"; ...
                    "D3_CombinedFixedOperator"; ...
                    "D4_PracticalAdaptiveNotch"];

nB = numel(branches_default);

trial_id = zeros(M*nB,1);
branch_col = strings(M*nB,1);
qhat_col = nan(M*nB,1);
bias_col = nan(M*nB,1);
abserr_col = nan(M*nB,1);
success_col = false(M*nB,1);
centroid_col = nan(M*nB,1);
asym_col = nan(M*nB,1);
adaptive_bin_col = nan(M*nB,1);

row = 0;
example = struct();

for imc = 1:M
    noise = noise_bank(imc,:);

    D0 = s_weak + noise;

    D1 = apply_fixed_notch_operator( ...
        D0, cfg.q_strong, k_strong_fixed, h0, t, cfg);

    D2 = D0 + strong_residual_h0;

    D3 = D1 + strong_residual_h0;

    mixture = s_strong + s_weak + noise;

    [D4, k_adaptive] = apply_practical_adaptive_notch( ...
        mixture, cfg.q_strong, h0, t, cfg);

    signals = {D0, D1, D2, D3, D4};

    for ib = 1:nB
        row = row + 1;

        [qhat, metric, ~] = ...
            search_q_concentration(signals{ib}, q_full, D_full);

        [centroid, asym] = ...
            local_curve_shape(metric, q_full, cfg.q_weak, ...
            cfg.shape_halfwidth);

        qb = qhat - cfg.q_weak;
        qe = abs(qb);

        trial_id(row) = imc;
        branch_col(row) = branches_default(ib);
        qhat_col(row) = qhat;
        bias_col(row) = qb;
        abserr_col(row) = qe;
        success_col(row) = is_recovered(qe, cfg);
        centroid_col(row) = centroid;
        asym_col(row) = asym;

        if ib == 5
            adaptive_bin_col(row) = k_adaptive;
        else
            adaptive_bin_col(row) = k_strong_fixed;
        end

        if imc == 1
            example.(char(branches_default(ib))).metric = metric;
            example.(char(branches_default(ib))).signal = signals{ib};
        end
    end
end

default_trials = table( ...
    trial_id, branch_col, qhat_col, bias_col, abserr_col, ...
    success_col, centroid_col, asym_col, adaptive_bin_col, ...
    'VariableNames', { ...
    'trial_id','branch','q_weak_hat','q_weak_signed_bias', ...
    'q_weak_abs_error','weak_recovered','local_q_centroid', ...
    'local_left_right_asymmetry','notch_center_bin'});

writetable(default_trials, ...
    fullfile(out_dir, 'default_mc_trials.csv'));

%% Default summary
sum_branch = branches_default;
sum_recall = nan(nB,1);
sum_rmse = nan(nB,1);
sum_mae = nan(nB,1);
sum_bias = nan(nB,1);
sum_centroid_shift = nan(nB,1);
sum_asym = nan(nB,1);

for ib = 1:nB
    mask = default_trials.branch == branches_default(ib);

    qb = default_trials.q_weak_signed_bias(mask);
    qe = default_trials.q_weak_abs_error(mask);

    sum_recall(ib) = mean(default_trials.weak_recovered(mask));
    sum_rmse(ib) = sqrt(mean(qb.^2));
    sum_mae(ib) = mean(qe);
    sum_bias(ib) = mean(qb);
    sum_centroid_shift(ib) = ...
        mean(default_trials.local_q_centroid(mask) - cfg.q_weak);
    sum_asym(ib) = ...
        mean(default_trials.local_left_right_asymmetry(mask));
end

default_summary = table( ...
    sum_branch, sum_recall, sum_rmse, sum_mae, sum_bias, ...
    sum_centroid_shift, sum_asym, ...
    'VariableNames', { ...
    'branch','weak_recovery_rate','weak_q_rmse','weak_q_mae', ...
    'weak_q_signed_bias','mean_local_centroid_shift', ...
    'mean_local_left_right_asymmetry'});

writetable(default_summary, ...
    fullfile(out_dir, 'default_mc_summary.csv'));

%% Paired transition counts
succD0 = branch_success(default_trials, "D0_WeakNoise", M);
succD1 = branch_success(default_trials, "D1_FilteredWeakNoise", M);
succD2 = branch_success(default_trials, "D2_WeakNoisePlusStrongResidual", M);
succD3 = branch_success(default_trials, "D3_CombinedFixedOperator", M);
succD4 = branch_success(default_trials, "D4_PracticalAdaptiveNotch", M);

T01 = transition_counts(succD0, succD1);
T02 = transition_counts(succD0, succD2);
T23 = transition_counts(succD2, succD3);
T34 = transition_counts(succD3, succD4);

%% ========================================================================
% PART II: WIDTH SWEEP WITH MECHANISM DECOMPOSITION

branches_width = ["D0_WeakNoise"; ...
                  "D1_FilteredWeakNoise"; ...
                  "D2_WeakNoisePlusStrongResidual"; ...
                  "D3_CombinedFixedOperator"];

nBW = numel(branches_width);

nRows = M * nH * nBW;

w_trial = zeros(nRows,1);
w_h = zeros(nRows,1);
w_branch = strings(nRows,1);
w_qhat = nan(nRows,1);
w_bias = nan(nRows,1);
w_err = nan(nRows,1);
w_success = false(nRows,1);

row = 0;

for ih = 1:nH
    h = H(ih);

    strong_residual = apply_fixed_notch_operator( ...
        s_strong, cfg.q_strong, k_strong_fixed, h, t, cfg);

    for imc = 1:M
        noise = noise_bank(imc,:);

        D0 = s_weak + noise;

        D1 = apply_fixed_notch_operator( ...
            D0, cfg.q_strong, k_strong_fixed, h, t, cfg);

        D2 = D0 + strong_residual;

        D3 = D1 + strong_residual;

        signals = {D0, D1, D2, D3};

        for ib = 1:nBW
            row = row + 1;

            [qhat, ~, ~] = ...
                search_q_concentration(signals{ib}, q_full, D_full);

            qb = qhat - cfg.q_weak;
            qe = abs(qb);

            w_trial(row) = imc;
            w_h(row) = h;
            w_branch(row) = branches_width(ib);
            w_qhat(row) = qhat;
            w_bias(row) = qb;
            w_err(row) = qe;
            w_success(row) = is_recovered(qe, cfg);
        end
    end
end

width_trials = table( ...
    w_trial, w_h, w_branch, w_qhat, w_bias, w_err, w_success, ...
    'VariableNames', { ...
    'trial_id','notch_halfwidth_bins','branch','q_weak_hat', ...
    'q_weak_signed_bias','q_weak_abs_error','weak_recovered'});

writetable(width_trials, ...
    fullfile(out_dir, 'width_sweep_trials.csv'));

%% Width summary
nSum = nH * nBW;

ws_branch = strings(nSum,1);
ws_h = zeros(nSum,1);
ws_recall = nan(nSum,1);
ws_bias = nan(nSum,1);
ws_rmse = nan(nSum,1);
ws_mae = nan(nSum,1);

row = 0;

for ib = 1:nBW
    for ih = 1:nH
        row = row + 1;

        mask = width_trials.branch == branches_width(ib) & ...
            width_trials.notch_halfwidth_bins == H(ih);

        qb = width_trials.q_weak_signed_bias(mask);
        qe = width_trials.q_weak_abs_error(mask);

        ws_branch(row) = branches_width(ib);
        ws_h(row) = H(ih);
        ws_recall(row) = mean(width_trials.weak_recovered(mask));
        ws_bias(row) = mean(qb);
        ws_rmse(row) = sqrt(mean(qb.^2));
        ws_mae(row) = mean(qe);
    end
end

width_summary = table( ...
    ws_branch, ws_h, ws_recall, ws_bias, ws_rmse, ws_mae, ...
    'VariableNames', { ...
    'branch','notch_halfwidth_bins','weak_recovery_rate', ...
    'weak_q_signed_bias','weak_q_rmse','weak_q_mae'});

writetable(width_summary, ...
    fullfile(out_dir, 'width_sweep_summary.csv'));

%% ========================================================================
% CONSOLE SUMMARY

fprintf('================ A3 NOISELESS ANATOMY =============\n');
for ih = 1:nH
    h = H(ih);

    p0 = noiseless_table.q_weak_signed_bias( ...
        noiseless_table.notch_halfwidth_bins == h & ...
        noiseless_table.branch == "P0_WeakOnly");

    p1 = noiseless_table.q_weak_signed_bias( ...
        noiseless_table.notch_halfwidth_bins == h & ...
        noiseless_table.branch == "P1_FilteredWeakOnly");

    p2 = noiseless_table.q_weak_signed_bias( ...
        noiseless_table.notch_halfwidth_bins == h & ...
        noiseless_table.branch == "P2_WeakPlusStrongResidual");

    p3 = noiseless_table.q_weak_signed_bias( ...
        noiseless_table.notch_halfwidth_bins == h & ...
        noiseless_table.branch == "P3_CombinedFixedOperator");

    fprintf(['h=%d  Bias(P0/P1/P2/P3) = ' ...
        '%+0.5f / %+0.5f / %+0.5f / %+0.5f   ' ...
        'Es_res/Es=%.4f   Es_res/Ew=%.4f   weak_removed=%.4f\n'], ...
        h, p0, p1, p2, p3, ...
        strong_residual_energy_ratio(ih), ...
        strong_residual_to_weak_energy(ih), ...
        weak_energy_removed_fraction(ih));
end

fprintf('\n================ A3 DEFAULT MC =====================\n');
for ib = 1:nB
    fprintf('%-34s Recall=%.3f  Bias=%+0.5f  RMSE=%.5f\n', ...
        default_summary.branch(ib), ...
        default_summary.weak_recovery_rate(ib), ...
        default_summary.weak_q_signed_bias(ib), ...
        default_summary.weak_q_rmse(ib));
end

fprintf('\nPaired transitions:\n');
fprintf('D0 -> D1: SS=%d SF=%d FS=%d FF=%d\n', ...
    T01.SS, T01.SF, T01.FS, T01.FF);
fprintf('D0 -> D2: SS=%d SF=%d FS=%d FF=%d\n', ...
    T02.SS, T02.SF, T02.FS, T02.FF);
fprintf('D2 -> D3: SS=%d SF=%d FS=%d FF=%d\n', ...
    T23.SS, T23.SF, T23.FS, T23.FF);
fprintf('D3 -> D4: SS=%d SF=%d FS=%d FF=%d\n', ...
    T34.SS, T34.SF, T34.FS, T34.FF);

fprintf('\n================ A3 WIDTH SWEEP ====================\n');
for row = 1:height(width_summary)
    fprintf('%-34s h=%d Recall=%.3f Bias=%+0.5f\n', ...
        width_summary.branch(row), ...
        width_summary.notch_halfwidth_bins(row), ...
        width_summary.weak_recovery_rate(row), ...
        width_summary.weak_q_signed_bias(row));
end
fprintf('====================================================\n');

%% Text summary
fid = fopen(fullfile(out_dir, 'summary.txt'), 'w');

fprintf(fid, 'EXP009-A3 Operator-Induced Peak-Shift Test\n');
fprintf(fid, '==========================================\n\n');

fprintf(fid, 'MC trials: %d\n', cfg.num_mc);
fprintf(fid, 'SNR: %.3f dB\n', cfg.snr_db);
fprintf(fid, 'q strong / weak: %.6f / %.6f\n', ...
    cfg.q_strong, cfg.q_weak);
fprintf(fid, 'A weak / A strong: %.6f\n', cfg.A_weak_ratio);
fprintf(fid, 'Fixed strong FFT bin: %d\n', k_strong_fixed);
fprintf(fid, 'Default notch halfwidth: %d\n\n', h0);

fprintf(fid, 'Noiseless anatomy\n');
fprintf(fid, '-----------------\n');

for ih = 1:nH
    h = H(ih);

    p1 = noiseless_table.q_weak_signed_bias( ...
        noiseless_table.notch_halfwidth_bins == h & ...
        noiseless_table.branch == "P1_FilteredWeakOnly");

    p2 = noiseless_table.q_weak_signed_bias( ...
        noiseless_table.notch_halfwidth_bins == h & ...
        noiseless_table.branch == "P2_WeakPlusStrongResidual");

    p3 = noiseless_table.q_weak_signed_bias( ...
        noiseless_table.notch_halfwidth_bins == h & ...
        noiseless_table.branch == "P3_CombinedFixedOperator");

    fprintf(fid, ...
        ['h=%d: P1 bias=%+.8f, P2 bias=%+.8f, P3 bias=%+.8f, ' ...
         'strong residual/original strong energy=%.8f, ' ...
         'strong residual/weak energy=%.8f, weak energy removed=%.8f\n'], ...
        h, p1, p2, p3, ...
        strong_residual_energy_ratio(ih), ...
        strong_residual_to_weak_energy(ih), ...
        weak_energy_removed_fraction(ih));
end

fprintf(fid, '\nDefault Monte Carlo\n');
fprintf(fid, '-------------------\n');

for ib = 1:nB
    fprintf(fid, '%s: Recall=%.6f, Bias=%+.8f, RMSE=%.8f, MAE=%.8f\n', ...
        default_summary.branch(ib), ...
        default_summary.weak_recovery_rate(ib), ...
        default_summary.weak_q_signed_bias(ib), ...
        default_summary.weak_q_rmse(ib), ...
        default_summary.weak_q_mae(ib));
end

fprintf(fid, '\nTransitions\n');
fprintf(fid, 'D0->D1: SS=%d SF=%d FS=%d FF=%d\n', ...
    T01.SS, T01.SF, T01.FS, T01.FF);
fprintf(fid, 'D0->D2: SS=%d SF=%d FS=%d FF=%d\n', ...
    T02.SS, T02.SF, T02.FS, T02.FF);
fprintf(fid, 'D2->D3: SS=%d SF=%d FS=%d FF=%d\n', ...
    T23.SS, T23.SF, T23.FS, T23.FF);
fprintf(fid, 'D3->D4: SS=%d SF=%d FS=%d FF=%d\n', ...
    T34.SS, T34.SF, T34.FS, T34.FF);

fclose(fid);

%% Figures
make_figures(out_dir, cfg, q_full, H, ...
    noiseless_table, energy_table, default_summary, default_trials, ...
    width_summary, example);

%% Save MAT
results = struct();
results.cfg = cfg;
results.k_strong_fixed = k_strong_fixed;
results.noiseless_table = noiseless_table;
results.energy_table = energy_table;
results.default_trials = default_trials;
results.default_summary = default_summary;
results.transition_D0_D1 = T01;
results.transition_D0_D2 = T02;
results.transition_D2_D3 = T23;
results.transition_D3_D4 = T34;
results.width_trials = width_trials;
results.width_summary = width_summary;
results.example = example;

save(fullfile(out_dir, 'exp09a3_results.mat'), 'results', '-v7.3');

fprintf('\nSaved EXP009-A3 outputs to:\n%s\n\n', out_dir);

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
function k0 = get_strong_notch_bin(s_strong, q_strong, t, cfg)
mu = cfg.mu_scale * (q_strong - cfg.q_ref);
dechirp = exp(-1j*pi*mu*t.^2);
Z = fft(s_strong .* dechirp);
[~, k0] = max(abs(Z).^2);
end

%% ========================================================================
function r = apply_fixed_notch_operator( ...
    x, q_used, k_fixed, halfwidth_bins, t, cfg)

mu = cfg.mu_scale * (q_used - cfg.q_ref);

dechirp = exp(-1j*pi*mu*t.^2);
rechirp = conj(dechirp);

z = x .* dechirp;
Z = fft(z);

mask = ones(1, numel(Z));

for dk = -halfwidth_bins:halfwidth_bins
    kk = mod((k_fixed-1) + dk, numel(Z)) + 1;
    mask(kk) = 0;
end

z_res = ifft(Z .* mask);
r = z_res .* rechirp;
end

%% ========================================================================
function [r, k0] = apply_practical_adaptive_notch( ...
    x, q_used, halfwidth_bins, t, cfg)

mu = cfg.mu_scale * (q_used - cfg.q_ref);

dechirp = exp(-1j*pi*mu*t.^2);
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
function [centroid, asym] = local_curve_shape( ...
    metric, q_grid, q0, halfwidth)

metric = metric(:);
q = q_grid(:);

mask = abs(q - q0) <= halfwidth;

qm = q(mask);
em = metric(mask);

den = sum(em);

if den <= eps
    centroid = q0;
    asym = 0;
    return;
end

centroid = sum(qm .* em) / den;

left = sum(em(qm < q0));
right = sum(em(qm > q0));

asym = (right - left) / max(right + left, eps);
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

%% ========================================================================
function s = branch_success(tbl, branch_name, M)
mask = tbl.branch == branch_name;
tmp = tbl(mask, :);
tmp = sortrows(tmp, 'trial_id');

if height(tmp) ~= M
    error('Unexpected number of rows for branch %s.', branch_name);
end

s = tmp.weak_recovered;
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
    noiseless_table, energy_table, default_summary, default_trials, ...
    width_summary, example)

%% Fig 1: noiseless branch q bias vs width
fig = figure('Visible', cfg.figure_visible);

branches = ["P1_FilteredWeakOnly", ...
            "P2_WeakPlusStrongResidual", ...
            "P3_CombinedFixedOperator"];

for ib = 1:numel(branches)
    mask = noiseless_table.branch == branches(ib);
    plot(noiseless_table.notch_halfwidth_bins(mask), ...
        noiseless_table.q_weak_signed_bias(mask), ...
        '-o', 'LineWidth', 1.5);
    hold on;
end

yline(0, '--');
xlabel('Notch halfwidth (FFT bins)');
ylabel('Noiseless weak-q signed bias');
title('A3 Noiseless Peak-Shift Decomposition');
legend('Filtered weak only', ...
       'Weak + filtered strong residual', ...
       'Combined fixed operator', ...
       'Location', 'best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir, 'fig01_noiseless_q_bias.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 2: operator energy anatomy
fig = figure('Visible', cfg.figure_visible);

plot(energy_table.notch_halfwidth_bins, ...
    energy_table.strong_residual_energy_over_original_strong, ...
    '-o', 'LineWidth', 1.5);
hold on;

plot(energy_table.notch_halfwidth_bins, ...
    energy_table.strong_residual_energy_over_weak, ...
    '-s', 'LineWidth', 1.5);

plot(energy_table.notch_halfwidth_bins, ...
    energy_table.weak_energy_removed_fraction, ...
    '-^', 'LineWidth', 1.5);

xlabel('Notch halfwidth (FFT bins)');
ylabel('Energy ratio / removed fraction');
title('A3 Operator Energy Anatomy');
legend('Strong residual / original strong', ...
       'Strong residual / weak', ...
       'Weak energy removed by operator', ...
       'Location', 'best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir, 'fig02_operator_energy.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 3: default MC recovery
fig = figure('Visible', cfg.figure_visible);

bar(default_summary.weak_recovery_rate);
ylim([0 1]);

xticks(1:height(default_summary));
xticklabels({'D0 Baseline', 'D1 Filter weak/noise', ...
    'D2 + strong residual', 'D3 Combined', 'D4 Practical'});
xtickangle(25);

ylabel('Weak-component recovery rate');
title('A3 Default-Width Monte Carlo Recovery');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir, 'fig03_default_mc_recovery.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 4: default signed-bias distribution
fig = figure('Visible', cfg.figure_visible);

branchesD = default_summary.branch;
grp = [];
vals = [];

for ib = 1:numel(branchesD)
    mask = default_trials.branch == branchesD(ib);
    grp = [grp; ib*ones(sum(mask),1)]; %#ok<AGROW>
    vals = [vals; default_trials.q_weak_signed_bias(mask)]; %#ok<AGROW>
end

boxchart(grp, vals);
yline(0, '--');

xticks(1:numel(branchesD));
xticklabels({'D0', 'D1', 'D2', 'D3', 'D4'});

ylabel('q_{weak}^{hat} - q_{weak}');
title('A3 Default-Width Signed Weak-q Bias');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir, 'fig04_default_mc_bias.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 5: width sweep recall
fig = figure('Visible', cfg.figure_visible);

branchesW = ["D0_WeakNoise", ...
             "D1_FilteredWeakNoise", ...
             "D2_WeakNoisePlusStrongResidual", ...
             "D3_CombinedFixedOperator"];

labelsW = {'D0 baseline', ...
           'D1 operator-only', ...
           'D2 strong-residual-only', ...
           'D3 combined'};

for ib = 1:numel(branchesW)
    mask = width_summary.branch == branchesW(ib);

    plot(width_summary.notch_halfwidth_bins(mask), ...
        width_summary.weak_recovery_rate(mask), ...
        '-o', 'LineWidth', 1.5);
    hold on;
end

ylim([0 1]);
xlabel('Notch halfwidth (FFT bins)');
ylabel('Weak recovery rate');
title('A3 Width Sweep: Failure-Source Decomposition');
legend(labelsW, 'Location', 'best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir, 'fig05_width_vs_recovery.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 6: width sweep signed bias
fig = figure('Visible', cfg.figure_visible);

for ib = 1:numel(branchesW)
    mask = width_summary.branch == branchesW(ib);

    plot(width_summary.notch_halfwidth_bins(mask), ...
        width_summary.weak_q_signed_bias(mask), ...
        '-o', 'LineWidth', 1.5);
    hold on;
end

yline(0, '--');
xlabel('Notch halfwidth (FFT bins)');
ylabel('Mean signed weak-q bias');
title('A3 Width Sweep: Peak Shift by Mechanism');
legend(labelsW, 'Location', 'best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir, 'fig06_width_vs_bias.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 7: residual-strong energy vs weak bias
% Use noiseless P3 bias to make the relationship visually direct.
p3mask = noiseless_table.branch == "P3_CombinedFixedOperator";

fig = figure('Visible', cfg.figure_visible);

plot(energy_table.strong_residual_energy_over_weak, ...
    noiseless_table.q_weak_signed_bias(p3mask), ...
    '-o', 'LineWidth', 1.5);

xlabel('Filtered strong residual energy / weak energy');
ylabel('Noiseless weak-q signed bias');
title('A3 Residual-Strong Energy vs Peak Shift');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir, 'fig07_residual_energy_vs_bias.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 8: representative concentration curves
fig = figure('Visible', cfg.figure_visible);

branchesEx = ["D0_WeakNoise", ...
              "D1_FilteredWeakNoise", ...
              "D2_WeakNoisePlusStrongResidual", ...
              "D3_CombinedFixedOperator", ...
              "D4_PracticalAdaptiveNotch"];

labelsEx = {'D0 baseline', ...
            'D1 operator-only', ...
            'D2 strong-residual-only', ...
            'D3 combined fixed', ...
            'D4 practical'};

for ib = 1:numel(branchesEx)
    metric = example.(char(branchesEx(ib))).metric;

    plot(q_full, normalize01(metric), ...
        'LineWidth', 1.2);
    hold on;
end

xline(cfg.q_weak, ':', 'True q_{weak}');

xlabel('q candidate');
ylabel('Normalized concentration metric');
title('A3 Representative Peak-Shift Decomposition');
legend(labelsEx, 'Location', 'best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir, 'fig08_example_concentration_curves.png'), ...
    'Resolution', 180);
close(fig);

end
