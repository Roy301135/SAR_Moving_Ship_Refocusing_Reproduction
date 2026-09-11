function results = exp09a4_residual_geometry()
%EXP09A4_RESIDUAL_GEOMETRY
% EXP009 / Pilot-01 / Experiment A4
%
% Residual Interference Geometry and First-Order Peak-Shift Explanation
%
% -------------------------------------------------------------------------
% Scientific question
% -------------------------------------------------------------------------
% A3 showed that the weak-q bias is mainly caused by the FILTERED STRONG
% RESIDUAL rather than direct weak filtering.
%
% A4 asks the next question:
%
%   Why does that residual pull the weak-q peak toward one side?
%
% The experiment has three parts:
%
%   A4-1  Mirror-q test
%         Put q_strong symmetrically below and above q_weak.
%         If the peak shift changes sign, the bias is directional "pulling"
%         toward q_strong rather than a fixed numerical artifact.
%
%   A4-2  Exact local matched-response decomposition
%         For diagnostic purposes define the weak-template response
%
%           C(q) = < r(t), a_w(q,t) >
%
%         where a_w(q,t) is the weak LFM template with the TRUE weak
%         center frequency and candidate q.
%
%         For r = s_w + e_s:
%
%           C(q) = C_w(q) + C_e(q)
%
%         and therefore
%
%           P(q) = |C(q)|^2
%                = |C_w(q)|^2
%                + |C_e(q)|^2
%                + 2 Re{ C_w(q) C_e*(q) }.
%
%         Define:
%           P_w     = |C_w|^2
%           P_e     = |C_e|^2
%           P_cross = 2 Re{C_w C_e*}
%           DeltaP  = P_e + P_cross
%
%         Since the weak-only peak is at q_weak, dP_w/dq ~= 0 there.
%         For a small perturbation, the first-order peak shift is
%
%           delta_q ~= - DeltaP'(q_weak) / P_w''(q_weak).
%
%         This is the key mathematical explanation tested in A4.
%
%   A4-3  Monte-Carlo mirror validation
%         Confirm that the sign reversal remains statistically visible with
%         noise using the operational concentration search.
%
% IMPORTANT:
%   The matched-response decomposition is an ORACLE DIAGNOSTIC used to
%   explain mechanism. It is not proposed as the final estimator.
%
% Run:
%   results = exp09a4_residual_geometry;

cfg = config_exp09a4();

%% Paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);

if isempty(cfg.output_dir)
    code_dir = fileparts(this_dir);
    paper_root = fileparts(code_dir);
    out_dir = fullfile(paper_root, 'results', 'exp09_pilot01', ...
        'exp09a4_residual_geometry');
else
    out_dir = cfg.output_dir;
end

if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

fprintf('\n============================================================\n');
fprintf(' EXP009-A4 / Residual Interference Geometry\n');
fprintf('============================================================\n');
fprintf('Output: %s\n', out_dir);

rng(cfg.seed, 'twister');

%% Common axes
N = cfg.N;
n = 0:N-1;
t = (n - N/2) / N;

q_search = cfg.q_search_min : cfg.q_search_step : cfg.q_search_max;
D_search = build_dechirp_dictionary(q_search, t, cfg);

q_geom = (cfg.q_weak - cfg.q_geom_halfwidth) : ...
    cfg.q_geom_step : ...
    (cfg.q_weak + cfg.q_geom_halfwidth);

%% Weak component
s_weak = synth_lfm(cfg.A_weak, cfg.q_weak, cfg.f_weak, ...
    cfg.phi_weak, t, cfg);

%% ========================================================================
% PART A4-1 / A4-2: NOISELESS MIRROR TEST + MATHEMATICAL DECOMPOSITION

mirror_names = ["LowerStrong"; "UpperStrong"];
mirror_qs = [cfg.q_strong_lower, cfg.q_strong_upper];

