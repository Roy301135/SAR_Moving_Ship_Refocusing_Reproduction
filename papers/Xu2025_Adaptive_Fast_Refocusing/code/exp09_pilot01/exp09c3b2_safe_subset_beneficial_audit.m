function results = exp09c3b2_safe_subset_beneficial_audit()
%EXP09C3B2_SAFE_SUBSET_BENEFICIAL_AUDIT
% EXP009 / Pilot-01 / C3-B2
%
% Safe-Subset Beneficial Opportunity Audit
%
% -------------------------------------------------------------------------
% Why this experiment exists
% -------------------------------------------------------------------------
% C3-B1.3 established:
%   - Harm-aware allocation is real and useful.
%   - However, even perfect Harmful avoidance explains only a minority of
%     the remaining TrialOracle gap.
%
% Therefore the next bottleneck is:
%
%   "Among safe / non-harmful trials, which ones are actually Beneficial?"
%
% Beneficial is decomposed exactly as:
%
%   Beneficial
%       = (~CheapSuccess) AND FallbackSuccess
%
% This motivates three tasks:
%
%   Task A: CheapFailure
%       Can we tell that the cheap branch is wrong?
%
%   Task B: Rescueability
%       Conditional on CheapFailure, can we tell whether fallback succeeds?
%
%   Task C: Beneficial
%       Can a direct model predict the joint event?
%
% We then compare:
%
%   pB_direct
%
% versus
%
%   pB_factor
%       = p(CheapFailure|X)
%       * p(FallbackSuccess|CheapFailure,X)
%
% and combine each with the fixed Harm veto learned in C3-B1.3.
%
% -------------------------------------------------------------------------
% Scientific caution
% -------------------------------------------------------------------------
% This remains a mechanism/policy pilot.
% q_strong and the signal-generation setup are still inherited from the
% controlled EXP009 synthetic environment.
%
% Run:
%   results = exp09c3b2_safe_subset_beneficial_audit;

cfg = config_exp09c3b2();

%% Paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.input_dir_c3b1_2)
    input_dir_c3b1_2 = fullfile( ...
        paper_root,'results','exp09_pilot01', ...
        'exp09c3b1_2_mechanism_observable_audit');
else
    input_dir_c3b1_2 = cfg.input_dir_c3b1_2;
end

if isempty(cfg.input_dir_c3b1_3)
    input_dir_c3b1_3 = fullfile( ...
        paper_root,'results','exp09_pilot01', ...
        'exp09c3b1_3_harm_aware_fallback');
else
    input_dir_c3b1_3 = cfg.input_dir_c3b1_3;
end

if isempty(cfg.output_dir)
    output_dir = fullfile( ...
        paper_root,'results','exp09_pilot01', ...
        'exp09c3b2_safe_subset_beneficial_audit');
else
    output_dir = cfg.output_dir;
end

if ~exist(output_dir,'dir')
    mkdir(output_dir);
end

fprintf('\n============================================================\n');
fprintf(' EXP009-C3-B2 / Safe-Subset Beneficial Opportunity Audit\n');
fprintf('============================================================\n');
fprintf('C3-B1.2 input: %s\n',input_dir_c3b1_2);
fprintf('C3-B1.3 input: %s\n',input_dir_c3b1_3);
fprintf('Output       : %s\n\n',output_dir);

%% Load rich trial banks
train_smooth = read_trial_bank( ...
    fullfile(input_dir_c3b1_2,'train_rich_trials_smooth.csv'));

train_abrupt = read_trial_bank( ...
    fullfile(input_dir_c3b1_2,'train_rich_trials_abrupt.csv'));

test_smooth = read_trial_bank( ...
    fullfile(input_dir_c3b1_2,'test_rich_trials_smooth.csv'));

test_abrupt = read_trial_bank( ...
    fullfile(input_dir_c3b1_2,'test_rich_trials_abrupt.csv'));

validate_required_columns(train_smooth,cfg);
validate_required_columns(train_abrupt,cfg);
validate_required_columns(test_smooth,cfg);
validate_required_columns(test_abrupt,cfg);

%% Attach exact task labels
train_smooth = attach_task_labels(train_smooth);
train_abrupt = attach_task_labels(train_abrupt);
test_smooth = attach_task_labels(test_smooth);
test_abrupt = attach_task_labels(test_abrupt);

%% Reconstruct cross-fitted physical-state prior
[train_smooth,test_smooth,state_smooth] = ...
    attach_crossfit_state_prior( ...
        train_smooth,test_smooth,cfg);

[train_abrupt,test_abrupt,state_abrupt] = ...
    attach_crossfit_state_prior( ...
        train_abrupt,test_abrupt,cfg);

train_smooth.regime = repmat("Smooth",height(train_smooth),1);
train_abrupt.regime = repmat("Abrupt",height(train_abrupt),1);
test_smooth.regime = repmat("Smooth",height(test_smooth),1);
test_abrupt.regime = repmat("Abrupt",height(test_abrupt),1);

train_all = [train_smooth;train_abrupt];
test_all = [test_smooth;test_abrupt];

%% State z-score learned on TRAIN only
state_mu = mean(train_all.state_prior,'omitnan');
state_sigma = std(train_all.state_prior,0,'omitnan');

if ~isfinite(state_sigma) || state_sigma<1e-12
    state_sigma = 1;
end

train_all.state_z = ...
    (train_all.state_prior-state_mu)/state_sigma;
test_all.state_z = ...
    (test_all.state_prior-state_mu)/state_sigma;

train_smooth.state_z = ...
    (train_smooth.state_prior-state_mu)/state_sigma;
train_abrupt.state_z = ...
    (train_abrupt.state_prior-state_mu)/state_sigma;
test_smooth.state_z = ...
    (test_smooth.state_prior-state_mu)/state_sigma;
test_abrupt.state_z = ...
    (test_abrupt.state_prior-state_mu)/state_sigma;

%% Read C3-B1.3 fixed harm-veto threshold
[veto_threshold,c3b1_3_selected] = ...
    read_c3b1_3_threshold( ...
        input_dir_c3b1_3,cfg);

fprintf('Fixed C3-B1.3 harm-veto threshold = %.8f\n\n', ...
    veto_threshold);

%% OOF predictions for TRAIN
[oof,fold_table] = make_oof_predictions( ...
    train_smooth,train_abrupt,cfg);

writetable(fold_table, ...
    fullfile(output_dir,'oof_fold_assignment.csv'));

%% Fit full TRAIN models and predict TEST
models = fit_full_models(train_all,cfg);

pred_test_all = predict_all_models( ...
    models,test_all,cfg);

pred_test_smooth = subset_prediction_struct( ...
    pred_test_all,test_all.regime=="Smooth");

pred_test_abrupt = subset_prediction_struct( ...
    pred_test_all,test_all.regime=="Abrupt");

%% ------------------------------------------------------------------------
% 0) Lambda-boundary sanity check from C3-B1.3
lambda_sanity = run_lambda_boundary_sanity( ...
    train_all,oof,cfg);

writetable(lambda_sanity, ...
    fullfile(output_dir,'lambda_boundary_sanity.csv'));

[~,best_lambda_idx] = max(lambda_sanity.policy_recall);
best_lambda_sanity = ...
    lambda_sanity.lambda(best_lambda_idx);

fprintf('Extended lambda sanity optimum = %.4f\n\n', ...
    best_lambda_sanity);

%% ------------------------------------------------------------------------
% 1) Feature-group task audit
group_audit = build_feature_group_task_audit( ...
    train_all,test_smooth,test_abrupt,cfg);

writetable(group_audit, ...
    fullfile(output_dir,'feature_group_task_audit.csv'));

%% ------------------------------------------------------------------------
% 2) Direct vs factorized Beneficial observability
direct_factor_audit = build_direct_factor_audit( ...
    train_all,oof, ...
    test_smooth,pred_test_smooth, ...
    test_abrupt,pred_test_abrupt, ...
    veto_threshold);

writetable(direct_factor_audit, ...
    fullfile(output_dir,'direct_vs_factorized_beneficial_audit.csv'));

%% ------------------------------------------------------------------------
% 3) Safe-subset composition
safe_subset_composition = build_safe_subset_composition( ...
    test_smooth,pred_test_smooth, ...
    test_abrupt,pred_test_abrupt, ...
    veto_threshold);

writetable(safe_subset_composition, ...
    fullfile(output_dir,'safe_subset_composition.csv'));

%% ------------------------------------------------------------------------
% 4) Build policy scores
score_test_all = build_policy_scores( ...
    test_all,pred_test_all, ...
    veto_threshold,cfg);

score_test_smooth = subset_score_struct( ...
    score_test_all,test_all.regime=="Smooth");

score_test_abrupt = subset_score_struct( ...
    score_test_all,test_all.regime=="Abrupt");

%% ------------------------------------------------------------------------
% 5) Matched-budget policy curves
policy_curves = table();

