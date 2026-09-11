function results = exp09c2_benefit_aware_allocation()
%EXP09C2_BENEFIT_AWARE_ALLOCATION
% EXP009 / Pilot-01 / Experiment C2
%
% Benefit-Aware Computation Allocation
%
% -------------------------------------------------------------------------
% Motivation
% -------------------------------------------------------------------------
% C1.1 decomposed the remaining Practical-vs-Oracle gap into:
%
%   ~90% allocation loss
%   ~10% selector loss
%
% Therefore C2 does NOT optimize the post-fallback branch selector.
% It asks a more direct policy question:
%
%   "If I spend one extra fallback computation on this residual state,
%    what is the expected recovery gain?"
%
% -------------------------------------------------------------------------
% Trial labels
% -------------------------------------------------------------------------
% Beneficial:
%   cheap fails AND fallback succeeds
%
% Harmful:
%   cheap succeeds AND fallback fails
%
% Neutral:
%   both branches have the same binary recovery outcome
%
% -------------------------------------------------------------------------
% Value-of-Computation target
% -------------------------------------------------------------------------
% Two simple LOCO logistic models estimate:
%
%   P(Beneficial | cheap observables)
%   P(Harmful    | cheap observables)
%
% Then:
%
%   V(x) = P(Beneficial|x) - lambda_harm * P(Harmful|x)
%
% Under a fixed fallback budget, larger V(x) should receive computation
% first.
%
% The primary observables are intentionally small and pre-fallback:
%
%   cheap prominence
%   cheap entropy
%   cheap second/first peak ratio
%
% No oracle quantities (Gamma, true q, weak ratio, SNR, etc.) are used by
% the practical model.
%
% -------------------------------------------------------------------------
% Models
% -------------------------------------------------------------------------
% 1) Prominence ranking baseline
% 2) Entropy ranking baseline
% 3) Linear logistic value model
% 4) Quadratic/interacting logistic value model
% 5) Oracle ranking
% 6) Random-allocation expectation
%
% All learned scores are leave-one-cell-out (LOCO):
% a complete parameter cell is held out during model fitting.
%
% -------------------------------------------------------------------------
% Main outputs
% -------------------------------------------------------------------------
% C2 emphasizes:
%
%   Beneficial Capture vs Computation Budget
%   Recovery Recall vs Computation Budget
%   Benefit Precision vs Computation Budget
%   Harmful Trigger Fraction vs Computation Budget
%
% rather than only ROC/AUC.
%
% Run:
%   results = exp09c2_benefit_aware_allocation;

cfg = config_exp09c2();

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
        'exp09c2_benefit_aware_allocation');
else
    out_dir = cfg.output_dir;
end

if ~exist(out_dir,'dir')
    mkdir(out_dir);
end

branch_file = fullfile(c1_dir,'c1_branch_trials.csv');

if ~exist(branch_file,'file')
    error('C1 branch trial file not found: %s',branch_file);
end

T = readtable(branch_file);

required = { ...
    'cell_id','trial_id', ...
    'cheap_success','fallback_success', ...
    'cheap_prominence','cheap_entropy','cheap_second_to_first'};

assert_table_vars(T,required,'c1_branch_trials.csv');

for i = 1:numel(cfg.primary_features)
    if ~ismember(cfg.primary_features{i},T.Properties.VariableNames)
        error('Primary feature "%s" not found in C1 branch table.', ...
            cfg.primary_features{i});
    end
end

fprintf('\n============================================================\n');
fprintf(' EXP009-C2 / Benefit-Aware Computation Allocation\n');
fprintf('============================================================\n');
fprintf('C1 input: %s\n',c1_dir);
fprintf('Output:   %s\n',out_dir);
fprintf('Trials:   %d\n',height(T));
fprintf('Cells:    %d\n\n',numel(unique(T.cell_id)));

%% Labels
cheap = logical(T.cheap_success);
fb = logical(T.fallback_success);

beneficial = ~cheap & fb;
harmful = cheap & ~fb;
neutral = ~(beneficial | harmful);

cheap_recall = mean(cheap);
fallback_recall = mean(fb);
oracle_union = cheap | fb;
oracle_recall = mean(oracle_union);

beneficial_rate = mean(beneficial);
harmful_rate = mean(harmful);
neutral_rate = mean(neutral);

