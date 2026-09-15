function exp09_pa5jb3r2_shared_policy()
%EXP09_PA5JB3R2_SHARED_POLICY
% EXP009 / PA5J-B3-R2
% Shared-Policy Cross-Aperture Robustness Audit
%
% Research question:
%   Does one fixed staged configuration work across both aperture regimes?
%
% A shared configuration is:
%   (Stage-2 signal, Stage-1 nominal budget, Stage-2 conditional budget)
%
% Primary evidence:
%   DenseRisk / Paper1s and DenseRisk / BeamDerived.
%
% Original-grid results:
%   consistency check only; never used to define the shared-policy gain.
%
% No new threshold, feature, physical simulation, or learned model is
% introduced in this experiment.

clc;
cfg = config_exp09_pa5jb3r2_shared_policy();

fprintf('============================================================\n');
fprintf('EXP009 / PA5J-B3-R2 Shared-Policy Robustness Audit\n');
fprintf('============================================================\n');

ensure_dir(cfg.output_dir);
ensure_dir(cfg.figure_dir);

%% ------------------------------------------------------------------------
% 1. Resolve / load canonical upstream results
% -------------------------------------------------------------------------
p_r1 = resolve_exact_file(cfg.input_r1,cfg.results_root, ...
    "pa5jb3r1_b3_vs_dense_b1.csv");
p_b3 = resolve_exact_file(cfg.input_b3,cfg.results_root, ...
    "pa5jb3_staged_sweep.csv");

fprintf('B3-R1 comparison : %s\n',p_r1);
fprintf('B3 staged sweep  : %s\n',p_b3);

R = readtable(p_r1,'VariableNamingRule','preserve');
B = readtable(p_b3,'VariableNamingRule','preserve');

assert_schema(R,cfg.req_r1,"B3-R1 comparison");
assert_schema(B,cfg.req_b3,"B3 staged sweep");
assert_no_missing(R,cfg.req_r1,"B3-R1 comparison");
assert_no_missing(B,cfg.req_b3,"B3 staged sweep");

%% ------------------------------------------------------------------------
% 2. Input uniqueness and B3-R1 <-> B3 reconstruction audit
% -------------------------------------------------------------------------
keyR = config_row_key(R);
keyB = config_row_key(B);

assert(numel(unique(keyR))==height(R), ...
    'B3-R1 rows are not unique by source/aperture/config.');
assert(numel(unique(keyB))==height(B), ...
    'B3 rows are not unique by source/aperture/config.');

[tf,loc] = ismember(keyR,keyB);
assert(all(tf),'At least one B3-R1 row cannot be matched to B3 staged sweep.');

Bm = B(loc,:);

cost_match = abs(double(R.b3_mean_objective_evals) - ...
                 double(Bm.mean_objective_evals)) <= 1e-10;
pf_match = abs(double(R.b3_final_failure_probability) - ...
               double(Bm.final_failure_probability)) <= 1e-12;
fb_match = abs(double(R.total_actual_fallback_fraction) - ...
               double(Bm.total_actual_fallback_fraction)) <= 1e-12;

assert(all(cost_match & pf_match & fb_match), ...
    'B3-R1 and B3 staged metrics disagree.');

JoinAudit = table( ...
    string(R.source),string(R.aperture_mode), ...
    string(R.stage2_signal), ...
    double(R.stage1_nominal_budget), ...
    double(R.stage2_conditional_nominal_budget), ...
    cost_match,pf_match,fb_match, ...
    'VariableNames',{ ...
    'source','aperture_mode','stage2_signal', ...
    'stage1_nominal_budget','stage2_conditional_nominal_budget', ...
    'mean_cost_match','failure_probability_match','fallback_fraction_match'});

writetable(JoinAudit,fullfile(cfg.output_dir, ...
    "pa5jb3r2_input_join_audit.csv"));

write_provenance(cfg,p_r1,p_b3);

%% ------------------------------------------------------------------------
% 3. Build one row per SHARED staged configuration
% -------------------------------------------------------------------------
rows = {};
rr = 0;