mirror_rows = cell(2,1);
mirror_curves = struct();

for icase = 1:2
    case_name = mirror_names(icase);
    q_s = mirror_qs(icase);

    s_strong = synth_lfm(cfg.A_strong, q_s, cfg.f_strong, ...
        cfg.phi_strong, t, cfg);

    k_strong = get_strong_notch_bin(s_strong, q_s, t, cfg);

    e_strong = apply_fixed_notch_operator( ...
        s_strong, q_s, k_strong, cfg.notch_halfwidth_bins, t, cfg);

    r_total = s_weak + e_strong;

    % Operational concentration search, same mechanism backend as A1-A3.
    [qhat_op, metric_op, ~] = ...
        search_q_concentration(r_total, q_search, D_search);

    [qhat_weak_op, metric_weak_op, ~] = ...
        search_q_concentration(s_weak, q_search, D_search);

    op_bias = qhat_op - cfg.q_weak;
    weak_only_op_bias = qhat_weak_op - cfg.q_weak;

    % Exact matched-response decomposition on a fine local q grid.
    [Cw, Ce, Ct] = matched_response_decomposition( ...
        s_weak, e_strong, q_geom, t, cfg);

    Pw = abs(Cw).^2;
    Pe = abs(Ce).^2;
    Pcross = 2 * real(Cw .* conj(Ce));
    Ptotal = abs(Ct).^2;
    DeltaP = Pe + Pcross;

    [~, idx_match] = max(Ptotal);
    qhat_match = q_geom(idx_match);
    matched_bias = qhat_match - cfg.q_weak;

    % First-order derivative/curvature around q_weak.
    [dPe, dPcross, dDelta, ddPw] = ...
        local_derivatives(q_geom, Pe, Pcross, DeltaP, Pw, ...
        cfg.q_weak, cfg.deriv_offset);

    delta_pred = - dDelta / ddPw;

    % Local asymmetry of the perturbation.
    asym_delta = local_pair_asymmetry(q_geom, DeltaP, cfg.q_weak);
    asym_cross = local_pair_asymmetry(q_geom, Pcross, cfg.q_weak);

    strong_residual_energy_over_weak = ...
        sum(abs(e_strong).^2) / sum(abs(s_weak).^2);

    mirror_rows{icase} = table( ...
        case_name, q_s, q_s-cfg.q_weak, k_strong, ...
        strong_residual_energy_over_weak, ...
        weak_only_op_bias, op_bias, matched_bias, delta_pred, ...
        dPe, dPcross, dDelta, ddPw, asym_delta, asym_cross, ...
        'VariableNames', { ...
        'case_name','q_strong','signed_separation','strong_notch_bin', ...
        'strong_residual_energy_over_weak', ...
        'weak_only_operational_bias','operational_bias', ...
        'matched_response_bias','first_order_predicted_bias', ...
        'dP_residual_dq','dP_cross_dq','dDeltaP_dq', ...
        'ddP_weak_dq2','DeltaP_pair_asymmetry','Pcross_pair_asymmetry'});

    fld = char(case_name);
    mirror_curves.(fld).q_geom = q_geom;
    mirror_curves.(fld).Pw = Pw;
    mirror_curves.(fld).Pe = Pe;
    mirror_curves.(fld).Pcross = Pcross;
    mirror_curves.(fld).DeltaP = DeltaP;
    mirror_curves.(fld).Ptotal = Ptotal;

    mirror_curves.(fld).q_search = q_search;
    mirror_curves.(fld).metric_op = metric_op;
    mirror_curves.(fld).metric_weak_op = metric_weak_op;
end

mirror_summary = [mirror_rows{1}; mirror_rows{2}];
writetable(mirror_summary, ...
    fullfile(out_dir, 'mirror_noiseless_summary.csv'));

%% ========================================================================
% PART A4-2b: SMALL SEPARATION SWEEP, BOTH SIDES

