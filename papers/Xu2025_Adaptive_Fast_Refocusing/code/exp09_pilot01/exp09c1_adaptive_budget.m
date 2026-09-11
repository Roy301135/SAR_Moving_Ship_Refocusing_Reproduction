function results = exp09c1_adaptive_budget()
%EXP09C1_ADAPTIVE_BUDGET
% EXP009 / Pilot-01 / Experiment C1
%
% Oracle-to-Practical Adaptive Budget Test
%
% -------------------------------------------------------------------------
% C1 asks a different question from B3/B4:
%
%   Reliability does NOT need to perfectly classify every future failure.
%   It only needs to allocate extra computation preferentially to risky
%   residual states and improve the weak-recovery / cost trade-off.
%
% -------------------------------------------------------------------------
% Cheap branch
% -------------------------------------------------------------------------
% Same weak-stage residual used in B1-B4:
%
%   r_cheap = s_weak + filtered_strong_residual + noise
%
% followed by one full q search.
%
% -------------------------------------------------------------------------
% Extra-computation fallback
% -------------------------------------------------------------------------
% When triggered, C1 returns to the original mixture and performs a more
% expensive parametric strong-component refit:
%
%   1) use known/previous-stage q_strong;
%   2) dechirp at q_strong;
%   3) estimate strong carrier with a zero-padded FFT;
%   4) least-squares fit the complex strong amplitude;
%   5) subtract the fitted strong component;
%   6) re-run weak-q search.
%
% This fallback is designed to attack the mechanism found in A3/A4:
% filtered coherent strong residual contaminates the weak-q search.
%
% IMPORTANT:
% q_strong is treated as available from the previous dominant-component
% stage. This preserves the A/B-series isolation of weak-stage failure.
%
% -------------------------------------------------------------------------
% Policies
% -------------------------------------------------------------------------
% Cheap:
%   never allocate extra budget.
%
% Always-extra:
%   run the fallback on every trial, then choose cheap vs fallback using
%   observable prominence.
%
% Oracle-adaptive:
%   upper bound. Extra budget is used only when fallback can rescue a cheap
%   failure. This is NOT a practical algorithm.
%
% Practical-adaptive:
%   low cheap-branch prominence triggers fallback. After fallback, choose
%   the branch with higher prominence.
%
% -------------------------------------------------------------------------
% Cost
% -------------------------------------------------------------------------
% Primary policy cost is expressed relative to the mandatory cheap stage:
%
%   normalized q-search budget = 1 + fallback_rate
%
% and refit calls/trial = fallback_rate.
%
% We also report candidate-q evaluations explicitly.
% Runtime is intentionally secondary at this pilot stage.
%
% Run:
%   results = exp09c1_adaptive_budget;

cfg = config_exp09c1();

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
        'exp09c1_adaptive_budget');
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

required_sel = {'cell_id','weak_ratio','signed_separation','snr_db','Gamma','Lambda'};
assert_table_vars(selected,required_sel,'selected_cells.csv');

required_ref = {'cell_id','baseline_recovery_rate','residual_recovery_rate', ...
    'paired_recovery_penalty','residual_catastrophic_rate'};
assert_table_vars(refined_b2,required_ref,'refined_cell_summary.csv');

selected = sortrows(selected,'cell_id');
refined_b2 = sortrows(refined_b2,'cell_id');

if height(selected)~=height(refined_b2) || ...
        any(selected.cell_id~=refined_b2.cell_id)
    error('B2 selected/refined tables do not align.');
end

fprintf('\n============================================================\n');
fprintf(' EXP009-C1 / Oracle-to-Practical Adaptive Budget\n');
fprintf('============================================================\n');
fprintf('B2 input: %s\n',b2_dir);
fprintf('Output:   %s\n',out_dir);
fprintf('Selected cells: %d\n',height(selected));
fprintf('MC trials/cell: %d\n\n',cfg.num_mc);

%% Common setup
rng(cfg.seed,'twister');

N = cfg.N;
n = 0:N-1;
t = (n-N/2)/N;

q_search = cfg.q_search_min:cfg.q_search_step:cfg.q_search_max;
D_search = build_dechirp_dictionary(q_search,t,cfg);

Nq = numel(q_search);

K = height(selected);
M = cfg.num_mc;
nRows = K*M;

% Match prior strong-referenced SNR convention.
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

%% Trial storage
cell_id = zeros(nRows,1);
trial_id = zeros(nRows,1);

weak_ratio = nan(nRows,1);
signed_sep = nan(nRows,1);
snr_db = nan(nRows,1);
Gamma = nan(nRows,1);
Lambda = nan(nRows,1);

baseline_q_hat = nan(nRows,1);
cheap_q_hat = nan(nRows,1);
fallback_q_hat = nan(nRows,1);

