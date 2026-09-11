function results = exp09c3b1_3_harm_aware_fallback()
%EXP09C3B1_3_HARM_AWARE_FALLBACK
% EXP009 / Pilot-01 / C3-B1.3
%
% State-Conditioned Harm-Aware Fallback Allocation
%
% -------------------------------------------------------------------------
% Scientific premise from C3-B1.2
% -------------------------------------------------------------------------
% Physical-state prior is reproducible, but Beneficial fate remains hard
% to predict within state. In contrast, Harmful fate is strongly observable
% from q-landscape morphology.
%
% Therefore the next method hypothesis is asymmetric:
%
%       opportunity(state)
%               -
%       realization harm risk(morphology)
%
% rather than a single undifferentiated "fallback value" classifier.
%
% -------------------------------------------------------------------------
% Main practical policies
% -------------------------------------------------------------------------
% StateOnly
%   rank only by cross-fitted physical-state prior.
%
% HarmOnlyMorph
%   rank by low predicted Harmful risk only.
%
% StateMorphDirect
%   conventional direct two-head fusion using state + morphology:
%       pB - pH
%
% StateAllDirect
%   direct two-head fusion using state + all C3-B1.2 observables.
%
% OpportunityMinusHarm
%   score = z(state_prior) - lambda * pH_morph
%   lambda tuned from out-of-fold TRAIN predictions only.
%
% OpportunityHardVeto
%   state ranking, but realizations with high pH_morph are strongly demoted.
%   veto threshold tuned from out-of-fold TRAIN only.
%
% OracleHarmVeto
%   oracle diagnostic: state ranking with TRUE Harmful outcomes demoted.
%   It answers how much of the remaining Oracle gap could be closed by
%   perfect harm avoidance alone.
%
% TrialOracle
%   upper bound using true Beneficial / Harmful labels.
%
% -------------------------------------------------------------------------
% Important design choice
% -------------------------------------------------------------------------
% Policy evaluation uses exact top-K budget allocation by SCORE only.
% The external budget is known; labels are never used for practical top-K
% selection. This yields exactly matched computation budget.
%
% Run:
%   results = exp09c3b1_3_harm_aware_fallback;

cfg = config_exp09c3b1_3();

%% Paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.input_dir)
    input_dir = fullfile( ...
        paper_root,'results','exp09_pilot01', ...
        'exp09c3b1_2_mechanism_observable_audit');
else
    input_dir = cfg.input_dir;
end

if isempty(cfg.output_dir)
    output_dir = fullfile( ...
        paper_root,'results','exp09_pilot01', ...
        'exp09c3b1_3_harm_aware_fallback');
else
    output_dir = cfg.output_dir;
end

if ~exist(output_dir,'dir')
    mkdir(output_dir);
end

fprintf('\n============================================================\n');
fprintf(' EXP009-C3-B1.3 / State-Conditioned Harm-Aware Fallback\n');
fprintf('============================================================\n');
fprintf('Input : %s\n',input_dir);
fprintf('Output: %s\n',output_dir);
fprintf('Primary budget: %.2f\n\n',cfg.primary_budget);

%% Load C3-B1.2 rich banks
train_smooth = read_trial_bank( ...
    fullfile(input_dir,'train_rich_trials_smooth.csv'));

train_abrupt = read_trial_bank( ...
    fullfile(input_dir,'train_rich_trials_abrupt.csv'));

test_smooth = read_trial_bank( ...
    fullfile(input_dir,'test_rich_trials_smooth.csv'));

test_abrupt = read_trial_bank( ...
    fullfile(input_dir,'test_rich_trials_abrupt.csv'));

validate_required_columns(train_smooth,cfg);
validate_required_columns(train_abrupt,cfg);
validate_required_columns(test_smooth,cfg);
validate_required_columns(test_abrupt,cfg);

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

%% State scaling learned from TRAIN
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

%% ------------------------------------------------------------------------
% Sequence-level OOF predictions for hyperparameter tuning
[oof,fold_table] = make_oof_predictions( ...
    train_smooth,train_abrupt,cfg);

writetable(fold_table, ...
    fullfile(output_dir,'oof_fold_assignment.csv'));

%% Fit full TRAIN models -> TEST
models = fit_full_models(train_all,cfg);

pred_test_all = predict_all_models( ...
    models,test_all,cfg);

pred_test_smooth = subset_predictions( ...
    pred_test_all,test_all.regime=="Smooth");

pred_test_abrupt = subset_predictions( ...
    pred_test_all,test_all.regime=="Abrupt");

%% ------------------------------------------------------------------------
% Tune harm-aware policy hyperparameters on OOF TRAIN only
tuning = tune_harm_aware_policies( ...
    train_all,oof,cfg);

writetable(tuning.lambda_sweep, ...
    fullfile(output_dir,'lambda_sweep_oof.csv'));

writetable(tuning.veto_sweep, ...
    fullfile(output_dir,'veto_sweep_oof.csv'));

selected = table( ...
    tuning.best_lambda, ...
    tuning.best_veto_threshold, ...
    tuning.best_lambda_recall, ...
    tuning.best_lambda_harm_fraction, ...
    tuning.best_veto_recall, ...
    tuning.best_veto_harm_fraction, ...
    'VariableNames',{ ...
    'best_lambda', ...
    'best_veto_threshold', ...
    'best_lambda_oof_recall', ...
    'best_lambda_oof_harm_fraction', ...
    'best_veto_oof_recall', ...
    'best_veto_oof_harm_fraction'});

writetable(selected, ...
    fullfile(output_dir,'selected_hyperparameters.csv'));

fprintf('Selected lambda = %.4f\n',tuning.best_lambda);
fprintf('Selected veto pH threshold = %.6f\n\n', ...
    tuning.best_veto_threshold);

%% ------------------------------------------------------------------------
% Build practical / oracle scores
score_train = build_policy_scores( ...
    train_all,oof,tuning,cfg,true);

score_test_all = build_policy_scores( ...
    test_all,pred_test_all,tuning,cfg,false);

score_test_smooth = subset_score_struct( ...
    score_test_all,test_all.regime=="Smooth");

score_test_abrupt = subset_score_struct( ...
    score_test_all,test_all.regime=="Abrupt");