fprintf('Cheap recall      = %.6f\n',cheap_recall);
fprintf('Fallback recall   = %.6f\n',fallback_recall);
fprintf('Oracle union      = %.6f\n',oracle_recall);
fprintf('Beneficial rate   = %.6f\n',beneficial_rate);
fprintf('Harmful rate      = %.6f\n',harmful_rate);
fprintf('Neutral rate      = %.6f\n\n',neutral_rate);

%% Practical feature matrices
feature_names = cfg.primary_features;
F = numel(feature_names);

X = nan(height(T),F);

for j = 1:F
    X(:,j) = double(T.(feature_names{j}));
end

% Linear feature map: standardized raw observables.
X_linear = X;

% Quadratic feature map:
% [x1 x2 x3 x1^2 x2^2 x3^2 x1*x2 x1*x3 x2*x3]
[X_quad,quad_names] = quadratic_feature_map(X,feature_names);

%% ------------------------------------------------------------------------
% Single-feature benefit/harm audit
feature = strings(F,1);
auc_benefit = nan(F,1);
dir_benefit = strings(F,1);
auc_harm = nan(F,1);
dir_harm = strings(F,1);

for j = 1:F
    feature(j) = feature_names{j};
    [auc_benefit(j),dir_benefit(j)] = ...
        oriented_auc(beneficial,X(:,j));
    [auc_harm(j),dir_harm(j)] = ...
        oriented_auc(harmful,X(:,j));
end

feature_audit = table( ...
    feature,auc_benefit,dir_benefit,auc_harm,dir_harm, ...
    'VariableNames',{ ...
    'feature','auc_beneficial','risk_direction_beneficial', ...
    'auc_harmful','risk_direction_harmful'});

feature_audit = sortrows(feature_audit,'auc_beneficial','descend');

writetable(feature_audit, ...
    fullfile(out_dir,'benefit_feature_audit.csv'));

%% ------------------------------------------------------------------------
% Leave-one-cell-out benefit/harm probability models
groups = T.cell_id;

[pB_lin,valid_B_lin] = loco_logistic_predictions( ...
    X_linear,beneficial,groups,cfg.logit_l2);

[pH_lin,valid_H_lin] = loco_logistic_predictions( ...
    X_linear,harmful,groups,cfg.logit_l2);

[pB_quad,valid_B_quad] = loco_logistic_predictions( ...
    X_quad,beneficial,groups,cfg.logit_l2);

[pH_quad,valid_H_quad] = loco_logistic_predictions( ...
    X_quad,harmful,groups,cfg.logit_l2);

valid_lin = valid_B_lin & valid_H_lin;
valid_quad = valid_B_quad & valid_H_quad;

value_lin = pB_lin - cfg.lambda_harm*pH_lin;
value_quad = pB_quad - cfg.lambda_harm*pH_quad;

%% Score diagnostics
auc_pB_lin = binary_auc(beneficial(valid_lin),pB_lin(valid_lin));
auc_pH_lin = binary_auc(harmful(valid_lin),pH_lin(valid_lin));

auc_pB_quad = binary_auc(beneficial(valid_quad),pB_quad(valid_quad));
auc_pH_quad = binary_auc(harmful(valid_quad),pH_quad(valid_quad));

% Net utility label for rank-correlation only.
net_utility = double(beneficial) - cfg.lambda_harm*double(harmful);

rho_value_lin = spearman_manual( ...
    value_lin(valid_lin),net_utility(valid_lin));

rho_value_quad = spearman_manual( ...
    value_quad(valid_quad),net_utility(valid_quad));

score_diag = table( ...
    ["Linear";"Quadratic"], ...
    [auc_pB_lin;auc_pB_quad], ...
    [auc_pH_lin;auc_pH_quad], ...
    [rho_value_lin;rho_value_quad], ...
    'VariableNames',{ ...
    'model','auc_beneficial','auc_harmful','spearman_with_net_utility'});

writetable(score_diag, ...
    fullfile(out_dir,'loco_score_diagnostics.csv'));

%% Save OOF trial scores
oof_scores = table( ...
    T.cell_id,T.trial_id,beneficial,harmful,neutral, ...
    pB_lin,pH_lin,value_lin,valid_lin, ...
    pB_quad,pH_quad,value_quad,valid_quad, ...
    T.cheap_prominence,T.cheap_entropy,T.cheap_second_to_first, ...
    'VariableNames',{ ...
    'cell_id','trial_id','beneficial','harmful','neutral', ...
    'p_beneficial_linear','p_harmful_linear','value_linear','valid_linear', ...
    'p_beneficial_quadratic','p_harmful_quadratic','value_quadratic','valid_quadratic', ...
    'cheap_prominence','cheap_entropy','cheap_second_to_first'});