baseline_success = false(nRows,1);
cheap_success = false(nRows,1);
fallback_success = false(nRows,1);

cheap_abs_error = nan(nRows,1);
fallback_abs_error = nan(nRows,1);

cheap_prominence = nan(nRows,1);
fallback_prominence = nan(nRows,1);

cheap_entropy = nan(nRows,1);
fallback_entropy = nan(nRows,1);

cheap_second_to_first = nan(nRows,1);
fallback_second_to_first = nan(nRows,1);

strong_fhat = nan(nRows,1);
strong_refit_residual_ratio = nan(nRows,1);

row = 0;

%% Main simulation: compute ALL branches once
for ik = 1:K
    rA = selected.weak_ratio(ik);
    sep = selected.signed_separation(ik);
    s = selected.snr_db(ik);
    q_s = cfg.q_weak + sep;

    s_w = synth_lfm(cfg.A_strong*rA,cfg.q_weak, ...
        cfg.f_weak,cfg.phi_weak,t,cfg);

    s_s = synth_lfm(cfg.A_strong,q_s, ...
        cfg.f_strong,cfg.phi_strong,t,cfg);

    % Cheap B1-B4 filtered strong residual.
    k_s = get_strong_notch_bin(s_s,q_s,t,cfg);

    e_s = apply_fixed_notch_operator( ...
        s_s,q_s,k_s,cfg.notch_halfwidth_bins,t,cfg);

    nb = noise_bank.(snr_field(s));

    for imc = 1:M
        noise = nb(imc,:);

        x_mix = s_s + s_w + noise;
        x_base = s_w + noise;
        x_cheap = s_w + e_s + noise;

        % Baseline weak-only reference.
        [qhb,~,~] = search_q_concentration( ...
            x_base,q_search,D_search);

        % Cheap residual search.
        [qhc,metric_c,idx_c] = ...
            search_q_concentration( ...
            x_cheap,q_search,D_search);

        feat_c = extract_gate_features( ...
            metric_c,idx_c,cfg);

        % Expensive fallback: off-grid strong parametric refit.
        [x_refit,fhat_s,~,~] = ...
            refit_and_subtract_strong( ...
            x_mix,q_s,t,cfg);

        [qhf,metric_f,idx_f] = ...
            search_q_concentration( ...
            x_refit,q_search,D_search);

        feat_f = extract_gate_features( ...
            metric_f,idx_f,cfg);

        eb = abs(qhb-cfg.q_weak);
        ec = abs(qhc-cfg.q_weak);
        ef = abs(qhf-cfg.q_weak);

        sb = eb <= (cfg.tau_q+cfg.success_tol);
        sc = ec <= (cfg.tau_q+cfg.success_tol);
        sf = ef <= (cfg.tau_q+cfg.success_tol);

        row = row+1;

        cell_id(row) = selected.cell_id(ik);
        trial_id(row) = imc;

        weak_ratio(row) = rA;
        signed_sep(row) = sep;
        snr_db(row) = s;
        Gamma(row) = selected.Gamma(ik);
        Lambda(row) = selected.Lambda(ik);

        baseline_q_hat(row) = qhb;
        cheap_q_hat(row) = qhc;
        fallback_q_hat(row) = qhf;

        baseline_success(row) = sb;
        cheap_success(row) = sc;
        fallback_success(row) = sf;

        cheap_abs_error(row) = ec;
        fallback_abs_error(row) = ef;

        cheap_prominence(row) = feat_c.prominence;
        fallback_prominence(row) = feat_f.prominence;

        cheap_entropy(row) = feat_c.curve_entropy;
        fallback_entropy(row) = feat_f.curve_entropy;

        cheap_second_to_first(row) = feat_c.second_to_first;
        fallback_second_to_first(row) = feat_f.second_to_first;

        strong_fhat(row) = fhat_s;

        strong_refit_residual_ratio(row) = ...
            sum(abs(x_refit).^2)/max(sum(abs(x_mix).^2),eps);
    end
end

%% Assemble branch table
branch_table = table( ...
    cell_id,trial_id,weak_ratio,signed_sep,snr_db,Gamma,Lambda, ...
    baseline_q_hat,cheap_q_hat,fallback_q_hat, ...
    baseline_success,cheap_success,fallback_success, ...
    cheap_abs_error,fallback_abs_error, ...
    cheap_prominence,fallback_prominence, ...
    cheap_entropy,fallback_entropy, ...
    cheap_second_to_first,fallback_second_to_first, ...
    strong_fhat,strong_refit_residual_ratio);

writetable(branch_table, ...
    fullfile(out_dir,'c1_branch_trials.csv'));

