function results = exp09c3b1_1_state_realization_complementarity()
%EXP09C3B1_1_STATE_REALIZATION_COMPLEMENTARITY
% EXP009 / Pilot-01 / C3-B1.1
%
% State + Instantaneous Realization Complementarity
%
% -------------------------------------------------------------------------
% Motivation from C3-B1
% -------------------------------------------------------------------------
% C3-B1 established that:
%
%   1) continuous signal parameters generate a highly reproducible
%      line-level fallback-utility state;
%
%   2) EMA only weakly improves trial-level state observability and does
%      not reliably improve matched-budget recovery;
%
%   3) PhysicalStatePrior helps, but remains far below TrialOracle.
%
% Therefore the next question is NOT "how can we make EMA more complex?"
%
% It is:
%
%   Does instantaneous residual evidence contain realization-level
%   information that complements the physical state prior?
%
% Equivalently:
%
%   P(Beneficial | state, instantaneous observables)
%
% versus:
%
%   P(Beneficial | state)
%   P(Beneficial | instantaneous observables)
%
% -------------------------------------------------------------------------
% Experimental principle
% -------------------------------------------------------------------------
% Reuse the independent signal-level TRAIN/TEST trial banks from C3-B1.
% No new signal simulation is needed.
%
% The diagnostic is deliberately nested:
%
%   StateOnly
%       [state prior]
%
%   InstantOnly
%       [prominence risk, entropy risk]
%
%   Additive
%       [state prior, prominence risk, entropy risk]
%
%   Interaction
%       Additive +
%       [state*prominence risk, state*entropy risk]
%
% All four models use the SAME two-headed ridge-logistic architecture:
%
%   pB = P(Beneficial | X)
%   pH = P(Harmful    | X)
%
% and the fallback-value score is:
%
%   V = pB - pH.
%
% Therefore performance differences are attributable primarily to the
% information supplied to the model, not to different model families.
%
% -------------------------------------------------------------------------
% Critical anti-leakage detail
% -------------------------------------------------------------------------
% TRAIN state priors are cross-fitted by sequence:
%
%   the state prior assigned to a TRAIN realization excludes that
%   realization's own sequence outcome from the line-level utility curve.
%
% TEST state priors use the full TRAIN line-level utility curve and NEVER
% use TEST labels.
%
% -------------------------------------------------------------------------
% Main diagnostics
% -------------------------------------------------------------------------
% 1. Pooled Beneficial / Harmful AUC.
% 2. Weighted within-line AUC:
%       Can instantaneous features distinguish realization fate when
%       physical line/state is held fixed?
% 3. Matched-budget Weak Recovery / Beneficial Capture / Harm.
% 4. Fraction of TrialOracle selection advantage captured.
% 5. State-bin conditional AUC:
%       Does realization evidence remain useful across risk states?
%
% Run:
%   results = exp09c3b1_1_state_realization_complementarity;

cfg = config_exp09c3b1_1();

rng(cfg.seed,'twister');

%% Resolve directories
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.c3b1_result_dir)
    c3b1_dir = fullfile( ...
        paper_root,'results','exp09_pilot01', ...
        'exp09c3b1_signal_level_continuous_state');
else
    c3b1_dir = cfg.c3b1_result_dir;
end

if isempty(cfg.output_dir)
    out_dir = fullfile( ...
        paper_root,'results','exp09_pilot01', ...
        'exp09c3b1_1_state_realization_complementarity');
else
    out_dir = cfg.output_dir;
end

if ~exist(out_dir,'dir')
    mkdir(out_dir);
end

fprintf('\n============================================================\n');
fprintf(' EXP009-C3-B1.1 / State + Realization Complementarity\n');
fprintf('============================================================\n');
fprintf('Input : %s\n',c3b1_dir);
fprintf('Output: %s\n\n',out_dir);

%% Load C3-B1 trial banks
train_smooth = readtable(fullfile(c3b1_dir,'train_trials_smooth.csv'));
train_abrupt = readtable(fullfile(c3b1_dir,'train_trials_abrupt.csv'));
test_smooth  = readtable(fullfile(c3b1_dir,'test_trials_smooth.csv'));
test_abrupt  = readtable(fullfile(c3b1_dir,'test_trials_abrupt.csv'));

required = { ...
    'sequence_id','line_index', ...
    'weak_ratio','signed_sep','q_strong', ...
    'cheap_prominence','cheap_entropy', ...
    'cheap_success','fallback_success', ...
    'beneficial','harmful'};

assert_table_vars(train_smooth,required,'train_trials_smooth.csv');
assert_table_vars(train_abrupt,required,'train_trials_abrupt.csv');
assert_table_vars(test_smooth,required,'test_trials_smooth.csv');
assert_table_vars(test_abrupt,required,'test_trials_abrupt.csv');

train_smooth.regime = repmat("Smooth",height(train_smooth),1);
train_abrupt.regime = repmat("Abrupt",height(train_abrupt),1);
test_smooth.regime  = repmat("Smooth",height(test_smooth),1);
test_abrupt.regime  = repmat("Abrupt",height(test_abrupt),1);

%% Signed fallback utility label
% +1 Beneficial, -1 Harmful, 0 Neutral.
train_smooth.signed_value = ...
    double(train_smooth.fallback_success) - ...
    double(train_smooth.cheap_success);

train_abrupt.signed_value = ...
    double(train_abrupt.fallback_success) - ...
    double(train_abrupt.cheap_success);

test_smooth.signed_value = ...
    double(test_smooth.fallback_success) - ...
    double(test_smooth.cheap_success);

test_abrupt.signed_value = ...
    double(test_abrupt.fallback_success) - ...
    double(test_abrupt.cheap_success);

%% ------------------------------------------------------------------------
% Cross-fitted physical-state prior
[train_smooth,test_smooth,state_smooth] = ...
    attach_crossfit_state_prior( ...
    train_smooth,test_smooth,cfg);

[train_abrupt,test_abrupt,state_abrupt] = ...
    attach_crossfit_state_prior( ...
    train_abrupt,test_abrupt,cfg);

state_smooth.regime = repmat("Smooth",height(state_smooth),1);
state_abrupt.regime = repmat("Abrupt",height(state_abrupt),1);

state_repro = [state_smooth;state_abrupt];
state_repro = movevars(state_repro,'regime','Before',1);

writetable(state_repro, ...
    fullfile(out_dir,'state_prior_reproducibility.csv'));

rho_state_smooth = spearman_manual( ...
    state_smooth.train_state_prior_full, ...
    state_smooth.test_state_utility);

