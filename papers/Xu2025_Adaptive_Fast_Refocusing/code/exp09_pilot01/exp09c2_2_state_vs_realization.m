function results = exp09c2_2_state_vs_realization()
%EXP09C2_2_STATE_VS_REALIZATION
% EXP009 / Pilot-01 / Experiment C2.2
%
% State-vs-Realization Predictability Decomposition
%
% -------------------------------------------------------------------------
% Motivation
% -------------------------------------------------------------------------
% C2.1 showed a consistent pattern:
%
%   - pooled single-feature AUC can look moderately strong;
%   - but LOCO generalization of strong-clean / mechanism-aware feature
%     groups is weak;
%   - prominence / entropy remain the strongest practical baselines.
%
% This suggests that some apparent predictability may come from
% BETWEEN-STATE differences (different parameter cells have different
% baseline fallback value) rather than WITHIN-STATE single-realization
% ranking.
%
% C2.2 tests exactly that.
%
% -------------------------------------------------------------------------
% Main decomposition
% -------------------------------------------------------------------------
% For each feature x:
%
%   1) Pooled AUC
%      AUC(x, Beneficial)
%
%   2) Cell-centered pooled AUC
%      AUC(x - mean_cell(x), Beneficial)
%
%      This removes the between-cell mean shift.
%
%   3) Same-direction within-cell AUC
%      Compute one AUC per cell using the SAME orientation determined by
%      the global pooled relationship, then average across valid cells.
%
%   4) Between-cell eta^2
%      Fraction of feature variance attributable to cell mean differences:
%
%        eta^2 = SS_between / SS_total
%
% If pooled AUC is high but centered / within-cell AUC collapses toward
% 0.5, the feature is mainly a STATE marker, not a realization-level
% fallback-value predictor.
%
% -------------------------------------------------------------------------
% State-level oracle
% -------------------------------------------------------------------------
% Each cell c has:
%
%   pB_c = P(Beneficial | cell c)
%   pH_c = P(Harmful    | cell c)
%
% and expected fallback utility:
%
%   u_c = pB_c - lambda_harm * pH_c.
%
% A diagnostic STATE ORACLE knows only u_c, not the individual trial
% labels. Under a computation-budget cap, it allocates fallback calls to
% high-u_c cells first but is RANDOM within each cell.
%
% This is compared with:
%
%   Random Expected
%   State Oracle
%   Trial Oracle
%
% and, when available, the practical C2.1 Prominence / Entropy curves.
%
% This directly quantifies how much of the selective-computation
% opportunity is explainable by state alone.
%
% -------------------------------------------------------------------------
% Important boundary
% -------------------------------------------------------------------------
% Cell identity and true cell-average utility are diagnostic oracle
% information. C2.2 is NOT proposing a practical state estimator yet.
% Its purpose is to decide whether the next research step should target:
%
%   single-shot confidence
%
% or:
%
%   region / track / history-level risk estimation.
%
% Run:
%   results = exp09c2_2_state_vs_realization;

cfg = config_exp09c2_2();

%% Paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.c2_1_result_dir)
    c2_1_dir = fullfile(paper_root,'results','exp09_pilot01', ...
        'exp09c2_1_mechanism_observable_audit');
else
    c2_1_dir = cfg.c2_1_result_dir;
end

if isempty(cfg.c1_result_dir)
    c1_dir = fullfile(paper_root,'results','exp09_pilot01', ...
        'exp09c1_adaptive_budget');
else
    c1_dir = cfg.c1_result_dir;
end

if isempty(cfg.output_dir)
    out_dir = fullfile(paper_root,'results','exp09_pilot01', ...
        'exp09c2_2_state_vs_realization');
else
    out_dir = cfg.output_dir;
end

if ~exist(out_dir,'dir')
    mkdir(out_dir);
end

feat_file = fullfile(c2_1_dir,'c2_1_trial_mechanism_features.csv');
c1_file = fullfile(c1_dir,'c1_branch_trials.csv');
curve_file = fullfile(c2_1_dir,'mechanism_budget_curves.csv');

if ~exist(feat_file,'file')
    error('C2.1 feature table not found: %s',feat_file);
end

if ~exist(c1_file,'file')
    error('C1 branch table not found: %s',c1_file);
end

Ftbl = readtable(feat_file);
C1 = readtable(c1_file);

required_feat = { ...
    'cell_id','trial_id','beneficial','harmful','neutral'};

assert_table_vars(Ftbl,required_feat,'c2_1_trial_mechanism_features.csv');

