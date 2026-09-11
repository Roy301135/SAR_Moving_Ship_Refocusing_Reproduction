function results = exp09b3_observable_reliability()
%EXP09B3_OBSERVABLE_RELIABILITY
% EXP009 / Pilot-01 / Experiment B3
%
% Observable Reliability Surrogate
%
% -------------------------------------------------------------------------
% Scientific question
% -------------------------------------------------------------------------
% B2 showed that the oracle physics index
%
%   Gamma = |delta_q_pred| / tau_q
%
% ranks dangerous cells well, but Gamma is not directly observable in a
% practical algorithm. It also does not fully explain stochastic
% perturbative failure or catastrophic peak replacement.
%
% B3 therefore asks:
%
%   Can actual residual q-search curve features identify:
%
%   (1) residual-induced failure;
%   (2) non-catastrophic perturbative failure;
%   (3) catastrophic peak ambiguity?
%
% Every candidate feature below is computed from quantities that would be
% available during the residual q search. True q is used ONLY to create
% ground-truth labels for this controlled synthetic experiment.
%
% -------------------------------------------------------------------------
% Trial labels
% -------------------------------------------------------------------------
% Baseline:
%   s_w + n
%
% Residual:
%   s_w + e_s + n
%
% residual-induced failure:
%   baseline succeeds AND residual fails
%
% perturbative failure:
%   residual-induced failure AND |q_hat-q_w| < catastrophic threshold
%
% catastrophic failure:
%   baseline succeeds AND residual error >= catastrophic threshold
%
% Conditioning on baseline success isolates failure introduced by the
% sequential residual rather than intrinsic weak/noise failure.
%
% -------------------------------------------------------------------------
% Observable features
% -------------------------------------------------------------------------
% From residual concentration metric M(q):
%
%   second_to_first
%   peak_margin_norm
%   prominence
%   peak_to_floor
%   peak_zscore
%   margin_to_mad
%   local_curvature_1
%   local_curvature_2
%   width50_q
%   width80_q
%   local_asymmetry / abs_local_asymmetry
%   curve_entropy
%   competitor_count
%   second_peak_separation_q
%   grid_instability_bins
%
% From residual signal state:
%
%   residual_energy_ratio_obs = ||r||^2 / ||x_mixture||^2
%
% -------------------------------------------------------------------------
% Diagnostics
% -------------------------------------------------------------------------
% 1) Single-feature AUC for any / perturbative / catastrophic failure.
% 2) Cell-level correlation of observable feature means with:
%      - oracle Gamma
%      - refined recovery penalty
% 3) Leave-one-cell-out logistic fusion of a fixed observable feature set.
%    This is only a diagnostic upper bound; it is NOT the final method.
%
% Run:
%   results = exp09b3_observable_reliability;

cfg = config_exp09b3();

%% Paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.b2_result_dir)
    b2_dir = fullfile(paper_root,'results','exp09_pilot01', ...
        'exp09b2_regime_gamma');
else
    b2_dir = cfg.b2_result_dir;
end

if isempty(cfg.output_dir)
    out_dir = fullfile(paper_root,'results','exp09_pilot01', ...
        'exp09b3_observable_reliability');
else
    out_dir = cfg.output_dir;
end

if ~exist(out_dir,'dir')
    mkdir(out_dir);
end

selected_file = fullfile(b2_dir,'selected_cells.csv');
refined_file = fullfile(b2_dir,'refined_cell_summary.csv');

if ~exist(selected_file,'file')
    error('B2 selected_cells.csv not found: %s', selected_file);
end

if ~exist(refined_file,'file')
    error('B2 refined_cell_summary.csv not found: %s', refined_file);
end

selected = readtable(selected_file);
refined_b2 = readtable(refined_file);

required_sel = { ...
    'weak_ratio','signed_separation','snr_db','Gamma','Lambda','cell_id'};
assert_table_vars(selected,required_sel,'selected_cells.csv');

required_ref = { ...
    'cell_id','baseline_recovery_rate','residual_recovery_rate', ...
    'paired_recovery_penalty','residual_catastrophic_rate'};
assert_table_vars(refined_b2,required_ref,'refined_cell_summary.csv');

selected = sortrows(selected,'cell_id');
refined_b2 = sortrows(refined_b2,'cell_id');

if height(selected) ~= height(refined_b2)
    error('B2 selected/refined tables have different row counts.');
end

if any(selected.cell_id ~= refined_b2.cell_id)
    error('B2 selected/refined cell IDs do not align.');
end

fprintf('\n============================================================\n');
fprintf(' EXP009-B3 / Observable Reliability Surrogate\n');
fprintf('============================================================\n');
fprintf('B2 input: %s\n', b2_dir);
fprintf('Output:   %s\n', out_dir);
fprintf('Selected cells: %d\n', height(selected));
fprintf('MC trials/cell: %d\n\n', cfg.num_mc);

%% Common signal/search setup
rng(cfg.seed,'twister');

N = cfg.N;
n = 0:N-1;
t = (n-N/2)/N;