dlist = cfg.separation_list;
nD = numel(dlist);

nRows = nD * 2;

sw_side = strings(nRows,1);
sw_abssep = nan(nRows,1);
sw_qs = nan(nRows,1);
sw_signedsep = nan(nRows,1);
sw_EresEw = nan(nRows,1);

sw_op_bias = nan(nRows,1);
sw_match_bias = nan(nRows,1);
sw_pred_bias = nan(nRows,1);

sw_dPe = nan(nRows,1);
sw_dPcross = nan(nRows,1);
sw_dDelta = nan(nRows,1);
sw_ddPw = nan(nRows,1);

sw_asymDelta = nan(nRows,1);
sw_asymCross = nan(nRows,1);

row = 0;

for iside = 1:2
    if iside == 1
        sgn = -1;
        side_name = "Lower";
    else
        sgn = +1;
        side_name = "Upper";
    end

    for id = 1:nD
        row = row + 1;

        d = dlist(id);
        q_s = cfg.q_weak + sgn*d;

        s_strong = synth_lfm(cfg.A_strong, q_s, cfg.f_strong, ...
            cfg.phi_strong, t, cfg);

        k_strong = get_strong_notch_bin(s_strong, q_s, t, cfg);

        e_strong = apply_fixed_notch_operator( ...
            s_strong, q_s, k_strong, cfg.notch_halfwidth_bins, t, cfg);

        r_total = s_weak + e_strong;

        [qhat_op, ~, ~] = ...
            search_q_concentration(r_total, q_search, D_search);

        [Cw, Ce, Ct] = matched_response_decomposition( ...
            s_weak, e_strong, q_geom, t, cfg);

        Pw = abs(Cw).^2;
        Pe = abs(Ce).^2;
        Pcross = 2 * real(Cw .* conj(Ce));
        Ptotal = abs(Ct).^2;
        DeltaP = Pe + Pcross;

        [~, idx_match] = max(Ptotal);
        qhat_match = q_geom(idx_match);

        [dPe, dPcross, dDelta, ddPw] = ...
            local_derivatives(q_geom, Pe, Pcross, DeltaP, Pw, ...
            cfg.q_weak, cfg.deriv_offset);

        delta_pred = -dDelta/ddPw;

        sw_side(row) = side_name;
        sw_abssep(row) = d;
        sw_qs(row) = q_s;
        sw_signedsep(row) = q_s - cfg.q_weak;

        sw_EresEw(row) = ...
            sum(abs(e_strong).^2) / sum(abs(s_weak).^2);

        sw_op_bias(row) = qhat_op - cfg.q_weak;
        sw_match_bias(row) = qhat_match - cfg.q_weak;
        sw_pred_bias(row) = delta_pred;

        sw_dPe(row) = dPe;
        sw_dPcross(row) = dPcross;
        sw_dDelta(row) = dDelta;
        sw_ddPw(row) = ddPw;

        sw_asymDelta(row) = ...
            local_pair_asymmetry(q_geom, DeltaP, cfg.q_weak);

        sw_asymCross(row) = ...
            local_pair_asymmetry(q_geom, Pcross, cfg.q_weak);
    end
end

separation_summary = table( ...
    sw_side, sw_abssep, sw_qs, sw_signedsep, sw_EresEw, ...
    sw_op_bias, sw_match_bias, sw_pred_bias, ...
    sw_dPe, sw_dPcross, sw_dDelta, sw_ddPw, ...
    sw_asymDelta, sw_asymCross, ...
    'VariableNames', { ...
    'side','abs_separation','q_strong','signed_separation', ...
    'strong_residual_energy_over_weak', ...
    'operational_bias','matched_response_bias', ...
    'first_order_predicted_bias', ...
    'dP_residual_dq','dP_cross_dq','dDeltaP_dq','ddP_weak_dq2', ...
    'DeltaP_pair_asymmetry','Pcross_pair_asymmetry'});