for ir = 1:2
    if ir==1
        T = test_smooth;
        Scores = score_test_smooth;
        regime = "Smooth";
    else
        T = test_abrupt;
        Scores = score_test_abrupt;
        regime = "Abrupt";
    end

    C = evaluate_all_policy_curves(T,Scores,cfg);
    C.regime = repmat(regime,height(C),1);
    C = movevars(C,'regime','Before',1);

    policy_curves = [policy_curves;C]; %#ok<AGROW>
end

writetable(policy_curves, ...
    fullfile(output_dir,'policy_curves.csv'));

reported = extract_reported_points( ...
    policy_curves,cfg.report_budgets);

writetable(reported, ...
    fullfile(output_dir,'reported_budget_points.csv'));

primary = reported( ...
    abs(reported.target_budget-cfg.primary_budget)<1e-12,:);

writetable(primary, ...
    fullfile(output_dir,'primary_25pct_policy_comparison.csv'));

%% ------------------------------------------------------------------------
% 6) Beneficial bottleneck decomposition
bottleneck = build_bottleneck_decomposition( ...
    test_smooth,pred_test_smooth, ...
    test_abrupt,pred_test_abrupt, ...
    direct_factor_audit,primary, ...
    veto_threshold);

writetable(bottleneck, ...
    fullfile(output_dir,'beneficial_bottleneck_decomposition.csv'));

%% ------------------------------------------------------------------------
% 7) Decision summary
decision = build_decision_summary( ...
    group_audit,direct_factor_audit, ...
    safe_subset_composition,primary, ...
    bottleneck,best_lambda_sanity, ...
    c3b1_3_selected);

writetable(decision, ...
    fullfile(output_dir,'decision_summary.csv'));

%% State-prior reproducibility
state_smooth.regime = repmat("Smooth",height(state_smooth),1);
state_abrupt.regime = repmat("Abrupt",height(state_abrupt),1);

state_summary = [state_smooth;state_abrupt];
state_summary = movevars(state_summary,'regime','Before',1);

writetable(state_summary, ...
    fullfile(output_dir,'state_prior_reproducibility.csv'));

%% Console
fprintf('\n================ FEATURE-GROUP TASK AUDIT ===================\n');
disp(group_audit);

fprintf('\n================ DIRECT VS FACTORIZED =======================\n');
disp(direct_factor_audit);

fprintf('\n================ 25%% POLICY COMPARISON ======================\n');
disp(primary(:,{ ...
    'regime','policy','policy_recall', ...
    'beneficial_capture','benefit_precision', ...
    'harmful_fraction_among_triggers'}));

fprintf('\n================ BENEFICIAL BOTTLENECK ======================\n');
disp(bottleneck);

fprintf('\n================ DECISION SUMMARY ===========================\n');
disp(decision);
fprintf('=============================================================\n');

%% Summary
write_summary( ...
    output_dir,cfg, ...
    veto_threshold,best_lambda_sanity, ...
    group_audit,direct_factor_audit, ...
    safe_subset_composition,primary, ...
    bottleneck,decision);

%% Figures
make_figures( ...
    output_dir,cfg, ...
    veto_threshold,lambda_sanity, ...
    group_audit,direct_factor_audit, ...
    safe_subset_composition,policy_curves, ...
    primary,bottleneck, ...
    test_smooth,pred_test_smooth, ...
    test_abrupt,pred_test_abrupt);

%% Save
results = struct();
results.cfg = cfg;
results.models = models;
results.fold_table = fold_table;
results.veto_threshold = veto_threshold;
results.lambda_sanity = lambda_sanity;
results.group_audit = group_audit;
results.direct_factor_audit = direct_factor_audit;
results.safe_subset_composition = safe_subset_composition;
results.policy_curves = policy_curves;
results.primary = primary;
results.bottleneck = bottleneck;
results.decision = decision;
results.state_summary = state_summary;

save(fullfile(output_dir,'exp09c3b2_results.mat'), ...
    'results','-v7.3');

fprintf('\nSaved C3-B2 outputs to:\n%s\n\n',output_dir);

end

%% ========================================================================
function T = read_trial_bank(filename)

if ~exist(filename,'file')
    error('Missing C3-B1.2 trial bank:\n%s',filename);
end

T = readtable(filename);

label_names = { ...
    'cheap_success','fallback_success', ...
    'beneficial','harmful'};

for i = 1:numel(label_names)
    name = label_names{i};

    if ismember(name,T.Properties.VariableNames)
        v = T.(name);
        v = double(v(:));
        T.(name) = logical(v);
    end
end

vars = T.Properties.VariableNames;

for i = 1:numel(vars)
    name = vars{i};
    v = T.(name);

    if isnumeric(v) || islogical(v)
        if isvector(v) && numel(v)==height(T)
            T.(name) = v(:);
        end
    end
end

end

%% ========================================================================
function validate_required_columns(T,cfg)

required = { ...
    'sequence_id','line_index', ...
    'weak_ratio','signed_sep', ...
    'cheap_success','fallback_success', ...
    'beneficial','harmful','signed_value', ...
    'allocation_tiebreak'};

required = [required,cfg.all_observable_features];

vars = T.Properties.VariableNames;

for i = 1:numel(required)
    if ~ismember(required{i},vars)
        error('Required C3-B1.2 column missing: %s',required{i});
    end
end

end

%% ========================================================================
function T = attach_task_labels(T)

T.cheap_failure = ~logical(T.cheap_success(:));
T.rescue_success = logical(T.fallback_success(:));

% Exact identity check:
beneficial_rebuilt = ...
    T.cheap_failure & T.rescue_success;

if any(beneficial_rebuilt ~= logical(T.beneficial(:)))
    error(['Beneficial identity mismatch: expected ' ...
           '(~cheap_success) & fallback_success.']);
end

harmful_rebuilt = ...
    logical(T.cheap_success(:)) & ...
    ~logical(T.fallback_success(:));

if any(harmful_rebuilt ~= logical(T.harmful(:)))
    error(['Harmful identity mismatch: expected ' ...
           'cheap_success & (~fallback_success).']);
end

T.neutral = ...
    ~(logical(T.beneficial(:)) | logical(T.harmful(:)));

end

%% ========================================================================
function [Ttrain,Ttest,S] = attach_crossfit_state_prior( ...
    Ttrain,Ttest,cfg)

lines = unique(Ttrain.line_index).';
seqs = unique(Ttrain.sequence_id).';

L = numel(lines);
M = numel(seqs);

if M<2
    error('Cross-fitted state prior requires >=2 TRAIN sequences.');
end

Y = nan(M,L);

for is = 1:M
    sid = seqs(is);

    for ik = 1:L
        k = lines(ik);

        idx = find( ...
            Ttrain.sequence_id==sid & ...
            Ttrain.line_index==k);

        if numel(idx)~=1
            error(['Expected one TRAIN row for sequence %g line %g; ' ...
                   'found %d.'],sid,k,numel(idx));
        end

        Y(is,ik) = double(Ttrain.signed_value(idx));
    end
end

train_raw = mean(Y,1).';
train_full = moving_average_shrink( ...
    train_raw,cfg.state_utility_smooth_window);

test_raw = nan(L,1);

for ik = 1:L
    k = lines(ik);
    mm = Ttest.line_index==k;

    test_raw(ik) = mean( ...
        double(Ttest.signed_value(mm)),'omitnan');
end

test_utility = moving_average_shrink( ...
    test_raw,cfg.state_utility_smooth_window);

Ttrain.state_prior = nan(height(Ttrain),1);

sumY = sum(Y,1);

for is = 1:M
    sid = seqs(is);

    cf_raw = ((sumY-Y(is,:))/(M-1)).';
    cf_smooth = moving_average_shrink( ...
        cf_raw,cfg.state_utility_smooth_window);

    for ik = 1:L
        k = lines(ik);

        idx = find( ...
            Ttrain.sequence_id==sid & ...
            Ttrain.line_index==k);

        Ttrain.state_prior(idx) = cf_smooth(ik);
    end
end

Ttest.state_prior = nan(height(Ttest),1);

for ik = 1:L
    k = lines(ik);
    mm = Ttest.line_index==k;

    Ttest.state_prior(mm) = train_full(ik);
end

line_index = lines(:);
weak_ratio = nan(L,1);
signed_sep = nan(L,1);

for ik = 1:L
    k = lines(ik);
    mm = Ttrain.line_index==k;

    weak_ratio(ik) = scalar_unique( ...
        Ttrain.weak_ratio(mm), ...
        sprintf('weak ratio line %d',k));

    signed_sep(ik) = scalar_unique( ...
        Ttrain.signed_sep(mm), ...
        sprintf('signed separation line %d',k));
end

train_state_prior_full = train_full;
test_state_utility = test_utility;

S = table( ...
    line_index,weak_ratio,signed_sep, ...
    train_raw,train_state_prior_full, ...
    test_raw,test_state_utility, ...
    'VariableNames',{ ...
    'line_index','weak_ratio','signed_sep', ...
    'train_utility_raw','train_state_prior_full', ...
    'test_utility_raw','test_state_utility'});