writetable(oof_scores, ...
    fullfile(out_dir,'loco_value_scores.csv'));

%% ------------------------------------------------------------------------
% Budget curves
budgets = cfg.budget_grid(:);
nB = numel(budgets);

% Practical LOCO score thresholds are derived from TRAINING cells only.
curve_prom = loco_budget_curve_from_feature( ...
    T.cell_id,T.cheap_prominence,'low', ...
    budgets,cheap,fb,beneficial,harmful);

curve_entropy = loco_budget_curve_from_feature( ...
    T.cell_id,T.cheap_entropy,'high', ...
    budgets,cheap,fb,beneficial,harmful);

curve_linear = loco_model_budget_curve( ...
    T.cell_id,X_linear,beneficial,harmful, ...
    budgets,cheap,fb,cfg.logit_l2,cfg.lambda_harm);

curve_quad = loco_model_budget_curve( ...
    T.cell_id,X_quad,beneficial,harmful, ...
    budgets,cheap,fb,cfg.logit_l2,cfg.lambda_harm);

curve_oracle = oracle_budget_curve( ...
    budgets,cheap,beneficial,harmful);

curve_random = random_expectation_curve( ...
    budgets,cheap_recall,beneficial_rate,harmful_rate);

% Add model name and combine.
curve_prom.policy = repmat("Prominence",height(curve_prom),1);
curve_entropy.policy = repmat("Entropy",height(curve_entropy),1);
curve_linear.policy = repmat("LinearValue",height(curve_linear),1);
curve_quad.policy = repmat("QuadraticValue",height(curve_quad),1);
curve_oracle.policy = repmat("Oracle",height(curve_oracle),1);
curve_random.policy = repmat("RandomExpected",height(curve_random),1);

budget_curves = [ ...
    curve_prom;curve_entropy;curve_linear;curve_quad; ...
    curve_oracle;curve_random];

budget_curves = movevars(budget_curves,'policy','Before',1);

writetable(budget_curves, ...
    fullfile(out_dir,'budget_policy_curves.csv'));

%% ------------------------------------------------------------------------
% Highlighted operating budgets
report_budgets = cfg.report_budgets(:);
nR = numel(report_budgets);

policy_list = ["Prominence","Entropy","LinearValue","QuadraticValue","Oracle","RandomExpected"];

summary_rows = {};

for ip = 1:numel(policy_list)
    pol = policy_list(ip);
    Cp = budget_curves(budget_curves.policy==pol,:);

    for ib = 1:nR
        b = report_budgets(ib);

        [~,ii] = min(abs(Cp.target_budget-b));

        summary_rows(end+1,:) = { ... %#ok<AGROW>
            char(pol), ...
            b, ...
            Cp.actual_trigger_rate(ii), ...
            Cp.policy_recall(ii), ...
            Cp.beneficial_capture(ii), ...
            Cp.benefit_precision(ii), ...
            Cp.harmful_fraction_among_triggers(ii), ...
            Cp.normalized_q_search_budget(ii)};
    end
end

budget_points = cell2table(summary_rows, ...
    'VariableNames',{ ...
    'policy','target_budget','actual_trigger_rate', ...
    'policy_recall','beneficial_capture','benefit_precision', ...
    'harmful_fraction_among_triggers','normalized_q_search_budget'});

writetable(budget_points, ...
    fullfile(out_dir,'reported_budget_points.csv'));

%% ------------------------------------------------------------------------
% Value-score calibration by decile using LOCO quadratic score
calibration = value_calibration_table( ...
    value_quad,valid_quad,beneficial,harmful, ...
    cfg.num_value_bins,cfg.lambda_harm);

writetable(calibration, ...
    fullfile(out_dir,'value_score_calibration.csv'));

%% ------------------------------------------------------------------------
% Cell-level label composition
cells = unique(T.cell_id);
K = numel(cells);

cell_diag = table(cells,'VariableNames',{'cell_id'});
cell_diag.beneficial_rate = nan(K,1);
cell_diag.harmful_rate = nan(K,1);
cell_diag.neutral_rate = nan(K,1);
cell_diag.cheap_recall = nan(K,1);
cell_diag.fallback_recall = nan(K,1);
cell_diag.oracle_recall = nan(K,1);

