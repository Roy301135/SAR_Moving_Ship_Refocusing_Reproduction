function results = exp09b1_failure_mechanism_map()
%EXP09B1_FAILURE_MECHANISM_MAP
% EXP009 / Pilot-01 / Experiment B1
%
% Failure / Mechanism Map
%
% -------------------------------------------------------------------------
% Why B1 is different from the originally planned "failure heatmap"
% -------------------------------------------------------------------------
% A1-A4 established a specific mechanism:
%
%   filtered strong residual
%       -> coherent cross-term with weak response
%       -> local concentration-curve perturbation
%       -> weak-q bias / failure
%
% Therefore B1 does NOT merely ask "where does the method fail?"
%
% It asks:
%
%   (1) Where is the weak component intrinsically recoverable?
%   (2) Where does the filtered strong residual create an additional
%       recovery penalty?
%   (3) Does the coherent cross-term remain the dominant local mechanism?
%   (4) Where does the first-order perturbation approximation remain valid,
%       and where does the problem become catastrophic / multi-peak?
%
% -------------------------------------------------------------------------
% Parameter axes
% -------------------------------------------------------------------------
%   r_A = A_weak / A_strong
%   signed separation = q_strong - q_weak
%   SNR (referenced to strong-component power)
%
% A4 showed that the interference is phase-sensitive. Therefore B1 keeps
% SIGNED separation rather than collapsing to |q_strong-q_weak|.
%
% -------------------------------------------------------------------------
% Two Monte-Carlo branches per cell
% -------------------------------------------------------------------------
% Baseline:
%   s_weak + n
%
% Residual:
%   s_weak + e_strong + n
%
% where e_strong is the filtered strong residual after the fixed CLEAN
% operator with true q_strong.
%
% The same noise realization is used for baseline and residual branches.
%
% -------------------------------------------------------------------------
% Noiseless mechanism diagnostics per (r_A, signed separation)
% -------------------------------------------------------------------------
% Matched weak-template response:
%
%   C(q) = C_w(q) + C_e(q)
%
%   P(q) = P_w + P_e + P_cross
%
% First-order predicted shift:
%
%   delta_q ~= - DeltaP'(q_w) / P_w''(q_w)
%
% with DeltaP = P_e + P_cross.
%
% -------------------------------------------------------------------------
% Run:
%   results = exp09b1_failure_mechanism_map;

cfg = config_exp09b1();

%% Paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);

if isempty(cfg.output_dir)
    code_dir = fileparts(this_dir);
    paper_root = fileparts(code_dir);
    out_dir = fullfile(paper_root, 'results', 'exp09_pilot01', ...
        'exp09b1_failure_mechanism_map');
else
    out_dir = cfg.output_dir;
end

if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

fprintf('\n============================================================\n');
fprintf(' EXP009-B1 / Failure & Mechanism Map\n');
fprintf('============================================================\n');
fprintf('Output: %s\n', out_dir);

rng(cfg.seed, 'twister');

%% Axes
N = cfg.N;
n = 0:N-1;
t = (n - N/2) / N;

q_search = cfg.q_search_min : cfg.q_search_step : cfg.q_search_max;
D_search = build_dechirp_dictionary(q_search, t, cfg);

q_geom = (cfg.q_weak - cfg.q_geom_halfwidth) : ...
    cfg.q_geom_step : ...
    (cfg.q_weak + cfg.q_geom_halfwidth);

ratios = cfg.weak_ratio_list;
seps = cfg.signed_separation_list;
snrs = cfg.snr_db_list;

nR = numel(ratios);
nD = numel(seps);
nS = numel(snrs);
M = cfg.num_mc;

fprintf('MC trials/cell                 = %d\n', M);
fprintf('Weak ratio list                = [%s]\n', num2str(ratios));
fprintf('Signed separation list         = [%s]\n', num2str(seps));
fprintf('SNR list                       = [%s] dB\n', num2str(snrs));
fprintf('q candidates/search            = %d\n', numel(q_search));
fprintf('Total map cells                = %d\n', nR*nD*nS);
fprintf('Residual-branch searches       = %d\n', nR*nD*nS*M);
fprintf('Baseline searches (reused)     = %d\n\n', nR*nS*M);

