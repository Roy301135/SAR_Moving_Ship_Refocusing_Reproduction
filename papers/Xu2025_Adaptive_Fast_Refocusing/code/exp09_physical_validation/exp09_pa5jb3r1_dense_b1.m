function exp09_pa5jb3r1_dense_b1()
%EXP09_PA5JB3R1_DENSE_B1
% EXP009 / PA5J-B3-R1
% Dense Single-Stage Comparator Audit
%
% Core question:
%   After enumerating every attainable deterministic tie-inclusive
%   threshold of every frozen B1 policy, do B3 staged policies still create
%   new cost-reliability Pareto points?
%
% This is a fairness / contribution audit:
%   - no new physical simulation;
%   - no new feature;
%   - no new policy;
%   - no threshold tuning;
%   - no interpolation invented between unattainable deterministic points.
%
% The dense single-stage comparator is exact for the stored deterministic
% policy scores under the frozen tie-inclusive rule.

clc;
cfg = config_exp09_pa5jb3r1_dense_b1();

fprintf('============================================================\n');
fprintf('EXP009 / PA5J-B3-R1 Dense Single-Stage Comparator Audit\n');
fprintf('============================================================\n');

ensure_dir(cfg.output_dir);
ensure_dir(cfg.figure_dir);

%% ------------------------------------------------------------------------
% 1. Resolve inputs
% -------------------------------------------------------------------------
p_trials = resolve_exact_file(cfg.input_trials,cfg.results_root, ...
    "pa5jb1_canonical_trials.csv");
p_b1 = resolve_exact_file(cfg.input_b1_sampled,cfg.results_root, ...
    "pa5jb1_policy_sweep.csv");
p_base = resolve_exact_file(cfg.input_baselines,cfg.results_root, ...
    "pa5jb1_baselines.csv");
p_b3 = resolve_exact_file(cfg.input_b3,cfg.results_root, ...
    "pa5jb3_staged_sweep.csv");

fprintf('Canonical trials : %s\n',p_trials);
fprintf('B1 sampled sweep : %s\n',p_b1);
fprintf('B1 baselines     : %s\n',p_base);
fprintf('B3 staged sweep  : %s\n',p_b3);

C = readtable(p_trials,'VariableNamingRule','preserve');
B1 = readtable(p_b1,'VariableNamingRule','preserve');
Base = readtable(p_base,'VariableNamingRule','preserve');
B3 = readtable(p_b3,'VariableNamingRule','preserve');

assert_schema(C,cfg.req_trials,"B1 canonical trials");
assert_schema(B1,cfg.req_b1,"B1 sampled sweep");
assert_schema(Base,cfg.req_base,"B1 baselines");
assert_schema(B3,cfg.req_b3,"B3 staged sweep");
assert_no_missing(C,cfg.req_trials,"B1 canonical trials");

combo = string(C.source)+"|"+string(C.trial_id);
assert(numel(unique(combo))==height(C), ...
    'source + trial_id is not unique.');

assert(all(double(C.n3_objective_evals)>= ...
           double(C.g0_objective_evals)), ...
    'Neighbor-3 objective cost below G0 for at least one trial.');

write_provenance(cfg,p_trials,p_b1,p_base,p_b3);

%% ------------------------------------------------------------------------
% 2. Enumerate every attainable B1 threshold
%    Efficient cumulative implementation:
%    sort once by risk score, then advance one complete tie class at a time.
% -------------------------------------------------------------------------
dense_rows = {};
rd = 0;

for isrc=1:numel(cfg.sources)
    src=cfg.sources(isrc);

    for iap=1:numel(cfg.aperture_modes)
        ap=cfg.aperture_modes(iap);

        idx=string(C.source)==src & string(C.aperture_mode)==ap;
        G=C(idx,:);
        assert(~isempty(G),'Missing primary group: %s / %s',src,ap);

        g0_fail=logical(G.g0_catastrophic_failure);
        n3_fail=logical(G.n3_catastrophic_failure);
        g0_cost=double(G.g0_objective_evals);
        n3_cost=double(G.n3_objective_evals);

        s_five=-double(G.fivebin_peak_fraction);
        s_ent=double(G.local_entropy5);
        s_lr=double(G.refined_lr_asymmetry);

        p_five=risk_percentile(s_five);
        p_ent=risk_percentile(s_ent);
        p_lr=risk_percentile(s_lr);

        s_cost0=max([p_five,p_ent],[],2);
        s_all3=max([p_five,p_ent,p_lr],[],2);

        score_matrix=[s_five,s_ent,s_cost0,s_lr,s_all3];

        for ip=1:numel(cfg.policy_names)
            pname=cfg.policy_names(ip);
            score=score_matrix(:,ip);
            diag_cost=double(cfg.policy_uses_refined(ip))* ...
                cfg.refined_lr_extra_evals;

            R=enumerate_policy_endpoints( ...
                src,ap,pname,diag_cost,score, ...
                g0_fail,n3_fail,g0_cost,n3_cost);

            nr=size(R,1);
            dense_rows(rd+(1:nr),:)=R; %#ok<AGROW>
            rd=rd+nr;
        end
    end
end