q_search = cfg.q_search_min:cfg.q_search_step:cfg.q_search_max;
D_search = build_dechirp_dictionary(q_search,t,cfg);

K = height(selected);
M = cfg.num_mc;

% Match B2 strong-referenced SNR convention.
s_ref = synth_lfm(cfg.A_strong,cfg.q_weak-0.05, ...
    cfg.f_strong,cfg.phi_strong,t,cfg);
Pstrong = mean(abs(s_ref).^2);

sel_snrs = unique(selected.snr_db).';
noise_bank = struct();

for is = 1:numel(sel_snrs)
    s = sel_snrs(is);
    noise_var = Pstrong/(10^(s/10));
    fld = snr_field(s);
    noise_bank.(fld) = sqrt(noise_var/2) * ...
        (randn(M,N)+1j*randn(M,N));
end

%% Feature names
feature_names = { ...
    'second_to_first', ...
    'peak_margin_norm', ...
    'prominence', ...
    'peak_to_floor', ...
    'peak_zscore', ...
    'margin_to_mad', ...
    'local_curvature_1', ...
    'local_curvature_2', ...
    'width50_q', ...
    'width80_q', ...
    'local_asymmetry', ...
    'abs_local_asymmetry', ...
    'curve_entropy', ...
    'competitor_count', ...
    'second_peak_separation_q', ...
    'grid_instability_bins', ...
    'residual_energy_ratio_obs'};

F = numel(feature_names);

%% Trial-level storage
nRows = K*M;

cell_id = zeros(nRows,1);
trial_id = zeros(nRows,1);
selection_regime = strings(nRows,1);

weak_ratio = nan(nRows,1);
signed_sep = nan(nRows,1);
snr_db = nan(nRows,1);
Gamma = nan(nRows,1);
Lambda = nan(nRows,1);

baseline_q_hat = nan(nRows,1);
residual_q_hat = nan(nRows,1);

baseline_success = false(nRows,1);
residual_success = false(nRows,1);

residual_signed_bias = nan(nRows,1);
residual_abs_error = nan(nRows,1);

induced_failure = false(nRows,1);
perturbative_failure = false(nRows,1);
catastrophic_failure = false(nRows,1);
residual_catastrophic_any = false(nRows,1);
rescue_event = false(nRows,1);

X = nan(nRows,F);

% Representative curves for visualization.
examples = struct();
examples.easy_success_found = false;
examples.perturb_failure_found = false;
examples.cat_failure_found = false;

row = 0;

%% Rerun B2 selected cells and extract practical observable features
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

    if ismember('selection_regime',selected.Properties.VariableNames)
        regime_name = string(selected.selection_regime(ik));
    else
        regime_name = "Unknown";
    end

    for imc = 1:M
        noise = nb(imc,:);

        x_mix = s_s + s_w + noise;
        xb = s_w + noise;
        xr = s_w + e_s + noise;

        [qhb,~,~] = search_q_concentration(xb,q_search,D_search);
        [qhr,metric_r,idx_r] = ...
            search_q_concentration(xr,q_search,D_search);

        eb = abs(qhb-cfg.q_weak);
        br = qhr-cfg.q_weak;
        er = abs(br);

        sb = eb <= (cfg.tau_q+cfg.success_tol);
        sr = er <= (cfg.tau_q+cfg.success_tol);

        cat_any = ...
            er >= (cfg.catastrophic_error_q-cfg.success_tol);

        cat = sb && cat_any;

        induced = sb && ~sr;
        pert = induced && ~cat;
        rescue = ~sb && sr;

        feat = extract_curve_features( ...
            metric_r,idx_r,q_search,cfg);

        residual_energy_ratio_obs = ...
            sum(abs(xr).^2)/max(sum(abs(x_mix).^2),eps);

        feat_vec = [ ...
            feat.second_to_first, ...
            feat.peak_margin_norm, ...
            feat.prominence, ...
            feat.peak_to_floor, ...
            feat.peak_zscore, ...
            feat.margin_to_mad, ...
            feat.local_curvature_1, ...
            feat.local_curvature_2, ...
            feat.width50_q, ...
            feat.width80_q, ...
            feat.local_asymmetry, ...
            abs(feat.local_asymmetry), ...
            feat.curve_entropy, ...
            feat.competitor_count, ...
            feat.second_peak_separation_q, ...
            feat.grid_instability_bins, ...
            residual_energy_ratio_obs];

        row = row+1;

        cell_id(row) = selected.cell_id(ik);
        trial_id(row) = imc;
        selection_regime(row) = regime_name;

        weak_ratio(row) = rA;
        signed_sep(row) = sep;
        snr_db(row) = s;
        Gamma(row) = selected.Gamma(ik);
        Lambda(row) = selected.Lambda(ik);

        baseline_q_hat(row) = qhb;
        residual_q_hat(row) = qhr;

        baseline_success(row) = sb;
        residual_success(row) = sr;

        residual_signed_bias(row) = br;
        residual_abs_error(row) = er;

        induced_failure(row) = induced;
        perturbative_failure(row) = pert;
        catastrophic_failure(row) = cat;
        residual_catastrophic_any(row) = cat_any;
        rescue_event(row) = rescue;

        X(row,:) = feat_vec;

        % Save one representative curve of each type.
        if ~examples.easy_success_found && ...
                regime_name=="Easy" && sb && sr
            examples.easy_success_found = true;
            examples.easy_success.metric = metric_r;
            examples.easy_success.q = q_search;
            examples.easy_success.cell_id = selected.cell_id(ik);
            examples.easy_success.q_hat = qhr;
        end

        if ~examples.perturb_failure_found && pert
            examples.perturb_failure_found = true;
            examples.perturb_failure.metric = metric_r;
            examples.perturb_failure.q = q_search;
            examples.perturb_failure.cell_id = selected.cell_id(ik);
            examples.perturb_failure.q_hat = qhr;
        end

        if ~examples.cat_failure_found && cat
            examples.cat_failure_found = true;
            examples.cat_failure.metric = metric_r;
            examples.cat_failure.q = q_search;
            examples.cat_failure.cell_id = selected.cell_id(ik);
            examples.cat_failure.q_hat = qhr;
        end
    end
