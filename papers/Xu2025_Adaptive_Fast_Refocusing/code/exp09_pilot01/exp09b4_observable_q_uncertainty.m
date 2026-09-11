function results = exp09b4_observable_q_uncertainty()
%EXP09B4_OBSERVABLE_Q_UNCERTAINTY
% EXP009 / Pilot-01 / Experiment B4
%
% Observable q-Uncertainty / Stability Estimation
%
% -------------------------------------------------------------------------
% Motivation
% -------------------------------------------------------------------------
% B3 showed:
%
%   - catastrophic failure is highly observable from prominence / entropy;
%   - perturbative failure remains much harder to predict from one static
%     residual concentration curve.
%
% B4 therefore tests a different information source:
%
%   "Does the estimated q remain stable when the DATA support is perturbed?"
%
% The key practical idea is that a fragile residual weak-q peak may still
% look plausible in the full aperture, but its estimate should fluctuate
% more across overlapping sub-apertures.
%
% -------------------------------------------------------------------------
% Observable local-uncertainty features
% -------------------------------------------------------------------------
% Four 75%-length overlapping contiguous sub-apertures are used by default.
%
% From their sub-grid q estimates:
%
%   subap_std_norm
%   subap_range_norm
%   subap_mad_norm
%   subap_full_dev_norm
%   subap_consensus_fraction
%
% All q-dispersion features are normalized by tau_q.
%
% B4 also tests a physics-guided curvature/noise proxy:
%
%   sigma_q_proxy
%       ~= sigma_{M'} / |M''(q_hat)|
%
% where sigma_{M'} is estimated from the robust fluctuation scale of the
% concentration curve.
%
% -------------------------------------------------------------------------
% Labels
% -------------------------------------------------------------------------
% As in B3, ground-truth labels use true q only for evaluation.
%
% residual-induced failure:
%   baseline succeeds AND residual fails
%
% perturbative failure:
%   residual-induced failure AND not catastrophic
%
% catastrophic failure:
%   baseline succeeds AND residual error >= catastrophic threshold
%
% For perturbative AUC, catastrophic trials are excluded from the negative
% class. This cleanly asks:
%
%   Can observable uncertainty separate non-catastrophic success from
%   non-catastrophic residual-induced failure?
%
% -------------------------------------------------------------------------
% Diagnostic fusion
% -------------------------------------------------------------------------
% Two leave-one-cell-out logistic diagnostics are included:
%
%   Local-only:
%       sub-aperture + curvature uncertainty
%
%   Two-channel:
%       local uncertainty + prominence + entropy
%
% These are diagnostics only, not the final method.
%
% Run:
%   results = exp09b4_observable_q_uncertainty;

cfg = config_exp09b4();

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

if isempty(cfg.b3_result_dir)
    b3_dir = fullfile(paper_root,'results','exp09_pilot01', ...
        'exp09b3_observable_reliability');
else
    b3_dir = cfg.b3_result_dir;
end

if isempty(cfg.output_dir)
    out_dir = fullfile(paper_root,'results','exp09_pilot01', ...
        'exp09b4_observable_q_uncertainty');
else
    out_dir = cfg.output_dir;
end

if ~exist(out_dir,'dir')
    mkdir(out_dir);
end

selected_file = fullfile(b2_dir,'selected_cells.csv');
refined_file = fullfile(b2_dir,'refined_cell_summary.csv');

if ~exist(selected_file,'file')
    error('B2 selected_cells.csv not found: %s',selected_file);
end

if ~exist(refined_file,'file')
    error('B2 refined_cell_summary.csv not found: %s',refined_file);
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

if height(selected) ~= height(refined_b2) || ...
        any(selected.cell_id ~= refined_b2.cell_id)
    error('B2 selected/refined tables do not align.');
end

fprintf('\n============================================================\n');
fprintf(' EXP009-B4 / Observable q-Uncertainty\n');
fprintf('============================================================\n');
fprintf('B2 input: %s\n',b2_dir);
fprintf('B3 input: %s\n',b3_dir);
fprintf('Output:   %s\n',out_dir);
fprintf('Selected cells: %d\n',height(selected));
fprintf('MC trials/cell: %d\n\n',cfg.num_mc);

%% Optional B3 reference
b3_best_pert_auc = NaN;
b3_best_pert_feature = "";

b3_auc_file = fullfile(b3_dir,'feature_auc_ranking.csv');

if exist(b3_auc_file,'file')
    b3_auc = readtable(b3_auc_file);

    if ismember('auc_perturbative_failure',b3_auc.Properties.VariableNames)
        [b3_best_pert_auc,ii] = ...
            max(b3_auc.auc_perturbative_failure);

        if ismember('feature',b3_auc.Properties.VariableNames)
            b3_best_pert_feature = string(b3_auc.feature(ii));
        end
    end
end

%% Common signal / search setup
rng(cfg.seed,'twister');

N = cfg.N;
n = 0:N-1;
t = (n-N/2)/N;

q_search = cfg.q_search_min:cfg.q_search_step:cfg.q_search_max;
D_full = build_dechirp_dictionary(q_search,t,cfg);

K = height(selected);
M = cfg.num_mc;

%% Sub-aperture geometry
sub_len = round(cfg.subap_fraction*N);
sub_len = min(max(sub_len,3),N);

max_start = N-sub_len+1;

if cfg.num_subaps == 1
    sub_starts = 1;
else
    sub_starts = round(linspace(1,max_start,cfg.num_subaps));
end

% Ensure unique ordered starts.
sub_starts = unique(sub_starts,'stable');
nSub = numel(sub_starts);

sub_indices = cell(nSub,1);
D_sub = cell(nSub,1);

for js = 1:nSub
    idx = sub_starts(js):(sub_starts(js)+sub_len-1);

    sub_indices{js} = idx;
    D_sub{js} = build_dechirp_dictionary( ...
        q_search,t(idx),cfg);
end

fprintf('Sub-aperture length: %d / %d samples (%.1f%%)\n', ...
    sub_len,N,100*sub_len/N);
fprintf('Sub-aperture starts: [%s]\n\n',num2str(sub_starts));

%% Match B2/B3 strong-referenced SNR convention
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
    'subap_std_norm', ...
    'subap_range_norm', ...
    'subap_mad_norm', ...
    'subap_full_dev_norm', ...
    'subap_consensus_fraction', ...
    'curvature_sigma_q_norm', ...
    'prominence', ...
    'curve_entropy', ...
    'second_to_first', ...
    'peak_zscore'};

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
residual_q_subgrid = nan(nRows,1);

baseline_success = false(nRows,1);
residual_success = false(nRows,1);

residual_signed_bias = nan(nRows,1);
residual_abs_error = nan(nRows,1);

induced_failure = false(nRows,1);
perturbative_failure = false(nRows,1);
catastrophic_failure = false(nRows,1);
residual_catastrophic_any = false(nRows,1);

X = nan(nRows,F);

% Store sub-aperture q estimates for later inspection.
Qsub = nan(nRows,nSub);

%% Representative examples
examples = struct();
examples.perturb_success_found = false;
examples.perturb_failure_found = false;
examples.cat_failure_found = false;

row = 0;

%% Main simulation
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

        xb = s_w + noise;
        xr = s_w + e_s + noise;

        [qhb,~,~] = ...
            search_q_concentration(xb,q_search,D_full);

        [qhr,metric_r,idx_r] = ...
            search_q_concentration(xr,q_search,D_full);

        qhr_subgrid = parabolic_peak_q( ...
            metric_r,q_search,idx_r);

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

        % -------------------------------------------------------------
        % Data-perturbation stability: overlapping sub-apertures
        q_sub = nan(nSub,1);

        for js = 1:nSub
            idx = sub_indices{js};

            [~,metric_s,idx_s] = ...
                search_q_concentration( ...
                xr(idx),q_search,D_sub{js});

            q_sub(js) = parabolic_peak_q( ...
                metric_s,q_search,idx_s);
        end

        sub_std = std(q_sub,0);
        sub_range = max(q_sub)-min(q_sub);
        sub_mad = median(abs(q_sub-median(q_sub)));
        sub_full_dev = median(abs(q_sub-qhr_subgrid));

        sub_consensus = mean( ...
            abs(q_sub-qhr_subgrid) <= cfg.tau_q);

        % -------------------------------------------------------------
        % Physics-guided curvature/noise uncertainty proxy
        sigma_q_proxy = curvature_uncertainty_proxy( ...
            metric_r,idx_r,q_search,cfg);

        % -------------------------------------------------------------
        % B3 ambiguity references
        b3feat = extract_static_features( ...
            metric_r,idx_r,cfg);

        feat_vec = [ ...
            sub_std/cfg.tau_q, ...
            sub_range/cfg.tau_q, ...
            sub_mad/cfg.tau_q, ...
            sub_full_dev/cfg.tau_q, ...
            sub_consensus, ...
            sigma_q_proxy/cfg.tau_q, ...
            b3feat.prominence, ...
            b3feat.curve_entropy, ...
            b3feat.second_to_first, ...
            b3feat.peak_zscore];

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
        residual_q_subgrid(row) = qhr_subgrid;

        baseline_success(row) = sb;
        residual_success(row) = sr;

        residual_signed_bias(row) = br;
        residual_abs_error(row) = er;

        induced_failure(row) = induced;
        perturbative_failure(row) = pert;
        catastrophic_failure(row) = cat;
        residual_catastrophic_any(row) = cat_any;

        X(row,:) = feat_vec;
        Qsub(row,:) = q_sub(:).';

        % Representative perturbative-cell success/failure pair.
        if regime_name=="Perturbative" && sb && sr && ...
                ~examples.perturb_success_found
            examples.perturb_success_found = true;
            examples.perturb_success.metric = metric_r;
            examples.perturb_success.q = q_search;
            examples.perturb_success.q_sub = q_sub;
            examples.perturb_success.q_full = qhr_subgrid;
            examples.perturb_success.cell_id = selected.cell_id(ik);
        end

        if pert && ~examples.perturb_failure_found
            examples.perturb_failure_found = true;
            examples.perturb_failure.metric = metric_r;
            examples.perturb_failure.q = q_search;
            examples.perturb_failure.q_sub = q_sub;
            examples.perturb_failure.q_full = qhr_subgrid;
            examples.perturb_failure.cell_id = selected.cell_id(ik);
        end

        if cat && ~examples.cat_failure_found
            examples.cat_failure_found = true;
            examples.cat_failure.metric = metric_r;
            examples.cat_failure.q = q_search;
            examples.cat_failure.q_sub = q_sub;
            examples.cat_failure.q_full = qhr_subgrid;
            examples.cat_failure.cell_id = selected.cell_id(ik);
        end
    end
end

%% Assemble trial table
trial_table = table( ...
    cell_id,trial_id,selection_regime,weak_ratio,signed_sep,snr_db, ...
    Gamma,Lambda,baseline_q_hat,residual_q_hat,residual_q_subgrid, ...
    baseline_success,residual_success,residual_signed_bias, ...
    residual_abs_error,induced_failure,perturbative_failure, ...
    catastrophic_failure,residual_catastrophic_any);

for jf = 1:F
    trial_table.(feature_names{jf}) = X(:,jf);
end

for js = 1:nSub
    trial_table.(sprintf('subap_q_%d',js)) = Qsub(:,js);
end

writetable(trial_table, ...
    fullfile(out_dir,'b4_trial_uncertainty_features.csv'));

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

    rep_base_diff(ik) = ...
        rep_base(ik)-refined_b2.baseline_recovery_rate(ik);

    rep_res_diff(ik) = ...
        rep_res(ik)-refined_b2.residual_recovery_rate(ik);

    rep_penalty_diff(ik) = ...
        rep_penalty(ik)-refined_b2.paired_recovery_penalty(ik);

    rep_cat_diff(ik) = ...
        rep_cat(ik)-refined_b2.residual_catastrophic_rate(ik);
end

reproduction_check = table( ...
    rep_cell, ...
    rep_base,refined_b2.baseline_recovery_rate,rep_base_diff, ...
    rep_res,refined_b2.residual_recovery_rate,rep_res_diff, ...
    rep_penalty,refined_b2.paired_recovery_penalty,rep_penalty_diff, ...
    rep_cat,refined_b2.residual_catastrophic_rate,rep_cat_diff, ...
    'VariableNames',{ ...
    'cell_id', ...
    'b4_baseline_recall','b2_baseline_recall','baseline_diff', ...
    'b4_residual_recall','b2_residual_recall','residual_diff', ...
    'b4_penalty','b2_penalty','penalty_diff', ...
    'b4_catastrophic_rate','b2_catastrophic_rate','catastrophic_diff'});

writetable(reproduction_check, ...
    fullfile(out_dir,'b2_reproduction_check.csv'));

max_reproduction_diff = max(abs([ ...
    rep_base_diff;rep_res_diff;rep_penalty_diff;rep_cat_diff]));

%% ------------------------------------------------------------------------
% Feature AUC audit
%
% Any induced failure:
mask_any = trial_table.baseline_success;
y_any = trial_table.induced_failure(mask_any);

% Perturbative evaluation:
% exclude catastrophic trials completely from the comparison.
mask_pert = trial_table.baseline_success & ...
    ~trial_table.catastrophic_failure;

y_pert = trial_table.perturbative_failure(mask_pert);

% Catastrophic evaluation:
mask_cat = trial_table.baseline_success;
y_cat = trial_table.catastrophic_failure(mask_cat);

feature_col = strings(F,1);

auc_any = nan(F,1);
dir_any = strings(F,1);

auc_pert = nan(F,1);
dir_pert = strings(F,1);

auc_cat = nan(F,1);
dir_cat = strings(F,1);

for jf = 1:F
    feature_col(jf) = feature_names{jf};

    [auc_any(jf),dir_any(jf)] = ...
        oriented_auc(y_any,X(mask_any,jf));

    [auc_pert(jf),dir_pert(jf)] = ...
        oriented_auc(y_pert,X(mask_pert,jf));

    [auc_cat(jf),dir_cat(jf)] = ...
        oriented_auc(y_cat,X(mask_cat,jf));
end

feature_auc_table = table( ...
    feature_col,auc_any,dir_any,auc_pert,dir_pert,auc_cat,dir_cat, ...
    'VariableNames',{ ...
    'feature', ...
    'auc_induced_failure','risk_direction_induced', ...
    'auc_perturbative_failure','risk_direction_perturbative', ...
    'auc_catastrophic_failure','risk_direction_catastrophic'});

feature_auc_table = sortrows( ...
    feature_auc_table,'auc_perturbative_failure','descend');

writetable(feature_auc_table, ...
    fullfile(out_dir,'feature_auc_ranking.csv'));

%% ------------------------------------------------------------------------
% Cell-level means and correlations
cell_mean = nan(K,F);

for ik = 1:K
    mm = trial_table.cell_id == selected.cell_id(ik) & ...
        trial_table.baseline_success;

    if any(mm)
        cell_mean(ik,:) = mean(X(mm,:),1,'omitnan');
    end
end

cell_feature_table = table( ...
    selected.cell_id,selected.Gamma,selected.Lambda, ...
    refined_b2.paired_recovery_penalty, ...
    refined_b2.residual_catastrophic_rate, ...
    'VariableNames',{ ...
    'cell_id','Gamma','Lambda','refined_penalty', ...
    'refined_catastrophic_rate'});

for jf = 1:F
    cell_feature_table.(['mean_' feature_names{jf}]) = ...
        cell_mean(:,jf);
end

writetable(cell_feature_table, ...
    fullfile(out_dir,'cell_mean_uncertainty_features.csv'));

corr_feature = strings(F,1);
rho_gamma = nan(F,1);
rho_penalty = nan(F,1);
rho_cat = nan(F,1);

for jf = 1:F
    corr_feature(jf) = feature_names{jf};

    rho_gamma(jf) = spearman_manual( ...
        cell_mean(:,jf),selected.Gamma);

    rho_penalty(jf) = spearman_manual( ...
        cell_mean(:,jf),refined_b2.paired_recovery_penalty);

    rho_cat(jf) = spearman_manual( ...
        cell_mean(:,jf),refined_b2.residual_catastrophic_rate);
end

cell_correlation_table = table( ...
    corr_feature,rho_gamma,rho_penalty,rho_cat, ...
    'VariableNames',{ ...
    'feature','spearman_with_Gamma', ...
    'spearman_with_refined_penalty', ...
    'spearman_with_catastrophic_rate'});

cell_correlation_table = sortrows( ...
    cell_correlation_table, ...
    'spearman_with_refined_penalty','descend');

writetable(cell_correlation_table, ...
    fullfile(out_dir,'cell_feature_correlations.csv'));

%% ------------------------------------------------------------------------
% Leave-one-cell-out diagnostic fusion
%
% Model A: local q uncertainty only.
local_idx = feature_indices( ...
    feature_names,cfg.local_logit_features);

% Model B: local uncertainty + B3 global ambiguity.
two_idx = feature_indices( ...
    feature_names,cfg.twochannel_logit_features);

groups_pert = trial_table.cell_id(mask_pert);

[p_local_pert,valid_local_pert] = ...
    loco_logistic_predictions( ...
    X(mask_pert,local_idx), ...
    y_pert,groups_pert,cfg.logit_l2);

[p_two_pert,valid_two_pert] = ...
    loco_logistic_predictions( ...
    X(mask_pert,two_idx), ...
    y_pert,groups_pert,cfg.logit_l2);

auc_local_pert = binary_auc( ...
    y_pert(valid_local_pert), ...
    p_local_pert(valid_local_pert));

auc_two_pert = binary_auc( ...
    y_pert(valid_two_pert), ...
    p_two_pert(valid_two_pert));

% Any residual-induced failure, same two-channel feature set.
groups_any = trial_table.cell_id(mask_any);

[p_two_any,valid_two_any] = ...
    loco_logistic_predictions( ...
    X(mask_any,two_idx), ...
    y_any,groups_any,cfg.logit_l2);

auc_two_any = binary_auc( ...
    y_any(valid_two_any), ...
    p_two_any(valid_two_any));

% Catastrophic diagnostic using the same two-channel set.
groups_cat = trial_table.cell_id(mask_cat);

[p_two_cat,valid_two_cat] = ...
    loco_logistic_predictions( ...
    X(mask_cat,two_idx), ...
    y_cat,groups_cat,cfg.logit_l2);

auc_two_cat = binary_auc( ...
    y_cat(valid_two_cat), ...
    p_two_cat(valid_two_cat));

%% Save OOF scores
pert_oof_table = table( ...
    trial_table.cell_id(mask_pert), ...
    trial_table.trial_id(mask_pert), ...
    y_pert,p_local_pert,valid_local_pert,p_two_pert,valid_two_pert, ...
    'VariableNames',{ ...
    'cell_id','trial_id','perturbative_failure', ...
    'local_oof_score','local_valid', ...
    'twochannel_oof_score','twochannel_valid'});

writetable(pert_oof_table, ...
    fullfile(out_dir,'loco_perturbative_scores.csv'));

%% ------------------------------------------------------------------------
% Cell-level OOF perturbative risk
cell_oof_local = nan(K,1);
cell_oof_two = nan(K,1);
cell_pert_rate = nan(K,1);

for ik = 1:K
    cid = selected.cell_id(ik);

    mm = pert_oof_table.cell_id == cid;

    if any(mm & pert_oof_table.local_valid)
        cell_oof_local(ik) = mean( ...
            pert_oof_table.local_oof_score( ...
            mm & pert_oof_table.local_valid));
    end

    if any(mm & pert_oof_table.twochannel_valid)
        cell_oof_two(ik) = mean( ...
            pert_oof_table.twochannel_oof_score( ...
            mm & pert_oof_table.twochannel_valid));
    end

    if any(mm)
        cell_pert_rate(ik) = mean( ...
            pert_oof_table.perturbative_failure(mm));
    end
end

loco_cell_summary = table( ...
    selected.cell_id,cell_oof_local,cell_oof_two,cell_pert_rate, ...
    selected.Gamma,refined_b2.paired_recovery_penalty, ...
    'VariableNames',{ ...
    'cell_id','mean_local_risk','mean_twochannel_risk', ...
    'empirical_perturbative_failure_rate','Gamma', ...
    'refined_penalty'});

writetable(loco_cell_summary, ...
    fullfile(out_dir,'loco_cell_summary.csv'));

rho_local_cell_penalty = spearman_manual( ...
    cell_oof_local,refined_b2.paired_recovery_penalty);

rho_two_cell_penalty = spearman_manual( ...
    cell_oof_two,refined_b2.paired_recovery_penalty);

%% ------------------------------------------------------------------------
% Summary tables
best_pert_auc = feature_auc_table.auc_perturbative_failure(1);
best_pert_feature = feature_auc_table.feature(1);

diagnostic_summary = table( ...
    b3_best_pert_auc,best_pert_auc, ...
    auc_local_pert,auc_two_pert,auc_two_any,auc_two_cat, ...
    rho_local_cell_penalty,rho_two_cell_penalty, ...
    max_reproduction_diff, ...
    'VariableNames',{ ...
    'b3_best_perturbative_auc', ...
    'b4_best_single_perturbative_auc', ...
    'b4_local_loco_perturbative_auc', ...
    'b4_twochannel_loco_perturbative_auc', ...
    'b4_twochannel_loco_any_auc', ...
    'b4_twochannel_loco_catastrophic_auc', ...
    'local_cell_risk_penalty_spearman', ...
    'twochannel_cell_risk_penalty_spearman', ...
    'max_b2_reproduction_diff'});

writetable(diagnostic_summary, ...
    fullfile(out_dir,'diagnostic_summary.csv'));

%% Console
fprintf('================ B4 REPRODUCTION ====================\n');
fprintf('Max absolute B2 reproduction diff = %.6g\n', ...
    max_reproduction_diff);

fprintf('\n================ B4 LABEL COUNTS ====================\n');
fprintf('Baseline-success trials       = %d\n',sum(mask_any));
fprintf('Residual-induced failures     = %d\n',sum(y_any));
fprintf('Perturbative evaluation trials= %d\n',sum(mask_pert));
fprintf('Perturbative failures         = %d\n',sum(y_pert));
fprintf('Catastrophic failures         = %d\n',sum(y_cat));

fprintf('\n================ B4 FEATURE AUDIT ===================\n');

topN = min(6,height(feature_auc_table));

for i = 1:topN
    fprintf('#%d %-26s AUC(pert)=%.3f AUC(any)=%.3f AUC(cat)=%.3f\n', ...
        i,feature_auc_table.feature(i), ...
        feature_auc_table.auc_perturbative_failure(i), ...
        feature_auc_table.auc_induced_failure(i), ...
        feature_auc_table.auc_catastrophic_failure(i));
end

if isfinite(b3_best_pert_auc)
    fprintf('\nB3 best perturbative AUC      = %.3f (%s)\n', ...
        b3_best_pert_auc,b3_best_pert_feature);
end

fprintf('B4 best single perturbative AUC= %.3f (%s)\n', ...
    best_pert_auc,best_pert_feature);

fprintf('B4 local-only LOCO AUC         = %.3f\n', ...
    auc_local_pert);

fprintf('B4 two-channel LOCO pert AUC   = %.3f\n', ...
    auc_two_pert);

fprintf('B4 two-channel LOCO any AUC    = %.3f\n', ...
    auc_two_any);

fprintf('B4 two-channel LOCO cat AUC    = %.3f\n', ...
    auc_two_cat);

fprintf('=====================================================\n');

%% Text summary
fid = fopen(fullfile(out_dir,'summary.txt'),'w');

fprintf(fid,'EXP009-B4 Observable q-Uncertainty\n');
fprintf(fid,'=================================\n\n');

fprintf(fid,'Selected B2 cells: %d\n',K);
fprintf(fid,'MC trials/cell: %d\n',M);
fprintf(fid,'Sub-apertures: %d x %d samples\n',nSub,sub_len);
fprintf(fid,'Sub-aperture starts: %s\n',num2str(sub_starts));
fprintf(fid,'Max B2 reproduction diff: %.8g\n\n', ...
    max_reproduction_diff);

fprintf(fid,'Label counts\n');
fprintf(fid,'------------\n');
fprintf(fid,'Baseline-success trials: %d\n',sum(mask_any));
fprintf(fid,'Residual-induced failures: %d\n',sum(y_any));
fprintf(fid,'Perturbative evaluation trials: %d\n',sum(mask_pert));
fprintf(fid,'Perturbative failures: %d\n',sum(y_pert));
fprintf(fid,'Catastrophic failures: %d\n\n',sum(y_cat));

fprintf(fid,'Feature AUC ranking by perturbative failure\n');
fprintf(fid,'------------------------------------------\n');

for i = 1:height(feature_auc_table)
    fprintf(fid, ...
        '%s: AUC_pert=%.6f dir=%s, AUC_any=%.6f, AUC_cat=%.6f\n', ...
        feature_auc_table.feature(i), ...
        feature_auc_table.auc_perturbative_failure(i), ...
        feature_auc_table.risk_direction_perturbative(i), ...
        feature_auc_table.auc_induced_failure(i), ...
        feature_auc_table.auc_catastrophic_failure(i));
end

fprintf(fid,'\nB3 comparison\n');
fprintf(fid,'-------------\n');

if isfinite(b3_best_pert_auc)
    fprintf(fid,'B3 best perturbative AUC: %.6f (%s)\n', ...
        b3_best_pert_auc,b3_best_pert_feature);
else
    fprintf(fid,'B3 best perturbative AUC: unavailable\n');
end

fprintf(fid,'B4 best single perturbative AUC: %.6f (%s)\n\n', ...
    best_pert_auc,best_pert_feature);

fprintf(fid,'LOCO diagnostic fusion\n');
fprintf(fid,'----------------------\n');
fprintf(fid,'Local-only perturbative AUC: %.6f\n',auc_local_pert);
fprintf(fid,'Two-channel perturbative AUC: %.6f\n',auc_two_pert);
fprintf(fid,'Two-channel any-failure AUC: %.6f\n',auc_two_any);
fprintf(fid,'Two-channel catastrophic AUC: %.6f\n',auc_two_cat);
fprintf(fid,'Local cell-risk vs penalty Spearman: %.6f\n', ...
    rho_local_cell_penalty);
fprintf(fid,'Two-channel cell-risk vs penalty Spearman: %.6f\n', ...
    rho_two_cell_penalty);

fclose(fid);

%% Figures
make_figures( ...
    out_dir,cfg,feature_auc_table,trial_table, ...
    cell_correlation_table,cell_feature_table, ...
    pert_oof_table,loco_cell_summary, ...
    auc_local_pert,auc_two_pert,b3_best_pert_auc,examples);

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

results.pert_oof_table = pert_oof_table;
results.loco_cell_summary = loco_cell_summary;

results.diagnostic_summary = diagnostic_summary;
results.examples = examples;

save(fullfile(out_dir,'exp09b4_results.mat'),'results','-v7.3');

fprintf('\nSaved EXP009-B4 outputs to:\n%s\n\n',out_dir);

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
function qsub = parabolic_peak_q(metric,q_grid,idx)
m = metric(:);
q = q_grid(:);

if idx<=1 || idx>=numel(m)
    qsub = q(idx);
    return;
end

y1 = m(idx-1);
y2 = m(idx);
y3 = m(idx+1);

den = y1 - 2*y2 + y3;

if abs(den) < eps
    delta = 0;
else
    delta = 0.5*(y1-y3)/den;
end

delta = min(max(delta,-1),1);

dq = q(idx+1)-q(idx);

qsub = q(idx)+delta*dq;
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
function sigma_q = curvature_uncertainty_proxy(metric,idx_peak,q_grid,cfg)
% First-order peak-location uncertainty proxy:
%
%   delta q ~= - epsilon'(q_hat) / M''(q_hat)
%
% Estimate:
%   sigma_{epsilon'} ~= sigma_M / (sqrt(2)*dq)
%
% where sigma_M is a robust MAD-based fluctuation scale estimated away
% from the primary peak.

m = metric(:);
q = q_grid(:);

L = numel(m);

if L<3 || idx_peak<=1 || idx_peak>=L
    sigma_q = Inf;
    return;
end

dq = abs(q(2)-q(1));

guard = cfg.noise_floor_guard_bins;

keep = true(L,1);

i1 = max(1,idx_peak-guard);
i2 = min(L,idx_peak+guard);

keep(i1:i2) = false;

floor_vals = m(keep);

if numel(floor_vals)<5
    floor_vals = m;
end

med = median(floor_vals);

sigma_M = 1.4826*median(abs(floor_vals-med));

Mpp = (m(idx_peak+1)-2*m(idx_peak)+m(idx_peak-1))/(dq^2);

curv = abs(Mpp);

sigma_slope = sigma_M/max(sqrt(2)*dq,eps);

sigma_q = sigma_slope/max(curv,eps);

% Prevent a single almost-flat numerical peak from creating Inf/NaN
% downstream. Large values remain large and therefore risky.
if ~isfinite(sigma_q)
    sigma_q = 1e6*dq;
end
end

%% ========================================================================
function feat = extract_static_features(metric,idx_peak,cfg)
m = metric(:);

L = numel(m);
peak = m(idx_peak);

floor_med = median(m);
floor_mad = median(abs(m-floor_med));

keep = true(L,1);

i1 = max(1,idx_peak-cfg.second_peak_guard_bins);
i2 = min(L,idx_peak+cfg.second_peak_guard_bins);

keep(i1:i2) = false;

if any(keep)
    tmp = m;
    tmp(~keep) = -Inf;
    second_peak = max(tmp);
else
    second_peak = 0;
end

feat.second_to_first = ...
    second_peak/max(peak,eps);

feat.prominence = ...
    (peak-floor_med)/max(peak,eps);

feat.peak_zscore = ...
    (peak-floor_med)/max(floor_mad,eps);

pp = m/max(sum(m),eps);
pp = pp(pp>0);

if L>1
    feat.curve_entropy = ...
        -sum(pp.*log(pp))/log(L);
else
    feat.curve_entropy = 0;
end
end

%% ========================================================================
function [auc_best,direction] = oriented_auc(y,score)
auc_plus = binary_auc(y,score);
auc_minus = binary_auc(y,-score);

if isnan(auc_plus) && isnan(auc_minus)
    auc_best = NaN;
    direction = "NA";
elseif isnan(auc_minus) || auc_plus>=auc_minus
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
function idx = feature_indices(feature_names,requested)
idx = zeros(numel(requested),1);

for i = 1:numel(requested)
    j = find(strcmp(feature_names,requested{i}),1);

    if isempty(j)
        error('Configured feature "%s" not found.',requested{i});
    end

    idx(i) = j;
end
end

%% ========================================================================
function [p_oof,valid_oof] = loco_logistic_predictions(X,y,groups,l2)
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

    if numel(unique(ytr))<2
        continue;
    end

    mu = mean(Xtr,1,'omitnan');
    sd = std(Xtr,0,1,'omitnan');

    mu(~isfinite(mu)) = 0;
    sd(~isfinite(sd) | sd<1e-12) = 1;

    Xtr = fill_nonfinite_with_training_mean(Xtr,mu);
    Xte = fill_nonfinite_with_training_mean(X(test,:),mu);

    Ztr = bsxfun(@rdivide,bsxfun(@minus,Xtr,mu),sd);
    Zte = bsxfun(@rdivide,bsxfun(@minus,Xte,mu),sd);

    Xtr1 = [ones(size(Ztr,1),1),Ztr];
    Xte1 = [ones(size(Zte,1),1),Zte];

    beta0 = zeros(size(Xtr1,2),1);

    objective = @(b) logistic_objective( ...
        b,Xtr1,ytr,l2);

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

loss = loss + l2*sum(beta(2:end).^2);
end

%% ========================================================================
function rho = spearman_manual(x,y)
x = x(:);
y = y(:);

valid = isfinite(x) & isfinite(y);

x = x(valid);
y = y(valid);

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

while i<=numel(xs)
    j = i;

    while j<numel(xs) && xs(j+1)==xs(i)
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
if snr_db>=0
    fld = sprintf('snr_p_%g',snr_db);
else
    fld = sprintf('snr_m_%g',abs(snr_db));
end

fld = strrep(fld,'.','p');
end

%% ========================================================================
function make_figures( ...
    out_dir,cfg,auc_tbl,trials,corr_tbl,cell_tbl, ...
    pert_oof,cell_oof,auc_local,auc_two,b3_best_auc,examples)

%% Fig 1: AUC ranking
topN = min(10,height(auc_tbl));
T = auc_tbl(1:topN,:);

fig = figure('Visible',cfg.figure_visible);

Y = [ ...
    T.auc_perturbative_failure, ...
    T.auc_induced_failure, ...
    T.auc_catastrophic_failure];

bar(Y);

ylim([0.45 1]);

xticks(1:topN);
xticklabels(T.feature);
xtickangle(35);

ylabel('Oriented AUC');
title('B4 Observable q-Uncertainty Feature Audit');

legend('Perturbative','Any induced','Catastrophic', ...
    'Location','best');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig01_uncertainty_feature_auc.png'), ...
    'Resolution',180);

close(fig);

%% Fig 2: best perturbative feature distribution
best_feature = char(T.feature(1));

mask = trials.baseline_success & ...
    ~trials.catastrophic_failure;

group = double(trials.perturbative_failure(mask))+1;

fig = figure('Visible',cfg.figure_visible);

boxchart(group,trials.(best_feature)(mask));

xticks([1 2]);
xticklabels({'Non-catastrophic success','Perturbative failure'});

ylabel(best_feature,'Interpreter','none');

title(sprintf('B4 Best Perturbative Feature: %s',best_feature), ...
    'Interpreter','none');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig02_best_perturbative_feature.png'), ...
    'Resolution',180);

