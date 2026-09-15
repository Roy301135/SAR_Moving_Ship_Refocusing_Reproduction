function exp09_pa5jb1_selective_n3_pareto()
%EXP09_PA5JB1_SELECTIVE_N3_PARETO
% EXP009 / PA5J-B1
% Selective Neighbor-3 Cost-Reliability Pareto
%
% Research question:
%   Can PA5J-A/B0 internal unreliability diagnostics selectively invoke
%   Neighbor-3 and create a better catastrophic-failure / computation
%   tradeoff than G0 or Always Neighbor-3?
%
% Frozen scientific rules:
%   1) Use stored G0 and Neighbor-3 outcomes; never assume trigger == rescue.
%   2) Use the PA5J-A catastrophic binary label unchanged.
%   3) Rank independently inside the four primary groups:
%        original_grid x Paper1s
%        original_grid x BeamDerived
%        dense_risk    x Paper1s
%        dense_risk    x BeamDerived
%   4) Tie-inclusive selection.
%   5) No truth variable enters any risk score.
%   6) Fusion uses parameter-free within-group empirical risk percentiles.
%   7) Objective-evaluation accounting reuses already-paid G0 work:
%        adaptive cost = G0 cost
%                      + diagnostic overhead
%                      + trigger * (Neighbor3 cost - G0 cost)
%      This is valid only after the cost audit verifies Neighbor3 cost >= G0
%      trial-by-trial and both use the same trial identity.
%   8) Summary exports facts only; no automatic research-branch decision.

clc;
cfg = config_exp09_pa5jb1_selective_n3();

fprintf('============================================================\n');
fprintf('EXP009 / PA5J-B1 Selective Neighbor-3 Pareto\n');
fprintf('============================================================\n');

ensure_dir(cfg.output_dir);
ensure_dir(cfg.figure_dir);

%% ------------------------------------------------------------------------
% 1. Resolve exact upstream artifacts
% -------------------------------------------------------------------------
p_pa5ja_o = resolve_exact_file(cfg.pa5ja_original, cfg.results_root, ...
    "pa5ja_indicator_trials_original.csv");
p_pa5ja_d = resolve_exact_file(cfg.pa5ja_dense, cfg.results_root, ...
    "pa5ja_indicator_trials_dense_risk.csv");
p_pa5i_o = resolve_exact_file(cfg.pa5i_original, cfg.results_root, ...
    "pa5i_trials.csv");
p_pa5i_d = resolve_exact_file(cfg.pa5i_dense, cfg.results_root, ...
    "pa5i_r1_dense_eta_trials.csv");

fprintf('PA5J-A original : %s\n', p_pa5ja_o);
fprintf('PA5J-A dense    : %s\n', p_pa5ja_d);
fprintf('PA5I original   : %s\n', p_pa5i_o);
fprintf('PA5I-R1 dense   : %s\n', p_pa5i_d);

%% ------------------------------------------------------------------------
% 2. Load and schema-contract audit
% -------------------------------------------------------------------------
Tjo = readtable(p_pa5ja_o, 'VariableNamingRule', 'preserve');
Tjd = readtable(p_pa5ja_d, 'VariableNamingRule', 'preserve');
Tio = readtable(p_pa5i_o, 'VariableNamingRule', 'preserve');
Tid = readtable(p_pa5i_d, 'VariableNamingRule', 'preserve');

assert_schema(Tjo, cfg.req_pa5ja, "PA5J-A original");
assert_schema(Tjd, cfg.req_pa5ja, "PA5J-A dense");
assert_schema(Tio, cfg.req_pa5i, "PA5I original");
assert_schema(Tid, cfg.req_pa5i, "PA5I-R1 dense");

assert_no_missing(Tjo, cfg.req_pa5ja, "PA5J-A original");
assert_no_missing(Tjd, cfg.req_pa5ja, "PA5J-A dense");
assert_no_missing(Tio, cfg.req_pa5i, "PA5I original");
assert_no_missing(Tid, cfg.req_pa5i, "PA5I-R1 dense");

%% ------------------------------------------------------------------------
% 3. Canonical trial construction and cross-experiment identity audit
% -------------------------------------------------------------------------
[Co, Ao] = build_canonical(Tjo, Tio, "original_grid", cfg);
[Cd, Ad] = build_canonical(Tjd, Tid, "dense_risk", cfg);

