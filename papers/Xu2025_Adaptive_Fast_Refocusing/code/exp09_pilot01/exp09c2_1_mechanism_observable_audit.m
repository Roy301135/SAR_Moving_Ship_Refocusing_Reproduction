function results = exp09c2_1_mechanism_observable_audit()
%EXP09C2_1_MECHANISM_OBSERVABLE_AUDIT
% EXP009 / Pilot-01 / Experiment C2.1
%
% Mechanism-Aware Pre-Fallback Observable Audit
%
% -------------------------------------------------------------------------
% Motivation
% -------------------------------------------------------------------------
% C2 showed:
%
%   - Benefit-aware target is conceptually correct;
%   - but weak-residual scalar observables
%       prominence / entropy / second-to-first
%     still do not outperform the simple prominence/entropy gates;
%   - therefore the current bottleneck is more likely missing INFORMATION
%     than insufficient classifier complexity.
%
% C2.1 directly tests that hypothesis.
%
% Instead of asking only:
%
%   "What does the weak residual curve look like?"
%
% C2.1 also measures:
%
%   "How clean was the preceding strong-component cancellation stage?"
%
% -------------------------------------------------------------------------
% Important experimental boundary
% -------------------------------------------------------------------------
% q_strong is still assumed available from the previous dominant-component
% stage, exactly as in C1. This preserves the controlled weak-stage
% isolation. No new claim is made yet about full sequential q_strong error
% propagation.
%
% -------------------------------------------------------------------------
% Practical pre-fallback feature groups
% -------------------------------------------------------------------------
% Weak-response group:
%   cheap_prominence
%   cheap_entropy
%   cheap_second_to_first
%
% Strong-clean group:
%   strong_frac_bin_offset_abs
%   strong_peak_concentration
%   strong_notch_capture_fraction
%   strong_side_leakage_to_notch
%   strong_local_spectral_width
%   strong_local_asymmetry
%   strong_global_removed_fraction
%
% Geometry/history group:
%   estimated_q_separation_abs
%   estimated_strong_weak_peak_ratio_db
%
% All strong-stage quantities are computed from the original mixture using
% the N-point dechirped FFT before any expensive parametric fallback.
%
% -------------------------------------------------------------------------
% Labels
% -------------------------------------------------------------------------
% Canonical Beneficial/Harmful labels are inherited from C1:
%
%   Beneficial = Cheap fail, Fallback success
%   Harmful    = Cheap success, Fallback fail
%   Neutral    = otherwise
%
% C2.1 reruns the exact C1 signal chain and aborts if the regenerated
% Cheap/Fallback outcomes do not match C1.
%
% -------------------------------------------------------------------------
% Main question
% -------------------------------------------------------------------------
% Do mechanism-aware strong-stage observables improve:
%
%   AUC(Beneficial)
%   Beneficial Capture @ fixed fallback budget
%   Weak Recovery / Cost Pareto
%
% beyond the weak-response observables used in C2?
%
% Run:
%   results = exp09c2_1_mechanism_observable_audit;

cfg = config_exp09c2_1();

%% Paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.c1_result_dir)
    c1_dir = fullfile(paper_root,'results','exp09_pilot01', ...
        'exp09c1_adaptive_budget');
else
    c1_dir = cfg.c1_result_dir;
end

if isempty(cfg.output_dir)
    out_dir = fullfile(paper_root,'results','exp09_pilot01', ...
        'exp09c2_1_mechanism_observable_audit');
else
    out_dir = cfg.output_dir;
end

if ~exist(out_dir,'dir')
    mkdir(out_dir);
end

c1_file = fullfile(c1_dir,'c1_branch_trials.csv');

if ~exist(c1_file,'file')
    error('C1 branch trial file not found: %s',c1_file);
end

C1 = readtable(c1_file);

required_c1 = { ...
    'cell_id','trial_id','weak_ratio','signed_sep','snr_db', ...
    'cheap_success','fallback_success', ...
    'cheap_q_hat','fallback_q_hat', ...
    'cheap_prominence','cheap_entropy','cheap_second_to_first'};

assert_table_vars(C1,required_c1,'c1_branch_trials.csv');

C1 = sortrows(C1,{'cell_id','trial_id'});

fprintf('\n============================================================\n');
fprintf(' EXP009-C2.1 / Mechanism-Aware Observable Audit\n');
fprintf('============================================================\n');
fprintf('C1 input: %s\n',c1_dir);
fprintf('Output:   %s\n',out_dir);
fprintf('Trials:   %d\n',height(C1));
fprintf('Cells:    %d\n\n',numel(unique(C1.cell_id)));

%% Common signal setup -- match C1
rng(cfg.seed,'twister');

N = cfg.N;
n = 0:N-1;
t = (n-N/2)/N;

q_search = cfg.q_search_min:cfg.q_search_step:cfg.q_search_max;
D_search = build_dechirp_dictionary(q_search,t,cfg);

cells = unique(C1.cell_id).';
K = numel(cells);
M = cfg.num_mc;

if height(C1) ~= K*M
    error(['C1 row count does not equal num_cells * num_mc. ' ...
        'Check cfg.num_mc or C1 input.']);
end

% Match C1 strong-referenced SNR convention.
s_ref = synth_lfm(cfg.A_strong,cfg.q_weak-0.05, ...
    cfg.f_strong,cfg.phi_strong,t,cfg);

Pstrong = mean(abs(s_ref).^2);

sel_snrs = unique(C1.snr_db).';
noise_bank = struct();

for is = 1:numel(sel_snrs)
    s = sel_snrs(is);
    noise_var = Pstrong/(10^(s/10));
    fld = snr_field(s);

    noise_bank.(fld) = sqrt(noise_var/2) * ...
        (randn(M,N)+1j*randn(M,N));
end

%% Storage
nRows = height(C1);