%% ------------------------------------------------------------------------
% Precompute strong residuals for each signed separation
%
% A_strong is fixed at 1.0.
strong_q = cfg.q_weak + seps;

strong_signal = cell(nD,1);
strong_residual = cell(nD,1);
strong_notch_bin = nan(nD,1);
strong_residual_energy = nan(nD,1);

for id = 1:nD
    q_s = strong_q(id);

    s_s = synth_lfm(cfg.A_strong, q_s, cfg.f_strong, ...
        cfg.phi_strong, t, cfg);

    k_s = get_strong_notch_bin(s_s, q_s, t, cfg);

    e_s = apply_fixed_notch_operator( ...
        s_s, q_s, k_s, cfg.notch_halfwidth_bins, t, cfg);

    strong_signal{id} = s_s;
    strong_residual{id} = e_s;
    strong_notch_bin(id) = k_s;
    strong_residual_energy(id) = sum(abs(e_s).^2);
end

%% ------------------------------------------------------------------------
% PART I: NOISELESS MECHANISM MAP
%
% One row per (weak ratio, signed separation).
nMechRows = nR*nD;

m_ratio = nan(nMechRows,1);
m_sep = nan(nMechRows,1);
m_qs = nan(nMechRows,1);
m_EresEw = nan(nMechRows,1);

m_operational_bias = nan(nMechRows,1);
m_matched_bias = nan(nMechRows,1);
m_predicted_bias = nan(nMechRows,1);

m_dPe = nan(nMechRows,1);
m_dPcross = nan(nMechRows,1);
m_dDelta = nan(nMechRows,1);
m_ddPw = nan(nMechRows,1);

m_cross_dominance = nan(nMechRows,1);
m_first_order_abs_error = nan(nMechRows,1);
m_first_order_rel_error = nan(nMechRows,1);

row = 0;

for ir = 1:nR
    rA = ratios(ir);

    s_w = synth_lfm(cfg.A_strong*rA, cfg.q_weak, cfg.f_weak, ...
        cfg.phi_weak, t, cfg);

    Ew = sum(abs(s_w).^2);

    for id = 1:nD
        row = row + 1;

        e_s = strong_residual{id};
        r_total = s_w + e_s;

        [qhat_op, ~, ~] = ...
            search_q_concentration(r_total, q_search, D_search);

        [Cw, Ce, Ct] = matched_response_decomposition( ...
            s_w, e_s, q_geom, t, cfg);

        Pw = abs(Cw).^2;
        Pe = abs(Ce).^2;
        Pcross = 2*real(Cw .* conj(Ce));
        DeltaP = Pe + Pcross;
        Ptotal = abs(Ct).^2;

        [~, idx_match] = max(Ptotal);
        qhat_match = q_geom(idx_match);

        [dPe, dPcross, dDelta, ddPw] = ...
            local_derivatives(q_geom, Pe, Pcross, DeltaP, Pw, ...
            cfg.q_weak, cfg.deriv_offset);

        pred_bias = -dDelta/ddPw;
        match_bias = qhat_match - cfg.q_weak;
        op_bias = qhat_op - cfg.q_weak;

        abs_fo_err = abs(match_bias - pred_bias);
        rel_fo_err = abs_fo_err / ...
            max(abs(match_bias), cfg.q_geom_step);

        m_ratio(row) = rA;
        m_sep(row) = seps(id);
        m_qs(row) = strong_q(id);
        m_EresEw(row) = strong_residual_energy(id) / Ew;

        m_operational_bias(row) = op_bias;
        m_matched_bias(row) = match_bias;
        m_predicted_bias(row) = pred_bias;

        m_dPe(row) = dPe;
        m_dPcross(row) = dPcross;
        m_dDelta(row) = dDelta;
        m_ddPw(row) = ddPw;

        m_cross_dominance(row) = ...
            abs(dPcross) / max(abs(dPe), eps);

        m_first_order_abs_error(row) = abs_fo_err;
        m_first_order_rel_error(row) = rel_fo_err;
    end
end

