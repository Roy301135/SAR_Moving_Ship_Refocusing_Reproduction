function results = exp09c3_history_aware_adaptive_computation()
%EXP09C3_HISTORY_AWARE_ADAPTIVE_COMPUTATION
% EXP009 / Pilot-01 / Experiment C3
%
% History-Aware Adaptive Computation
%
% -------------------------------------------------------------------------
% Research question
% -------------------------------------------------------------------------
% C2.2 showed:
%
%   - pooled prominence / entropy AUC is moderately high;
%   - after cell centering, their AUC collapses to ~0.5;
%   - therefore these observables mainly indicate a persistent latent risk
%     STATE rather than the fate of one isolated realization.
%
% C3 asks:
%
%   "If the latent risk state persists across neighboring azimuth lines,
%    can causal history aggregation estimate computation value better than
%    one-shot confidence?"
%
% -------------------------------------------------------------------------
% This first C3 is intentionally a BOOTSTRAP sequence proof-of-concept.
% -------------------------------------------------------------------------
% It does not rerun signal-level FrAc/CLEAN.
%
% Instead:
%
%   1) take the already validated 4500 C1/C2.1 trials;
%   2) split trials inside every cell into disjoint TRAIN/TEST pools;
%   3) generate synthetic sequences whose latent cell/state evolves as a
%      Markov process;
%   4) sample one independent empirical realization from the corresponding
%      state pool at each sequence position.
%
% Thus each sequence contains:
%
%   persistent latent risk state
%   +
%   independent realization noise
%
% which is exactly the statistical question isolated by C2.2.
%
% -------------------------------------------------------------------------
% Regimes
% -------------------------------------------------------------------------
% Smooth:
%   state mostly stays unchanged and occasionally moves to an adjacent
%   utility-ranked state.
%
% Abrupt:
%   same persistence, plus occasional jumps to a far-away state.
%
% -------------------------------------------------------------------------
% Policies
% -------------------------------------------------------------------------
% InstantPE:
%   instantaneous percentile risk from cheap prominence + entropy.
%
% EMA:
%   causal exponential moving average of InstantPE.
%
% EMAReset:
%   same EMA, but a large score innovation resets the history state.
%
% KnownStatePrior:
%   diagnostic state-level policy using TRAIN-pool cell utility
%   p(Beneficial|cell)-p(Harmful|cell). It knows state identity but not
%   individual trial fate.
%
% TrialOracle:
%   knows the individual Beneficial label.
%
% RandomExpected:
%   matched-budget random allocation expectation.
%
% -------------------------------------------------------------------------
% Hyperparameter discipline
% -------------------------------------------------------------------------
% EMA alpha and reset threshold are tuned ONLY on synthetic TRAIN
% sequences built from odd/even-disjoint empirical trial pools.
%
% All budget thresholds are also obtained from TRAIN score distributions.
%
% TEST sequences use the disjoint held-out trial pool.
%
% -------------------------------------------------------------------------
% Main outputs
% -------------------------------------------------------------------------
% - state-risk correlation
% - Beneficial capture vs computation budget
% - Weak recovery vs computation budget
% - smooth vs abrupt comparison
% - representative sequence plots
% - reset behavior near abrupt state changes
%
% Run:
%   results = exp09c3_history_aware_adaptive_computation;

cfg = config_exp09c3();

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

if isempty(cfg.c2_2_result_dir)
    c2_2_dir = fullfile(paper_root,'results','exp09_pilot01', ...
        'exp09c2_2_state_vs_realization');
else
    c2_2_dir = cfg.c2_2_result_dir;
end

if isempty(cfg.output_dir)
    out_dir = fullfile(paper_root,'results','exp09_pilot01', ...
        'exp09c3_history_aware_adaptive_computation');
else
    out_dir = cfg.output_dir;
end

if ~exist(out_dir,'dir')
    mkdir(out_dir);
end

feat_file = fullfile(c2_1_dir,'c2_1_trial_mechanism_features.csv');
c1_file = fullfile(c1_dir,'c1_branch_trials.csv');
state_file = fullfile(c2_2_dir,'cell_state_summary.csv');

if ~exist(feat_file,'file')
    error('C2.1 feature table not found: %s',feat_file);
end
if ~exist(c1_file,'file')
    error('C1 branch table not found: %s',c1_file);
end
if ~exist(state_file,'file')
    error('C2.2 state summary not found: %s',state_file);
end

Ftbl = readtable(feat_file);
C1 = readtable(c1_file);
S = readtable(state_file);

required_F = { ...
    'cell_id','trial_id','beneficial','harmful', ...
    'cheap_prominence','cheap_entropy'};

assert_table_vars(Ftbl,required_F,'c2_1_trial_mechanism_features.csv');

required_C1 = {'cell_id','trial_id','cheap_success','fallback_success'};
assert_table_vars(C1,required_C1,'c1_branch_trials.csv');

required_S = { ...
    'cell_id','beneficial_rate','harmful_rate','net_fallback_utility'};
assert_table_vars(S,required_S,'cell_state_summary.csv');

%% Align trial tables
Ftbl = sortrows(Ftbl,{'cell_id','trial_id'});
C1 = sortrows(C1,{'cell_id','trial_id'});

if height(Ftbl)~=height(C1)
    error('C2.1 and C1 row counts differ.');
end

if any(Ftbl.cell_id~=C1.cell_id) || any(Ftbl.trial_id~=C1.trial_id)
    error('C2.1 and C1 trial keys do not align.');
end

cheap = logical(C1.cheap_success);
fallback = logical(C1.fallback_success);
beneficial = logical(Ftbl.beneficial);
harmful = logical(Ftbl.harmful);