end

%% ========================================================================
function y = moving_average_shrink(x,w)

x = double(x(:));
w = max(1,round(w));

N = numel(x);
y = nan(N,1);

left = floor((w-1)/2);
right = w-1-left;

for i = 1:N
    i1 = max(1,i-left);
    i2 = min(N,i+right);

    y(i) = mean(x(i1:i2),'omitnan');
end

end

%% ========================================================================
function v = scalar_unique(x,label)

x = double(x(:));
x = x(isfinite(x));

if isempty(x)
    error('No finite values for %s.',label);
end

v = x(1);

if any(abs(x-v)>1e-12)
    error('%s is not constant.',label);
end

end

%% ========================================================================
function [threshold,Tsel] = read_c3b1_3_threshold(input_dir,cfg)

filename = fullfile( ...
    input_dir,'selected_hyperparameters.csv');

if ~exist(filename,'file')
    if cfg.require_c3b1_3_threshold
        error(['Missing C3-B1.3 selected hyperparameter file:\n%s\n' ...
               'Run C3-B1.3 first.'],filename);
    else
        threshold = Inf;
        Tsel = table();
        return;
    end
end

Tsel = readtable(filename);

if ~ismember('best_veto_threshold', ...
        Tsel.Properties.VariableNames)
    error('best_veto_threshold missing from C3-B1.3 file.');
end

v = double(Tsel.best_veto_threshold(:));
v = v(isfinite(v));

if numel(v)~=1
    error('Expected one finite best_veto_threshold.');
end

threshold = v(1);

end

%% ========================================================================
function [oof,fold_table] = make_oof_predictions( ...
    train_smooth,train_abrupt,cfg)

T = [train_smooth;train_abrupt];

seqs = unique(T.sequence_id).';

rng(cfg.seed+3000,'twister');

perm = seqs(randperm(numel(seqs)));

fold_id_seq = zeros(numel(seqs),1);

for i = 1:numel(perm)
    sid = perm(i);
    orig = find(seqs==sid,1);

    fold_id_seq(orig) = mod(i-1,cfg.num_folds)+1;
end

fold_id = nan(height(T),1);

for i = 1:numel(seqs)
    fold_id(T.sequence_id==seqs(i)) = ...
        fold_id_seq(i);
end

if any(~isfinite(fold_id))
    error('OOF fold assignment failed.');
end

pH_morph = nan(height(T),1);
pB_direct = nan(height(T),1);
pCheapFail = nan(height(T),1);
pRescueGivenFail = nan(height(T),1);

feature_names = [{'state_prior'},cfg.all_observable_features];

for k = 1:cfg.num_folds

    is_val = fold_id==k;
    is_fit = ~is_val;

    Tfit = T(is_fit,:);
    Tval = T(is_val,:);

    % Harm model: morphology only, matching C3-B1.3.
    Xm_fit = table_to_matrix( ...
        Tfit,cfg.morphology_features);

    Xm_val = table_to_matrix( ...
        Tval,cfg.morphology_features);

    mdlH = fit_binary_model( ...
        Xm_fit,Tfit.harmful,cfg);

    pH_morph(is_val) = ...
        predict_binary_model(mdlH,Xm_val);

    % Direct Beneficial model.
    X_fit = table_to_matrix(Tfit,feature_names);
    X_val = table_to_matrix(Tval,feature_names);

    mdlB = fit_binary_model( ...
        X_fit,Tfit.beneficial,cfg);

    pB_direct(is_val) = ...
        predict_binary_model(mdlB,X_val);

    % Cheap-failure model.
    mdlC = fit_binary_model( ...
        X_fit,Tfit.cheap_failure,cfg);

    pCheapFail(is_val) = ...
        predict_binary_model(mdlC,X_val);

    % Rescueability model:
    % train only where Cheap actually failed.
    mm_fail_fit = logical(Tfit.cheap_failure(:));

    if sum(mm_fail_fit)<10
        error('Too few CheapFailure training rows in fold %d.',k);
    end

    Xr_fit = table_to_matrix( ...
        Tfit(mm_fail_fit,:),feature_names);

    yr_fit = ...
        Tfit.rescue_success(mm_fail_fit);

    mdlR = fit_binary_model( ...
        Xr_fit,yr_fit,cfg);

    pRescueGivenFail(is_val) = ...
        predict_binary_model(mdlR,X_val);
end

if any(~isfinite(pH_morph)) || ...
   any(~isfinite(pB_direct)) || ...
   any(~isfinite(pCheapFail)) || ...
   any(~isfinite(pRescueGivenFail))
    error('OOF prediction bank contains non-finite values.');
end

oof = struct();
oof.pH_morph = pH_morph;
oof.pB_direct = pB_direct;
oof.pCheapFail = pCheapFail;
oof.pRescueGivenFail = pRescueGivenFail;
oof.pB_factor = ...
    pCheapFail .* pRescueGivenFail;

fold_table = table( ...
    seqs(:),fold_id_seq(:), ...
    'VariableNames',{'sequence_id','fold_id'});

end

%% ========================================================================
function models = fit_full_models(T,cfg)

feature_names = [{'state_prior'},cfg.all_observable_features];

% Harm morphology.
Xm = table_to_matrix(T,cfg.morphology_features);

models.harmMorph = fit_binary_model( ...
    Xm,T.harmful,cfg);

% Direct Beneficial.
X = table_to_matrix(T,feature_names);

models.directBeneficial = fit_binary_model( ...
    X,T.beneficial,cfg);

% Cheap failure.
models.cheapFailure = fit_binary_model( ...
    X,T.cheap_failure,cfg);

% Rescueability conditional on CheapFailure.
mm_fail = logical(T.cheap_failure(:));

Xr = table_to_matrix(T(mm_fail,:),feature_names);
yr = T.rescue_success(mm_fail);

models.rescueGivenFail = fit_binary_model( ...
    Xr,yr,cfg);

end

%% ========================================================================
function P = predict_all_models(models,T,cfg)

feature_names = [{'state_prior'},cfg.all_observable_features];

Xm = table_to_matrix(T,cfg.morphology_features);
X = table_to_matrix(T,feature_names);

P = struct();

P.pH_morph = predict_binary_model( ...
    models.harmMorph,Xm);

P.pB_direct = predict_binary_model( ...
    models.directBeneficial,X);

P.pCheapFail = predict_binary_model( ...
    models.cheapFailure,X);

P.pRescueGivenFail = predict_binary_model( ...
    models.rescueGivenFail,X);

P.pB_factor = ...
    P.pCheapFail .* P.pRescueGivenFail;

end

%% ========================================================================
function P2 = subset_prediction_struct(P,mask)

mask = logical(mask(:));

names = fieldnames(P);

for i = 1:numel(names)
    name = names{i};
    v = P.(name);

    if isvector(v) && numel(v)==numel(mask)
        P2.(name) = v(mask);
    else
        error('Prediction field %s has unexpected dimensions.',name);
    end
end

end

%% ========================================================================
function L = run_lambda_boundary_sanity(T,oof,cfg)

lambda = cfg.lambda_sanity_grid(:);

policy_recall = nan(size(lambda));
beneficial_capture = nan(size(lambda));
harmful_fraction = nan(size(lambda));

for i = 1:numel(lambda)
    score = ...
        double(T.state_z(:)) - ...
        lambda(i)*double(oof.pH_morph(:));

    M = evaluate_policy_at_budget( ...
        T,score,cfg.primary_budget);

    policy_recall(i) = M.policy_recall;
    beneficial_capture(i) = M.beneficial_capture;
    harmful_fraction(i) = M.harmful_fraction_among_triggers;
end

L = table( ...
    lambda,policy_recall, ...
    beneficial_capture,harmful_fraction);

end

%% ========================================================================
function G = build_feature_group_task_audit( ...
    train_all,test_smooth,test_abrupt,cfg)

group_names = string(cfg.feature_group_names(:));

rows = {};

for ig = 1:numel(group_names)

    gname = group_names(ig);
    feature_names = feature_group_features( ...
        char(gname),cfg);

    Xtr = table_to_matrix(train_all,feature_names);

    % Three models:
    % Direct Beneficial, CheapFailure, Rescueability|CheapFailure.
    mdlB = fit_binary_model( ...
        Xtr,train_all.beneficial,cfg);

    mdlC = fit_binary_model( ...
        Xtr,train_all.cheap_failure,cfg);

    mm_fail_tr = logical(train_all.cheap_failure(:));

    Xr_tr = table_to_matrix( ...
        train_all(mm_fail_tr,:),feature_names);

    mdlR = fit_binary_model( ...
        Xr_tr,train_all.rescue_success(mm_fail_tr),cfg);

    for ir = 1:2
        if ir==1
            Tte = test_smooth;
            regime = 'Smooth';
        else
            Tte = test_abrupt;
            regime = 'Abrupt';
        end

        Xte = table_to_matrix(Tte,feature_names);

        pB = predict_binary_model(mdlB,Xte);
        pC = predict_binary_model(mdlC,Xte);
        pR = predict_binary_model(mdlR,Xte);

        aucB = binary_auc(Tte.beneficial,pB);
        aucC = binary_auc(Tte.cheap_failure,pC);

        [wB,nWB] = weighted_within_line_auc( ...
            Tte,pB,Tte.beneficial);

        [wC,nWC] = weighted_within_line_auc( ...
            Tte,pC,Tte.cheap_failure);

        mm_fail_te = logical(Tte.cheap_failure(:));

        aucR = binary_auc( ...
            Tte.rescue_success(mm_fail_te), ...
            pR(mm_fail_te));

        [wR,nWR] = weighted_within_line_auc( ...
            Tte(mm_fail_te,:), ...
            pR(mm_fail_te), ...
            Tte.rescue_success(mm_fail_te));

        rows(end+1,:) = { ... %#ok<AGROW>
            char(gname),regime, ...
            aucB,wB,nWB, ...
            aucC,wC,nWC, ...
            aucR,wR,nWR};
    end