mechanism_table = table( ...
    m_ratio, m_sep, m_qs, m_EresEw, ...
    m_operational_bias, m_matched_bias, m_predicted_bias, ...
    m_dPe, m_dPcross, m_dDelta, m_ddPw, ...
    m_cross_dominance, ...
    m_first_order_abs_error, m_first_order_rel_error, ...
    'VariableNames', { ...
    'weak_ratio','signed_separation','q_strong', ...
    'strong_residual_energy_over_weak', ...
    'noiseless_operational_bias','matched_response_bias', ...
    'first_order_predicted_bias', ...
    'dP_residual_dq','dP_cross_dq','dDeltaP_dq','ddP_weak_dq2', ...
    'cross_slope_dominance_ratio', ...
    'first_order_abs_error','first_order_rel_error'});

writetable(mechanism_table, ...
    fullfile(out_dir, 'mechanism_map_noiseless.csv'));

%% ------------------------------------------------------------------------
% PART II: MONTE-CARLO FAILURE MAP
%
% Baseline depends only on (weak ratio, SNR), not on separation.
% Compute baseline once and reuse it across all separation cells.
%
% Same noise bank is reused across ALL parameter cells within each SNR.
baseline_recall = nan(nR,nS);
baseline_mean_bias = nan(nR,nS);
baseline_rmse = nan(nR,nS);
baseline_mae = nan(nR,nS);
baseline_cat_rate = nan(nR,nS);

% Store per-trial baseline results for reuse.
baseline_qhat = nan(M,nR,nS);
baseline_success = false(M,nR,nS);
baseline_cat = false(M,nR,nS);

% One shared noise bank per SNR.
noise_bank = cell(nS,1);

% Strong reference power = 1 for our amplitude-1 LFM, but calculate it
% explicitly to keep the code self-documenting.
s_ref = strong_signal{1};
Pstrong = mean(abs(s_ref).^2);

for is = 1:nS
    snr_db = snrs(is);

    noise_var = Pstrong / (10^(snr_db/10));

    noise_bank{is} = sqrt(noise_var/2) * ...
        (randn(M,N) + 1j*randn(M,N));

    for ir = 1:nR
        rA = ratios(ir);

        s_w = synth_lfm(cfg.A_strong*rA, cfg.q_weak, ...
            cfg.f_weak, cfg.phi_weak, t, cfg);

        qh = nan(M,1);
        qb = nan(M,1);
        qe = nan(M,1);
        succ = false(M,1);
        cat = false(M,1);

        for imc = 1:M
            x0 = s_w + noise_bank{is}(imc,:);

            [qh(imc), ~, ~] = ...
                search_q_concentration(x0, q_search, D_search);

            qb(imc) = qh(imc) - cfg.q_weak;
            qe(imc) = abs(qb(imc));

            succ(imc) = qe(imc) <= ...
                (cfg.tau_q + cfg.success_tol);

            cat(imc) = qe(imc) >= ...
                (cfg.catastrophic_error_q - cfg.success_tol);
        end

        baseline_qhat(:,ir,is) = qh;
        baseline_success(:,ir,is) = succ;
        baseline_cat(:,ir,is) = cat;

        baseline_recall(ir,is) = mean(succ);
        baseline_mean_bias(ir,is) = mean(qb);
        baseline_rmse(ir,is) = sqrt(mean(qb.^2));
        baseline_mae(ir,is) = mean(qe);
        baseline_cat_rate(ir,is) = mean(cat);
    end
end

%% Residual map rows
nPerfRows = nR*nD*nS;

p_ratio = nan(nPerfRows,1);
p_sep = nan(nPerfRows,1);
p_snr = nan(nPerfRows,1);

p_base_recall = nan(nPerfRows,1);
p_res_recall = nan(nPerfRows,1);
p_recall_penalty = nan(nPerfRows,1);

p_base_bias = nan(nPerfRows,1);
p_res_bias = nan(nPerfRows,1);
p_bias_change = nan(nPerfRows,1);

p_res_rmse = nan(nPerfRows,1);
p_res_mae = nan(nPerfRows,1);

p_base_cat = nan(nPerfRows,1);
p_res_cat = nan(nPerfRows,1);
p_cat_increase = nan(nPerfRows,1);

p_EresEw = nan(nPerfRows,1);
p_dPcross = nan(nPerfRows,1);
p_pred_bias = nan(nPerfRows,1);
p_match_bias = nan(nPerfRows,1);

p_success_to_failure = nan(nPerfRows,1);
p_failure_to_success = nan(nPerfRows,1);

