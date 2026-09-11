function results = exp09b2_regime_gamma()
%EXP09B2_REGIME_GAMMA
% EXP009 / Pilot-01 / Experiment B2
%
% Purpose:
%   1) Define oracle physics index Gamma = |delta_q_pred| / tau_q.
%   2) Compare Gamma with residual-strength index Lambda = Eres/Ew.
%   3) Use B1 cells to diagnose easy / dangerous regions.
%   4) Automatically choose representative easy / perturbative /
%      catastrophic cells and rerun them with more Monte-Carlo trials.
%
% IMPORTANT:
%   Gamma is still an ORACLE mechanism index, not a practical online score.

cfg = config_exp09b2();

%% Paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.b1_result_dir)
    b1_dir = fullfile(paper_root,'results','exp09_pilot01', ...
        'exp09b1_failure_mechanism_map');
else
    b1_dir = cfg.b1_result_dir;
end

if isempty(cfg.output_dir)
    out_dir = fullfile(paper_root,'results','exp09_pilot01', ...
        'exp09b2_regime_gamma');
else
    out_dir = cfg.output_dir;
end

if ~exist(out_dir,'dir'); mkdir(out_dir); end

perf_file = fullfile(b1_dir,'performance_map_mc.csv');
mech_file = fullfile(b1_dir,'mechanism_map_noiseless.csv');

if ~exist(perf_file,'file')
    error('B1 performance file not found: %s', perf_file);
end
if ~exist(mech_file,'file')
    error('B1 mechanism file not found: %s', mech_file);
end

fprintf('\n============================================================\n');
fprintf(' EXP009-B2 / Regime Boundary + Gamma\n');
fprintf('============================================================\n');
fprintf('B1 input: %s\n', b1_dir);
fprintf('Output:   %s\n\n', out_dir);

perf = readtable(perf_file);
mech = readtable(mech_file);

req = {'weak_ratio','signed_separation','snr_db', ...
    'baseline_recovery_rate','residual_recovery_rate', ...
    'residual_recovery_penalty','residual_mean_signed_bias', ...
    'residual_induced_bias_change','residual_catastrophic_rate', ...
    'strong_residual_energy_over_weak','first_order_predicted_bias'};
assert_table_vars(perf,req,'performance_map_mc.csv');

%% Physics indices on all B1 cells
perf.Gamma = abs(perf.first_order_predicted_bias) / cfg.tau_q;
perf.Lambda = perf.strong_residual_energy_over_weak;
perf.feasible = perf.baseline_recovery_rate >= cfg.feasible_baseline_min;
perf.dangerous = perf.feasible & ...
    perf.residual_recovery_penalty >= cfg.danger_penalty_threshold;
perf.catastrophic_cell = perf.feasible & ...
    perf.residual_catastrophic_rate >= cfg.catastrophic_rate_min;

perf.empirical_regime = strings(height(perf),1);
for i = 1:height(perf)
    perf.empirical_regime(i) = classify_regime( ...
        perf.baseline_recovery_rate(i), ...
        perf.residual_recovery_penalty(i), ...
        perf.residual_catastrophic_rate(i), cfg);
end
writetable(perf,fullfile(out_dir,'b1_cells_with_gamma.csv'));

%% B1 diagnostic: Gamma vs Lambda
mask = perf.feasible;
y = perf.dangerous(mask);
g = perf.Gamma(mask);
l = perf.Lambda(mask);
pen = perf.residual_recovery_penalty(mask);
abias = abs(perf.residual_induced_bias_change(mask));

auc_gamma = binary_auc(y,g);
auc_lambda = binary_auc(y,l);

[fprG,tprG,thrG] = roc_curve_manual(y,g);
[gamma_opt_threshold,gamma_opt_youden] = ...
    optimal_youden_threshold(fprG,tprG,thrG);

cm_gamma1 = confusion_counts(y,g >= 1);
cm_gamma_opt = confusion_counts(y,g >= gamma_opt_threshold);

rho_gamma_penalty = spearman_manual(g,pen);
rho_lambda_penalty = spearman_manual(l,pen);
rho_gamma_absbias = spearman_manual(g,abias);

%% Per-SNR diagnostic
snrs = unique(perf.snr_db).';
nS = numel(snrs);

snr_col = nan(nS,1);
ncell_col = nan(nS,1);
ndanger_col = nan(nS,1);
aucg_col = nan(nS,1);
aucl_col = nan(nS,1);
rhog_col = nan(nS,1);
rhol_col = nan(nS,1);

for is = 1:nS
    s = snrs(is);
    mm = perf.feasible & perf.snr_db == s;

    yy = perf.dangerous(mm);
    gg = perf.Gamma(mm);
    ll = perf.Lambda(mm);
    pp = perf.residual_recovery_penalty(mm);

    snr_col(is) = s;
    ncell_col(is) = sum(mm);
    ndanger_col(is) = sum(yy);
    aucg_col(is) = binary_auc(yy,gg);
    aucl_col(is) = binary_auc(yy,ll);
    rhog_col(is) = spearman_manual(gg,pp);
    rhol_col(is) = spearman_manual(ll,pp);