close(fig);

%% Fig 3: Sub-aperture uncertainty plane
fig = figure('Visible',cfg.figure_visible);

m = trials.baseline_success & ...
    ~trials.catastrophic_failure;

classes = double(trials.perturbative_failure(m));

scatter( ...
    trials.subap_std_norm(m), ...
    trials.curvature_sigma_q_norm(m), ...
    24,classes,'filled');

xlabel('Sub-aperture q std / \tau_q');
ylabel('Curvature-noise \sigma_q proxy / \tau_q');

title('B4 Perturbative Uncertainty Plane');

cb = colorbar;
cb.Ticks = [0 1];
cb.TickLabels = {'Success','Perturbative failure'};

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig03_perturbative_uncertainty_plane.png'), ...
    'Resolution',180);

close(fig);

%% Fig 4: Cell-level correlations
rhoP = corr_tbl.spearman_with_refined_penalty;

[~,ord] = sort(abs(rhoP),'descend');

topN2 = min(10,numel(ord));
ord = ord(1:topN2);

fig = figure('Visible',cfg.figure_visible);

Y = [ ...
    corr_tbl.spearman_with_Gamma(ord), ...
    corr_tbl.spearman_with_refined_penalty(ord), ...
    corr_tbl.spearman_with_catastrophic_rate(ord)];