if any(beneficial ~= (~cheap & fallback)) || ...
        any(harmful ~= (cheap & ~fallback))
    error('Beneficial/Harmful labels do not match C1 branch outcomes.');
end

%% Merge outcome columns into one trial bank
Bank = table();
Bank.cell_id = Ftbl.cell_id;
Bank.trial_id = Ftbl.trial_id;
Bank.cheap_success = cheap;
Bank.fallback_success = fallback;
Bank.beneficial = beneficial;
Bank.harmful = harmful;
Bank.cheap_prominence = double(Ftbl.cheap_prominence);
Bank.cheap_entropy = double(Ftbl.cheap_entropy);

cells = unique(Bank.cell_id).';
K = numel(cells);

S = sortrows(S,'cell_id');

if height(S)~=K || any(S.cell_id(:) ~= cells(:))
    error('C2.2 cell_state_summary does not match trial-bank cell IDs.');
end

%% Train/test empirical pool split
train_is_odd = (cfg.train_trial_parity==1);

if train_is_odd
    is_train_pool = mod(Bank.trial_id,2)==1;
else
    is_train_pool = mod(Bank.trial_id,2)==0;
end

is_test_pool = ~is_train_pool;

for ik = 1:K
    c = cells(ik);

    if sum(is_train_pool & Bank.cell_id==c)<10 || ...
            sum(is_test_pool & Bank.cell_id==c)<10
        error('Insufficient train/test pool in cell %g.',c);
    end
end

TrainPool = Bank(is_train_pool,:);
TestPool = Bank(is_test_pool,:);

%% Cell utility estimated ONLY from train empirical pool
state_utility_train = nan(K,1);
state_benefit_train = nan(K,1);
state_harm_train = nan(K,1);

for ik = 1:K
    c = cells(ik);
    mm = TrainPool.cell_id==c;

    state_benefit_train(ik) = mean(TrainPool.beneficial(mm));
    state_harm_train(ik) = mean(TrainPool.harmful(mm));

    state_utility_train(ik) = ...
        state_benefit_train(ik)-state_harm_train(ik);
end

% Utility-ranked state order defines "adjacent latent difficulty states".
[~,utility_order] = sort(state_utility_train,'ascend');

rank_of_cell = nan(K,1);
for r = 1:K
    rank_of_cell(utility_order(r)) = r;
end

%% Empirical-CDF calibration for instantaneous practical risk
calib = build_instantaneous_calibration(TrainPool);

% Precompute instantaneous risk once for each empirical bank row. Sequence
% generation then only samples stored scalar scores instead of repeatedly
% evaluating empirical CDFs.
TrainPool = add_instant_score_to_pool(TrainPool,calib);
TestPool = add_instant_score_to_pool(TestPool,calib);

%% State transition matrices
P_smooth = build_smooth_transition_matrix(K,cfg.p_stay);

P_abrupt = build_abrupt_transition_matrix( ...
    P_smooth,cfg.p_jump,cfg.min_jump_rank_distance);

%% Generate TRAIN sequences
rng(cfg.seed,'twister');

train_smooth = generate_sequence_set( ...
    cfg.num_train_sequences_per_regime, ...
    cfg.sequence_length, ...
    "Smooth",P_smooth,utility_order,rank_of_cell, ...
    TrainPool,cells,state_utility_train,calib,cfg);

train_abrupt = generate_sequence_set( ...
    cfg.num_train_sequences_per_regime, ...
    cfg.sequence_length, ...
    "Abrupt",P_abrupt,utility_order,rank_of_cell, ...
    TrainPool,cells,state_utility_train,calib,cfg);

%% Tune EMA alpha on TRAIN sequences
alpha_grid = cfg.alpha_grid(:);
nA = numel(alpha_grid);

alpha_score = nan(nA,1);

for ia = 1:nA
    a = alpha_grid(ia);

    Ts = apply_history_to_set(train_smooth,a,NaN);
    Ta = apply_history_to_set(train_abrupt,a,NaN);

    train_combined = [Ts;Ta];

    alpha_score(ia) = policy_recall_at_budget( ...
        train_combined,'ema_score',cfg.tune_budget);
end

[~,best_alpha_idx] = max(alpha_score);
best_alpha = alpha_grid(best_alpha_idx);

%% Tune reset innovation threshold on TRAIN sequences
% First obtain innovations under the selected EMA alpha.
Ts0 = apply_history_to_set(train_smooth,best_alpha,NaN);
Ta0 = apply_history_to_set(train_abrupt,best_alpha,NaN);
T0 = [Ts0;Ta0];

innovation_train = abs(T0.innovation);
innovation_train = innovation_train(isfinite(innovation_train));

reset_q_grid = cfg.reset_quantile_grid(:);
nQ = numel(reset_q_grid);

reset_thresholds = nan(nQ,1);
reset_score = nan(nQ,1);

for iq = 1:nQ
    q = reset_q_grid(iq);

    thr = empirical_quantile(innovation_train,q);
    reset_thresholds(iq) = thr;

    Ts = apply_history_to_set(train_smooth,best_alpha,thr);
    Ta = apply_history_to_set(train_abrupt,best_alpha,thr);

    train_combined = [Ts;Ta];

    reset_score(iq) = policy_recall_at_budget( ...
        train_combined,'reset_score',cfg.tune_budget);
end

[~,best_reset_idx] = max(reset_score);
best_reset_quantile = reset_q_grid(best_reset_idx);
best_reset_threshold = reset_thresholds(best_reset_idx);