%% ------------------------------------------------------------------------
% Reproduction check: Cheap must reproduce B2 residual branch
rep_cell = selected.cell_id;

rep_base = nan(K,1);
rep_cheap = nan(K,1);
rep_fallback = nan(K,1);

rep_base_diff = nan(K,1);
rep_cheap_diff = nan(K,1);

for ik = 1:K
    mm = branch_table.cell_id == selected.cell_id(ik);

    rep_base(ik) = mean(branch_table.baseline_success(mm));
    rep_cheap(ik) = mean(branch_table.cheap_success(mm));
    rep_fallback(ik) = mean(branch_table.fallback_success(mm));

    rep_base_diff(ik) = ...
        rep_base(ik)-refined_b2.baseline_recovery_rate(ik);

    rep_cheap_diff(ik) = ...
        rep_cheap(ik)-refined_b2.residual_recovery_rate(ik);
end

reproduction_check = table( ...
    rep_cell,rep_base,refined_b2.baseline_recovery_rate,rep_base_diff, ...
    rep_cheap,refined_b2.residual_recovery_rate,rep_cheap_diff, ...
    rep_fallback, ...
    'VariableNames',{ ...
    'cell_id', ...
    'c1_baseline_recall','b2_baseline_recall','baseline_diff', ...
    'c1_cheap_recall','b2_residual_recall','cheap_diff', ...
    'fallback_recall'});

writetable(reproduction_check, ...
    fullfile(out_dir,'b2_reproduction_check.csv'));

max_reproduction_diff = ...
    max(abs([rep_base_diff;rep_cheap_diff]));

%% ------------------------------------------------------------------------
% Core branch diagnostics
cheap_recall = mean(cheap_success);
fallback_recall = mean(fallback_success);
baseline_recall = mean(baseline_success);

beneficial = ~cheap_success & fallback_success;
harmful = cheap_success & ~fallback_success;
same_success = cheap_success & fallback_success;
same_fail = ~cheap_success & ~fallback_success;

beneficial_rate = mean(beneficial);
harmful_rate = mean(harmful);

oracle_success = cheap_success | fallback_success;
oracle_recall = mean(oracle_success);

% Oracle minimal useful trigger:
% only spend extra budget on trials where fallback rescues a cheap failure.
oracle_trigger = beneficial;
oracle_trigger_rate = mean(oracle_trigger);

% Practical all-extra branch selector:
% Run fallback on all trials, then keep the branch with higher prominence.
use_fallback_all = ...
    fallback_prominence > cheap_prominence;

always_select_success = cheap_success;
always_select_success(use_fallback_all) = ...
    fallback_success(use_fallback_all);

always_select_recall = mean(always_select_success);

% Always-extra blind replacement, for diagnostic completeness.
always_replace_recall = fallback_recall;

%% ------------------------------------------------------------------------
% Prominence threshold sweep
%
% low prominence => high risk => trigger fallback
valid_prom = isfinite(cheap_prominence);
prom_values = cheap_prominence(valid_prom);

q_levels = linspace(0,1,cfg.num_thresholds);

prom_thresholds = nan(numel(q_levels),1);

for i = 1:numel(q_levels)
    prom_thresholds(i) = empirical_quantile( ...
        prom_values,q_levels(i));
end

prom_thresholds = unique(prom_thresholds,'stable');

prom_curve = evaluate_gate_curve( ...
    cheap_prominence,prom_thresholds,'low', ...
    cheap_success,fallback_success, ...
    cheap_prominence,fallback_prominence, ...
    baseline_success,Nq);

writetable(prom_curve, ...
    fullfile(out_dir,'policy_curve_prominence.csv'));

%% Entropy sweep
% high entropy => high risk => trigger fallback
valid_ent = isfinite(cheap_entropy);
ent_values = cheap_entropy(valid_ent);

ent_thresholds = nan(numel(q_levels),1);

for i = 1:numel(q_levels)
    ent_thresholds(i) = empirical_quantile( ...
        ent_values,1-q_levels(i));
end

ent_thresholds = unique(ent_thresholds,'stable');

ent_curve = evaluate_gate_curve( ...
    cheap_entropy,ent_thresholds,'high', ...
    cheap_success,fallback_success, ...
    cheap_prominence,fallback_prominence, ...
    baseline_success,Nq);

writetable(ent_curve, ...
    fullfile(out_dir,'policy_curve_entropy.csv'));

%% ------------------------------------------------------------------------
% Practical operating point at Oracle-matched extra-budget rate
[~,iprom_match] = min( ...
    abs(prom_curve.fallback_rate-oracle_trigger_rate));

prom_matched = prom_curve(iprom_match,:);

[~,ient_match] = min( ...
    abs(ent_curve.fallback_rate-oracle_trigger_rate));