C = [Co; Cd];
A = [Ao; Ad];

% Combined unique source + trial_id
combo_key = string(C.source) + "|" + string(C.trial_id);
assert(numel(unique(combo_key)) == height(C), ...
    'Combined source + trial_id is not unique.');

expected_total = height(Tjo) + height(Tjd);
assert(height(C) == expected_total, 'Complete-case row count changed.');

writetable(C, fullfile(cfg.output_dir, "pa5jb1_canonical_trials.csv"));
writetable(A, fullfile(cfg.output_dir, "pa5jb1_input_audit.csv"));

%% ------------------------------------------------------------------------
% 4. Cost-model audit
% -------------------------------------------------------------------------
assert(all(C.n3_objective_evals >= C.g0_objective_evals), ...
    'Neighbor-3 objective evaluations are lower than G0 for at least one trial.');

C.n3_incremental_evals = C.n3_objective_evals - C.g0_objective_evals;

cost_audit = groupsummary(C, {'source','aperture_mode'}, ...
    {'mean','min','max'}, ...
    {'g0_objective_evals','n3_objective_evals','n3_incremental_evals'});
writetable(cost_audit, fullfile(cfg.output_dir, "pa5jb1_cost_model_audit.csv"));

%% ------------------------------------------------------------------------
% 5. Primary group policy sweep
% -------------------------------------------------------------------------
sources = ["original_grid","dense_risk"];
apertures = ["Paper1s","BeamDerived"];

rows = {};
baseline_rows = {};
tie_rows = {};
r = 0;
rb = 0;
rt = 0;