cell_id = zeros(nRows,1);
trial_id = zeros(nRows,1);

cheap_success_new = false(nRows,1);
fallback_success_new = false(nRows,1);

cheap_q_hat_new = nan(nRows,1);
fallback_q_hat_new = nan(nRows,1);

% Weak-response observables
cheap_prominence = nan(nRows,1);
cheap_entropy = nan(nRows,1);
cheap_second_to_first = nan(nRows,1);

% Strong-clean observables
strong_frac_bin_offset_abs = nan(nRows,1);
strong_peak_concentration = nan(nRows,1);
strong_notch_capture_fraction = nan(nRows,1);
strong_side_leakage_to_notch = nan(nRows,1);
strong_local_spectral_width = nan(nRows,1);
strong_local_asymmetry = nan(nRows,1);
strong_global_removed_fraction = nan(nRows,1);

% Practical geometry/history observables
estimated_q_separation_abs = nan(nRows,1);
estimated_strong_weak_peak_ratio_db = nan(nRows,1);

% Additional diagnostic
strong_peak_power = nan(nRows,1);
cheap_peak_power = nan(nRows,1);

row = 0;

%% Re-run C1 signal chain and collect pre-fallback mechanism observables
for ik = 1:K
    cid = cells(ik);

    rows_cell = C1(C1.cell_id==cid,:);

    if height(rows_cell) ~= M
        error('Cell %d does not contain cfg.num_mc rows.',cid);
    end

    % Cell-level parameters are constant by construction.
    rA = rows_cell.weak_ratio(1);
    sep = rows_cell.signed_sep(1);
    s = rows_cell.snr_db(1);

    q_s = cfg.q_weak + sep;

    s_w = synth_lfm(cfg.A_strong*rA,cfg.q_weak, ...
        cfg.f_weak,cfg.phi_weak,t,cfg);

    s_s = synth_lfm(cfg.A_strong,q_s, ...
        cfg.f_strong,cfg.phi_strong,t,cfg);

    % Cheap C1 strong-only fixed-notch residual.
    k_s_true = get_strong_notch_bin(s_s,q_s,t,cfg);

    e_s = apply_fixed_notch_operator( ...
        s_s,q_s,k_s_true,cfg.notch_halfwidth_bins,t,cfg);

    nb = noise_bank.(snr_field(s));

    for imc = 1:M
        noise = nb(imc,:);

        x_mix = s_s + s_w + noise;
        x_cheap = s_w + e_s + noise;

        % Cheap weak q search -- exact C1 reproduction.
        [qhc,metric_c,idx_c] = ...
            search_q_concentration( ...
            x_cheap,q_search,D_search);

        feat_c = extract_weak_features( ...
            metric_c,idx_c,cfg);

        % Practical strong-stage N-point dechirped FFT observables.
        Sfeat = extract_strong_stage_features( ...
            x_mix,q_s,t,cfg);

        % C1 fallback -- exact same off-grid parametric refit.
        [x_refit,~,~,~] = ...
            refit_and_subtract_strong( ...
            x_mix,q_s,t,cfg);

        [qhf,~,~] = ...
            search_q_concentration( ...
            x_refit,q_search,D_search);

        sc = abs(qhc-cfg.q_weak) <= ...
            (cfg.tau_q+cfg.success_tol);

        sf = abs(qhf-cfg.q_weak) <= ...
            (cfg.tau_q+cfg.success_tol);

        row = row+1;

        cell_id(row) = cid;
        trial_id(row) = imc;

        cheap_success_new(row) = sc;
        fallback_success_new(row) = sf;

        cheap_q_hat_new(row) = qhc;
        fallback_q_hat_new(row) = qhf;

        cheap_prominence(row) = feat_c.prominence;
        cheap_entropy(row) = feat_c.curve_entropy;
        cheap_second_to_first(row) = feat_c.second_to_first;

        strong_frac_bin_offset_abs(row) = ...
            Sfeat.frac_bin_offset_abs;

        strong_peak_concentration(row) = ...
            Sfeat.peak_concentration;

        strong_notch_capture_fraction(row) = ...
            Sfeat.notch_capture_fraction;

        strong_side_leakage_to_notch(row) = ...
            Sfeat.side_leakage_to_notch;

        strong_local_spectral_width(row) = ...
            Sfeat.local_spectral_width;

        strong_local_asymmetry(row) = ...
            Sfeat.local_asymmetry;

        strong_global_removed_fraction(row) = ...
            Sfeat.global_removed_fraction;

        estimated_q_separation_abs(row) = ...
            abs(q_s-qhc);

        cheap_peak_power(row) = metric_c(idx_c);
        strong_peak_power(row) = Sfeat.peak_power;

        estimated_strong_weak_peak_ratio_db(row) = ...
            10*log10( ...
            max(Sfeat.peak_power,eps) / ...
            max(metric_c(idx_c),eps));
    end
end

%% Reproduction check against C1
if any(cell_id ~= C1.cell_id) || any(trial_id ~= C1.trial_id)
    error('C2.1 generated row ordering does not match C1.');
end

cheap_mismatch = sum( ...
    cheap_success_new ~= logical(C1.cheap_success));

fallback_mismatch = sum( ...
    fallback_success_new ~= logical(C1.fallback_success));

cheap_q_maxdiff = max(abs( ...
    cheap_q_hat_new-C1.cheap_q_hat));

fallback_q_maxdiff = max(abs( ...
    fallback_q_hat_new-C1.fallback_q_hat));

fprintf('================ C2.1 REPRODUCTION ===================\n');
fprintf('Cheap success mismatches      = %d\n',cheap_mismatch);
fprintf('Fallback success mismatches   = %d\n',fallback_mismatch);
fprintf('Max Cheap q difference        = %.6g\n',cheap_q_maxdiff);
fprintf('Max Fallback q difference     = %.6g\n',fallback_q_maxdiff);