required_c1 = { ...
    'cell_id','trial_id','weak_ratio','signed_sep','snr_db', ...
    'cheap_success','fallback_success'};

assert_table_vars(C1,required_c1,'c1_branch_trials.csv');

for j = 1:numel(cfg.features)
    if ~ismember(cfg.features{j},Ftbl.Properties.VariableNames)
        error('Feature "%s" not found in C2.1 feature table.', ...
            cfg.features{j});
    end
end

%% Align tables robustly
Ftbl = sortrows(Ftbl,{'cell_id','trial_id'});
C1 = sortrows(C1,{'cell_id','trial_id'});

if height(Ftbl) ~= height(C1)
    error('C2.1 feature table and C1 branch table have different row counts.');
end

if any(Ftbl.cell_id ~= C1.cell_id) || ...
        any(Ftbl.trial_id ~= C1.trial_id)
    error('C2.1 and C1 trial keys do not align after sorting.');
end

beneficial = logical(Ftbl.beneficial);
harmful = logical(Ftbl.harmful);
neutral = logical(Ftbl.neutral);

cheap = logical(C1.cheap_success);
fb = logical(C1.fallback_success);

if any(beneficial ~= (~cheap & fb)) || ...
        any(harmful ~= (cheap & ~fb))
    error('C2.1 value labels do not match C1 branch outcomes.');
end

cell_id = Ftbl.cell_id(:);
cells = unique(cell_id).';
K = numel(cells);
N = height(Ftbl);

cheap_recall = mean(cheap);
fallback_recall = mean(fb);
trial_oracle_recall = mean(cheap | fb);

beneficial_rate = mean(beneficial);
harmful_rate = mean(harmful);
neutral_rate = mean(neutral);

fprintf('\n============================================================\n');
fprintf(' EXP009-C2.2 / State-vs-Realization Decomposition\n');
fprintf('============================================================\n');
fprintf('Trials: %d\n',N);
fprintf('Cells:  %d\n',K);
fprintf('Cheap recall:        %.6f\n',cheap_recall);
fprintf('Fallback recall:     %.6f\n',fallback_recall);
fprintf('Trial-oracle recall: %.6f\n',trial_oracle_recall);
fprintf('Beneficial rate:     %.6f\n',beneficial_rate);
fprintf('Harmful rate:        %.6f\n\n',harmful_rate);

%% ------------------------------------------------------------------------
% Cell summary
cell_summary = table(cells(:),'VariableNames',{'cell_id'});

cell_summary.n_trials = zeros(K,1);
cell_summary.weak_ratio = nan(K,1);
cell_summary.signed_sep = nan(K,1);
cell_summary.snr_db = nan(K,1);

cell_summary.beneficial_rate = nan(K,1);
cell_summary.harmful_rate = nan(K,1);
cell_summary.neutral_rate = nan(K,1);
cell_summary.net_fallback_utility = nan(K,1);

cell_summary.cheap_recall = nan(K,1);
cell_summary.fallback_recall = nan(K,1);
cell_summary.oracle_recall = nan(K,1);

% Append cell means for every feature.
for j = 1:numel(cfg.features)
    vn = ['mean_' cfg.features{j}];
    cell_summary.(vn) = nan(K,1);
end

for ik = 1:K
    c = cells(ik);
    mm = cell_id==c;

    cell_summary.n_trials(ik) = sum(mm);

    % Physical parameters should be constant inside a cell.
    cell_summary.weak_ratio(ik) = scalar_unique(C1.weak_ratio(mm), ...
        sprintf('weak_ratio, cell %g',c));

    cell_summary.signed_sep(ik) = scalar_unique(C1.signed_sep(mm), ...
        sprintf('signed_sep, cell %g',c));

    cell_summary.snr_db(ik) = scalar_unique(C1.snr_db(mm), ...
        sprintf('snr_db, cell %g',c));

    pB = mean(beneficial(mm));
    pH = mean(harmful(mm));

    cell_summary.beneficial_rate(ik) = pB;
    cell_summary.harmful_rate(ik) = pH;
    cell_summary.neutral_rate(ik) = mean(neutral(mm));

    cell_summary.net_fallback_utility(ik) = ...
        pB-cfg.lambda_harm*pH;

    cell_summary.cheap_recall(ik) = mean(cheap(mm));
    cell_summary.fallback_recall(ik) = mean(fb(mm));
    cell_summary.oracle_recall(ik) = mean(cheap(mm) | fb(mm));

    for j = 1:numel(cfg.features)
        vn = ['mean_' cfg.features{j}];
        x = double(Ftbl.(cfg.features{j}));
        cell_summary.(vn)(ik) = mean(x(mm),'omitnan');
    end