%% Harm-model information audit
harm_audit = build_harm_model_audit( ...
    train_all,oof, ...
    test_smooth,pred_test_smooth, ...
    test_abrupt,pred_test_abrupt);

writetable(harm_audit, ...
    fullfile(output_dir,'harm_model_audit.csv'));

%% Risk calibration
risk_calibration = build_risk_calibration( ...
    test_smooth,test_abrupt, ...
    pred_test_smooth,pred_test_abrupt);

writetable(risk_calibration, ...
    fullfile(output_dir,'harm_risk_calibration.csv'));

%% ------------------------------------------------------------------------
% Exact matched-budget policy curves
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

    C = evaluate_all_policy_curves( ...
        T,Scores,cfg);

    C.regime = repmat(regime,height(C),1);
    C = movevars(C,'regime','Before',1);

    policy_curves = [policy_curves;C]; %#ok<AGROW>
end

writetable(policy_curves, ...
    fullfile(output_dir,'harm_aware_policy_curves.csv'));

reported = extract_reported_points( ...
    policy_curves,cfg.report_budgets);

writetable(reported, ...
    fullfile(output_dir,'reported_budget_points.csv'));

%% Primary budget diagnostic
primary = reported( ...
    abs(reported.target_budget-cfg.primary_budget)<1e-12,:);

writetable(primary, ...
    fullfile(output_dir,'primary_25pct_policy_comparison.csv'));

%% Oracle decomposition
oracle_decomp = build_oracle_decomposition( ...
    primary,cfg);

writetable(oracle_decomp, ...
    fullfile(output_dir,'oracle_harm_decomposition.csv'));

%% Policy delta vs StateOnly
delta_vs_state = build_delta_vs_state( ...
    policy_curves);

writetable(delta_vs_state, ...
    fullfile(output_dir,'delta_vs_stateonly.csv'));

%% Decision summary
decision = build_decision_summary( ...
    harm_audit,primary,oracle_decomp, ...
    tuning,cfg);

writetable(decision, ...
    fullfile(output_dir,'decision_summary.csv'));

%% State prior reproducibility summary
state_smooth.regime = repmat("Smooth",height(state_smooth),1);
state_abrupt.regime = repmat("Abrupt",height(state_abrupt),1);

state_summary = [state_smooth;state_abrupt];
state_summary = movevars(state_summary,'regime','Before',1);

writetable(state_summary, ...
    fullfile(output_dir,'state_prior_reproducibility.csv'));

%% Console
fprintf('\n================ HARM MODEL AUDIT ============================\n');
disp(harm_audit);

fprintf('\n================ 25%% POLICY COMPARISON ======================\n');
disp(primary(:,{ ...
    'regime','policy','policy_recall', ...
    'beneficial_capture','benefit_precision', ...
    'harmful_fraction_among_triggers'}));

fprintf('\n================ ORACLE HARM DECOMPOSITION ==================\n');
disp(oracle_decomp);

fprintf('\n================ DECISION SUMMARY ===========================\n');
disp(decision);
fprintf('=============================================================\n');

%% Summary text
write_summary( ...
    output_dir,cfg,tuning,harm_audit, ...
    primary,oracle_decomp,decision);

%% Figures
make_figures( ...
    output_dir,cfg,tuning, ...
    harm_audit,risk_calibration, ...
    policy_curves,primary, ...
    oracle_decomp,delta_vs_state, ...
    test_smooth,test_abrupt, ...
    pred_test_smooth,pred_test_abrupt);

%% Save
results = struct();
results.cfg = cfg;
results.models = models;
results.fold_table = fold_table;
results.tuning = tuning;
results.harm_audit = harm_audit;
results.risk_calibration = risk_calibration;
results.policy_curves = policy_curves;
results.primary = primary;
results.oracle_decomp = oracle_decomp;
results.delta_vs_state = delta_vs_state;
results.decision = decision;
results.state_summary = state_summary;

save(fullfile(output_dir,'exp09c3b1_3_results.mat'), ...
    'results','-v7.3');

fprintf('\nSaved C3-B1.3 outputs to:\n%s\n\n',output_dir);

end

%% ========================================================================
function T = read_trial_bank(filename)

if ~exist(filename,'file')
    error('Missing C3-B1.2 trial bank:\n%s',filename);
end

T = readtable(filename);

% Normalize labels to logical column vectors.
label_names = { ...
    'cheap_success','fallback_success', ...
    'beneficial','harmful'};

for i = 1:numel(label_names)
    name = label_names{i};

    if ismember(name,T.Properties.VariableNames)
        T.(name) = logical(double(T.(name)(:)));
    end
end

% Force scalar-valued columns to columns.
numeric_names = T.Properties.VariableNames;

for i = 1:numel(numeric_names)
    name = numeric_names{i};

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

required = [ ...
    required, ...
    cfg.morphology_features, ...
    cfg.all_observable_features];

vars = T.Properties.VariableNames;

for i = 1:numel(required)
    if ~ismember(required{i},vars)
        error('Required C3-B1.2 column missing: %s',required{i});
    end
end

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

% Cross-fitted TRAIN state prior.
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

% TEST state prior is learned from full TRAIN.
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
function [oof,fold_table] = make_oof_predictions( ...
    train_smooth,train_abrupt,cfg)

Ts = train_smooth;
Ta = train_abrupt;

T = [Ts;Ta];

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
    fold_id(T.sequence_id==seqs(i)) = fold_id_seq(i);
end

if any(~isfinite(fold_id))
    error('OOF fold assignment failed.');
end

pH_morph = nan(height(T),1);

pB_stateMorph = nan(height(T),1);
pH_stateMorph = nan(height(T),1);
value_stateMorph = nan(height(T),1);

pB_stateAll = nan(height(T),1);
pH_stateAll = nan(height(T),1);
value_stateAll = nan(height(T),1);