rho_state_abrupt = spearman_manual( ...
    state_abrupt.train_state_prior_full, ...
    state_abrupt.test_state_utility);

%% ------------------------------------------------------------------------
% Instantaneous risk transforms
% Feature calibration uses pooled TRAIN features only; no outcome labels.
train_all0 = [train_smooth;train_abrupt];

calib = build_instant_calibration(train_all0);

train_smooth = add_instant_risk_features(train_smooth,calib);
train_abrupt = add_instant_risk_features(train_abrupt,calib);
test_smooth = add_instant_risk_features(test_smooth,calib);
test_abrupt = add_instant_risk_features(test_abrupt,calib);

train_all = [train_smooth;train_abrupt];

%% Build nested feature sets and fit identical model family
model_names = string(cfg.model_names(:));
nModels = numel(model_names);

models = cell(nModels,1);
feature_name_cell = cell(nModels,1);

% Prediction containers
train_pred = struct();
smooth_pred = struct();
abrupt_pred = struct();

coef_rows = {};

for im = 1:nModels
    name = model_names(im);

    [Xtr,feature_names] = build_feature_matrix(train_all,name);
    [Xs,~] = build_feature_matrix(test_smooth,name);
    [Xa,~] = build_feature_matrix(test_abrupt,name);

    mdl = fit_two_head_value_model( ...
        Xtr, ...
        logical(train_all.beneficial), ...
        logical(train_all.harmful), ...
        cfg);

    models{im} = mdl;
    feature_name_cell{im} = feature_names;

    Ptr = predict_two_head_value(mdl,Xtr);
    Ps = predict_two_head_value(mdl,Xs);
    Pa = predict_two_head_value(mdl,Xa);

    key = char(name);

    train_pred.(key) = Ptr;
    smooth_pred.(key) = Ps;
    abrupt_pred.(key) = Pa;

    % Coefficients on standardized feature scale.
    coef_names = ["Intercept";string(feature_names(:))];

    for j = 1:numel(coef_names)
        coef_rows(end+1,:) = { ... %#ok<AGROW>
            key,char(coef_names(j)), ...
            mdl.betaB(j),mdl.betaH(j)};
    end
end

coef_table = cell2table(coef_rows, ...
    'VariableNames',{ ...
    'model','term','beta_beneficial','beta_harmful'});

writetable(coef_table, ...
    fullfile(out_dir,'model_coefficients.csv'));

%% Add predictions to TEST tables for audit
for im = 1:nModels
    key = char(model_names(im));

    test_smooth.([key '_pB']) = smooth_pred.(key).pB;
    test_smooth.([key '_pH']) = smooth_pred.(key).pH;
    test_smooth.([key '_value']) = smooth_pred.(key).value;

    test_abrupt.([key '_pB']) = abrupt_pred.(key).pB;
    test_abrupt.([key '_pH']) = abrupt_pred.(key).pH;
    test_abrupt.([key '_value']) = abrupt_pred.(key).value;
end

writetable(test_smooth, ...
    fullfile(out_dir,'test_predictions_smooth.csv'));

writetable(test_abrupt, ...
    fullfile(out_dir,'test_predictions_abrupt.csv'));

%% ------------------------------------------------------------------------
% Model information audit
metrics = table();

for ir = 1:2
    if ir==1
        T = test_smooth;
        Pred = smooth_pred;
        regime = "Smooth";
    else
        T = test_abrupt;
        Pred = abrupt_pred;
        regime = "Abrupt";
    end

    for im = 1:nModels
        key = char(model_names(im));
        P = Pred.(key);

        aucB = binary_auc(T.beneficial,P.pB);
        aucH = binary_auc(T.harmful,P.pH);

        utility_rho = spearman_manual( ...
            P.value,T.signed_value);

        [withinB,nValidB] = ...
            weighted_within_line_auc( ...
            T,P.pB,T.beneficial);

        [withinH,nValidH] = ...
            weighted_within_line_auc( ...
            T,P.pH,T.harmful);

        row = table( ...
            regime,model_names(im), ...
            aucB,aucH,utility_rho, ...
            withinB,withinH,nValidB,nValidH, ...
            'VariableNames',{ ...
            'regime','model', ...
            'beneficial_auc','harmful_auc', ...
            'signed_utility_spearman', ...
            'within_line_beneficial_auc', ...
            'within_line_harmful_auc', ...
            'valid_lines_beneficial_auc', ...
            'valid_lines_harmful_auc'});

        metrics = [metrics;row]; %#ok<AGROW>
    end
end

writetable(metrics, ...
    fullfile(out_dir,'model_information_audit.csv'));

%% ------------------------------------------------------------------------
% Conditional AUC by state bin
state_bin_auc = table();

for ir = 1:2
    if ir==1
        Ttr = train_smooth;
        Tte = test_smooth;
        Pred = smooth_pred;
        regime = "Smooth";
    else
        Ttr = train_abrupt;
        Tte = test_abrupt;
        Pred = abrupt_pred;
        regime = "Abrupt";
    end

    edges = quantile_edges_unique( ...
        Ttr.state_prior,cfg.num_state_bins);

    bin_id = assign_bins( ...
        Tte.state_prior,edges);

    for ib = 1:(numel(edges)-1)
        mm = bin_id==ib;

        for im = 1:nModels
            key = char(model_names(im));
            P = Pred.(key);

            if sum(mm)>=2
                aucB = binary_auc( ...
                    Tte.beneficial(mm),P.pB(mm));

                aucH = binary_auc( ...
                    Tte.harmful(mm),P.pH(mm));
            else
                aucB = NaN;
                aucH = NaN;
            end

            row = table( ...
                regime,model_names(im),ib, ...
                edges(ib),edges(ib+1), ...
                sum(mm),mean(Tte.state_prior(mm),'omitnan'), ...
                aucB,aucH, ...
                'VariableNames',{ ...
                'regime','model','state_bin', ...
                'state_low','state_high','n_trials', ...
                'mean_state_prior', ...
                'beneficial_auc','harmful_auc'});

            state_bin_auc = [state_bin_auc;row]; %#ok<AGROW>
        end
    end
end

writetable(state_bin_auc, ...
    fullfile(out_dir,'state_bin_conditional_auc.csv'));

%% ------------------------------------------------------------------------
% Policy curves: same train-calibrated budget convention as C3-B1
budget_curves = table();