end

%% Assemble trial table
trial_table = table( ...
    cell_id,trial_id,selection_regime,weak_ratio,signed_sep,snr_db, ...
    Gamma,Lambda,baseline_q_hat,residual_q_hat, ...
    baseline_success,residual_success,residual_signed_bias, ...
    residual_abs_error,induced_failure,perturbative_failure, ...
    catastrophic_failure,residual_catastrophic_any,rescue_event);

for jf = 1:F
    trial_table.(feature_names{jf}) = X(:,jf);
end

writetable(trial_table,fullfile(out_dir,'observable_trial_features.csv'));

%% ------------------------------------------------------------------------
% Reproduction check against B2 refined summary
rep_cell = selected.cell_id;
rep_base = nan(K,1);
rep_res = nan(K,1);
rep_penalty = nan(K,1);
rep_cat = nan(K,1);
rep_base_diff = nan(K,1);
rep_res_diff = nan(K,1);
rep_penalty_diff = nan(K,1);
rep_cat_diff = nan(K,1);

for ik = 1:K
    mm = trial_table.cell_id == selected.cell_id(ik);

    rep_base(ik) = mean(trial_table.baseline_success(mm));
    rep_res(ik) = mean(trial_table.residual_success(mm));
    rep_penalty(ik) = rep_base(ik)-rep_res(ik);
    rep_cat(ik) = mean(trial_table.residual_catastrophic_any(mm));

    rep_base_diff(ik) = rep_base(ik)-refined_b2.baseline_recovery_rate(ik);
    rep_res_diff(ik) = rep_res(ik)-refined_b2.residual_recovery_rate(ik);
    rep_penalty_diff(ik) = ...
        rep_penalty(ik)-refined_b2.paired_recovery_penalty(ik);
    rep_cat_diff(ik) = ...
        rep_cat(ik)-refined_b2.residual_catastrophic_rate(ik);
end

reproduction_check = table( ...
    rep_cell,rep_base,refined_b2.baseline_recovery_rate,rep_base_diff, ...
    rep_res,refined_b2.residual_recovery_rate,rep_res_diff, ...
    rep_penalty,refined_b2.paired_recovery_penalty,rep_penalty_diff, ...
    rep_cat,refined_b2.residual_catastrophic_rate,rep_cat_diff, ...
    'VariableNames',{ ...
    'cell_id','b3_baseline_recall','b2_baseline_recall','baseline_diff', ...
    'b3_residual_recall','b2_residual_recall','residual_diff', ...
    'b3_penalty','b2_penalty','penalty_diff', ...
    'b3_catastrophic_rate','b2_catastrophic_rate','catastrophic_diff'});

writetable(reproduction_check, ...
    fullfile(out_dir,'b2_reproduction_check.csv'));

max_reproduction_diff = max(abs([ ...
    rep_base_diff;rep_res_diff;rep_penalty_diff;rep_cat_diff]));

%% ------------------------------------------------------------------------
% Single-feature AUC audit
%
% Any / perturbative / catastrophic are evaluated ONLY on trials where
% baseline succeeded, so that the target isolates residual-induced effects.
eval_mask = trial_table.baseline_success;

y_any = trial_table.induced_failure(eval_mask);
y_pert = trial_table.perturbative_failure(eval_mask);
y_cat = trial_table.catastrophic_failure(eval_mask);

feature_col = strings(F,1);

auc_any = nan(F,1);
dir_any = strings(F,1);

auc_pert = nan(F,1);
dir_pert = strings(F,1);

auc_cat = nan(F,1);
dir_cat = strings(F,1);

for jf = 1:F
    feature_col(jf) = feature_names{jf};

    score = X(eval_mask,jf);

    [auc_any(jf),dir_any(jf)] = oriented_auc(y_any,score);
    [auc_pert(jf),dir_pert(jf)] = oriented_auc(y_pert,score);
    [auc_cat(jf),dir_cat(jf)] = oriented_auc(y_cat,score);
end