dense_names={ ...
    'source','aperture_mode','policy', ...
    'diagnostic_extra_evals_per_trial','cutoff_score', ...
    'cutoff_tie_count','selected_count','actual_trigger_fraction', ...
    'mean_objective_evals','final_failure_count','n_trials', ...
    'final_failure_probability','failure_wilson_lo','failure_wilson_hi', ...
    'rescued_count','induced_count','persistent_after_fallback_count', ...
    'missed_g0_failure_count'};

D=cell2table(dense_rows,'VariableNames',dense_names);
writetable(D,fullfile(cfg.output_dir,"pa5jb3r1_dense_b1_points.csv"));

%% ------------------------------------------------------------------------
% 3. Reconstruct every sampled B1 point from dense endpoints
% -------------------------------------------------------------------------
audit_rows={};
ra=0;

for i=1:height(B1)
    src=string(B1.source(i));
    ap=string(B1.aperture_mode(i));
    pol=string(B1.policy(i));

    if ~ismember(pol,cfg.policy_names)
        continue;
    end

    selected=B1.selected_count(i);

    Q=D(string(D.source)==src & ...
        string(D.aperture_mode)==ap & ...
        string(D.policy)==pol & ...
        D.selected_count==selected,:);

    % A unique selected_count is expected under nested tie-inclusive sets.
    assert(height(Q)==1, ...
        'Dense comparator cannot uniquely reconstruct B1 point.');

    c_match=abs(Q.mean_objective_evals(1)- ...
        B1.mean_objective_evals(i))<=cfg.audit_tol;
    f_match=Q.final_failure_count(1)==B1.final_failure_count(i);
    a_match=abs(Q.actual_trigger_fraction(1)- ...
        B1.actual_trigger_fraction(i))<=cfg.audit_tol;

    assert(c_match && f_match && a_match, ...
        'Dense comparator differs from sampled B1 endpoint.');

    ra=ra+1;
    audit_rows(ra,:)={ ...
        src,ap,pol,B1.nominal_budget(i),selected, ...
        Q.actual_trigger_fraction(1),B1.actual_trigger_fraction(i),a_match, ...
        Q.mean_objective_evals(1),B1.mean_objective_evals(i),c_match, ...
        Q.final_failure_count(1),B1.final_failure_count(i),f_match}; %#ok<AGROW>
end

A=cell2table(audit_rows,'VariableNames',{ ...
    'source','aperture_mode','policy','sampled_nominal_budget', ...
    'selected_count','dense_actual_trigger_fraction', ...
    'sampled_actual_trigger_fraction','actual_fraction_match', ...
    'dense_mean_cost','sampled_mean_cost','mean_cost_match', ...
    'dense_final_failure_count','sampled_final_failure_count', ...
    'failure_count_match'});

writetable(A,fullfile(cfg.output_dir,"pa5jb3r1_b1_reconstruction_audit.csv"));

%% ------------------------------------------------------------------------
% 4. Exact dense B1 Pareto front
% -------------------------------------------------------------------------
F1=build_dense_b1_front(D,cfg);
writetable(F1,fullfile(cfg.output_dir,"pa5jb3r1_dense_b1_front.csv"));

%% ------------------------------------------------------------------------
% 5. Re-evaluate every B3 staged point against dense B1
% -------------------------------------------------------------------------
cmp_rows={};
rc=0;

for i=1:height(B3)
    src=string(B3.source(i));
    ap=string(B3.aperture_mode(i));
    cost=double(B3.mean_objective_evals(i));
    pf=double(B3.final_failure_probability(i));

    Q=D(string(D.source)==src & string(D.aperture_mode)==ap & ...
        double(D.mean_objective_evals)<=cost+cfg.audit_tol,:);

    assert(~isempty(Q),'No dense B1 comparator below B3 cost.');

    best_pf=min(double(Q.final_failure_probability));
    J=find(abs(double(Q.final_failure_probability)-best_pf)<=cfg.audit_tol);

    % Among equally reliable dense B1 comparators, retain cheapest.
    [~,jj]=min(double(Q.mean_objective_evals(J)));
    q=Q(J(jj),:);

    new_gain=best_pf-pf;
    old_gain=double(B3.gain_vs_best_b1_at_no_more_cost(i));

    if new_gain>cfg.gain_tol
        relation="strictly_better_than_dense_B1";
    elseif abs(new_gain)<=cfg.gain_tol
        relation="equal_to_dense_B1";
    else
        relation="worse_than_dense_B1";
    end

    rc=rc+1;
    cmp_rows(rc,:)={ ...
        src,ap,string(B3.stage2_signal(i)), ...
        double(B3.stage1_nominal_budget(i)), ...
        double(B3.stage2_conditional_nominal_budget(i)), ...
        double(B3.total_actual_fallback_fraction(i)), ...
        cost,pf, ...
        string(q.policy(1)),double(q.actual_trigger_fraction(1)), ...
        double(q.mean_objective_evals(1)),best_pf, ...
        old_gain,new_gain,old_gain-new_gain,relation}; %#ok<AGROW>
end