bar(Y);

ylim([-1 1]);

xticks(1:topN2);
xticklabels(corr_tbl.feature(ord));
xtickangle(35);

ylabel('Spearman correlation');

title('B4 Cell-Level Uncertainty Correlations');

legend('\Gamma','Refined penalty','Catastrophic rate', ...
    'Location','best');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig04_cell_uncertainty_correlations.png'), ...
    'Resolution',180);

close(fig);

%% Fig 5: Best cell observable vs penalty
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

title(sprintf('B4 Cell Observable vs Penalty: %s',feat_name), ...
    'Interpreter','none');

cb = colorbar;
cb.Label.String = '\Gamma';

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig05_best_cell_uncertainty_vs_penalty.png'), ...
    'Resolution',180);

close(fig);

%% Fig 6: LOCO perturbative ROC
validL = pert_oof.local_valid;
validT = pert_oof.twochannel_valid;

[fprL,tprL,~] = roc_curve_manual( ...
    pert_oof.perturbative_failure(validL), ...
    pert_oof.local_oof_score(validL));

[fprT,tprT,~] = roc_curve_manual( ...
    pert_oof.perturbative_failure(validT), ...
    pert_oof.twochannel_oof_score(validT));

fig = figure('Visible',cfg.figure_visible);

plot(fprL,tprL,'LineWidth',1.4);
hold on;