%% Trial-level table for residual branch + paired baseline labels
nTrialRows = nR*nD*nS*M;

t_trial = zeros(nTrialRows,1);
t_ratio = nan(nTrialRows,1);
t_sep = nan(nTrialRows,1);
t_snr = nan(nTrialRows,1);

t_base_qhat = nan(nTrialRows,1);
t_res_qhat = nan(nTrialRows,1);

t_base_success = false(nTrialRows,1);
t_res_success = false(nTrialRows,1);

t_res_bias = nan(nTrialRows,1);
t_res_abs_error = nan(nTrialRows,1);
t_res_cat = false(nTrialRows,1);

rowPerf = 0;
rowTrial = 0;

for is = 1:nS
    snr_db = snrs(is);

    for ir = 1:nR
        rA = ratios(ir);

        s_w = synth_lfm(cfg.A_strong*rA, cfg.q_weak, ...
            cfg.f_weak, cfg.phi_weak, t, cfg);

        for id = 1:nD
            rowPerf = rowPerf + 1;

            e_s = strong_residual{id};

            qh_res = nan(M,1);
            qb_res = nan(M,1);
            qe_res = nan(M,1);
            succ_res = false(M,1);
            cat_res = false(M,1);

            for imc = 1:M
                xr = s_w + e_s + noise_bank{is}(imc,:);

                [qh_res(imc), ~, ~] = ...
                    search_q_concentration(xr, q_search, D_search);

                qb_res(imc) = qh_res(imc) - cfg.q_weak;
                qe_res(imc) = abs(qb_res(imc));

                succ_res(imc) = qe_res(imc) <= ...
                    (cfg.tau_q + cfg.success_tol);

                cat_res(imc) = qe_res(imc) >= ...
                    (cfg.catastrophic_error_q - cfg.success_tol);

                rowTrial = rowTrial + 1;

                t_trial(rowTrial) = imc;
                t_ratio(rowTrial) = rA;
                t_sep(rowTrial) = seps(id);
                t_snr(rowTrial) = snr_db;

                t_base_qhat(rowTrial) = baseline_qhat(imc,ir,is);
                t_res_qhat(rowTrial) = qh_res(imc);

                t_base_success(rowTrial) = ...
                    baseline_success(imc,ir,is);

                t_res_success(rowTrial) = succ_res(imc);

                t_res_bias(rowTrial) = qb_res(imc);
                t_res_abs_error(rowTrial) = qe_res(imc);
                t_res_cat(rowTrial) = cat_res(imc);
            end

            bSucc = baseline_success(:,ir,is);
            rSucc = succ_res;

            p_ratio(rowPerf) = rA;
            p_sep(rowPerf) = seps(id);
            p_snr(rowPerf) = snr_db;

            p_base_recall(rowPerf) = baseline_recall(ir,is);
            p_res_recall(rowPerf) = mean(succ_res);
            p_recall_penalty(rowPerf) = ...
                baseline_recall(ir,is) - mean(succ_res);

            p_base_bias(rowPerf) = baseline_mean_bias(ir,is);
            p_res_bias(rowPerf) = mean(qb_res);
            p_bias_change(rowPerf) = ...
                mean(qb_res) - baseline_mean_bias(ir,is);

            p_res_rmse(rowPerf) = sqrt(mean(qb_res.^2));
            p_res_mae(rowPerf) = mean(qe_res);

            p_base_cat(rowPerf) = baseline_cat_rate(ir,is);
            p_res_cat(rowPerf) = mean(cat_res);
            p_cat_increase(rowPerf) = ...
                mean(cat_res) - baseline_cat_rate(ir,is);

            % Attach corresponding noiseless mechanism metrics.
            mmask = mechanism_table.weak_ratio == rA & ...
                mechanism_table.signed_separation == seps(id);

            p_EresEw(rowPerf) = ...
                mechanism_table.strong_residual_energy_over_weak(mmask);

            p_dPcross(rowPerf) = ...
                mechanism_table.dP_cross_dq(mmask);

            p_pred_bias(rowPerf) = ...
                mechanism_table.first_order_predicted_bias(mmask);

            p_match_bias(rowPerf) = ...
                mechanism_table.matched_response_bias(mmask);

            p_success_to_failure(rowPerf) = sum(bSucc & ~rSucc);
            p_failure_to_success(rowPerf) = sum(~bSucc & rSucc);
        end
    end