for isrc = 1:numel(sources)
    for iap = 1:numel(apertures)
        src = sources(isrc);
        ap = apertures(iap);
        idx = string(C.source) == src & string(C.aperture_mode) == ap;
        G = C(idx,:);

        assert(~isempty(G), 'Primary group missing: %s / %s', src, ap);

        % ---- Baseline facts
        g0_fail = logical(G.g0_catastrophic_failure);
        n3_fail = logical(G.n3_catastrophic_failure);
        g0_err = double(G.g0_branch_error_bins);
        n3_err = double(G.n3_branch_error_bins);
        g0_cost = double(G.g0_objective_evals);
        n3_cost = double(G.n3_objective_evals);

        [g0_lo,g0_hi] = wilson_ci(sum(g0_fail), numel(g0_fail));
        [n3_lo,n3_hi] = wilson_ci(sum(n3_fail), numel(n3_fail));

        rb = rb + 1;
        baseline_rows(rb,:) = {src, ap, "G0_OriginalTop1", height(G), ...
            sum(g0_fail), mean(g0_fail), g0_lo, g0_hi, mean(g0_cost), ...
            qtile(g0_err,0.95), qtile(g0_err,0.99), ...
            qtile(g0_err,0.999), max(g0_err)}; %#ok<AGROW>

        rb = rb + 1;
        baseline_rows(rb,:) = {src, ap, "Always_Neighbor3", height(G), ...
            sum(n3_fail), mean(n3_fail), n3_lo, n3_hi, mean(n3_cost), ...
            qtile(n3_err,0.95), qtile(n3_err,0.99), ...
            qtile(n3_err,0.999), max(n3_err)}; %#ok<AGROW>

        % ---- Frozen risk signals, higher = more dangerous
        s_five = -double(G.fivebin_peak_fraction);   % low raw = high risk
        s_ent  =  double(G.local_entropy5);          % high raw = high risk
        s_lr   =  double(G.refined_lr_asymmetry);    % high raw = high risk

        % Parameter-free, within-group, tie-preserving empirical risk ranks.
        p_five = risk_percentile(s_five);
        p_ent  = risk_percentile(s_ent);
        p_lr   = risk_percentile(s_lr);

        s_cost0 = max([p_five,p_ent],[],2);
        s_all3  = max([p_five,p_ent,p_lr],[],2);

        score_matrix = [s_five, s_ent, s_cost0, s_lr, s_all3];

        mean_g0_cost = mean(g0_cost);
        mean_n3_cost = mean(n3_cost);
        denom_norm = mean_n3_cost - mean_g0_cost;
        assert(denom_norm > 0, 'Non-positive G0 -> N3 mean cost gap.');

        for ip = 1:numel(cfg.policy_names)
            pname = cfg.policy_names(ip);
            score = score_matrix(:,ip);
            diag_cost = double(cfg.policy_uses_refined(ip)) * ...
                        cfg.refined_lr_extra_evals;

            for ib = 1:numel(cfg.budgets)
                b = cfg.budgets(ib);

                [trigger, sel] = tie_inclusive_top(score, b);

                % Actual final outcome: use N3 only where triggered.
                final_fail = g0_fail;
                final_fail(trigger) = n3_fail(trigger);

                final_err = g0_err;
                final_err(trigger) = n3_err(trigger);

                rescued = trigger & g0_fail & ~n3_fail;
                induced = trigger & ~g0_fail & n3_fail;
                persistent_after_fallback = trigger & g0_fail & n3_fail;
                missed_g0_fail = ~trigger & g0_fail;

                % Cost accounting:
                % G0 is always paid because the gate is based on G0 state.
                % If policy needs refined_lr_asymmetry, +2 is paid on every
                % trial because all trials must be ranked before fallback.
                % Triggered trials then pay only the incremental G0->N3
                % objective evaluations, reusing their existing G0 work.
                trial_cost = g0_cost + diag_cost + ...
                    double(trigger) .* (n3_cost - g0_cost);

                mean_cost = mean(trial_cost);
                norm_cost = (mean_cost - mean_g0_cost) / denom_norm;

                n_fail = sum(final_fail);
                [pf_lo,pf_hi] = wilson_ci(n_fail, height(G));

                n_g0fail = sum(g0_fail);
                if n_g0fail > 0
                    rescue_of_g0fail = sum(rescued) / n_g0fail;
                    unresolved_of_g0fail = sum(final_fail) / n_g0fail;
                else
                    rescue_of_g0fail = NaN;
                    unresolved_of_g0fail = NaN;
                end

                n_g0success = sum(~g0_fail);
                if n_g0success > 0
                    induced_of_g0success = sum(induced) / n_g0success;
                else
                    induced_of_g0success = NaN;
                end

                r = r + 1;
                rows(r,:) = { ...
                    src, ap, pname, b, ...
                    sel.actual_fraction, sel.selected_count, ...
                    sel.target_count, sel.cutoff_score, sel.cutoff_tie_count, ...
                    sel.budget_inflation, diag_cost, ...
                    mean_cost, norm_cost, ...
                    n_fail, height(G), mean(final_fail), pf_lo, pf_hi, ...
                    sum(rescued), n_g0fail, rescue_of_g0fail, ...
                    sum(induced), n_g0success, induced_of_g0success, ...
                    sum(persistent_after_fallback), sum(missed_g0_fail), ...
                    unresolved_of_g0fail, ...
                    qtile(final_err,0.95), qtile(final_err,0.99), ...
                    qtile(final_err,0.999), max(final_err)}; %#ok<AGROW>

                rt = rt + 1;
                tie_rows(rt,:) = {src, ap, pname, b, ...
                    sel.target_count, sel.selected_count, ...
                    sel.actual_fraction, sel.cutoff_score, ...
                    sel.cutoff_tie_count, sel.budget_inflation}; %#ok<AGROW>
            end
        end
    end
end

baseline_names = {'source','aperture_mode','method','n_trials', ...
    'failure_count','failure_probability','failure_wilson_lo', ...
    'failure_wilson_hi','mean_objective_evals','q95_branch_error_bins', ...
    'q99_branch_error_bins','q999_branch_error_bins','max_branch_error_bins'};

policy_names = {'source','aperture_mode','policy','nominal_budget', ...
    'actual_trigger_fraction','selected_count','target_count', ...
    'cutoff_score','cutoff_tie_count','budget_inflation', ...
    'diagnostic_extra_evals_per_trial', ...
    'mean_objective_evals','normalized_cost_G0_to_N3', ...
    'final_failure_count','n_trials','final_failure_probability', ...
    'failure_wilson_lo','failure_wilson_hi', ...
    'rescued_count','g0_failure_count','rescued_fraction_of_g0_failures', ...
    'induced_count','g0_success_count','induced_fraction_of_g0_successes', ...
    'persistent_after_fallback_count','missed_g0_failure_count', ...
    'unresolved_fraction_of_g0_failures', ...
    'q95_final_branch_error_bins','q99_final_branch_error_bins', ...
    'q999_final_branch_error_bins','max_final_branch_error_bins'};