for ir = 1:2
    if ir==1
        Ttr = train_smooth;
        Tte = test_smooth;
        regime = "Smooth";

        % Need train predictions on the corresponding regime subset.
        mask_tr = train_all.regime=="Smooth";
        PredTrainAll = train_pred;
        PredTest = smooth_pred;
    else
        Ttr = train_abrupt;
        Tte = test_abrupt;
        regime = "Abrupt";

        mask_tr = train_all.regime=="Abrupt";
        PredTrainAll = train_pred;
        PredTest = abrupt_pred;
    end

    for im = 1:nModels
        key = char(model_names(im));

        score_train = PredTrainAll.(key).value(mask_tr);
        score_test = PredTest.(key).value;

        C = evaluate_policy_curve( ...
            Ttr,Tte,score_train,score_test,cfg.budget_grid);

        C.regime = repmat(regime,height(C),1);
        C.policy = repmat(model_names(im),height(C),1);

        budget_curves = [budget_curves;C]; %#ok<AGROW>
    end

    % Direct state prior: useful reference independent of the logistic head.
    Csp = evaluate_policy_curve( ...
        Ttr,Tte,Ttr.state_prior,Tte.state_prior,cfg.budget_grid);

    Csp.regime = repmat(regime,height(Csp),1);
    Csp.policy = repmat("StatePriorDirect",height(Csp),1);

    % Legacy PE risk from C3-B1.
    Cpe = evaluate_policy_curve( ...
        Ttr,Tte,Ttr.legacy_instant_risk,Tte.legacy_instant_risk, ...
        cfg.budget_grid);

    Cpe.regime = repmat(regime,height(Cpe),1);
    Cpe.policy = repmat("LegacyInstantPE",height(Cpe),1);

    Cto = trial_oracle_curve(Tte,cfg.budget_grid);
    Cto.regime = repmat(regime,height(Cto),1);
    Cto.policy = repmat("TrialOracle",height(Cto),1);

    Cr = random_expected_curve(Tte,cfg.budget_grid);
    Cr.regime = repmat(regime,height(Cr),1);
    Cr.policy = repmat("RandomExpected",height(Cr),1);

    budget_curves = [budget_curves;Csp;Cpe;Cto;Cr]; %#ok<AGROW>
end

budget_curves = movevars( ...
    budget_curves,{'regime','policy'},'Before',1);

writetable(budget_curves, ...
    fullfile(out_dir,'complementarity_budget_curves.csv'));

%% Highlighted budget points
reported = extract_reported_budget_points( ...
    budget_curves,cfg.report_budgets);

writetable(reported, ...
    fullfile(out_dir,'reported_budget_points.csv'));

%% ------------------------------------------------------------------------
% Oracle-gap capture
oracle_gap = compute_oracle_gap_capture( ...
    reported,cfg.report_budgets);

writetable(oracle_gap, ...
    fullfile(out_dir,'oracle_gap_capture.csv'));

%% Complementarity summary
comp = compute_complementarity_summary( ...
    metrics,reported,oracle_gap,cfg);

writetable(comp, ...
    fullfile(out_dir,'complementarity_summary.csv'));

%% Calibration / value deciles for Interaction
value_calibration = table();

for ir = 1:2
    if ir==1
        T = test_smooth;
        P = smooth_pred.Interaction;
        regime = "Smooth";
    else
        T = test_abrupt;
        P = abrupt_pred.Interaction;
        regime = "Abrupt";
    end

    C = value_score_calibration( ...
        P.value,T.signed_value,10);

    C.regime = repmat(regime,height(C),1);

    value_calibration = [value_calibration;C]; %#ok<AGROW>
end

value_calibration = movevars( ...
    value_calibration,'regime','Before',1);

writetable(value_calibration, ...
    fullfile(out_dir,'interaction_value_calibration.csv'));

%% Console summary
fprintf('================ C3-B1.1 STATE REPRODUCIBILITY ==============\n');
fprintf('Smooth rho(train state, test utility) = %.3f\n',rho_state_smooth);
fprintf('Abrupt rho(train state, test utility) = %.3f\n',rho_state_abrupt);

fprintf('\n================ C3-B1.1 INFORMATION AUDIT ===================\n');
disp(metrics);

fprintf('\n================ C3-B1.1 25%% BUDGET =========================\n');
rows25 = reported(abs(reported.target_budget-0.25)<1e-12,:);
disp(rows25(:,{ ...
    'regime','policy','actual_trigger_rate', ...
    'policy_recall','beneficial_capture', ...
    'benefit_precision','harmful_fraction_among_triggers'}));

fprintf('\n================ C3-B1.1 COMPLEMENTARITY =====================\n');
disp(comp);
fprintf('==============================================================\n');

%% Summary text
write_summary( ...
    out_dir,cfg,rho_state_smooth,rho_state_abrupt, ...
    metrics,reported,oracle_gap,comp);

%% Figures
make_figures( ...
    out_dir,cfg,metrics,state_bin_auc, ...
    budget_curves,reported,oracle_gap, ...
    value_calibration,test_smooth,test_abrupt);

%% Save
results = struct();
results.cfg = cfg;
results.state_repro = state_repro;
results.metrics = metrics;
results.state_bin_auc = state_bin_auc;
results.budget_curves = budget_curves;
results.reported = reported;
results.oracle_gap = oracle_gap;
results.complementarity = comp;
results.value_calibration = value_calibration;
results.models = models;
results.feature_names = feature_name_cell;

save(fullfile(out_dir,'exp09c3b1_1_results.mat'), ...
    'results','-v7.3');

fprintf('\nSaved EXP009-C3-B1.1 outputs to:\n%s\n\n',out_dir);

end

%% ========================================================================
function [Ttrain,Ttest,S] = attach_crossfit_state_prior( ...
    Ttrain,Ttest,cfg)

lines = unique(Ttrain.line_index).';
seqs = unique(Ttrain.sequence_id).';

L = numel(lines);
M = numel(seqs);

if M<2
    error('Cross-fitted state prior requires at least two TRAIN sequences.');
end

% Y(s,k) is signed fallback utility for TRAIN sequence s, line k.
Y = nan(M,L);

for is = 1:M
    sid = seqs(is);

    for ik = 1:L
        k = lines(ik);

        idx = find( ...
            Ttrain.sequence_id==sid & ...
            Ttrain.line_index==k);

        if numel(idx)~=1
            error(['Expected exactly one TRAIN row for sequence %g, ' ...
                'line %g; found %d.'],sid,k,numel(idx));
        end

        Y(is,ik) = double(Ttrain.signed_value(idx));
    end
end

train_raw = mean(Y,1).';
train_full = moving_average_shrink( ...
    train_raw,cfg.state_utility_smooth_window);