Cmp=cell2table(cmp_rows,'VariableNames',{ ...
    'source','aperture_mode','stage2_signal', ...
    'stage1_nominal_budget','stage2_conditional_nominal_budget', ...
    'total_actual_fallback_fraction','b3_mean_objective_evals', ...
    'b3_final_failure_probability','dense_b1_best_policy', ...
    'dense_b1_best_actual_trigger_fraction','dense_b1_best_mean_cost', ...
    'dense_b1_best_failure_probability','old_sampled_b1_gain', ...
    'new_dense_b1_gain','gain_removed_by_dense_audit','relation'});

writetable(Cmp,fullfile(cfg.output_dir,"pa5jb3r1_b3_vs_dense_b1.csv"));

%% ------------------------------------------------------------------------
% 6. Combined B1 + B3 Pareto front
% -------------------------------------------------------------------------
Combined=build_combined_front(D,B3,Base,cfg);
writetable(Combined,fullfile(cfg.output_dir,"pa5jb3r1_combined_front.csv"));

%% ------------------------------------------------------------------------
% 7. Smoke tests
% -------------------------------------------------------------------------
Smoke=build_smoke_tests(C,D,A,Cmp,cfg);
writetable(Smoke,fullfile(cfg.output_dir,"pa5jb3r1_smoke_test.csv"));
assert(all(Smoke.pass), ...
    'PA5J-B3-R1 smoke test failed. Do not interpret results.');

%% ------------------------------------------------------------------------
% 8. Figures
% -------------------------------------------------------------------------
make_figures(D,B1,B3,Base,Combined,cfg);

%% ------------------------------------------------------------------------
% 9. Rich TXT
% -------------------------------------------------------------------------
write_results_txt(C,D,F1,B1,B3,Cmp,Combined,Base,A,Smoke,cfg, ...
    p_trials,p_b1,p_base,p_b3);

fprintf('\nPA5J-B3-R1 completed.\n');
fprintf('Output: %s\n',cfg.output_dir);
fprintf('Upload RESULTS_EXP009_PA5JB3R1.txt + four audit figures first.\n');
fprintf('No method claim or operating point was selected automatically.\n');

end

%% =========================================================================
% Dense policy endpoint enumeration
% =========================================================================
function rows=enumerate_policy_endpoints(src,ap,pname,diag_cost,score, ...
    g0_fail,n3_fail,g0_cost,n3_cost)

score=double(score(:));
N=numel(score);

assert(all(isfinite(score)),'Non-finite policy score.');
assert(numel(g0_fail)==N && numel(n3_fail)==N, ...
    'Outcome length mismatch.');
assert(numel(g0_cost)==N && numel(n3_cost)==N, ...
    'Cost length mismatch.');

base_fail=sum(g0_fail);
base_cost=mean(g0_cost)+diag_cost;

delta_cost=double(n3_cost-g0_cost);
delta_fail=double(n3_fail)-double(g0_fail);

rescued=double(g0_fail & ~n3_fail);
induced=double(~g0_fail & n3_fail);
persistent_fail=double(g0_fail & n3_fail);
triggered_g0_fail=double(g0_fail);

% Sort once. Equal score values are processed as one indivisible tie class.
[s,ord]=sort(score,'descend');

dc=delta_cost(ord);
df=delta_fail(ord);
rs=rescued(ord);
ii=induced(ord);
pp=persistent_fail(ord);
gg=triggered_g0_fail(ord);

rows=cell(0,18);

% No-trigger endpoint.
[lo0,hi0]=wilson_ci(base_fail,N);
rows(end+1,:)={ ...
    src,ap,pname,diag_cost,NaN,0,0,0, ...
    base_cost,base_fail,N,base_fail/N,lo0,hi0, ...
    0,0,0,base_fail}; %#ok<AGROW>

cum_n=0;
cum_dc=0;
cum_df=0;
cum_rescue=0;
cum_induced=0;
cum_persistent=0;
cum_g0_triggered=0;

i=1;
while i<=N
    j=i;
    while j<N && s(j+1)==s(i)
        j=j+1;
    end

    idx=i:j;
    tie_n=numel(idx);

    cum_n=cum_n+tie_n;
    cum_dc=cum_dc+sum(dc(idx));
    cum_df=cum_df+sum(df(idx));
    cum_rescue=cum_rescue+sum(rs(idx));
    cum_induced=cum_induced+sum(ii(idx));
    cum_persistent=cum_persistent+sum(pp(idx));
    cum_g0_triggered=cum_g0_triggered+sum(gg(idx));

    final_fail=base_fail+cum_df;
    mean_cost=base_cost+cum_dc/N;
    missed=base_fail-cum_g0_triggered;
    [lo,hi]=wilson_ci(final_fail,N);

    rows(end+1,:)={ ...
        src,ap,pname,diag_cost,s(i),tie_n,cum_n,cum_n/N, ...
        mean_cost,final_fail,N,final_fail/N,lo,hi, ...
        cum_rescue,cum_induced,cum_persistent,missed}; %#ok<AGROW>

    i=j+1;
end

end

%% =========================================================================
% Dense B1 front
% =========================================================================
function F=build_dense_b1_front(D,cfg)

keep=false(height(D),1);

for isrc=1:numel(cfg.sources)
    src=cfg.sources(isrc);
    for iap=1:numel(cfg.aperture_modes)
        ap=cfg.aperture_modes(iap);
        idx=find(string(D.source)==src & string(D.aperture_mode)==ap);
        c=double(D.mean_objective_evals(idx));
        f=double(D.final_failure_probability(idx));
        keep(idx(pareto_mask(c,f)))=true;
    end