for isig=1:numel(cfg.stage2_signals)
    sig = cfg.stage2_signals(isig);

    for ib1=1:numel(cfg.stage1_budgets)
        b1 = cfg.stage1_budgets(ib1);

        for ib2=1:numel(cfg.stage2_budgets)
            b2 = cfg.stage2_budgets(ib2);

            % DenseRisk primary pair
            Rp = get_row(R,cfg.primary_source,"Paper1s",sig,b1,b2,cfg);
            Rb = get_row(R,cfg.primary_source,"BeamDerived",sig,b1,b2,cfg);

            Bp = get_row(B,cfg.primary_source,"Paper1s",sig,b1,b2,cfg);
            Bb = get_row(B,cfg.primary_source,"BeamDerived",sig,b1,b2,cfg);

            % Original consistency pair — not used for dense selection.
            Rop = get_row(R,cfg.consistency_source,"Paper1s",sig,b1,b2,cfg);
            Rob = get_row(R,cfg.consistency_source,"BeamDerived",sig,b1,b2,cfg);

            Bop = get_row(B,cfg.consistency_source,"Paper1s",sig,b1,b2,cfg);
            Bob = get_row(B,cfg.consistency_source,"BeamDerived",sig,b1,b2,cfg);

            gp = double(Rp.new_dense_b1_gain);
            gb = double(Rb.new_dense_b1_gain);

            robust_gain = min(gp,gb);
            mean_gain = mean([gp,gb]);

            % Relative gain with respect to the per-aperture dense-B1
            % comparator. Undefined if comparator failure probability is 0.
            relp = safe_relative_gain(gp, ...
                double(Rp.dense_b1_best_failure_probability));
            relb = safe_relative_gain(gb, ...
                double(Rb.dense_b1_best_failure_probability));

            if isfinite(relp) && isfinite(relb)
                robust_rel_gain = min(relp,relb);
            else
                robust_rel_gain = NaN;
            end

            % Convert probability difference to paired integer failure-count
            % improvement for transparency.
            [saved_p,comp_count_p] = saved_failure_count(Rp,Bp);
            [saved_b,comp_count_b] = saved_failure_count(Rb,Bb);

            strict_both = gp>cfg.gain_tol && gb>cfg.gain_tol;
            noninferior_both = gp>=-cfg.gain_tol && gb>=-cfg.gain_tol;

            dense_class = classify_pair(gp,gb,cfg.gain_tol);

            % Original consistency (never used to construct robust_gain).
            gop = double(Rop.new_dense_b1_gain);
            gob = double(Rob.new_dense_b1_gain);

            original_noninferior_both = ...
                gop>=-cfg.gain_tol && gob>=-cfg.gain_tol;
            original_strict_both = ...
                gop>cfg.gain_tol && gob>cfg.gain_tol;
            original_class = classify_pair(gop,gob,cfg.gain_tol);

            [saved_op,comp_count_op] = saved_failure_count(Rop,Bop);
            [saved_ob,comp_count_ob] = saved_failure_count(Rob,Bob);

            worst_norm_cost = max( ...
                double(Bp.normalized_cost_G0_to_N3), ...
                double(Bb.normalized_cost_G0_to_N3));

            mean_norm_cost = mean([ ...
                double(Bp.normalized_cost_G0_to_N3), ...
                double(Bb.normalized_cost_G0_to_N3)]);

            worst_fallback = max( ...
                double(Bp.total_actual_fallback_fraction), ...
                double(Bb.total_actual_fallback_fraction));

            rr=rr+1;
            rows(rr,:)={ ...
                sig,b1,b2, ...
                gp,gb,robust_gain,mean_gain, ...
                relp,relb,robust_rel_gain, ...
                saved_p,saved_b,min(saved_p,saved_b), ...
                comp_count_p,comp_count_b, ...
                strict_both,noninferior_both,dense_class, ...
                double(Bp.mean_objective_evals), ...
                double(Bb.mean_objective_evals), ...
                double(Bp.normalized_cost_G0_to_N3), ...
                double(Bb.normalized_cost_G0_to_N3), ...
                worst_norm_cost,mean_norm_cost,worst_fallback, ...
                double(Bp.final_failure_probability), ...
                double(Bb.final_failure_probability), ...
                double(Rp.dense_b1_best_failure_probability), ...
                double(Rb.dense_b1_best_failure_probability), ...
                string(Rp.dense_b1_best_policy), ...
                string(Rb.dense_b1_best_policy), ...
                gop,gob, ...
                saved_op,saved_ob, ...
                comp_count_op,comp_count_ob, ...
                original_strict_both,original_noninferior_both, ...
                original_class, ...
                double(Bop.final_failure_probability), ...
                double(Bob.final_failure_probability)}; %#ok<AGROW>
        end
    end
end