% Independent TEST line utility for reproducibility diagnostics only.
test_raw = nan(L,1);

for ik = 1:L
    k = lines(ik);
    mm = Ttest.line_index==k;

    if ~any(mm)
        error('TEST bank missing line %g.',k);
    end

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

    cf_raw = ((sumY - Y(is,:))/(M-1)).';

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

% TEST state prior uses all TRAIN sequences and no TEST labels.
Ttest.state_prior = nan(height(Ttest),1);

for ik = 1:L
    k = lines(ik);

    mm = Ttest.line_index==k;
    Ttest.state_prior(mm) = train_full(ik);
end

% Diagnostic physical parameters.
weak_ratio = nan(L,1);
signed_sep = nan(L,1);

for ik = 1:L
    k = lines(ik);
    mm = Ttrain.line_index==k;

    weak_ratio(ik) = scalar_unique( ...
        Ttrain.weak_ratio(mm), ...
        sprintf('weak_ratio line %g',k));

    signed_sep(ik) = scalar_unique( ...
        Ttrain.signed_sep(mm), ...
        sprintf('signed_sep line %g',k));
end

line_index = lines(:);
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
function calib = build_instant_calibration(T)

p = double(T.cheap_prominence(:));
e = double(T.cheap_entropy(:));

p = p(isfinite(p));
e = e(isfinite(e));

if isempty(p) || isempty(e)
    error('No finite instantaneous observables for calibration.');
end

calib.prom_sorted = sort(p);
calib.ent_sorted = sort(e);

end

%% ========================================================================
function T = add_instant_risk_features(T,calib)

N = height(T);

risk_prom = nan(N,1);
risk_entropy = nan(N,1);

for i = 1:N
    Fp = empirical_cdf_value( ...
        calib.prom_sorted,double(T.cheap_prominence(i)));

    Fe = empirical_cdf_value( ...
        calib.ent_sorted,double(T.cheap_entropy(i)));

    risk_prom(i) = 1-Fp;
    risk_entropy(i) = Fe;
end

T.risk_prominence = min(max(risk_prom,0),1);
T.risk_entropy = min(max(risk_entropy,0),1);

T.legacy_instant_risk = ...
    0.5*(T.risk_prominence+T.risk_entropy);

end

%% ========================================================================
function F = empirical_cdf_value(sorted_x,x)

sorted_x = double(sorted_x(:));

if isempty(sorted_x) || ~isfinite(x)
    F = 0.5;
    return;
end

N = numel(sorted_x);

nLess = sum(sorted_x<x);
nEq = sum(sorted_x==x);

F = (nLess+0.5*nEq)/N;
F = min(max(F,0),1);

if ~isscalar(F)
    error('empirical_cdf_value must return a scalar.');
end

end

%% ========================================================================
function [X,names] = build_feature_matrix(T,model_name)

state = double(T.state_prior(:));
rp = double(T.risk_prominence(:));
re = double(T.risk_entropy(:));

switch string(model_name)
    case "StateOnly"
        X = state;
        names = {'state_prior'};

    case "InstantOnly"
        X = [rp,re];
        names = {'risk_prominence','risk_entropy'};

    case "Additive"
        X = [state,rp,re];
        names = { ...
            'state_prior', ...
            'risk_prominence', ...
            'risk_entropy'};

    case "Interaction"
        X = [ ...
            state,rp,re, ...
            state.*rp, ...
            state.*re];

        names = { ...
            'state_prior', ...
            'risk_prominence', ...
            'risk_entropy', ...
            'state_x_risk_prominence', ...
            'state_x_risk_entropy'};

    otherwise
        error('Unknown model: %s',string(model_name));
end

if size(X,1)~=height(T)
    error('Feature matrix row count does not match table height.');
end

if any(~isfinite(X(:)))
    error('Feature matrix contains non-finite values.');
end

end

%% ========================================================================
function mdl = fit_two_head_value_model(X,yB,yH,cfg)

X = double(X);
yB = double(logical(yB(:)));
yH = double(logical(yH(:)));

if size(X,1)~=numel(yB) || numel(yB)~=numel(yH)
    error('Feature/label dimensions are inconsistent.');
end

mu = mean(X,1);
sigma = std(X,0,1);

sigma(~isfinite(sigma) | sigma<1e-12) = 1;

Xz = bsxfun(@rdivide, ...
    bsxfun(@minus,X,mu),sigma);

betaB = fit_ridge_logistic_irls( ...
    Xz,yB,cfg.ridge_lambda, ...
    cfg.irls_max_iter,cfg.irls_tol,cfg.prob_clip);

betaH = fit_ridge_logistic_irls( ...
    Xz,yH,cfg.ridge_lambda, ...
    cfg.irls_max_iter,cfg.irls_tol,cfg.prob_clip);

mdl = struct();
mdl.mu = mu;
mdl.sigma = sigma;
mdl.betaB = betaB;
mdl.betaH = betaH;
mdl.lambda = cfg.ridge_lambda;

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
        error('Non-finite logistic Newton step.');
    end

    beta_new = beta-step;

    if norm(beta_new-beta) <= ...
            tol*(1+norm(beta))
        beta = beta_new;
        return;
    end

    beta = beta_new;
end

end

%% ========================================================================
function P = predict_two_head_value(mdl,X)

X = double(X);

if size(X,2)~=numel(mdl.mu)
    error('Prediction feature dimension mismatch.');
end

Xz = bsxfun(@rdivide, ...
    bsxfun(@minus,X,mdl.mu),mdl.sigma);

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
function [aucW,nValid] = weighted_within_line_auc(T,score,label)

score = double(score(:));
label = logical(label(:));

lines = unique(T.line_index).';

auc_num = 0;
weight_sum = 0;
nValid = 0;

for ik = 1:numel(lines)
    mm = T.line_index==lines(ik);

    y = label(mm);
    s = score(mm);

    nPos = sum(y);
    nNeg = sum(~y);

    if nPos>0 && nNeg>0
        a = binary_auc(y,s);

        % Pair-count weighting matches the amount of ranking information
        % available within each fixed physical state.
        w = nPos*nNeg;

        auc_num = auc_num + w*a;
        weight_sum = weight_sum + w;
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
function edges = quantile_edges_unique(x,nBins)

x = double(x(:));
x = x(isfinite(x));

if isempty(x)
    error('No finite state-prior values for binning.');
end

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

% Open the end points slightly so every finite sample is assigned.
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

%% ========================================================================
function C = evaluate_policy_curve( ...
    Ttrain,Ttest,score_train,score_test,budgets)