ent_matched = ent_curve(ient_match,:);

oracle_gain = oracle_recall-cheap_recall;

if oracle_gain > 0
    prom_gain_capture = ...
        (prom_matched.policy_recall-cheap_recall)/oracle_gain;

    ent_gain_capture = ...
        (ent_matched.policy_recall-cheap_recall)/oracle_gain;
else
    prom_gain_capture = NaN;
    ent_gain_capture = NaN;
end

%% ------------------------------------------------------------------------
% Budget-controlled LOCO practical policies
%
% For each held-out cell and each requested target fallback rate:
%   1) determine threshold from TRAINING cells only;
%   2) apply threshold to held-out cell;
%   3) if triggered, run practical branch selection by prominence.
%
% We already computed both branches once; the policy simulation simply
% decides whether fallback budget would have been allocated.
target_rates = cfg.target_fallback_rates(:);

nB = numel(target_rates);

loco_budget = nan(nB,1);
loco_recall = nan(nB,1);
loco_cond_fail = nan(nB,1);
loco_rescue = nan(nB,1);
loco_harm = nan(nB,1);
loco_qevals = nan(nB,1);

loco_trial_policy = cell(nB,1);

for ib = 1:nB
    target_rate = target_rates(ib);

    [policy_success,trigger,use_fb,threshold_by_cell] = ...
        loco_budget_policy( ...
        branch_table.cell_id, ...
        cheap_prominence, ...
        target_rate, ...
        cheap_success,fallback_success, ...
        cheap_prominence,fallback_prominence);

    loco_budget(ib) = mean(trigger);
    loco_recall(ib) = mean(policy_success);

    base_mask = baseline_success;

    if any(base_mask)
        loco_cond_fail(ib) = ...
            mean(~policy_success(base_mask));
    end

    cheap_fail = ~cheap_success;

    if any(cheap_fail)
        loco_rescue(ib) = ...
            mean(policy_success(cheap_fail));
    end

    cheap_ok = cheap_success;

    if any(cheap_ok)
        loco_harm(ib) = ...
            mean(~policy_success(cheap_ok));
    end

    loco_qevals(ib) = Nq*(1+loco_budget(ib));

    loco_trial_policy{ib} = table( ...
        branch_table.cell_id,branch_table.trial_id, ...
        trigger,use_fb,policy_success, ...
        'VariableNames',{ ...
        'cell_id','trial_id','trigger','use_fallback', ...
        'policy_success'});

    % Save per-budget threshold map.
    threshold_tbl = table( ...
        unique(branch_table.cell_id),threshold_by_cell, ...
        'VariableNames',{'cell_id','training_prominence_threshold'});

    writetable(threshold_tbl, ...
        fullfile(out_dir, ...
        sprintf('loco_thresholds_budget_%03d.csv', ...
        round(100*target_rate))));
end

loco_budget_table = table( ...
    target_rates,loco_budget,loco_recall,loco_cond_fail, ...
    loco_rescue,loco_harm,loco_qevals, ...
    'VariableNames',{ ...
    'target_fallback_rate','actual_fallback_rate','policy_recall', ...
    'conditional_failure_rate_given_baseline_success', ...
    'rescue_rate_among_cheap_failures', ...
    'harm_rate_among_cheap_successes', ...
    'q_candidate_evals_per_trial'});

writetable(loco_budget_table, ...
    fullfile(out_dir,'loco_budget_policies.csv'));

%% ------------------------------------------------------------------------
% Cell-level branch and policy diagnostics
cell_diag = table(selected.cell_id, ...
    'VariableNames',{'cell_id'});

cell_diag.weak_ratio = selected.weak_ratio;
cell_diag.signed_separation = selected.signed_separation;
cell_diag.snr_db = selected.snr_db;
cell_diag.Gamma = selected.Gamma;

cell_diag.baseline_recall = nan(K,1);
cell_diag.cheap_recall = nan(K,1);
cell_diag.fallback_recall = nan(K,1);
cell_diag.oracle_recall = nan(K,1);
cell_diag.beneficial_rate = nan(K,1);
cell_diag.harmful_rate = nan(K,1);

for ik = 1:K
    mm = branch_table.cell_id == selected.cell_id(ik);

    cell_diag.baseline_recall(ik) = ...
        mean(baseline_success(mm));

    cell_diag.cheap_recall(ik) = ...
        mean(cheap_success(mm));

    cell_diag.fallback_recall(ik) = ...
        mean(fallback_success(mm));

    cell_diag.oracle_recall(ik) = ...
        mean(cheap_success(mm) | fallback_success(mm));

    cell_diag.beneficial_rate(ik) = ...
        mean(~cheap_success(mm) & fallback_success(mm));

    cell_diag.harmful_rate(ik) = ...
        mean(cheap_success(mm) & ~fallback_success(mm));