for ik = 1:K
    mm = T.cell_id==cells(ik);

    cell_diag.beneficial_rate(ik) = mean(beneficial(mm));
    cell_diag.harmful_rate(ik) = mean(harmful(mm));
    cell_diag.neutral_rate(ik) = mean(neutral(mm));

    cell_diag.cheap_recall(ik) = mean(cheap(mm));
    cell_diag.fallback_recall(ik) = mean(fb(mm));
    cell_diag.oracle_recall(ik) = mean(oracle_union(mm));
end

writetable(cell_diag, ...
    fullfile(out_dir,'cell_value_diagnostics.csv'));

%% Console summary
fprintf('================ C2 SCORE DIAGNOSTICS ================\n');
fprintf('Linear benefit AUC       = %.3f\n',auc_pB_lin);
fprintf('Linear harm AUC          = %.3f\n',auc_pH_lin);
fprintf('Linear value Spearman    = %.3f\n',rho_value_lin);
fprintf('Quadratic benefit AUC    = %.3f\n',auc_pB_quad);
fprintf('Quadratic harm AUC       = %.3f\n',auc_pH_quad);
fprintf('Quadratic value Spearman = %.3f\n',rho_value_quad);

fprintf('\n================ C2 BUDGET POINTS ====================\n');

for ib = 1:nR
    b = report_budgets(ib);

    fprintf('\nTarget budget %.0f%%\n',100*b);

    rows = budget_points(abs(budget_points.target_budget-b)<1e-12,:);

    for ir = 1:height(rows)
        fprintf('  %-16s actual=%.3f recall=%.3f capture=%.3f precision=%.3f harm=%.3f\n', ...
            rows.policy{ir}, ...
            rows.actual_trigger_rate(ir), ...
            rows.policy_recall(ir), ...
            rows.beneficial_capture(ir), ...
            rows.benefit_precision(ir), ...
            rows.harmful_fraction_among_triggers(ir));
    end
end

fprintf('======================================================\n');

%% Text summary
fid = fopen(fullfile(out_dir,'summary.txt'),'w');

fprintf(fid,'EXP009-C2 Benefit-Aware Computation Allocation\n');
fprintf(fid,'==============================================\n\n');

fprintf(fid,'Trial composition\n');
fprintf(fid,'-----------------\n');
fprintf(fid,'Trials: %d\n',height(T));
fprintf(fid,'Cheap recall: %.6f\n',cheap_recall);
fprintf(fid,'Fallback recall: %.6f\n',fallback_recall);
fprintf(fid,'Oracle union recall: %.6f\n',oracle_recall);
fprintf(fid,'Beneficial rate: %.6f\n',beneficial_rate);
fprintf(fid,'Harmful rate: %.6f\n',harmful_rate);
fprintf(fid,'Neutral rate: %.6f\n\n',neutral_rate);

fprintf(fid,'LOCO score diagnostics\n');
fprintf(fid,'----------------------\n');
fprintf(fid,'Linear benefit AUC: %.6f\n',auc_pB_lin);
fprintf(fid,'Linear harm AUC: %.6f\n',auc_pH_lin);
fprintf(fid,'Linear value Spearman: %.6f\n',rho_value_lin);
fprintf(fid,'Quadratic benefit AUC: %.6f\n',auc_pB_quad);
fprintf(fid,'Quadratic harm AUC: %.6f\n',auc_pH_quad);
fprintf(fid,'Quadratic value Spearman: %.6f\n\n',rho_value_quad);

fprintf(fid,'Primary practical features\n');
fprintf(fid,'--------------------------\n');
for j = 1:F
    fprintf(fid,'%s\n',feature_names{j});
end

fprintf(fid,'\nHighlighted budget points\n');
fprintf(fid,'-------------------------\n');

for ir = 1:height(budget_points)
    fprintf(fid, ...
        ['%s target=%.3f actual=%.6f recall=%.6f ' ...
         'capture=%.6f precision=%.6f harm=%.6f budget=%.6f\n'], ...
        budget_points.policy{ir}, ...
        budget_points.target_budget(ir), ...
        budget_points.actual_trigger_rate(ir), ...
        budget_points.policy_recall(ir), ...
        budget_points.beneficial_capture(ir), ...
        budget_points.benefit_precision(ir), ...
        budget_points.harmful_fraction_among_triggers(ir), ...
        budget_points.normalized_q_search_budget(ir));
end

fclose(fid);