writetable(separation_summary, ...
    fullfile(out_dir, 'separation_sweep_summary.csv'));

%% ========================================================================
% PART A4-3: MONTE-CARLO MIRROR VALIDATION

M = cfg.num_mc;

% Use one common noise power based on a representative two-component case.
s_strong_ref = synth_lfm(cfg.A_strong, cfg.q_strong_lower, ...
    cfg.f_strong, cfg.phi_strong, t, cfg);

signal_power = mean(abs(s_strong_ref + s_weak).^2);
noise_var = signal_power / (10^(cfg.snr_db/10));

noise_bank = sqrt(noise_var/2) * ...
    (randn(M,N) + 1j*randn(M,N));

nMCrows = M * 4;

mc_trial = zeros(nMCrows,1);
mc_case = strings(nMCrows,1);
mc_branch = strings(nMCrows,1);
mc_qs = nan(nMCrows,1);
mc_qhat = nan(nMCrows,1);
mc_bias = nan(nMCrows,1);
mc_error = nan(nMCrows,1);
mc_success = false(nMCrows,1);

row = 0;

for icase = 1:2
    case_name = mirror_names(icase);
    q_s = mirror_qs(icase);

    s_strong = synth_lfm(cfg.A_strong, q_s, cfg.f_strong, ...
        cfg.phi_strong, t, cfg);

    k_strong = get_strong_notch_bin(s_strong, q_s, t, cfg);

    e_strong = apply_fixed_notch_operator( ...
        s_strong, q_s, k_strong, cfg.notch_halfwidth_bins, t, cfg);

    for imc = 1:M
        nmc = noise_bank(imc,:);

        x0 = s_weak + nmc;
        xR = s_weak + nmc + e_strong;

        sigs = {x0, xR};
        branch_names = ["Baseline", "PlusStrongResidual"];

        for ib = 1:2
            row = row + 1;

            [qhat, ~, ~] = ...
                search_q_concentration(sigs{ib}, q_search, D_search);

            qb = qhat - cfg.q_weak;
            qe = abs(qb);

            mc_trial(row) = imc;
            mc_case(row) = case_name;
            mc_branch(row) = branch_names(ib);
            mc_qs(row) = q_s;
            mc_qhat(row) = qhat;
            mc_bias(row) = qb;
            mc_error(row) = qe;
            mc_success(row) = ...
                qe <= (cfg.tau_q + cfg.success_tol);
        end
    end
end

mc_trials = table( ...
    mc_trial, mc_case, mc_branch, mc_qs, mc_qhat, mc_bias, ...
    mc_error, mc_success, ...
    'VariableNames', { ...
    'trial_id','case_name','branch','q_strong','q_weak_hat', ...
    'q_weak_signed_bias','q_weak_abs_error','weak_recovered'});

writetable(mc_trials, ...
    fullfile(out_dir, 'mirror_mc_trials.csv'));

%% MC summary
mc_names = strings(4,1);
mc_recall = nan(4,1);
mc_mean_bias = nan(4,1);
mc_rmse = nan(4,1);
mc_mae = nan(4,1);

row = 0;

for icase = 1:2
    for ib = 1:2
        row = row + 1;

        case_name = mirror_names(icase);

        if ib == 1
            branch_name = "Baseline";
        else
            branch_name = "PlusStrongResidual";
        end

        mask = mc_trials.case_name == case_name & ...
            mc_trials.branch == branch_name;

        qb = mc_trials.q_weak_signed_bias(mask);
        qe = mc_trials.q_weak_abs_error(mask);

        mc_names(row) = case_name + "_" + branch_name;
        mc_recall(row) = mean(mc_trials.weak_recovered(mask));
        mc_mean_bias(row) = mean(qb);
        mc_rmse(row) = sqrt(mean(qb.^2));
        mc_mae(row) = mean(qe);
    end
end

