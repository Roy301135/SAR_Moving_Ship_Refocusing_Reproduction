function exp09_pa5jb3_staged_gate()
%EXP09_PA5JB3_STAGED_GATE
% EXP009 / PA5J-B3
% Staged Reliability Gate
%
% Scientific question:
%   Does sequential reliability allocation outperform single-stage /
%   symmetric fusion at the same computational cost?
%
% Stage 1:
%   Refined-LR ranks the full primary group.
%
% Stage 2:
%   Only Stage-1-untriggered trials are reranked using one frozen Cost-0
%   signal: FiveBin, Entropy, or Cost0_MaxRank.
%
% Recovery:
%   Neighbor-3 is invoked on the union of both stages.
%
% This experiment:
%   - does not add a new indicator;
%   - does not learn a fusion weight;
%   - does not choose a final threshold;
%   - does not use truth physics;
%   - does not assume triggered == rescued;
%   - compares against the complete B1 single-stage policy envelope.

clc;
cfg = config_exp09_pa5jb3_staged_gate();

fprintf('============================================================\n');
fprintf('EXP009 / PA5J-B3 Staged Reliability Gate\n');
fprintf('============================================================\n');

ensure_dir(cfg.output_dir);
ensure_dir(cfg.figure_dir);

%% ------------------------------------------------------------------------
% 1. Resolve exact upstream artifacts
% -------------------------------------------------------------------------
p_trials = resolve_exact_file(cfg.input_trials, cfg.results_root, ...
    "pa5jb1_canonical_trials.csv");
p_b1 = resolve_exact_file(cfg.input_b1_sweep, cfg.results_root, ...
    "pa5jb1_policy_sweep.csv");
p_base = resolve_exact_file(cfg.input_b1_baselines, cfg.results_root, ...
    "pa5jb1_baselines.csv");
p_b2 = resolve_exact_file(cfg.input_b2_screen, cfg.results_root, ...
    "pa5jb2_residual_cost0_screen.csv");

fprintf('Canonical trials : %s\n',p_trials);
fprintf('B1 sweep         : %s\n',p_b1);
fprintf('B1 baselines     : %s\n',p_base);
fprintf('B2 residual audit: %s\n',p_b2);

C = readtable(p_trials,'VariableNamingRule','preserve');
B1 = readtable(p_b1,'VariableNamingRule','preserve');
Base = readtable(p_base,'VariableNamingRule','preserve');
B2 = readtable(p_b2,'VariableNamingRule','preserve');

assert_schema(C,cfg.req_trials,"B1 canonical trials");
assert_schema(B1,cfg.req_b1,"B1 policy sweep");
assert_schema(Base,cfg.req_base,"B1 baselines");
assert_schema(B2,cfg.req_b2,"B2 residual screen");

assert_no_missing(C,cfg.req_trials,"B1 canonical trials");

combo = string(C.source)+"|"+string(C.trial_id);
assert(numel(unique(combo))==height(C), ...
    'source + trial_id is not unique in B1 canonical trials.');

%% ------------------------------------------------------------------------
% 2. Upstream baseline / cost audit
% -------------------------------------------------------------------------
assert(all(double(C.n3_objective_evals) >= ...
           double(C.g0_objective_evals)), ...
    'Neighbor-3 cost is below G0 for at least one trial.');

write_runtime_provenance(cfg,p_trials,p_b1,p_base,p_b2);

%% ------------------------------------------------------------------------
% 3. Two-stage policy sweep
% -------------------------------------------------------------------------
rows = {};
audit_b1_rows = {};
audit_b2_rows = {};
rr=0; r1=0; r2=0;