plot(fprT,tprT,'LineWidth',1.4);
plot([0 1],[0 1],'--');

xlabel('False positive rate');
ylabel('True positive rate');

if isfinite(b3_best_auc)
    title(sprintf(['B4 LOCO Perturbative ROC: local %.3f, ' ...
        'two-channel %.3f, B3 best single %.3f'], ...
        auc_local,auc_two,b3_best_auc));
else
    title(sprintf(['B4 LOCO Perturbative ROC: local %.3f, ' ...
        'two-channel %.3f'],auc_local,auc_two));
end

legend('Local uncertainty','Two-channel','Chance', ...
    'Location','southeast');

grid on;
axis square;

exportgraphics(fig, ...
    fullfile(out_dir,'fig06_loco_perturbative_roc.png'), ...
    'Resolution',180);

close(fig);

%% Fig 7: Cell-level OOF risk
fig = figure('Visible',cfg.figure_visible);

scatter( ...
    cell_oof.mean_twochannel_risk, ...
    cell_oof.empirical_perturbative_failure_rate, ...
    75,cell_oof.Gamma,'filled');

xlabel('Mean two-channel LOCO risk');
ylabel('Empirical perturbative failure probability');

title('B4 Practical Uncertainty Risk vs Perturbative Failure');

cb = colorbar;
cb.Label.String = '\Gamma';

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig07_loco_cell_perturbative_risk.png'), ...
    'Resolution',180);