end

writetable(cell_summary, ...
    fullfile(out_dir,'cell_state_summary.csv'));

%% ------------------------------------------------------------------------
% Label-level between-cell decomposition
yB = double(beneficial);
yH = double(harmful);
utility = double(beneficial)-cfg.lambda_harm*double(harmful);

eta2_beneficial = calc_between_cell_eta2(yB,cell_id);
eta2_harmful = calc_between_cell_eta2(yH,cell_id);
eta2_utility = calc_between_cell_eta2(utility,cell_id);

label_state_summary = table( ...
    ["Beneficial";"Harmful";"NetUtility"], ...
    [eta2_beneficial;eta2_harmful;eta2_utility], ...
    'VariableNames',{'target','between_cell_eta2'});

writetable(label_state_summary, ...
    fullfile(out_dir,'label_state_variance.csv'));

%% ------------------------------------------------------------------------
% Feature predictability decomposition
M = numel(cfg.features);

feature = strings(M,1);

pooled_auc_B = nan(M,1);
global_direction = strings(M,1);

cell_centered_auc_B = nan(M,1);

within_cell_auc_mean = nan(M,1);
within_cell_auc_weighted = nan(M,1);
within_cell_auc_std = nan(M,1);
n_valid_within_cells = zeros(M,1);

between_cell_eta2 = nan(M,1);

cell_mean_spearman_with_Brate = nan(M,1);
cell_mean_spearman_with_utility = nan(M,1);

% Save per-cell same-direction AUC values for heatmap.
within_auc_matrix = nan(K,M);

for j = 1:M
    fn = cfg.features{j};
    feature(j) = string(fn);

    x = double(Ftbl.(fn));
    x = x(:);

    [auc_best,dir_best] = oriented_auc(beneficial,x);

    pooled_auc_B(j) = auc_best;
    global_direction(j) = dir_best;

    % Apply ONE global orientation for all within-cell analyses.
    sgn = direction_to_sign(dir_best);
    xo = sgn*x;

    % Cell-centered feature removes between-cell mean shifts.
    xc = center_within_cell(xo,cell_id);

    cell_centered_auc_B(j) = binary_auc(beneficial,xc);

    % Same-direction AUC per cell.
    aucs = nan(K,1);
    weights = zeros(K,1);

    for ik = 1:K
        mm = cell_id==cells(ik);

        if numel(unique(beneficial(mm)))<2
            continue;
        end

        aucs(ik) = binary_auc(beneficial(mm),xo(mm));
        weights(ik) = sum(mm);
    end

    within_auc_matrix(:,j) = aucs;

    valid = isfinite(aucs);

    n_valid_within_cells(j) = sum(valid);

    if any(valid)
        within_cell_auc_mean(j) = mean(aucs(valid));
        within_cell_auc_std(j) = std(aucs(valid));

        ww = weights(valid);
        within_cell_auc_weighted(j) = ...
            sum(ww.*aucs(valid))/sum(ww);
    end

    between_cell_eta2(j) = calc_between_cell_eta2(x,cell_id);

    cell_means = nan(K,1);

    for ik = 1:K
        mm = cell_id==cells(ik);
        cell_means(ik) = mean(x(mm),'omitnan');
    end

    cell_mean_spearman_with_Brate(j) = ...
        spearman_manual(cell_means,cell_summary.beneficial_rate);

    cell_mean_spearman_with_utility(j) = ...
        spearman_manual(cell_means,cell_summary.net_fallback_utility);
end

predictability = table( ...
    feature,pooled_auc_B,global_direction, ...
    cell_centered_auc_B, ...
    within_cell_auc_mean,within_cell_auc_weighted, ...
    within_cell_auc_std,n_valid_within_cells, ...
    between_cell_eta2, ...
    cell_mean_spearman_with_Brate, ...
    cell_mean_spearman_with_utility, ...
    'VariableNames',{ ...
    'feature','pooled_auc_beneficial','global_direction', ...
    'cell_centered_auc_beneficial', ...
    'within_cell_auc_mean','within_cell_auc_weighted', ...
    'within_cell_auc_std','n_valid_within_cells', ...
    'between_cell_eta2', ...
    'cell_mean_spearman_with_beneficial_rate', ...
    'cell_mean_spearman_with_net_utility'});

predictability = sortrows( ...
    predictability,'pooled_auc_beneficial','descend');

writetable(predictability, ...
    fullfile(out_dir,'state_vs_realization_predictability.csv'));