end

F=D(keep,:);
F=sortrows(F,{'source','aperture_mode','mean_objective_evals'});
end

%% =========================================================================
% Combined dense B1 + B3 + baselines front
% =========================================================================
function Out=build_combined_front(D,B3,Base,cfg)

rows={};
r=0;

for isrc=1:numel(cfg.sources)
    src=cfg.sources(isrc);
    for iap=1:numel(cfg.aperture_modes)
        ap=cfg.aperture_modes(iap);

        Q=D(string(D.source)==src & string(D.aperture_mode)==ap,:);
        for i=1:height(Q)
            r=r+1;
            rows(r,:)={src,ap,"DenseB1",string(Q.policy(i)), ...
                double(Q.actual_trigger_fraction(i)),NaN, ...
                double(Q.mean_objective_evals(i)), ...
                double(Q.final_failure_probability(i))}; %#ok<AGROW>
        end

        Q=B3(string(B3.source)==src & string(B3.aperture_mode)==ap,:);
        for i=1:height(Q)
            r=r+1;
            rows(r,:)={src,ap,"B3",string(Q.stage2_signal(i)), ...
                double(Q.stage1_nominal_budget(i)), ...
                double(Q.stage2_conditional_nominal_budget(i)), ...
                double(Q.mean_objective_evals(i)), ...
                double(Q.final_failure_probability(i))}; %#ok<AGROW>
        end

        Q=Base(string(Base.source)==src & string(Base.aperture_mode)==ap,:);
        for i=1:height(Q)
            r=r+1;
            rows(r,:)={src,ap,"Baseline",string(Q.method(i)), ...
                NaN,NaN,double(Q.mean_objective_evals(i)), ...
                double(Q.failure_probability(i))}; %#ok<AGROW>
        end
    end
end

All=cell2table(rows,'VariableNames',{ ...
    'source','aperture_mode','family','policy_or_signal', ...
    'budget_or_stage1','stage2_budget','mean_objective_evals', ...
    'final_failure_probability'});

keep=false(height(All),1);

for isrc=1:numel(cfg.sources)
    src=cfg.sources(isrc);
    for iap=1:numel(cfg.aperture_modes)
        ap=cfg.aperture_modes(iap);
        idx=find(string(All.source)==src & string(All.aperture_mode)==ap);
        c=double(All.mean_objective_evals(idx));
        f=double(All.final_failure_probability(idx));
        keep(idx(pareto_mask(c,f)))=true;
    end
end

Out=All(keep,:);
Out=sortrows(Out,{'source','aperture_mode','mean_objective_evals'});
end

function keep=pareto_mask(cost,fail)
% Efficient 2-D Pareto test for minimization of both cost and failure.
% Semantics match the previous tolerance-based definition:
% a point is dominated only if another point is no worse in both metrics
% and strictly better by more than tol in at least one metric.

tol=1e-12;
cost=double(cost(:));
fail=double(fail(:));
n=numel(cost);

assert(numel(fail)==n,'Pareto input length mismatch.');
assert(all(isfinite(cost)) && all(isfinite(fail)), ...
    'Non-finite Pareto metric.');

[cs,ord]=sort(cost,'ascend');
fs=fail(ord);
keep_sorted=false(n,1);

best_fail_lower_cost=Inf;
i=1;

while i<=n
    % Treat costs within tol as the same cost level for dominance purposes.
    j=i;
    while j<n && abs(cs(j+1)-cs(i))<=tol
        j=j+1;
    end

    group_fail=fs(i:j);
    min_group=min(group_fail);

    % Same-cost points with failure above the group minimum are dominated.
    at_group_min=abs(group_fail-min_group)<=tol;

    % A strictly lower-cost point dominates this cost level when it has
    % failure <= min_group (within tolerance).
    lower_cost_dominates = best_fail_lower_cost <= min_group + tol;

    if ~lower_cost_dominates
        keep_sorted(i:j)=at_group_min;
    end

    best_fail_lower_cost=min(best_fail_lower_cost,min_group);
    i=j+1;
end

keep=false(n,1);
keep(ord)=keep_sorted;
end

%% =========================================================================
% Figures
% =========================================================================
function make_figures(D,B1,B3,Base,Combined,cfg)