if cheap_mismatch>0 || fallback_mismatch>0 || ...
        cheap_q_maxdiff>1e-12 || fallback_q_maxdiff>1e-12
    error(['C2.1 does not exactly reproduce C1 branch outcomes. ' ...
        'Stop before feature analysis.']);
end

%% Canonical labels inherited from C1
cheap = logical(C1.cheap_success);
fb = logical(C1.fallback_success);

beneficial = ~cheap & fb;
harmful = cheap & ~fb;
neutral = ~(beneficial | harmful);

cheap_recall = mean(cheap);
fallback_recall = mean(fb);
oracle_recall = mean(cheap | fb);

%% Assemble feature table
feature_table = table( ...
    cell_id,trial_id,beneficial,harmful,neutral, ...
    cheap_prominence,cheap_entropy,cheap_second_to_first, ...
    strong_frac_bin_offset_abs,strong_peak_concentration, ...
    strong_notch_capture_fraction,strong_side_leakage_to_notch, ...
    strong_local_spectral_width,strong_local_asymmetry, ...
    strong_global_removed_fraction, ...
    estimated_q_separation_abs,estimated_strong_weak_peak_ratio_db, ...
    strong_peak_power,cheap_peak_power);

writetable(feature_table, ...
    fullfile(out_dir,'c2_1_trial_mechanism_features.csv'));

%% Feature groups
weak_names = { ...
    'cheap_prominence', ...
    'cheap_entropy', ...
    'cheap_second_to_first'};

strong_names = { ...
    'strong_frac_bin_offset_abs', ...
    'strong_peak_concentration', ...
    'strong_notch_capture_fraction', ...
    'strong_side_leakage_to_notch', ...
    'strong_local_spectral_width', ...
    'strong_local_asymmetry', ...
    'strong_global_removed_fraction'};

geometry_names = { ...
    'estimated_q_separation_abs', ...
    'estimated_strong_weak_peak_ratio_db'};

mechanism_names = [strong_names geometry_names];
all_names = [weak_names mechanism_names];

%% Single-feature audit
all_feature_names = all_names;
F = numel(all_feature_names);

feature = strings(F,1);
auc_beneficial = nan(F,1);
dir_beneficial = strings(F,1);
auc_harmful = nan(F,1);
dir_harmful = strings(F,1);

for j = 1:F
    feature(j) = all_feature_names{j};

    x = feature_table.(all_feature_names{j});

    [auc_beneficial(j),dir_beneficial(j)] = ...
        oriented_auc(beneficial,x);

    [auc_harmful(j),dir_harmful(j)] = ...
        oriented_auc(harmful,x);
end

feature_audit = table( ...
    feature,auc_beneficial,dir_beneficial, ...
    auc_harmful,dir_harmful, ...
    'VariableNames',{ ...
    'feature','auc_beneficial','direction_beneficial', ...
    'auc_harmful','direction_harmful'});

feature_audit = sortrows( ...
    feature_audit,'auc_beneficial','descend');

writetable(feature_audit, ...
    fullfile(out_dir,'mechanism_feature_audit.csv'));

%% Group-level LOCO value models
groups = { ...
    weak_names, ...
    strong_names, ...
    geometry_names, ...
    mechanism_names, ...
    all_names};

group_names = [ ...
    "WeakOnly"; ...
    "StrongCleanOnly"; ...
    "GeometryOnly"; ...
    "MechanismCombined"; ...
    "AllCombined"];

G = numel(groups);

group_auc_B = nan(G,1);
group_auc_H = nan(G,1);
group_value_spearman = nan(G,1);

group_value_scores = cell(G,1);
group_valid = cell(G,1);

for ig = 1:G
    Xg = table_to_matrix(feature_table,groups{ig});

    [pB,validB] = loco_logistic_predictions( ...
        Xg,beneficial,cell_id,cfg.logit_l2);

    [pH,validH] = loco_logistic_predictions( ...
        Xg,harmful,cell_id,cfg.logit_l2);

    valid = validB & validH;

    V = pB-cfg.lambda_harm*pH;

    group_auc_B(ig) = ...
        binary_auc(beneficial(valid),pB(valid));

    group_auc_H(ig) = ...
        binary_auc(harmful(valid),pH(valid));

    utility = double(beneficial)- ...
        cfg.lambda_harm*double(harmful);

    group_value_spearman(ig) = ...
        spearman_manual(V(valid),utility(valid));

    group_value_scores{ig} = V;
    group_valid{ig} = valid;
end

group_diagnostics = table( ...
    group_names,group_auc_B,group_auc_H,group_value_spearman, ...
    'VariableNames',{ ...
    'feature_group','auc_beneficial','auc_harmful', ...
    'spearman_with_net_utility'});

writetable(group_diagnostics, ...
    fullfile(out_dir,'group_loco_diagnostics.csv'));

%% Budget curves
budgets = cfg.budget_grid(:);

% Simple C2 baselines.
curve_prom = loco_budget_curve_from_feature( ...
    cell_id,cheap_prominence,'low', ...
    budgets,cheap,fb,beneficial,harmful);

curve_entropy = loco_budget_curve_from_feature( ...
    cell_id,cheap_entropy,'high', ...
    budgets,cheap,fb,beneficial,harmful);

% A directly interpretable strong-stage scalar:
% higher side leakage -> more likely to benefit from refit.
curve_leakage = loco_budget_curve_from_feature( ...
    cell_id,strong_side_leakage_to_notch,'high', ...
    budgets,cheap,fb,beneficial,harmful);

% Learned group models: thresholds are fit from training-cell scores only.
curve_groups = cell(G,1);

for ig = 1:G
    Xg = table_to_matrix(feature_table,groups{ig});

    curve_groups{ig} = loco_model_budget_curve( ...
        cell_id,Xg,beneficial,harmful, ...
        budgets,cheap,fb,cfg.logit_l2,cfg.lambda_harm);

    curve_groups{ig}.policy = ...
        repmat(group_names(ig),height(curve_groups{ig}),1);