%% Per-cell AUC table
within_auc_table = array2table(within_auc_matrix, ...
    'VariableNames',matlab.lang.makeValidName(cfg.features));
within_auc_table = addvars(within_auc_table,cells(:), ...
    'Before',1,'NewVariableNames','cell_id');

writetable(within_auc_table, ...
    fullfile(out_dir,'within_cell_auc_by_feature.csv'));

%% ------------------------------------------------------------------------
% State-oracle versus Trial-oracle budget curves
budgets = cfg.budget_grid(:);

state_curve = state_oracle_budget_curve( ...
    budgets,cell_summary,N,cheap_recall,cfg.lambda_harm);

trial_curve = trial_oracle_budget_curve( ...
    budgets,cheap_recall,beneficial_rate);

random_curve = random_expectation_curve( ...
    budgets,cheap_recall,beneficial_rate,harmful_rate, ...
    cfg.lambda_harm);

state_curve.policy = repmat("StateOracle",height(state_curve),1);
trial_curve.policy = repmat("TrialOracle",height(trial_curve),1);
random_curve.policy = repmat("RandomExpected",height(random_curve),1);

budget_curves = [state_curve;trial_curve;random_curve];

% Optionally import C2.1 practical Prominence / Entropy curves for context.
if exist(curve_file,'file')
    Ccurve = readtable(curve_file);

    required_curve = { ...
        'policy','target_budget','actual_trigger_rate', ...
        'policy_recall','beneficial_capture','benefit_precision', ...
        'harmful_fraction_among_triggers', ...
        'normalized_q_search_budget'};

    assert_table_vars(Ccurve,required_curve,'mechanism_budget_curves.csv');

    Ccurve.policy = string(Ccurve.policy);
    keep = ismember(Ccurve.policy,["Prominence","Entropy"]);

    Ccurve = Ccurve(keep,:);

    % Reorder to match.
    Ccurve = Ccurve(:,budget_curves.Properties.VariableNames);

    budget_curves = [budget_curves;Ccurve];
end

budget_curves = movevars(budget_curves,'policy','Before',1);

writetable(budget_curves, ...
    fullfile(out_dir,'state_vs_trial_budget_curves.csv'));

%% ------------------------------------------------------------------------
% How much selective advantage is explainable by STATE knowledge?
report_budgets = cfg.report_budgets(:);
R = numel(report_budgets);

target_budget = report_budgets;
random_recall = nan(R,1);
state_oracle_recall = nan(R,1);
trial_oracle_recall_at_budget = nan(R,1);

state_share_of_selection_advantage = nan(R,1);
state_share_of_total_oracle_gain_from_cheap = nan(R,1);

state_actual_budget = nan(R,1);
trial_actual_budget = nan(R,1);

for ir = 1:R
    b = report_budgets(ir);

    Cr = random_curve;
    Cs = state_curve;
    Ct = trial_curve;

    [~,iR] = min(abs(Cr.target_budget-b));
    [~,iS] = min(abs(Cs.target_budget-b));
    [~,iT] = min(abs(Ct.target_budget-b));

    random_recall(ir) = Cr.policy_recall(iR);
    state_oracle_recall(ir) = Cs.policy_recall(iS);
    trial_oracle_recall_at_budget(ir) = Ct.policy_recall(iT);

    state_actual_budget(ir) = Cs.actual_trigger_rate(iS);
    trial_actual_budget(ir) = Ct.actual_trigger_rate(iT);

    denom_sel = ...
        trial_oracle_recall_at_budget(ir)-random_recall(ir);

    if denom_sel>0
        state_share_of_selection_advantage(ir) = ...
            (state_oracle_recall(ir)-random_recall(ir))/denom_sel;
    end

    denom_total = ...
        trial_oracle_recall_at_budget(ir)-cheap_recall;

    if denom_total>0
        state_share_of_total_oracle_gain_from_cheap(ir) = ...
            (state_oracle_recall(ir)-cheap_recall)/denom_total;
    end
end

gain_decomp = table( ...
    target_budget, ...
    state_actual_budget,trial_actual_budget, ...
    random_recall,state_oracle_recall, ...
    trial_oracle_recall_at_budget, ...
    state_share_of_selection_advantage, ...
    state_share_of_total_oracle_gain_from_cheap);

writetable(gain_decomp, ...
    fullfile(out_dir,'state_oracle_gain_decomposition.csv'));

%% ------------------------------------------------------------------------
% State-level feature correlations
state_feature = strings(M,1);
rho_with_Brate = nan(M,1);
rho_with_utility = nan(M,1);