tie_names = {'source','aperture_mode','policy','nominal_budget', ...
    'target_count','selected_count','actual_trigger_fraction', ...
    'cutoff_score','cutoff_tie_count','budget_inflation'};

B = cell2table(baseline_rows, 'VariableNames', baseline_names);
P = cell2table(rows, 'VariableNames', policy_names);
Tie = cell2table(tie_rows, 'VariableNames', tie_names);

writetable(B, fullfile(cfg.output_dir, "pa5jb1_baselines.csv"));
writetable(P, fullfile(cfg.output_dir, "pa5jb1_policy_sweep.csv"));
writetable(Tie, fullfile(cfg.output_dir, "pa5jb1_tie_audit.csv"));

%% ------------------------------------------------------------------------
% 6. Smoke tests
% -------------------------------------------------------------------------
smoke = run_smoke_tests(C, B, P, cfg);
writetable(smoke, fullfile(cfg.output_dir, "pa5jb1_smoke_test.csv"));

assert(all(smoke.pass), ...
    'At least one PA5J-B1 smoke test failed. Formal result is not valid.');

%% ------------------------------------------------------------------------
% 7. Figures: separate primary groups for readability
% -------------------------------------------------------------------------
for isrc = 1:numel(sources)
    for iap = 1:numel(apertures)
        src = sources(isrc);
        ap = apertures(iap);
        make_group_figures(P, B, src, ap, cfg);
    end
end

%% ------------------------------------------------------------------------
% 8. Factual summary only
% -------------------------------------------------------------------------
write_summary(C, B, P, smoke, cfg, ...
    {p_pa5ja_o,p_pa5ja_d,p_pa5i_o,p_pa5i_d});

fprintf('\nPA5J-B1 formal run completed.\n');
fprintf('Output: %s\n', cfg.output_dir);
fprintf('No automatic research-branch interpretation was performed.\n');

end

%% =========================================================================
% Canonical construction
% =========================================================================
function [C,A] = build_canonical(Tj, Ti, expected_source, cfg)

src = unique(string(Tj.source));
assert(numel(src)==1 && src==expected_source, ...
    'Unexpected PA5J-A source for %s.', expected_source);

m = string(Ti.method);
G0 = Ti(m == cfg.method_g0,:);
N3 = Ti(m == cfg.method_n3,:);

assert(height(G0)==height(Tj), ...
    'G0 row count mismatch for %s.', expected_source);
assert(height(N3)==height(Tj), ...
    'Neighbor-3 row count mismatch for %s.', expected_source);

key_j  = physical_key(Tj, cfg.identity_fields);
key_g0 = physical_key(G0, cfg.identity_fields);
key_n3 = physical_key(N3, cfg.identity_fields);

assert(numel(unique(key_j))==height(Tj), ...
    'PA5J-A physical identity is not unique for %s.', expected_source);
assert(numel(unique(key_g0))==height(G0), ...
    'PA5I G0 physical identity is not unique for %s.', expected_source);
assert(numel(unique(key_n3))==height(N3), ...
    'PA5I Neighbor-3 physical identity is not unique for %s.', expected_source);

[tf0,loc0] = ismember(key_j,key_g0);
[tf1,loc1] = ismember(key_j,key_n3);
assert(all(tf0) && all(tf1), ...
    'Physical identity join is incomplete for %s.', expected_source);

G0 = G0(loc0,:);
N3 = N3(loc1,:);

% Consumer-schema cross-check: PA5J-A G0 outcome must exactly inherit PA5I.
max_err_diff = max(abs(double(Tj.branch_error_to_global_bins) - ...
                       double(G0.branch_error_to_global_bins)));
fail_match = all(double(Tj.catastrophic_branch_failure) == ...
                 double(G0.catastrophic_branch_failure));