for isrc=1:numel(cfg.sources)
    src=cfg.sources(isrc);

    for iap=1:numel(cfg.aperture_modes)
        ap=cfg.aperture_modes(iap);

        idx = string(C.source)==src & string(C.aperture_mode)==ap;
        G = C(idx,:);
        assert(~isempty(G),'Missing primary group: %s / %s',src,ap);

        N=height(G);

        % Stored upstream outcomes
        g0_fail=logical(G.g0_catastrophic_failure);
        n3_fail=logical(G.n3_catastrophic_failure);
        g0_err=double(G.g0_branch_error_bins);
        n3_err=double(G.n3_branch_error_bins);
        g0_cost=double(G.g0_objective_evals);
        n3_cost=double(G.n3_objective_evals);

        assert(all(n3_cost>=g0_cost), ...
            'Negative Neighbor-3 incremental cost in %s / %s.',src,ap);

        % Frozen risk scores: larger = higher risk.
        s_five=-double(G.fivebin_peak_fraction);
        s_ent=double(G.local_entropy5);
        s_lr=double(G.refined_lr_asymmetry);

        % Frozen B1/B2 percentile fusion semantics.
        p_five=risk_percentile(s_five);
        p_ent=risk_percentile(s_ent);
        s_cost0=max([p_five,p_ent],[],2);

        score_names=cfg.stage2_signals;
        score_matrix=[s_five,s_ent,s_cost0];

        mean_g0_cost=mean(g0_cost);
        mean_n3_cost=mean(n3_cost);
        cost_gap=mean_n3_cost-mean_g0_cost;
        assert(cost_gap>0,'Non-positive G0->N3 cost gap.');

        for ib1=1:numel(cfg.stage1_budgets)
            b1=cfg.stage1_budgets(ib1);

            [T1,S1]=tie_inclusive_top(s_lr,b1);
            candidate=~T1;
            Ncand=sum(candidate);

            % b2=0 must reproduce B1 G5 exactly.
            qg5=B1(string(B1.source)==src & ...
                    string(B1.aperture_mode)==ap & ...
                    string(B1.policy)=="G5_RefinedLR" & ...
                    abs(double(B1.nominal_budget)-b1)<=cfg.audit_tol,:);
            assert(height(qg5)==1, ...
                'Missing unique B1 G5 row: %s / %s / %.6f',src,ap,b1);

            % Stage-1 final outcome, equivalent to B1 G5.
            f1=g0_fail;
            f1(T1)=n3_fail(T1);
            c1=g0_cost+cfg.refined_lr_extra_evals + ...
               double(T1).*(n3_cost-g0_cost);

            b1_count_match=S1.selected_count==qg5.selected_count(1);
            b1_frac_match=abs(S1.actual_fraction- ...
                qg5.actual_trigger_fraction(1))<=cfg.audit_tol;
            b1_fail_match=sum(f1)==qg5.final_failure_count(1);
            b1_cost_match=abs(mean(c1)-qg5.mean_objective_evals(1)) ...
                <=cfg.audit_tol;

            assert(b1_count_match && b1_frac_match && ...
                   b1_fail_match && b1_cost_match, ...
                'Stage-1 reconstruction differs from B1 G5.');

            r1=r1+1;
            audit_b1_rows(r1,:)={src,ap,b1, ...
                S1.selected_count,qg5.selected_count(1),b1_count_match, ...
                S1.actual_fraction,qg5.actual_trigger_fraction(1), ...
                b1_frac_match,sum(f1),qg5.final_failure_count(1), ...
                b1_fail_match,mean(c1),qg5.mean_objective_evals(1), ...
                b1_cost_match}; %#ok<AGROW>

            for isig=1:numel(score_names)
                signal=score_names(isig);
                s2_full=score_matrix(:,isig);
                s2_candidate=s2_full(candidate);

                for ib2=1:numel(cfg.stage2_budgets)
                    b2=cfg.stage2_budgets(ib2);

                    [T2local,S2]=tie_inclusive_top(s2_candidate,b2);
                    T2=false(N,1);
                    cand_idx=find(candidate);
                    T2(cand_idx(T2local))=true;

                    assert(~any(T1&T2), ...
                        'Stage-1 and Stage-2 trigger sets overlap.');

                    T=T1|T2;

                    final_fail=g0_fail;
                    final_fail(T)=n3_fail(T);

                    final_err=g0_err;
                    final_err(T)=n3_err(T);

                    % Decompose actual recovery contribution.
                    rescued1=T1 & g0_fail & ~n3_fail;
                    rescued2=T2 & g0_fail & ~n3_fail;
                    induced1=T1 & ~g0_fail & n3_fail;
                    induced2=T2 & ~g0_fail & n3_fail;
                    persistent_fail=T & g0_fail & n3_fail;
                    missed=~T & g0_fail;

                    % Cost:
                    % Refined-LR +2 is paid for the whole group.
                    % Stage-2 Cost-0 score has no additional objective eval.
                    trial_cost=g0_cost+cfg.refined_lr_extra_evals + ...
                        double(T).*(n3_cost-g0_cost);

                    mean_cost=mean(trial_cost);
                    norm_cost=(mean_cost-mean_g0_cost)/cost_gap;

                    nfail=sum(final_fail);
                    [flo,fhi]=wilson_ci(nfail,N);

                    % Conservative discrete cost-matched comparisons.
                    [best_any,best_any_policy,best_any_budget] = ...
                        best_b1_at_no_more_cost(B1,src,ap, ...
                        cfg.b1_policy_names,mean_cost,cfg.audit_tol);

                    [best_g5,~,best_g5_budget] = ...
                        best_b1_at_no_more_cost(B1,src,ap, ...
                        "G5_RefinedLR",mean_cost,cfg.audit_tol);

                    [best_g6,~,best_g6_budget] = ...
                        best_b1_at_no_more_cost(B1,src,ap, ...
                        "G6_All3_MaxRank",mean_cost,cfg.audit_tol);

                    [best_g4,~,best_g4_budget] = ...
                        best_b1_at_no_more_cost(B1,src,ap, ...
                        "G4_Cost0_MaxRank",mean_cost,cfg.audit_tol);

                    gain_any=best_any-mean(final_fail);
                    gain_g5=best_g5-mean(final_fail);
                    gain_g6=best_g6-mean(final_fail);
                    gain_g4=best_g4-mean(final_fail);

                    rr=rr+1;
                    rows(rr,:)={ ...
                        src,ap,signal,b1,S1.actual_fraction, ...
                        S1.selected_count,S1.cutoff_score, ...
                        S1.cutoff_tie_count,S1.budget_inflation, ...
                        b2,S2.actual_fraction,S2.selected_count, ...
                        S2.cutoff_score,S2.cutoff_tie_count, ...
                        S2.budget_inflation,Ncand, ...
                        sum(T2)/N,sum(T)/N,sum(T), ...
                        cfg.refined_lr_extra_evals,mean_cost,norm_cost, ...
                        nfail,N,mean(final_fail),flo,fhi, ...
                        sum(rescued1),sum(rescued2), ...
                        sum(induced1),sum(induced2), ...
                        sum(persistent_fail),sum(missed), ...
                        qtile(final_err,0.95),qtile(final_err,0.99), ...
                        qtile(final_err,0.999),max(final_err), ...
                        best_any,best_any_policy,best_any_budget,gain_any, ...
                        best_g5,best_g5_budget,gain_g5, ...
                        best_g6,best_g6_budget,gain_g6, ...
                        best_g4,best_g4_budget,gain_g4}; %#ok<AGROW>

                    % Dense-risk exact reconstruction against B2 where
                    % anchor/budget pairs overlap the frozen B2 audit.
                    if src=="dense_risk" && ...
                       any(abs(cfg_anchor_b2()-b1)<=cfg.audit_tol) && ...
                       any(abs(cfg_screen_b2()-b2)<=cfg.audit_tol)

                        qb2=B2(string(B2.source)=="dense_risk" & ...
                            string(B2.aperture_mode)==ap & ...
                            abs(double(B2.g5_nominal_budget)-b1) ...
                                <=cfg.audit_tol & ...
                            string(B2.cost0_signal)==signal & ...
                            abs(double(B2.residual_screen_nominal_budget)-b2) ...
                                <=cfg.audit_tol,:);

                        assert(height(qb2)==1, ...
                            'Missing unique B2 audit row.');

                        b2_count_match=S2.selected_count==qb2.selected_count(1);
                        b2_frac_match=abs(S2.actual_fraction- ...
                            qb2.residual_screen_actual_fraction_of_pool(1)) ...
                            <=cfg.audit_tol;
                        b2_rescue_match=sum(T2 & g0_fail)== ...
                            qb2.residual_failures_selected(1);

                        assert(b2_count_match && b2_frac_match && ...
                               b2_rescue_match, ...
                            'Stage-2 reconstruction differs from B2.');

                        r2=r2+1;
                        audit_b2_rows(r2,:)={ ...
                            src,ap,b1,signal,b2, ...
                            S2.selected_count,qb2.selected_count(1), ...
                            b2_count_match,S2.actual_fraction, ...
                            qb2.residual_screen_actual_fraction_of_pool(1), ...
                            b2_frac_match,sum(T2&g0_fail), ...
                            qb2.residual_failures_selected(1), ...
                            b2_rescue_match}; %#ok<AGROW>
                    end
                end
            end
        end
    end