%% Figures
make_figures( ...
    out_dir,cfg,feature_audit,score_diag, ...
    budget_curves,budget_points,calibration,cell_diag, ...
    cheap_recall,oracle_recall);

%% Save
results = struct();

results.cfg = cfg;
results.feature_names = feature_names;
results.quad_names = quad_names;

results.feature_audit = feature_audit;
results.score_diag = score_diag;
results.oof_scores = oof_scores;

results.budget_curves = budget_curves;
results.budget_points = budget_points;
results.calibration = calibration;
results.cell_diag = cell_diag;

results.cheap_recall = cheap_recall;
results.fallback_recall = fallback_recall;
results.oracle_recall = oracle_recall;

save(fullfile(out_dir,'exp09c2_results.mat'),'results','-v7.3');

fprintf('\nSaved EXP009-C2 outputs to:\n%s\n\n',out_dir);

end

%% ========================================================================
function [Xq,names] = quadratic_feature_map(X,feature_names)
X = double(X);

F = size(X,2);

Xq = X;
names = string(feature_names(:));

% Squares
for j = 1:F
    Xq(:,end+1) = X(:,j).^2; %#ok<AGROW>
    names(end+1,1) = string(feature_names{j}) + "^2"; %#ok<AGROW>
end

% Pairwise interactions
for j = 1:F
    for k = j+1:F
        Xq(:,end+1) = X(:,j).*X(:,k); %#ok<AGROW>
        names(end+1,1) = ...
            string(feature_names{j}) + "*" + string(feature_names{k}); %#ok<AGROW>
    end
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

% Do not regularize intercept.
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

N = numel(cheap);
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
        beneficial_capture(ib) = ...
            min(1,actual/benefit_rate);
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
function calibration = value_calibration_table( ...
    score,valid,beneficial,harmful,num_bins,lambda_harm)

score = score(:);
valid = valid(:);

idx = find(valid & isfinite(score));

s = score(idx);
b = beneficial(idx);
h = harmful(idx);

[ss,ord] = sort(s,'ascend');

idx = idx(ord);
b = b(ord);
h = h(ord);

N = numel(idx);

bin_id = zeros(N,1);

for i = 1:N
    bin_id(i) = min(num_bins,ceil(i*num_bins/N));
end

bin = (1:num_bins).';
count = zeros(num_bins,1);
mean_score = nan(num_bins,1);
beneficial_rate = nan(num_bins,1);
harmful_rate = nan(num_bins,1);
empirical_net_utility = nan(num_bins,1);

for k = 1:num_bins
    mm = bin_id==k;

    count(k) = sum(mm);

    if count(k)>0
        mean_score(k) = mean(ss(mm));
        beneficial_rate(k) = mean(b(mm));
        harmful_rate(k) = mean(h(mm));

        empirical_net_utility(k) = ...
            beneficial_rate(k)-lambda_harm*harmful_rate(k);
    end
end

calibration = table( ...
    bin,count,mean_score,beneficial_rate,harmful_rate, ...
    empirical_net_utility);
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
function make_figures( ...
    out_dir,cfg,feature_audit,score_diag, ...
    budget_curves,budget_points,calibration,cell_diag, ...
    cheap_recall,oracle_recall)

%% Fig 1: Cell label composition
fig = figure('Visible',cfg.figure_visible);

bar([ ...
    cell_diag.beneficial_rate, ...
    cell_diag.harmful_rate, ...
    cell_diag.neutral_rate]);

ylim([0 1]);

xlabel('Selected cell ID');
ylabel('Trial fraction');

title('C2 Fallback Value Composition by Cell');

legend('Beneficial','Harmful','Neutral','Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig01_value_composition_by_cell.png'), ...
    'Resolution',180);

close(fig);

%% Fig 2: Single-feature AUC
fig = figure('Visible',cfg.figure_visible);

Y = [feature_audit.auc_beneficial,feature_audit.auc_harmful];

bar(Y);
ylim([0.45 1]);

xticks(1:height(feature_audit));
xticklabels(feature_audit.feature);
xtickangle(30);

ylabel('Oriented AUC');
title('C2 Practical Feature Audit for Fallback Value');

legend('Beneficial','Harmful','Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig02_feature_value_auc.png'), ...
    'Resolution',180);

close(fig);

%% Fig 3: Learned score diagnostics
fig = figure('Visible',cfg.figure_visible);

Y = [score_diag.auc_beneficial,score_diag.auc_harmful];