end

G = cell2table(rows, ...
    'VariableNames',{ ...
    'feature_group','regime', ...
    'beneficial_pooled_auc', ...
    'beneficial_within_line_auc', ...
    'beneficial_valid_lines', ...
    'cheapfailure_pooled_auc', ...
    'cheapfailure_within_line_auc', ...
    'cheapfailure_valid_lines', ...
    'rescueability_pooled_auc', ...
    'rescueability_within_line_auc', ...
    'rescueability_valid_lines'});

end

%% ========================================================================
function names = feature_group_features(group_name,cfg)

switch group_name
    case 'StateOnly'
        names = {'state_prior'};

    case 'MorphologyOnly'
        names = cfg.morphology_features;

    case 'StrongCompetitionOnly'
        names = cfg.strong_competition_features;

    case 'SubapertureOnly'
        names = cfg.subaperture_features;

    case 'AllObservable'
        names = cfg.all_observable_features;

    case 'StateAll'
        names = [{'state_prior'},cfg.all_observable_features];

    otherwise
        error('Unknown feature group: %s',group_name);
end

end

%% ========================================================================
function A = build_direct_factor_audit( ...
    train_all,oof, ...
    test_smooth,pred_smooth, ...
    test_abrupt,pred_abrupt, ...
    veto_threshold)

rows = {};

% OOF Train combined
rows = append_direct_factor_rows( ...
    rows,train_all,oof, ...
    'OOF-Train','Combined',veto_threshold);

% TEST Smooth
rows = append_direct_factor_rows( ...
    rows,test_smooth,pred_smooth, ...
    'Test','Smooth',veto_threshold);

% TEST Abrupt
rows = append_direct_factor_rows( ...
    rows,test_abrupt,pred_abrupt, ...
    'Test','Abrupt',veto_threshold);

A = cell2table(rows, ...
    'VariableNames',{ ...
    'split','regime','subset','score_type', ...
    'pooled_beneficial_auc', ...
    'within_line_beneficial_auc', ...
    'valid_within_lines', ...
    'n_trials','beneficial_prevalence'});

end

%% ========================================================================
function rows = append_direct_factor_rows( ...
    rows,T,P,split,regime,veto_threshold)

subsets = { ...
    'All',true(height(T),1); ...
    'OracleSafe',~logical(T.harmful(:)); ...
    'PracticalSafe',double(P.pH_morph(:))<=veto_threshold};

scores = { ...
    'Direct',double(P.pB_direct(:)); ...
    'Factorized',double(P.pB_factor(:)); ...
    'CheapFailureOnly',double(P.pCheapFail(:)); ...
    'RescueGivenFailOnly',double(P.pRescueGivenFail(:))};

for is = 1:size(subsets,1)

    sname = subsets{is,1};
    mask = logical(subsets{is,2});

    for it = 1:size(scores,1)
        score_name = scores{it,1};
        score = scores{it,2};

        y = logical(T.beneficial(mask));
        s = score(mask);

        aucP = binary_auc(y,s);

        [aucW,nValid] = weighted_within_line_auc( ...
            T(mask,:),s,y);

        rows(end+1,:) = { ... %#ok<AGROW>
            split,regime,sname,score_name, ...
            aucP,aucW,nValid, ...
            sum(mask),mean(double(y))};
    end
end

end

%% ========================================================================
function C = build_safe_subset_composition( ...
    test_smooth,pred_smooth, ...
    test_abrupt,pred_abrupt, ...
    veto_threshold)

rows = {};

for ir = 1:2
    if ir==1
        T = test_smooth;
        P = pred_smooth;
        regime = 'Smooth';
    else
        T = test_abrupt;
        P = pred_abrupt;
        regime = 'Abrupt';
    end

    subsets = { ...
        'All',true(height(T),1); ...
        'OracleSafe',~logical(T.harmful(:)); ...
        'PracticalSafe',double(P.pH_morph(:))<=veto_threshold};

    for is = 1:size(subsets,1)
        sname = subsets{is,1};
        mask = logical(subsets{is,2});

        n = sum(mask);

        if n==0
            continue;
        end

        rows(end+1,:) = { ... %#ok<AGROW>
            regime,sname,n, ...
            mean(double(T.beneficial(mask))), ...
            mean(double(T.harmful(mask))), ...
            mean(double(T.neutral(mask))), ...
            mean(double(T.cheap_failure(mask))), ...
            mean(double(T.fallback_success(mask)))};
    end
end

C = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','subset','n_trials', ...
    'beneficial_rate','harmful_rate','neutral_rate', ...
    'cheap_failure_rate','fallback_success_rate'});

end

%% ========================================================================
function Scores = build_policy_scores(T,P,veto_threshold,cfg)

state = double(T.state_z(:));
pBdirect = double(P.pB_direct(:));
pBfactor = double(P.pB_factor(:));
pH = double(P.pH_morph(:));

risk = pH>veto_threshold;

Scores = struct();

Scores.StateOnly = state;
Scores.DirectBeneficial = pBdirect;
Scores.FactorizedBeneficial = pBfactor;

Scores.DirectBeneficialHarmVeto = ...
    pBdirect - cfg.veto_rank_penalty*double(risk);

Scores.FactorizedBeneficialHarmVeto = ...
    pBfactor - cfg.veto_rank_penalty*double(risk);

Scores.OracleSafeFactorized = ...
    pBfactor - ...
    cfg.veto_rank_penalty*double(T.harmful(:));

neutral = ~(logical(T.beneficial(:)) | logical(T.harmful(:)));

Scores.TrialOracle = ...
    2*double(T.beneficial(:)) + ...
    1*double(neutral(:)) + ...
    1e-6*state;

end

%% ========================================================================
function S2 = subset_score_struct(S,mask)

mask = logical(mask(:));
names = fieldnames(S);

for i = 1:numel(names)
    name = names{i};
    v = S.(name);

    if isvector(v) && numel(v)==numel(mask)
        S2.(name) = v(mask);
    else
        error('Score field %s has unexpected dimensions.',name);
    end
end

end

%% ========================================================================
function C = evaluate_all_policy_curves(T,Scores,cfg)

policies = [ ...
    "StateOnly", ...
    "DirectBeneficial", ...
    "FactorizedBeneficial", ...
    "DirectBeneficialHarmVeto", ...
    "FactorizedBeneficialHarmVeto", ...
    "OracleSafeFactorized", ...
    "TrialOracle", ...
    "RandomExpected"];

C = table();

for ip = 1:numel(policies)
    policy = policies(ip);

    if policy=="RandomExpected"
        Cp = random_expected_curve(T,cfg.budget_grid);
    else
        score = Scores.(char(policy));
        Cp = exact_budget_curve(T,score,cfg.budget_grid);
    end

    Cp.policy = repmat(policy,height(Cp),1);
    Cp = movevars(Cp,'policy','Before',1);

    C = [C;Cp]; %#ok<AGROW>
end

end

%% ========================================================================
function C = exact_budget_curve(T,score,budgets)

score = double(score(:));
budgets = double(budgets(:));

nB = numel(budgets);

target_budget = budgets;
actual_trigger_rate = nan(nB,1);
policy_recall = nan(nB,1);
beneficial_capture = nan(nB,1);
benefit_precision = nan(nB,1);
harmful_fraction_among_triggers = nan(nB,1);
net_utility_among_triggers = nan(nB,1);
normalized_q_search_budget = nan(nB,1);

for ib = 1:nB
    M = evaluate_policy_at_budget( ...
        T,score,budgets(ib));

    actual_trigger_rate(ib) = M.actual_trigger_rate;
    policy_recall(ib) = M.policy_recall;
    beneficial_capture(ib) = M.beneficial_capture;
    benefit_precision(ib) = M.benefit_precision;
    harmful_fraction_among_triggers(ib) = ...
        M.harmful_fraction_among_triggers;
    net_utility_among_triggers(ib) = ...
        M.net_utility_among_triggers;
    normalized_q_search_budget(ib) = ...
        1+M.actual_trigger_rate;
end