%% Generate independent TEST sequences
% Shift RNG stream after training sequence generation.
rng(cfg.seed+1000,'twister');

test_smooth = generate_sequence_set( ...
    cfg.num_test_sequences_per_regime, ...
    cfg.sequence_length, ...
    "Smooth",P_smooth,utility_order,rank_of_cell, ...
    TestPool,cells,state_utility_train,calib,cfg);

test_abrupt = generate_sequence_set( ...
    cfg.num_test_sequences_per_regime, ...
    cfg.sequence_length, ...
    "Abrupt",P_abrupt,utility_order,rank_of_cell, ...
    TestPool,cells,state_utility_train,calib,cfg);

test_smooth = apply_history_to_set( ...
    test_smooth,best_alpha,best_reset_threshold);

test_abrupt = apply_history_to_set( ...
    test_abrupt,best_alpha,best_reset_threshold);

%% Prepare TRAIN score distributions for budget thresholds
train_smooth = apply_history_to_set( ...
    train_smooth,best_alpha,best_reset_threshold);

train_abrupt = apply_history_to_set( ...
    train_abrupt,best_alpha,best_reset_threshold);

train_all = [train_smooth;train_abrupt];

%% State-estimation diagnostics
diag_rows = {};

regime_names = ["Smooth","Abrupt"];
test_sets = {test_smooth,test_abrupt};

score_names = { ...
    'instant_score','ema_score','reset_score','state_prior_score'};

score_labels = { ...
    'InstantPE','EMA','EMAReset','KnownStatePrior'};

for ir = 1:2
    T = test_sets{ir};

    for is = 1:numel(score_names)
        sc = double(T.(score_names{is}));
        target = double(T.state_utility_norm);

        rho_state = spearman_manual(sc,target);
        auc_B = binary_auc(T.beneficial,sc);

        diag_rows(end+1,:) = { ... %#ok<AGROW>
            char(regime_names(ir)), ...
            score_labels{is}, ...
            rho_state,auc_B};
    end
end

state_diagnostics = cell2table(diag_rows, ...
    'VariableNames',{ ...
    'regime','policy_score','spearman_with_state_utility', ...
    'beneficial_auc'});

writetable(state_diagnostics, ...
    fullfile(out_dir,'state_estimation_diagnostics.csv'));

%% Budget policy curves
policies = { ...
    'instant_score','InstantPE'; ...
    'ema_score','EMA'; ...
    'reset_score','EMAReset'; ...
    'state_prior_score','KnownStatePrior'};

budget_curves = table();

for ir = 1:2
    regime = regime_names(ir);
    Ttest = test_sets{ir};

    for ip = 1:size(policies,1)
        score_var = policies{ip,1};
        policy_label = string(policies{ip,2});

        C = evaluate_score_policy_curve( ...
            train_all,Ttest,score_var,cfg.budget_grid);

        C.regime = repmat(regime,height(C),1);
        C.policy = repmat(policy_label,height(C),1);

        budget_curves = [budget_curves;C]; %#ok<AGROW>
    end

    % Trial oracle and random expected use TEST regime rates.
    Cto = trial_oracle_curve(Ttest,cfg.budget_grid);
    Cto.regime = repmat(regime,height(Cto),1);
    Cto.policy = repmat("TrialOracle",height(Cto),1);

    Cr = random_expected_curve(Ttest,cfg.budget_grid);
    Cr.regime = repmat(regime,height(Cr),1);
    Cr.policy = repmat("RandomExpected",height(Cr),1);

    budget_curves = [budget_curves;Cto;Cr]; %#ok<AGROW>
end

budget_curves = movevars( ...
    budget_curves,{'regime','policy'},'Before',1);

writetable(budget_curves, ...
    fullfile(out_dir,'history_budget_curves.csv'));

%% Highlighted budget points
point_rows = {};

for ir = 1:2
    regime = regime_names(ir);

    Creg = budget_curves(budget_curves.regime==regime,:);

    pols = unique(Creg.policy,'stable');

    for ip = 1:numel(pols)
        Cp = Creg(Creg.policy==pols(ip),:);

        for ib = 1:numel(cfg.report_budgets)
            b = cfg.report_budgets(ib);

            [~,ii] = min(abs(Cp.target_budget-b));

            point_rows(end+1,:) = { ... %#ok<AGROW>
                char(regime),char(pols(ip)),b, ...
                Cp.actual_trigger_rate(ii), ...
                Cp.policy_recall(ii), ...
                Cp.beneficial_capture(ii), ...
                Cp.benefit_precision(ii), ...
                Cp.harmful_fraction_among_triggers(ii), ...
                Cp.normalized_q_search_budget(ii)};
        end
    end
end

budget_points = cell2table(point_rows, ...
    'VariableNames',{ ...
    'regime','policy','target_budget','actual_trigger_rate', ...
    'policy_recall','beneficial_capture','benefit_precision', ...
    'harmful_fraction_among_triggers', ...
    'normalized_q_search_budget'});

writetable(budget_points, ...
    fullfile(out_dir,'reported_budget_points.csv'));

%% Jump diagnostics for abrupt TEST sequences
jump_diag = evaluate_jump_diagnostics(test_abrupt);

writetable(jump_diag, ...
    fullfile(out_dir,'abrupt_jump_diagnostics.csv'));

%% Hyperparameter record
tuning = table();
tuning.best_alpha = best_alpha;
tuning.best_reset_quantile = best_reset_quantile;
tuning.best_reset_threshold = best_reset_threshold;
tuning.train_recall_ema_at_tune_budget = alpha_score(best_alpha_idx);
tuning.train_recall_reset_at_tune_budget = reset_score(best_reset_idx);
tuning.tune_budget = cfg.tune_budget;