for j = 1:M
    fn = cfg.features{j};
    state_feature(j) = string(fn);

    vn = ['mean_' fn];
    cm = cell_summary.(vn);

    rho_with_Brate(j) = ...
        spearman_manual(cm,cell_summary.beneficial_rate);

    rho_with_utility(j) = ...
        spearman_manual(cm,cell_summary.net_fallback_utility);
end

state_corr = table( ...
    state_feature,rho_with_Brate,rho_with_utility, ...
    'VariableNames',{ ...
    'feature','spearman_cellmean_vs_beneficial_rate', ...
    'spearman_cellmean_vs_net_utility'});

state_corr = sortrows( ...
    state_corr,'spearman_cellmean_vs_net_utility','descend');

writetable(state_corr, ...
    fullfile(out_dir,'state_feature_correlations.csv'));

%% Console summary
fprintf('================ C2.2 LABEL STATE VARIANCE ===========\n');
fprintf('Beneficial between-cell eta^2 = %.3f\n',eta2_beneficial);
fprintf('Harmful between-cell eta^2    = %.3f\n',eta2_harmful);
fprintf('Net-utility between-cell eta^2= %.3f\n',eta2_utility);

fprintf('\n================ C2.2 TOP FEATURE DECOMPOSITION ======\n');

topN = min(8,height(predictability));

for i = 1:topN
    fprintf(['#%d %-34s pooled=%.3f centered=%.3f ' ...
        'within=%.3f eta2=%.3f validCells=%d\n'], ...
        i,char(predictability.feature(i)), ...
        predictability.pooled_auc_beneficial(i), ...
        predictability.cell_centered_auc_beneficial(i), ...
        predictability.within_cell_auc_weighted(i), ...
        predictability.between_cell_eta2(i), ...
        predictability.n_valid_within_cells(i));
end

fprintf('\n================ C2.2 STATE-ORACLE DECOMPOSITION =====\n');

for ir = 1:R
    fprintf(['Budget %.0f%%: Random=%.3f StateOracle=%.3f ' ...
        'TrialOracle=%.3f StateShare(selection)=%.3f ' ...
        'StateShare(total)=%.3f\n'], ...
        100*target_budget(ir), ...
        random_recall(ir), ...
        state_oracle_recall(ir), ...
        trial_oracle_recall_at_budget(ir), ...
        state_share_of_selection_advantage(ir), ...
        state_share_of_total_oracle_gain_from_cheap(ir));
end

fprintf('======================================================\n');

%% Text summary
fid = fopen(fullfile(out_dir,'summary.txt'),'w');

fprintf(fid,'EXP009-C2.2 State-vs-Realization Predictability Decomposition\n');
fprintf(fid,'============================================================\n\n');

fprintf(fid,'Trial composition\n');
fprintf(fid,'-----------------\n');
fprintf(fid,'Trials: %d\n',N);
fprintf(fid,'Cells: %d\n',K);
fprintf(fid,'Cheap recall: %.6f\n',cheap_recall);
fprintf(fid,'Fallback recall: %.6f\n',fallback_recall);
fprintf(fid,'Trial-oracle recall: %.6f\n',trial_oracle_recall);
fprintf(fid,'Beneficial rate: %.6f\n',beneficial_rate);
fprintf(fid,'Harmful rate: %.6f\n',harmful_rate);
fprintf(fid,'Neutral rate: %.6f\n\n',neutral_rate);

fprintf(fid,'Label-level between-cell variance\n');
fprintf(fid,'---------------------------------\n');
fprintf(fid,'Beneficial eta^2: %.6f\n',eta2_beneficial);
fprintf(fid,'Harmful eta^2: %.6f\n',eta2_harmful);
fprintf(fid,'Net utility eta^2: %.6f\n\n',eta2_utility);

fprintf(fid,'Feature predictability decomposition\n');
fprintf(fid,'------------------------------------\n');

for i = 1:height(predictability)
    fprintf(fid, ...
        ['%s pooledAUC=%.6f dir=%s centeredAUC=%.6f ' ...
         'withinMean=%.6f withinWeighted=%.6f eta2=%.6f ' ...
         'validCells=%d rhoCellB=%.6f rhoCellU=%.6f\n'], ...
        char(predictability.feature(i)), ...
        predictability.pooled_auc_beneficial(i), ...
        char(predictability.global_direction(i)), ...
        predictability.cell_centered_auc_beneficial(i), ...
        predictability.within_cell_auc_mean(i), ...
        predictability.within_cell_auc_weighted(i), ...
        predictability.between_cell_eta2(i), ...
        predictability.n_valid_within_cells(i), ...
        predictability.cell_mean_spearman_with_beneficial_rate(i), ...
        predictability.cell_mean_spearman_with_net_utility(i));