mc_summary = table( ...
    mc_names, mc_recall, mc_mean_bias, mc_rmse, mc_mae, ...
    'VariableNames', { ...
    'case_branch','weak_recovery_rate','mean_signed_bias', ...
    'weak_q_rmse','weak_q_mae'});

writetable(mc_summary, ...
    fullfile(out_dir, 'mirror_mc_summary.csv'));

%% ========================================================================
% CONSOLE SUMMARY

fprintf('================ A4 MIRROR NOISELESS ===============\n');
for i = 1:height(mirror_summary)
    fprintf(['%-12s q_s=%0.4f sep=%+0.4f  Eres/Ew=%0.4f  ' ...
        'opBias=%+0.5f  matchBias=%+0.5f  pred=%+0.5f  ' ...
        'dPe=%+0.3e  dPcross=%+0.3e\n'], ...
        mirror_summary.case_name(i), ...
        mirror_summary.q_strong(i), ...
        mirror_summary.signed_separation(i), ...
        mirror_summary.strong_residual_energy_over_weak(i), ...
        mirror_summary.operational_bias(i), ...
        mirror_summary.matched_response_bias(i), ...
        mirror_summary.first_order_predicted_bias(i), ...
        mirror_summary.dP_residual_dq(i), ...
        mirror_summary.dP_cross_dq(i));
end

fprintf('\n================ A4 SEPARATION SWEEP ================\n');
for i = 1:height(separation_summary)
    fprintf(['%-5s d=%0.3f  signedSep=%+0.3f  Eres/Ew=%0.3f  ' ...
        'op=%+0.5f  match=%+0.5f  pred=%+0.5f  ' ...
        'dPe=%+0.2e  dPcross=%+0.2e\n'], ...
        separation_summary.side(i), ...
        separation_summary.abs_separation(i), ...
        separation_summary.signed_separation(i), ...
        separation_summary.strong_residual_energy_over_weak(i), ...
        separation_summary.operational_bias(i), ...
        separation_summary.matched_response_bias(i), ...
        separation_summary.first_order_predicted_bias(i), ...
        separation_summary.dP_residual_dq(i), ...
        separation_summary.dP_cross_dq(i));
end

fprintf('\n================ A4 MIRROR MONTE CARLO ==============\n');
for i = 1:height(mc_summary)
    fprintf('%-34s Recall=%0.3f  Bias=%+0.5f  RMSE=%0.5f\n', ...
        mc_summary.case_branch(i), ...
        mc_summary.weak_recovery_rate(i), ...
        mc_summary.mean_signed_bias(i), ...
        mc_summary.weak_q_rmse(i));
end
fprintf('=====================================================\n');

%% Text summary
fid = fopen(fullfile(out_dir, 'summary.txt'), 'w');

fprintf(fid, 'EXP009-A4 Residual Interference Geometry\n');
fprintf(fid, '========================================\n\n');

fprintf(fid, 'MC trials: %d\n', cfg.num_mc);
fprintf(fid, 'SNR: %.3f dB\n', cfg.snr_db);
fprintf(fid, 'q weak: %.6f\n', cfg.q_weak);
fprintf(fid, 'A weak / A strong: %.6f\n', cfg.A_weak_ratio);
fprintf(fid, 'Notch halfwidth: %d bins\n\n', ...
    cfg.notch_halfwidth_bins);

fprintf(fid, 'Mirror noiseless\n');
fprintf(fid, '----------------\n');