end

diagnostic_by_snr = table( ...
    snr_col,ncell_col,ndanger_col,aucg_col,aucl_col,rhog_col,rhol_col, ...
    'VariableNames',{'snr_db','num_feasible_cells','num_dangerous_cells', ...
    'auc_gamma','auc_lambda','spearman_gamma_penalty', ...
    'spearman_lambda_penalty'});
writetable(diagnostic_by_snr,fullfile(out_dir,'gamma_diagnostic_by_snr.csv'));

%% Select representative cells from B1 behavior, NOT from Gamma
selected = select_representative_cells(perf,cfg);
if isempty(selected); error('No B1 cells selected for B2 refinement.'); end
selected.cell_id = (1:height(selected)).';
writetable(selected,fullfile(out_dir,'selected_cells.csv'));

fprintf('Selected %d cells for refined MC.\n',height(selected));
for i = 1:height(selected)
    fprintf(['#%02d %-12s SNR=%+g rA=%.2f sep=%+.3f ' ...
        'pen=%.3f cat=%.3f Gamma=%.3f Lambda=%.3f\n'], ...
        selected.cell_id(i),selected.selection_regime(i), ...
        selected.snr_db(i),selected.weak_ratio(i), ...
        selected.signed_separation(i), ...
        selected.residual_recovery_penalty(i), ...
        selected.residual_catastrophic_rate(i), ...
        selected.Gamma(i),selected.Lambda(i));
end

%% Refined MC setup
rng(cfg.seed,'twister');

N = cfg.N;
n = 0:N-1;
t = (n-N/2)/N;
q_search = cfg.q_search_min:cfg.q_search_step:cfg.q_search_max;
D_search = build_dechirp_dictionary(q_search,t,cfg);

M = cfg.refine_num_mc;
K = height(selected);

sel_snrs = unique(selected.snr_db).';
noise_bank = struct();

s_ref = synth_lfm(cfg.A_strong,cfg.q_weak-0.05, ...
    cfg.f_strong,cfg.phi_strong,t,cfg);
Pstrong = mean(abs(s_ref).^2);

for is = 1:numel(sel_snrs)
    s = sel_snrs(is);
    noise_var = Pstrong/(10^(s/10));
    fld = snr_field(s);
    noise_bank.(fld) = sqrt(noise_var/2) * ...
        (randn(M,N) + 1j*randn(M,N));
end

%% Refined trial/result storage
nRows = K*M;

tt_cell = zeros(nRows,1);
tt_trial = zeros(nRows,1);
tt_regime = strings(nRows,1);
tt_ratio = nan(nRows,1);
tt_sep = nan(nRows,1);
tt_snr = nan(nRows,1);
tt_gamma = nan(nRows,1);
tt_lambda = nan(nRows,1);
tt_base_q = nan(nRows,1);
tt_res_q = nan(nRows,1);
tt_base_success = false(nRows,1);
tt_res_success = false(nRows,1);
tt_base_err = nan(nRows,1);
tt_res_err = nan(nRows,1);
tt_res_bias = nan(nRows,1);
tt_res_cat = false(nRows,1);

rr_cell = (1:K).';
rr_selection_regime = strings(K,1);
rr_empirical_regime = strings(K,1);
rr_ratio = nan(K,1);
rr_sep = nan(K,1);
rr_snr = nan(K,1);
rr_gamma = nan(K,1);
rr_lambda = nan(K,1);
rr_base_recall = nan(K,1);
rr_base_lo = nan(K,1);
rr_base_hi = nan(K,1);
rr_res_recall = nan(K,1);
rr_res_lo = nan(K,1);
rr_res_hi = nan(K,1);
rr_penalty = nan(K,1);
rr_penalty_lo = nan(K,1);
rr_penalty_hi = nan(K,1);
rr_res_cat = nan(K,1);
rr_res_bias = nan(K,1);
rr_res_rmse = nan(K,1);

row = 0;