end

fprintf(fid,'\nState-oracle gain decomposition\n');
fprintf(fid,'-------------------------------\n');

for ir = 1:R
    fprintf(fid, ...
        ['target=%.3f stateActual=%.6f trialActual=%.6f ' ...
         'random=%.6f stateOracle=%.6f trialOracle=%.6f ' ...
         'stateShareSelection=%.6f stateShareTotal=%.6f\n'], ...
        target_budget(ir), ...
        state_actual_budget(ir), ...
        trial_actual_budget(ir), ...
        random_recall(ir), ...
        state_oracle_recall(ir), ...
        trial_oracle_recall_at_budget(ir), ...
        state_share_of_selection_advantage(ir), ...
        state_share_of_total_oracle_gain_from_cheap(ir));
end

fclose(fid);

%% Figures
make_figures( ...
    out_dir,cfg,predictability,within_auc_matrix,cells, ...
    label_state_summary,cell_summary,budget_curves, ...
    gain_decomp,state_corr,cheap_recall);

%% Save
results = struct();

results.cfg = cfg;
results.cell_summary = cell_summary;
results.label_state_summary = label_state_summary;
results.predictability = predictability;
results.within_auc_table = within_auc_table;
results.budget_curves = budget_curves;
results.gain_decomp = gain_decomp;
results.state_corr = state_corr;

results.cheap_recall = cheap_recall;
results.fallback_recall = fallback_recall;
results.trial_oracle_recall = trial_oracle_recall;

save(fullfile(out_dir,'exp09c2_2_results.mat'), ...
    'results','-v7.3');

fprintf('\nSaved EXP009-C2.2 outputs to:\n%s\n\n',out_dir);

end

%% ========================================================================
function v = scalar_unique(x,label)
x = double(x(:));
x = x(isfinite(x));

if isempty(x)
    error('No finite values found for %s.',label);
end

v = x(1);

if any(abs(x-v) > 1e-12)
    error('%s is not constant within cell.',label);
end
end

%% ========================================================================
function eta2 = calc_between_cell_eta2(x,groups)
x = double(x(:));
groups = groups(:);

valid = isfinite(x);
x = x(valid);
groups = groups(valid);

if numel(x)<2
    eta2 = NaN;
    return;
end

mu = mean(x);
sst = sum((x-mu).^2);

if sst<=eps
    eta2 = 0;
    return;
end

ug = unique(groups).';
ssb = 0;

for ig = 1:numel(ug)
    mm = groups==ug(ig);
    nc = sum(mm);

    if nc==0
        continue;
    end

    muc = mean(x(mm));
    ssb = ssb + nc*(muc-mu)^2;
end

eta2 = ssb/sst;
eta2 = min(max(real(eta2),0),1);
end

%% ========================================================================
function xc = center_within_cell(x,groups)
x = double(x(:));
groups = groups(:);

xc = nan(size(x));
ug = unique(groups).';

for ig = 1:numel(ug)
    mm = groups==ug(ig);
    vals = x(mm);

    mu = mean(vals,'omitnan');
    xc(mm) = vals-mu;
end
end

%% ========================================================================
function s = direction_to_sign(direction)
direction = string(direction);

if direction=="+"
    s = 1;
elseif direction=="-"
    s = -1;
else
    s = 1;
end
end

%% ========================================================================
function curve = state_oracle_budget_curve( ...
    budgets,cell_summary,N,cheap_recall,lambda_harm)
%STATE_ORACLE_BUDGET_CURVE
% Diagnostic expected-performance upper bound when the policy knows only
% each cell's average fallback value, not individual trial labels.
%
% Within a selected cell, fallback calls are assumed random.

budgets = budgets(:);
nB = numel(budgets);

pB = cell_summary.beneficial_rate(:);
pH = cell_summary.harmful_rate(:);
nC = cell_summary.n_trials(:);

u = pB-lambda_harm*pH;

[~,ord] = sort(u,'descend');

total_B = sum(nC.*pB);

target_budget = budgets;
actual_trigger_rate = nan(nB,1);
policy_recall = nan(nB,1);
beneficial_capture = nan(nB,1);
benefit_precision = nan(nB,1);
harmful_fraction_among_triggers = nan(nB,1);
normalized_q_search_budget = nan(nB,1);