end

curve_prom.policy = repmat("Prominence",height(curve_prom),1);
curve_entropy.policy = repmat("Entropy",height(curve_entropy),1);
curve_leakage.policy = repmat("SideLeakage",height(curve_leakage),1);

curve_oracle = oracle_budget_curve( ...
    budgets,cheap,beneficial,harmful);
curve_oracle.policy = repmat("Oracle",height(curve_oracle),1);

curve_random = random_expectation_curve( ...
    budgets,cheap_recall,mean(beneficial),mean(harmful));
curve_random.policy = repmat("RandomExpected",height(curve_random),1);

budget_curves = [ ...
    curve_prom; ...
    curve_entropy; ...
    curve_leakage; ...
    curve_groups{1}; ...
    curve_groups{2}; ...
    curve_groups{3}; ...
    curve_groups{4}; ...
    curve_groups{5}; ...
    curve_oracle; ...
    curve_random];

budget_curves = movevars( ...
    budget_curves,'policy','Before',1);

writetable(budget_curves, ...
    fullfile(out_dir,'mechanism_budget_curves.csv'));

%% Highlighted budgets
report_budgets = cfg.report_budgets(:);

policy_list = unique(budget_curves.policy,'stable');

rows = {};

for ip = 1:numel(policy_list)
    Cp = budget_curves(budget_curves.policy==policy_list(ip),:);

    for ib = 1:numel(report_budgets)
        b = report_budgets(ib);

        [~,ii] = min(abs(Cp.target_budget-b));

        rows(end+1,:) = { ... %#ok<AGROW>
            char(policy_list(ip)), ...
            b, ...
            Cp.actual_trigger_rate(ii), ...
            Cp.policy_recall(ii), ...
            Cp.beneficial_capture(ii), ...
            Cp.benefit_precision(ii), ...
            Cp.harmful_fraction_among_triggers(ii), ...
            Cp.normalized_q_search_budget(ii)};
    end
end

budget_points = cell2table(rows, ...
    'VariableNames',{ ...
    'policy','target_budget','actual_trigger_rate', ...
    'policy_recall','beneficial_capture','benefit_precision', ...
    'harmful_fraction_among_triggers', ...
    'normalized_q_search_budget'});

writetable(budget_points, ...
    fullfile(out_dir,'reported_budget_points.csv'));

%% Cell-level mechanism statistics
cell_diag = table(cells(:), ...
    'VariableNames',{'cell_id'});

cell_diag.beneficial_rate = nan(K,1);
cell_diag.harmful_rate = nan(K,1);
cell_diag.mean_side_leakage = nan(K,1);
cell_diag.mean_frac_bin_offset = nan(K,1);
cell_diag.mean_estimated_q_separation = nan(K,1);
cell_diag.mean_strong_weak_ratio_db = nan(K,1);

for ik = 1:K
    mm = cell_id==cells(ik);

    cell_diag.beneficial_rate(ik) = ...
        mean(beneficial(mm));

    cell_diag.harmful_rate(ik) = ...
        mean(harmful(mm));

    cell_diag.mean_side_leakage(ik) = ...
        mean(strong_side_leakage_to_notch(mm),'omitnan');

    cell_diag.mean_frac_bin_offset(ik) = ...
        mean(strong_frac_bin_offset_abs(mm),'omitnan');

    cell_diag.mean_estimated_q_separation(ik) = ...
        mean(estimated_q_separation_abs(mm),'omitnan');

    cell_diag.mean_strong_weak_ratio_db(ik) = ...
        mean(estimated_strong_weak_peak_ratio_db(mm),'omitnan');
end

writetable(cell_diag, ...
    fullfile(out_dir,'cell_mechanism_diagnostics.csv'));

%% Console summary
fprintf('\n================ C2.1 FEATURE AUDIT ==================\n');
topN = min(8,height(feature_audit));

for i = 1:topN
    fprintf('#%d %-34s AUC(B)=%.3f dir=%s AUC(H)=%.3f\n', ...
        i,feature_audit.feature(i), ...
        feature_audit.auc_beneficial(i), ...
        feature_audit.direction_beneficial(i), ...
        feature_audit.auc_harmful(i));
end

fprintf('\n================ C2.1 GROUP DIAGNOSTICS =============\n');

for ig = 1:G
    fprintf('%-20s AUC(B)=%.3f AUC(H)=%.3f rho(V)=%.3f\n', ...
        group_names(ig), ...
        group_auc_B(ig), ...
        group_auc_H(ig), ...
        group_value_spearman(ig));
end

fprintf('\n================ C2.1 25%% BUDGET ====================\n');

rows25 = budget_points( ...
    abs(budget_points.target_budget-0.25)<1e-12,:);

for i = 1:height(rows25)
    fprintf('%-20s actual=%.3f recall=%.3f capture=%.3f precision=%.3f harm=%.3f\n', ...
        rows25.policy{i}, ...
        rows25.actual_trigger_rate(i), ...
        rows25.policy_recall(i), ...
        rows25.beneficial_capture(i), ...
        rows25.benefit_precision(i), ...
        rows25.harmful_fraction_among_triggers(i));
end

fprintf('======================================================\n');

%% Text summary
fid = fopen(fullfile(out_dir,'summary.txt'),'w');

fprintf(fid,'EXP009-C2.1 Mechanism-Aware Pre-Fallback Observable Audit\n');
fprintf(fid,'========================================================\n\n');

fprintf(fid,'Reproduction\n');
fprintf(fid,'------------\n');
fprintf(fid,'Cheap success mismatches: %d\n',cheap_mismatch);
fprintf(fid,'Fallback success mismatches: %d\n',fallback_mismatch);
fprintf(fid,'Max Cheap q difference: %.12g\n',cheap_q_maxdiff);
fprintf(fid,'Max Fallback q difference: %.12g\n\n',fallback_q_maxdiff);