score_train = add_tiebreak( ...
    score_train,Ttrain);

score_test = add_tiebreak( ...
    score_test,Ttest);

budgets = double(budgets(:));
nB = numel(budgets);

target_budget = budgets;
actual_trigger_rate = nan(nB,1);
policy_recall = nan(nB,1);
beneficial_capture = nan(nB,1);
benefit_precision = nan(nB,1);
harmful_fraction_among_triggers = nan(nB,1);
normalized_q_search_budget = nan(nB,1);

cheap = logical(Ttest.cheap_success(:));
fallback = logical(Ttest.fallback_success(:));
beneficial = logical(Ttest.beneficial(:));
harmful = logical(Ttest.harmful(:));

nBeneficial = sum(beneficial);

for ib = 1:nB
    b = budgets(ib);

    if b<=0
        trigger = false(size(score_test));
    elseif b>=1
        trigger = true(size(score_test));
    else
        thr = empirical_quantile(score_train,1-b);
        trigger = score_test>=thr;
    end

    actual_trigger_rate(ib) = mean(trigger);

    out = cheap;
    out(trigger) = fallback(trigger);

    policy_recall(ib) = mean(out);

    if nBeneficial>0
        beneficial_capture(ib) = ...
            sum(trigger & beneficial)/nBeneficial;
    end

    nTrig = sum(trigger);

    if nTrig>0
        benefit_precision(ib) = ...
            sum(trigger & beneficial)/nTrig;

        harmful_fraction_among_triggers(ib) = ...
            sum(trigger & harmful)/nTrig;
    end

    normalized_q_search_budget(ib) = ...
        1+actual_trigger_rate(ib);
end

C = table( ...
    target_budget,actual_trigger_rate,policy_recall, ...
    beneficial_capture,benefit_precision, ...
    harmful_fraction_among_triggers, ...
    normalized_q_search_budget);

end

%% ========================================================================
function score = add_tiebreak(score,T)

score = double(score(:));

if numel(score)~=height(T)
    error('Score length does not match table height.');
end

if ismember('allocation_tiebreak',T.Properties.VariableNames)
    tb = double(T.allocation_tiebreak(:));

    if numel(tb)~=numel(score)
        error('allocation_tiebreak length mismatch.');
    end

    score = score + 1e-9*(tb-0.5);
end

end

%% ========================================================================
function C = trial_oracle_curve(Ttest,budgets)

budgets = double(budgets(:));

cheap_recall = mean(Ttest.cheap_success);
benefit_rate = mean(Ttest.beneficial);

nB = numel(budgets);

target_budget = budgets;
actual_trigger_rate = nan(nB,1);
policy_recall = nan(nB,1);
beneficial_capture = nan(nB,1);
benefit_precision = nan(nB,1);
harmful_fraction_among_triggers = zeros(nB,1);
normalized_q_search_budget = nan(nB,1);

for ib = 1:nB
    used = min(max(budgets(ib),0),benefit_rate);

    actual_trigger_rate(ib) = used;
    policy_recall(ib) = cheap_recall+used;

    if benefit_rate>0
        beneficial_capture(ib) = min(1,used/benefit_rate);
    end

    if used>0
        benefit_precision(ib) = 1;
    end

    normalized_q_search_budget(ib) = 1+used;
end

C = table( ...
    target_budget,actual_trigger_rate,policy_recall, ...
    beneficial_capture,benefit_precision, ...
    harmful_fraction_among_triggers, ...
    normalized_q_search_budget);

end

%% ========================================================================
function C = random_expected_curve(Ttest,budgets)

budgets = double(budgets(:));

cheap_recall = mean(Ttest.cheap_success);
benefit_rate = mean(Ttest.beneficial);
harm_rate = mean(Ttest.harmful);

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

benefit_precision(budgets==0) = NaN;
harmful_fraction_among_triggers(budgets==0) = NaN;

normalized_q_search_budget = 1+budgets;

C = table( ...
    target_budget,actual_trigger_rate,policy_recall, ...
    beneficial_capture,benefit_precision, ...
    harmful_fraction_among_triggers, ...
    normalized_q_search_budget);

end

%% ========================================================================
function R = extract_reported_budget_points(C,budgets)

budgets = double(budgets(:));

regimes = unique(C.regime,'stable');
policies = unique(C.policy,'stable');

rows = {};

for ir = 1:numel(regimes)
    for ip = 1:numel(policies)
        Cp = C( ...
            C.regime==regimes(ir) & ...
            C.policy==policies(ip),:);

        if isempty(Cp)
            continue;
        end

        for ib = 1:numel(budgets)
            b = budgets(ib);
            [~,ii] = min(abs(Cp.target_budget-b));

            rows(end+1,:) = { ... %#ok<AGROW>
                char(regimes(ir)), ...
                char(policies(ip)), ...
                b, ...
                Cp.actual_trigger_rate(ii), ...
                Cp.policy_recall(ii), ...
                Cp.beneficial_capture(ii), ...
                Cp.benefit_precision(ii), ...
                Cp.harmful_fraction_among_triggers(ii), ...
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
    'normalized_q_search_budget'});

end

%% ========================================================================
function G = compute_oracle_gap_capture(R,budgets)

budgets = double(budgets(:));

primary = ["StateOnly","InstantOnly","Additive","Interaction", ...
           "StatePriorDirect","LegacyInstantPE"];

regimes = ["Smooth","Abrupt"];

rows = {};

for ir = 1:numel(regimes)
    regime = regimes(ir);

    for ib = 1:numel(budgets)
        b = budgets(ib);

        rr = get_reported_recall(R,regime,"RandomExpected",b);
        ro = get_reported_recall(R,regime,"TrialOracle",b);

        denom = ro-rr;

        for ip = 1:numel(primary)
            pol = primary(ip);

            if ~any(strcmp(R.policy,char(pol)) & ...
                    strcmp(R.regime,char(regime)))
                continue;
            end

            rm = get_reported_recall(R,regime,pol,b);

            if abs(denom)<eps
                frac = NaN;
            else
                frac = (rm-rr)/denom;
            end

            rows(end+1,:) = { ... %#ok<AGROW>
                char(regime),char(pol),b, ...
                rr,rm,ro,frac};
        end
    end
end

G = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','policy','target_budget', ...
    'random_recall','model_recall','oracle_recall', ...
    'oracle_selection_advantage_fraction'});

end

%% ========================================================================
function r = get_reported_recall(R,regime,policy,budget)