for ib = 1:nB
    cap = max(0,min(1,budgets(ib)))*N;
    remaining = cap;

    expected_gain = 0;
    expected_B = 0;
    expected_H = 0;
    used = 0;

    for jj = 1:numel(ord)
        c = ord(jj);

        % A budget cap does not force us to spend computation on states
        % whose expected utility is non-positive.
        if u(c)<=0 || remaining<=0
            break;
        end

        m = min(remaining,nC(c));

        expected_gain = expected_gain + m*u(c);
        expected_B = expected_B + m*pB(c);
        expected_H = expected_H + m*pH(c);

        used = used + m;
        remaining = remaining-m;
    end

    actual_trigger_rate(ib) = used/N;
    policy_recall(ib) = cheap_recall + expected_gain/N;

    if total_B>0
        beneficial_capture(ib) = expected_B/total_B;
    end

    if used>0
        benefit_precision(ib) = expected_B/used;
        harmful_fraction_among_triggers(ib) = expected_H/used;
    end

    normalized_q_search_budget(ib) = 1+actual_trigger_rate(ib);
end

curve = table( ...
    target_budget,actual_trigger_rate,policy_recall, ...
    beneficial_capture,benefit_precision, ...
    harmful_fraction_among_triggers, ...
    normalized_q_search_budget);
end

%% ========================================================================
function curve = trial_oracle_budget_curve( ...
    budgets,cheap_recall,beneficial_rate)
budgets = budgets(:);
nB = numel(budgets);

target_budget = budgets;
actual_trigger_rate = nan(nB,1);
policy_recall = nan(nB,1);
beneficial_capture = nan(nB,1);
benefit_precision = nan(nB,1);
harmful_fraction_among_triggers = zeros(nB,1);
normalized_q_search_budget = nan(nB,1);

for ib = 1:nB
    used = min(max(budgets(ib),0),beneficial_rate);

    actual_trigger_rate(ib) = used;
    policy_recall(ib) = cheap_recall+used;

    if beneficial_rate>0
        beneficial_capture(ib) = min(1,used/beneficial_rate);
    end

    if used>0
        benefit_precision(ib) = 1;
    end

    normalized_q_search_budget(ib) = 1+used;
end

curve = table( ...
    target_budget,actual_trigger_rate,policy_recall, ...
    beneficial_capture,benefit_precision, ...
    harmful_fraction_among_triggers, ...
    normalized_q_search_budget);
end

%% ========================================================================
function curve = random_expectation_curve( ...
    budgets,cheap_recall,beneficial_rate,harmful_rate,lambda_harm)
budgets = budgets(:);

target_budget = budgets;
actual_trigger_rate = budgets;

policy_recall = ...
    cheap_recall + budgets*(beneficial_rate-lambda_harm*harmful_rate);

beneficial_capture = budgets;

benefit_precision = repmat(beneficial_rate,numel(budgets),1);
harmful_fraction_among_triggers = ...
    repmat(harmful_rate,numel(budgets),1);

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
% Efficient Mann-Whitney / rank-based AUC.
y = logical(y(:));
score = double(score(:));

valid = isfinite(score);
y = y(valid);
score = score(valid);

nPos = sum(y);
nNeg = sum(~y);

if nPos==0 || nNeg==0
    auc = NaN;
    return;
end

r = average_ranks(score);

sumPos = sum(r(y));

auc = ...
    (sumPos - nPos*(nPos+1)/2) / ...
    (nPos*nNeg);
end

%% ========================================================================
function rho = spearman_manual(x,y)
x = double(x(:));
y = double(y(:));

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

if numel(C)<4
    rho = NaN;
else
    rho = C(1,2);
end
end

%% ========================================================================
function r = average_ranks(x)
x = double(x(:));

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
function make_figures( ...
    out_dir,cfg,predictability,within_auc_matrix,cells, ...
    label_state_summary,cell_summary,budget_curves, ...
    gain_decomp,state_corr,cheap_recall)

%% Figure 1: Pooled vs centered vs within-cell AUC
topN = min(10,height(predictability));
T = predictability(1:topN,:);

fig = figure('Visible',cfg.figure_visible);

Y = [ ...
    T.pooled_auc_beneficial, ...
    T.cell_centered_auc_beneficial, ...
    T.within_cell_auc_weighted];

bar(Y);
hold on;
yline(0.5,'--');

ylim([0.4 1]);

xticks(1:topN);
xticklabels(T.feature);
xtickangle(35);

ylabel('Beneficial AUC');
title('C2.2 Pooled vs Within-State Predictability');

legend('Pooled','Cell-centered pooled','Within-cell weighted', ...
    'Location','best');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig01_pooled_vs_within_auc.png'), ...
    'Resolution',180);