end

performance_table = table( ...
    p_ratio, p_sep, p_snr, ...
    p_base_recall, p_res_recall, p_recall_penalty, ...
    p_base_bias, p_res_bias, p_bias_change, ...
    p_res_rmse, p_res_mae, ...
    p_base_cat, p_res_cat, p_cat_increase, ...
    p_EresEw, p_dPcross, p_pred_bias, p_match_bias, ...
    p_success_to_failure, p_failure_to_success, ...
    'VariableNames', { ...
    'weak_ratio','signed_separation','snr_db', ...
    'baseline_recovery_rate','residual_recovery_rate', ...
    'residual_recovery_penalty', ...
    'baseline_mean_signed_bias','residual_mean_signed_bias', ...
    'residual_induced_bias_change', ...
    'residual_q_rmse','residual_q_mae', ...
    'baseline_catastrophic_rate','residual_catastrophic_rate', ...
    'catastrophic_rate_increase', ...
    'strong_residual_energy_over_weak','dP_cross_dq', ...
    'first_order_predicted_bias','matched_response_bias', ...
    'paired_success_to_failure_count','paired_failure_to_success_count'});

writetable(performance_table, ...
    fullfile(out_dir, 'performance_map_mc.csv'));

trial_table = table( ...
    t_trial, t_ratio, t_sep, t_snr, ...
    t_base_qhat, t_res_qhat, ...
    t_base_success, t_res_success, ...
    t_res_bias, t_res_abs_error, t_res_cat, ...
    'VariableNames', { ...
    'trial_id','weak_ratio','signed_separation','snr_db', ...
    'baseline_q_hat','residual_q_hat', ...
    'baseline_success','residual_success', ...
    'residual_signed_bias','residual_abs_error', ...
    'residual_catastrophic'});

writetable(trial_table, ...
    fullfile(out_dir, 'mc_trial_level.csv'));

%% ------------------------------------------------------------------------
% Baseline summary table
b_rows = nR*nS;

b_ratio = nan(b_rows,1);
b_snr = nan(b_rows,1);
b_recall = nan(b_rows,1);
b_bias = nan(b_rows,1);
b_rmse = nan(b_rows,1);
b_mae = nan(b_rows,1);
b_cat = nan(b_rows,1);

row = 0;

for is = 1:nS
    for ir = 1:nR
        row = row + 1;

        b_ratio(row) = ratios(ir);
        b_snr(row) = snrs(is);
        b_recall(row) = baseline_recall(ir,is);
        b_bias(row) = baseline_mean_bias(ir,is);
        b_rmse(row) = baseline_rmse(ir,is);
        b_mae(row) = baseline_mae(ir,is);
        b_cat(row) = baseline_cat_rate(ir,is);
    end
end

baseline_table = table( ...
    b_ratio, b_snr, b_recall, b_bias, b_rmse, b_mae, b_cat, ...
    'VariableNames', { ...
    'weak_ratio','snr_db','baseline_recovery_rate', ...
    'baseline_mean_signed_bias','baseline_q_rmse','baseline_q_mae', ...
    'baseline_catastrophic_rate'});

writetable(baseline_table, ...
    fullfile(out_dir, 'baseline_summary.csv'));

%% ------------------------------------------------------------------------
% Console summary
fprintf('================ B1 MECHANISM SUMMARY ==============\n');

fprintf('Median cross-slope dominance |dPcross|/|dPe| = %.2f\n', ...
    median(mechanism_table.cross_slope_dominance_ratio));

fprintf('Median first-order abs error                 = %.6f\n', ...
    median(mechanism_table.first_order_abs_error));

fprintf('Median first-order relative error            = %.3f\n', ...
    median(mechanism_table.first_order_rel_error));

fprintf('\n================ B1 PERFORMANCE SUMMARY =============\n');

for is = 1:nS
    snr_db = snrs(is);

    mask = performance_table.snr_db == snr_db;

    fprintf(['SNR=%+g dB: mean baseline recall=%.3f, ' ...
        'mean residual recall=%.3f, mean penalty=%.3f, ' ...
        'mean catastrophic increase=%.3f\n'], ...
        snr_db, ...
        mean(performance_table.baseline_recovery_rate(mask)), ...
        mean(performance_table.residual_recovery_rate(mask)), ...
        mean(performance_table.residual_recovery_penalty(mask)), ...
        mean(performance_table.catastrophic_rate_increase(mask)));