writetable(tuning, ...
    fullfile(out_dir,'history_tuning_summary.csv'));

alpha_table = table(alpha_grid,alpha_score, ...
    'VariableNames',{'alpha','train_recall_at_tune_budget'});
writetable(alpha_table,fullfile(out_dir,'alpha_sweep.csv'));

reset_table = table( ...
    reset_q_grid,reset_thresholds,reset_score, ...
    'VariableNames',{ ...
    'reset_quantile','reset_threshold', ...
    'train_recall_at_tune_budget'});
writetable(reset_table,fullfile(out_dir,'reset_sweep.csv'));

%% Save representative sequences
rep_smooth = test_smooth(test_smooth.sequence_id==1,:);
rep_abrupt = test_abrupt(test_abrupt.sequence_id==1,:);

writetable(rep_smooth, ...
    fullfile(out_dir,'representative_smooth_sequence.csv'));
writetable(rep_abrupt, ...
    fullfile(out_dir,'representative_abrupt_sequence.csv'));

%% Console summary
fprintf('================ C3 TUNING ===========================\n');
fprintf('Best EMA alpha              = %.3f\n',best_alpha);
fprintf('Best reset quantile         = %.3f\n',best_reset_quantile);
fprintf('Best reset threshold        = %.6f\n',best_reset_threshold);

fprintf('\n================ C3 STATE DIAGNOSTICS ================\n');
for i = 1:height(state_diagnostics)
    fprintf('%-8s %-16s rho(state)=%.3f AUC(B)=%.3f\n', ...
        state_diagnostics.regime{i}, ...
        state_diagnostics.policy_score{i}, ...
        state_diagnostics.spearman_with_state_utility(i), ...
        state_diagnostics.beneficial_auc(i));
end

fprintf('\n================ C3 25%% BUDGET ======================\n');

rows25 = budget_points(abs(budget_points.target_budget-0.25)<1e-12,:);

for i = 1:height(rows25)
    fprintf('%-8s %-16s actual=%.3f recall=%.3f capture=%.3f precision=%.3f harm=%.3f\n', ...
        rows25.regime{i},rows25.policy{i}, ...
        rows25.actual_trigger_rate(i), ...
        rows25.policy_recall(i), ...
        rows25.beneficial_capture(i), ...
        rows25.benefit_precision(i), ...
        rows25.harmful_fraction_among_triggers(i));
end

fprintf('\n================ C3 ABRUPT JUMP ======================\n');
disp(jump_diag);

fprintf('======================================================\n');

%% Text summary
fid = fopen(fullfile(out_dir,'summary.txt'),'w');

fprintf(fid,'EXP009-C3 History-Aware Adaptive Computation\n');
fprintf(fid,'============================================\n\n');

fprintf(fid,'Experimental boundary\n');
fprintf(fid,'---------------------\n');
fprintf(fid,['This is a bootstrap sequential-state proof-of-concept ' ...
    'using disjoint empirical train/test trial pools from C1/C2.1.\n']);
fprintf(fid,['It does not yet constitute a continuous physical SAR ' ...
    'azimuth-motion experiment.\n\n']);

fprintf(fid,'Tuning\n');
fprintf(fid,'------\n');
fprintf(fid,'Best EMA alpha: %.6f\n',best_alpha);
fprintf(fid,'Best reset quantile: %.6f\n',best_reset_quantile);
fprintf(fid,'Best reset threshold: %.6f\n',best_reset_threshold);
fprintf(fid,'Tune budget: %.6f\n\n',cfg.tune_budget);

fprintf(fid,'State-estimation diagnostics\n');
fprintf(fid,'----------------------------\n');
for i = 1:height(state_diagnostics)
    fprintf(fid,'%s %s rho_state=%.6f aucB=%.6f\n', ...
        state_diagnostics.regime{i}, ...
        state_diagnostics.policy_score{i}, ...
        state_diagnostics.spearman_with_state_utility(i), ...
        state_diagnostics.beneficial_auc(i));
end

fprintf(fid,'\nHighlighted budget points\n');
fprintf(fid,'-------------------------\n');
for i = 1:height(budget_points)
    fprintf(fid, ...
        ['%s %s target=%.3f actual=%.6f recall=%.6f ' ...
         'capture=%.6f precision=%.6f harm=%.6f budget=%.6f\n'], ...
        budget_points.regime{i}, ...
        budget_points.policy{i}, ...
        budget_points.target_budget(i), ...
        budget_points.actual_trigger_rate(i), ...
        budget_points.policy_recall(i), ...
        budget_points.beneficial_capture(i), ...
        budget_points.benefit_precision(i), ...
        budget_points.harmful_fraction_among_triggers(i), ...
        budget_points.normalized_q_search_budget(i));
end

fprintf(fid,'\nAbrupt jump diagnostics\n');
fprintf(fid,'-----------------------\n');
for i = 1:height(jump_diag)
    fprintf(fid,'%s meanAbsInnovation=%.6f meanPostJumpRiskError=%.6f\n', ...
        jump_diag.policy{i}, ...
        jump_diag.mean_abs_innovation(i), ...
        jump_diag.mean_post_jump_state_risk_abs_error(i));
end

fclose(fid);

%% Figures
make_figures( ...
    out_dir,cfg,state_diagnostics,budget_curves,budget_points, ...
    rep_smooth,rep_abrupt,jump_diag, ...
    alpha_table,reset_table);