feature_auc_table = table( ...
    feature_col,auc_any,dir_any,auc_pert,dir_pert,auc_cat,dir_cat, ...
    'VariableNames',{ ...
    'feature','auc_induced_failure','risk_direction_induced', ...
    'auc_perturbative_failure','risk_direction_perturbative', ...
    'auc_catastrophic_failure','risk_direction_catastrophic'});

feature_auc_table = sortrows(feature_auc_table, ...
    'auc_induced_failure','descend');

writetable(feature_auc_table,fullfile(out_dir,'feature_auc_ranking.csv'));

%% ------------------------------------------------------------------------
% Cell-level observable means and correlation with oracle Gamma / penalty
cell_mean = nan(K,F);

for ik = 1:K
    mm = trial_table.cell_id == selected.cell_id(ik) & ...
        trial_table.baseline_success;

    if ~any(mm)
        continue;
    end

    cell_mean(ik,:) = mean(X(mm,:),1,'omitnan');
end

cell_feature_table = table(selected.cell_id,selected.Gamma,selected.Lambda, ...
    refined_b2.paired_recovery_penalty, ...
    'VariableNames',{'cell_id','Gamma','Lambda','refined_penalty'});

for jf = 1:F
    cell_feature_table.(['mean_' feature_names{jf}]) = cell_mean(:,jf);
end

writetable(cell_feature_table,fullfile(out_dir,'cell_mean_observables.csv'));

corr_feature = strings(F,1);
rho_gamma = nan(F,1);
rho_penalty = nan(F,1);

for jf = 1:F
    corr_feature(jf) = feature_names{jf};
    rho_gamma(jf) = spearman_manual(cell_mean(:,jf),selected.Gamma);
    rho_penalty(jf) = spearman_manual( ...
        cell_mean(:,jf),refined_b2.paired_recovery_penalty);
end

cell_correlation_table = table( ...
    corr_feature,rho_gamma,rho_penalty, ...
    'VariableNames',{'feature','spearman_with_Gamma', ...
    'spearman_with_refined_penalty'});

cell_correlation_table = sortrows(cell_correlation_table, ...
    'spearman_with_refined_penalty','descend');

writetable(cell_correlation_table, ...
    fullfile(out_dir,'cell_feature_correlations.csv'));

%% ------------------------------------------------------------------------
% Leave-one-cell-out transparent logistic fusion
%
% This is a diagnostic upper bound, not the final proposed method.
logit_names = cfg.logit_feature_names;

logit_idx = zeros(numel(logit_names),1);

for j = 1:numel(logit_names)
    idx = find(strcmp(feature_names,logit_names{j}),1);
    if isempty(idx)
        error('Configured logistic feature "%s" was not found.', ...
            logit_names{j});
    end
    logit_idx(j) = idx;
end

Xlog = X(eval_mask,logit_idx);
ylog = y_any;
groups = trial_table.cell_id(eval_mask);

[p_oof,valid_oof] = loco_logistic_predictions( ...
    Xlog,ylog,groups,cfg.logit_l2);

auc_logit = binary_auc(ylog(valid_oof),p_oof(valid_oof));

% Also report Spearman with the binary outcome as a rank diagnostic.
rho_logit = spearman_manual(p_oof(valid_oof),double(ylog(valid_oof)));

logit_table = table( ...
    trial_table.cell_id(eval_mask), ...
    trial_table.trial_id(eval_mask), ...
    ylog,p_oof,valid_oof, ...
    'VariableNames',{'cell_id','trial_id','induced_failure', ...
    'oof_failure_score','valid_oof'});

writetable(logit_table,fullfile(out_dir,'loco_logistic_scores.csv'));

%% Cell-level OOF predicted risk
logit_cell = selected.cell_id;
logit_mean_risk = nan(K,1);
logit_empirical_fail = nan(K,1);

for ik = 1:K
    mm = logit_table.cell_id == selected.cell_id(ik) & ...
        logit_table.valid_oof;

    if any(mm)
        logit_mean_risk(ik) = mean(logit_table.oof_failure_score(mm));
        logit_empirical_fail(ik) = mean(logit_table.induced_failure(mm));
    end
end

logit_cell_summary = table( ...
    logit_cell,logit_mean_risk,logit_empirical_fail, ...
    selected.Gamma,refined_b2.paired_recovery_penalty, ...
    'VariableNames',{'cell_id','mean_oof_risk','empirical_induced_failure', ...
    'Gamma','refined_penalty'});

writetable(logit_cell_summary, ...
    fullfile(out_dir,'loco_logistic_cell_summary.csv'));

rho_logit_cell_penalty = spearman_manual( ...
    logit_mean_risk,refined_b2.paired_recovery_penalty);

%% ------------------------------------------------------------------------
% Console summary
fprintf('================ B3 REPRODUCTION ====================\n');
fprintf('Max absolute B2 reproduction diff = %.6g\n', ...
    max_reproduction_diff);

fprintf('\n================ B3 FEATURE AUDIT ===================\n');
fprintf('Baseline-success trials            = %d\n',sum(eval_mask));
fprintf('Residual-induced failures          = %d\n',sum(y_any));
fprintf('Perturbative failures              = %d\n',sum(y_pert));
fprintf('Catastrophic failures              = %d\n\n',sum(y_cat));