for ik = 1:K
    rA = selected.weak_ratio(ik);
    sep = selected.signed_separation(ik);
    s = selected.snr_db(ik);
    q_s = cfg.q_weak + sep;

    s_w = synth_lfm(cfg.A_strong*rA,cfg.q_weak, ...
        cfg.f_weak,cfg.phi_weak,t,cfg);
    s_s = synth_lfm(cfg.A_strong,q_s, ...
        cfg.f_strong,cfg.phi_strong,t,cfg);

    k_s = get_strong_notch_bin(s_s,q_s,t,cfg);
    e_s = apply_fixed_notch_operator( ...
        s_s,q_s,k_s,cfg.notch_halfwidth_bins,t,cfg);

    nb = noise_bank.(snr_field(s));

    base_success = false(M,1);
    res_success = false(M,1);
    res_bias = nan(M,1);
    res_cat = false(M,1);

    for imc = 1:M
        noise = nb(imc,:);

        xb = s_w + noise;
        xr = s_w + e_s + noise;

        [qhb,~,~] = search_q_concentration(xb,q_search,D_search);
        [qhr,~,~] = search_q_concentration(xr,q_search,D_search);

        eb = abs(qhb-cfg.q_weak);
        br = qhr-cfg.q_weak;
        er = abs(br);

        sb = eb <= (cfg.tau_q + cfg.success_tol);
        sr = er <= (cfg.tau_q + cfg.success_tol);
        cr = er >= (cfg.catastrophic_error_q-cfg.success_tol);

        base_success(imc) = sb;
        res_success(imc) = sr;
        res_bias(imc) = br;
        res_cat(imc) = cr;

        row = row + 1;
        tt_cell(row) = ik;
        tt_trial(row) = imc;
        tt_regime(row) = selected.selection_regime(ik);
        tt_ratio(row) = rA;
        tt_sep(row) = sep;
        tt_snr(row) = s;
        tt_gamma(row) = selected.Gamma(ik);
        tt_lambda(row) = selected.Lambda(ik);
        tt_base_q(row) = qhb;
        tt_res_q(row) = qhr;
        tt_base_success(row) = sb;
        tt_res_success(row) = sr;
        tt_base_err(row) = eb;
        tt_res_err(row) = er;
        tt_res_bias(row) = br;
        tt_res_cat(row) = cr;
    end

    [blo,bhi] = wilson_ci(sum(base_success),M,cfg.ci_alpha);
    [rlo,rhi] = wilson_ci(sum(res_success),M,cfg.ci_alpha);

    paired_diff = double(base_success)-double(res_success);
    rng(cfg.bootstrap_seed+ik,'twister');
    [plo,phi] = bootstrap_mean_ci( ...
        paired_diff,cfg.bootstrap_reps,cfg.ci_alpha);

    rr_selection_regime(ik) = selected.selection_regime(ik);
    rr_ratio(ik) = rA;
    rr_sep(ik) = sep;
    rr_snr(ik) = s;
    rr_gamma(ik) = selected.Gamma(ik);
    rr_lambda(ik) = selected.Lambda(ik);
    rr_base_recall(ik) = mean(base_success);
    rr_base_lo(ik) = blo;
    rr_base_hi(ik) = bhi;
    rr_res_recall(ik) = mean(res_success);
    rr_res_lo(ik) = rlo;
    rr_res_hi(ik) = rhi;
    rr_penalty(ik) = mean(paired_diff);
    rr_penalty_lo(ik) = plo;
    rr_penalty_hi(ik) = phi;
    rr_res_cat(ik) = mean(res_cat);
    rr_res_bias(ik) = mean(res_bias);
    rr_res_rmse(ik) = sqrt(mean(res_bias.^2));

    rr_empirical_regime(ik) = classify_regime( ...
        rr_base_recall(ik),rr_penalty(ik),rr_res_cat(ik),cfg);
end

refined_trials = table( ...
    tt_cell,tt_trial,tt_regime,tt_ratio,tt_sep,tt_snr,tt_gamma,tt_lambda, ...
    tt_base_q,tt_res_q,tt_base_success,tt_res_success, ...
    tt_base_err,tt_res_err,tt_res_bias,tt_res_cat, ...
    'VariableNames',{'cell_id','trial_id','selection_regime', ...
    'weak_ratio','signed_separation','snr_db','Gamma','Lambda', ...
    'baseline_q_hat','residual_q_hat','baseline_success','residual_success', ...
    'baseline_abs_error','residual_abs_error','residual_signed_bias', ...
    'residual_catastrophic'});
writetable(refined_trials,fullfile(out_dir,'refined_mc_trials.csv'));

refined_summary = table( ...
    rr_cell,rr_selection_regime,rr_empirical_regime, ...
    rr_ratio,rr_sep,rr_snr,rr_gamma,rr_lambda, ...
    rr_base_recall,rr_base_lo,rr_base_hi, ...
    rr_res_recall,rr_res_lo,rr_res_hi, ...
    rr_penalty,rr_penalty_lo,rr_penalty_hi, ...
    rr_res_cat,rr_res_bias,rr_res_rmse, ...
    'VariableNames',{'cell_id','selection_regime','refined_empirical_regime', ...
    'weak_ratio','signed_separation','snr_db','Gamma','Lambda', ...
    'baseline_recovery_rate','baseline_recovery_ci_low', ...
    'baseline_recovery_ci_high','residual_recovery_rate', ...
    'residual_recovery_ci_low','residual_recovery_ci_high', ...
    'paired_recovery_penalty','penalty_ci_low','penalty_ci_high', ...
    'residual_catastrophic_rate','residual_mean_signed_bias', ...
    'residual_q_rmse'});