for i = 1:height(mirror_summary)
    fprintf(fid, ...
        ['%s: q_s=%.6f, signedSep=%+.6f, Eres/Ew=%.8f, ' ...
         'opBias=%+.8f, matchedBias=%+.8f, predictedBias=%+.8f, ' ...
         'dPe=%+.8e, dPcross=%+.8e, dDelta=%+.8e, ddPw=%+.8e\n'], ...
        mirror_summary.case_name(i), ...
        mirror_summary.q_strong(i), ...
        mirror_summary.signed_separation(i), ...
        mirror_summary.strong_residual_energy_over_weak(i), ...
        mirror_summary.operational_bias(i), ...
        mirror_summary.matched_response_bias(i), ...
        mirror_summary.first_order_predicted_bias(i), ...
        mirror_summary.dP_residual_dq(i), ...
        mirror_summary.dP_cross_dq(i), ...
        mirror_summary.dDeltaP_dq(i), ...
        mirror_summary.ddP_weak_dq2(i));
end

fprintf(fid, '\nMonte Carlo mirror\n');
fprintf(fid, '------------------\n');

for i = 1:height(mc_summary)
    fprintf(fid, ...
        '%s: Recall=%.6f, Bias=%+.8f, RMSE=%.8f, MAE=%.8f\n', ...
        mc_summary.case_branch(i), ...
        mc_summary.weak_recovery_rate(i), ...
        mc_summary.mean_signed_bias(i), ...
        mc_summary.weak_q_rmse(i), ...
        mc_summary.weak_q_mae(i));
end

fclose(fid);

%% Figures
make_figures(out_dir, cfg, q_search, mirror_summary, mirror_curves, ...
    separation_summary, mc_trials, mc_summary);

%% Save MAT
results = struct();
results.cfg = cfg;
results.mirror_summary = mirror_summary;
results.mirror_curves = mirror_curves;
results.separation_summary = separation_summary;
results.mc_trials = mc_trials;
results.mc_summary = mc_summary;

save(fullfile(out_dir, 'exp09a4_results.mat'), 'results', '-v7.3');

fprintf('\nSaved EXP009-A4 outputs to:\n%s\n\n', out_dir);

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
function [Cw, Ce, Ct] = matched_response_decomposition( ...
    s_weak, e_strong, q_grid, t, cfg)
% Oracle diagnostic matched response at the TRUE weak center frequency.
%
% For each candidate q:
%   a_w(q,t) = exp(j*pi*mu(q)*t^2 + j*2*pi*f_weak*t)
%
% Cw(q) = <s_weak, a_w(q)>
% Ce(q) = <e_strong, a_w(q)>
% Ct(q) = Cw(q) + Ce(q)
%
% Common normalization by N keeps numerical scale manageable without
% affecting the predicted peak shift.

mu = cfg.mu_scale * (q_grid(:) - cfg.q_ref);

A = exp(1j * (pi*(mu * (t.^2)) + 2*pi*cfg.f_weak*t));

% Each ROW of A is one candidate weak-template a_w(q,t).
% We need the complex inner product
%
%   C(q) = sum_t conj(a_w(q,t)) * x(t)
%
% for every q candidate.  Using element-wise multiplication + SUM avoids
% orientation ambiguity and is safer than matrix-transpose products here.
%
% A:          [Nq x N]
% s_weak:     [1  x N]
% e_strong:   [1  x N]
%
% After implicit expansion and sum(...,2):
% Cw/Ce:      [Nq x 1], then transpose to row vectors [1 x Nq].

if size(A,2) ~= numel(s_weak) || size(A,2) ~= numel(e_strong)
    error(['matched_response_decomposition: dimension mismatch. ' ...
        'Expected template length and signal length to be identical.']);
end

Cw = sum(conj(A) .* s_weak, 2).';
Ce = sum(conj(A) .* e_strong, 2).';

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

h = q(ip) - q(i0);

if abs((q(i0)-q(im)) - h) > 1e-12
    error('Derivative grid is not symmetric around q0.');
end

dPe = (Pe(ip) - Pe(im)) / (2*h);
dPcross = (Pcross(ip) - Pcross(im)) / (2*h);
dDelta = (DeltaP(ip) - DeltaP(im)) / (2*h);

ddPw = (Pw(ip) - 2*Pw(i0) + Pw(im)) / (h^2);
end