bar(Y);
ylim([0.45 1]);

xticks(1:height(score_diag));
xticklabels(score_diag.model);

ylabel('LOCO AUC');
title('C2 LOCO Benefit/Harm Score Diagnostics');

legend('Beneficial','Harmful','Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig03_loco_score_auc.png'), ...
    'Resolution',180);

close(fig);

%% Fig 4: Value calibration
fig = figure('Visible',cfg.figure_visible);

plot(calibration.mean_score, ...
    calibration.empirical_net_utility, ...
    '-o','LineWidth',1.4);

hold on;
plot(calibration.mean_score, ...
    calibration.beneficial_rate, ...
    '-o','LineWidth',1.1);

plot(calibration.mean_score, ...
    calibration.harmful_rate, ...
    '-o','LineWidth',1.1);

xlabel('Mean LOCO quadratic value score');
ylabel('Empirical rate / net utility');

title('C2 Value-Score Calibration');

legend('Net utility','Beneficial rate','Harmful rate', ...
    'Location','best');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig04_value_score_calibration.png'), ...
    'Resolution',180);

close(fig);

%% Common policy colors are left to MATLAB defaults.
policies = ["Prominence","Entropy","LinearValue", ...
    "QuadraticValue","Oracle","RandomExpected"];

%% Fig 5: Beneficial capture vs budget
fig = figure('Visible',cfg.figure_visible);

hold on;

for i = 1:numel(policies)
    Cp = budget_curves(budget_curves.policy==policies(i),:);

    plot(Cp.actual_trigger_rate,Cp.beneficial_capture, ...
        'LineWidth',1.3);
end

xlabel('Actual fallback rate');
ylabel('Capture of all beneficial trials');

title('C2 Beneficial Capture vs Computation Budget');

legend(policies,'Location','southeast');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig05_beneficial_capture_vs_budget.png'), ...
    'Resolution',180);

close(fig);

%% Fig 6: Recall vs budget
fig = figure('Visible',cfg.figure_visible);

hold on;

for i = 1:numel(policies)
    Cp = budget_curves(budget_curves.policy==policies(i),:);

    plot(Cp.normalized_q_search_budget,Cp.policy_recall, ...
        'LineWidth',1.3);
end

scatter(1,cheap_recall,70,'filled');
scatter(1+(oracle_recall-cheap_recall),oracle_recall,80,'filled');

xlabel('Normalized q-search budget');
ylabel('Weak recovery rate');

title('C2 Benefit-Aware Quality-Cost Pareto');

legend([policies,"Cheap","Oracle minimal point"], ...
    'Location','best');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig06_quality_cost_pareto.png'), ...
    'Resolution',180);

close(fig);

%% Fig 7: Benefit precision vs budget
fig = figure('Visible',cfg.figure_visible);

hold on;

for i = 1:numel(policies)
    Cp = budget_curves(budget_curves.policy==policies(i),:);

    plot(Cp.actual_trigger_rate,Cp.benefit_precision, ...
        'LineWidth',1.3);
end

xlabel('Actual fallback rate');
ylabel('Beneficial fraction among triggered trials');

title('C2 Budget Efficiency');

legend(policies,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig07_benefit_precision_vs_budget.png'), ...
    'Resolution',180);

close(fig);

%% Fig 8: Harm fraction vs budget
fig = figure('Visible',cfg.figure_visible);

hold on;

for i = 1:numel(policies)
    Cp = budget_curves(budget_curves.policy==policies(i),:);

    plot(Cp.actual_trigger_rate, ...
        Cp.harmful_fraction_among_triggers, ...
        'LineWidth',1.3);
end

xlabel('Actual fallback rate');
ylabel('Harmful fraction among triggered trials');

title('C2 Harmful Allocation vs Budget');

legend(policies,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig08_harmful_allocation_vs_budget.png'), ...
    'Resolution',180);

close(fig);

%% Fig 9: highlighted 25% budget comparison
target = 0.25;

rows = budget_points(abs(budget_points.target_budget-target)<1e-12,:);

fig = figure('Visible',cfg.figure_visible);

bar(rows.policy_recall);
ylim([0 1]);

xticks(1:height(rows));
xticklabels(rows.policy);
xtickangle(30);

ylabel('Weak recovery rate');
title('C2 Policy Comparison at 25% Target Budget');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig09_policy_comparison_25pct.png'), ...
    'Resolution',180);

close(fig);

end