%% Save
results = struct();
results.cfg = cfg;
results.tuning = tuning;
results.state_diagnostics = state_diagnostics;
results.budget_curves = budget_curves;
results.budget_points = budget_points;
results.jump_diag = jump_diag;
results.alpha_table = alpha_table;
results.reset_table = reset_table;

save(fullfile(out_dir,'exp09c3_results.mat'),'results','-v7.3');

fprintf('\nSaved EXP009-C3 outputs to:\n%s\n\n',out_dir);

end

%% ========================================================================
function calib = build_instantaneous_calibration(TrainPool)
prom = double(TrainPool.cheap_prominence(:));
ent = double(TrainPool.cheap_entropy(:));

prom = prom(isfinite(prom));
ent = ent(isfinite(ent));

if isempty(prom) || isempty(ent)
    error('Non-finite instantaneous calibration features.');
end

calib.prom_sorted = sort(prom);
calib.ent_sorted = sort(ent);
end

%% ========================================================================
function Pool = add_instant_score_to_pool(Pool,calib)
N = height(Pool);
score = nan(N,1);

for i = 1:N
    score(i) = instantaneous_risk( ...
        double(Pool.cheap_prominence(i)), ...
        double(Pool.cheap_entropy(i)), ...
        calib);
end

Pool.instant_score = score;
end

%% ========================================================================
function r = instantaneous_risk(prominence,entropy,calib)
% Low prominence -> high risk.
% High entropy   -> high risk.

Fp = empirical_cdf_value(calib.prom_sorted,prominence);
Fe = empirical_cdf_value(calib.ent_sorted,entropy);

risk_prom = 1-Fp;
risk_ent = Fe;

r = 0.5*(risk_prom+risk_ent);
r = min(max(r,0),1);

if ~isscalar(r)
    error('instantaneous_risk must return a scalar.');
end
end

%% ========================================================================
function F = empirical_cdf_value(sorted_x,x)
sorted_x = double(sorted_x(:));

if ~isfinite(x)
    F = 0.5;
    return;
end

N = numel(sorted_x);

if N==0
    F = 0.5;
    return;
end

% Mid-rank style empirical CDF.
nLess = sum(sorted_x < x);
nEq = sum(sorted_x == x);

F = (nLess + 0.5*nEq)/N;
F = min(max(F,0),1);
end

%% ========================================================================
function P = build_smooth_transition_matrix(K,p_stay)
if p_stay<0 || p_stay>1
    error('p_stay must lie in [0,1].');
end

P = zeros(K,K);

for r = 1:K
    P(r,r) = p_stay;

    rem = 1-p_stay;

    nbr = [];

    if r>1
        nbr(end+1) = r-1; %#ok<AGROW>
    end

    if r<K
        nbr(end+1) = r+1; %#ok<AGROW>
    end

    if isempty(nbr)
        P(r,r) = 1;
    else
        P(r,nbr) = rem/numel(nbr);
    end
end

P = normalize_transition_rows(P);
end

%% ========================================================================
function P = build_abrupt_transition_matrix( ...
    P_smooth,p_jump,min_rank_distance)

K = size(P_smooth,1);

P_far = zeros(K,K);

for r = 1:K
    candidates = find(abs((1:K)-r) >= min_rank_distance);

    if isempty(candidates)
        candidates = setdiff(1:K,r);
    end

    if isempty(candidates)
        P_far(r,r) = 1;
    else
        P_far(r,candidates) = 1/numel(candidates);
    end
end

P = (1-p_jump)*P_smooth + p_jump*P_far;
P = normalize_transition_rows(P);
end

%% ========================================================================
function P = normalize_transition_rows(P)
for i = 1:size(P,1)
    s = sum(P(i,:));

    if s<=0
        error('Transition row has zero mass.');
    end

    P(i,:) = P(i,:)/s;
end
end

%% ========================================================================
function Tset = generate_sequence_set( ...
    num_seq,L,regime,P_rank,utility_order,rank_of_cell, ...
    Pool,cells,state_utility_train,calib,cfg) %#ok<INUSD>

K = numel(cells);

u_min = min(state_utility_train);
u_max = max(state_utility_train);

if abs(u_max-u_min)<eps
    u_norm = 0.5*ones(K,1);
else
    u_norm = (state_utility_train-u_min)/(u_max-u_min);
end

totalN = num_seq*L;

sequence_id = zeros(totalN,1);
time_index = zeros(totalN,1);
regime_col = repmat(string(regime),totalN,1);

state_rank = zeros(totalN,1);
cell_id = zeros(totalN,1);

state_utility = nan(totalN,1);
state_utility_norm = nan(totalN,1);

cheap_success = false(totalN,1);
fallback_success = false(totalN,1);
beneficial = false(totalN,1);
harmful = false(totalN,1);

cheap_prominence = nan(totalN,1);
cheap_entropy = nan(totalN,1);

instant_score = nan(totalN,1);
state_prior_score = nan(totalN,1);

% Independent random tie breaker for exact score ties. This is especially
% important for KnownStatePrior, where all realizations in one state share
% the same score. It carries no signal/outcome information.
allocation_tiebreak = nan(totalN,1);

is_state_change = false(totalN,1);
is_far_jump = false(totalN,1);

row = 0;

% Pre-cache pool indices by CELL INDEX.
pool_idx = cell(K,1);

for ik = 1:K
    pool_idx{ik} = find(Pool.cell_id==cells(ik));

    if isempty(pool_idx{ik})
        error('No empirical pool rows for cell %g.',cells(ik));
    end
end