for k = 1:cfg.num_folds

    is_val = fold_id==k;
    is_fit = ~is_val;

    if ~any(is_val) || ~any(is_fit)
        error('Invalid OOF fold %d.',k);
    end

    Tfit = T(is_fit,:);
    Tval = T(is_val,:);

    % Harm morphology model.
    Xm_fit = table_to_matrix( ...
        Tfit,cfg.morphology_features);

    Xm_val = table_to_matrix( ...
        Tval,cfg.morphology_features);

    mdlH = fit_binary_model( ...
        Xm_fit,Tfit.harmful,cfg);

    pH_morph(is_val) = ...
        predict_binary_model(mdlH,Xm_val);

    % Direct state + morphology two-head model.
    sm_names = [{'state_prior'},cfg.morphology_features];

    Xsm_fit = table_to_matrix(Tfit,sm_names);
    Xsm_val = table_to_matrix(Tval,sm_names);

    mdlSM = fit_two_head_model( ...
        Xsm_fit,Tfit.beneficial,Tfit.harmful,cfg);

    Psm = predict_two_head_model( ...
        mdlSM,Xsm_val);

    pB_stateMorph(is_val) = Psm.pB;
    pH_stateMorph(is_val) = Psm.pH;
    value_stateMorph(is_val) = Psm.value;

    % Direct state + all observable two-head model.
    sa_names = [{'state_prior'},cfg.all_observable_features];

    Xsa_fit = table_to_matrix(Tfit,sa_names);
    Xsa_val = table_to_matrix(Tval,sa_names);

    mdlSA = fit_two_head_model( ...
        Xsa_fit,Tfit.beneficial,Tfit.harmful,cfg);

    Psa = predict_two_head_model( ...
        mdlSA,Xsa_val);

    pB_stateAll(is_val) = Psa.pB;
    pH_stateAll(is_val) = Psa.pH;
    value_stateAll(is_val) = Psa.value;
end

if any(~isfinite(pH_morph)) || ...
   any(~isfinite(value_stateMorph)) || ...
   any(~isfinite(value_stateAll))
    error('OOF prediction bank contains non-finite values.');
end

oof = struct();
oof.pH_morph = pH_morph;
oof.pB_stateMorph = pB_stateMorph;
oof.pH_stateMorph = pH_stateMorph;
oof.value_stateMorph = value_stateMorph;
oof.pB_stateAll = pB_stateAll;
oof.pH_stateAll = pH_stateAll;
oof.value_stateAll = value_stateAll;

fold_table = table( ...
    seqs(:),fold_id_seq(:), ...
    'VariableNames',{'sequence_id','fold_id'});

end

%% ========================================================================
function models = fit_full_models(T,cfg)

% Morphology Harm model.
Xm = table_to_matrix(T,cfg.morphology_features);

models.harmMorph = fit_binary_model( ...
    Xm,T.harmful,cfg);

% Direct State + Morphology.
sm_names = [{'state_prior'},cfg.morphology_features];

Xsm = table_to_matrix(T,sm_names);

models.stateMorph = fit_two_head_model( ...
    Xsm,T.beneficial,T.harmful,cfg);

% Direct State + All Observables.
sa_names = [{'state_prior'},cfg.all_observable_features];

Xsa = table_to_matrix(T,sa_names);

models.stateAll = fit_two_head_model( ...
    Xsa,T.beneficial,T.harmful,cfg);

end

%% ========================================================================
function P = predict_all_models(models,T,cfg)

Xm = table_to_matrix(T,cfg.morphology_features);

P.pH_morph = predict_binary_model( ...
    models.harmMorph,Xm);

sm_names = [{'state_prior'},cfg.morphology_features];

Xsm = table_to_matrix(T,sm_names);

Psm = predict_two_head_model( ...
    models.stateMorph,Xsm);

P.pB_stateMorph = Psm.pB;
P.pH_stateMorph = Psm.pH;
P.value_stateMorph = Psm.value;

sa_names = [{'state_prior'},cfg.all_observable_features];

Xsa = table_to_matrix(T,sa_names);

Psa = predict_two_head_model( ...
    models.stateAll,Xsa);

P.pB_stateAll = Psa.pB;
P.pH_stateAll = Psa.pH;
P.value_stateAll = Psa.value;

end

%% ========================================================================
function P2 = subset_predictions(P,mask)

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
function mdl = fit_binary_model(X,y,cfg)

X = double(X);
y = double(logical(y(:)));

if size(X,1)~=numel(y)
    error('Binary-model feature/label dimensions differ.');
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
function mdl = fit_two_head_model(X,yB,yH,cfg)

X = double(X);

yB = double(logical(yB(:)));
yH = double(logical(yH(:)));

if size(X,1)~=numel(yB) || numel(yB)~=numel(yH)
    error('Two-head feature/label dimensions differ.');
end

[Xz,prep] = fit_standardizer(X);

betaB = fit_ridge_logistic_irls( ...
    Xz,yB,cfg.ridge_lambda, ...
    cfg.irls_max_iter,cfg.irls_tol,cfg.prob_clip);

betaH = fit_ridge_logistic_irls( ...
    Xz,yH,cfg.ridge_lambda, ...
    cfg.irls_max_iter,cfg.irls_tol,cfg.prob_clip);

mdl = struct();
mdl.prep = prep;
mdl.betaB = betaB;
mdl.betaH = betaH;

end

%% ========================================================================
function P = predict_two_head_model(mdl,X)

Xz = apply_standardizer(X,mdl.prep);

Xd = [ones(size(Xz,1),1),Xz];

etaB = Xd*mdl.betaB;
etaH = Xd*mdl.betaH;

etaB = min(max(etaB,-30),30);
etaH = min(max(etaH,-30),30);

pB = 1./(1+exp(-etaB));
pH = 1./(1+exp(-etaH));

P = struct();
P.pB = pB(:);
P.pH = pH(:);
P.value = (pB-pH);
P.value = P.value(:);

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
function tuning = tune_harm_aware_policies(T,oof,cfg)

state_z = double(T.state_z(:));
pH = double(oof.pH_morph(:));

% Lambda sweep.
nL = numel(cfg.lambda_grid);

lambda = cfg.lambda_grid(:);
policy_recall = nan(nL,1);
beneficial_capture = nan(nL,1);
benefit_precision = nan(nL,1);
harmful_fraction = nan(nL,1);

for i = 1:nL
    score = state_z-lambda(i)*pH;

    M = evaluate_policy_at_budget( ...
        T,score,cfg.primary_budget);

    policy_recall(i) = M.policy_recall;
    beneficial_capture(i) = M.beneficial_capture;
    benefit_precision(i) = M.benefit_precision;
    harmful_fraction(i) = M.harmful_fraction_among_triggers;
end

lambda_sweep = table( ...
    lambda,policy_recall, ...
    beneficial_capture,benefit_precision,harmful_fraction);