end

%% ------------------------------------------------------------------------
% 4. Tables
% -------------------------------------------------------------------------
names={ ...
    'source','aperture_mode','stage2_signal', ...
    'stage1_nominal_budget','stage1_actual_fraction', ...
    'stage1_selected_count','stage1_cutoff_score', ...
    'stage1_cutoff_tie_count','stage1_budget_inflation', ...
    'stage2_conditional_nominal_budget', ...
    'stage2_conditional_actual_fraction', ...
    'stage2_selected_count','stage2_cutoff_score', ...
    'stage2_cutoff_tie_count','stage2_budget_inflation', ...
    'stage2_candidate_count','stage2_extra_fraction_of_all_trials', ...
    'total_actual_fallback_fraction','total_selected_count', ...
    'diagnostic_extra_evals_per_trial', ...
    'mean_objective_evals','normalized_cost_G0_to_N3', ...
    'final_failure_count','n_trials','final_failure_probability', ...
    'failure_wilson_lo','failure_wilson_hi', ...
    'stage1_rescued_count','stage2_rescued_count', ...
    'stage1_induced_count','stage2_induced_count', ...
    'persistent_after_fallback_count','missed_g0_failure_count', ...
    'q95_final_branch_error_bins','q99_final_branch_error_bins', ...
    'q999_final_branch_error_bins','max_final_branch_error_bins', ...
    'best_b1_failure_at_no_more_cost','best_b1_policy_at_no_more_cost', ...
    'best_b1_budget_at_no_more_cost','gain_vs_best_b1_at_no_more_cost', ...
    'best_g5_failure_at_no_more_cost','best_g5_budget_at_no_more_cost', ...
    'gain_vs_g5_at_no_more_cost', ...
    'best_g6_failure_at_no_more_cost','best_g6_budget_at_no_more_cost', ...
    'gain_vs_g6_at_no_more_cost', ...
    'best_g4_failure_at_no_more_cost','best_g4_budget_at_no_more_cost', ...
    'gain_vs_g4_at_no_more_cost'};

P=cell2table(rows,'VariableNames',names);

A1=cell2table(audit_b1_rows,'VariableNames',{ ...
    'source','aperture_mode','stage1_nominal_budget', ...
    'reconstructed_selected_count','b1_selected_count', ...
    'selected_count_match','reconstructed_actual_fraction', ...
    'b1_actual_fraction','actual_fraction_match', ...
    'reconstructed_final_failure_count','b1_final_failure_count', ...
    'failure_count_match','reconstructed_mean_cost','b1_mean_cost', ...
    'mean_cost_match'});

A2=cell2table(audit_b2_rows,'VariableNames',{ ...
    'source','aperture_mode','stage1_nominal_budget', ...
    'stage2_signal','stage2_conditional_nominal_budget', ...
    'reconstructed_stage2_selected_count','b2_selected_count', ...
    'selected_count_match','reconstructed_stage2_actual_fraction', ...
    'b2_stage2_actual_fraction','actual_fraction_match', ...
    'reconstructed_residual_failure_selected', ...
    'b2_residual_failure_selected','residual_failure_match'});