for iseq = 1:num_seq
    r = randi(K);
    prev_r = r;

    for t = 1:L
        row = row+1;

        if t>1
            probs = P_rank(prev_r,:);
            r = sample_discrete(probs);
        end

        cell_index = utility_order(r);
        cid = cells(cell_index);

        idx_candidates = pool_idx{cell_index};
        jj = idx_candidates(randi(numel(idx_candidates)));

        sequence_id(row) = iseq;
        time_index(row) = t;

        state_rank(row) = r;
        cell_id(row) = cid;

        state_utility(row) = state_utility_train(cell_index);
        state_utility_norm(row) = u_norm(cell_index);

        cheap_success(row) = logical(Pool.cheap_success(jj));
        fallback_success(row) = logical(Pool.fallback_success(jj));
        beneficial(row) = logical(Pool.beneficial(jj));
        harmful(row) = logical(Pool.harmful(jj));

        cheap_prominence(row) = double(Pool.cheap_prominence(jj));
        cheap_entropy(row) = double(Pool.cheap_entropy(jj));

        instant_score(row) = double(Pool.instant_score(jj));
        state_prior_score(row) = u_norm(cell_index);
        allocation_tiebreak(row) = rand;

        if t>1
            is_state_change(row) = (r~=prev_r);
            is_far_jump(row) = ...
                abs(r-prev_r)>=cfg.min_jump_rank_distance;
        end

        prev_r = r;
    end
end

Tset = table( ...
    sequence_id,time_index,regime_col, ...
    state_rank,cell_id,state_utility,state_utility_norm, ...
    cheap_success,fallback_success,beneficial,harmful, ...
    cheap_prominence,cheap_entropy, ...
    instant_score,state_prior_score,allocation_tiebreak, ...
    is_state_change,is_far_jump);

end

%% ========================================================================
function idx = sample_discrete(probs)
probs = double(probs(:));

if any(probs<0) || sum(probs)<=0
    error('Invalid discrete probability vector.');
end

probs = probs/sum(probs);
cdf = cumsum(probs);

u = rand;
idx = find(u<=cdf,1,'first');

if isempty(idx)
    idx = numel(probs);
end
end

%% ========================================================================
function Tout = apply_history_to_set(Tin,alpha,reset_threshold)
Tout = Tin;

N = height(Tout);

ema_score = nan(N,1);
reset_score = nan(N,1);
innovation = nan(N,1);
reset_event = false(N,1);

seqs = unique(Tout.sequence_id).';

for is = 1:numel(seqs)
    idx = find(Tout.sequence_id==seqs(is));

    [~,ord] = sort(Tout.time_index(idx));
    idx = idx(ord);

    x = double(Tout.instant_score(idx));
    x = x(:);

    e = nan(size(x));
    rr = nan(size(x));
    inn = nan(size(x));
    re = false(size(x));

    e(1) = x(1);
    rr(1) = x(1);
    inn(1) = 0;

    for t = 2:numel(x)
        % EMA branch.
        inn(t) = x(t)-e(t-1);
        e(t) = alpha*x(t)+(1-alpha)*e(t-1);

        % Reset branch uses its own previous state.
        if isfinite(reset_threshold)
            innovation_reset = x(t)-rr(t-1);

            if abs(innovation_reset)>reset_threshold
                rr(t) = x(t);
                re(t) = true;
            else
                rr(t) = alpha*x(t)+(1-alpha)*rr(t-1);
            end
        else
            rr(t) = e(t);
        end
    end

    ema_score(idx) = e;
    reset_score(idx) = rr;
    innovation(idx) = inn;
    reset_event(idx) = re;
end

Tout.ema_score = ema_score;
Tout.reset_score = reset_score;
Tout.innovation = innovation;
Tout.reset_event = reset_event;
end

%% ========================================================================
function recall = policy_recall_at_budget(T,score_var,budget)
score = double(T.(score_var));
score = score(:);

if ismember('allocation_tiebreak',T.Properties.VariableNames)
    tb = double(T.allocation_tiebreak(:));
    score = score + 1e-9*(tb-0.5);
end

thr = empirical_quantile(score,1-budget);
trigger = score>=thr;

out = logical(T.cheap_success);
fb = logical(T.fallback_success);

out(trigger) = fb(trigger);

recall = mean(out);
end

%% ========================================================================
function C = evaluate_score_policy_curve( ...
    Ttrain,Ttest,score_var,budgets)

train_score = double(Ttrain.(score_var));
test_score = double(Ttest.(score_var));

train_score = train_score(:);
test_score = test_score(:);

if ismember('allocation_tiebreak',Ttrain.Properties.VariableNames)
    tb = double(Ttrain.allocation_tiebreak(:));
    train_score = train_score + 1e-9*(tb-0.5);
end

if ismember('allocation_tiebreak',Ttest.Properties.VariableNames)
    tb = double(Ttest.allocation_tiebreak(:));
    test_score = test_score + 1e-9*(tb-0.5);
end

budgets = budgets(:);
nB = numel(budgets);

target_budget = budgets;
actual_trigger_rate = nan(nB,1);
policy_recall = nan(nB,1);
beneficial_capture = nan(nB,1);
benefit_precision = nan(nB,1);
harmful_fraction_among_triggers = nan(nB,1);
normalized_q_search_budget = nan(nB,1);

cheap = logical(Ttest.cheap_success);
fb = logical(Ttest.fallback_success);
beneficial = logical(Ttest.beneficial);
harmful = logical(Ttest.harmful);

nBeneficial = sum(beneficial);

for ib = 1:nB
    b = budgets(ib);

    if b<=0
        trigger = false(size(test_score));
    elseif b>=1
        trigger = true(size(test_score));
    else
        thr = empirical_quantile(train_score,1-b);
        trigger = test_score>=thr;
    end

    actual_trigger_rate(ib) = mean(trigger);

    out = cheap;
    out(trigger) = fb(trigger);

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
function C = trial_oracle_curve(Ttest,budgets)
budgets = budgets(:);