assert(max_err_diff <= cfg.branch_error_match_tol, ...
    'Stored G0 branch error differs between PA5J-A and PA5I for %s.', ...
    expected_source);
assert(fail_match, ...
    'Stored G0 catastrophic label differs between PA5J-A and PA5I for %s.', ...
    expected_source);

assert(all(double(N3.n_objective_evals) >= double(G0.n_objective_evals)), ...
    'N3 cost < G0 cost for at least one trial in %s.', expected_source);

C = Tj;
C.g0_branch_error_bins = double(G0.branch_error_to_global_bins);
C.g0_catastrophic_failure = double(G0.catastrophic_branch_failure);
C.g0_objective_evals = double(G0.n_objective_evals);

C.n3_branch_error_bins = double(N3.branch_error_to_global_bins);
C.n3_catastrophic_failure = double(N3.catastrophic_branch_failure);
C.n3_objective_evals = double(N3.n_objective_evals);

A = table( ...
    expected_source, height(Tj), height(G0), height(N3), ...
    numel(unique(key_j)), ...
    sum(~tf0), sum(~tf1), ...
    max_err_diff, fail_match, ...
    sum(C.g0_catastrophic_failure), ...
    sum(C.n3_catastrophic_failure), ...
    sum(C.g0_catastrophic_failure==1 & C.n3_catastrophic_failure==0), ...
    sum(C.g0_catastrophic_failure==0 & C.n3_catastrophic_failure==1), ...
    mean(C.g0_objective_evals), mean(C.n3_objective_evals), ...
    min(C.n3_objective_evals-C.g0_objective_evals), ...
    max(C.n3_objective_evals-C.g0_objective_evals), ...
    'VariableNames', { ...
    'source','pa5ja_rows','g0_rows','n3_rows','unique_physical_keys', ...
    'unmatched_g0','unmatched_n3','max_g0_branch_error_mismatch', ...
    'g0_failure_label_match','g0_failure_count','n3_failure_count', ...
    'g0_fail_to_n3_success','g0_success_to_n3_fail', ...
    'mean_g0_objective_evals','mean_n3_objective_evals', ...
    'min_incremental_n3_evals','max_incremental_n3_evals'});

end

%% =========================================================================
% Risk policy helpers
% =========================================================================
function p = risk_percentile(score)
% Tie-preserving midrank percentile. Higher score = higher risk.
score = double(score(:));
assert(all(isfinite(score)), 'Non-finite risk score.');

n = numel(score);
if n==1
    p = 1;
    return;
end

[~,~,ic] = unique(score,'sorted');
counts = accumarray(ic,1);
hi = cumsum(counts);
lo = hi-counts+1;
mid = (lo+hi)/2;
rankv = mid(ic);
p = (rankv-1)/(n-1);
end

function [mask,s] = tie_inclusive_top(score,b)
score = double(score(:));
n = numel(score);
assert(all(isfinite(score)), 'Non-finite policy score.');
assert(b>=0 && b<=1, 'Budget outside [0,1].');

if b==0
    mask = false(n,1);
    s = selection_struct(0,0,0,NaN,0,0);
    return;
end

if b==1
    mask = true(n,1);
    cutoff = min(score);
    tie_n = sum(score==cutoff);
    s = selection_struct(n,n,1,cutoff,tie_n,0);
    return;
end

target = ceil(b*n);
ss = sort(score,'descend');
cutoff = ss(target);

% Frozen rule: do not use trial_id / row order to break a tie.
mask = score >= cutoff;
selected = sum(mask);
actual = selected/n;
tie_n = sum(score==cutoff);
inflation = actual-b;

s = selection_struct(target,selected,actual,cutoff,tie_n,inflation);
end

function s = selection_struct(target,selected,actual,cutoff,tie_n,inflation)
s.target_count = target;
s.selected_count = selected;
s.actual_fraction = actual;
s.cutoff_score = cutoff;
s.cutoff_tie_count = tie_n;
s.budget_inflation = inflation;
end

%% =========================================================================
% Statistics
% =========================================================================
function [lo,hi] = wilson_ci(k,n)
if n<=0
    lo = NaN; hi = NaN; return;