best_idx = choose_best_policy_index( ...
    policy_recall,harmful_fraction,beneficial_capture);

best_lambda = lambda(best_idx);

% Veto threshold candidates learned only from OOF TRAIN pH distribution.
qgrid = cfg.veto_quantile_grid(:);

threshold = nan(numel(qgrid)+1,1);
threshold(1:numel(qgrid)) = arrayfun( ...
    @(q) empirical_quantile(pH,q),qgrid);

% Include +Inf = no veto.
threshold(end) = Inf;

policy_recall = nan(size(threshold));
beneficial_capture = nan(size(threshold));
benefit_precision = nan(size(threshold));
harmful_fraction = nan(size(threshold));
veto_fraction = nan(size(threshold));

for i = 1:numel(threshold)

    risk = pH>threshold(i);

    score = state_z - ...
        cfg.veto_rank_penalty*double(risk);

    M = evaluate_policy_at_budget( ...
        T,score,cfg.primary_budget);

    policy_recall(i) = M.policy_recall;
    beneficial_capture(i) = M.beneficial_capture;
    benefit_precision(i) = M.benefit_precision;
    harmful_fraction(i) = M.harmful_fraction_among_triggers;
    veto_fraction(i) = mean(risk);
end

veto_sweep = table( ...
    threshold,veto_fraction, ...
    policy_recall,beneficial_capture, ...
    benefit_precision,harmful_fraction);

best_veto_idx = choose_best_policy_index( ...
    policy_recall,harmful_fraction,beneficial_capture);

best_veto_threshold = threshold(best_veto_idx);

tuning = struct();
tuning.lambda_sweep = lambda_sweep;
tuning.veto_sweep = veto_sweep;

tuning.best_lambda = best_lambda;
tuning.best_veto_threshold = best_veto_threshold;

tuning.best_lambda_recall = ...
    lambda_sweep.policy_recall(best_idx);
tuning.best_lambda_harm_fraction = ...
    lambda_sweep.harmful_fraction(best_idx);

tuning.best_veto_recall = ...
    veto_sweep.policy_recall(best_veto_idx);
tuning.best_veto_harm_fraction = ...
    veto_sweep.harmful_fraction(best_veto_idx);

end

%% ========================================================================
function idx = choose_best_policy_index( ...
    recall,harm_fraction,benefit_capture)

recall = double(recall(:));
harm_fraction = double(harm_fraction(:));
benefit_capture = double(benefit_capture(:));

maxR = max(recall);

cand = find(abs(recall-maxR)<=1e-12);

if numel(cand)>1
    h = harm_fraction(cand);
    minH = min(h);

    cand = cand(abs(h-minH)<=1e-12);
end

if numel(cand)>1
    b = benefit_capture(cand);
    [~,ii] = max(b);

    idx = cand(ii);
else
    idx = cand(1);
end

end

%% ========================================================================
function Scores = build_policy_scores( ...
    T,P,tuning,cfg,is_oof)

if nargin<5
    is_oof = false;
end

state_z = double(T.state_z(:));

Scores = struct();

Scores.StateOnly = state_z;

Scores.HarmOnlyMorph = ...
    -double(P.pH_morph(:));

Scores.StateMorphDirect = ...
    double(P.value_stateMorph(:));

Scores.StateAllDirect = ...
    double(P.value_stateAll(:));

Scores.OpportunityMinusHarm = ...
    state_z - ...
    tuning.best_lambda*double(P.pH_morph(:));

risk = double(P.pH_morph(:)) > ...
    tuning.best_veto_threshold;

Scores.OpportunityHardVeto = ...
    state_z - ...
    cfg.veto_rank_penalty*double(risk);

Scores.OracleHarmVeto = ...
    state_z - ...
    cfg.veto_rank_penalty*double(T.harmful(:));

% Exact oracle ordering:
%   Beneficial first, Neutral second, Harmful last.
neutral = ~(logical(T.beneficial) | logical(T.harmful));

Scores.TrialOracle = ...
    2*double(T.beneficial(:)) + ...
    1*double(neutral(:));

% Add an infinitesimal state term to break oracle ties reproducibly without
% changing class ordering.
Scores.TrialOracle = ...
    Scores.TrialOracle + 1e-6*state_z;

% Preserve OOF flag for diagnostics if needed.
Scores.is_oof = is_oof;

end

%% ========================================================================
function S2 = subset_score_struct(S,mask)

mask = logical(mask(:));

names = fieldnames(S);

for i = 1:numel(names)
    name = names{i};

    if strcmp(name,'is_oof')
        S2.(name) = S.(name);
        continue;
    end

    v = S.(name);

    if isvector(v) && numel(v)==numel(mask)
        S2.(name) = v(mask);
    else
        error('Score field %s has unexpected dimensions.',name);
    end
end

end

%% ========================================================================
function A = build_harm_model_audit( ...
    train_all,oof, ...
    test_smooth,pred_smooth, ...
    test_abrupt,pred_abrupt)

rows = {};

% OOF TRAIN
auc_train = binary_auc( ...
    train_all.harmful,oof.pH_morph);

[within_train,nWithinTrain] = ...
    weighted_within_line_auc( ...
        train_all,oof.pH_morph,train_all.harmful);

rows(end+1,:) = { ...
    'OOF-Train','Combined', ...
    auc_train,within_train,nWithinTrain};

% Smooth TEST
auc_s = binary_auc( ...
    test_smooth.harmful,pred_smooth.pH_morph);

[within_s,nWithinS] = ...
    weighted_within_line_auc( ...
        test_smooth,pred_smooth.pH_morph,test_smooth.harmful);

rows(end+1,:) = { ...
    'Test','Smooth', ...
    auc_s,within_s,nWithinS};

% Abrupt TEST
auc_a = binary_auc( ...
    test_abrupt.harmful,pred_abrupt.pH_morph);

[within_a,nWithinA] = ...
    weighted_within_line_auc( ...
        test_abrupt,pred_abrupt.pH_morph,test_abrupt.harmful);

rows(end+1,:) = { ...
    'Test','Abrupt', ...
    auc_a,within_a,nWithinA};

A = cell2table(rows, ...
    'VariableNames',{ ...
    'split','regime', ...
    'pooled_harm_auc', ...
    'within_line_harm_auc', ...
    'valid_within_lines'});

end