cheap = logical(Ttest.cheap_success);
beneficial = logical(Ttest.beneficial);

cheap_recall = mean(cheap);
benefit_rate = mean(beneficial);

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
budgets = budgets(:);

cheap_recall = mean(Ttest.cheap_success);
benefit_rate = mean(Ttest.beneficial);
harm_rate = mean(Ttest.harmful);

target_budget = budgets;
actual_trigger_rate = budgets;

policy_recall = ...
    cheap_recall + budgets*(benefit_rate-harm_rate);

beneficial_capture = budgets;

benefit_precision = repmat(benefit_rate,numel(budgets),1);
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
function D = evaluate_jump_diagnostics(T)
policies = {'instant_score','ema_score','reset_score'};
labels = {'InstantPE','EMA','EMAReset'};

P = numel(policies);

policy = cell(P,1);
mean_abs_innovation = nan(P,1);
mean_post_jump_state_risk_abs_error = nan(P,1);
mean_all_state_risk_abs_error = nan(P,1);

jump_idx = find(T.is_far_jump);

for ip = 1:P
    policy{ip} = labels{ip};

    s = double(T.(policies{ip}));
    s = s(:);

    target = double(T.state_utility_norm);
    target = target(:);

    mean_all_state_risk_abs_error(ip) = ...
        mean(abs(s-target),'omitnan');

    jump_change = [];

    post_err = [];

    for jj = 1:numel(jump_idx)
        k = jump_idx(jj);

        % Ensure predecessor belongs to the same sequence.
        if k<=1 || ...
                T.sequence_id(k-1)~=T.sequence_id(k)
            continue;
        end

        jump_change(end+1,1) = abs(s(k)-s(k-1)); %#ok<AGROW>

        seqid = T.sequence_id(k);
        tidx = find(T.sequence_id==seqid);

        t0 = T.time_index(k);
        mm = tidx( ...
            T.time_index(tidx)>=t0 & ...
            T.time_index(tidx)<=t0+4);

        post_err = [post_err;abs(s(mm)-target(mm))]; %#ok<AGROW>
    end

    if ~isempty(jump_change)
        mean_abs_innovation(ip) = mean(jump_change,'omitnan');
    end

    if ~isempty(post_err)
        mean_post_jump_state_risk_abs_error(ip) = ...
            mean(post_err,'omitnan');
    end
end

D = table( ...
    policy,mean_abs_innovation, ...
    mean_post_jump_state_risk_abs_error, ...
    mean_all_state_risk_abs_error);
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
    (sumPos - nPos*(nPos+1)/2)/(nPos*nNeg);
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
p = min(max(p,0),1);

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
    out_dir,cfg,state_diag,budget_curves,budget_points, ...
    rep_smooth,rep_abrupt,jump_diag,alpha_table,reset_table)

%% Fig 1: State correlation
fig = figure('Visible',cfg.figure_visible);

regimes = {'Smooth','Abrupt'};
policies = {'InstantPE','EMA','EMAReset','KnownStatePrior'};

Y = nan(numel(policies),numel(regimes));

for ip = 1:numel(policies)
    for ir = 1:numel(regimes)
        mm = strcmp(state_diag.policy_score,policies{ip}) & ...
            strcmp(state_diag.regime,regimes{ir});

        Y(ip,ir) = ...
            state_diag.spearman_with_state_utility(mm);
    end
end

bar(Y);

ylim([-0.1 1]);

xticks(1:numel(policies));
xticklabels(policies);
xtickangle(20);

ylabel('Spearman with latent state utility');
title('C3 History Improves Latent-State Observability');

legend(regimes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig01_state_observability.png'), ...
    'Resolution',180);

close(fig);

%% Fig 2: Representative smooth sequence
fig = figure('Visible',cfg.figure_visible);

plot(rep_smooth.time_index,rep_smooth.state_utility_norm, ...
    'LineWidth',1.7);
hold on;

plot(rep_smooth.time_index,rep_smooth.instant_score, ...
    'LineWidth',1.0);

plot(rep_smooth.time_index,rep_smooth.ema_score, ...
    'LineWidth',1.4);

plot(rep_smooth.time_index,rep_smooth.reset_score, ...
    'LineWidth',1.2);

xlabel('Sequence position');
ylabel('Normalized risk / score');

title('C3 Representative Smooth Latent-State Tracking');

legend('True state utility','InstantPE','EMA','EMAReset', ...
    'Location','best');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig02_representative_smooth_tracking.png'), ...
    'Resolution',180);

close(fig);

%% Fig 3: Representative abrupt sequence
fig = figure('Visible',cfg.figure_visible);

plot(rep_abrupt.time_index,rep_abrupt.state_utility_norm, ...
    'LineWidth',1.7);
hold on;

plot(rep_abrupt.time_index,rep_abrupt.instant_score, ...
    'LineWidth',1.0);

plot(rep_abrupt.time_index,rep_abrupt.ema_score, ...
    'LineWidth',1.4);

plot(rep_abrupt.time_index,rep_abrupt.reset_score, ...
    'LineWidth',1.2);

jump_x = rep_abrupt.time_index(rep_abrupt.is_far_jump);

for j = 1:numel(jump_x)
    xline(jump_x(j),':');
end

xlabel('Sequence position');
ylabel('Normalized risk / score');

title('C3 Representative Abrupt-State Tracking');