mm = strcmp(R.regime,char(regime)) & ...
     strcmp(R.policy,char(policy)) & ...
     abs(R.target_budget-budget)<1e-12;

if sum(mm)~=1
    error('Could not uniquely locate reported recall.');
end

r = R.policy_recall(mm);

end

%% ========================================================================
function C = compute_complementarity_summary( ...
    metrics,reported,oracle_gap,cfg)

regimes = ["Smooth","Abrupt"];

rows = {};

for ir = 1:numel(regimes)
    regime = regimes(ir);

    mState = get_metric_row(metrics,regime,"StateOnly");
    mInst  = get_metric_row(metrics,regime,"InstantOnly");
    mAdd   = get_metric_row(metrics,regime,"Additive");
    mInt   = get_metric_row(metrics,regime,"Interaction");

    b = cfg.tune_budget;

    rState = get_reported_recall( ...
        reported,regime,"StateOnly",b);

    rInst = get_reported_recall( ...
        reported,regime,"InstantOnly",b);

    rAdd = get_reported_recall( ...
        reported,regime,"Additive",b);

    rInt = get_reported_recall( ...
        reported,regime,"Interaction",b);

    gState = get_gap_fraction( ...
        oracle_gap,regime,"StateOnly",b);

    gInst = get_gap_fraction( ...
        oracle_gap,regime,"InstantOnly",b);

    gAdd = get_gap_fraction( ...
        oracle_gap,regime,"Additive",b);

    gInt = get_gap_fraction( ...
        oracle_gap,regime,"Interaction",b);

    rows(end+1,:) = { ... %#ok<AGROW>
        char(regime), ...
        mState.beneficial_auc, ...
        mInst.beneficial_auc, ...
        mAdd.beneficial_auc, ...
        mInt.beneficial_auc, ...
        mAdd.beneficial_auc - ...
            max(mState.beneficial_auc,mInst.beneficial_auc), ...
        mInt.beneficial_auc-mAdd.beneficial_auc, ...
        mInst.within_line_beneficial_auc, ...
        mAdd.within_line_beneficial_auc, ...
        mInt.within_line_beneficial_auc, ...
        rState,rInst,rAdd,rInt, ...
        rAdd-max(rState,rInst), ...
        rInt-rAdd, ...
        gState,gInst,gAdd,gInt};
end

C = cell2table(rows, ...
    'VariableNames',{ ...
    'regime', ...
    'auc_state','auc_instant','auc_additive','auc_interaction', ...
    'auc_additive_gain_over_best_single', ...
    'auc_interaction_gain_over_additive', ...
    'within_line_auc_instant', ...
    'within_line_auc_additive', ...
    'within_line_auc_interaction', ...
    'recall25_state','recall25_instant', ...
    'recall25_additive','recall25_interaction', ...
    'recall25_additive_gain_over_best_single', ...
    'recall25_interaction_gain_over_additive', ...
    'oracle_fraction_state','oracle_fraction_instant', ...
    'oracle_fraction_additive','oracle_fraction_interaction'});

end

%% ========================================================================
function row = get_metric_row(M,regime,model)

mm = M.regime==regime & M.model==model;

if sum(mm)~=1
    error('Could not uniquely locate model metric row.');
end

row = M(mm,:);

end

%% ========================================================================
function f = get_gap_fraction(G,regime,policy,budget)

mm = strcmp(G.regime,char(regime)) & ...
     strcmp(G.policy,char(policy)) & ...
     abs(G.target_budget-budget)<1e-12;

if sum(mm)~=1
    error('Could not uniquely locate oracle-gap fraction.');
end

f = G.oracle_selection_advantage_fraction(mm);

end

%% ========================================================================
function C = value_score_calibration(score,y,nBins)

score = double(score(:));
y = double(y(:));

edges = quantile_edges_unique(score,nBins);
bin_id = assign_bins(score,edges);

B = numel(edges)-1;

bin_index = (1:B).';
score_low = edges(1:end-1).';
score_high = edges(2:end).';

n_trials = zeros(B,1);
mean_predicted_value = nan(B,1);
empirical_signed_value = nan(B,1);
beneficial_rate = nan(B,1);
harmful_rate = nan(B,1);

for ib = 1:B
    mm = bin_id==ib;

    n_trials(ib) = sum(mm);

    if n_trials(ib)>0
        mean_predicted_value(ib) = mean(score(mm),'omitnan');
        empirical_signed_value(ib) = mean(y(mm),'omitnan');
        beneficial_rate(ib) = mean(y(mm)==1);
        harmful_rate(ib) = mean(y(mm)==-1);
    end
end

C = table( ...
    bin_index,score_low,score_high,n_trials, ...
    mean_predicted_value,empirical_signed_value, ...
    beneficial_rate,harmful_rate);

end

%% ========================================================================
function write_summary( ...
    out_dir,cfg,rho_s,rho_a,metrics,reported,oracle_gap,comp)

fid = fopen(fullfile(out_dir,'summary.txt'),'w');

fprintf(fid,'EXP009-C3-B1.1 State + Instantaneous Realization Complementarity\n');
fprintf(fid,'================================================================\n\n');

fprintf(fid,'Research question\n');
fprintf(fid,'-----------------\n');
fprintf(fid,['Does instantaneous residual evidence contain useful ' ...
    'within-state realization information beyond the signal-generated ' ...
    'physical state prior?\n\n']);

fprintf(fid,'State-prior construction\n');
fprintf(fid,'------------------------\n');
fprintf(fid,['TRAIN state priors are leave-one-sequence-out cross-fitted. ' ...
    'TEST state priors use only TRAIN outcomes. No TEST label enters ' ...
    'state construction.\n\n']);

fprintf(fid,'State reproducibility\n');
fprintf(fid,'---------------------\n');
fprintf(fid,'Smooth rho(train state, test utility): %.6f\n',rho_s);
fprintf(fid,'Abrupt rho(train state, test utility): %.6f\n\n',rho_a);

fprintf(fid,'Model architecture\n');
fprintf(fid,'------------------\n');
fprintf(fid,['All feature sets use the same two-headed ridge logistic model: ' ...
    'pB=P(Beneficial|X), pH=P(Harmful|X), value=pB-pH.\n']);
fprintf(fid,'Fixed ridge lambda: %.6f\n\n',cfg.ridge_lambda);

fprintf(fid,'Information audit\n');
fprintf(fid,'-----------------\n');