C = table( ...
    target_budget,actual_trigger_rate, ...
    policy_recall,beneficial_capture, ...
    benefit_precision, ...
    harmful_fraction_among_triggers, ...
    net_utility_among_triggers, ...
    normalized_q_search_budget);

end

%% ========================================================================
function M = evaluate_policy_at_budget(T,score,budget)

trigger = exact_topk_trigger( ...
    score,budget,T.allocation_tiebreak);

cheap = logical(T.cheap_success(:));
fallback = logical(T.fallback_success(:));

out = cheap;
out(trigger) = fallback(trigger);

beneficial = logical(T.beneficial(:));
harmful = logical(T.harmful(:));

nBeneficial = sum(beneficial);
nTrig = sum(trigger);

M = struct();
M.actual_trigger_rate = mean(trigger);
M.policy_recall = mean(out);

if nBeneficial>0
    M.beneficial_capture = ...
        sum(trigger & beneficial)/nBeneficial;
else
    M.beneficial_capture = NaN;
end

if nTrig>0
    M.benefit_precision = ...
        sum(trigger & beneficial)/nTrig;

    M.harmful_fraction_among_triggers = ...
        sum(trigger & harmful)/nTrig;

    M.net_utility_among_triggers = ...
        (sum(trigger & beneficial)- ...
         sum(trigger & harmful))/nTrig;
else
    M.benefit_precision = NaN;
    M.harmful_fraction_among_triggers = NaN;
    M.net_utility_among_triggers = NaN;
end

end

%% ========================================================================
function trigger = exact_topk_trigger(score,budget,tiebreak)

score = double(score(:));
tiebreak = double(tiebreak(:));

N = numel(score);

if numel(tiebreak)~=N
    error('Tie-break length mismatch.');
end

budget = min(max(double(budget),0),1);
K = round(budget*N);
K = min(max(K,0),N);

trigger = false(N,1);

if K==0
    return;
elseif K==N
    trigger(:) = true;
    return;
end

safe_score = score;
safe_score(~isfinite(safe_score)) = -Inf;

rank_score = ...
    safe_score + 1e-10*(tiebreak-0.5);

[~,ord] = sort(rank_score,'descend');

trigger(ord(1:K)) = true;

end

%% ========================================================================
function C = random_expected_curve(T,budgets)

budgets = double(budgets(:));

cheap_recall = mean(double(T.cheap_success));
benefit_rate = mean(double(T.beneficial));
harm_rate = mean(double(T.harmful));

target_budget = budgets;
actual_trigger_rate = budgets;

policy_recall = ...
    cheap_recall + ...
    budgets*(benefit_rate-harm_rate);

beneficial_capture = budgets;

benefit_precision = ...
    repmat(benefit_rate,numel(budgets),1);

harmful_fraction_among_triggers = ...
    repmat(harm_rate,numel(budgets),1);

net_utility_among_triggers = ...
    repmat(benefit_rate-harm_rate,numel(budgets),1);

benefit_precision(budgets==0) = NaN;
harmful_fraction_among_triggers(budgets==0) = NaN;
net_utility_among_triggers(budgets==0) = NaN;

normalized_q_search_budget = 1+budgets;

C = table( ...
    target_budget,actual_trigger_rate, ...
    policy_recall,beneficial_capture, ...
    benefit_precision, ...
    harmful_fraction_among_triggers, ...
    net_utility_among_triggers, ...
    normalized_q_search_budget);

end

%% ========================================================================
function R = extract_reported_points(C,budgets)

budgets = double(budgets(:));

regimes = unique(string(C.regime),'stable');
policies = unique(string(C.policy),'stable');

rows = {};

for ir = 1:numel(regimes)
    for ip = 1:numel(policies)

        mm = string(C.regime)==regimes(ir) & ...
             string(C.policy)==policies(ip);

        Cp = C(mm,:);

        if isempty(Cp)
            continue;
        end

        for ib = 1:numel(budgets)
            b = budgets(ib);

            [~,ii] = min(abs(Cp.target_budget-b));

            rows(end+1,:) = { ... %#ok<AGROW>
                char(regimes(ir)),char(policies(ip)),b, ...
                Cp.actual_trigger_rate(ii), ...
                Cp.policy_recall(ii), ...
                Cp.beneficial_capture(ii), ...
                Cp.benefit_precision(ii), ...
                Cp.harmful_fraction_among_triggers(ii), ...
                Cp.net_utility_among_triggers(ii), ...
                Cp.normalized_q_search_budget(ii)};
        end
    end
end

R = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','policy','target_budget', ...
    'actual_trigger_rate','policy_recall', ...
    'beneficial_capture','benefit_precision', ...
    'harmful_fraction_among_triggers', ...
    'net_utility_among_triggers', ...
    'normalized_q_search_budget'});

end

%% ========================================================================
function B = build_bottleneck_decomposition( ...
    test_smooth,pred_smooth, ...
    test_abrupt,pred_abrupt, ...
    direct_factor_audit,primary, ...
    veto_threshold)

rows = {};

for ir = 1:2
    if ir==1
        T = test_smooth;
        P = pred_smooth;
        regime = 'Smooth';
    else
        T = test_abrupt;
        P = pred_abrupt;
        regime = 'Abrupt';
    end

    % Task A: Cheap failure observability.
    aucCheap = binary_auc( ...
        T.cheap_failure,P.pCheapFail);

    [withinCheap,nCheapLines] = ...
        weighted_within_line_auc( ...
            T,P.pCheapFail,T.cheap_failure);

    % Task B: Rescueability conditional on CheapFailure.
    mmFail = logical(T.cheap_failure(:));

    aucRescue = binary_auc( ...
        T.rescue_success(mmFail), ...
        P.pRescueGivenFail(mmFail));

    [withinRescue,nRescueLines] = ...
        weighted_within_line_auc( ...
            T(mmFail,:), ...
            P.pRescueGivenFail(mmFail), ...
            T.rescue_success(mmFail));

    % Direct / factorized Beneficial within OracleSafe.
    aucDirectSafe = lookup_direct_factor_auc( ...
        direct_factor_audit, ...
        'Test',regime,'OracleSafe','Direct', ...
        'within_line_beneficial_auc');

    aucFactorSafe = lookup_direct_factor_auc( ...
        direct_factor_audit, ...
        'Test',regime,'OracleSafe','Factorized', ...
        'within_line_beneficial_auc');

    % Practical safe subset size.
    practicalSafe = ...
        double(P.pH_morph(:))<=veto_threshold;

    practicalSafeFraction = mean(practicalSafe);

    % 25% policy metrics.
    rState = get_primary_metric( ...
        primary,regime,'StateOnly','policy_recall');

    rDirect = get_primary_metric( ...
        primary,regime,'DirectBeneficial','policy_recall');

    rFactor = get_primary_metric( ...
        primary,regime,'FactorizedBeneficial','policy_recall');

    rDirectVeto = get_primary_metric( ...
        primary,regime,'DirectBeneficialHarmVeto','policy_recall');

    rFactorVeto = get_primary_metric( ...
        primary,regime,'FactorizedBeneficialHarmVeto','policy_recall');

    rOracleSafeFactor = get_primary_metric( ...
        primary,regime,'OracleSafeFactorized','policy_recall');

    rTrial = get_primary_metric( ...
        primary,regime,'TrialOracle','policy_recall');

    remainingGap = rTrial-rState;

    gainFactorVeto = rFactorVeto-rState;
    gainOracleSafeFactor = rOracleSafeFactor-rState;

    if remainingGap>eps
        fracGapFactorVeto = gainFactorVeto/remainingGap;
        fracGapOracleSafeFactor = ...
            gainOracleSafeFactor/remainingGap;
    else
        fracGapFactorVeto = NaN;
        fracGapOracleSafeFactor = NaN;
    end

    rows(end+1,:) = { ... %#ok<AGROW>
        regime, ...
        aucCheap,withinCheap,nCheapLines, ...
        aucRescue,withinRescue,nRescueLines, ...
        aucDirectSafe,aucFactorSafe, ...
        practicalSafeFraction, ...
        rState,rDirect,rFactor,rDirectVeto,rFactorVeto, ...
        rOracleSafeFactor,rTrial, ...
        gainFactorVeto,gainOracleSafeFactor, ...
        fracGapFactorVeto,fracGapOracleSafeFactor};
end

B = cell2table(rows, ...
    'VariableNames',{ ...
    'regime', ...
    'cheapfailure_pooled_auc', ...
    'cheapfailure_within_line_auc', ...
    'cheapfailure_valid_lines', ...
    'rescueability_pooled_auc', ...
    'rescueability_within_line_auc', ...
    'rescueability_valid_lines', ...
    'direct_beneficial_oraclesafe_within_auc', ...
    'factorized_beneficial_oraclesafe_within_auc', ...
    'practical_safe_fraction', ...
    'state_recall_25', ...
    'direct_beneficial_recall_25', ...
    'factorized_beneficial_recall_25', ...
    'direct_harmveto_recall_25', ...
    'factorized_harmveto_recall_25', ...
    'oracle_safe_factorized_recall_25', ...
    'trial_oracle_recall_25', ...
    'factorized_harmveto_gain_vs_state', ...
    'oracle_safe_factorized_gain_vs_state', ...
    'fraction_trialoracle_gap_captured_by_factorized_harmveto', ...
    'fraction_trialoracle_gap_captured_by_oracle_safe_factorized'});