writetable(refined_summary,fullfile(out_dir,'refined_cell_summary.csv'));

%% Refined diagnostic
refined_danger = ...
    refined_summary.baseline_recovery_rate >= cfg.feasible_baseline_min & ...
    refined_summary.paired_recovery_penalty >= cfg.danger_penalty_threshold;

refined_auc_gamma = binary_auc(refined_danger,refined_summary.Gamma);
refined_auc_lambda = binary_auc(refined_danger,refined_summary.Lambda);
refined_rho_gamma_penalty = spearman_manual( ...
    refined_summary.Gamma,refined_summary.paired_recovery_penalty);
refined_rho_lambda_penalty = spearman_manual( ...
    refined_summary.Lambda,refined_summary.paired_recovery_penalty);

diagnostic_summary = table( ...
    auc_gamma,auc_lambda,gamma_opt_threshold,gamma_opt_youden, ...
    rho_gamma_penalty,rho_lambda_penalty,rho_gamma_absbias, ...
    refined_auc_gamma,refined_auc_lambda, ...
    refined_rho_gamma_penalty,refined_rho_lambda_penalty, ...
    'VariableNames',{'b1_auc_gamma','b1_auc_lambda', ...
    'b1_opt_gamma_threshold','b1_opt_gamma_youden', ...
    'b1_spearman_gamma_penalty','b1_spearman_lambda_penalty', ...
    'b1_spearman_gamma_abs_bias_change','refined_auc_gamma', ...
    'refined_auc_lambda','refined_spearman_gamma_penalty', ...
    'refined_spearman_lambda_penalty'});
writetable(diagnostic_summary,fullfile(out_dir,'diagnostic_summary.csv'));

%% Text summary
fid = fopen(fullfile(out_dir,'summary.txt'),'w');
fprintf(fid,'EXP009-B2 Regime Boundary + Gamma\n');
fprintf(fid,'================================\n\n');
fprintf(fid,'Gamma = |delta_q_pred| / tau_q\n');
fprintf(fid,'tau_q = %.6f\n',cfg.tau_q);
fprintf(fid,'B1 feasible threshold = %.3f\n',cfg.feasible_baseline_min);
fprintf(fid,'Danger penalty threshold = %.3f\n\n', ...
    cfg.danger_penalty_threshold);

fprintf(fid,'B1 screening\n');
fprintf(fid,'------------\n');
fprintf(fid,'AUC Gamma = %.6f\n',auc_gamma);
fprintf(fid,'AUC Lambda = %.6f\n',auc_lambda);
fprintf(fid,'Optimal Gamma threshold = %.6f\n',gamma_opt_threshold);
fprintf(fid,'Optimal Youden J = %.6f\n',gamma_opt_youden);
fprintf(fid,'Spearman Gamma vs penalty = %.6f\n',rho_gamma_penalty);
fprintf(fid,'Spearman Lambda vs penalty = %.6f\n',rho_lambda_penalty);
fprintf(fid,'Spearman Gamma vs |MC bias change| = %.6f\n\n',rho_gamma_absbias);

fprintf(fid,'Gamma=1 confusion: TP=%d FP=%d TN=%d FN=%d\n', ...
    cm_gamma1.TP,cm_gamma1.FP,cm_gamma1.TN,cm_gamma1.FN);
fprintf(fid,'Optimal-Gamma confusion: TP=%d FP=%d TN=%d FN=%d\n\n', ...
    cm_gamma_opt.TP,cm_gamma_opt.FP,cm_gamma_opt.TN,cm_gamma_opt.FN);

fprintf(fid,'Refined MC\n');
fprintf(fid,'----------\n');
fprintf(fid,'Selected cells = %d\n',K);
fprintf(fid,'MC trials/cell = %d\n',M);
fprintf(fid,'Refined AUC Gamma = %.6f\n',refined_auc_gamma);
fprintf(fid,'Refined AUC Lambda = %.6f\n',refined_auc_lambda);
fprintf(fid,'Refined Spearman Gamma vs penalty = %.6f\n', ...
    refined_rho_gamma_penalty);
fprintf(fid,'Refined Spearman Lambda vs penalty = %.6f\n\n', ...
    refined_rho_lambda_penalty);