end
z = 1.959963984540054;
phat = k/n;
den = 1 + z^2/n;
ctr = (phat + z^2/(2*n))/den;
half = z*sqrt(phat*(1-phat)/n + z^2/(4*n^2))/den;
lo = max(0,ctr-half);
hi = min(1,ctr+half);
end

function q = qtile(x,p)
x = sort(double(x(:)));
x = x(isfinite(x));
if isempty(x)
    q = NaN; return;
end
if numel(x)==1
    q = x(1); return;
end
pos = 1 + (numel(x)-1)*p;
i0 = floor(pos);
i1 = ceil(pos);
if i0==i1
    q = x(i0);
else
    a = pos-i0;
    q = (1-a)*x(i0) + a*x(i1);
end
end

%% =========================================================================
% Smoke tests
% =========================================================================
function S = run_smoke_tests(C,B,P,cfg)

name = strings(0,1);
pass = false(0,1);
detail = strings(0,1);

[name,pass,detail] = add_test(name,pass,detail, ...
    "combined_source_trial_id_unique", ...
    numel(unique(string(C.source)+"|"+string(C.trial_id)))==height(C), ...
    sprintf('%d / %d unique', ...
    numel(unique(string(C.source)+"|"+string(C.trial_id))),height(C)));

expected_rows = 4 * numel(cfg.policy_names) * numel(cfg.budgets);
[name,pass,detail] = add_test(name,pass,detail, ...
    "policy_row_count", height(P)==expected_rows, ...
    sprintf('%d rows, expected %d',height(P),expected_rows));

z = P(P.nominal_budget==0,:);
[name,pass,detail] = add_test(name,pass,detail, ...
    "zero_budget_selects_none", all(z.selected_count==0), ...
    sprintf('max selected = %d',max(z.selected_count)));

f = P(P.nominal_budget==1,:);
[name,pass,detail] = add_test(name,pass,detail, ...
    "full_budget_selects_all", all(f.selected_count==f.n_trials), ...
    sprintf('%d full-budget rows checked',height(f)));

% At full fallback every policy must equal stored Always-N3 failure count.
ok_full_fail = true;
for i=1:height(f)
    bb = B(string(B.source)==string(f.source(i)) & ...
           string(B.aperture_mode)==string(f.aperture_mode(i)) & ...
           string(B.method)=="Always_Neighbor3",:);
    ok_full_fail = ok_full_fail && ...
        (f.final_failure_count(i)==bb.failure_count(1));
end
[name,pass,detail] = add_test(name,pass,detail, ...
    "full_budget_matches_neighbor3_failure", ok_full_fail, ...
    "All policy endpoints checked against Always Neighbor-3.");

[name,pass,detail] = add_test(name,pass,detail, ...
    "all_n3_incremental_cost_nonnegative", ...
    all(C.n3_objective_evals-C.g0_objective_evals>=0), ...
    sprintf('min delta = %.3f', ...
    min(C.n3_objective_evals-C.g0_objective_evals)));

% Stored G0 label consistency in canonical trials.
[name,pass,detail] = add_test(name,pass,detail, ...
    "canonical_g0_label_matches_pa5ja", ...
    all(double(C.catastrophic_branch_failure)== ...
        double(C.g0_catastrophic_failure)), ...
    "PA5J-A and PA5I G0 labels agree.");

% Wilson edge behavior.
[lo0,hi0] = wilson_ci(0,100);
[lo1,hi1] = wilson_ci(100,100);
ok_ci = isfinite(lo0) && isfinite(hi0) && isfinite(lo1) && ...
        isfinite(hi1) && lo0>=0 && hi0<=1 && lo1>=0 && hi1<=1;
[name,pass,detail] = add_test(name,pass,detail, ...
    "wilson_edge_cases", ok_ci, ...
    sprintf('[0/100]=[%.6g,%.6g], [100/100]=[%.6g,%.6g]', ...
    lo0,hi0,lo1,hi1));

S = table(name,pass,detail);
end

function [name,pass,detail] = add_test(name,pass,detail,nm,ok,dt)
name(end+1,1)=string(nm);
pass(end+1,1)=logical(ok);
detail(end+1,1)=string(dt);
end

%% =========================================================================
% Figures
% =========================================================================
function make_group_figures(P,B,src,ap,cfg)