end

%% ========================================================================
function D = build_decision_summary( ...
    group_audit,direct_factor_audit, ...
    safe_subset_composition,primary, ...
    bottleneck,best_lambda_sanity, ...
    c3b1_3_selected)

rows = {};

for regime = {'Smooth','Abrupt'}
    r = regime{1};

    B = bottleneck(strcmp(bottleneck.regime,r),:);

    % Best beneficial feature-group within-line AUC.
    mm = strcmp(group_audit.regime,r);
    Tg = group_audit(mm,:);

    [bestBeneficialAUC,ii] = max( ...
        Tg.beneficial_within_line_auc);

    bestBeneficialGroup = ...
        Tg.feature_group{ii};

    [bestCheapAUC,jj] = max( ...
        Tg.cheapfailure_within_line_auc);

    bestCheapGroup = ...
        Tg.feature_group{jj};

    [bestRescueAUC,kk] = max( ...
        Tg.rescueability_within_line_auc);

    bestRescueGroup = ...
        Tg.feature_group{kk};

    % Safe-subset direct/factorized.
    dSafe = lookup_direct_factor_auc( ...
        direct_factor_audit, ...
        'Test',r,'OracleSafe','Direct', ...
        'within_line_beneficial_auc');

    fSafe = lookup_direct_factor_auc( ...
        direct_factor_audit, ...
        'Test',r,'OracleSafe','Factorized', ...
        'within_line_beneficial_auc');

    % Practical-safe Beneficial prevalence.
    mmc = strcmp(safe_subset_composition.regime,r) & ...
          strcmp(safe_subset_composition.subset,'PracticalSafe');

    safeBeneficialRate = ...
        safe_subset_composition.beneficial_rate(mmc);

    % Main policy gain.
    stateRecall = get_primary_metric( ...
        primary,r,'StateOnly','policy_recall');

    factorVetoRecall = get_primary_metric( ...
        primary,r,'FactorizedBeneficialHarmVeto','policy_recall');

    directVetoRecall = get_primary_metric( ...
        primary,r,'DirectBeneficialHarmVeto','policy_recall');

    trialRecall = get_primary_metric( ...
        primary,r,'TrialOracle','policy_recall');

    rows(end+1,:) = { ... %#ok<AGROW>
        r, ...
        bestBeneficialGroup,bestBeneficialAUC, ...
        bestCheapGroup,bestCheapAUC, ...
        bestRescueGroup,bestRescueAUC, ...
        dSafe,fSafe, ...
        safeBeneficialRate, ...
        stateRecall,directVetoRecall,factorVetoRecall,trialRecall, ...
        factorVetoRecall-stateRecall, ...
        B.fraction_trialoracle_gap_captured_by_factorized_harmveto, ...
        best_lambda_sanity};
end

D = cell2table(rows, ...
    'VariableNames',{ ...
    'regime', ...
    'best_beneficial_group', ...
    'best_beneficial_within_auc', ...
    'best_cheapfailure_group', ...
    'best_cheapfailure_within_auc', ...
    'best_rescue_group', ...
    'best_rescue_within_auc', ...
    'direct_oraclesafe_within_auc', ...
    'factorized_oraclesafe_within_auc', ...
    'practical_safe_beneficial_rate', ...
    'state_recall_25', ...
    'direct_harmveto_recall_25', ...
    'factorized_harmveto_recall_25', ...
    'trial_oracle_recall_25', ...
    'factorized_harmveto_gain_vs_state', ...
    'fraction_trialoracle_gap_captured_by_factorized_harmveto', ...
    'extended_lambda_sanity_optimum'});

% Add previous C3-B1.3 lambda if available.
if ~isempty(c3b1_3_selected) && ...
   ismember('best_lambda', ...
       c3b1_3_selected.Properties.VariableNames)

    oldLambda = ...
        double(c3b1_3_selected.best_lambda(1));

    D.c3b1_3_original_lambda = ...
        repmat(oldLambda,height(D),1);
else
    D.c3b1_3_original_lambda = ...
        nan(height(D),1);
end

end

%% ========================================================================
function v = lookup_direct_factor_auc( ...
    T,split,regime,subset,score_type,varname)

mm = strcmp(T.split,split) & ...
     strcmp(T.regime,regime) & ...
     strcmp(T.subset,subset) & ...
     strcmp(T.score_type,score_type);

if sum(mm)~=1
    error(['Could not uniquely find audit row: %s/%s/%s/%s'], ...
        split,regime,subset,score_type);
end

v = T.(varname)(mm);

end

%% ========================================================================
function v = get_primary_metric(T,regime,policy,varname)

mm = strcmp(T.regime,regime) & ...
     strcmp(T.policy,policy);

if sum(mm)~=1
    error('Could not uniquely find %s / %s.',regime,policy);
end

v = T.(varname)(mm);

end

%% ========================================================================
function write_summary( ...
    output_dir,cfg, ...
    veto_threshold,best_lambda_sanity, ...
    group_audit,direct_factor_audit, ...
    safe_subset_composition,primary, ...
    bottleneck,decision)

fid = fopen(fullfile(output_dir,'summary.txt'),'w');

fprintf(fid,'EXP009-C3-B2 Safe-Subset Beneficial Opportunity Audit\n');
fprintf(fid,'=====================================================\n\n');

fprintf(fid,'Research question\n');
fprintf(fid,'-----------------\n');
fprintf(fid,['C3-B1.3 showed that Harmful fate is observable, but perfect ' ...
    'harm avoidance explains only a minority of the TrialOracle gap.\n']);
fprintf(fid,['C3-B2 therefore asks: among safe / non-harmful trials, which ' ...
    'ones are actually worth rescuing?\n\n']);

fprintf(fid,'Exact decomposition\n');
fprintf(fid,'-------------------\n');
fprintf(fid,'Beneficial = CheapFailure AND FallbackSuccess\n\n');
fprintf(fid,['This motivates separate CheapFailure and Rescueability models, ' ...
    'plus a factorized Beneficial score:\n']);
fprintf(fid,'  pB_factor = p(CheapFailure|X) * p(FallbackSuccess|CheapFailure,X)\n\n');

fprintf(fid,'C3-B1.3 fixed harm-veto threshold = %.8f\n',veto_threshold);
fprintf(fid,'Extended lambda sanity optimum = %.4f\n\n',best_lambda_sanity);

fprintf(fid,'Feature-group task audit\n');
fprintf(fid,'------------------------\n');
for i = 1:height(group_audit)
    fprintf(fid,[ ...
        '%-21s %-7s | Bwithin=%.4f Cwithin=%.4f Rwithin=%.4f\n'], ...
        group_audit.feature_group{i}, ...
        group_audit.regime{i}, ...
        group_audit.beneficial_within_line_auc(i), ...
        group_audit.cheapfailure_within_line_auc(i), ...
        group_audit.rescueability_within_line_auc(i));
end

fprintf(fid,'\nDirect vs factorized Beneficial audit\n');
fprintf(fid,'------------------------------------\n');
for i = 1:height(direct_factor_audit)
    if strcmp(direct_factor_audit.split{i},'Test')
        fprintf(fid,[ ...
            '%s %-13s %-18s pooled=%.4f within=%.4f prev=%.4f n=%d\n'], ...
            direct_factor_audit.regime{i}, ...
            direct_factor_audit.subset{i}, ...
            direct_factor_audit.score_type{i}, ...
            direct_factor_audit.pooled_beneficial_auc(i), ...
            direct_factor_audit.within_line_beneficial_auc(i), ...
            direct_factor_audit.beneficial_prevalence(i), ...
            direct_factor_audit.n_trials(i));
    end
end

fprintf(fid,'\nSafe-subset composition\n');
fprintf(fid,'-----------------------\n');
for i = 1:height(safe_subset_composition)
    fprintf(fid,[ ...
        '%s %-13s n=%d B=%.4f H=%.4f N=%.4f CheapFail=%.4f\n'], ...
        safe_subset_composition.regime{i}, ...
        safe_subset_composition.subset{i}, ...
        safe_subset_composition.n_trials(i), ...
        safe_subset_composition.beneficial_rate(i), ...
        safe_subset_composition.harmful_rate(i), ...
        safe_subset_composition.neutral_rate(i), ...
        safe_subset_composition.cheap_failure_rate(i));
end

fprintf(fid,'\n25%% matched-budget policy comparison\n');
fprintf(fid,'------------------------------------\n');
for i = 1:height(primary)
    fprintf(fid,[ ...
        '%s %-31s recall=%.6f capture=%.6f precision=%.6f harm=%.6f\n'], ...
        primary.regime{i},primary.policy{i}, ...
        primary.policy_recall(i), ...
        primary.beneficial_capture(i), ...
        primary.benefit_precision(i), ...
        primary.harmful_fraction_among_triggers(i));