for i = 1:height(refined_summary)
    fprintf(fid,['#%02d select=%s refined=%s SNR=%+g rA=%.2f sep=%+.3f ' ...
        'Gamma=%.3f Lambda=%.3f Base=%.3f Res=%.3f ' ...
        'Penalty=%.3f [%.3f,%.3f] Cat=%.3f Bias=%+.5f\n'], ...
        refined_summary.cell_id(i),refined_summary.selection_regime(i), ...
        refined_summary.refined_empirical_regime(i), ...
        refined_summary.snr_db(i),refined_summary.weak_ratio(i), ...
        refined_summary.signed_separation(i),refined_summary.Gamma(i), ...
        refined_summary.Lambda(i),refined_summary.baseline_recovery_rate(i), ...
        refined_summary.residual_recovery_rate(i), ...
        refined_summary.paired_recovery_penalty(i), ...
        refined_summary.penalty_ci_low(i),refined_summary.penalty_ci_high(i), ...
        refined_summary.residual_catastrophic_rate(i), ...
        refined_summary.residual_mean_signed_bias(i));
end
fclose(fid);

%% Console
fprintf('\n================ B2 SUMMARY =========================\n');
fprintf('Feasible B1 cells                 = %d\n',sum(mask));
fprintf('Dangerous B1 cells                = %d\n',sum(y));
fprintf('AUC Gamma                         = %.3f\n',auc_gamma);
fprintf('AUC Lambda                        = %.3f\n',auc_lambda);
fprintf('Optimal Gamma threshold           = %.3f\n',gamma_opt_threshold);
fprintf('Spearman Gamma vs penalty         = %.3f\n',rho_gamma_penalty);
fprintf('Spearman Lambda vs penalty        = %.3f\n',rho_lambda_penalty);
fprintf('Selected refined cells            = %d\n',K);
fprintf('MC trials/cell                    = %d\n',M);
fprintf('Refined AUC Gamma                 = %.3f\n',refined_auc_gamma);
fprintf('Refined AUC Lambda                = %.3f\n',refined_auc_lambda);
fprintf('=====================================================\n');

make_figures(out_dir,cfg,perf,mech,fprG,tprG,auc_gamma, ...
    gamma_opt_threshold,refined_summary);

results = struct();
results.cfg = cfg;
results.b1_performance_with_gamma = perf;
results.b1_mechanism = mech;
results.diagnostic_by_snr = diagnostic_by_snr;
results.diagnostic_summary = diagnostic_summary;
results.gamma1_confusion = cm_gamma1;
results.gamma_opt_confusion = cm_gamma_opt;
results.selected_cells = selected;
results.refined_trials = refined_trials;
results.refined_summary = refined_summary;

save(fullfile(out_dir,'exp09b2_results.mat'),'results','-v7.3');

fprintf('\nSaved EXP009-B2 outputs to:\n%s\n\n',out_dir);
end

%% ========================================================================
function D = build_dechirp_dictionary(q_grid,t,cfg)
mu = cfg.mu_scale*(q_grid(:)-cfg.q_ref);
D = exp(-1j*pi*(mu*(t.^2)));
end

%% ========================================================================
function s = synth_lfm(A,q,f0,phi0,t,cfg)
mu = cfg.mu_scale*(q-cfg.q_ref);
s = A.*exp(1j*(pi*mu*t.^2 + 2*pi*f0*t + phi0));
end

%% ========================================================================
function [q_hat,metric,idx] = search_q_concentration(x,q_grid,D)
if size(D,2) ~= numel(x)
    error(['search_q_concentration: dimension mismatch. ' ...
        'Dictionary and signal lengths must match.']);
end
Y = fft(bsxfun(@times,D,x),[],2);
metric = max(abs(Y).^2,[],2);
[~,idx] = max(metric);
q_hat = q_grid(idx);
end

%% ========================================================================
function k0 = get_strong_notch_bin(s_strong,q_strong,t,cfg)
mu = cfg.mu_scale*(q_strong-cfg.q_ref);
dechirp = exp(-1j*pi*mu*t.^2);
Z = fft(s_strong.*dechirp);
[~,k0] = max(abs(Z).^2);
end

%% ========================================================================
function r = apply_fixed_notch_operator( ...
    x,q_used,k_fixed,halfwidth_bins,t,cfg)

mu = cfg.mu_scale*(q_used-cfg.q_ref);
dechirp = exp(-1j*pi*mu*t.^2);
rechirp = conj(dechirp);

Z = fft(x.*dechirp);
mask = ones(1,numel(Z));

for dk = -halfwidth_bins:halfwidth_bins
    kk = mod((k_fixed-1)+dk,numel(Z))+1;
    mask(kk) = 0;
end

r = ifft(Z.*mask).*rechirp;
end

%% ========================================================================
function assert_table_vars(tbl,names,filename)
vars = tbl.Properties.VariableNames;
for i = 1:numel(names)
    if ~ismember(names{i},vars)
        error('Missing variable "%s" in %s.',names{i},filename);
    end
end
end

%% ========================================================================
function regime = classify_regime(base_recall,penalty,cat_rate,cfg)
if base_recall < cfg.feasible_baseline_min
    regime = "IntrinsicLimited";