topN = min(6,height(feature_auc_table));

for i = 1:topN
    fprintf('#%d %-28s AUC(any)=%.3f  AUC(pert)=%.3f  AUC(cat)=%.3f\n', ...
        i,feature_auc_table.feature(i), ...
        feature_auc_table.auc_induced_failure(i), ...
        feature_auc_table.auc_perturbative_failure(i), ...
        feature_auc_table.auc_catastrophic_failure(i));
end

fprintf('\nLOCO observable-fusion AUC          = %.3f\n',auc_logit);
fprintf('LOCO score-outcome Spearman         = %.3f\n',rho_logit);
fprintf('LOCO cell-risk vs penalty Spearman  = %.3f\n', ...
    rho_logit_cell_penalty);
fprintf('=====================================================\n');

%% Text summary
fid = fopen(fullfile(out_dir,'summary.txt'),'w');

fprintf(fid,'EXP009-B3 Observable Reliability Surrogate\n');
fprintf(fid,'==========================================\n\n');

fprintf(fid,'Selected B2 cells: %d\n',K);
fprintf(fid,'MC trials/cell: %d\n',M);
fprintf(fid,'Max B2 reproduction diff: %.8g\n\n', ...
    max_reproduction_diff);

fprintf(fid,'Trial labels conditioned on baseline success\n');
fprintf(fid,'-------------------------------------------\n');
fprintf(fid,'Baseline-success trials: %d\n',sum(eval_mask));
fprintf(fid,'Residual-induced failures: %d\n',sum(y_any));
fprintf(fid,'Perturbative failures: %d\n',sum(y_pert));
fprintf(fid,'Catastrophic failures: %d\n\n',sum(y_cat));

fprintf(fid,'Top observable features by induced-failure AUC\n');
fprintf(fid,'----------------------------------------------\n');

for i = 1:height(feature_auc_table)
    fprintf(fid, ...
        '%s: AUC_any=%.6f dir=%s, AUC_pert=%.6f, AUC_cat=%.6f\n', ...
        feature_auc_table.feature(i), ...
        feature_auc_table.auc_induced_failure(i), ...
        feature_auc_table.risk_direction_induced(i), ...
        feature_auc_table.auc_perturbative_failure(i), ...
        feature_auc_table.auc_catastrophic_failure(i));
end

fprintf(fid,'\nTransparent LOCO logistic diagnostic\n');
fprintf(fid,'------------------------------------\n');
fprintf(fid,'Features: %s\n',strjoin(logit_names,', '));
fprintf(fid,'LOCO AUC: %.6f\n',auc_logit);
fprintf(fid,'LOCO score-outcome Spearman: %.6f\n',rho_logit);
fprintf(fid,'LOCO cell-risk vs refined-penalty Spearman: %.6f\n', ...
    rho_logit_cell_penalty);

fclose(fid);

%% Figures
make_figures(out_dir,cfg,feature_auc_table,trial_table, ...
    cell_correlation_table,cell_feature_table, ...
    logit_table,logit_cell_summary,examples);

%% Save
results = struct();
results.cfg = cfg;
results.selected = selected;
results.refined_b2 = refined_b2;
results.trial_table = trial_table;
results.reproduction_check = reproduction_check;
results.feature_auc_table = feature_auc_table;
results.cell_feature_table = cell_feature_table;
results.cell_correlation_table = cell_correlation_table;
results.logit_table = logit_table;
results.logit_cell_summary = logit_cell_summary;
results.auc_logit = auc_logit;
results.rho_logit_cell_penalty = rho_logit_cell_penalty;
results.examples = examples;

save(fullfile(out_dir,'exp09b3_results.mat'),'results','-v7.3');

fprintf('\nSaved EXP009-B3 outputs to:\n%s\n\n',out_dir);

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
function feat = extract_curve_features(metric,idx_peak,q_grid,cfg)
% All features are computed around the ESTIMATED peak. No true q is used.

m = metric(:);
q = q_grid(:);

L = numel(m);

if numel(q) ~= L
    error('extract_curve_features: metric/q-grid length mismatch.');
end

peak = m(idx_peak);
floor_med = median(m);
floor_mad = median(abs(m-floor_med));

% Second peak outside guard region around primary peak.
keep = true(L,1);

i1 = max(1,idx_peak-cfg.second_peak_guard_bins);
i2 = min(L,idx_peak+cfg.second_peak_guard_bins);

keep(i1:i2) = false;

if any(keep)
    tmp = m;
    tmp(~keep) = -Inf;
    [second_peak,idx_second] = max(tmp);
else
    second_peak = 0;
    idx_second = idx_peak;
end

feat.second_to_first = second_peak/max(peak,eps);
feat.peak_margin_norm = ...
    (peak-second_peak)/max(peak,eps);

feat.prominence = ...
    (peak-floor_med)/max(peak,eps);

feat.peak_to_floor = ...
    peak/max(floor_med,eps);