%% ========================================================================
function C = build_risk_calibration( ...
    test_smooth,test_abrupt, ...
    pred_smooth,pred_abrupt)

rows = {};

for ir = 1:2
    if ir==1
        T = test_smooth;
        pH = pred_smooth.pH_morph;
        regime = 'Smooth';
    else
        T = test_abrupt;
        pH = pred_abrupt.pH_morph;
        regime = 'Abrupt';
    end

    edges = quantile_edges_unique(pH,10);
    bin_id = assign_bins(pH,edges);

    for ib = 1:(numel(edges)-1)
        mm = bin_id==ib;

        rows(end+1,:) = { ... %#ok<AGROW>
            regime,ib, ...
            edges(ib),edges(ib+1), ...
            sum(mm), ...
            mean(pH(mm),'omitnan'), ...
            mean(double(T.harmful(mm)),'omitnan'), ...
            mean(double(T.beneficial(mm)),'omitnan')};
    end
end

C = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','risk_bin', ...
    'pH_low','pH_high','n_trials', ...
    'mean_predicted_harm_risk', ...
    'empirical_harmful_rate', ...
    'empirical_beneficial_rate'});

end

%% ========================================================================
function C = evaluate_all_policy_curves(T,Scores,cfg)

policies = string(cfg.policy_names(:));

C = table();

for ip = 1:numel(policies)
    policy = policies(ip);

    if policy=="RandomExpected"
        Cp = random_expected_curve(T,cfg.budget_grid);
    else
        score = Scores.(char(policy));

        Cp = exact_budget_curve( ...
            T,score,cfg.budget_grid);
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

if numel(score)~=height(T)
    error('Policy score length mismatch.');
end

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

score = double(score(:));

if numel(score)~=height(T)
    error('Score length does not match trial table.');
end

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

% Deterministic tiny tie-break.
rank_score = safe_score + 1e-10*(tiebreak-0.5);

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
    cheap_recall + budgets*(benefit_rate-harm_rate);

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
function D = build_oracle_decomposition(primary,cfg)

regimes = ["Smooth","Abrupt"];

rows = {};

for ir = 1:numel(regimes)
    regime = regimes(ir);

    rState = get_primary_metric( ...
        primary,regime,"StateOnly",'policy_recall');

    rPrac = get_primary_metric( ...
        primary,regime,"OpportunityMinusHarm",'policy_recall');

    rVeto = get_primary_metric( ...
        primary,regime,"OpportunityHardVeto",'policy_recall');

    rOH = get_primary_metric( ...
        primary,regime,"OracleHarmVeto",'policy_recall');

    rTO = get_primary_metric( ...
        primary,regime,"TrialOracle",'policy_recall');

    total_gap = rTO-rState;
    harm_oracle_gain = rOH-rState;
    practical_gain = rPrac-rState;
    veto_gain = rVeto-rState;

    if total_gap>eps
        harm_explain_frac = harm_oracle_gain/total_gap;
        practical_total_frac = practical_gain/total_gap;
        veto_total_frac = veto_gain/total_gap;
    else
        harm_explain_frac = NaN;
        practical_total_frac = NaN;
        veto_total_frac = NaN;
    end

    if harm_oracle_gain>eps
        practical_harm_capture = ...
            practical_gain/harm_oracle_gain;

        veto_harm_capture = ...
            veto_gain/harm_oracle_gain;
    else
        practical_harm_capture = NaN;
        veto_harm_capture = NaN;
    end

    rows(end+1,:) = { ... %#ok<AGROW>
        char(regime),cfg.primary_budget, ...
        rState,rPrac,rVeto,rOH,rTO, ...
        total_gap,harm_oracle_gain, ...
        practical_gain,veto_gain, ...
        harm_explain_frac, ...
        practical_total_frac,veto_total_frac, ...
        practical_harm_capture,veto_harm_capture};
end

D = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','target_budget', ...
    'state_recall','opportunity_minus_harm_recall', ...
    'hard_veto_recall','oracle_harm_veto_recall', ...
    'trial_oracle_recall', ...
    'trial_oracle_gap_above_state', ...
    'oracle_harm_gain_above_state', ...
    'practical_gain_above_state', ...
    'hard_veto_gain_above_state', ...
    'fraction_total_gap_explainable_by_perfect_harm_avoidance', ...
    'fraction_total_gap_captured_by_practical_score', ...
    'fraction_total_gap_captured_by_hard_veto', ...
    'fraction_oracle_harm_gain_captured_by_practical_score', ...
    'fraction_oracle_harm_gain_captured_by_hard_veto'});

end

%% ========================================================================
function D = build_delta_vs_state(C)

rows = {};

regimes = unique(string(C.regime),'stable');
policies = unique(string(C.policy),'stable');

for ir = 1:numel(regimes)
    regime = regimes(ir);

    Cstate = C( ...
        string(C.regime)==regime & ...
        string(C.policy)=="StateOnly",:);

    for ip = 1:numel(policies)
        policy = policies(ip);

        if policy=="StateOnly" || policy=="RandomExpected"
            continue;
        end

        Cp = C( ...
            string(C.regime)==regime & ...
            string(C.policy)==policy,:);

        if height(Cp)~=height(Cstate)
            error('Budget-grid mismatch for delta-vs-state.');
        end

        for i = 1:height(Cp)
            rows(end+1,:) = { ... %#ok<AGROW>
                char(regime),char(policy), ...
                Cp.target_budget(i), ...
                Cp.policy_recall(i)-Cstate.policy_recall(i), ...
                Cp.harmful_fraction_among_triggers(i)- ...
                    Cstate.harmful_fraction_among_triggers(i)};
        end
    end
end

D = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','policy','target_budget', ...
    'recall_delta_vs_state', ...
    'harm_fraction_delta_vs_state'});

end

%% ========================================================================
function D = build_decision_summary( ...
    harm_audit,primary,oracle_decomp,tuning,cfg)

rows = {};