for isrc=1:numel(cfg.sources)
    src=cfg.sources(isrc);
    for iap=1:numel(cfg.aperture_modes)
        ap=cfg.aperture_modes(iap);

        fig=figure('Visible','off','Color','w');
        hold on; grid on; box on;

        % Old sampled B1 envelope
        Qs=B1(string(B1.source)==src & ...
              string(B1.aperture_mode)==ap & ...
              ismember(string(B1.policy),cfg.policy_names),:);
        ks=pareto_mask(double(Qs.mean_objective_evals), ...
                       double(Qs.final_failure_probability));
        Es=sortrows(Qs(ks,:),'mean_objective_evals');
        plot(Es.mean_objective_evals,Es.final_failure_probability, ...
            '--o','LineWidth',1.0,'MarkerSize',4, ...
            'DisplayName','Sampled B1 envelope');

        % Exact dense B1 front
        Qd=D(string(D.source)==src & string(D.aperture_mode)==ap,:);
        kd=pareto_mask(double(Qd.mean_objective_evals), ...
                       double(Qd.final_failure_probability));
        Ed=sortrows(Qd(kd,:),'mean_objective_evals');
        plot(Ed.mean_objective_evals,Ed.final_failure_probability, ...
            '-','LineWidth',1.8,'DisplayName','Dense B1 frontier');

        % B3 staged points that survive combined Pareto front
        Qc=Combined(string(Combined.source)==src & ...
                    string(Combined.aperture_mode)==ap & ...
                    string(Combined.family)=="B3",:);
        if ~isempty(Qc)
            scatter(Qc.mean_objective_evals,Qc.final_failure_probability, ...
                38,'s','filled','DisplayName','B3 on combined frontier');
        end

        % All B3 points lightly visible
        Q3=B3(string(B3.source)==src & string(B3.aperture_mode)==ap,:);
        scatter(Q3.mean_objective_evals,Q3.final_failure_probability, ...
            10,'.','DisplayName','All B3 staged points');

        Bb=Base(string(Base.source)==src & ...
                string(Base.aperture_mode)==ap,:);
        G0=Bb(string(Bb.method)=="G0_OriginalTop1",:);
        N3=Bb(string(Bb.method)=="Always_Neighbor3",:);

        plot(G0.mean_objective_evals,G0.failure_probability,'^', ...
            'MarkerSize',8,'LineWidth',1.4,'DisplayName','G0');
        plot(N3.mean_objective_evals,N3.failure_probability,'d', ...
            'MarkerSize',8,'LineWidth',1.4,'DisplayName','Always N3');

        xlabel('Mean objective evaluations');
        ylabel('Final catastrophic failure probability');
        title(sprintf('%s / %s: dense B1 audit',src,ap), ...
            'Interpreter','none');
        legend('Location','best','Interpreter','none');

        safe=regexprep(char(src+"_"+ap),'[^A-Za-z0-9_]','_');
        exportgraphics(fig,fullfile(cfg.figure_dir, ...
            "fig01_dense_audit_"+safe+".png"),'Resolution',180);
        close(fig);
    end
end
end

%% =========================================================================
% Rich result TXT
% =========================================================================
function write_results_txt(C,D,F1,B1,B3,Cmp,Combined,Base,A,Smoke,cfg, ...
    p_trials,p_b1,p_base,p_b3)

path=fullfile(cfg.output_dir,"RESULTS_EXP009_PA5JB3R1.txt");
fid=fopen(path,'w');
assert(fid>0,'Cannot open B3-R1 result TXT.');
c=onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP009 / PA5J-B3-R1 — Dense Single-Stage Comparator Audit\n');
fprintf(fid,'FORMAL FAIRNESS / CONTRIBUTION AUDIT\n');
fprintf(fid,'No method claim or operating point is automatically selected.\n\n');