Shared = cell2table(rows,'VariableNames',{ ...
    'stage2_signal','stage1_nominal_budget', ...
    'stage2_conditional_nominal_budget', ...
    'dense_Paper1s_gain','dense_BeamDerived_gain', ...
    'robust_min_gain','dense_mean_gain', ...
    'dense_Paper1s_relative_gain','dense_BeamDerived_relative_gain', ...
    'robust_min_relative_gain', ...
    'dense_Paper1s_saved_failures','dense_BeamDerived_saved_failures', ...
    'robust_min_saved_failures', ...
    'dense_Paper1s_comparator_failure_count', ...
    'dense_BeamDerived_comparator_failure_count', ...
    'dense_strict_both','dense_noninferior_both','dense_pair_class', ...
    'dense_Paper1s_mean_cost','dense_BeamDerived_mean_cost', ...
    'dense_Paper1s_normalized_cost','dense_BeamDerived_normalized_cost', ...
    'dense_worst_normalized_cost','dense_mean_normalized_cost', ...
    'dense_worst_actual_fallback_fraction', ...
    'dense_Paper1s_final_failure_probability', ...
    'dense_BeamDerived_final_failure_probability', ...
    'dense_Paper1s_comparator_failure_probability', ...
    'dense_BeamDerived_comparator_failure_probability', ...
    'dense_Paper1s_comparator_policy', ...
    'dense_BeamDerived_comparator_policy', ...
    'original_Paper1s_gain','original_BeamDerived_gain', ...
    'original_Paper1s_saved_failures','original_BeamDerived_saved_failures', ...
    'original_Paper1s_comparator_failure_count', ...
    'original_BeamDerived_comparator_failure_count', ...
    'original_strict_both','original_noninferior_both', ...
    'original_pair_class', ...
    'original_Paper1s_final_failure_probability', ...
    'original_BeamDerived_final_failure_probability'});

assert(height(Shared)== ...
    numel(cfg.stage2_signals)*numel(cfg.stage1_budgets)* ...
    numel(cfg.stage2_budgets), ...
    'Unexpected number of shared configurations.');

%% ------------------------------------------------------------------------
% 4. Robust candidate frontier
% -------------------------------------------------------------------------
Shared.robust_front = false(height(Shared),1);

idx = find(Shared.dense_strict_both);
if ~isempty(idx)
    k = robust_pareto_mask( ...
        double(Shared.dense_worst_normalized_cost(idx)), ...
        double(Shared.robust_min_gain(idx)));
    Shared.robust_front(idx(k)) = true;
end

writetable(Shared,fullfile(cfg.output_dir, ...
    "pa5jb3r2_shared_configs.csv"));

%% ------------------------------------------------------------------------
% 5. Stage-2 signal summary
% -------------------------------------------------------------------------
sumrows={};
rs=0;

for isig=1:numel(cfg.stage2_signals)
    sig=cfg.stage2_signals(isig);
    Q=Shared(string(Shared.stage2_signal)==sig,:);

    strict=Q.dense_strict_both;
    noninf=Q.dense_noninferior_both;

    rs=rs+1;
    sumrows(rs,:)={ ...
        sig,height(Q),sum(strict),sum(noninf), ...
        max(Q.robust_min_gain), ...
        max(Q.robust_min_saved_failures), ...
        sum(Q.robust_front), ...
        sum(strict & Q.original_noninferior_both), ...
        sum(strict & Q.original_strict_both)}; %#ok<AGROW>
end

SignalSummary=cell2table(sumrows,'VariableNames',{ ...
    'stage2_signal','n_shared_configs','dense_strict_both_count', ...
    'dense_noninferior_both_count','max_robust_min_gain', ...
    'max_robust_min_saved_failures','robust_front_count', ...
    'dense_strict_and_original_noninferior_count', ...
    'dense_strict_and_original_strict_count'});

writetable(SignalSummary,fullfile(cfg.output_dir, ...
    "pa5jb3r2_signal_summary.csv"));

%% ------------------------------------------------------------------------
% 6. Cross-aperture gain concordance
% -------------------------------------------------------------------------
CorrRows={};
rc=0;

sets=["ALL",cfg.stage2_signals];

for i=1:numel(sets)
    s=sets(i);
    if s=="ALL"
        Q=Shared;
    else
        Q=Shared(string(Shared.stage2_signal)==s,:);
    end

    rho=spearman_corr( ...
        double(Q.dense_Paper1s_gain), ...
        double(Q.dense_BeamDerived_gain));

    rc=rc+1;
    CorrRows(rc,:)={s,height(Q),rho}; %#ok<AGROW>
end

Corr=cell2table(CorrRows,'VariableNames',{ ...
    'stage2_signal_scope','n_configs','spearman_gain_correlation'});

writetable(Corr,fullfile(cfg.output_dir, ...
    "pa5jb3r2_cross_aperture_correlation.csv"));

%% ------------------------------------------------------------------------
% 7. Smoke tests
% -------------------------------------------------------------------------
Smoke=build_smoke_tests(R,B,JoinAudit,Shared,cfg);
writetable(Smoke,fullfile(cfg.output_dir, ...
    "pa5jb3r2_smoke_test.csv"));