for regime = ["Smooth","Abrupt"]

    mm = strcmp(harm_audit.split,'Test') & ...
         strcmp(harm_audit.regime,char(regime));

    if sum(mm)~=1
        error('Missing harm audit row for %s.',regime);
    end

    harm_pooled = harm_audit.pooled_harm_auc(mm);
    harm_within = harm_audit.within_line_harm_auc(mm);

    rState = get_primary_metric( ...
        primary,regime,"StateOnly",'policy_recall');

    rDirectMorph = get_primary_metric( ...
        primary,regime,"StateMorphDirect",'policy_recall');

    rDirectAll = get_primary_metric( ...
        primary,regime,"StateAllDirect",'policy_recall');

    rPrac = get_primary_metric( ...
        primary,regime,"OpportunityMinusHarm",'policy_recall');

    rVeto = get_primary_metric( ...
        primary,regime,"OpportunityHardVeto",'policy_recall');

    hState = get_primary_metric( ...
        primary,regime,"StateOnly", ...
        'harmful_fraction_among_triggers');

    hPrac = get_primary_metric( ...
        primary,regime,"OpportunityMinusHarm", ...
        'harmful_fraction_among_triggers');

    hVeto = get_primary_metric( ...
        primary,regime,"OpportunityHardVeto", ...
        'harmful_fraction_among_triggers');

    od = oracle_decomp( ...
        strcmp(oracle_decomp.regime,char(regime)),:);

    rows(end+1,:) = { ... %#ok<AGROW>
        char(regime), ...
        harm_pooled,harm_within, ...
        tuning.best_lambda, ...
        tuning.best_veto_threshold, ...
        rState,rDirectMorph,rDirectAll,rPrac,rVeto, ...
        rPrac-rState, ...
        rVeto-rState, ...
        hState,hPrac,hVeto, ...
        hPrac-hState, ...
        hVeto-hState, ...
        od.fraction_total_gap_explainable_by_perfect_harm_avoidance, ...
        od.fraction_total_gap_captured_by_practical_score, ...
        od.fraction_oracle_harm_gain_captured_by_practical_score};
end

D = cell2table(rows, ...
    'VariableNames',{ ...
    'regime', ...
    'test_harm_pooled_auc', ...
    'test_harm_within_line_auc', ...
    'selected_lambda', ...
    'selected_veto_threshold', ...
    'recall_stateonly', ...
    'recall_stateMorphDirect', ...
    'recall_stateAllDirect', ...
    'recall_opportunityMinusHarm', ...
    'recall_opportunityHardVeto', ...
    'gain_practical_vs_state', ...
    'gain_veto_vs_state', ...
    'harm_fraction_stateonly', ...
    'harm_fraction_practical', ...
    'harm_fraction_veto', ...
    'harm_fraction_delta_practical', ...
    'harm_fraction_delta_veto', ...
    'fraction_total_gap_explainable_by_perfect_harm_avoidance', ...
    'fraction_total_gap_captured_by_practical_score', ...
    'fraction_oracle_harm_gain_captured_by_practical_score'});

end

%% ========================================================================
function v = get_primary_metric(T,regime,policy,varname)

mm = strcmp(T.regime,char(regime)) & ...
     strcmp(T.policy,char(policy));

if sum(mm)~=1
    error('Could not uniquely find %s / %s.',regime,policy);
end

v = T.(varname)(mm);

end

%% ========================================================================
function write_summary( ...
    output_dir,cfg,tuning,harm_audit, ...
    primary,oracle_decomp,decision)

fid = fopen(fullfile(output_dir,'summary.txt'),'w');

fprintf(fid,'EXP009-C3-B1.3 State-Conditioned Harm-Aware Fallback\n');
fprintf(fid,'====================================================\n\n');

fprintf(fid,'Research hypothesis\n');
fprintf(fid,'-------------------\n');
fprintf(fid,['C3-B1.2 showed asymmetric observability: Beneficial fate ' ...
    'remained difficult within state, while Harmful fate was strongly ' ...
    'observable from q-landscape morphology. C3-B1.3 therefore tests:\n\n']);
fprintf(fid,'  opportunity(state) - harm_risk(morphology)\n\n');
fprintf(fid,['against StateOnly and direct State+feature fusion at exactly ' ...
    'matched computation budgets.\n\n']);

fprintf(fid,'OOF-selected hyperparameters\n');
fprintf(fid,'----------------------------\n');
fprintf(fid,'lambda = %.6f\n',tuning.best_lambda);
fprintf(fid,'veto pH threshold = %.6f\n\n', ...
    tuning.best_veto_threshold);

fprintf(fid,'Harm-risk model audit\n');
fprintf(fid,'---------------------\n');
for i = 1:height(harm_audit)
    fprintf(fid,[ ...
        '%s %s pooledH=%.6f withinH=%.6f validLines=%d\n'], ...
        harm_audit.split{i}, ...
        harm_audit.regime{i}, ...
        harm_audit.pooled_harm_auc(i), ...
        harm_audit.within_line_harm_auc(i), ...
        harm_audit.valid_within_lines(i));
end

fprintf(fid,'\n25%% matched-budget policy comparison\n');
fprintf(fid,'------------------------------------\n');
for i = 1:height(primary)
    fprintf(fid,[ ...
        '%s %-24s recall=%.6f capture=%.6f precision=%.6f ' ...
        'harm=%.6f netUtility=%.6f\n'], ...
        primary.regime{i},primary.policy{i}, ...
        primary.policy_recall(i), ...
        primary.beneficial_capture(i), ...
        primary.benefit_precision(i), ...
        primary.harmful_fraction_among_triggers(i), ...
        primary.net_utility_among_triggers(i));
end

fprintf(fid,'\nOracle-harm decomposition\n');
fprintf(fid,'-------------------------\n');
for i = 1:height(oracle_decomp)
    fprintf(fid,[ ...
        '%s State=%.6f Practical=%.6f HardVeto=%.6f ' ...
        'OracleHarm=%.6f TrialOracle=%.6f\n'], ...
        oracle_decomp.regime{i}, ...
        oracle_decomp.state_recall(i), ...
        oracle_decomp.opportunity_minus_harm_recall(i), ...
        oracle_decomp.hard_veto_recall(i), ...
        oracle_decomp.oracle_harm_veto_recall(i), ...
        oracle_decomp.trial_oracle_recall(i));

    fprintf(fid,[ ...
        '  Perfect harm avoidance explains %.3f of TrialOracle gap.\n'], ...
        oracle_decomp. ...
        fraction_total_gap_explainable_by_perfect_harm_avoidance(i));

    fprintf(fid,[ ...
        '  Practical score captures %.3f of total TrialOracle gap and ' ...
        '%.3f of OracleHarm gain.\n'], ...
        oracle_decomp. ...
        fraction_total_gap_captured_by_practical_score(i), ...
        oracle_decomp. ...
        fraction_oracle_harm_gain_captured_by_practical_score(i));