writetable(P,fullfile(cfg.output_dir,"pa5jb3_staged_sweep.csv"));
writetable(A1,fullfile(cfg.output_dir,"pa5jb3_b1_reconstruction_audit.csv"));
writetable(A2,fullfile(cfg.output_dir,"pa5jb3_b2_reconstruction_audit.csv"));

%% ------------------------------------------------------------------------
% 5. Pareto front construction
% -------------------------------------------------------------------------
Front=build_pareto_front(P,B1,Base,cfg);
writetable(Front,fullfile(cfg.output_dir,"pa5jb3_pareto_front.csv"));

%% ------------------------------------------------------------------------
% 6. Smoke tests
% -------------------------------------------------------------------------
Smoke=build_smoke_tests(C,P,A1,A2,cfg);
writetable(Smoke,fullfile(cfg.output_dir,"pa5jb3_smoke_test.csv"));

assert(all(Smoke.pass), ...
    'PA5J-B3 smoke test failed. Do not interpret formal results.');

%% ------------------------------------------------------------------------
% 7. Figures
% -------------------------------------------------------------------------
make_pareto_figures(P,B1,Base,cfg);
make_dense_heatmaps(P,cfg);

%% ------------------------------------------------------------------------
% 8. Rich result TXT for Research-Layer upload
% -------------------------------------------------------------------------
write_results_txt(C,P,Front,B1,Base,A1,A2,Smoke,cfg, ...
    p_trials,p_b1,p_base,p_b2);

fprintf('\nPA5J-B3 formal run completed.\n');
fprintf('Output: %s\n',cfg.output_dir);
fprintf('Upload RESULTS_EXP009_PA5JB3.txt + key figures first.\n');
fprintf('No operating point or research branch was automatically selected.\n');

end

%% =========================================================================
% Cost-matched B1 comparator
% =========================================================================
function [pf,pol,bud]=best_b1_at_no_more_cost(B1,src,ap,policies,cost,tol)

Q=B1(string(B1.source)==src & string(B1.aperture_mode)==ap,:);
Q=Q(ismember(string(Q.policy),string(policies)),:);
Q=Q(double(Q.mean_objective_evals)<=cost+tol,:);

if isempty(Q)
    pf=NaN; pol=""; bud=NaN;
    return;
end

m=min(double(Q.final_failure_probability));
J=find(abs(double(Q.final_failure_probability)-m)<=tol);

% If several points have the same failure probability, prefer the cheapest.
[~,k]=min(double(Q.mean_objective_evals(J)));
j=J(k);

pf=double(Q.final_failure_probability(j));
pol=string(Q.policy(j));
bud=double(Q.nominal_budget(j));
end

%% =========================================================================
% Pareto front
% =========================================================================
function F=build_pareto_front(P,B1,Base,cfg)

allrows={};
r=0;

for isrc=1:numel(cfg.sources)
    src=cfg.sources(isrc);
    for iap=1:numel(cfg.aperture_modes)
        ap=cfg.aperture_modes(iap);

        % G0 / Always N3
        Bb=Base(string(Base.source)==src & ...
            string(Base.aperture_mode)==ap,:);
        for i=1:height(Bb)
            r=r+1;
            allrows(r,:)={src,ap,"Baseline",string(Bb.method(i)), ...
                NaN,NaN,NaN,double(Bb.mean_objective_evals(i)), ...
                double(Bb.failure_probability(i))}; %#ok<AGROW>
        end

        % Full B1 policy family
        Q=B1(string(B1.source)==src & ...
             string(B1.aperture_mode)==ap & ...
             ismember(string(B1.policy),cfg.b1_policy_names),:);
        for i=1:height(Q)
            r=r+1;
            allrows(r,:)={src,ap,"B1",string(Q.policy(i)), ...
                double(Q.nominal_budget(i)),NaN,NaN, ...
                double(Q.mean_objective_evals(i)), ...
                double(Q.final_failure_probability(i))}; %#ok<AGROW>
        end

        % Staged family
        Q=P(string(P.source)==src & string(P.aperture_mode)==ap,:);
        for i=1:height(Q)
            r=r+1;
            allrows(r,:)={src,ap,"B3",string(Q.stage2_signal(i)), ...
                double(Q.stage1_nominal_budget(i)), ...
                double(Q.stage2_conditional_nominal_budget(i)), ...
                double(Q.total_actual_fallback_fraction(i)), ...
                double(Q.mean_objective_evals(i)), ...
                double(Q.final_failure_probability(i))}; %#ok<AGROW>
        end
    end
end

All=cell2table(allrows,'VariableNames',{ ...
    'source','aperture_mode','family','policy_or_signal', ...
    'stage1_or_single_budget','stage2_conditional_budget', ...
    'actual_fallback_fraction','mean_objective_evals', ...
    'final_failure_probability'});

keep=false(height(All),1);

for isrc=1:numel(cfg.sources)
    src=cfg.sources(isrc);
    for iap=1:numel(cfg.aperture_modes)
        ap=cfg.aperture_modes(iap);
        idx=find(string(All.source)==src & string(All.aperture_mode)==ap);
        c=double(All.mean_objective_evals(idx));
        f=double(All.final_failure_probability(idx));
        pm=pareto_mask(c,f);
        keep(idx(pm))=true;
    end
end

F=All(keep,:);
F=sortrows(F,{'source','aperture_mode','mean_objective_evals'});
end