end

writetable(cell_diag, ...
    fullfile(out_dir,'cell_branch_diagnostics.csv'));

%% ------------------------------------------------------------------------
% Summary policy table
policy_name = [ ...
    "Cheap"; ...
    "AlwaysExtra_Replace"; ...
    "AlwaysExtra_SelectByProminence"; ...
    "OracleAdaptive_MinUseful"; ...
    "PracticalProminence_MatchedOracleCost"; ...
    "PracticalEntropy_MatchedOracleCost"];

policy_recall = [ ...
    cheap_recall; ...
    always_replace_recall; ...
    always_select_recall; ...
    oracle_recall; ...
    prom_matched.policy_recall; ...
    ent_matched.policy_recall];

fallback_rate = [ ...
    0; ...
    1; ...
    1; ...
    oracle_trigger_rate; ...
    prom_matched.fallback_rate; ...
    ent_matched.fallback_rate];

normalized_search_budget = 1+fallback_rate;

q_candidate_evals_per_trial = ...
    Nq*normalized_search_budget;

refit_calls_per_trial = fallback_rate;

policy_summary = table( ...
    policy_name,policy_recall,fallback_rate, ...
    normalized_search_budget,q_candidate_evals_per_trial, ...
    refit_calls_per_trial, ...
    'VariableNames',{ ...
    'policy','weak_recovery_rate','fallback_rate', ...
    'normalized_q_search_budget','q_candidate_evals_per_trial', ...
    'strong_refit_calls_per_trial'});

writetable(policy_summary, ...
    fullfile(out_dir,'policy_summary.csv'));

%% ------------------------------------------------------------------------
% Main console summary
fprintf('================ C1 REPRODUCTION ====================\n');
fprintf('Max absolute B2 reproduction diff = %.6g\n', ...
    max_reproduction_diff);

fprintf('\n================ C1 BRANCH POTENTIAL =================\n');
fprintf('Baseline weak-only recall          = %.3f\n',baseline_recall);
fprintf('Cheap recall                       = %.3f\n',cheap_recall);
fprintf('Fallback-only recall               = %.3f\n',fallback_recall);
fprintf('Oracle union recall                = %.3f\n',oracle_recall);
fprintf('Rescuable cheap-failure rate       = %.3f\n',beneficial_rate);
fprintf('Fallback harm rate                 = %.3f\n',harmful_rate);
fprintf('Oracle minimal trigger rate        = %.3f\n',oracle_trigger_rate);

fprintf('\n================ C1 PRACTICAL POLICY =================\n');
fprintf('Always-extra select recall         = %.3f\n', ...
    always_select_recall);

fprintf('Prominence matched-cost recall     = %.3f\n', ...
    prom_matched.policy_recall);

fprintf('Prominence matched fallback rate   = %.3f\n', ...
    prom_matched.fallback_rate);

fprintf('Prominence oracle-gain capture     = %.3f\n', ...
    prom_gain_capture);

fprintf('Entropy matched-cost recall        = %.3f\n', ...
    ent_matched.policy_recall);

fprintf('Entropy oracle-gain capture        = %.3f\n', ...
    ent_gain_capture);

fprintf('\nLOCO budget policies:\n');

for ib = 1:nB
    fprintf('  target %.0f%% -> actual %.3f, recall %.3f, q-budget %.3f\n', ...
        100*target_rates(ib), ...
        loco_budget(ib), ...
        loco_recall(ib), ...
        1+loco_budget(ib));
end

fprintf('=====================================================\n');

%% Text summary
fid = fopen(fullfile(out_dir,'summary.txt'),'w');

fprintf(fid,'EXP009-C1 Oracle-to-Practical Adaptive Budget Test\n');
fprintf(fid,'==================================================\n\n');

fprintf(fid,'Selected B2 cells: %d\n',K);
fprintf(fid,'MC trials/cell: %d\n',M);
fprintf(fid,'q candidates/search: %d\n',Nq);
fprintf(fid,'Refit FFT factor: %d\n',cfg.refit_nfft_factor);
fprintf(fid,'Max B2 reproduction diff: %.8g\n\n', ...
    max_reproduction_diff);

fprintf(fid,'Branch potential\n');
fprintf(fid,'----------------\n');
fprintf(fid,'Baseline recall: %.6f\n',baseline_recall);
fprintf(fid,'Cheap recall: %.6f\n',cheap_recall);
fprintf(fid,'Fallback-only recall: %.6f\n',fallback_recall);
fprintf(fid,'Always-extra select recall: %.6f\n',always_select_recall);
fprintf(fid,'Oracle union recall: %.6f\n',oracle_recall);
fprintf(fid,'Beneficial fallback rate: %.6f\n',beneficial_rate);
fprintf(fid,'Harmful fallback rate: %.6f\n',harmful_rate);
fprintf(fid,'Oracle minimal useful trigger rate: %.6f\n\n', ...
    oracle_trigger_rate);