fprintf(fid,'Trial composition\n');
fprintf(fid,'-----------------\n');
fprintf(fid,'Cheap recall: %.6f\n',cheap_recall);
fprintf(fid,'Fallback recall: %.6f\n',fallback_recall);
fprintf(fid,'Oracle recall: %.6f\n',oracle_recall);
fprintf(fid,'Beneficial rate: %.6f\n',mean(beneficial));
fprintf(fid,'Harmful rate: %.6f\n',mean(harmful));
fprintf(fid,'Neutral rate: %.6f\n\n',mean(neutral));

fprintf(fid,'Top single features by Beneficial AUC\n');
fprintf(fid,'-------------------------------------\n');

for i = 1:height(feature_audit)
    fprintf(fid,'%s AUC_B=%.6f dir=%s AUC_H=%.6f dirH=%s\n', ...
        feature_audit.feature(i), ...
        feature_audit.auc_beneficial(i), ...
        feature_audit.direction_beneficial(i), ...
        feature_audit.auc_harmful(i), ...
        feature_audit.direction_harmful(i));
end

fprintf(fid,'\nLOCO feature groups\n');
fprintf(fid,'-------------------\n');

for ig = 1:G
    fprintf(fid,'%s AUC_B=%.6f AUC_H=%.6f rhoV=%.6f\n', ...
        group_names(ig), ...
        group_auc_B(ig), ...
        group_auc_H(ig), ...
        group_value_spearman(ig));
end

fprintf(fid,'\nHighlighted budget points\n');
fprintf(fid,'-------------------------\n');

for i = 1:height(budget_points)
    fprintf(fid, ...
        ['%s target=%.3f actual=%.6f recall=%.6f ' ...
         'capture=%.6f precision=%.6f harm=%.6f budget=%.6f\n'], ...
        budget_points.policy{i}, ...
        budget_points.target_budget(i), ...
        budget_points.actual_trigger_rate(i), ...
        budget_points.policy_recall(i), ...
        budget_points.beneficial_capture(i), ...
        budget_points.benefit_precision(i), ...
        budget_points.harmful_fraction_among_triggers(i), ...
        budget_points.normalized_q_search_budget(i));
end

fclose(fid);

%% Figures
make_figures( ...
    out_dir,cfg,feature_audit,group_diagnostics, ...
    budget_curves,budget_points,feature_table,cell_diag, ...
    cheap_recall,oracle_recall);

%% Save
results = struct();

results.cfg = cfg;
results.feature_table = feature_table;
results.feature_audit = feature_audit;
results.group_diagnostics = group_diagnostics;
results.budget_curves = budget_curves;
results.budget_points = budget_points;
results.cell_diag = cell_diag;

results.cheap_recall = cheap_recall;
results.fallback_recall = fallback_recall;
results.oracle_recall = oracle_recall;

save(fullfile(out_dir,'exp09c2_1_results.mat'), ...
    'results','-v7.3');

fprintf('\nSaved EXP009-C2.1 outputs to:\n%s\n\n',out_dir);

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
function feat = extract_weak_features(metric,idx_peak,cfg)
m = metric(:);

L = numel(m);
peak = m(idx_peak);

floor_med = median(m);

feat.prominence = ...
    (peak-floor_med)/max(peak,eps);

pp = m/max(sum(m),eps);
pp = pp(pp>0);

if L>1
    feat.curve_entropy = ...
        -sum(pp.*log(pp))/log(L);
else
    feat.curve_entropy = 0;
end

guard = 4;
keep = true(L,1);

i1 = max(1,idx_peak-guard);
i2 = min(L,idx_peak+guard);

keep(i1:i2) = false;

if any(keep)
    tmp = m;
    tmp(~keep) = -Inf;
    second_peak = max(tmp);
else
    second_peak = 0;
end

feat.second_to_first = second_peak/max(peak,eps);
end

%% ========================================================================
function feat = extract_strong_stage_features(x_mix,q_strong,t,cfg)
% Practical strong-stage observables from the N-point dechirped FFT.
%
% No fallback/refit output is used here.

N = numel(x_mix);

mu = cfg.mu_scale*(q_strong-cfg.q_ref);
dechirp = exp(-1j*pi*mu*t.^2);

Z = fft(x_mix.*dechirp);

% IMPORTANT ORIENTATION GUARD:
% Always force the local spectrum to a column vector before weighted
% moment calculations. Otherwise, a row-vector spectrum indexed by a
% column-vector index can interact with column-vector offsets through
% implicit expansion and produce an L-by-L matrix instead of a scalar.
P = abs(Z(:)).^2;

[peak_power,k0] = max(P);

%% Fractional-bin offset
km = mod(k0-2,N)+1;
kp = mod(k0,N)+1;

ym = P(km);
y0 = P(k0);
yp = P(kp);

den = ym - 2*y0 + yp;

if abs(den)<eps
    delta = 0;
else
    delta = 0.5*(ym-yp)/den;
end

% Since k0 is the discrete maximum, a physically meaningful local
% parabolic offset should stay within roughly half a bin.
delta = min(max(delta,-0.5),0.5);

feat.frac_bin_offset_abs = abs(delta);

%% Local window around strong peak
hw = cfg.strong_local_halfwidth_bins;
offsets = (-hw:hw).';

idx_local = mod((k0-1)+offsets,N)+1;

% Explicitly preserve column-vector orientation for all local spectral
% statistics. This prevents MATLAB implicit-expansion bugs in expressions
% such as offsets .* weights.
P_local = P(idx_local);
P_local = P_local(:);

E_local = sum(P_local);

feat.peak_concentration = ...
    peak_power/max(E_local,eps);

%% Notch capture fraction
nhw = cfg.notch_halfwidth_bins;
notch_mask = abs(offsets)<=nhw;