function keep=pareto_mask(cost,fail)
n=numel(cost);
keep=true(n,1);
tol=1e-12;
for i=1:n
    dominated=false;
    for j=1:n
        if i==j, continue; end
        no_worse=(cost(j)<=cost(i)+tol) && (fail(j)<=fail(i)+tol);
        strictly=(cost(j)<cost(i)-tol) || (fail(j)<fail(i)-tol);
        if no_worse && strictly
            dominated=true;
            break;
        end
    end
    keep(i)=~dominated;
end
end

%% =========================================================================
% Figures
% =========================================================================
function make_pareto_figures(P,B1,Base,cfg)

for isrc=1:numel(cfg.sources)
    src=cfg.sources(isrc);

    for iap=1:numel(cfg.aperture_modes)
        ap=cfg.aperture_modes(iap);

        fig=figure('Visible','off','Color','w');
        hold on; grid on; box on;

        % B1 overall non-dominated envelope
        Q1=B1(string(B1.source)==src & ...
              string(B1.aperture_mode)==ap & ...
              ismember(string(B1.policy),cfg.b1_policy_names),:);
        k1=pareto_mask(double(Q1.mean_objective_evals), ...
                       double(Q1.final_failure_probability));
        E1=Q1(k1,:);
        E1=sortrows(E1,'mean_objective_evals');
        plot(E1.mean_objective_evals,E1.final_failure_probability, ...
            '-o','LineWidth',1.5,'MarkerSize',5, ...
            'DisplayName','Best B1 envelope');

        % Staged signal-specific envelopes
        Q=P(string(P.source)==src & string(P.aperture_mode)==ap,:);
        for isig=1:numel(cfg.stage2_signals)
            sig=cfg.stage2_signals(isig);
            Z=Q(string(Q.stage2_signal)==sig,:);
            kz=pareto_mask(double(Z.mean_objective_evals), ...
                           double(Z.final_failure_probability));
            Z=Z(kz,:);
            Z=sortrows(Z,'mean_objective_evals');
            plot(Z.mean_objective_evals,Z.final_failure_probability, ...
                '-s','LineWidth',1.3,'MarkerSize',4, ...
                'DisplayName',"Staged "+sig);
        end

        % Baseline points
        Bb=Base(string(Base.source)==src & ...
                string(Base.aperture_mode)==ap,:);
        G0=Bb(string(Bb.method)=="G0_OriginalTop1",:);
        N3=Bb(string(Bb.method)=="Always_Neighbor3",:);

        plot(G0.mean_objective_evals,G0.failure_probability,'^', ...
            'MarkerSize',8,'LineWidth',1.5,'DisplayName','G0');
        plot(N3.mean_objective_evals,N3.failure_probability,'d', ...
            'MarkerSize',8,'LineWidth',1.5,'DisplayName','Always N3');

        xlabel('Mean objective evaluations');
        ylabel('Final catastrophic failure probability');
        title(sprintf('%s / %s: staged reliability Pareto',src,ap), ...
            'Interpreter','none');
        legend('Location','best','Interpreter','none');

        safe=regexprep(char(src+"_"+ap),'[^A-Za-z0-9_]','_');
        exportgraphics(fig,fullfile(cfg.figure_dir, ...
            "fig01_pareto_"+safe+".png"),'Resolution',180);
        close(fig);
    end
end
end

function make_dense_heatmaps(P,cfg)
src="dense_risk";

for iap=1:numel(cfg.aperture_modes)
    ap=cfg.aperture_modes(iap);
    Q=P(string(P.source)==src & string(P.aperture_mode)==ap,:);

    fig=figure('Visible','off','Color','w');
    tl=tiledlayout(1,numel(cfg.stage2_signals), ...
        'Padding','compact','TileSpacing','compact');

    for isig=1:numel(cfg.stage2_signals)
        sig=cfg.stage2_signals(isig);
        Z=Q(string(Q.stage2_signal)==sig,:);

        M=nan(numel(cfg.stage1_budgets),numel(cfg.stage2_budgets));
        for i=1:numel(cfg.stage1_budgets)
            for j=1:numel(cfg.stage2_budgets)
                q=Z(abs(double(Z.stage1_nominal_budget)- ...
                    cfg.stage1_budgets(i))<1e-12 & ...
                    abs(double(Z.stage2_conditional_nominal_budget)- ...
                    cfg.stage2_budgets(j))<1e-12,:);
                assert(height(q)==1,'Missing B3 heatmap cell.');
                M(i,j)=q.final_failure_probability;
            end
        end

        nexttile;
        imagesc(cfg.stage2_budgets,cfg.stage1_budgets,M);
        axis xy; colorbar;
        xlabel('Stage-2 conditional budget');
        ylabel('Stage-1 Refined-LR budget');
        title(sig,'Interpreter','none');
    end

    title(tl,sprintf('%s: final catastrophic failure probability',ap), ...
        'Interpreter','none');

    exportgraphics(fig,fullfile(cfg.figure_dir, ...
        "fig02_budget_map_"+ap+".png"),'Resolution',180);
    close(fig);
end
end

%% =========================================================================
% Rich result TXT
% =========================================================================
function write_results_txt(C,P,F,B1,Base,A1,A2,Smoke,cfg, ...
    p_trials,p_b1,p_base,p_b2)