end

fprintf('=====================================================\n');

%% Text summary
fid = fopen(fullfile(out_dir, 'summary.txt'), 'w');

fprintf(fid, 'EXP009-B1 Failure / Mechanism Map\n');
fprintf(fid, '================================\n\n');

fprintf(fid, 'MC trials/cell: %d\n', cfg.num_mc);
fprintf(fid, 'Weak ratios: %s\n', num2str(ratios));
fprintf(fid, 'Signed separations: %s\n', num2str(seps));
fprintf(fid, 'SNRs: %s dB\n', num2str(snrs));
fprintf(fid, 'CLEAN notch halfwidth: %d bins\n\n', ...
    cfg.notch_halfwidth_bins);

fprintf(fid, 'Mechanism summary\n');
fprintf(fid, '-----------------\n');
fprintf(fid, ...
    'Median cross-slope dominance |dPcross|/|dPe|: %.8f\n', ...
    median(mechanism_table.cross_slope_dominance_ratio));
fprintf(fid, ...
    'Median first-order abs error: %.8f\n', ...
    median(mechanism_table.first_order_abs_error));
fprintf(fid, ...
    'Median first-order relative error: %.8f\n\n', ...
    median(mechanism_table.first_order_rel_error));

fprintf(fid, 'Performance summary\n');
fprintf(fid, '-------------------\n');

for is = 1:nS
    snr_db = snrs(is);
    mask = performance_table.snr_db == snr_db;

    fprintf(fid, ...
        ['SNR=%+g dB: baseline recall=%.6f, residual recall=%.6f, ' ...
         'penalty=%.6f, catastrophic increase=%.6f\n'], ...
        snr_db, ...
        mean(performance_table.baseline_recovery_rate(mask)), ...
        mean(performance_table.residual_recovery_rate(mask)), ...
        mean(performance_table.residual_recovery_penalty(mask)), ...
        mean(performance_table.catastrophic_rate_increase(mask)));
end

fclose(fid);

%% Figures
make_figures(out_dir, cfg, mechanism_table, performance_table);

%% Save
results = struct();
results.cfg = cfg;
results.mechanism_table = mechanism_table;
results.performance_table = performance_table;
results.trial_table = trial_table;
results.baseline_table = baseline_table;

save(fullfile(out_dir, 'exp09b1_results.mat'), 'results', '-v7.3');

fprintf('\nSaved EXP009-B1 outputs to:\n%s\n\n', out_dir);

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
% Safe explicit broadcasting through BSXFUN avoids row/column ambiguity.
Y = fft(bsxfun(@times, D, x), [], 2);
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
function [Cw, Ce, Ct] = matched_response_decomposition( ...
    s_weak, e_strong, q_grid, t, cfg)
% Oracle diagnostic.
%
% A is [Nq x N]. Each row is a candidate weak template.
mu = cfg.mu_scale * (q_grid(:) - cfg.q_ref);

A = exp(1j * (pi*(mu * (t.^2)) + 2*pi*cfg.f_weak*t));

if size(A,2) ~= numel(s_weak) || ...
        size(A,2) ~= numel(e_strong)

    error(['matched_response_decomposition: dimension mismatch. ' ...
        'Template and signal lengths must match.']);
end

% Explicit row-wise complex inner products:
% C(q) = sum_t conj(a(q,t))*x(t)
Cw = sum(bsxfun(@times, conj(A), s_weak), 2).';
Ce = sum(bsxfun(@times, conj(A), e_strong), 2).';

Cw = Cw / numel(t);
Ce = Ce / numel(t);
Ct = Cw + Ce;
end

%% ========================================================================
function [dPe, dPcross, dDelta, ddPw] = ...
    local_derivatives(q, Pe, Pcross, DeltaP, Pw, q0, deriv_offset)

q = q(:);
Pe = Pe(:);
Pcross = Pcross(:);
DeltaP = DeltaP(:);
Pw = Pw(:);

[~, i0] = min(abs(q - q0));
[~, im] = min(abs(q - (q0 - deriv_offset)));
[~, ip] = min(abs(q - (q0 + deriv_offset)));