E_notch = sum(P_local(notch_mask));

feat.notch_capture_fraction = ...
    E_notch/max(E_local,eps);

%% Side leakage immediately outside notch
outer = cfg.strong_side_outer_halfwidth_bins;

side_mask = ...
    abs(offsets)>nhw & ...
    abs(offsets)<=outer;

E_side = sum(P_local(side_mask));

feat.side_leakage_to_notch = ...
    E_side/max(E_notch,eps);

%% Local spectral width in FFT bins
weights = P_local/max(E_local,eps);
weights = weights(:);
offsets = offsets(:);

mu_bin = sum(offsets.*weights);

local_var = sum(((offsets-mu_bin).^2).*weights);
local_var = max(real(local_var),0);

feat.local_spectral_width = sqrt(local_var);

if ~isscalar(feat.local_spectral_width)
    error(['extract_strong_stage_features: local_spectral_width must be ' ...
        'scalar, but got size %s.'],mat2str(size(feat.local_spectral_width)));
end

%% Local left/right asymmetry outside center
left_mask = offsets<0;
right_mask = offsets>0;

E_left = sum(P_local(left_mask));
E_right = sum(P_local(right_mask));

feat.local_asymmetry = ...
    abs(E_right-E_left)/max(E_right+E_left,eps);

%% Fraction of total dechirped spectral power captured by cheap notch
E_total = sum(P);

feat.global_removed_fraction = ...
    E_notch/max(E_total,eps);

feat.peak_power = peak_power;
end

%% ========================================================================
function [r,fhat,alpha,atom] = ...
    refit_and_subtract_strong(x,q_strong,t,cfg)

N = numel(x);

mu = cfg.mu_scale*(q_strong-cfg.q_ref);
dechirp = exp(-1j*pi*mu*t.^2);

z = x.*dechirp;

nfft = cfg.refit_nfft_factor*N;

Z = fft(z,nfft);
P = abs(Z).^2;

[~,k0] = max(P);

km = mod(k0-2,nfft)+1;
kp = mod(k0,nfft)+1;

ym = P(km);
y0 = P(k0);
yp = P(kp);

den = ym - 2*y0 + yp;

if abs(den)<eps
    delta = 0;
else
    delta = 0.5*(ym-yp)/den;
end

delta = min(max(delta,-1),1);

bin0 = k0-1;

if bin0 > nfft/2
    bin0 = bin0-nfft;
end

fhat = (bin0+delta)*(N/nfft);

atom = exp(1j*(pi*mu*t.^2 + 2*pi*fhat*t));

den_a = sum(abs(atom).^2);

if den_a<=eps
    alpha = 0;
else
    alpha = sum(conj(atom).*x)/den_a;
end

r = x-alpha*atom;
end

%% ========================================================================
function X = table_to_matrix(T,names)
X = nan(height(T),numel(names));

for j = 1:numel(names)
    X(:,j) = double(T.(names{j}));
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

    [model,ok] = fit_logistic_model(X(train,:),y(train),l2);

    if ~ok
        continue;
    end

    p_oof(test) = predict_logistic_model(model,X(test,:));
    valid_oof(test) = true;
end
end

%% ========================================================================
function [model,ok] = fit_logistic_model(X,y,l2)
X = double(X);
y = double(y(:));

ok = false;
model = struct();

if numel(unique(y))<2
    return;
end

mu = mean(X,1,'omitnan');
sd = std(X,0,1,'omitnan');

mu(~isfinite(mu)) = 0;
sd(~isfinite(sd) | sd<1e-12) = 1;

X = fill_nonfinite_with_training_mean(X,mu);

Z = bsxfun(@rdivide,bsxfun(@minus,X,mu),sd);
Z1 = [ones(size(Z,1),1),Z];

beta0 = zeros(size(Z1,2),1);

objective = @(b) logistic_objective(b,Z1,y,l2);

opts = optimset( ...
    'Display','off', ...
    'MaxIter',1500, ...
    'MaxFunEvals',8000, ...
    'TolX',1e-7, ...
    'TolFun',1e-7);

beta = fminsearch(objective,beta0,opts);

model.mu = mu;
model.sd = sd;
model.beta = beta;

ok = true;
end

%% ========================================================================
function p = predict_logistic_model(model,X)
X = double(X);

X = fill_nonfinite_with_training_mean(X,model.mu);

Z = bsxfun(@rdivide, ...
    bsxfun(@minus,X,model.mu),model.sd);

Z1 = [ones(size(Z,1),1),Z];

z = Z1*model.beta;
z = max(min(z,35),-35);

p = 1./(1+exp(-z));
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
function curve = loco_budget_curve_from_feature( ...
    cell_id,feature,direction,budgets,cheap,fb,beneficial,harmful)

cell_id = cell_id(:);
feature = feature(:);
budgets = budgets(:);

N = numel(cell_id);
nB = numel(budgets);

trigger_mat = false(N,nB);
cells = unique(cell_id).';

for ic = 1:numel(cells)
    c = cells(ic);

    test = cell_id==c;
    train = ~test;

    train_feat = feature(train);
    train_feat = train_feat(isfinite(train_feat));

    test_idx = find(test);

    for ib = 1:nB
        b = budgets(ib);

        if b<=0
            trig = false(sum(test),1);
        elseif b>=1
            trig = true(sum(test),1);
        else
            switch direction
                case 'low'
                    thr = empirical_quantile(train_feat,b);
                    trig = feature(test)<=thr;
                case 'high'
                    thr = empirical_quantile(train_feat,1-b);
                    trig = feature(test)>=thr;
                otherwise
                    error('Unknown feature budget direction.');
            end
        end

        trigger_mat(test_idx,ib) = trig;
    end
end

curve = summarize_trigger_matrix( ...
    trigger_mat,budgets,cheap,fb,beneficial,harmful);