for i = 1:height(metrics)
    fprintf(fid,[ ...
        '%s %s aucB=%.6f aucH=%.6f utilityRho=%.6f ' ...
        'withinLineAucB=%.6f withinLineAucH=%.6f\n'], ...
        char(metrics.regime(i)), ...
        char(metrics.model(i)), ...
        metrics.beneficial_auc(i), ...
        metrics.harmful_auc(i), ...
        metrics.signed_utility_spearman(i), ...
        metrics.within_line_beneficial_auc(i), ...
        metrics.within_line_harmful_auc(i));
end

fprintf(fid,'\n25%% budget\n');
fprintf(fid,'----------\n');

rows25 = reported(abs(reported.target_budget-0.25)<1e-12,:);

for i = 1:height(rows25)
    fprintf(fid,[ ...
        '%s %s actual=%.6f recall=%.6f capture=%.6f ' ...
        'precision=%.6f harm=%.6f\n'], ...
        rows25.regime{i},rows25.policy{i}, ...
        rows25.actual_trigger_rate(i), ...
        rows25.policy_recall(i), ...
        rows25.beneficial_capture(i), ...
        rows25.benefit_precision(i), ...
        rows25.harmful_fraction_among_triggers(i));
end

fprintf(fid,'\nComplementarity summary\n');
fprintf(fid,'-----------------------\n');

for i = 1:height(comp)
    fprintf(fid,[ ...
        '%s: aucAddGain=%.6f aucInteractGain=%.6f ' ...
        'withinLineInstant=%.6f withinLineAdd=%.6f ' ...
        'withinLineInteract=%.6f recallAddGain=%.6f ' ...
        'recallInteractGain=%.6f oracleFracState=%.6f ' ...
        'oracleFracInstant=%.6f oracleFracAdd=%.6f ' ...
        'oracleFracInteract=%.6f\n'], ...
        comp.regime{i}, ...
        comp.auc_additive_gain_over_best_single(i), ...
        comp.auc_interaction_gain_over_additive(i), ...
        comp.within_line_auc_instant(i), ...
        comp.within_line_auc_additive(i), ...
        comp.within_line_auc_interaction(i), ...
        comp.recall25_additive_gain_over_best_single(i), ...
        comp.recall25_interaction_gain_over_additive(i), ...
        comp.oracle_fraction_state(i), ...
        comp.oracle_fraction_instant(i), ...
        comp.oracle_fraction_additive(i), ...
        comp.oracle_fraction_interaction(i));
end

fprintf(fid,'\nInterpretation notices\n');
fprintf(fid,'----------------------\n');

for i = 1:height(comp)
    regime = comp.regime{i};

    if comp.within_line_auc_instant(i) >= ...
            cfg.within_line_auc_notice
        fprintf(fid,[ ...
            '%s: instantaneous observables show meaningful ' ...
            'within-line Beneficial ranking (AUC %.3f >= %.3f).\n'], ...
            regime,comp.within_line_auc_instant(i), ...
            cfg.within_line_auc_notice);
    else
        fprintf(fid,[ ...
            '%s: instantaneous observables show weak within-line ' ...
            'Beneficial ranking (AUC %.3f < %.3f).\n'], ...
            regime,comp.within_line_auc_instant(i), ...
            cfg.within_line_auc_notice);
    end

    if comp.auc_additive_gain_over_best_single(i) >= ...
            cfg.delta_auc_notice
        fprintf(fid,[ ...
            '%s: additive state+instant information produces a ' ...
            'noticeable pooled AUC gain (%.3f).\n'], ...
            regime, ...
            comp.auc_additive_gain_over_best_single(i));
    else
        fprintf(fid,[ ...
            '%s: additive state+instant AUC gain is small (%.3f).\n'], ...
            regime, ...
            comp.auc_additive_gain_over_best_single(i));
    end

    if comp.recall25_additive_gain_over_best_single(i) >= ...
            cfg.delta_recall_notice
        fprintf(fid,[ ...
            '%s: additive state+instant policy gives a noticeable ' ...
            '25%%-budget recovery gain (%.4f).\n'], ...
            regime, ...
            comp.recall25_additive_gain_over_best_single(i));
    else
        fprintf(fid,[ ...
            '%s: additive state+instant 25%%-budget recovery gain ' ...
            'is small (%.4f).\n'], ...
            regime, ...
            comp.recall25_additive_gain_over_best_single(i));
    end

    if comp.auc_interaction_gain_over_additive(i) >= ...
            cfg.delta_auc_notice
        fprintf(fid,[ ...
            '%s: state-dependent interaction terms appear useful ' ...
            '(AUC gain %.3f).\n'], ...
            regime, ...
            comp.auc_interaction_gain_over_additive(i));
    else
        fprintf(fid,[ ...
            '%s: interaction terms add little pooled AUC beyond ' ...
            'the additive model (%.3f).\n'], ...
            regime, ...
            comp.auc_interaction_gain_over_additive(i));
    end
end

fprintf(fid,'\nPrimary scientific boundary\n');
fprintf(fid,'---------------------------\n');
fprintf(fid,['StateOnly uses a TRAIN-derived diagnostic physical-state prior. ' ...
    'It is not yet a practical state estimator. This experiment tests ' ...
    'information complementarity, not the final deployable policy.\n']);

fclose(fid);

end

%% ========================================================================
function make_figures( ...
    out_dir,cfg,metrics,state_bin_auc, ...
    budget_curves,reported,oracle_gap, ...
    value_calibration,test_smooth,test_abrupt)

primary_models = ["StateOnly","InstantOnly","Additive","Interaction"];
regimes = ["Smooth","Abrupt"];

%% Fig 1: pooled Beneficial AUC
Y = nan(numel(primary_models),2);

for im = 1:numel(primary_models)
    for ir = 1:2
        mm = metrics.model==primary_models(im) & ...
             metrics.regime==regimes(ir);

        Y(im,ir) = metrics.beneficial_auc(mm);
    end
end

fig = figure('Visible',cfg.figure_visible);
bar(Y);

ylim([0.45 1]);
yline(0.5,'--');

xticks(1:numel(primary_models));
xticklabels(primary_models);
xtickangle(20);

ylabel('Beneficial AUC');
title('C3-B1.1 State + Realization Information Audit');

legend(regimes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig01_beneficial_auc_audit.png'), ...
    'Resolution',180);

close(fig);

%% Fig 2: within-line Beneficial AUC
Y = nan(numel(primary_models),2);

for im = 1:numel(primary_models)
    for ir = 1:2
        mm = metrics.model==primary_models(im) & ...
             metrics.regime==regimes(ir);

        Y(im,ir) = ...
            metrics.within_line_beneficial_auc(mm);
    end