hR = q(ip) - q(i0);
hL = q(i0) - q(im);

if abs(hR-hL) > 1e-12
    error('Derivative grid is not symmetric around q0.');
end

h = hR;

dPe = (Pe(ip) - Pe(im)) / (2*h);
dPcross = (Pcross(ip) - Pcross(im)) / (2*h);
dDelta = (DeltaP(ip) - DeltaP(im)) / (2*h);

ddPw = (Pw(ip) - 2*Pw(i0) + Pw(im)) / (h^2);
end

%% ========================================================================
function make_figures(out_dir, cfg, mech, perf)

ratios = cfg.weak_ratio_list;
seps = cfg.signed_separation_list;

% Find requested SNR slice.
[~, iS] = min(abs(cfg.snr_db_list - cfg.figure_snr_db));
snr_plot = cfg.snr_db_list(iS);

%% Fig 1: residual recovery at selected SNR
Z = table_to_grid(perf, ratios, seps, snr_plot, ...
    'residual_recovery_rate');

fig = figure('Visible', cfg.figure_visible);
imagesc(seps, ratios, Z);
axis xy;
colorbar;
caxis([0 1]);
xlabel('q_s - q_w');
ylabel('A_w / A_s');
title(sprintf('B1 Residual Weak Recovery, SNR = %g dB', snr_plot));