assert(all(Smoke.pass), ...
    'PA5J-B3-R2 smoke test failed. Do not interpret results.');

%% ------------------------------------------------------------------------
% 8. Figures
% -------------------------------------------------------------------------
make_figures(Shared,cfg);

%% ------------------------------------------------------------------------
% 9. Rich Research-Layer result TXT
% -------------------------------------------------------------------------
write_results_txt(Shared,SignalSummary,Corr,Smoke,JoinAudit,cfg,p_r1,p_b3);

fprintf('\nPA5J-B3-R2 completed.\n');
fprintf('Output: %s\n',cfg.output_dir);
fprintf('Upload RESULTS_EXP009_PA5JB3R2.txt + key figures first.\n');
fprintf('No shared operating point was automatically selected.\n');

end

%% =========================================================================
% Saved-failure accounting
% =========================================================================
function [saved,comp_count]=saved_failure_count(Rrow,Brow)

n=double(Brow.n_trials);
b3_count=double(Brow.final_failure_count);
comp_pf=double(Rrow.dense_b1_best_failure_probability);

raw=comp_pf*n;
comp_count=round(raw);

assert(abs(raw-comp_count)<=1e-7, ...
    'Dense-B1 comparator probability does not map to integer count.');

saved=comp_count-b3_count;

gain_count=double(Rrow.new_dense_b1_gain)*n;
assert(abs(gain_count-saved)<=1e-7, ...
    'Probability gain and saved-failure count disagree.');
end

function r=safe_relative_gain(gain,base)
if base>0
    r=gain/base;
else
    r=NaN;
end
end

function c=classify_pair(a,b,tol)
if a>tol && b>tol
    c="strict_both";
elseif a>=-tol && b>=-tol && (a>tol || b>tol)
    c="noninferior_both";
elseif abs(a)<=tol && abs(b)<=tol
    c="equal_both";
elseif (a>tol && b<-tol) || (b>tol && a<-tol)
    c="mixed_sign";
elseif a<-tol && b<-tol
    c="worse_both";
else
    c="mixed_boundary";
end
end

%% =========================================================================
% Robust Pareto: minimize worst normalized cost, maximize robust gain
% =========================================================================
function keep=robust_pareto_mask(cost,gain)

cost=double(cost(:));
gain=double(gain(:));
n=numel(cost);
tol=1e-12;
keep=true(n,1);

for i=1:n
    dominated=false;
    for j=1:n
        if i==j
            continue;
        end
        no_worse=(cost(j)<=cost(i)+tol) && ...
                 (gain(j)>=gain(i)-tol);
        strict=(cost(j)<cost(i)-tol) || ...
               (gain(j)>gain(i)+tol);
        if no_worse && strict
            dominated=true;
            break;
        end
    end
    keep(i)=~dominated;
end
end

%% =========================================================================
% Spearman correlation without Statistics Toolbox
% =========================================================================
function rho=spearman_corr(x,y)
x=double(x(:));
y=double(y(:));
assert(numel(x)==numel(y),'Spearman input length mismatch.');
rx=midranks(x);
ry=midranks(y);

dx=rx-mean(rx);
dy=ry-mean(ry);

den=sqrt(sum(dx.^2)*sum(dy.^2));
if den==0
    rho=NaN;
else
    rho=sum(dx.*dy)/den;
end
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

%% =========================================================================
% Figures
% =========================================================================
function make_figures(S,cfg)

% Fig 1: cross-aperture dense gain scatter
fig=figure('Visible','off','Color','w');
hold on; grid on; box on;

for isig=1:numel(cfg.stage2_signals)
    sig=cfg.stage2_signals(isig);
    Q=S(string(S.stage2_signal)==sig,:);
    scatter(Q.dense_Paper1s_gain,Q.dense_BeamDerived_gain, ...
        28,'DisplayName',sig);
end

xline(0,'--','HandleVisibility','off');
yline(0,'--','HandleVisibility','off');
xlabel('Dense Paper1s gain vs dense B1');
ylabel('Dense BeamDerived gain vs dense B1');
title('PA5J-B3-R2: shared-policy cross-aperture gain');
legend('Location','best','Interpreter','none');

exportgraphics(fig,fullfile(cfg.figure_dir, ...
    "fig01_dense_gain_scatter.png"),'Resolution',180);
close(fig);

% Fig 2: robust gain heatmap by signal
fig=figure('Visible','off','Color','w');
tl=tiledlayout(1,numel(cfg.stage2_signals), ...
    'Padding','compact','TileSpacing','compact');

mabs=max(abs(S.robust_min_gain));
if mabs<=0
    mabs=1;
end