close(fig);

%% Fig 8: Global ambiguity vs local uncertainty
m = trials.baseline_success;

classes = zeros(sum(m),1);

classes(trials.perturbative_failure(m)) = 1;
classes(trials.catastrophic_failure(m)) = 2;

fig = figure('Visible',cfg.figure_visible);

scatter( ...
    trials.subap_std_norm(m), ...
    trials.prominence(m), ...
    24,classes,'filled');

xlabel('Sub-aperture q std / \tau_q');
ylabel('Prominence');

title('B4 Two-Channel Risk Plane');

cb = colorbar;
cb.Ticks = [0 1 2];
cb.TickLabels = {'Safe','Perturbative','Catastrophic'};

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig08_twochannel_risk_plane.png'), ...
    'Resolution',180);

close(fig);

%% Fig 9: Representative sub-aperture stability
if examples.perturb_success_found || ...
        examples.perturb_failure_found || ...
        examples.cat_failure_found

    fig = figure('Visible',cfg.figure_visible);

    labels = {};

    if examples.perturb_success_found
        plot( ...
            examples.perturb_success.q, ...
            normalize01(examples.perturb_success.metric), ...
            'LineWidth',1.4);

        hold on;

        labels{end+1} = sprintf('Perturbative-cell success (#%d)', ...
            examples.perturb_success.cell_id); %#ok<AGROW>
    end

    if examples.perturb_failure_found
        plot( ...
            examples.perturb_failure.q, ...
            normalize01(examples.perturb_failure.metric), ...
            'LineWidth',1.4);

        hold on;

        labels{end+1} = sprintf('Perturbative failure (#%d)', ...
            examples.perturb_failure.cell_id); %#ok<AGROW>
    end

    if examples.cat_failure_found
        plot( ...
            examples.cat_failure.q, ...
            normalize01(examples.cat_failure.metric), ...
            'LineWidth',1.4);

        hold on;

        labels{end+1} = sprintf('Catastrophic failure (#%d)', ...
            examples.cat_failure.cell_id); %#ok<AGROW>
    end

    xline(cfg.q_weak,':','True q_w');

    % Mark sub-aperture estimates for the perturbative failure example.
    if examples.perturb_failure_found
        qsub = examples.perturb_failure.q_sub;

        for k = 1:numel(qsub)
            xline(qsub(k),'--');
        end
    end

    xlabel('q candidate');
    ylabel('Normalized concentration');

    title('B4 Representative Full-Curve + Sub-Aperture Stability');

    legend(labels,'Location','best');

    grid on;

    exportgraphics(fig, ...
        fullfile(out_dir,'fig09_representative_subap_stability.png'), ...
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