end

fprintf(fid,'\nDecision summary\n');
fprintf(fid,'----------------\n');
for i = 1:height(decision)
    fprintf(fid,[ ...
        '%s withinH=%.3f | State %.4f -> Practical %.4f ' ...
        '(delta %+0.4f), HardVeto %.4f (delta %+0.4f)\n'], ...
        decision.regime{i}, ...
        decision.test_harm_within_line_auc(i), ...
        decision.recall_stateonly(i), ...
        decision.recall_opportunityMinusHarm(i), ...
        decision.gain_practical_vs_state(i), ...
        decision.recall_opportunityHardVeto(i), ...
        decision.gain_veto_vs_state(i));

    fprintf(fid,[ ...
        '  Harm allocation State %.4f -> Practical %.4f (delta %+0.4f), ' ...
        'HardVeto %.4f (delta %+0.4f)\n'], ...
        decision.harm_fraction_stateonly(i), ...
        decision.harm_fraction_practical(i), ...
        decision.harm_fraction_delta_practical(i), ...
        decision.harm_fraction_veto(i), ...
        decision.harm_fraction_delta_veto(i));
end

fprintf(fid,'\nInterpretation logic\n');
fprintf(fid,'--------------------\n');
fprintf(fid,['1. If OpportunityMinusHarm / HardVeto improves recovery and reduces ' ...
    'harmful allocation at matched cost, the asymmetric policy hypothesis ' ...
    'is supported.\n']);
fprintf(fid,['2. If OracleHarmVeto gives a large gain but the practical policy does ' ...
    'not, the remaining bottleneck is harm-risk estimation.\n']);
fprintf(fid,['3. If OracleHarmVeto itself gives little gain, harm avoidance alone ' ...
    'cannot close the gap; better Beneficial-opportunity observability is ' ...
    'required.\n']);
fprintf(fid,['4. If direct StateAll fusion matches or beats the decomposed policy, ' ...
    'the decomposition remains scientifically informative but not yet ' ...
    'algorithmically advantageous.\n\n']);

fprintf(fid,'Scientific boundary\n');
fprintf(fid,'-------------------\n');
fprintf(fid,['q_strong is still oracle/known because C3-B1.3 isolates weak-stage ' ...
    'allocation logic. This is a mechanism-policy pilot, not yet the final ' ...
    'deployable ship-refocusing method.\n']);

fclose(fid);

end

%% ========================================================================
function make_figures( ...
    output_dir,cfg,tuning, ...
    harm_audit,risk_calibration, ...
    policy_curves,primary, ...
    oracle_decomp,delta_vs_state, ...
    test_smooth,test_abrupt, ...
    pred_smooth,pred_abrupt)

%% Fig 1: OOF lambda sweep
T = tuning.lambda_sweep;

fig = figure('Visible',cfg.figure_visible);
yyaxis left;
plot(T.lambda,T.policy_recall,'-o','LineWidth',1.2);
ylabel('OOF recovery rate');

yyaxis right;
plot(T.lambda,T.harmful_fraction,'-s','LineWidth',1.2);
ylabel('Harmful fraction among triggers');

xlabel('\lambda');
title('C3-B1.3 OOF Opportunity-minus-Harm Tuning');
grid on;

exportgraphics(fig, ...
    fullfile(output_dir,'fig01_lambda_tuning.png'), ...
    'Resolution',180);
close(fig);

%% Fig 2: OOF veto sweep
T = tuning.veto_sweep;
finite = isfinite(T.threshold);

fig = figure('Visible',cfg.figure_visible);
yyaxis left;
plot(T.veto_fraction(finite), ...
     T.policy_recall(finite), ...
     '-o','LineWidth',1.2);
ylabel('OOF recovery rate');

yyaxis right;
plot(T.veto_fraction(finite), ...
     T.harmful_fraction(finite), ...
     '-s','LineWidth',1.2);
ylabel('Harmful fraction among triggers');

xlabel('Fraction classified high-risk');
title('C3-B1.3 OOF Hard-Veto Tuning');
grid on;

exportgraphics(fig, ...
    fullfile(output_dir,'fig02_veto_tuning.png'), ...
    'Resolution',180);
close(fig);

%% Fig 3: 25% recovery
policies = [ ...
    "StateOnly", ...
    "HarmOnlyMorph", ...
    "StateMorphDirect", ...
    "StateAllDirect", ...
    "OpportunityMinusHarm", ...
    "OpportunityHardVeto", ...
    "OracleHarmVeto", ...
    "TrialOracle"];

regimes = ["Smooth","Abrupt"];
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
title('C3-B1.3 Policy Comparison at 25% Budget');
legend(regimes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(output_dir,'fig03_policy_recovery_25pct.png'), ...
    'Resolution',180);
close(fig);

%% Fig 4: 25% harmful allocation
Y = nan(numel(policies),2);

for ip = 1:numel(policies)
    for ir = 1:2
        mm = strcmp(primary.policy,char(policies(ip))) & ...
             strcmp(primary.regime,char(regimes(ir)));

        Y(ip,ir) = ...
            primary.harmful_fraction_among_triggers(mm);
    end
end

fig = figure('Visible',cfg.figure_visible);
bar(Y);

xticks(1:numel(policies));
xticklabels(policies);
xtickangle(30);

ylabel('Harmful fraction among triggered trials');
title('C3-B1.3 Harmful Allocation at 25% Budget');
legend(regimes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(output_dir,'fig04_harmful_allocation_25pct.png'), ...
    'Resolution',180);
close(fig);

%% Fig 5-6: Quality-cost
plot_policies = [ ...
    "StateOnly", ...
    "StateMorphDirect", ...
    "StateAllDirect", ...
    "OpportunityMinusHarm", ...
    "OpportunityHardVeto", ...
    "OracleHarmVeto", ...
    "TrialOracle", ...
    "RandomExpected"];