Q = P(string(P.source)==src & string(P.aperture_mode)==ap,:);
Bb = B(string(B.source)==src & string(B.aperture_mode)==ap,:);

safe = regexprep(char(src+"_"+ap),'[^A-Za-z0-9_]','_');

% Figure 1: primary cost-reliability Pareto
fig = figure('Visible','off','Color','w');
hold on; grid on; box on;
pols = unique(string(Q.policy),'stable');
for i=1:numel(pols)
    R = Q(string(Q.policy)==pols(i),:);
    [x,ord] = sort(R.mean_objective_evals);
    y = R.final_failure_probability(ord);
    plot(x,y,'-o','DisplayName',pols(i),'LineWidth',1.2,'MarkerSize',4);
end
g0 = Bb(string(Bb.method)=="G0_OriginalTop1",:);
n3 = Bb(string(Bb.method)=="Always_Neighbor3",:);
plot(g0.mean_objective_evals,g0.failure_probability,'s', ...
    'MarkerSize',8,'LineWidth',1.5,'DisplayName','G0');
plot(n3.mean_objective_evals,n3.failure_probability,'d', ...
    'MarkerSize',8,'LineWidth',1.5,'DisplayName','Always N3');
xlabel('Mean objective evaluations');
ylabel('Final catastrophic failure probability');
title(sprintf('%s / %s: cost-reliability Pareto',src,ap),'Interpreter','none');
legend('Location','best','Interpreter','none');
exportgraphics(fig,fullfile(cfg.figure_dir, ...
    "fig01_pareto_"+safe+".png"),'Resolution',180);
close(fig);

% Figure 2: final failure vs actual fallback fraction
fig = figure('Visible','off','Color','w');
hold on; grid on; box on;
for i=1:numel(pols)
    R = Q(string(Q.policy)==pols(i),:);
    [x,ord] = sort(R.actual_trigger_fraction);
    y = R.final_failure_probability(ord);
    plot(x,y,'-o','DisplayName',pols(i),'LineWidth',1.2,'MarkerSize',4);
end
xlabel('Actual fallback fraction');
ylabel('Final catastrophic failure probability');
title(sprintf('%s / %s: reliability vs fallback',src,ap),'Interpreter','none');
legend('Location','best','Interpreter','none');
exportgraphics(fig,fullfile(cfg.figure_dir, ...
    "fig02_failure_vs_fallback_"+safe+".png"),'Resolution',180);
close(fig);

% Figure 3: max final branch error vs mean cost
fig = figure('Visible','off','Color','w');
hold on; grid on; box on;
for i=1:numel(pols)
    R = Q(string(Q.policy)==pols(i),:);
    [x,ord] = sort(R.mean_objective_evals);
    y = R.max_final_branch_error_bins(ord);
    plot(x,y,'-o','DisplayName',pols(i),'LineWidth',1.2,'MarkerSize',4);
end
plot(g0.mean_objective_evals,g0.max_branch_error_bins,'s', ...
    'MarkerSize',8,'LineWidth',1.5,'DisplayName','G0');
plot(n3.mean_objective_evals,n3.max_branch_error_bins,'d', ...
    'MarkerSize',8,'LineWidth',1.5,'DisplayName','Always N3');
xlabel('Mean objective evaluations');
ylabel('Max final branch error (bins)');
title(sprintf('%s / %s: catastrophic tail',src,ap),'Interpreter','none');
legend('Location','best','Interpreter','none');
exportgraphics(fig,fullfile(cfg.figure_dir, ...
    "fig03_maxerror_vs_cost_"+safe+".png"),'Resolution',180);
close(fig);

end

%% =========================================================================
% Summary
% =========================================================================
function write_summary(C,B,P,S,cfg,paths)

f = fopen(fullfile(cfg.output_dir, ...
    "PA5JB1_FORMAL_METRIC_SUMMARY.txt"),'w');
assert(f>0,'Cannot open summary file.');
cleanup = onCleanup(@() fclose(f)); %#ok<NASGU>

fprintf(f,'EXP009 / PA5J-B1 formal metric export\n');
fprintf(f,'No automatic research-branch interpretation.\n\n');