fprintf(fid,'Matched-cost practical policies\n');
fprintf(fid,'-------------------------------\n');
fprintf(fid,'Prominence threshold: %.8f\n',prom_matched.threshold);
fprintf(fid,'Prominence fallback rate: %.6f\n', ...
    prom_matched.fallback_rate);
fprintf(fid,'Prominence recall: %.6f\n', ...
    prom_matched.policy_recall);
fprintf(fid,'Prominence oracle-gain capture: %.6f\n\n', ...
    prom_gain_capture);

fprintf(fid,'Entropy threshold: %.8f\n',ent_matched.threshold);
fprintf(fid,'Entropy fallback rate: %.6f\n', ...
    ent_matched.fallback_rate);
fprintf(fid,'Entropy recall: %.6f\n', ...
    ent_matched.policy_recall);
fprintf(fid,'Entropy oracle-gain capture: %.6f\n\n', ...
    ent_gain_capture);

fprintf(fid,'LOCO budget policies\n');
fprintf(fid,'--------------------\n');

for ib = 1:nB
    fprintf(fid, ...
        ['Target=%.3f Actual=%.6f Recall=%.6f ' ...
         'CondFail=%.6f Rescue=%.6f Harm=%.6f ' ...
         'Qevals=%.2f\n'], ...
        target_rates(ib),loco_budget(ib),loco_recall(ib), ...
        loco_cond_fail(ib),loco_rescue(ib),loco_harm(ib), ...
        loco_qevals(ib));
end

fclose(fid);

%% Figures
make_figures( ...
    out_dir,cfg,branch_table, ...
    prom_curve,ent_curve,policy_summary, ...
    loco_budget_table,cell_diag, ...
    cheap_recall,oracle_recall,oracle_trigger_rate, ...
    prom_matched,ent_matched);

%% Save
results = struct();

results.cfg = cfg;
results.selected = selected;
results.refined_b2 = refined_b2;

results.branch_table = branch_table;
results.reproduction_check = reproduction_check;
results.cell_diag = cell_diag;

results.prominence_curve = prom_curve;
results.entropy_curve = ent_curve;

results.policy_summary = policy_summary;
results.loco_budget_table = loco_budget_table;

results.prom_matched = prom_matched;
results.ent_matched = ent_matched;

results.oracle_trigger_rate = oracle_trigger_rate;
results.oracle_recall = oracle_recall;
results.cheap_recall = cheap_recall;

save(fullfile(out_dir,'exp09c1_results.mat'), ...
    'results','-v7.3');

fprintf('\nSaved EXP009-C1 outputs to:\n%s\n\n',out_dir);

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
function [r,fhat,alpha,atom] = ...
    refit_and_subtract_strong(x,q_strong,t,cfg)
% Off-grid parametric strong-component refit.
%
% q_strong is assumed available from the previous dominant-component stage.
% Carrier/frequency is estimated continuously using zero-padded FFT +
% parabolic interpolation, followed by a complex LS amplitude fit.

N = numel(x);

mu = cfg.mu_scale*(q_strong-cfg.q_ref);

dechirp = exp(-1j*pi*mu*t.^2);

z = x.*dechirp;

nfft = cfg.refit_nfft_factor*N;

Z = fft(z,nfft);
P = abs(Z).^2;

[~,k0] = max(P);

% Quadratic interpolation around FFT-power maximum, including wraparound.
km = mod(k0-2,nfft)+1;
kp = mod(k0,nfft)+1;

ym = P(km);
y0 = P(k0);
yp = P(kp);

den = ym - 2*y0 + yp;

if abs(den) < eps
    delta = 0;
else
    delta = 0.5*(ym-yp)/den;
end

delta = min(max(delta,-1),1);

bin0 = k0-1;

if bin0 > nfft/2
    bin0 = bin0-nfft;
end

% Because t increments by 1/N, DFT bin in nfft maps to f units by N/nfft.
fhat = (bin0+delta)*(N/nfft);

atom = exp(1j*(pi*mu*t.^2 + 2*pi*fhat*t));

den_a = sum(abs(atom).^2);

if den_a <= eps
    alpha = 0;
else
    alpha = sum(conj(atom).*x)/den_a;
end

r = x - alpha*atom;
end

%% ========================================================================
function feat = extract_gate_features(metric,idx_peak,cfg)
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