end

%% ========================================================================
function curve = loco_model_budget_curve( ...
    cell_id,X,beneficial,harmful,budgets,cheap,fb,l2,lambda_harm)

cell_id = cell_id(:);
budgets = budgets(:);

N = numel(cell_id);
nB = numel(budgets);

trigger_mat = false(N,nB);
cells = unique(cell_id).';

for ic = 1:numel(cells)
    c = cells(ic);

    test = cell_id==c;
    train = ~test;

    [mB,okB] = fit_logistic_model( ...
        X(train,:),double(beneficial(train)),l2);

    [mH,okH] = fit_logistic_model( ...
        X(train,:),double(harmful(train)),l2);

    if ~okB || ~okH
        continue;
    end

    pB_train = predict_logistic_model(mB,X(train,:));
    pH_train = predict_logistic_model(mH,X(train,:));

    pB_test = predict_logistic_model(mB,X(test,:));
    pH_test = predict_logistic_model(mH,X(test,:));

    value_train = pB_train-lambda_harm*pH_train;
    value_test = pB_test-lambda_harm*pH_test;

    test_idx = find(test);

    for ib = 1:nB
        b = budgets(ib);

        if b<=0
            trig = false(sum(test),1);
        elseif b>=1
            trig = true(sum(test),1);
        else
            thr = empirical_quantile(value_train,1-b);
            trig = value_test>=thr;
        end

        trigger_mat(test_idx,ib) = trig;
    end
end

curve = summarize_trigger_matrix( ...
    trigger_mat,budgets,cheap,fb,beneficial,harmful);
end

%% ========================================================================
function curve = summarize_trigger_matrix( ...
    trigger_mat,budgets,cheap,fb,beneficial,harmful)

budgets = budgets(:);
nB = numel(budgets);

target_budget = budgets;
actual_trigger_rate = nan(nB,1);
policy_recall = nan(nB,1);
beneficial_capture = nan(nB,1);
benefit_precision = nan(nB,1);
harmful_fraction_among_triggers = nan(nB,1);
normalized_q_search_budget = nan(nB,1);

nBeneficial = sum(beneficial);

for ib = 1:nB
    tr = trigger_mat(:,ib);

    actual_trigger_rate(ib) = mean(tr);

    pol = cheap;
    pol(tr) = fb(tr);

    policy_recall(ib) = mean(pol);

    if nBeneficial>0
        beneficial_capture(ib) = ...
            sum(beneficial & tr)/nBeneficial;
    end

    nTr = sum(tr);

    if nTr>0
        benefit_precision(ib) = ...
            sum(beneficial & tr)/nTr;

        harmful_fraction_among_triggers(ib) = ...
            sum(harmful & tr)/nTr;
    end

    normalized_q_search_budget(ib) = ...
        1+actual_trigger_rate(ib);
end

curve = table( ...
    target_budget,actual_trigger_rate,policy_recall, ...
    beneficial_capture,benefit_precision, ...
    harmful_fraction_among_triggers, ...
    normalized_q_search_budget);
end

%% ========================================================================
function curve = oracle_budget_curve(budgets,cheap,beneficial,harmful)
budgets = budgets(:);

nB = numel(budgets);

benefit_rate = mean(beneficial);
cheap_recall = mean(cheap);

target_budget = budgets;
actual_trigger_rate = nan(nB,1);
policy_recall = nan(nB,1);
beneficial_capture = nan(nB,1);
benefit_precision = nan(nB,1);
harmful_fraction_among_triggers = zeros(nB,1);
normalized_q_search_budget = nan(nB,1);

for ib = 1:nB
    b = budgets(ib);

    actual = min(max(b,0),benefit_rate);

    actual_trigger_rate(ib) = actual;

    policy_recall(ib) = ...
        min(cheap_recall+actual,cheap_recall+benefit_rate);

    if benefit_rate>0
        beneficial_capture(ib) = min(1,actual/benefit_rate);
    end

    if actual>0
        benefit_precision(ib) = 1;
    else
        benefit_precision(ib) = NaN;
    end

    normalized_q_search_budget(ib) = 1+actual;
end

curve = table( ...
    target_budget,actual_trigger_rate,policy_recall, ...
    beneficial_capture,benefit_precision, ...
    harmful_fraction_among_triggers, ...
    normalized_q_search_budget);
end

%% ========================================================================
function curve = random_expectation_curve( ...
    budgets,cheap_recall,benefit_rate,harm_rate)

budgets = budgets(:);
nB = numel(budgets);

target_budget = budgets;
actual_trigger_rate = budgets;

policy_recall = ...
    cheap_recall + budgets*(benefit_rate-harm_rate);

beneficial_capture = budgets;

benefit_precision = repmat(benefit_rate,nB,1);
harmful_fraction_among_triggers = repmat(harm_rate,nB,1);

benefit_precision(budgets==0) = NaN;
harmful_fraction_among_triggers(budgets==0) = NaN;

normalized_q_search_budget = 1+budgets;

curve = table( ...
    target_budget,actual_trigger_rate,policy_recall, ...
    beneficial_capture,benefit_precision, ...
    harmful_fraction_among_triggers, ...
    normalized_q_search_budget);
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
function q = empirical_quantile(x,p)
x = x(:);
x = x(isfinite(x));

if isempty(x)
    q = NaN;
    return;
end

x = sort(x);
p = min(max(p,0),1);

if numel(x)==1
    q = x;
    return;
end

pos = 1+p*(numel(x)-1);

lo = floor(pos);
hi = ceil(pos);

if lo==hi
    q = x(lo);
else
    w = pos-lo;
    q = (1-w)*x(lo)+w*x(hi);
end
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
    out_dir,cfg,feature_audit,group_diag, ...
    budget_curves,budget_points,Ftbl,cell_diag, ...
    cheap_recall,oracle_recall)