end

fprintf(fid,'\nBottleneck decomposition\n');
fprintf(fid,'------------------------\n');
for i = 1:height(bottleneck)
    fprintf(fid,[ ...
        '%s CheapFail within=%.4f | Rescue within=%.4f | ' ...
        'DirectSafeB=%.4f | FactorSafeB=%.4f\n'], ...
        bottleneck.regime{i}, ...
        bottleneck.cheapfailure_within_line_auc(i), ...
        bottleneck.rescueability_within_line_auc(i), ...
        bottleneck.direct_beneficial_oraclesafe_within_auc(i), ...
        bottleneck.factorized_beneficial_oraclesafe_within_auc(i));

    fprintf(fid,[ ...
        '  State=%.4f FactorVeto=%.4f TrialOracle=%.4f | ' ...
        'FactorVeto captures %.3f of remaining TrialOracle gap.\n'], ...
        bottleneck.state_recall_25(i), ...
        bottleneck.factorized_harmveto_recall_25(i), ...
        bottleneck.trial_oracle_recall_25(i), ...
        bottleneck. ...
        fraction_trialoracle_gap_captured_by_factorized_harmveto(i));
end

fprintf(fid,'\nDecision summary\n');
fprintf(fid,'----------------\n');
for i = 1:height(decision)
    fprintf(fid,[ ...
        '%s bestB=%s %.4f | bestCheap=%s %.4f | bestRescue=%s %.4f\n'], ...
        decision.regime{i}, ...
        decision.best_beneficial_group{i}, ...
        decision.best_beneficial_within_auc(i), ...
        decision.best_cheapfailure_group{i}, ...
        decision.best_cheapfailure_within_auc(i), ...
        decision.best_rescue_group{i}, ...
        decision.best_rescue_within_auc(i));

    fprintf(fid,[ ...
        '  State %.4f -> Factorized+Veto %.4f (delta %+0.4f), ' ...
        'Direct+Veto %.4f, TrialOracle %.4f\n'], ...
        decision.state_recall_25(i), ...
        decision.factorized_harmveto_recall_25(i), ...
        decision.factorized_harmveto_gain_vs_state(i), ...
        decision.direct_harmveto_recall_25(i), ...
        decision.trial_oracle_recall_25(i));
end

fprintf(fid,'\nInterpretation logic\n');
fprintf(fid,'--------------------\n');
fprintf(fid,['1. If CheapFailure AUC is much higher than direct Beneficial AUC, ' ...
    'the first missing piece is cheap-branch reliability estimation.\n']);
fprintf(fid,['2. If Rescueability AUC is weak even after conditioning on CheapFailure, ' ...
    'fallback success itself is the harder latent variable.\n']);
fprintf(fid,['3. If factorized Beneficial outperforms direct Beneficial inside the ' ...
    'OracleSafe subset, the decomposition is algorithmically useful.\n']);
fprintf(fid,['4. If factorized+HarmVeto improves matched-budget recovery, the full ' ...
    'three-stage policy (state opportunity -> harm veto -> rescue ranking) ' ...
    'gets its first positive pilot.\n']);
fprintf(fid,['5. If all safe-subset Beneficial scores remain near 0.5, the next move ' ...
    'should not be a bigger classifier; we need new observables or a more ' ...
    'direct model of cheap failure / fallback rescue physics.\n']);

fclose(fid);

end

%% ========================================================================
function make_figures( ...
    output_dir,cfg, ...
    veto_threshold,lambda_sanity, ...
    group_audit,direct_factor_audit, ...
    safe_subset_composition,policy_curves, ...
    primary,bottleneck, ...
    test_smooth,pred_smooth, ...
    test_abrupt,pred_abrupt)

%% Fig 1: lambda boundary sanity
fig = figure('Visible',cfg.figure_visible);
plot(lambda_sanity.lambda, ...
     lambda_sanity.policy_recall, ...
     '-o','LineWidth',1.2);
xlabel('\lambda');
ylabel('OOF recovery rate');
title('C3-B2 Preflight: Extended \lambda Boundary Sanity');
grid on;
exportgraphics(fig, ...
    fullfile(output_dir,'fig01_lambda_boundary_sanity.png'), ...
    'Resolution',180);
close(fig);

%% Fig 2: Feature-group task audit
groups = unique(string(group_audit.feature_group),'stable');
regimes = ["Smooth","Abrupt"];

for ir = 1:2
    regime = regimes(ir);

    Tg = group_audit(strcmp(group_audit.regime,char(regime)),:);

    Y = [ ...
        Tg.beneficial_within_line_auc, ...
        Tg.cheapfailure_within_line_auc, ...
        Tg.rescueability_within_line_auc];

    fig = figure('Visible',cfg.figure_visible);
    bar(Y);
    yline(0.5,'--');
    ylim([0.45 1]);

    xticks(1:height(Tg));
    xticklabels(string(Tg.feature_group));
    xtickangle(25);

    ylabel('Weighted within-line AUC');
    title(sprintf( ...
        'C3-B2 %s: Which Subproblem Is Observable?', ...
        char(regime)));

    legend( ...
        ["Beneficial","CheapFailure","Rescueability"], ...
        'Location','best');

    grid on;

    exportgraphics(fig, ...
        fullfile(output_dir,sprintf( ...
        'fig%02d_%s_task_audit.png', ...
        1+ir,lower(char(regime)))), ...
        'Resolution',180);

    close(fig);
end

%% Fig 4: Direct vs factorized in safe subsets
rows = {};

for ir = 1:2
    regime = regimes(ir);

    for subset = ["All","OracleSafe","PracticalSafe"]
        for score = ["Direct","Factorized"]
            mm = strcmp(direct_factor_audit.split,'Test') & ...
                 strcmp(direct_factor_audit.regime,char(regime)) & ...
                 strcmp(direct_factor_audit.subset,char(subset)) & ...
                 strcmp(direct_factor_audit.score_type,char(score));

            rows(end+1,:) = { ... %#ok<AGROW>
                char(regime),char(subset),char(score), ...
                direct_factor_audit.within_line_beneficial_auc(mm)};
        end
    end
end

Tf = cell2table(rows, ...
    'VariableNames',{'regime','subset','score','auc'});

fig = figure('Visible',cfg.figure_visible);

cats = ["All","OracleSafe","PracticalSafe"];
Y = nan(numel(cats),4);

for ic = 1:numel(cats)
    c = cats(ic);

    Y(ic,1) = Tf.auc(strcmp(Tf.regime,'Smooth') & ...
                    strcmp(Tf.subset,char(c)) & ...
                    strcmp(Tf.score,'Direct'));

    Y(ic,2) = Tf.auc(strcmp(Tf.regime,'Smooth') & ...
                    strcmp(Tf.subset,char(c)) & ...
                    strcmp(Tf.score,'Factorized'));

    Y(ic,3) = Tf.auc(strcmp(Tf.regime,'Abrupt') & ...
                    strcmp(Tf.subset,char(c)) & ...
                    strcmp(Tf.score,'Direct'));

    Y(ic,4) = Tf.auc(strcmp(Tf.regime,'Abrupt') & ...
                    strcmp(Tf.subset,char(c)) & ...
                    strcmp(Tf.score,'Factorized'));
end

bar(Y);
yline(0.5,'--');
ylim([0.45 1]);
xticks(1:numel(cats));
xticklabels(cats);

ylabel('Within-line Beneficial AUC');
title('C3-B2 Direct vs Factorized Beneficial Observability');

legend( ...
    ["Smooth Direct","Smooth Factorized", ...
     "Abrupt Direct","Abrupt Factorized"], ...
    'Location','best');

grid on;

exportgraphics(fig, ...
    fullfile(output_dir,'fig04_direct_vs_factorized_safe_auc.png'), ...
    'Resolution',180);
close(fig);

%% Fig 5: Safe-subset composition
fig = figure('Visible',cfg.figure_visible);

Tps = safe_subset_composition( ...
    strcmp(safe_subset_composition.subset,'PracticalSafe'),:);

Y = [ ...
    Tps.beneficial_rate, ...
    Tps.neutral_rate, ...
    Tps.harmful_rate];

bar(Y);
ylim([0 1]);

xticks(1:height(Tps));
xticklabels(string(Tps.regime));

ylabel('Fraction');
title(sprintf( ...
    'C3-B2 Practical-Safe Composition (p_H \\leq %.3f)', ...
    veto_threshold));

legend(["Beneficial","Neutral","Harmful"],'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(output_dir,'fig05_practical_safe_composition.png'), ...
    'Resolution',180);
close(fig);

%% Fig 6: Policy comparison at 25%
policies = [ ...
    "StateOnly", ...
    "DirectBeneficial", ...
    "FactorizedBeneficial", ...
    "DirectBeneficialHarmVeto", ...
    "FactorizedBeneficialHarmVeto", ...
    "OracleSafeFactorized", ...
    "TrialOracle"];