elseif cat_rate >= cfg.catastrophic_rate_min
    regime = "Catastrophic";
elseif penalty <= cfg.easy_penalty_max
    regime = "Easy";
elseif penalty >= cfg.perturbative_penalty_min && ...
        penalty <= cfg.perturbative_penalty_max && ...
        cat_rate <= cfg.perturbative_cat_max
    regime = "Perturbative";
else
    regime = "Transition";
end
end

%% ========================================================================
function selected = select_representative_cells(perf,cfg)
% Selection is based on B1 empirical behavior, not Gamma.
snrs = unique(perf.snr_db).';
used = false(height(perf),1);

idx_all = [];
reg_all = strings(0,1);
regimes = ["Easy","Perturbative","Catastrophic"];

for irg = 1:numel(regimes)
    reg = regimes(irg);
    picked = 0;

    for is = 1:numel(snrs)
        if picked >= cfg.selected_per_regime; break; end

        idx = find_candidate(perf,used,reg,snrs(is),cfg);

        if ~isempty(idx)
            idx_all(end+1,1) = idx; %#ok<AGROW>
            reg_all(end+1,1) = reg; %#ok<AGROW>
            used(idx) = true;
            picked = picked + 1;
        end
    end

    while picked < cfg.selected_per_regime
        idx = find_candidate(perf,used,reg,NaN,cfg);
        if isempty(idx); break; end

        idx_all(end+1,1) = idx; %#ok<AGROW>
        reg_all(end+1,1) = reg; %#ok<AGROW>
        used(idx) = true;
        picked = picked + 1;
    end
end

selected = perf(idx_all,:);
selected.selection_regime = reg_all;
selected = movevars(selected,'selection_regime','Before',1);
end

%% ========================================================================
function idx = find_candidate(perf,used,reg,snr_db,cfg)
base = perf.feasible & ~used;
if ~isnan(snr_db)
    base = base & abs(perf.snr_db-snr_db)<1e-12;
end

switch reg
    case "Easy"
        mask = base & ...
            perf.residual_recovery_penalty <= cfg.easy_penalty_max & ...
            perf.residual_catastrophic_rate < cfg.catastrophic_rate_min;
        cand = find(mask);
        if isempty(cand); cand = find(base); end
        if isempty(cand); idx = []; return; end
        score = abs(perf.residual_recovery_penalty(cand)) + ...
            0.5*perf.residual_catastrophic_rate(cand);
        [~,j] = min(score);
        idx = cand(j);

    case "Perturbative"
        mask = base & ...
            perf.residual_recovery_penalty >= cfg.perturbative_penalty_min & ...
            perf.residual_recovery_penalty <= cfg.perturbative_penalty_max & ...
            perf.residual_catastrophic_rate <= cfg.perturbative_cat_max;
        cand = find(mask);
        if isempty(cand)
            cand = find(base & ...
                perf.residual_catastrophic_rate < cfg.catastrophic_rate_min);
        end
        if isempty(cand); idx = []; return; end
        target = 0.15;
        score = abs(perf.residual_recovery_penalty(cand)-target) + ...
            1.5*perf.residual_catastrophic_rate(cand);
        [~,j] = min(score);
        idx = cand(j);

    case "Catastrophic"
        mask = base & ...
            perf.residual_catastrophic_rate >= cfg.catastrophic_rate_min;
        cand = find(mask);
        if isempty(cand); cand = find(base); end
        if isempty(cand); idx = []; return; end
        score = 10*perf.residual_catastrophic_rate(cand) + ...
            perf.residual_recovery_penalty(cand);
        [~,j] = max(score);
        idx = cand(j);

    otherwise
        error('Unknown regime.');
end
end

%% ========================================================================
function auc = binary_auc(y,score)
y = logical(y(:));
score = score(:);
valid = isfinite(score);
y = y(valid);
score = score(valid);

pos = score(y);
neg = score(~y);

if isempty(pos) || isempty(neg)
    auc = NaN;
    return;
end

wins = 0;
ties = 0;
for i = 1:numel(pos)
    wins = wins + sum(pos(i)>neg);
    ties = ties + sum(pos(i)==neg);
end
auc = (wins + 0.5*ties)/(numel(pos)*numel(neg));
end

%% ========================================================================
function [fpr,tpr,thr] = roc_curve_manual(y,score)
y = logical(y(:));
score = score(:);
valid = isfinite(score);
y = y(valid);
score = score(valid);

u = unique(score,'sorted');
thr = [Inf; flipud(u); -Inf];

P = sum(y);
N = sum(~y);

fpr = nan(numel(thr),1);
tpr = nan(numel(thr),1);

for i = 1:numel(thr)
    pred = score >= thr(i);
    TP = sum(pred & y);
    FP = sum(pred & ~y);

    if P>0; tpr(i)=TP/P; end
    if N>0; fpr(i)=FP/N; end