legend('True state utility','InstantPE','EMA','EMAReset', ...
    'Location','best');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig03_representative_abrupt_tracking.png'), ...
    'Resolution',180);

close(fig);

%% Shared policy list
plot_policies = [ ...
    "InstantPE","EMA","EMAReset", ...
    "KnownStatePrior","TrialOracle","RandomExpected"];

%% Fig 4: Smooth beneficial capture
fig = figure('Visible',cfg.figure_visible);
hold on;

for ip = 1:numel(plot_policies)
    Cp = budget_curves( ...
        budget_curves.regime=="Smooth" & ...
        budget_curves.policy==plot_policies(ip),:);

    plot(Cp.actual_trigger_rate,Cp.beneficial_capture, ...
        'LineWidth',1.35);
end

xlabel('Actual fallback rate');
ylabel('Capture of all beneficial trials');

title('C3 Smooth Regime: Beneficial Capture vs Budget');

legend(plot_policies,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig04_smooth_capture_vs_budget.png'), ...
    'Resolution',180);

close(fig);

%% Fig 5: Smooth quality-cost
fig = figure('Visible',cfg.figure_visible);
hold on;

for ip = 1:numel(plot_policies)
    Cp = budget_curves( ...
        budget_curves.regime=="Smooth" & ...
        budget_curves.policy==plot_policies(ip),:);

    plot(Cp.normalized_q_search_budget,Cp.policy_recall, ...
        'LineWidth',1.35);
end

xlabel('Normalized q-search budget');
ylabel('Weak recovery rate');

title('C3 Smooth Regime: Quality-Cost Pareto');

legend(plot_policies,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig05_smooth_quality_cost.png'), ...
    'Resolution',180);

close(fig);

%% Fig 6: Abrupt beneficial capture
fig = figure('Visible',cfg.figure_visible);
hold on;

for ip = 1:numel(plot_policies)
    Cp = budget_curves( ...
        budget_curves.regime=="Abrupt" & ...
        budget_curves.policy==plot_policies(ip),:);

    plot(Cp.actual_trigger_rate,Cp.beneficial_capture, ...
        'LineWidth',1.35);
end

xlabel('Actual fallback rate');
ylabel('Capture of all beneficial trials');

title('C3 Abrupt Regime: Beneficial Capture vs Budget');

legend(plot_policies,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig06_abrupt_capture_vs_budget.png'), ...
    'Resolution',180);

close(fig);

%% Fig 7: Abrupt quality-cost
fig = figure('Visible',cfg.figure_visible);
hold on;

for ip = 1:numel(plot_policies)
    Cp = budget_curves( ...
        budget_curves.regime=="Abrupt" & ...
        budget_curves.policy==plot_policies(ip),:);

    plot(Cp.normalized_q_search_budget,Cp.policy_recall, ...
        'LineWidth',1.35);
end

xlabel('Normalized q-search budget');
ylabel('Weak recovery rate');

title('C3 Abrupt Regime: Quality-Cost Pareto');

legend(plot_policies,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig07_abrupt_quality_cost.png'), ...
    'Resolution',180);

close(fig);

%% Fig 8: 25% policy comparison by regime
rows25 = budget_points(abs(budget_points.target_budget-0.25)<1e-12,:);

primary = ismember(string(rows25.policy), ...
    ["InstantPE","EMA","EMAReset","KnownStatePrior"]);

R = rows25(primary,:);

pol_order = ["InstantPE","EMA","EMAReset","KnownStatePrior"];

Y = nan(numel(pol_order),2);

for ip = 1:numel(pol_order)
    mmS = strcmp(R.regime,'Smooth') & ...
        strcmp(R.policy,char(pol_order(ip)));

    mmA = strcmp(R.regime,'Abrupt') & ...
        strcmp(R.policy,char(pol_order(ip)));

    if any(mmS)
        Y(ip,1) = R.policy_recall(mmS);
    end

    if any(mmA)
        Y(ip,2) = R.policy_recall(mmA);
    end
end

fig = figure('Visible',cfg.figure_visible);

bar(Y);
ylim([0 1]);

xticks(1:numel(pol_order));
xticklabels(pol_order);
xtickangle(20);

ylabel('Weak recovery rate');
title('C3 Policy Comparison at 25% Budget');

legend('Smooth','Abrupt','Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig08_policy_comparison_25pct.png'), ...
    'Resolution',180);

close(fig);

%% Fig 9: Jump error
fig = figure('Visible',cfg.figure_visible);

bar(jump_diag.mean_post_jump_state_risk_abs_error);

xticks(1:height(jump_diag));
xticklabels(jump_diag.policy);

ylabel('Mean |score - state risk|, first 5 samples after jump');
title('C3 Abrupt Transition Tracking Error');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig09_jump_tracking_error.png'), ...
    'Resolution',180);

close(fig);

%% Fig 10: tuning audit
fig = figure('Visible',cfg.figure_visible);

plot(alpha_table.alpha, ...
    alpha_table.train_recall_at_tune_budget, ...
    '-o','LineWidth',1.3);

xlabel('EMA \alpha');
ylabel('TRAIN recovery at tuning budget');

title('C3 EMA Alpha Tuning');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig10_alpha_tuning.png'), ...
    'Resolution',180);

close(fig);

fig = figure('Visible',cfg.figure_visible);

plot(reset_table.reset_quantile, ...
    reset_table.train_recall_at_tune_budget, ...
    '-o','LineWidth',1.3);

xlabel('Innovation reset quantile');
ylabel('TRAIN recovery at tuning budget');

title('C3 Reset-Threshold Tuning');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig11_reset_tuning.png'), ...
    'Resolution',180);

close(fig);

end