feat.peak_zscore = ...
    (peak-floor_med)/max(floor_mad,eps);

feat.margin_to_mad = ...
    (peak-second_peak)/max(floor_mad,eps);

% Local curvature at +/- 1 and +/- 2 grid cells.
feat.local_curvature_1 = local_curvature(m,idx_peak,1);
feat.local_curvature_2 = local_curvature(m,idx_peak,2);

% Contiguous width around the primary peak.
feat.width50_q = contiguous_width(m,q,idx_peak,0.50);
feat.width80_q = contiguous_width(m,q,idx_peak,0.80);

% Local left-right asymmetry around estimated peak.
K = cfg.local_asymmetry_bins;

left_sum = 0;
right_sum = 0;

for dk = 1:K
    il = idx_peak-dk;
    ir = idx_peak+dk;

    if il >= 1
        left_sum = left_sum + m(il);
    end

    if ir <= L
        right_sum = right_sum + m(ir);
    end
end

feat.local_asymmetry = ...
    (right_sum-left_sum)/max(right_sum+left_sum,eps);

% Normalized entropy of the whole q-search curve.
pp = m/max(sum(m),eps);
pp = pp(pp>0);

if L > 1
    feat.curve_entropy = ...
        -sum(pp.*log(pp))/log(L);
else
    feat.curve_entropy = 0;
end

% Number of competing local maxima above a fraction of primary peak.
local_max = false(L,1);

if L >= 3
    local_max(2:L-1) = ...
        m(2:L-1) >= m(1:L-2) & ...
        m(2:L-1) >= m(3:L);
end

local_max(idx_peak) = false;

feat.competitor_count = ...
    sum(local_max & m >= cfg.competitor_fraction*peak);

feat.second_peak_separation_q = ...
    abs(q(idx_second)-q(idx_peak));

% Alternate-grid instability:
% compare maxima on odd and even candidate subsets.
odd_idx = 1:2:L;
even_idx = 2:2:L;

[~,jo] = max(m(odd_idx));
q_odd = q(odd_idx(jo));

if isempty(even_idx)
    q_even = q_odd;
else
    [~,je] = max(m(even_idx));
    q_even = q(even_idx(je));
end

feat.grid_instability_bins = ...
    abs(q_odd-q_even)/max(abs(q(2)-q(1)),eps);

% Keep floor MAD for future diagnostics if needed.
feat.floor_mad = floor_mad;
end

%% ========================================================================
function c = local_curvature(m,idx_peak,offset)
L = numel(m);

il = idx_peak-offset;
ir = idx_peak+offset;

if il < 1 || ir > L
    c = 0;
    return;
end

peak = m(idx_peak);
c = (peak - 0.5*(m(il)+m(ir)))/max(peak,eps);
end

%% ========================================================================
function w = contiguous_width(m,q,idx_peak,fraction)
threshold = fraction*m(idx_peak);

il = idx_peak;
ir = idx_peak;

while il>1 && m(il-1)>=threshold
    il = il-1;
end

while ir<numel(m) && m(ir+1)>=threshold
    ir = ir+1;
end

w = q(ir)-q(il);
end

%% ========================================================================
function [auc_best,direction] = oriented_auc(y,score)
auc_plus = binary_auc(y,score);
auc_minus = binary_auc(y,-score);

if isnan(auc_plus) && isnan(auc_minus)
    auc_best = NaN;
    direction = "NA";
elseif isnan(auc_minus) || auc_plus >= auc_minus
    auc_best = auc_plus;
    direction = "+";
else
    auc_best = auc_minus;
    direction = "-";
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

auc = (wins+0.5*ties)/(numel(pos)*numel(neg));
end

%% ========================================================================
function rho = spearman_manual(x,y)
x = x(:);
y = y(:);

valid = isfinite(x) & isfinite(y);

x = x(valid);
y = y(valid);

if numel(x) < 3
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
function assert_table_vars(tbl,names,filename)
vars = tbl.Properties.VariableNames;

for i = 1:numel(names)
    if ~ismember(names{i},vars)
        error('Missing variable "%s" in %s.',names{i},filename);
    end
end
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
function [p_oof,valid_oof] = loco_logistic_predictions(X,y,groups,l2)
% Leave-one-cell-out logistic regression using base MATLAB only.
%
% This is a diagnostic fusion model. Standardization is fit ONLY on the
% training cells of each fold.

X = double(X);
y = double(y(:));
groups = groups(:);

n = size(X,1);

p_oof = nan(n,1);
valid_oof = false(n,1);

ug = unique(groups).';