for isig=1:numel(cfg.stage2_signals)
    sig=cfg.stage2_signals(isig);
    Q=S(string(S.stage2_signal)==sig,:);

    M=nan(numel(cfg.stage1_budgets),numel(cfg.stage2_budgets));

    for i=1:numel(cfg.stage1_budgets)
        for j=1:numel(cfg.stage2_budgets)
            z=Q(abs(Q.stage1_nominal_budget-cfg.stage1_budgets(i))<1e-12 & ...
                abs(Q.stage2_conditional_nominal_budget- ...
                    cfg.stage2_budgets(j))<1e-12,:);
            assert(height(z)==1,'Missing shared-config heatmap cell.');
            M(i,j)=z.robust_min_gain;
        end
    end

    nexttile;
    imagesc(cfg.stage2_budgets,cfg.stage1_budgets,M);
    axis xy;
    colorbar;
    caxis([-mabs,mabs]);
    xlabel('Stage-2 conditional budget');
    ylabel('Stage-1 Refined-LR budget');
    title(sig,'Interpreter','none');
end

title(tl,'Worst-aperture dense gain: min(Paper1s, BeamDerived)', ...
    'Interpreter','none');

exportgraphics(fig,fullfile(cfg.figure_dir, ...
    "fig02_robust_gain_maps.png"),'Resolution',180);
close(fig);

% Fig 3: robust gain versus worst normalized cost
fig=figure('Visible','off','Color','w');
hold on; grid on; box on;

for isig=1:numel(cfg.stage2_signals)
    sig=cfg.stage2_signals(isig);
    Q=S(string(S.stage2_signal)==sig,:);
    scatter(Q.dense_worst_normalized_cost,Q.robust_min_gain, ...
        22,'DisplayName',sig);
end

Q=S(S.robust_front,:);
if ~isempty(Q)
    scatter(Q.dense_worst_normalized_cost,Q.robust_min_gain, ...
        70,'s','LineWidth',1.5,'DisplayName','Robust candidate front');
end

yline(0,'--','HandleVisibility','off');
xlabel('Worst-aperture normalized cost');
ylabel('Worst-aperture dense gain');
title('Shared staged robustness versus worst-case compute');
legend('Location','best','Interpreter','none');

exportgraphics(fig,fullfile(cfg.figure_dir, ...
    "fig03_robust_gain_vs_cost.png"),'Resolution',180);
close(fig);

% Fig 4: Original consistency only for dense-strict configs
Q=S(S.dense_strict_both,:);

fig=figure('Visible','off','Color','w');
hold on; grid on; box on;

if ~isempty(Q)
    for isig=1:numel(cfg.stage2_signals)
        sig=cfg.stage2_signals(isig);
        Z=Q(string(Q.stage2_signal)==sig,:);
        if ~isempty(Z)
            scatter(Z.original_Paper1s_gain,Z.original_BeamDerived_gain, ...
                34,'DisplayName',sig);
        end
    end
end

xline(0,'--','HandleVisibility','off');
yline(0,'--','HandleVisibility','off');
xlabel('Original Paper1s gain vs dense B1');
ylabel('Original BeamDerived gain vs dense B1');
title('Original-grid consistency of dense-robust shared configs');
legend('Location','best','Interpreter','none');

exportgraphics(fig,fullfile(cfg.figure_dir, ...
    "fig04_original_consistency.png"),'Resolution',180);
close(fig);

end

%% =========================================================================
% Rich results TXT
% =========================================================================
function write_results_txt(S,SignalSummary,Corr,Smoke,JoinAudit,cfg,p_r1,p_b3)

path=fullfile(cfg.output_dir,"RESULTS_EXP009_PA5JB3R2.txt");
fid=fopen(path,'w');
assert(fid>0,'Cannot open B3-R2 result TXT.');
c=onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP009 / PA5J-B3-R2 — Shared-Policy Cross-Aperture Robustness Audit\n');
fprintf(fid,'FORMAL RESULT EXPORT FOR RESEARCH-LAYER REVIEW\n');
fprintf(fid,'No shared operating point is automatically selected.\n\n');