fprintf(fid,'============================================================\n');
fprintf(fid,'1. INPUT / SOFTWARE AUDIT\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'Canonical trials : %s\n',p_trials);
fprintf(fid,'B1 sampled sweep : %s\n',p_b1);
fprintf(fid,'B1 baselines     : %s\n',p_base);
fprintf(fid,'B3 staged sweep  : %s\n',p_b3);
fprintf(fid,'Canonical N=%d; unique source+trial_id=%d\n', ...
    height(C),numel(unique(string(C.source)+"|"+string(C.trial_id))));
fprintf(fid,'Dense B1 endpoints=%d\n',height(D));
fprintf(fid,'Sampled B1 reconstruction rows=%d; all pass=%d\n', ...
    height(A),all(A.actual_fraction_match & A.mean_cost_match & ...
                  A.failure_count_match));
fprintf(fid,'Smoke tests=%d; all pass=%d\n\n', ...
    height(Smoke),all(Smoke.pass));

fprintf(fid,'============================================================\n');
fprintf(fid,'2. DENSE COMPARATOR DEFINITION\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'Policies: %s\n',strjoin(cfg.policy_names,", "));
fprintf(fid,['For each policy and primary group, every distinct score value is ', ...
    'used as a tie-inclusive cutoff.\n']);
fprintf(fid,['Therefore every attainable deterministic threshold set is ', ...
    'enumerated, plus the no-trigger endpoint.\n']);
fprintf(fid,'No interpolation is used.\n\n');

fprintf(fid,'============================================================\n');
fprintf(fid,'3. DENSE B1 FRONTIER SIZE\n');
fprintf(fid,'============================================================\n');
for isrc=1:numel(cfg.sources)
    src=cfg.sources(isrc);
    for iap=1:numel(cfg.aperture_modes)
        ap=cfg.aperture_modes(iap);
        Q=D(string(D.source)==src & string(D.aperture_mode)==ap,:);
        F=F1(string(F1.source)==src & string(F1.aperture_mode)==ap,:);
        fprintf(fid,'%s / %s: dense endpoints=%d; Pareto points=%d\n', ...
            src,ap,height(Q),height(F));
    end
end

fprintf(fid,'\n============================================================\n');
fprintf(fid,'4. B3 VS DENSE B1 — CORE VERDICT TABLE\n');
fprintf(fid,'============================================================\n');

for isrc=1:numel(cfg.sources)
    src=cfg.sources(isrc);
    for iap=1:numel(cfg.aperture_modes)
        ap=cfg.aperture_modes(iap);
        Q=Cmp(string(Cmp.source)==src & string(Cmp.aperture_mode)==ap,:);

        better=Q.new_dense_b1_gain>cfg.gain_tol;
        equalish=abs(Q.new_dense_b1_gain)<=cfg.gain_tol;
        worse=Q.new_dense_b1_gain<-cfg.gain_tol;

        fprintf(fid,'\n[%s / %s]\n',src,ap);
        fprintf(fid,'  B3 staged points=%d\n',height(Q));
        fprintf(fid,'  strictly better than dense B1=%d\n',sum(better));
        fprintf(fid,'  equal to dense B1=%d\n',sum(equalish));
        fprintf(fid,'  worse than dense B1=%d\n',sum(worse));
        fprintf(fid,'  max old sampled-B1 gain=%.9g\n', ...
            max(Q.old_sampled_b1_gain));
        fprintf(fid,'  max dense-B1 gain=%.9g\n', ...
            max(Q.new_dense_b1_gain));
        fprintf(fid,'  mean gain removed by dense audit=%.9g\n', ...
            mean(Q.gain_removed_by_dense_audit));

        % Strongest surviving staged point by dense gain.
        [mg,j]=max(Q.new_dense_b1_gain);
        q=Q(j,:);
        fprintf(fid,['  strongest staged gain: signal=%s, b1=%.6g, ', ...
            'b2=%.6g, cost=%.6f, P_F=%.9g, dense comparator=%s, ', ...
            'dense P_F=%.9g, gain=%.9g\n'], ...
            string(q.stage2_signal),q.stage1_nominal_budget, ...
            q.stage2_conditional_nominal_budget, ...
            q.b3_mean_objective_evals,q.b3_final_failure_probability, ...
            string(q.dense_b1_best_policy), ...
            q.dense_b1_best_failure_probability,mg);
    end
end

fprintf(fid,'\n============================================================\n');
fprintf(fid,'5. OLD GAIN VS DENSE-AUDITED GAIN\n');
fprintf(fid,'============================================================\n');

for isrc=1:numel(cfg.sources)
    src=cfg.sources(isrc);
    for iap=1:numel(cfg.aperture_modes)
        ap=cfg.aperture_modes(iap);
        Q=Cmp(string(Cmp.source)==src & string(Cmp.aperture_mode)==ap,:);

        oldpos=sum(Q.old_sampled_b1_gain>cfg.gain_tol);
        newpos=sum(Q.new_dense_b1_gain>cfg.gain_tol);
        destroyed=sum(Q.old_sampled_b1_gain>cfg.gain_tol & ...
                      Q.new_dense_b1_gain<=cfg.gain_tol);

        fprintf(fid,'%s / %s: old-positive=%d; dense-positive=%d; ', ...
            src,ap,oldpos,newpos);
        fprintf(fid,'old gains removed=%d\n',destroyed);
    end
end

fprintf(fid,'\n============================================================\n');
fprintf(fid,'6. COMBINED DENSE-B1 + B3 PARETO MEMBERSHIP\n');
fprintf(fid,'============================================================\n');

for isrc=1:numel(cfg.sources)
    src=cfg.sources(isrc);
    for iap=1:numel(cfg.aperture_modes)
        ap=cfg.aperture_modes(iap);
        Q=Combined(string(Combined.source)==src & ...
                   string(Combined.aperture_mode)==ap,:);
        nb1=sum(string(Q.family)=="DenseB1");
        nb3=sum(string(Q.family)=="B3");
        nbase=sum(string(Q.family)=="Baseline");
        fprintf(fid,'%s / %s: DenseB1=%d, B3=%d, Baseline=%d\n', ...
            src,ap,nb1,nb3,nbase);

        Q3=Q(string(Q.family)=="B3",:);
        if ~isempty(Q3)
            sigs=unique(string(Q3.policy_or_signal),'stable');
            fprintf(fid,'  B3 frontier membership by Stage-2 signal:');
            for k=1:numel(sigs)
                fprintf(fid,' %s=%d;',sigs(k), ...
                    sum(string(Q3.policy_or_signal)==sigs(k)));
            end
            fprintf(fid,'\n');
        end
    end
end

fprintf(fid,'\n============================================================\n');
fprintf(fid,'7. BEST B3 UNDER PRE-REGISTERED NORMALIZED COST CAPS\n');
fprintf(fid,'   WITH DENSE-B1 COMPARATOR AT NO GREATER COST\n');
fprintf(fid,'============================================================\n');

for isrc=1:numel(cfg.sources)
    src=cfg.sources(isrc);
    for iap=1:numel(cfg.aperture_modes)
        ap=cfg.aperture_modes(iap);

        fprintf(fid,'\n[%s / %s]\n',src,ap);

        Bb=Base(string(Base.source)==src & ...
                string(Base.aperture_mode)==ap,:);
        G0=Bb(string(Bb.method)=="G0_OriginalTop1",:);
        N3=Bb(string(Bb.method)=="Always_Neighbor3",:);
        gap=N3.mean_objective_evals(1)-G0.mean_objective_evals(1);

        Q=Cmp(string(Cmp.source)==src & string(Cmp.aperture_mode)==ap,:);

        for ic=1:numel(cfg.report_normalized_cost_caps)
            cap=cfg.report_normalized_cost_caps(ic);
            maxcost=G0.mean_objective_evals(1)+cap*gap;
            Z=Q(Q.b3_mean_objective_evals<=maxcost+cfg.audit_tol,:);

            if isempty(Z)
                fprintf(fid,'  cap %.2f: no B3 point\n',cap);
                continue;
            end

            m=min(Z.b3_final_failure_probability);
            W=Z(abs(Z.b3_final_failure_probability-m)<=cfg.audit_tol,:);
            [~,j]=min(W.b3_mean_objective_evals);
            q=W(j,:);

            fprintf(fid,['  cap %.2f: %s b1=%.3f b2=%.3f ', ...
                'cost=%.4f P_F=%.9g | denseB1=%s cost=%.4f ', ...
                'P_F=%.9g | dense gain=%.9g\n'], ...
                cap,string(q.stage2_signal), ...
                q.stage1_nominal_budget, ...
                q.stage2_conditional_nominal_budget, ...
                q.b3_mean_objective_evals, ...
                q.b3_final_failure_probability, ...
                string(q.dense_b1_best_policy), ...
                q.dense_b1_best_mean_cost, ...
                q.dense_b1_best_failure_probability, ...
                q.new_dense_b1_gain);
        end
    end
end

fprintf(fid,'\n============================================================\n');
fprintf(fid,'8. SAFETY / INTERPRETATION BOUNDARIES\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'Total B3 induced-failure counts across sweep: %d\n', ...
    sum(B3.stage1_induced_count)+sum(B3.stage2_induced_count));
fprintf(fid,'Total B3 persistent-after-fallback counts across sweep: %d\n', ...
    sum(B3.persistent_after_fallback_count));
fprintf(fid,'Dense B1 comparison uses only attainable deterministic tie-inclusive endpoints.\n');
fprintf(fid,'No randomization / interpolation was introduced.\n');
fprintf(fid,'No threshold or operating point was selected.\n');
fprintf(fid,'No truth physical variable was used.\n');
fprintf(fid,['A positive new_dense_b1_gain means the staged point has lower ', ...
    'failure probability than every attainable deterministic B1 point ', ...
    'with no greater mean objective cost.\n']);
end

%% =========================================================================
% Smoke tests
% =========================================================================
function S=build_smoke_tests(C,D,A,Cmp,cfg)

name=strings(0,1); pass=false(0,1); detail=strings(0,1);

combo=string(C.source)+"|"+string(C.trial_id);
[name,pass,detail]=add_test(name,pass,detail, ...
    "canonical_source_trial_unique", ...
    numel(unique(combo))==height(C), ...
    sprintf('%d / %d unique',numel(unique(combo)),height(C)));

[name,pass,detail]=add_test(name,pass,detail, ...
    "sampled_B1_reconstruction_all_pass", ...
    all(A.actual_fraction_match & A.mean_cost_match & ...
        A.failure_count_match), ...
    sprintf('%d rows checked',height(A)));

% Every dense policy/group must have no-trigger and full-trigger endpoints.
ok_end=true;
for isrc=1:numel(cfg.sources)
    for iap=1:numel(cfg.aperture_modes)
        for ip=1:numel(cfg.policy_names)
            Q=D(string(D.source)==cfg.sources(isrc) & ...
                string(D.aperture_mode)==cfg.aperture_modes(iap) & ...
                string(D.policy)==cfg.policy_names(ip),:);
            ok_end=ok_end && any(Q.selected_count==0) && ...
                any(Q.selected_count==Q.n_trials);
        end
    end
end
[name,pass,detail]=add_test(name,pass,detail, ...
    "dense_endpoint_zero_and_full_exist",ok_end, ...
    'All policy/group combinations contain no-trigger and full-trigger endpoints.');

% Nested threshold set => selected_count strictly increases after removing
% possible duplicate endpoint count (should not exist).
ok_nested=true;
for isrc=1:numel(cfg.sources)
    for iap=1:numel(cfg.aperture_modes)
        for ip=1:numel(cfg.policy_names)
            Q=D(string(D.source)==cfg.sources(isrc) & ...
                string(D.aperture_mode)==cfg.aperture_modes(iap) & ...
                string(D.policy)==cfg.policy_names(ip),:);
            sc=sort(Q.selected_count);
            ok_nested=ok_nested && all(diff(sc)>0);
        end
    end
end
[name,pass,detail]=add_test(name,pass,detail, ...
    "dense_selected_counts_strictly_nested",ok_nested, ...
    'Selected counts strictly increase across attainable thresholds.');

ok_prob=all(D.final_failure_probability>=0 & ...
            D.final_failure_probability<=1) && ...
        all(isfinite(D.mean_objective_evals));
[name,pass,detail]=add_test(name,pass,detail, ...
    "dense_metric_range",ok_prob, ...
    'Dense endpoint probabilities and costs are valid.');

ok_cmp=all(isfinite(Cmp.new_dense_b1_gain)) && ...
       all(isfinite(Cmp.dense_b1_best_failure_probability));
[name,pass,detail]=add_test(name,pass,detail, ...
    "all_B3_points_have_dense_comparator",ok_cmp, ...
    sprintf('%d B3 points compared',height(Cmp)));

ok_gain=all(Cmp.new_dense_b1_gain <= ...
            Cmp.old_sampled_b1_gain + cfg.audit_tol);
[name,pass,detail]=add_test(name,pass,detail, ...
    "dense_gain_not_above_sampled_gain",ok_gain, ...
    'Dense B1 contains all sampled B1 endpoints, so audited gain cannot increase.');

[name,pass,detail]=add_test(name,pass,detail, ...
    "n3_cost_not_below_g0", ...
    all(double(C.n3_objective_evals)>=double(C.g0_objective_evals)), ...
    sprintf('min delta=%.6f', ...
    min(double(C.n3_objective_evals-C.g0_objective_evals))));

S=table(name,pass,detail);
end

function [name,pass,detail]=add_test(name,pass,detail,nm,ok,dt)
name(end+1,1)=string(nm);
pass(end+1,1)=logical(ok);
detail(end+1,1)=string(dt);
end

%% =========================================================================
% Risk / statistics
% =========================================================================
function p=risk_percentile(score)
score=double(score(:));
assert(all(isfinite(score)),'Non-finite risk score.');
n=numel(score);
if n==1
    p=1; return;
end
r=midranks(score);
p=(r-1)/(n-1);
end

function r=midranks(x)
x=double(x(:));
[s,ord]=sort(x,'ascend');
n=numel(x);
rr=zeros(n,1);
i=1;
while i<=n
    j=i;
    while j<n && s(j+1)==s(i)
        j=j+1;
    end
    rr(i:j)=(i+j)/2;
    i=j+1;
end
r=zeros(n,1);
r(ord)=rr;
end

function [lo,hi]=wilson_ci(k,n)
if n<=0
    lo=NaN; hi=NaN; return;
end
z=1.959963984540054;
p=k/n;
den=1+z^2/n;
ctr=(p+z^2/(2*n))/den;
half=z*sqrt(p*(1-p)/n+z^2/(4*n^2))/den;
lo=max(0,ctr-half);
hi=min(1,ctr+half);
end

function q=qtile(x,p)
x=sort(double(x(:)));
x=x(isfinite(x));
if isempty(x)
    q=NaN; return;
end
if numel(x)==1
    q=x(1); return;
end
pos=1+(numel(x)-1)*p;
i0=floor(pos); i1=ceil(pos);
if i0==i1
    q=x(i0);
else
    a=pos-i0;
    q=(1-a)*x(i0)+a*x(i1);
end
end

%% =========================================================================
% Provenance / IO
% =========================================================================
function write_provenance(cfg,p_trials,p_b1,p_base,p_b3)

key=[ ...
    "experiment_id";"research_role";"dense_comparator_scope"; ...
    "policies";"selection_rule";"refined_lr_extra_evals"; ...
    "input_trials";"input_sampled_b1";"input_baselines";"input_b3"; ...
    "interpolation";"truth_physics"];

value=[ ...
    cfg.experiment_id; ...
    "Fairness / method-contribution audit"; ...
    "Every attainable deterministic tie-inclusive cutoff"; ...
    strjoin(cfg.policy_names,","); ...
    "tie-inclusive"; ...
    string(cfg.refined_lr_extra_evals); ...
    string(p_trials);string(p_b1);string(p_base);string(p_b3); ...
    "none";"not used"];

source=[ ...
    "Frozen B3-R1 design"; ...
    "PA5J-B3 result interpretation"; ...
    "Dense single-stage comparator protocol"; ...
    "PA5J-B1 frozen policy family"; ...
    "PA5J-B0/B1"; ...
    "PA5J-A/B1"; ...
    "Canonical artifact";"Canonical artifact";"Canonical artifact"; ...
    "Canonical artifact"; ...
    "Fairness constraint"; ...
    "B3-R1 design constraint"];

T=table(key,value,source);
writetable(T,fullfile(cfg.output_dir,"PARAMETER_PROVENANCE_PA5JB3R1.csv"));
end

function assert_schema(T,required,label)
vars=string(T.Properties.VariableNames);
missing=required(~ismember(required,vars));
assert(isempty(missing), ...
    '%s missing required fields: %s',label,strjoin(missing,', '));
end

function assert_no_missing(T,required,label)
for i=1:numel(required)
    v=char(required(i));
    assert(~any(ismissing(T.(v))), ...
        '%s contains missing values in %s.',label,v);
end
end

function p=resolve_exact_file(expected,root,filename)
if isfile(expected)
    p=expected; return;
end
hits=dir(fullfile(root,"**",filename));
assert(numel(hits)==1, ...
    ['Expected exactly one %s under %s; found %d. ', ...
     'STOP and resolve ambiguity.'],filename,root,numel(hits));
p=fullfile(hits(1).folder,hits(1).name);
end

function ensure_dir(p)
if ~isfolder(p)
    mkdir(p);
end
end