end

fig = figure('Visible',cfg.figure_visible);
bar(Y);

ylim([0.45 1]);
yline(0.5,'--');

xticks(1:numel(primary_models));
xticklabels(primary_models);
xtickangle(20);

ylabel('Weighted within-line Beneficial AUC');
title('C3-B1.1 Realization Discrimination at Fixed Physical State');

legend(regimes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig02_within_line_beneficial_auc.png'), ...
    'Resolution',180);

close(fig);

%% Fig 3: Smooth quality-cost
plot_policies = [ ...
    "StateOnly","InstantOnly","Additive","Interaction", ...
    "TrialOracle","RandomExpected"];

fig = figure('Visible',cfg.figure_visible);
hold on;

for ip = 1:numel(plot_policies)
    Cp = budget_curves( ...
        budget_curves.regime=="Smooth" & ...
        budget_curves.policy==plot_policies(ip),:);

    plot( ...
        Cp.normalized_q_search_budget, ...
        Cp.policy_recall, ...
        'LineWidth',1.35);
end

xlabel('Normalized q-search budget');
ylabel('Weak recovery rate');
title('C3-B1.1 Smooth: State + Realization Quality-Cost');

legend(plot_policies,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig03_smooth_quality_cost.png'), ...
    'Resolution',180);

close(fig);

%% Fig 4: Abrupt quality-cost
fig = figure('Visible',cfg.figure_visible);
hold on;

for ip = 1:numel(plot_policies)
    Cp = budget_curves( ...
        budget_curves.regime=="Abrupt" & ...
        budget_curves.policy==plot_policies(ip),:);

    plot( ...
        Cp.normalized_q_search_budget, ...
        Cp.policy_recall, ...
        'LineWidth',1.35);
end

xlabel('Normalized q-search budget');
ylabel('Weak recovery rate');
title('C3-B1.1 Abrupt: State + Realization Quality-Cost');

legend(plot_policies,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig04_abrupt_quality_cost.png'), ...
    'Resolution',180);

close(fig);

%% Fig 5: 25% policy recovery
rows25 = reported(abs(reported.target_budget-0.25)<1e-12,:);

Y = nan(numel(primary_models),2);

for im = 1:numel(primary_models)
    for ir = 1:2
        mm = strcmp(rows25.policy,char(primary_models(im))) & ...
             strcmp(rows25.regime,char(regimes(ir)));

        Y(im,ir) = rows25.policy_recall(mm);
    end
end

fig = figure('Visible',cfg.figure_visible);
bar(Y);

ylim([0 1]);

xticks(1:numel(primary_models));
xticklabels(primary_models);
xtickangle(20);

ylabel('Weak recovery rate');
title('C3-B1.1 Policy Comparison at 25% Budget');

legend(regimes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig05_policy_comparison_25pct.png'), ...
    'Resolution',180);

close(fig);

%% Fig 6: oracle selection advantage captured at 25%
G = oracle_gap( ...
    abs(oracle_gap.target_budget-0.25)<1e-12 & ...
    ismember(string(oracle_gap.policy),primary_models),:);

Y = nan(numel(primary_models),2);

for im = 1:numel(primary_models)
    for ir = 1:2
        mm = strcmp(G.policy,char(primary_models(im))) & ...
             strcmp(G.regime,char(regimes(ir)));

        Y(im,ir) = ...
            G.oracle_selection_advantage_fraction(mm);
    end
end

fig = figure('Visible',cfg.figure_visible);
bar(Y);

xticks(1:numel(primary_models));
xticklabels(primary_models);
xtickangle(20);

ylabel('Fraction of TrialOracle selection advantage');
title('C3-B1.1 How Much Oracle Opportunity Is Explained?');

legend(regimes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig06_oracle_gap_capture_25pct.png'), ...
    'Resolution',180);

close(fig);

%% Fig 7-8: conditional AUC across state bins
conditional_models = ["InstantOnly","Additive","Interaction"];

for ir = 1:2
    regime = regimes(ir);

    fig = figure('Visible',cfg.figure_visible);
    hold on;

    for im = 1:numel(conditional_models)
        C = state_bin_auc( ...
            state_bin_auc.regime==regime & ...
            state_bin_auc.model==conditional_models(im),:);

        plot( ...
            C.mean_state_prior,C.beneficial_auc, ...
            '-o','LineWidth',1.25);
    end

    yline(0.5,'--');

    xlabel('Mean physical-state prior in bin');
    ylabel('Conditional Beneficial AUC');

    title(sprintf( ...
        'C3-B1.1 %s: Realization Information Across State', ...
        char(regime)));

    legend(conditional_models,'Location','best');
    grid on;

    exportgraphics(fig, ...
        fullfile(out_dir,sprintf( ...
        'fig%02d_%s_state_bin_auc.png', ...
        6+ir,lower(char(regime)))), ...
        'Resolution',180);

    close(fig);
end

%% Fig 9: Interaction value calibration
fig = figure('Visible',cfg.figure_visible);
hold on;

for ir = 1:2
    C = value_calibration(value_calibration.regime==regimes(ir),:);

    plot( ...
        C.mean_predicted_value, ...
        C.empirical_signed_value, ...
        '-o','LineWidth',1.25);
end

xlabel('Predicted fallback value p_B - p_H');
ylabel('Empirical signed fallback value');

title('C3-B1.1 Interaction Value Calibration');
legend(regimes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig09_interaction_value_calibration.png'), ...
    'Resolution',180);

close(fig);

%% Fig 10: State x instantaneous plane, Smooth TEST
fig = figure('Visible',cfg.figure_visible);

class_id = zeros(height(test_smooth),1);
class_id(logical(test_smooth.beneficial)) = 1;
class_id(logical(test_smooth.harmful)) = -1;

scatter( ...
    test_smooth.state_prior, ...
    test_smooth.legacy_instant_risk, ...
    14,class_id,'filled');

xlabel('Physical-state prior');
ylabel('Instantaneous PE risk');
title('C3-B1.1 Smooth State-Realization Plane');

cb = colorbar;
cb.Ticks = [-1 0 1];
cb.TickLabels = {'Harmful','Neutral','Beneficial'};

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig10_smooth_state_realization_plane.png'), ...
    'Resolution',180);

close(fig);

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
function assert_table_vars(T,names,filename)

vars = T.Properties.VariableNames;

for i = 1:numel(names)
    if ~ismember(names{i},vars)
        error('Missing variable "%s" in %s.', ...
            names{i},filename);
    end
end

end