close(fig);

%% Figure 2: Between-cell variance fraction
fig = figure('Visible',cfg.figure_visible);

bar(T.between_cell_eta2);

ylim([0 1]);

xticks(1:topN);
xticklabels(T.feature);
xtickangle(35);

ylabel('Between-cell \eta^2');
title('C2.2 How Much Feature Variance Is State-Level?');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig02_feature_between_cell_eta2.png'), ...
    'Resolution',180);

close(fig);

%% Figure 3: Label state variance
fig = figure('Visible',cfg.figure_visible);

bar(label_state_summary.between_cell_eta2);

ylim([0 1]);

xticks(1:height(label_state_summary));
xticklabels(label_state_summary.target);

ylabel('Between-cell \eta^2');
title('C2.2 State Contribution to Target Variance');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig03_label_state_variance.png'), ...
    'Resolution',180);

close(fig);

%% Figure 4: Within-cell AUC heatmap
% Reorder columns to the same sorted order used by predictability.
[~,loc] = ismember(string(predictability.feature),string(cfg.features));
A = within_auc_matrix(:,loc);

fig = figure('Visible',cfg.figure_visible);

imagesc(A,[0 1]);
colorbar;

xlabel('Feature');
ylabel('Cell ID');

xticks(1:numel(loc));
xticklabels(predictability.feature);
xtickangle(35);

yticks(1:numel(cells));
yticklabels(string(cells));

title('C2.2 Same-Direction Within-Cell Beneficial AUC');

exportgraphics(fig, ...
    fullfile(out_dir,'fig04_within_cell_auc_heatmap.png'), ...
    'Resolution',180);

close(fig);

%% Figure 5: State vs Trial oracle quality-cost
fig = figure('Visible',cfg.figure_visible);
hold on;

policies = unique(string(budget_curves.policy),'stable');
policies = policies(:);

for i = 1:numel(policies)
    Cp = budget_curves(string(budget_curves.policy)==policies(i),:);

    plot(Cp.normalized_q_search_budget,Cp.policy_recall, ...
        'LineWidth',1.4);
end

scatter(1,cheap_recall,70,'filled');

xlabel('Normalized q-search budget');
ylabel('Weak recovery rate');

title('C2.2 State-Level vs Trial-Level Adaptive Opportunity');

legend([policies;"Cheap"],'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig05_state_vs_trial_quality_cost.png'), ...
    'Resolution',180);

close(fig);

%% Figure 6: State share of oracle selection advantage
fig = figure('Visible',cfg.figure_visible);

plot(gain_decomp.target_budget, ...
    gain_decomp.state_share_of_selection_advantage, ...
    '-o','LineWidth',1.4);

hold on;

plot(gain_decomp.target_budget, ...
    gain_decomp.state_share_of_total_oracle_gain_from_cheap, ...
    '-o','LineWidth',1.4);

ylim([0 1]);

xlabel('Fallback budget cap');
ylabel('Fraction');

title('C2.2 How Much Oracle Gain Is State-Explainable?');

legend('Share of selection advantage above random', ...
    'Share of total oracle gain from cheap', ...
    'Location','best');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig06_state_explainable_gain.png'), ...
    'Resolution',180);

close(fig);

%% Figure 7: Cell utility map in physical state space
fig = figure('Visible',cfg.figure_visible);

scatter( ...
    cell_summary.signed_sep, ...
    cell_summary.weak_ratio, ...
    120,cell_summary.net_fallback_utility,'filled');

xlabel('q_s - q_w');
ylabel('A_w / A_s');

title('C2.2 Cell-Level Expected Fallback Utility');

cb = colorbar;
cb.Label.String = 'p_B - p_H';

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig07_cell_state_utility_map.png'), ...
    'Resolution',180);

close(fig);

%% Figure 8: Strongest cell-mean correlations
state_corr.abs_rho = abs(state_corr.spearman_cellmean_vs_net_utility);
state_corr = sortrows(state_corr,'abs_rho','descend');

nS = min(10,height(state_corr));
S = state_corr(1:nS,:);

fig = figure('Visible',cfg.figure_visible);

bar(S.spearman_cellmean_vs_net_utility);

ylim([-1 1]);

xticks(1:nS);
xticklabels(S.feature);
xtickangle(35);

ylabel('Spearman correlation');
title('C2.2 Cell-Mean Feature vs Cell Net Utility');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig08_cellmean_feature_correlations.png'), ...
    'Resolution',180);

close(fig);

end