%% Fig 1: Single-feature beneficial AUC
topN = min(12,height(feature_audit));
T = feature_audit(1:topN,:);

fig = figure('Visible',cfg.figure_visible);

Y = [T.auc_beneficial,T.auc_harmful];
bar(Y);

ylim([0.45 1]);

xticks(1:topN);
xticklabels(T.feature);
xtickangle(35);

ylabel('Oriented AUC');
title('C2.1 Mechanism-Aware Observable Audit');

legend('Beneficial','Harmful','Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig01_mechanism_feature_auc.png'), ...
    'Resolution',180);

close(fig);

%% Fig 2: Group LOCO AUC
fig = figure('Visible',cfg.figure_visible);

Y = [group_diag.auc_beneficial,group_diag.auc_harmful];
bar(Y);

ylim([0.45 1]);

xticks(1:height(group_diag));
xticklabels(group_diag.feature_group);
xtickangle(25);

ylabel('LOCO AUC');
title('C2.1 Feature-Group LOCO Diagnostics');

legend('Beneficial','Harmful','Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig02_group_loco_auc.png'), ...
    'Resolution',180);

close(fig);

%% Fig 3: Beneficial capture vs budget
policies = [ ...
    "Prominence", ...
    "Entropy", ...
    "SideLeakage", ...
    "WeakOnly", ...
    "StrongCleanOnly", ...
    "GeometryOnly", ...
    "MechanismCombined", ...
    "AllCombined", ...
    "Oracle", ...
    "RandomExpected"];

fig = figure('Visible',cfg.figure_visible);
hold on;

for i = 1:numel(policies)
    Cp = budget_curves(budget_curves.policy==policies(i),:);

    plot(Cp.actual_trigger_rate,Cp.beneficial_capture, ...
        'LineWidth',1.25);
end

xlabel('Actual fallback rate');
ylabel('Capture of all beneficial trials');

title('C2.1 Beneficial Capture vs Budget');

legend(policies,'Location','eastoutside');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig03_beneficial_capture_vs_budget.png'), ...
    'Resolution',180);

close(fig);

%% Fig 4: Quality-cost Pareto
fig = figure('Visible',cfg.figure_visible);
hold on;

for i = 1:numel(policies)
    Cp = budget_curves(budget_curves.policy==policies(i),:);

    plot(Cp.normalized_q_search_budget,Cp.policy_recall, ...
        'LineWidth',1.25);
end

scatter(1,cheap_recall,70,'filled');
scatter(1+(oracle_recall-cheap_recall),oracle_recall,80,'filled');

xlabel('Normalized q-search budget');
ylabel('Weak recovery rate');

title('C2.1 Mechanism-Aware Quality-Cost Pareto');

legend([policies,"Cheap","Oracle minimal point"], ...
    'Location','eastoutside');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig04_quality_cost_pareto.png'), ...
    'Resolution',180);

close(fig);

%% Fig 5: 25% budget comparison
rows25 = budget_points( ...
    abs(budget_points.target_budget-0.25)<1e-12,:);

fig = figure('Visible',cfg.figure_visible);

bar(rows25.policy_recall);
ylim([0 1]);

xticks(1:height(rows25));
xticklabels(rows25.policy);
xtickangle(35);

ylabel('Weak recovery rate');
title('C2.1 Policy Comparison at 25% Target Budget');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig05_policy_comparison_25pct.png'), ...
    'Resolution',180);

close(fig);

%% Fig 6: Benefit precision at 25% budget
fig = figure('Visible',cfg.figure_visible);

bar(rows25.benefit_precision);
ylim([0 1]);

xticks(1:height(rows25));
xticklabels(rows25.policy);
xtickangle(35);

ylabel('Beneficial fraction among triggered trials');
title('C2.1 Budget Precision at 25% Target');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig06_precision_25pct.png'), ...
    'Resolution',180);

close(fig);

%% Fig 7: Side leakage by fallback value class
class_id = ones(height(Ftbl),1);
class_id(Ftbl.beneficial) = 2;
class_id(Ftbl.harmful) = 3;

fig = figure('Visible',cfg.figure_visible);

boxchart(class_id,Ftbl.strong_side_leakage_to_notch);

xticks([1 2 3]);
xticklabels({'Neutral','Beneficial','Harmful'});

ylabel('Strong side leakage / notch energy');
title('C2.1 Strong Leakage by Fallback Value Class');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig07_side_leakage_by_value_class.png'), ...
    'Resolution',180);

close(fig);

%% Fig 8: Practical mechanism plane
fig = figure('Visible',cfg.figure_visible);

classes = zeros(height(Ftbl),1);
classes(Ftbl.beneficial) = 1;
classes(Ftbl.harmful) = 2;

scatter( ...
    Ftbl.estimated_q_separation_abs, ...
    Ftbl.strong_side_leakage_to_notch, ...
    22,classes,'filled');

xlabel('Estimated |q_s - q_w|');
ylabel('Strong side leakage / notch energy');

title('C2.1 Practical Geometry-Leakage Plane');

cb = colorbar;
cb.Ticks = [0 1 2];
cb.TickLabels = {'Neutral','Beneficial','Harmful'};

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig08_geometry_leakage_plane.png'), ...
    'Resolution',180);

close(fig);

%% Fig 9: Cell-level mechanism map
fig = figure('Visible',cfg.figure_visible);

scatter( ...
    cell_diag.mean_estimated_q_separation, ...
    cell_diag.mean_side_leakage, ...
    100,cell_diag.beneficial_rate,'filled');

xlabel('Mean estimated q separation');
ylabel('Mean strong side leakage / notch energy');

title('C2.1 Cell-Level Mechanism Map');

cb = colorbar;
cb.Label.String = 'Beneficial fallback rate';

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig09_cell_mechanism_map.png'), ...
    'Resolution',180);

close(fig);

end