end
end

%% ========================================================================
function [thr,Jmax] = optimal_youden_threshold(fpr,tpr,thresholds)
J = tpr-fpr;
valid = isfinite(J) & isfinite(thresholds);

if ~any(valid)
    thr = NaN;
    Jmax = NaN;
    return;
end

Jv = J(valid);
Tv = thresholds(valid);
[Jmax,j] = max(Jv);
thr = Tv(j);
end

%% ========================================================================
function C = confusion_counts(y,pred)
y = logical(y(:));
pred = logical(pred(:));

C.TP = sum(y & pred);
C.FP = sum(~y & pred);
C.TN = sum(~y & ~pred);
C.FN = sum(y & ~pred);
end

%% ========================================================================
function rho = spearman_manual(x,y)
x = x(:); y = y(:);
valid = isfinite(x) & isfinite(y);
x = x(valid); y = y(valid);

if numel(x)<3
    rho = NaN;
    return;
end

rx = average_ranks(x);
ry = average_ranks(y);

C = corrcoef(rx,ry);
rho = C(1,2);
end

%% ========================================================================
function r = average_ranks(x)
x = x(:);
[xs,ord] = sort(x);
rs = nan(size(xs));

i = 1;
while i <= numel(xs)
    j = i;
    while j < numel(xs) && xs(j+1)==xs(i)
        j = j+1;
    end
    rs(i:j) = (i+j)/2;
    i = j+1;
end

r = nan(size(x));
r(ord) = rs;
end

%% ========================================================================
function [lo,hi] = wilson_ci(k,n,alpha)
if n<=0
    lo = NaN; hi = NaN; return;
end

if abs(alpha-0.05)<1e-12
    z = 1.959963984540054;
else
    z = sqrt(2)*erfinv(1-alpha);
end

p = k/n;
den = 1+z^2/n;
center = (p+z^2/(2*n))/den;
half = z*sqrt(p*(1-p)/n + z^2/(4*n^2))/den;

lo = max(0,center-half);
hi = min(1,center+half);
end

%% ========================================================================
function [lo,hi] = bootstrap_mean_ci(x,B,alpha)
x = x(:);
n = numel(x);
boot = nan(B,1);

for b = 1:B
    idx = randi(n,n,1);
    boot(b) = mean(x(idx));
end

boot = sort(boot);
ilo = max(1,ceil((alpha/2)*B));
ihi = min(B,floor((1-alpha/2)*B));

lo = boot(ilo);
hi = boot(ihi);
end

%% ========================================================================
function fld = snr_field(snr_db)
if snr_db >= 0
    fld = sprintf('snr_p_%g',snr_db);
else
    fld = sprintf('snr_m_%g',abs(snr_db));
end
fld = strrep(fld,'.','p');
end

%% ========================================================================
function make_figures(out_dir,cfg,perf,mech, ...
    fprG,tprG,auc_gamma,gamma_opt_threshold,refined)

ratios = unique(mech.weak_ratio).';
seps = unique(mech.signed_separation).';

% Fig 1: Gamma heatmap
gamma_mech = abs(mech.first_order_predicted_bias)/cfg.tau_q;
Z = mechanism_to_grid(mech,ratios,seps,gamma_mech);

fig = figure('Visible',cfg.figure_visible);
imagesc(seps,ratios,Z); axis xy; colorbar;
xlabel('q_s - q_w'); ylabel('A_w / A_s');
title('\Gamma = |\delta q_{pred}| / \tau_q');
exportgraphics(fig,fullfile(out_dir,'fig01_gamma_heatmap.png'), ...
    'Resolution',180);
close(fig);

% Fig 2: Gamma vs B1 penalty
m = perf.feasible;
fig = figure('Visible',cfg.figure_visible);
scatter(perf.Gamma(m),perf.residual_recovery_penalty(m), ...
    46,perf.snr_db(m),'filled');
hold on;
xline(1,'--','\Gamma=1');
yline(cfg.danger_penalty_threshold,'--','Danger penalty');
xlabel('\Gamma'); ylabel('B1 residual-induced recovery penalty');
title('B2: \Gamma vs B1 Recovery Penalty');
cb=colorbar; cb.Label.String='SNR (dB)'; grid on;
exportgraphics(fig,fullfile(out_dir,'fig02_gamma_vs_b1_penalty.png'), ...
    'Resolution',180);
close(fig);

% Fig 3: Lambda vs penalty
fig = figure('Visible',cfg.figure_visible);
scatter(perf.Lambda(m),perf.residual_recovery_penalty(m), ...
    46,perf.snr_db(m),'filled');