for ig = 1:numel(ug)
    g = ug(ig);

    test = groups==g;
    train = ~test;

    Xtr = X(train,:);
    ytr = y(train);

    if numel(unique(ytr)) < 2
        continue;
    end

    mu = mean(Xtr,1,'omitnan');
    sd = std(Xtr,0,1,'omitnan');

    sd(~isfinite(sd) | sd<1e-12) = 1;
    mu(~isfinite(mu)) = 0;

    Xtr = fill_nonfinite_with_training_mean(Xtr,mu);
    Xte = fill_nonfinite_with_training_mean(X(test,:),mu);

    Ztr = bsxfun(@rdivide,bsxfun(@minus,Xtr,mu),sd);
    Zte = bsxfun(@rdivide,bsxfun(@minus,Xte,mu),sd);

    Xtr1 = [ones(size(Ztr,1),1),Ztr];
    Xte1 = [ones(size(Zte,1),1),Zte];

    beta0 = zeros(size(Xtr1,2),1);

    objective = @(b) logistic_objective(b,Xtr1,ytr,l2);

    opts = optimset( ...
        'Display','off', ...
        'MaxIter',1200, ...
        'MaxFunEvals',6000, ...
        'TolX',1e-7, ...
        'TolFun',1e-7);

    beta = fminsearch(objective,beta0,opts);

    z = Xte1*beta;
    z = max(min(z,35),-35);

    p_oof(test) = 1./(1+exp(-z));
    valid_oof(test) = true;
end
end

%% ========================================================================
function Xo = fill_nonfinite_with_training_mean(X,mu)
Xo = X;

for j = 1:size(Xo,2)
    bad = ~isfinite(Xo(:,j));

    if any(bad)
        Xo(bad,j) = mu(j);
    end
end
end

%% ========================================================================
function loss = logistic_objective(beta,X,y,l2)
z = X*beta;
z = max(min(z,35),-35);

p = 1./(1+exp(-z));

loss = -sum( ...
    y.*log(max(p,eps)) + ...
    (1-y).*log(max(1-p,eps)));

% Do not regularize intercept.
loss = loss + l2*sum(beta(2:end).^2);
end

%% ========================================================================
function make_figures(out_dir,cfg,auc_tbl,trials, ...
    corr_tbl,cell_tbl,logit_tbl,logit_cell,examples)

%% Fig 1: Top feature AUCs
topN = min(10,height(auc_tbl));
T = auc_tbl(1:topN,:);

fig = figure('Visible',cfg.figure_visible);

Y = [ ...
    T.auc_induced_failure, ...
    T.auc_perturbative_failure, ...
    T.auc_catastrophic_failure];

bar(Y);
ylim([0.45 1]);

xticks(1:topN);
xticklabels(T.feature);
xtickangle(35);

ylabel('Oriented AUC');
title('B3 Observable Feature Audit');
legend('Any induced failure','Perturbative','Catastrophic', ...
    'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig01_feature_auc_ranking.png'), ...
    'Resolution',180);
close(fig);

%% Fig 2: Best induced-failure feature distribution
best_feature = char(T.feature(1));

x = trials.(best_feature);

mask = trials.baseline_success;

fig = figure('Visible',cfg.figure_visible);

group = double(trials.induced_failure(mask))+1;
boxchart(group,x(mask));

xticks([1 2]);
xticklabels({'No induced failure','Residual-induced failure'});

ylabel(best_feature,'Interpreter','none');
title(sprintf('B3 Best Observable Feature: %s',best_feature), ...
    'Interpreter','none');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig02_best_feature_distribution.png'), ...
    'Resolution',180);
close(fig);

%% Fig 3: peak competition plane
fig = figure('Visible',cfg.figure_visible);

m = trials.baseline_success;

classes = zeros(sum(m),1);
classes(trials.perturbative_failure(m)) = 1;
classes(trials.catastrophic_failure(m)) = 2;

scatter( ...
    trials.second_to_first(m), ...
    trials.local_curvature_1(m), ...
    22,classes,'filled');

xlabel('Second / first peak');
ylabel('Local curvature');
title('B3 Observable Peak-Competition Plane');

cb = colorbar;
cb.Ticks = [0 1 2];
cb.TickLabels = {'Safe','Perturbative','Catastrophic'};

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig03_peak_competition_plane.png'), ...
    'Resolution',180);
close(fig);

%% Fig 4: ambiguity plane
fig = figure('Visible',cfg.figure_visible);

scatter( ...
    trials.second_to_first(m), ...
    trials.grid_instability_bins(m), ...
    22,classes,'filled');

xlabel('Second / first peak');
ylabel('Odd-even grid peak disagreement (bins)');
title('B3 Catastrophic Ambiguity Observables');

cb = colorbar;
cb.Ticks = [0 1 2];
cb.TickLabels = {'Safe','Perturbative','Catastrophic'};

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig04_ambiguity_plane.png'), ...
    'Resolution',180);
close(fig);

%% Fig 5: Cell feature correlation with Gamma / penalty
% Sort by absolute penalty correlation for visual readability.
rhoP = corr_tbl.spearman_with_refined_penalty;
[~,ord] = sort(abs(rhoP),'descend');

topN2 = min(10,numel(ord));
ord = ord(1:topN2);

fig = figure('Visible',cfg.figure_visible);

Y = [ ...
    corr_tbl.spearman_with_Gamma(ord), ...
    corr_tbl.spearman_with_refined_penalty(ord)];

bar(Y);
ylim([-1 1]);

xticks(1:topN2);
xticklabels(corr_tbl.feature(ord));
xtickangle(35);