feat.second_to_first = second_peak/max(peak,eps);
end

%% ========================================================================
function curve = evaluate_gate_curve( ...
    feature,thresholds,direction, ...
    cheap_success,fallback_success, ...
    cheap_prom,fallback_prom,baseline_success,Nq)

nT = numel(thresholds);

threshold = thresholds(:);
fallback_rate = nan(nT,1);
policy_recall = nan(nT,1);
conditional_failure_rate = nan(nT,1);
rescue_rate = nan(nT,1);
harm_rate = nan(nT,1);
normalized_q_search_budget = nan(nT,1);
q_candidate_evals_per_trial = nan(nT,1);

for it = 1:nT
    thr = thresholds(it);

    switch direction
        case 'low'
            trigger = feature <= thr;
        case 'high'
            trigger = feature >= thr;
        otherwise
            error('Unknown gate direction.');
    end

    % After extra computation, keep the branch with higher observable
    % prominence rather than blindly overwriting the cheap result.
    use_fb = trigger & ...
        (fallback_prom > cheap_prom);

    policy_success = cheap_success;
    policy_success(use_fb) = fallback_success(use_fb);

    fallback_rate(it) = mean(trigger);
    policy_recall(it) = mean(policy_success);

    bm = baseline_success;

    if any(bm)
        conditional_failure_rate(it) = ...
            mean(~policy_success(bm));
    end

    cf = ~cheap_success;

    if any(cf)
        rescue_rate(it) = ...
            mean(policy_success(cf));
    end

    cs = cheap_success;

    if any(cs)
        harm_rate(it) = ...
            mean(~policy_success(cs));
    end

    normalized_q_search_budget(it) = ...
        1+fallback_rate(it);

    q_candidate_evals_per_trial(it) = ...
        Nq*normalized_q_search_budget(it);
end

curve = table( ...
    threshold,fallback_rate,policy_recall, ...
    conditional_failure_rate,rescue_rate,harm_rate, ...
    normalized_q_search_budget,q_candidate_evals_per_trial);
end

%% ========================================================================
function [policy_success,trigger,use_fb,threshold_by_cell] = ...
    loco_budget_policy( ...
    cell_id,prominence,target_rate, ...
    cheap_success,fallback_success,cheap_prom,fallback_prom)

cells = unique(cell_id).';

N = numel(cell_id);

policy_success = cheap_success;
trigger = false(N,1);
use_fb = false(N,1);

threshold_by_cell = nan(numel(cells),1);

for ic = 1:numel(cells)
    c = cells(ic);

    test = cell_id==c;
    train = ~test;

    train_prom = prominence(train);
    train_prom = train_prom(isfinite(train_prom));

    if isempty(train_prom)
        continue;
    end

    % low prominence => risk.
    thr = empirical_quantile(train_prom,target_rate);

    threshold_by_cell(ic) = thr;

    trig_test = prominence(test) <= thr;

    idx_test = find(test);

    trigger(idx_test) = trig_test;

    use_test = trig_test & ...
        (fallback_prom(test) > cheap_prom(test));

    use_fb(idx_test) = use_test;

    tmp = cheap_success(test);
    fb = fallback_success(test);

    tmp(use_test) = fb(use_test);

    policy_success(idx_test) = tmp;
end
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

pos = 1 + p*(numel(x)-1);

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
    out_dir,cfg,branch_table,prom_curve,ent_curve,policy_summary, ...
    loco_budget_table,cell_diag,cheap_recall,oracle_recall, ...
    oracle_trigger_rate,prom_matched,ent_matched)

%% Fig 1: Branch potential by cell
fig = figure('Visible',cfg.figure_visible);

Y = [ ...
    cell_diag.cheap_recall, ...
    cell_diag.fallback_recall, ...
    cell_diag.oracle_recall];

bar(Y);

ylim([0 1]);

xlabel('Selected cell ID');
ylabel('Weak recovery rate');

title('C1 Branch Potential by Cell');

legend('Cheap','Parametric refit fallback','Oracle union', ...
    'Location','best');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig01_branch_potential_by_cell.png'), ...
    'Resolution',180);

close(fig);

%% Fig 2: Fallback rescue vs harm
fig = figure('Visible',cfg.figure_visible);

scatter( ...
    cell_diag.beneficial_rate, ...
    cell_diag.harmful_rate, ...
    80,cell_diag.Gamma,'filled');

xlabel('Beneficial fallback rate');
ylabel('Harmful fallback rate');

title('C1 Fallback Rescue-Harm Plane');

cb = colorbar;
cb.Label.String = '\Gamma';

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig02_fallback_rescue_harm.png'), ...
    'Resolution',180);

close(fig);