fprintf(f,'Inputs:\n');
for i=1:numel(paths)
    fprintf(f,'  %s\n',paths{i});
end

fprintf(f,'\nCanonical trials: %d\n',height(C));
fprintf(f,'Unique source+trial_id: %d\n', ...
    numel(unique(string(C.source)+"|"+string(C.trial_id))));
fprintf(f,'Policy sweep rows: %d\n',height(P));
fprintf(f,'All smoke tests pass: %d\n',all(S.pass));

fprintf(f,'\nStored upstream G0 -> Neighbor-3 audit:\n');
srcs = unique(string(C.source),'stable');
for i=1:numel(srcs)
    D=C(string(C.source)==srcs(i),:);
    fprintf(f,'  %s: N=%d, G0 failures=%d, N3 failures=%d, ', ...
        srcs(i),height(D),sum(D.g0_catastrophic_failure), ...
        sum(D.n3_catastrophic_failure));
    fprintf(f,'G0 fail->N3 success=%d, G0 success->N3 fail=%d\n', ...
        sum(D.g0_catastrophic_failure==1 & D.n3_catastrophic_failure==0), ...
        sum(D.g0_catastrophic_failure==0 & D.n3_catastrophic_failure==1));
    fprintf(f,'       mean evals G0=%.6f, N3=%.6f, delta=%.6f\n', ...
        mean(D.g0_objective_evals),mean(D.n3_objective_evals), ...
        mean(D.n3_objective_evals-D.g0_objective_evals));
end

fprintf(f,'\nPrimary group baselines:\n');
for i=1:height(B)
    fprintf(f,'  %s / %s / %s: failures=%d/%d, P_F=%.9g, mean evals=%.6f, max err=%.9g\n', ...
        string(B.source(i)),string(B.aperture_mode(i)),string(B.method(i)), ...
        B.failure_count(i),B.n_trials(i),B.failure_probability(i), ...
        B.mean_objective_evals(i),B.max_branch_error_bins(i));
end

fprintf(f,'\nFrozen policies:\n');
for i=1:numel(cfg.policy_names)
    fprintf(f,'  %s; refined-LR diagnostic cost=%d eval/trial\n', ...
        cfg.policy_names(i), ...
        double(cfg.policy_uses_refined(i))*cfg.refined_lr_extra_evals);
end

fprintf(f,'\nCost model:\n');
fprintf(f,'  G0 is always paid before the diagnostic decision.\n');
fprintf(f,'  Triggered fallback cost adds (N3 evals - G0 evals).\n');
fprintf(f,'  Refined-LR policies add %d objective evaluations to every trial.\n', ...
    cfg.refined_lr_extra_evals);
fprintf(f,'  No threshold or operating point is locked in this experiment.\n');

end

%% =========================================================================
% Generic audits / IO
% =========================================================================
function assert_schema(T,required,label)
vars = string(T.Properties.VariableNames);
missing = required(~ismember(required,vars));
assert(isempty(missing), ...
    '%s missing required fields: %s',label,strjoin(missing,', '));
end

function assert_no_missing(T,required,label)
for i=1:numel(required)
    v = char(required(i));
    x = T.(v);
    assert(~any(ismissing(x)), ...
        '%s contains missing values in %s.',label,v);
end
end

function key = physical_key(T,fields)
n = height(T);
key = repmat("",n,1);
for j=1:numel(fields)
    v = fields{j};
    x = T.(v);
    if isnumeric(x) || islogical(x)
        piece = compose("%.17g",double(x));
    else
        piece = string(x);
    end
    if j==1
        key = piece;
    else
        key = key + "|" + piece;
    end
end
end

function path_out = resolve_exact_file(expected_path,search_root,filename)
if isfile(expected_path)
    path_out = expected_path;
    return;
end

fprintf('Expected path missing, exact-filename search: %s\n',filename);
hits = dir(fullfile(search_root,"**",filename));
assert(numel(hits)==1, ...
    ['Expected exactly one artifact named %s under %s; found %d. ', ...
     'STOP: resolve path ambiguity before formal run.'], ...
    filename,search_root,numel(hits));

path_out = fullfile(hits(1).folder,hits(1).name);
end

function ensure_dir(p)
if ~isfolder(p)
    mkdir(p);
end
end