exportgraphics(fig, ...
    fullfile(out_dir, 'fig01_recovery_heatmap.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 2: residual-induced recall penalty
Z = table_to_grid(perf, ratios, seps, snr_plot, ...
    'residual_recovery_penalty');

fig = figure('Visible', cfg.figure_visible);
imagesc(seps, ratios, Z);
axis xy;
colorbar;
xlabel('q_s - q_w');
ylabel('A_w / A_s');
title(sprintf('B1 Residual-Induced Recovery Penalty, SNR = %g dB', ...
    snr_plot));

exportgraphics(fig, ...
    fullfile(out_dir, 'fig02_penalty_heatmap.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 3: mean signed bias
Z = table_to_grid(perf, ratios, seps, snr_plot, ...
    'residual_mean_signed_bias');

fig = figure('Visible', cfg.figure_visible);
imagesc(seps, ratios, Z);
axis xy;
colorbar;
xlabel('q_s - q_w');
ylabel('A_w / A_s');
title(sprintf('B1 Residual Mean Signed q Bias, SNR = %g dB', ...
    snr_plot));

exportgraphics(fig, ...
    fullfile(out_dir, 'fig03_bias_heatmap.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 4: catastrophic-rate increase
Z = table_to_grid(perf, ratios, seps, snr_plot, ...
    'catastrophic_rate_increase');

fig = figure('Visible', cfg.figure_visible);
imagesc(seps, ratios, Z);
axis xy;
colorbar;
xlabel('q_s - q_w');
ylabel('A_w / A_s');
title(sprintf('B1 Catastrophic-Failure Increase, SNR = %g dB', ...
    snr_plot));

exportgraphics(fig, ...
    fullfile(out_dir, 'fig04_catastrophic_heatmap.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 5: noiseless first-order predicted bias
Z = mechanism_to_grid(mech, ratios, seps, ...
    'first_order_predicted_bias');

fig = figure('Visible', cfg.figure_visible);
imagesc(seps, ratios, Z);
axis xy;
colorbar;
xlabel('q_s - q_w');
ylabel('A_w / A_s');
title('B1 First-Order Predicted Weak-q Bias');

exportgraphics(fig, ...
    fullfile(out_dir, 'fig05_predicted_bias_heatmap.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 6: cross-term slope
Z = mechanism_to_grid(mech, ratios, seps, 'dP_cross_dq');

fig = figure('Visible', cfg.figure_visible);
imagesc(seps, ratios, Z);
axis xy;
colorbar;
xlabel('q_s - q_w');
ylabel('A_w / A_s');
title('B1 Coherent Cross-Term Slope dP_{cross}/dq at q_w');

exportgraphics(fig, ...
    fullfile(out_dir, 'fig06_cross_slope_heatmap.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 7: first-order predicted vs matched diagnostic
fig = figure('Visible', cfg.figure_visible);

scatter(mech.matched_response_bias, ...
    mech.first_order_predicted_bias, 42, ...
    mech.weak_ratio, 'filled');

hold on;

lim = max(abs([ ...
    mech.matched_response_bias; ...
    mech.first_order_predicted_bias]));

if lim <= 0
    lim = 1e-3;
end

plot([-lim lim], [-lim lim], '--', 'LineWidth', 1.2);

xlabel('Matched-response bias');
ylabel('First-order predicted bias');
title('B1 First-Order Peak-Shift Validation');
cb = colorbar;
cb.Label.String = 'A_w / A_s';
grid on;
axis equal;

exportgraphics(fig, ...
    fullfile(out_dir, 'fig07_prediction_vs_matched.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 8: residual energy over weak
Z = mechanism_to_grid(mech, ratios, seps, ...
    'strong_residual_energy_over_weak');

fig = figure('Visible', cfg.figure_visible);
imagesc(seps, ratios, Z);
axis xy;
colorbar;
xlabel('q_s - q_w');
ylabel('A_w / A_s');
title('B1 Filtered Strong Residual Energy / Weak Energy');

exportgraphics(fig, ...
    fullfile(out_dir, 'fig08_residual_energy_heatmap.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 9: mean penalty vs weak ratio for each SNR
fig = figure('Visible', cfg.figure_visible);

for is = 1:numel(cfg.snr_db_list)
    snr_db = cfg.snr_db_list(is);

    y = nan(size(ratios));

    for ir = 1:numel(ratios)
        mask = perf.snr_db == snr_db & ...
            perf.weak_ratio == ratios(ir);

        y(ir) = mean(perf.residual_recovery_penalty(mask));
    end

    plot(ratios, y, '-o', 'LineWidth', 1.4);
    hold on;
end

xlabel('A_w / A_s');
ylabel('Mean residual-induced recovery penalty');
title('B1 Recovery Penalty vs Weak Strength');
legend(arrayfun(@(x) sprintf('SNR %g dB',x), ...
    cfg.snr_db_list, 'UniformOutput', false), ...
    'Location', 'best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir, 'fig09_penalty_vs_weak_ratio.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 10: predicted bias vs MC bias change at selected SNR
mask = perf.snr_db == snr_plot;

fig = figure('Visible', cfg.figure_visible);

scatter(perf.first_order_predicted_bias(mask), ...
    perf.residual_induced_bias_change(mask), ...
    42, perf.weak_ratio(mask), 'filled');

hold on;

xv = perf.first_order_predicted_bias(mask);
yv = perf.residual_induced_bias_change(mask);

lim = max(abs([xv;yv]));

if lim <= 0
    lim = 1e-3;
end

plot([-lim lim], [-lim lim], '--', 'LineWidth', 1.2);

xlabel('Noiseless first-order predicted bias');
ylabel('Monte-Carlo mean residual-induced bias change');
title(sprintf('B1 Theory vs Monte-Carlo Bias, SNR = %g dB', ...
    snr_plot));
cb = colorbar;
cb.Label.String = 'A_w / A_s';
grid on;
axis equal;

exportgraphics(fig, ...
    fullfile(out_dir, 'fig10_theory_vs_mc_bias.png'), ...
    'Resolution', 180);
close(fig);

end

%% ========================================================================
function Z = table_to_grid(tbl, ratios, seps, snr_db, varname)

Z = nan(numel(ratios), numel(seps));

for ir = 1:numel(ratios)
    for id = 1:numel(seps)

        mask = tbl.weak_ratio == ratios(ir) & ...
            tbl.signed_separation == seps(id) & ...
            tbl.snr_db == snr_db;

        vals = tbl.(varname)(mask);

        if isempty(vals)
            error('Missing performance-map cell.');
        end

        Z(ir,id) = vals(1);
    end
end

end

%% ========================================================================
function Z = mechanism_to_grid(tbl, ratios, seps, varname)

Z = nan(numel(ratios), numel(seps));

for ir = 1:numel(ratios)
    for id = 1:numel(seps)

        mask = tbl.weak_ratio == ratios(ir) & ...
            tbl.signed_separation == seps(id);

        vals = tbl.(varname)(mask);

        if isempty(vals)
            error('Missing mechanism-map cell.');
        end

        Z(ir,id) = vals(1);
    end
end

end