%% Fig 3: Prominence Pareto
fig = figure('Visible',cfg.figure_visible);

plot( ...
    prom_curve.normalized_q_search_budget, ...
    prom_curve.policy_recall, ...
    '-o','LineWidth',1.2);

hold on;

scatter(1,cheap_recall,70,'filled');
scatter(1+oracle_trigger_rate,oracle_recall,85,'filled');

scatter( ...
    prom_matched.normalized_q_search_budget, ...
    prom_matched.policy_recall, ...
    85,'filled');

xlabel('Normalized q-search budget');
ylabel('Weak recovery rate');

title('C1 Prominence-Gated Quality-Cost Curve');

legend('Practical threshold sweep','Cheap','Oracle adaptive', ...
    'Practical matched-cost','Location','best');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig03_prominence_quality_cost.png'), ...
    'Resolution',180);

close(fig);

%% Fig 4: Prominence vs entropy policy curves
fig = figure('Visible',cfg.figure_visible);

plot( ...
    prom_curve.fallback_rate, ...
    prom_curve.policy_recall, ...
    'LineWidth',1.3);

hold on;

plot( ...
    ent_curve.fallback_rate, ...
    ent_curve.policy_recall, ...
    'LineWidth',1.3);

yline(cheap_recall,'--','Cheap');

scatter( ...
    oracle_trigger_rate,oracle_recall, ...
    80,'filled');

xlabel('Fallback rate');
ylabel('Weak recovery rate');

title('C1 Practical Gate Comparison');

legend('Prominence','Entropy','Cheap','Oracle', ...
    'Location','best');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig04_gate_comparison.png'), ...
    'Resolution',180);

close(fig);

%% Fig 5: LOCO budget policies
fig = figure('Visible',cfg.figure_visible);

plot( ...
    1+loco_budget_table.actual_fallback_rate, ...
    loco_budget_table.policy_recall, ...
    '-o','LineWidth',1.4);

hold on;

scatter(1,cheap_recall,70,'filled');
scatter(1+oracle_trigger_rate,oracle_recall,85,'filled');

xlabel('Normalized q-search budget');
ylabel('Weak recovery rate');

title('C1 LOCO Budget-Controlled Practical Policies');

legend('LOCO practical','Cheap','Oracle adaptive', ...
    'Location','best');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig05_loco_budget_pareto.png'), ...
    'Resolution',180);

close(fig);

%% Fig 6: Policy summary
fig = figure('Visible',cfg.figure_visible);

bar(policy_summary.weak_recovery_rate);

ylim([0 1]);

xticks(1:height(policy_summary));
xticklabels(policy_summary.policy);
xtickangle(30);

ylabel('Weak recovery rate');
title('C1 Policy Summary');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig06_policy_recovery_summary.png'), ...
    'Resolution',180);

close(fig);

%% Fig 7: Cheap confidence vs fallback benefit
benefit = ...
    ~branch_table.cheap_success & ...
    branch_table.fallback_success;

fig = figure('Visible',cfg.figure_visible);

boxchart( ...
    double(benefit)+1, ...
    branch_table.cheap_prominence);

xticks([1 2]);
xticklabels({'No fallback benefit','Fallback rescues'});

ylabel('Cheap-branch prominence');
title('C1 Does Prominence Target Rescuable Trials?');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig07_prominence_vs_fallback_benefit.png'), ...
    'Resolution',180);

close(fig);

%% Fig 8: matched-cost policy cell map
cells = unique(branch_table.cell_id).';
K = numel(cells);

cheap_cell = nan(K,1);
prom_cell = nan(K,1);
oracle_cell = nan(K,1);

% Reconstruct matched prominence policy.
trigger = ...
    branch_table.cheap_prominence <= prom_matched.threshold;

use_fb = trigger & ...
    branch_table.fallback_prominence > ...
    branch_table.cheap_prominence;

pol = branch_table.cheap_success;
pol(use_fb) = branch_table.fallback_success(use_fb);

orc = branch_table.cheap_success | ...
    branch_table.fallback_success;

for i = 1:K
    mm = branch_table.cell_id==cells(i);

    cheap_cell(i) = mean(branch_table.cheap_success(mm));
    prom_cell(i) = mean(pol(mm));
    oracle_cell(i) = mean(orc(mm));
end

fig = figure('Visible',cfg.figure_visible);

bar([cheap_cell,prom_cell,oracle_cell]);

ylim([0 1]);

xlabel('Selected cell ID');
ylabel('Weak recovery rate');

title('C1 Matched-Cost Practical Policy by Cell');

legend('Cheap','Practical','Oracle union', ...
    'Location','best');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig08_matched_cost_by_cell.png'), ...
    'Resolution',180);

close(fig);

end