hold on;
yline(cfg.danger_penalty_threshold,'--','Danger penalty');
xlabel('\Lambda = E_{strong,res}/E_w');
ylabel('B1 residual-induced recovery penalty');
title('B2: \Lambda vs B1 Recovery Penalty');
cb=colorbar; cb.Label.String='SNR (dB)'; grid on;
exportgraphics(fig,fullfile(out_dir,'fig03_lambda_vs_b1_penalty.png'), ...
    'Resolution',180);
close(fig);

% Fig 4: Gamma ROC
fig = figure('Visible',cfg.figure_visible);
plot(fprG,tprG,'-o','LineWidth',1.4); hold on;
plot([0 1],[0 1],'--');
xlabel('False positive rate'); ylabel('True positive rate');
title(sprintf('B2 Gamma ROC, AUC = %.3f',auc_gamma));
grid on; axis square;
exportgraphics(fig,fullfile(out_dir,'fig04_gamma_roc.png'), ...
    'Resolution',180);
close(fig);

% Fig 5: Gamma-Lambda risk plane
fig = figure('Visible',cfg.figure_visible);
scatter(perf.Gamma(m),perf.Lambda(m),52, ...
    perf.residual_recovery_penalty(m),'filled');
hold on; xline(1,'--');
xlabel('\Gamma'); ylabel('\Lambda');
title('B2 B1 Risk Plane: \Gamma vs \Lambda');
cb=colorbar; cb.Label.String='Recovery penalty'; grid on;
exportgraphics(fig,fullfile(out_dir,'fig05_gamma_lambda_risk_plane.png'), ...
    'Resolution',180);
close(fig);

% Fig 6: Refined penalty vs Gamma with CI
fig = figure('Visible',cfg.figure_visible);
x = refined.Gamma;
y = refined.paired_recovery_penalty;
elo = y-refined.penalty_ci_low;
ehi = refined.penalty_ci_high-y;
errorbar(x,y,elo,ehi,'o','LineStyle','none','LineWidth',1.2);
hold on;
xline(1,'--','\Gamma=1');
yline(cfg.danger_penalty_threshold,'--','Danger penalty');
for i=1:height(refined)
    text(x(i),y(i),sprintf('  #%d',refined.cell_id(i)));
end
xlabel('\Gamma'); ylabel('Refined paired recovery penalty');
title('B2 Refined MC: Penalty vs \Gamma'); grid on;
exportgraphics(fig,fullfile(out_dir,'fig06_refined_penalty_vs_gamma.png'), ...
    'Resolution',180);
close(fig);

% Fig 7: Baseline vs residual recall
fig = figure('Visible',cfg.figure_visible);
bar([refined.baseline_recovery_rate,refined.residual_recovery_rate]);
ylim([0 1]); xlabel('Selected cell ID'); ylabel('Recovery rate');
title('B2 Refined Recovery: Baseline vs Residual');
legend('Baseline','Residual','Location','best'); grid on;
exportgraphics(fig,fullfile(out_dir,'fig07_refined_recovery.png'), ...
    'Resolution',180);
close(fig);

% Fig 8: Catastrophic rate vs Gamma
fig = figure('Visible',cfg.figure_visible);
scatter(refined.Gamma,refined.residual_catastrophic_rate, ...
    60,refined.snr_db,'filled');
hold on; xline(1,'--');
xlabel('\Gamma'); ylabel('Residual catastrophic rate');
title('B2 Refined Catastrophic Rate vs \Gamma');
cb=colorbar; cb.Label.String='SNR (dB)'; grid on;
exportgraphics(fig,fullfile(out_dir,'fig08_refined_catastrophic_vs_gamma.png'), ...
    'Resolution',180);
close(fig);

% Fig 9: Safe vs dangerous Gamma distributions
fig = figure('Visible',cfg.figure_visible);
histogram(perf.Gamma(perf.feasible & ~perf.dangerous), ...
    'Normalization','probability'); hold on;
histogram(perf.Gamma(perf.feasible & perf.dangerous), ...
    'Normalization','probability');
xline(1,'--','\Gamma=1');
xline(gamma_opt_threshold,':','B1 optimal threshold');
xlabel('\Gamma'); ylabel('Probability');
title('B2 Gamma Distribution: Safe vs Dangerous B1 Cells');
legend('Safe','Dangerous','Location','best'); grid on;
exportgraphics(fig,fullfile(out_dir,'fig09_gamma_distributions.png'), ...
    'Resolution',180);
close(fig);
end

%% ========================================================================
function Z = mechanism_to_grid(tbl,ratios,seps,values)
Z = nan(numel(ratios),numel(seps));

for ir=1:numel(ratios)
    for id=1:numel(seps)
        m = abs(tbl.weak_ratio-ratios(ir))<1e-12 & ...
            abs(tbl.signed_separation-seps(id))<1e-12;
        idx = find(m,1);
        if isempty(idx); error('Missing mechanism-map cell.'); end
        Z(ir,id) = values(idx);
    end
end
end