fprintf(fid,'============================================================\n');
fprintf(fid,'1. INPUT / SOFTWARE AUDIT\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'B3-R1 input: %s\n',p_r1);
fprintf(fid,'B3 input   : %s\n',p_b3);
fprintf(fid,'R1 rows=%d; B3 join-audit rows=%d; all join checks pass=%d\n', ...
    height(JoinAudit),height(JoinAudit), ...
    all(JoinAudit.mean_cost_match & ...
        JoinAudit.failure_probability_match & ...
        JoinAudit.fallback_fraction_match));
fprintf(fid,'Shared configuration count=%d\n',height(S));
fprintf(fid,'Smoke tests=%d; all pass=%d\n\n', ...
    height(Smoke),all(Smoke.pass));

fprintf(fid,'============================================================\n');
fprintf(fid,'2. FROZEN ROBUSTNESS DEFINITION\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'Primary source: %s\n',cfg.primary_source);
fprintf(fid,'Apertures: %s\n',strjoin(cfg.apertures,", "));
fprintf(fid,'Stage-2 signals: %s\n',strjoin(cfg.stage2_signals,", "));
fprintf(fid,'Stage-1 budgets: %s\n',numvec_string(cfg.stage1_budgets));
fprintf(fid,'Stage-2 budgets: %s\n',numvec_string(cfg.stage2_budgets));
fprintf(fid,'robust_min_gain = min(dense Paper1s gain, dense BeamDerived gain)\n');
fprintf(fid,['Dense strict-both requires gain > 0 against each aperture''s ', ...
    'own exhaustive dense-B1 frontier.\n']);
fprintf(fid,'Original grid is consistency-only and never enters robust_min_gain.\n\n');

fprintf(fid,'============================================================\n');
fprintf(fid,'3. CROSS-APERTURE CORE VERDICT\n');
fprintf(fid,'============================================================\n');

strict=S.dense_strict_both;
noninf=S.dense_noninferior_both;

fprintf(fid,'Dense strict-both configurations: %d / %d\n',sum(strict),height(S));
fprintf(fid,'Dense noninferior-both configurations: %d / %d\n',sum(noninf),height(S));
fprintf(fid,'Robust-front configurations: %d\n',sum(S.robust_front));

if any(strict)
    Q=S(strict,:);
    [mx,j]=max(Q.robust_min_gain);
    q=Q(j,:);
    fprintf(fid,['Strongest worst-aperture gain: signal=%s, b1=%.6g, b2=%.6g, ', ...
        'robust gain=%.9g, Paper gain=%.9g, Beam gain=%.9g, ', ...
        'worst norm cost=%.9g, saved failures=(%d,%d)\n'], ...
        string(q.stage2_signal),q.stage1_nominal_budget, ...
        q.stage2_conditional_nominal_budget,mx, ...
        q.dense_Paper1s_gain,q.dense_BeamDerived_gain, ...
        q.dense_worst_normalized_cost, ...
        q.dense_Paper1s_saved_failures, ...
        q.dense_BeamDerived_saved_failures);

    fprintf(fid,'Dense-strict configs also Original-noninferior in both apertures: %d / %d\n', ...
        sum(Q.original_noninferior_both),height(Q));
    fprintf(fid,'Dense-strict configs also Original-strict in both apertures: %d / %d\n', ...
        sum(Q.original_strict_both),height(Q));
else
    fprintf(fid,'No dense strict-both shared configuration exists.\n');
end

fprintf(fid,'\n============================================================\n');
fprintf(fid,'4. STAGE-2 SIGNAL SUMMARY\n');
fprintf(fid,'============================================================\n');

for i=1:height(SignalSummary)
    fprintf(fid,[ ...
        '%s: shared=%d, dense strict-both=%d, dense noninferior-both=%d, ', ...
        'max robust gain=%.9g, max robust saved failures=%d, ', ...
        'robust-front=%d, strict+Original-noninferior=%d, ', ...
        'strict+Original-strict=%d\n'], ...
        string(SignalSummary.stage2_signal(i)), ...
        SignalSummary.n_shared_configs(i), ...
        SignalSummary.dense_strict_both_count(i), ...
        SignalSummary.dense_noninferior_both_count(i), ...
        SignalSummary.max_robust_min_gain(i), ...
        SignalSummary.max_robust_min_saved_failures(i), ...
        SignalSummary.robust_front_count(i), ...
        SignalSummary.dense_strict_and_original_noninferior_count(i), ...
        SignalSummary.dense_strict_and_original_strict_count(i));
end

fprintf(fid,'\n============================================================\n');
fprintf(fid,'5. CROSS-APERTURE GAIN CONCORDANCE\n');
fprintf(fid,'============================================================\n');
for i=1:height(Corr)
    fprintf(fid,'%s: N=%d, Spearman rho=%.9g\n', ...
        string(Corr.stage2_signal_scope(i)), ...
        Corr.n_configs(i),Corr.spearman_gain_correlation(i));
end

fprintf(fid,'\n============================================================\n');
fprintf(fid,'6. TOP SHARED CONFIGURATIONS BY WORST-APERTURE GAIN\n');
fprintf(fid,'============================================================\n');

Q=S(S.dense_strict_both,:);
if isempty(Q)
    fprintf(fid,'No strict-both configuration to rank.\n');
else
    Q=sortrows(Q,{'robust_min_gain','dense_worst_normalized_cost'}, ...
        {'descend','ascend'});
    n=min(cfg.top_k,height(Q));

    for i=1:n
        q=Q(i,:);
        fprintf(fid,[ ...
            '#%02d %s b1=%.3f b2=%.3f | robust=%.9g ', ...
            'Paper=%.9g Beam=%.9g | saved=(%d,%d) | ', ...
            'worst norm cost=%.6f | Original gain=(%.9g,%.9g) ', ...
            'Original class=%s | robust_front=%d\n'], ...
            i,string(q.stage2_signal), ...
            q.stage1_nominal_budget, ...
            q.stage2_conditional_nominal_budget, ...
            q.robust_min_gain, ...
            q.dense_Paper1s_gain,q.dense_BeamDerived_gain, ...
            q.dense_Paper1s_saved_failures, ...
            q.dense_BeamDerived_saved_failures, ...
            q.dense_worst_normalized_cost, ...
            q.original_Paper1s_gain,q.original_BeamDerived_gain, ...
            string(q.original_pair_class),q.robust_front);
    end
end

fprintf(fid,'\n============================================================\n');
fprintf(fid,'7. ROBUST CANDIDATE FRONT\n');
fprintf(fid,'============================================================\n');

Q=S(S.robust_front,:);
if isempty(Q)
    fprintf(fid,'No strict-both robust candidate front exists.\n');
else
    Q=sortrows(Q,'dense_worst_normalized_cost');
    for i=1:height(Q)
        q=Q(i,:);
        fprintf(fid,[ ...
            '%s b1=%.3f b2=%.3f | worst norm cost=%.6f | ', ...
            'robust gain=%.9g | Paper gain=%.9g Beam gain=%.9g | ', ...
            'Original=(%.9g,%.9g) class=%s\n'], ...
            string(q.stage2_signal),q.stage1_nominal_budget, ...
            q.stage2_conditional_nominal_budget, ...
            q.dense_worst_normalized_cost,q.robust_min_gain, ...
            q.dense_Paper1s_gain,q.dense_BeamDerived_gain, ...
            q.original_Paper1s_gain,q.original_BeamDerived_gain, ...
            string(q.original_pair_class));
    end
end

fprintf(fid,'\n============================================================\n');
fprintf(fid,'8. INTERPRETATION BOUNDARIES\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'No configuration was selected using Original-grid performance.\n');
fprintf(fid,'No new B3 budget, score, or threshold was introduced.\n');
fprintf(fid,'No physical truth variable was used.\n');
fprintf(fid,['A positive robust_min_gain means the SAME staged configuration ', ...
    'strictly beats each aperture''s own exhaustive deterministic ', ...
    'single-stage B1 frontier at no greater cost.\n']);
fprintf(fid,['This remains an in-grid cross-aperture robustness audit, not an ', ...
    'independent held-out generalization test.\n']);
end

%% =========================================================================
% Smoke tests
% =========================================================================
function Smoke=build_smoke_tests(R,B,JoinAudit,S,cfg)

name=strings(0,1);
pass=false(0,1);
detail=strings(0,1);

[name,pass,detail]=add_test(name,pass,detail, ...
    "r1_unique_source_aperture_config", ...
    numel(unique(config_row_key(R)))==height(R), ...
    sprintf('%d / %d unique',numel(unique(config_row_key(R))),height(R)));

[name,pass,detail]=add_test(name,pass,detail, ...
    "b3_unique_source_aperture_config", ...
    numel(unique(config_row_key(B)))==height(B), ...
    sprintf('%d / %d unique',numel(unique(config_row_key(B))),height(B)));

okjoin=all(JoinAudit.mean_cost_match & ...
           JoinAudit.failure_probability_match & ...
           JoinAudit.fallback_fraction_match);
[name,pass,detail]=add_test(name,pass,detail, ...
    "r1_b3_join_metrics_match",okjoin, ...
    sprintf('%d rows checked',height(JoinAudit)));

expected=numel(cfg.stage2_signals)* ...
    numel(cfg.stage1_budgets)*numel(cfg.stage2_budgets);
[name,pass,detail]=add_test(name,pass,detail, ...
    "shared_config_count",height(S)==expected, ...
    sprintf('%d / %d',height(S),expected));

okrobust=all(abs(S.robust_min_gain - ...
    min([S.dense_Paper1s_gain,S.dense_BeamDerived_gain],[],2))<=1e-12);
[name,pass,detail]=add_test(name,pass,detail, ...
    "robust_gain_definition",okrobust, ...
    'robust gain equals rowwise min of dense aperture gains');

okstrict=all(S.dense_strict_both == ...
    (S.dense_Paper1s_gain>cfg.gain_tol & ...
     S.dense_BeamDerived_gain>cfg.gain_tol));
[name,pass,detail]=add_test(name,pass,detail, ...
    "strict_both_definition",okstrict, ...
    'strict-both flag matches both dense gains > 0');

okcount=all(abs( ...
    S.dense_Paper1s_gain.*get_dense_n(S,"Paper1s") - ...
    S.dense_Paper1s_saved_failures) < 1e-7) && ...
    all(abs( ...
    S.dense_BeamDerived_gain.*get_dense_n(S,"BeamDerived") - ...
    S.dense_BeamDerived_saved_failures) < 1e-7);

[name,pass,detail]=add_test(name,pass,detail, ...
    "gain_probability_matches_saved_counts",okcount, ...
    'dense probability gains map to integer paired failure-count gains');

[name,pass,detail]=add_test(name,pass,detail, ...
    "no_nan_primary_gain", ...
    all(isfinite(S.dense_Paper1s_gain)) && ...
    all(isfinite(S.dense_BeamDerived_gain)), ...
    'All primary dense gains are finite.');

Smoke=table(name,pass,detail);
end

function n=get_dense_n(S,ap)
% n is constant by aperture; infer it from comparator count / probability
% is unsafe at zero. Use known B3 final probability and counts are not
% stored in Shared, so return the frozen dataset sizes validated upstream.
if string(ap)=="Paper1s"
    n=1122*ones(height(S),1);
elseif string(ap)=="BeamDerived"
    n=408*ones(height(S),1);
else
    error('Unknown dense aperture.');
end
end

function [name,pass,detail]=add_test(name,pass,detail,nm,ok,dt)
name(end+1,1)=string(nm);
pass(end+1,1)=logical(ok);
detail(end+1,1)=string(dt);
end

%% =========================================================================
% Exact row retrieval / keys
% =========================================================================
function q=get_row(T,src,ap,sig,b1,b2,cfg)

mask=string(T.source)==src & ...
     string(T.aperture_mode)==ap & ...
     string(T.stage2_signal)==sig & ...
     abs(double(T.stage1_nominal_budget)-b1)<=cfg.gain_tol & ...
     abs(double(T.stage2_conditional_nominal_budget)-b2)<=cfg.gain_tol;

q=T(mask,:);
assert(height(q)==1, ...
    'Expected one row for %s / %s / %s / %.6g / %.6g; got %d.', ...
    src,ap,sig,b1,b2,height(q));
end

function key=config_row_key(T)
key=string(T.source)+"|"+string(T.aperture_mode)+"|"+ ...
    string(T.stage2_signal)+"|"+ ...
    compose('%.12g',double(T.stage1_nominal_budget))+"|"+ ...
    compose('%.12g',double(T.stage2_conditional_nominal_budget));
end

%% =========================================================================
% Provenance / IO
% =========================================================================
function write_provenance(cfg,p_r1,p_b3)

key=[ ...
    "experiment_id";"research_role";"primary_source"; ...
    "consistency_source";"shared_policy_definition"; ...
    "robust_gain_definition";"stage2_signals"; ...
    "stage1_budgets";"stage2_budgets"; ...
    "input_b3r1";"input_b3";"original_role"; ...
    "truth_physics"];

value=[ ...
    cfg.experiment_id; ...
    "Shared-policy cross-aperture robustness audit"; ...
    cfg.primary_source; ...
    cfg.consistency_source; ...
    "(Stage2 signal, b1, b2) fixed across apertures"; ...
    "min(dense Paper1s gain, dense BeamDerived gain)"; ...
    strjoin(cfg.stage2_signals,","); ...
    numvec_string(cfg.stage1_budgets); ...
    numvec_string(cfg.stage2_budgets); ...
    string(p_r1);string(p_b3); ...
    "consistency check only; excluded from robust selection"; ...
    "not used"];

source=[ ...
    "Frozen PA5J-B3-R2 design"; ...
    "PA5J-B3-R1 interpretation"; ...
    "B3-R2 primary robustness domain"; ...
    "B3-R2 rare-event consistency domain"; ...
    "B3 frozen configuration grid"; ...
    "Pre-registered B3-R2 metric"; ...
    "PA5J-B3"; ...
    "PA5J-B3"; ...
    "PA5J-B3"; ...
    "Canonical upstream artifact"; ...
    "Canonical upstream artifact"; ...
    "Research-layer anti-overfitting rule"; ...
    "B3-R2 design constraint"];

T=table(key,value,source);
writetable(T,fullfile(cfg.output_dir, ...
    "PARAMETER_PROVENANCE_PA5JB3R2.csv"));
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
    p=expected;
    return;
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