%% ========================================================================
function A = local_pair_asymmetry(q, y, q0)
% Pairwise left/right asymmetry around q0.
%
% Positive A:
%   right side is larger than left side on average.
%
% Negative A:
%   left side is larger than right side on average.

q = q(:);
y = y(:);

left_mask = q < q0;
right_mask = q > q0;

ql = q(left_mask);
yl = y(left_mask);

qr = q(right_mask);
yr = y(right_mask);

% Pair equal offsets from q0.
dl = q0 - ql;
dr = qr - q0;

vals = [];

for i = 1:numel(dl)
    [dmin, j] = min(abs(dr - dl(i)));

    if dmin <= 1e-10
        scale = max(abs(yr(j)) + abs(yl(i)), eps);
        vals(end+1,1) = (yr(j) - yl(i)) / scale; %#ok<AGROW>
    end
end

if isempty(vals)
    A = 0;
else
    A = mean(vals);
end
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
function make_figures(out_dir, cfg, q_search, mirror_summary, ...
    mirror_curves, sep, mc_trials, mc_summary)

%% Fig 1: Operational mirror curves
fig = figure('Visible', cfg.figure_visible);

for case_name = ["LowerStrong", "UpperStrong"]
    fld = char(case_name);

    plot(mirror_curves.(fld).q_search, ...
        normalize01(mirror_curves.(fld).metric_op), ...
        'LineWidth', 1.4);
    hold on;
end

xline(cfg.q_weak, ':', 'True q_{weak}');