Y = nan(numel(policies),2);

for ip = 1:numel(policies)
    for ir = 1:2
        mm = strcmp(primary.policy,char(policies(ip))) & ...
             strcmp(primary.regime,char(regimes(ir)));

        Y(ip,ir) = primary.policy_recall(mm);
    end
end

fig = figure('Visible',cfg.figure_visible);
bar(Y);
ylim([0 1]);

xticks(1:numel(policies));
xticklabels(policies);
xtickangle(30);

ylabel('Weak recovery rate');
title('C3-B2 Policy Comparison at 25% Budget');
legend(regimes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(output_dir,'fig06_policy_recovery_25pct.png'), ...
    'Resolution',180);
close(fig);

%% Fig 7-8: quality-cost by regime
show_policies = [ ...
    "StateOnly", ...
    "DirectBeneficial", ...
    "FactorizedBeneficial", ...
    "DirectBeneficialHarmVeto", ...
    "FactorizedBeneficialHarmVeto", ...
    "OracleSafeFactorized", ...
    "TrialOracle", ...
    "RandomExpected"];

for ir = 1:2
    regime = regimes(ir);

    fig = figure('Visible',cfg.figure_visible);
    hold on;

    for ip = 1:numel(show_policies)
        mm = string(policy_curves.regime)==regime & ...
             string(policy_curves.policy)==show_policies(ip);

        T = policy_curves(mm,:);

        plot(T.normalized_q_search_budget, ...
             T.policy_recall, ...
             'LineWidth',1.2);
    end

    xlabel('Normalized q-search budget');
    ylabel('Weak recovery rate');

    title(sprintf( ...
        'C3-B2 %s: Beneficial Opportunity Quality-Cost', ...
        char(regime)));

    legend(show_policies,'Location','best');
    grid on;

    exportgraphics(fig, ...
        fullfile(output_dir,sprintf( ...
        'fig%02d_%s_quality_cost.png', ...
        6+ir,lower(char(regime)))), ...
        'Resolution',180);

    close(fig);
end

%% Fig 9: Bottleneck decomposition
Y = [ ...
    bottleneck.cheapfailure_within_line_auc, ...
    bottleneck.rescueability_within_line_auc, ...
    bottleneck.direct_beneficial_oraclesafe_within_auc, ...
    bottleneck.factorized_beneficial_oraclesafe_within_auc];

fig = figure('Visible',cfg.figure_visible);
bar(Y);
yline(0.5,'--');
ylim([0.45 1]);

xticks(1:height(bottleneck));
xticklabels(string(bottleneck.regime));

ylabel('Within-line AUC');
title('C3-B2 Beneficial Bottleneck Decomposition');

legend( ...
    ["CheapFailure","Rescueability", ...
     "Direct B | OracleSafe","Factorized B | OracleSafe"], ...
    'Location','best');

grid on;

exportgraphics(fig, ...
    fullfile(output_dir,'fig09_beneficial_bottleneck_decomposition.png'), ...
    'Resolution',180);
close(fig);

%% Fig 10-11: Opportunity plane pCheapFail vs pRescueGivenFail
for ir = 1:2
    if ir==1
        T = test_smooth;
        P = pred_smooth;
        regime = "Smooth";
    else
        T = test_abrupt;
        P = pred_abrupt;
        regime = "Abrupt";
    end

    class_id = zeros(height(T),1);
    class_id(logical(T.beneficial)) = 1;
    class_id(logical(T.harmful)) = -1;

    fig = figure('Visible',cfg.figure_visible);

    scatter( ...
        P.pCheapFail, ...
        P.pRescueGivenFail, ...
        16,class_id,'filled');

    xlabel('Predicted CheapFailure probability');
    ylabel('Predicted rescue probability | CheapFailure');

    title(sprintf( ...
        'C3-B2 %s: Factorized Beneficial Opportunity Plane', ...
        char(regime)));

    cb = colorbar;
    cb.Ticks = [-1 0 1];
    cb.TickLabels = {'Harmful','Neutral','Beneficial'};

    grid on;

    exportgraphics(fig, ...
        fullfile(output_dir,sprintf( ...
        'fig%02d_%s_factorized_opportunity_plane.png', ...
        9+ir,lower(char(regime)))), ...
        'Resolution',180);

    close(fig);
end

end

%% ========================================================================
function mdl = fit_binary_model(X,y,cfg)

X = double(X);
y = double(logical(y(:)));

if size(X,1)~=numel(y)
    error('Binary-model feature/label dimensions differ.');
end

if numel(unique(y))<2
    error('Binary model requires both classes.');
end

[Xz,prep] = fit_standardizer(X);

beta = fit_ridge_logistic_irls( ...
    Xz,y,cfg.ridge_lambda, ...
    cfg.irls_max_iter,cfg.irls_tol,cfg.prob_clip);

mdl = struct();
mdl.prep = prep;
mdl.beta = beta;

end

%% ========================================================================
function p = predict_binary_model(mdl,X)

Xz = apply_standardizer(X,mdl.prep);

Xd = [ones(size(Xz,1),1),Xz];

eta = Xd*mdl.beta;
eta = min(max(eta,-30),30);

p = 1./(1+exp(-eta));
p = p(:);

end

%% ========================================================================
function [Xz,prep] = fit_standardizer(X)

X = double(X);
P = size(X,2);

impute = zeros(1,P);

for j = 1:P
    v = X(:,j);
    finite = isfinite(v);

    if any(finite)
        impute(j) = median(v(finite));
    else
        impute(j) = 0;
    end

    v(~finite) = impute(j);
    X(:,j) = v;
end

mu = mean(X,1);
sigma = std(X,0,1);

sigma(~isfinite(sigma) | sigma<1e-12) = 1;

Xz = bsxfun(@rdivide, ...
    bsxfun(@minus,X,mu),sigma);

prep = struct();
prep.impute = impute;
prep.mu = mu;
prep.sigma = sigma;

end

%% ========================================================================
function Xz = apply_standardizer(X,prep)

X = double(X);

if size(X,2)~=numel(prep.mu)
    error('Standardizer feature dimension mismatch.');
end

for j = 1:size(X,2)
    v = X(:,j);
    v(~isfinite(v)) = prep.impute(j);
    X(:,j) = v;
end

Xz = bsxfun(@rdivide, ...
    bsxfun(@minus,X,prep.mu),prep.sigma);

end

%% ========================================================================
function beta = fit_ridge_logistic_irls( ...
    X,y,lambda,max_iter,tol,pclip)

[N,P] = size(X);

Xd = [ones(N,1),X];
beta = zeros(P+1,1);

penalty = lambda*eye(P+1);
penalty(1,1) = 0;

for it = 1:max_iter

    eta = Xd*beta;
    eta = min(max(eta,-30),30);

    p = 1./(1+exp(-eta));
    p = min(max(p,pclip),1-pclip);

    w = p.*(1-p);

    g = Xd.'*(p-y) + penalty*beta;

    Xw = bsxfun(@times,Xd,w);
    H = Xd.'*Xw + penalty;

    step = H\g;

    if any(~isfinite(step))
        error('Non-finite IRLS step.');
    end

    beta_new = beta-step;

    if norm(beta_new-beta) <= tol*(1+norm(beta))
        beta = beta_new;
        return;
    end

    beta = beta_new;
end

end

%% ========================================================================
function X = table_to_matrix(T,names)

N = height(T);
P = numel(names);

X = nan(N,P);

for j = 1:P
    name = names{j};

    if ~ismember(name,T.Properties.VariableNames)
        error('Feature missing: %s',name);
    end

    v = double(T.(name));
    v = v(:);

    if numel(v)~=N
        error('Feature %s does not have one scalar per trial.',name);
    end

    X(:,j) = v;
end

end

%% ========================================================================
function [aucW,nValid] = weighted_within_line_auc(T,score,label)

score = double(score(:));
label = logical(label(:));

if height(T)~=numel(score) || numel(score)~=numel(label)
    error('Within-line AUC dimension mismatch.');
end

if ismember('regime',T.Properties.VariableNames)
    group_key = string(T.regime) + "_" + string(T.line_index);
else
    group_key = string(T.line_index);
end

groups = unique(group_key,'stable');

auc_num = 0;
weight_sum = 0;
nValid = 0;

for i = 1:numel(groups)
    mm = group_key==groups(i);

    y = label(mm);
    s = score(mm);

    valid = isfinite(s);
    y = y(valid);
    s = s(valid);

    nPos = sum(y);
    nNeg = sum(~y);

    if nPos>0 && nNeg>0
        a = binary_auc(y,s);
        w = nPos*nNeg;

        auc_num = auc_num+w*a;
        weight_sum = weight_sum+w;
        nValid = nValid+1;
    end
end

if weight_sum<=0
    aucW = NaN;
else
    aucW = auc_num/weight_sum;
end

end

%% ========================================================================
function auc = binary_auc(y,score)

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