ylabel('Spearman correlation');
title('B3 Cell-Level Observable Correlations');
legend('\Gamma','Refined penalty','Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig05_cell_feature_correlations.png'), ...
    'Resolution',180);
close(fig);

%% Fig 6: Best penalty-correlated cell observable
[~,ibest] = max(abs(corr_tbl.spearman_with_refined_penalty));

feat_name = char(corr_tbl.feature(ibest));
col_name = ['mean_' feat_name];

fig = figure('Visible',cfg.figure_visible);

scatter( ...
    cell_tbl.(col_name), ...
    cell_tbl.refined_penalty, ...
    75,cell_tbl.Gamma,'filled');

xlabel(feat_name,'Interpreter','none');
ylabel('B2 refined recovery penalty');

title(sprintf('B3 Cell Observable vs Penalty: %s',feat_name), ...
    'Interpreter','none');

cb = colorbar;
cb.Label.String = '\Gamma';

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig06_best_cell_observable_vs_penalty.png'), ...
    'Resolution',180);
close(fig);

%% Fig 7: Leave-one-cell-out logistic ROC
valid = logit_tbl.valid_oof;

[fpr,tpr,~] = roc_curve_manual( ...
    logit_tbl.induced_failure(valid), ...
    logit_tbl.oof_failure_score(valid));

auc = binary_auc( ...
    logit_tbl.induced_failure(valid), ...
    logit_tbl.oof_failure_score(valid));

fig = figure('Visible',cfg.figure_visible);

plot(fpr,tpr,'-o','LineWidth',1.3);
hold on;
plot([0 1],[0 1],'--');

xlabel('False positive rate');
ylabel('True positive rate');
title(sprintf('B3 LOCO Observable Fusion, AUC = %.3f',auc));

grid on;
axis square;

exportgraphics(fig, ...
    fullfile(out_dir,'fig07_loco_logistic_roc.png'), ...
    'Resolution',180);
close(fig);

%% Fig 8: Cell-level LOCO risk vs empirical failure
fig = figure('Visible',cfg.figure_visible);

scatter( ...
    logit_cell.mean_oof_risk, ...
    logit_cell.empirical_induced_failure, ...
    75,logit_cell.Gamma,'filled');

xlabel('Mean LOCO observable risk score');
ylabel('Empirical residual-induced failure probability');
title('B3 Practical Observable Risk vs Empirical Failure');

cb = colorbar;
cb.Label.String = '\Gamma';

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig08_loco_cell_risk.png'), ...
    'Resolution',180);
close(fig);

%% Fig 9: Representative residual concentration curves
if examples.easy_success_found || ...
        examples.perturb_failure_found || ...
        examples.cat_failure_found

    fig = figure('Visible',cfg.figure_visible);

    labels = {};

    if examples.easy_success_found
        plot( ...
            examples.easy_success.q, ...
            normalize01(examples.easy_success.metric), ...
            'LineWidth',1.3);
        hold on;
        labels{end+1} = sprintf('Easy success (#%d)', ...
            examples.easy_success.cell_id); %#ok<AGROW>
    end

    if examples.perturb_failure_found
        plot( ...
            examples.perturb_failure.q, ...
            normalize01(examples.perturb_failure.metric), ...
            'LineWidth',1.3);
        hold on;
        labels{end+1} = sprintf('Perturbative failure (#%d)', ...
            examples.perturb_failure.cell_id); %#ok<AGROW>
    end

    if examples.cat_failure_found
        plot( ...
            examples.cat_failure.q, ...
            normalize01(examples.cat_failure.metric), ...
            'LineWidth',1.3);
        hold on;
        labels{end+1} = sprintf('Catastrophic failure (#%d)', ...
            examples.cat_failure.cell_id); %#ok<AGROW>
    end

    xline(cfg.q_weak,':','True q_w');

    xlabel('q candidate');
    ylabel('Normalized concentration');
    title('B3 Representative Observable Residual Curves');
    legend(labels,'Location','best');
    grid on;

    exportgraphics(fig, ...
        fullfile(out_dir,'fig09_representative_curves.png'), ...
        'Resolution',180);
    close(fig);
end

end

%% ========================================================================
function [fpr,tpr,thr] = roc_curve_manual(y,score)
y = logical(y(:));
score = score(:);

valid = isfinite(score);
y = y(valid);
score = score(valid);

u = unique(score,'sorted');
thr = [Inf;flipud(u);-Inf];

P = sum(y);
N = sum(~y);

fpr = nan(numel(thr),1);
tpr = nan(numel(thr),1);

for i = 1:numel(thr)
    pred = score>=thr(i);

    TP = sum(pred & y);
    FP = sum(pred & ~y);

    if P>0
        tpr(i) = TP/P;
    end

    if N>0
        fpr(i) = FP/N;
    end
end
end

%% ========================================================================
function y = normalize01(x)
x = x(:);

xmin = min(x);
xmax = max(x);

if xmax<=xmin
    y = zeros(size(x));
else
    y = (x-xmin)/(xmax-xmin);
end
end