xlabel('q candidate');
ylabel('Normalized operational concentration');
title('A4 Mirror Test: Operational Weak-q Peak');
legend('q_s < q_w', 'q_s > q_w', 'True q_w', ...
    'Location', 'best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir, 'fig01_mirror_operational_curves.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 2: Lower matched-response decomposition
fig = figure('Visible', cfg.figure_visible);

c = mirror_curves.LowerStrong;

plot(c.q_geom, c.Pw, 'LineWidth', 1.4);
hold on;
plot(c.q_geom, c.Pe, 'LineWidth', 1.4);
plot(c.q_geom, c.Pcross, 'LineWidth', 1.4);
plot(c.q_geom, c.Ptotal, 'LineWidth', 1.6);

xline(cfg.q_weak, ':', 'True q_{weak}');

xlabel('q');
ylabel('Matched-response power term');
title('A4 Lower-Strong: Exact Local Interference Decomposition');
legend('P_w', 'P_e', 'P_{cross}', 'P_{total}', ...
    'Location', 'best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir, 'fig02_lower_decomposition.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 3: Upper matched-response decomposition
fig = figure('Visible', cfg.figure_visible);

c = mirror_curves.UpperStrong;

plot(c.q_geom, c.Pw, 'LineWidth', 1.4);
hold on;
plot(c.q_geom, c.Pe, 'LineWidth', 1.4);
plot(c.q_geom, c.Pcross, 'LineWidth', 1.4);
plot(c.q_geom, c.Ptotal, 'LineWidth', 1.6);

xline(cfg.q_weak, ':', 'True q_{weak}');

xlabel('q');
ylabel('Matched-response power term');
title('A4 Upper-Strong: Exact Local Interference Decomposition');
legend('P_w', 'P_e', 'P_{cross}', 'P_{total}', ...
    'Location', 'best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir, 'fig03_upper_decomposition.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 4: Perturbation DeltaP mirror comparison
fig = figure('Visible', cfg.figure_visible);

plot(mirror_curves.LowerStrong.q_geom, ...
    mirror_curves.LowerStrong.DeltaP, 'LineWidth', 1.5);
hold on;

plot(mirror_curves.UpperStrong.q_geom, ...
    mirror_curves.UpperStrong.DeltaP, 'LineWidth', 1.5);

xline(cfg.q_weak, ':', 'True q_{weak}');
yline(0, '--');

xlabel('q');
ylabel('\DeltaP(q) = P_e + P_{cross}');
title('A4 Mirror Perturbation Geometry');
legend('q_s < q_w', 'q_s > q_w', 'Location', 'best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir, 'fig04_mirror_DeltaP.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 5: Separation sweep biases
fig = figure('Visible', cfg.figure_visible);

x = sep.signed_separation;

plot(x, sep.operational_bias, 'o-', 'LineWidth', 1.4);
hold on;
plot(x, sep.matched_response_bias, 's-', 'LineWidth', 1.4);
plot(x, sep.first_order_predicted_bias, '^-', 'LineWidth', 1.4);

xline(0, '--');
yline(0, '--');

xlabel('q_s - q_w');
ylabel('Weak-q bias');
title('A4 Separation Sweep: Measured vs First-Order Peak Shift');
legend('Operational', 'Matched diagnostic', ...
    'First-order prediction', 'Location', 'best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir, 'fig05_separation_vs_bias.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 6: Derivative contributions
fig = figure('Visible', cfg.figure_visible);

plot(x, sep.dP_residual_dq, 'o-', 'LineWidth', 1.4);
hold on;
plot(x, sep.dP_cross_dq, 's-', 'LineWidth', 1.4);
plot(x, sep.dDeltaP_dq, '^-', 'LineWidth', 1.4);

xline(0, '--');
yline(0, '--');

xlabel('q_s - q_w');
ylabel('Derivative at q_w');
title('A4 Perturbation Slope: Residual vs Coherent Cross-Term');
legend('dP_e/dq', 'dP_{cross}/dq', 'd\DeltaP/dq', ...
    'Location', 'best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir, 'fig06_derivative_contributions.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 7: Residual energy vs separation
fig = figure('Visible', cfg.figure_visible);

plot(x, sep.strong_residual_energy_over_weak, ...
    'o-', 'LineWidth', 1.4);

xline(0, '--');

xlabel('q_s - q_w');
ylabel('Filtered strong residual energy / weak energy');
title('A4 Residual Energy vs Relative q Position');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir, 'fig07_residual_energy_vs_separation.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 8: Monte Carlo signed-bias boxplot
labels = ["LowerStrong_Baseline", ...
          "LowerStrong_PlusStrongResidual", ...
          "UpperStrong_Baseline", ...
          "UpperStrong_PlusStrongResidual"];

grp = [];
vals = [];

for i = 1:numel(labels)
    parts = split(labels(i), "_");

    case_name = parts(1);
    branch_name = join(parts(2:end), "_");

    mask = mc_trials.case_name == case_name & ...
        mc_trials.branch == branch_name;

    grp = [grp; i*ones(sum(mask),1)]; %#ok<AGROW>
    vals = [vals; mc_trials.q_weak_signed_bias(mask)]; %#ok<AGROW>
end

fig = figure('Visible', cfg.figure_visible);

boxchart(grp, vals);
yline(0, '--');

xticks(1:4);
xticklabels({'Lower baseline', 'Lower + residual', ...
    'Upper baseline', 'Upper + residual'});
xtickangle(20);

ylabel('q_{weak}^{hat} - q_{weak}');
title('A4 Monte Carlo Mirror Sign Test');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir, 'fig08_mc_mirror_bias.png'), ...
    'Resolution', 180);
close(fig);

%% Fig 9: Monte Carlo recovery
fig = figure('Visible', cfg.figure_visible);

bar(mc_summary.weak_recovery_rate);
ylim([0 1]);

xticks(1:4);
xticklabels({'Lower baseline', 'Lower + residual', ...
    'Upper baseline', 'Upper + residual'});
xtickangle(20);

ylabel('Weak recovery rate');
title('A4 Monte Carlo Mirror Recovery');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir, 'fig09_mc_mirror_recovery.png'), ...
    'Resolution', 180);
close(fig);

end