path=fullfile(cfg.output_dir,"RESULTS_EXP009_PA5JB3.txt");
fid=fopen(path,'w');
assert(fid>0,'Cannot open B3 result TXT.');
c=onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP009 / PA5J-B3 — Staged Reliability Gate\n');
fprintf(fid,'FORMAL RESULT EXPORT FOR RESEARCH-LAYER REVIEW\n');
fprintf(fid,'No operating point or research branch is automatically selected.\n\n');

fprintf(fid,'============================================================\n');
fprintf(fid,'1. INPUT / SOFTWARE AUDIT\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'Canonical trials : %s\n',p_trials);
fprintf(fid,'B1 sweep         : %s\n',p_b1);
fprintf(fid,'B1 baselines     : %s\n',p_base);
fprintf(fid,'B2 residual audit: %s\n',p_b2);
fprintf(fid,'Canonical N=%d; unique source+trial_id=%d\n', ...
    height(C),numel(unique(string(C.source)+"|"+string(C.trial_id))));
fprintf(fid,'B1 reconstruction rows=%d; all pass=%d\n', ...
    height(A1),all(A1.selected_count_match & ...
                   A1.actual_fraction_match & ...
                   A1.failure_count_match & ...
                   A1.mean_cost_match));
fprintf(fid,'B2 reconstruction rows=%d; all pass=%d\n', ...
    height(A2),all(A2.selected_count_match & ...
                   A2.actual_fraction_match & ...
                   A2.residual_failure_match));
fprintf(fid,'Smoke tests=%d; all pass=%d\n\n', ...
    height(Smoke),all(Smoke.pass));

fprintf(fid,'============================================================\n');
fprintf(fid,'2. FROZEN DESIGN\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'Stage-1 budgets: %s\n',numvec_string(cfg.stage1_budgets));
fprintf(fid,'Stage-2 conditional budgets: %s\n', ...
    numvec_string(cfg.stage2_budgets));
fprintf(fid,'Stage-2 signals: %s\n',strjoin(cfg.stage2_signals,", "));
fprintf(fid,'Refined-LR diagnostic overhead: %d eval/trial\n', ...
    cfg.refined_lr_extra_evals);
fprintf(fid,'Stage-2 Cost-0 overhead: 0 objective eval\n');
fprintf(fid,'Selection: tie-inclusive at both stages\n\n');

fprintf(fid,'============================================================\n');
fprintf(fid,'3. BASELINES\n');
fprintf(fid,'============================================================\n');
for i=1:height(Base)
    fprintf(fid,'%s / %s / %s: P_F=%.9g (%d/%d), mean evals=%.6f\n', ...
        string(Base.source(i)),string(Base.aperture_mode(i)), ...
        string(Base.method(i)),Base.failure_probability(i), ...
        Base.failure_count(i),Base.n_trials(i), ...
        Base.mean_objective_evals(i));
end

fprintf(fid,'\n============================================================\n');
fprintf(fid,'4. STAGED PARETO FRONT POINTS\n');
fprintf(fid,'============================================================\n');
for isrc=1:numel(cfg.sources)
    src=cfg.sources(isrc);
    for iap=1:numel(cfg.aperture_modes)
        ap=cfg.aperture_modes(iap);
        fprintf(fid,'\n[%s / %s]\n',src,ap);
        Q=F(string(F.source)==src & string(F.aperture_mode)==ap,:);
        for i=1:height(Q)
            fprintf(fid,'  %-8s %-18s cost=%9.4f  P_F=%10.7f', ...
                string(Q.family(i)),string(Q.policy_or_signal(i)), ...
                Q.mean_objective_evals(i),Q.final_failure_probability(i));
            if string(Q.family(i))=="B3"
                fprintf(fid,'  b1=%.3f b2=%.3f total_fb=%.4f', ...
                    Q.stage1_or_single_budget(i), ...
                    Q.stage2_conditional_budget(i), ...
                    Q.actual_fallback_fraction(i));
            elseif string(Q.family(i))=="B1"
                fprintf(fid,'  budget=%.3f',Q.stage1_or_single_budget(i));
            end
            fprintf(fid,'\n');
        end
    end
end

fprintf(fid,'\n============================================================\n');
fprintf(fid,'5. BEST STAGED RESULT UNDER PRE-REGISTERED COST CAPS\n');
fprintf(fid,'============================================================\n');
for isrc=1:numel(cfg.sources)
    src=cfg.sources(isrc);
    for iap=1:numel(cfg.aperture_modes)
        ap=cfg.aperture_modes(iap);
        fprintf(fid,'\n[%s / %s]\n',src,ap);

        Q=P(string(P.source)==src & string(P.aperture_mode)==ap,:);
        Bb=Base(string(Base.source)==src & ...
                string(Base.aperture_mode)==ap,:);
        G0=Bb(string(Bb.method)=="G0_OriginalTop1",:);
        N3=Bb(string(Bb.method)=="Always_Neighbor3",:);
        gap=N3.mean_objective_evals(1)-G0.mean_objective_evals(1);

        for ic=1:numel(cfg.report_normalized_cost_caps)
            cap=cfg.report_normalized_cost_caps(ic);
            maxcost=G0.mean_objective_evals(1)+cap*gap;
            Z=Q(Q.mean_objective_evals<=maxcost+cfg.audit_tol,:);
            if isempty(Z)
                fprintf(fid,'  cost cap %.2f: no staged point\n',cap);
                continue;
            end
            m=min(Z.final_failure_probability);
            W=Z(abs(Z.final_failure_probability-m)<=cfg.audit_tol,:);
            [~,j]=min(W.mean_objective_evals);
            q=W(j,:);
            fprintf(fid,['  cost cap %.2f: signal=%s, b1=%.3f, b2=%.3f, ', ...
                'actual_fb=%.4f, evals=%.4f, P_F=%.9g, ', ...
                'gain_vs_best_B1=%.9g\n'], ...
                cap,string(q.stage2_signal), ...
                q.stage1_nominal_budget,q.stage2_conditional_nominal_budget, ...
                q.total_actual_fallback_fraction,q.mean_objective_evals, ...
                q.final_failure_probability, ...
                q.gain_vs_best_b1_at_no_more_cost);
        end
    end
end

fprintf(fid,'\n============================================================\n');
fprintf(fid,'6. NEW-PARETO EVIDENCE VS COMPLETE B1 ENVELOPE\n');
fprintf(fid,'============================================================\n');
for isrc=1:numel(cfg.sources)
    src=cfg.sources(isrc);
    for iap=1:numel(cfg.aperture_modes)
        ap=cfg.aperture_modes(iap);
        Q=P(string(P.source)==src & string(P.aperture_mode)==ap,:);
        improve=Q.gain_vs_best_b1_at_no_more_cost>cfg.audit_tol;
        equalish=abs(Q.gain_vs_best_b1_at_no_more_cost)<=cfg.audit_tol;
        fprintf(fid,'%s / %s: strictly improved staged points=%d/%d; ', ...
            src,ap,sum(improve),height(Q));
        fprintf(fid,'equal-to-envelope=%d; max gain=%.9g\n', ...
            sum(equalish),max(Q.gain_vs_best_b1_at_no_more_cost));
    end
end

fprintf(fid,'\n============================================================\n');
fprintf(fid,'7. STAGE-2 SIGNAL COMPARISON\n');
fprintf(fid,'============================================================\n');
for isrc=1:numel(cfg.sources)
    src=cfg.sources(isrc);
    for iap=1:numel(cfg.aperture_modes)
        ap=cfg.aperture_modes(iap);
        fprintf(fid,'\n[%s / %s]\n',src,ap);
        for isig=1:numel(cfg.stage2_signals)
            sig=cfg.stage2_signals(isig);
            Q=P(string(P.source)==src & ...
                string(P.aperture_mode)==ap & ...
                string(P.stage2_signal)==sig,:);
            fprintf(fid,'  %s: min P_F=%.9g; max gain vs best B1=%.9g; ', ...
                sig,min(Q.final_failure_probability), ...
                max(Q.gain_vs_best_b1_at_no_more_cost));
            fprintf(fid,'Pareto-front occurrences=%d\n', ...
                sum(string(F.source)==src & ...
                    string(F.aperture_mode)==ap & ...
                    string(F.family)=="B3" & ...
                    string(F.policy_or_signal)==sig));
        end
    end
end

fprintf(fid,'\n============================================================\n');
fprintf(fid,'8. IMPORTANT COUNTS / SAFETY\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'Total induced failures across staged sweep: %d\n', ...
    sum(P.stage1_induced_count)+sum(P.stage2_induced_count));
fprintf(fid,'Total persistent-after-fallback counts across staged rows: %d\n', ...
    sum(P.persistent_after_fallback_count));
fprintf(fid,'No truth physical variable is used by PA5J-B3.\n');
fprintf(fid,'No threshold / operating point is locked by this export.\n');
fprintf(fid,'Positive gain_vs_best_B1 means lower final failure probability than\n');
fprintf(fid,'every B1 selective policy available at no greater mean objective cost.\n');
end

%% =========================================================================
% Smoke tests
% =========================================================================
function S=build_smoke_tests(C,P,A1,A2,cfg)

name=strings(0,1); pass=false(0,1); detail=strings(0,1);

combo=string(C.source)+"|"+string(C.trial_id);
[name,pass,detail]=add_test(name,pass,detail, ...
    "canonical_source_trial_unique", ...
    numel(unique(combo))==height(C), ...
    sprintf('%d / %d unique',numel(unique(combo)),height(C)));

expected= ...
    numel(cfg.sources)*numel(cfg.aperture_modes)* ...
    numel(cfg.stage1_budgets)*numel(cfg.stage2_signals)* ...
    numel(cfg.stage2_budgets);

[name,pass,detail]=add_test(name,pass,detail, ...
    "staged_sweep_row_count",height(P)==expected, ...
    sprintf('%d / %d rows',height(P),expected));

[name,pass,detail]=add_test(name,pass,detail, ...
    "b1_reconstruction_all_pass", ...
    all(A1.selected_count_match & A1.actual_fraction_match & ...
        A1.failure_count_match & A1.mean_cost_match), ...
    sprintf('%d rows checked',height(A1)));

[name,pass,detail]=add_test(name,pass,detail, ...
    "b2_reconstruction_all_pass", ...
    all(A2.selected_count_match & A2.actual_fraction_match & ...
        A2.residual_failure_match), ...
    sprintf('%d rows checked',height(A2)));

% b2=0 must be identical across all Stage-2 signal names.
Q=P(abs(P.stage2_conditional_nominal_budget)<=cfg.audit_tol,:);
ok_zero=true;
groups=unique(string(Q.source)+"|"+string(Q.aperture_mode)+"|"+ ...
    compose('%.6f',Q.stage1_nominal_budget));
for ig=1:numel(groups)
    z=Q((string(Q.source)+"|"+string(Q.aperture_mode)+"|"+ ...
        compose('%.6f',Q.stage1_nominal_budget))==groups(ig),:);
    ok_zero=ok_zero && numel(unique(z.final_failure_count))==1 && ...
        max(z.mean_objective_evals)-min(z.mean_objective_evals)<=cfg.audit_tol;
end
[name,pass,detail]=add_test(name,pass,detail, ...
    "stage2_zero_signal_invariance",ok_zero, ...
    'b2=0 gives the same endpoint for all Stage-2 signal names.');

% b2=1 must trigger every Stage-1-untriggered trial.
Q=P(abs(P.stage2_conditional_nominal_budget-1)<=cfg.audit_tol,:);
ok_full=all(Q.total_selected_count==Q.n_trials);
[name,pass,detail]=add_test(name,pass,detail, ...
    "stage2_full_reaches_full_fallback",ok_full, ...
    sprintf('%d endpoints checked',height(Q)));

% Trialwise cost safety inherited from canonical input.
[name,pass,detail]=add_test(name,pass,detail, ...
    "n3_cost_not_below_g0", ...
    all(double(C.n3_objective_evals)>=double(C.g0_objective_evals)), ...
    sprintf('min delta=%.6f', ...
    min(double(C.n3_objective_evals-C.g0_objective_evals))));

% Probabilities / costs finite.
ok_num=all(isfinite(P.mean_objective_evals)) && ...
       all(isfinite(P.final_failure_probability)) && ...
       all(P.final_failure_probability>=0 & ...
           P.final_failure_probability<=1);
[name,pass,detail]=add_test(name,pass,detail, ...
    "finite_metric_range",ok_num,'All formal metrics finite and valid.');

S=table(name,pass,detail);
end

function [name,pass,detail]=add_test(name,pass,detail,nm,ok,dt)
name(end+1,1)=string(nm);
pass(end+1,1)=logical(ok);
detail(end+1,1)=string(dt);
end

%% =========================================================================
% Selection / ranks / statistics
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

function [mask,s]=tie_inclusive_top(score,b)
score=double(score(:));
n=numel(score);
assert(all(isfinite(score)),'Non-finite policy score.');
assert(b>=0 && b<=1,'Budget outside [0,1].');

if n==0
    assert(b==0,'Non-zero Stage-2 budget with empty candidate pool.');
    mask=false(0,1);
    s=sel_struct(0,0,0,NaN,0,0);
    return;
end

if b==0
    mask=false(n,1);
    s=sel_struct(0,0,0,NaN,0,0);
    return;
end

if b==1
    mask=true(n,1);
    cutoff=min(score);
    s=sel_struct(n,n,1,cutoff,sum(score==cutoff),0);
    return;
end

target=ceil(b*n);
ss=sort(score,'descend');
cutoff=ss(target);
mask=score>=cutoff;
selected=sum(mask);
actual=selected/n;
s=sel_struct(target,selected,actual,cutoff, ...
    sum(score==cutoff),actual-b);
end

function s=sel_struct(target,selected,actual,cutoff,tien,inflation)
s.target_count=target;
s.selected_count=selected;
s.actual_fraction=actual;
s.cutoff_score=cutoff;
s.cutoff_tie_count=tien;
s.budget_inflation=inflation;
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
% Frozen B2 overlap budgets
% =========================================================================
function x=cfg_anchor_b2()
x=[0.10,0.20,0.30,0.50];
end

function x=cfg_screen_b2()
x=[0.05,0.10,0.20,0.30];
end

%% =========================================================================
% Provenance / IO
% =========================================================================
function write_runtime_provenance(cfg,p_trials,p_b1,p_base,p_b2)

key=[ ...
    "experiment_id";"research_role";"stage1_signal"; ...
    "stage1_budgets";"stage2_signals";"stage2_budgets"; ...
    "refined_lr_extra_evals";"selection_rule"; ...
    "input_canonical_trials";"input_b1_sweep"; ...
    "input_b1_baselines";"input_b2_screen"; ...
    "truth_physics_role"];

value=[ ...
    cfg.experiment_id; ...
    "Staged reliability allocation / cost-reliability Pareto"; ...
    "refined_lr_asymmetry"; ...
    numvec_string(cfg.stage1_budgets); ...
    strjoin(cfg.stage2_signals,","); ...
    numvec_string(cfg.stage2_budgets); ...
    string(cfg.refined_lr_extra_evals); ...
    "tie-inclusive at both stages"; ...
    string(p_trials);string(p_b1);string(p_base);string(p_b2); ...
    "not used"];

source=[ ...
    "Frozen PA5J-B3 design"; ...
    "PA5J-B0/B1/B2 lineage"; ...
    "PA5J-A/B1/B2"; ...
    "Pre-registered B3 sweep"; ...
    "PA5J-B2 residual information audit"; ...
    "Pre-registered B3 sweep"; ...
    "PA5J-A/B1"; ...
    "PA5J-B0 engineering rule"; ...
    "Canonical upstream artifact"; ...
    "Canonical upstream artifact"; ...
    "Canonical upstream artifact"; ...
    "B2 reconstruction audit"; ...
    "B3 design constraint"];

T=table(key,value,source);
writetable(T,fullfile(cfg.output_dir,"PARAMETER_PROVENANCE_PA5JB3.csv"));
end

function s=numvec_string(x)
s="["+strjoin(compose('%.6g',x),",")+"]";
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