for ir = 1:2
    regime = regimes(ir);

    fig = figure('Visible',cfg.figure_visible);
    hold on;

    for ip = 1:numel(plot_policies)
        mm = string(policy_curves.regime)==regime & ...
             string(policy_curves.policy)==plot_policies(ip);

        C = policy_curves(mm,:);

        plot(C.normalized_q_search_budget, ...
             C.policy_recall, ...
             'LineWidth',1.2);
    end

    xlabel('Normalized q-search budget');
    ylabel('Weak recovery rate');
    title(sprintf( ...
        'C3-B1.3 %s: Harm-Aware Quality-Cost', ...
        char(regime)));

    legend(plot_policies,'Location','best');
    grid on;

    exportgraphics(fig, ...
        fullfile(output_dir,sprintf( ...
        'fig%02d_%s_quality_cost.png', ...
        4+ir,lower(char(regime)))), ...
        'Resolution',180);

    close(fig);
end

%% Fig 7: Oracle harm decomposition
Y = [ ...
    oracle_decomp.state_recall, ...
    oracle_decomp.opportunity_minus_harm_recall, ...
    oracle_decomp.oracle_harm_veto_recall, ...
    oracle_decomp.trial_oracle_recall];

fig = figure('Visible',cfg.figure_visible);
bar(Y);

xticks(1:height(oracle_decomp));
xticklabels(string(oracle_decomp.regime));

ylabel('Weak recovery rate');
title('C3-B1.3 How Much Can Perfect Harm Avoidance Explain?');

legend( ...
    ["StateOnly","Practical","OracleHarmVeto","TrialOracle"], ...
    'Location','best');

grid on;

exportgraphics(fig, ...
    fullfile(output_dir,'fig07_oracle_harm_decomposition.png'), ...
    'Resolution',180);
close(fig);

%% Fig 8: Delta recall vs StateOnly
fig = figure('Visible',cfg.figure_visible);
hold on;

show_policies = [ ...
    "StateMorphDirect", ...
    "StateAllDirect", ...
    "OpportunityMinusHarm", ...
    "OpportunityHardVeto", ...
    "OracleHarmVeto"];

for ip = 1:numel(show_policies)
    mm = string(delta_vs_state.regime)=="Abrupt" & ...
         string(delta_vs_state.policy)==show_policies(ip);

    T = delta_vs_state(mm,:);

    plot(T.target_budget, ...
         T.recall_delta_vs_state, ...
         'LineWidth',1.2);
end

yline(0,'--');

xlabel('Fallback budget');
ylabel('\Delta recovery vs StateOnly');
title('C3-B1.3 Abrupt: Added Value Beyond StateOnly');

legend(show_policies,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(output_dir,'fig08_abrupt_delta_vs_state.png'), ...
    'Resolution',180);
close(fig);

%% Fig 9-10: State vs harm-risk plane
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
        T.state_prior, ...
        P.pH_morph, ...
        16,class_id,'filled');

    xlabel('Physical-state opportunity prior');
    ylabel('Predicted Harmful risk');
    title(sprintf( ...
        'C3-B1.3 %s Opportunity-Risk Plane', ...
        char(regime)));

    cb = colorbar;
    cb.Ticks = [-1 0 1];
    cb.TickLabels = {'Harmful','Neutral','Beneficial'};

    grid on;

    exportgraphics(fig, ...
        fullfile(output_dir,sprintf( ...
        'fig%02d_%s_opportunity_risk_plane.png', ...
        8+ir,lower(char(regime)))), ...
        'Resolution',180);

    close(fig);
end

%% Fig 11: Harm-risk calibration
fig = figure('Visible',cfg.figure_visible);
hold on;

for ir = 1:2
    regime = regimes(ir);

    T = risk_calibration( ...
        strcmp(risk_calibration.regime,char(regime)),:);

    plot(T.mean_predicted_harm_risk, ...
         T.empirical_harmful_rate, ...
         '-o','LineWidth',1.2);
end

xlabel('Mean predicted Harmful risk');
ylabel('Empirical Harmful rate');
title('C3-B1.3 Harm-Risk Calibration');
legend(regimes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(output_dir,'fig11_harm_risk_calibration.png'), ...
    'Resolution',180);
close(fig);

%% Fig 12: Harm model AUC
Ttest = harm_audit(strcmp(harm_audit.split,'Test'),:);

Y = [ ...
    Ttest.pooled_harm_auc, ...
    Ttest.within_line_harm_auc];

fig = figure('Visible',cfg.figure_visible);
bar(Y);
yline(0.5,'--');
ylim([0.45 1]);

xticks(1:height(Ttest));
xticklabels(string(Ttest.regime));

ylabel('AUC');
title('C3-B1.3 Morphology Harm-Risk Model');

legend(["Pooled","Within-line"],'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(output_dir,'fig12_harm_model_auc.png'), ...
    'Resolution',180);
close(fig);

end

%% ========================================================================
function [aucW,nValid] = weighted_within_line_auc(T,score,label)

score = double(score(:));
label = logical(label(:));

% Regime-aware grouping if combined TRAIN is passed.
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

%% ========================================================================
function q = empirical_quantile(x,p)

x = double(x(:));
x = x(isfinite(x));

if isempty(x)
    q = NaN;
    return;
end

x = sort(x);
p = min(max(double(p),0),1);

if numel(x)==1
    q = x(1);
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

if ~isscalar(q)
    error('empirical_quantile must return a scalar.');
end

end

%% ========================================================================
function edges = quantile_edges_unique(x,nBins)

x = double(x(:));
x = x(isfinite(x));

pp = linspace(0,1,nBins+1);

edges = nan(size(pp));

for i = 1:numel(pp)
    edges(i) = empirical_quantile(x,pp(i));
end

edges = unique(edges,'stable');

if numel(edges)<2
    mn = min(x);
    mx = max(x);

    if abs(mx-mn)<eps
        edges = [mn-0.5,mx+0.5];
    else
        edges = [mn,mx];
    end
end

span = max(1,abs(edges(end)-edges(1)));

edges(1) = edges(1)-1e-12*span;
edges(end) = edges(end)+1e-12*span;

end

%% ========================================================================
function bin_id = assign_bins(x,edges)

x = double(x(:));
edges = double(edges(:).');

B = numel(edges)-1;
bin_id = nan(size(x));

for ib = 1:B
    if ib<B
        mm = x>=edges(ib) & x<edges(ib+1);
    else
        mm = x>=edges(ib) & x<=edges(ib+1);
    end

    bin_id(mm) = ib;
end

end
