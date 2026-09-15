function exp09_pa5jb2_residual_anatomy()
%EXP09_PA5JB2_RESIDUAL_ANATOMY
% EXP009 / PA5J-B2
% Residual-Failure / Policy-Crossover Anatomy
%
% Research questions:
%   RQ1. After Refined-LR removes the most obvious G0 failures, do the
%        Cost-0 signals still discriminate the remaining failures?
%   RQ2. Which physical states concentrate in the G5 residual failure tail?
%        Is the residual tail explainable by eta / fence geometry alone?
%   RQ3. Why can naive All3 max-rank fusion underperform Refined-LR at low
%        fallback budgets and improve later?
%
% This experiment does NOT:
%   - add a new indicator;
%   - retrain / weight a fusion score;
%   - invoke Neighbor-3 again;
%   - choose a final threshold;
%   - promote truth physics into gate features.
%
% Engineering rules inherited from PA5J-B0/B1:
%   exact schema contract, unique trial identity, complete-case audit,
%   tie-inclusive cutoff, nominal/actual budget separation, reconstruction
%   audit against B1, Wilson intervals, factual summary only.

clc;
cfg = config_exp09_pa5jb2_residual_anatomy();

fprintf('============================================================\n');
fprintf('EXP009 / PA5J-B2 Residual Failure Anatomy\n');
fprintf('============================================================\n');

ensure_dir(cfg.output_dir);
ensure_dir(cfg.figure_dir);

%% 1. Resolve exact inputs
p_dense = resolve_exact_file(cfg.input_dense, cfg.results_root, ...
    "pa5ja_indicator_trials_dense_risk.csv");
p_b1 = resolve_exact_file(cfg.input_b1_sweep, cfg.results_root, ...
    "pa5jb1_policy_sweep.csv");

fprintf('Dense PA5J-A : %s\n', p_dense);
fprintf('B1 sweep     : %s\n', p_b1);

D = readtable(p_dense, 'VariableNamingRule','preserve');
B1 = readtable(p_b1, 'VariableNamingRule','preserve');

assert_schema(D, cfg.req_dense, "PA5J-A dense-risk");
assert_schema(B1, cfg.req_b1, "PA5J-B1 policy sweep");
assert_no_missing(D, cfg.req_dense, "PA5J-A dense-risk");

assert(all(string(D.source)==cfg.primary_source), ...
    'PA5J-A input is not purely dense_risk.');
assert(numel(unique(D.trial_id))==height(D), ...
    'dense_risk trial_id is not unique.');

%% 2. Frozen parameter provenance
write_provenance(cfg, p_dense, p_b1);

%% 3. Main analyses
summary_rows = {};
screen_rows = {};
disp_rows = {};
phys_rows = {};
trial_rows = {};
audit_rows = {};

rs=0; rr=0; rd=0; rp=0; rt=0; ra=0;

for ia = 1:numel(cfg.aperture_modes)
    ap = cfg.aperture_modes(ia);
    G = D(string(D.aperture_mode)==ap,:);
    assert(~isempty(G),'Missing aperture group: %s',ap);

    F = logical(G.catastrophic_branch_failure);

    % Frozen raw risk scores: larger means riskier.
    s_five = -double(G.fivebin_peak_fraction);
    s_ent  =  double(G.local_entropy5);
    s_lr   =  double(G.refined_lr_asymmetry);

    % Frozen B1 fusion definitions.
    p_five = risk_percentile(s_five);
    p_ent  = risk_percentile(s_ent);
    p_lr   = risk_percentile(s_lr);
    s_cost0 = max([p_five,p_ent],[],2);
    s_all3  = max([p_five,p_ent,p_lr],[],2);

    total_fail = sum(F);
    assert(total_fail>0,'No G0 failures in %s.',ap);

    for ib = 1:numel(cfg.anchor_budgets)
        b = cfg.anchor_budgets(ib);

        [Tlr, slr] = tie_inclusive_top(s_lr,b);
        [Tall, sall] = tie_inclusive_top(s_all3,b);

        captured = F & Tlr;
        residual = F & ~Tlr;
        candidate = ~Tlr;

        ncap = sum(captured);
        nres = sum(residual);

        rs=rs+1;
        [rlo,rhi] = wilson_ci(nres,total_fail);
        summary_rows(rs,:) = { ...
            cfg.primary_source, ap, b, ...
            slr.actual_fraction, slr.selected_count, ...
            total_fail, ncap, nres, ncap/total_fail, nres/total_fail, ...
            rlo, rhi, sum(candidate), mean(F(candidate))}; %#ok<AGROW>

        % Trial-level membership export.
        for k=1:height(G)
            rt=rt+1;
            trial_rows(rt,:) = { ...
                cfg.primary_source, ap, b, G.trial_id(k), ...
                double(F(k)), double(Tlr(k)), double(Tall(k)), ...
                double(captured(k)), double(residual(k)), ...
                double(G.fivebin_peak_fraction(k)), ...
                double(G.local_entropy5(k)), ...
                double(G.refined_lr_asymmetry(k)), ...
                double(G.relative_phase_rad(k)), ...
                double(G.Gamma_PA4(k)), ...
                double(G.true_eta_bins(k)), ...
                double(G.weak_to_strong_ratio(k)), ...
                double(G.delta_velocity_mps(k)), ...
                string(G.strong_velocity_side(k))}; %#ok<AGROW>
        end

        % -------------------------------------------------------------
        % RQ1: residual-pool discriminability of Cost-0 signals
        % -------------------------------------------------------------
        score_names = ["FiveBin","Entropy","Cost0_MaxRank"];
        score_mat = [s_five,s_ent,s_cost0];

        for is=1:numel(score_names)
            sname = score_names(is);
            sc = score_mat(:,is);

            auc = binary_auc(sc(candidate),F(candidate));

            for iq=1:numel(cfg.residual_screen_budgets)
                q = cfg.residual_screen_budgets(iq);

                local_score = sc(candidate);
                [local_sel, ss] = tie_inclusive_top(local_score,q);

                sel = false(height(G),1);
                cand_idx = find(candidate);
                sel(cand_idx(local_sel)) = true;

                rescued_resid = sum(residual & sel);
                selected_fail = sum(F & sel);
                selected_total = sum(sel);

                if nres>0
                    cond_capture = rescued_resid/nres;
                    [clo,chi] = wilson_ci(rescued_resid,nres);
                else
                    cond_capture = NaN; clo=NaN; chi=NaN;
                end

                if selected_total>0
                    precision = selected_fail/selected_total;
                    [plo,phi] = wilson_ci(selected_fail,selected_total);
                else
                    precision = NaN; plo=NaN; phi=NaN;
                end

                rr=rr+1;
                screen_rows(rr,:) = { ...
                    cfg.primary_source, ap, b, sname, auc, ...
                    q, ss.actual_fraction, selected_total/height(G), ...
                    selected_total, rescued_resid, nres, cond_capture, ...
                    clo, chi, selected_fail, precision, plo, phi}; %#ok<AGROW>
            end
        end

        % -------------------------------------------------------------
        % RQ3: G6 vs G5 rank displacement at the same nominal budget
        % -------------------------------------------------------------
        lost_fail = F & Tlr & ~Tall;
        gained_fail = F & ~Tlr & Tall;
        overlap_fail = F & Tlr & Tall;

        promoted_success = ~F & ~Tlr & Tall;
        demoted_success = ~F & Tlr & ~Tall;

        rd=rd+1;
        disp_rows(rd,:) = { ...
            cfg.primary_source, ap, b, ...
            slr.actual_fraction, sall.actual_fraction, ...
            sum(F&Tlr), sum(F&Tall), sum(overlap_fail), ...
            sum(lost_fail), sum(gained_fail), ...
            sum(gained_fail)-sum(lost_fail), ...
            sum(promoted_success), sum(demoted_success), ...
            sum(Tlr & Tall), sum(Tlr | Tall)}; %#ok<AGROW>

        % -------------------------------------------------------------
        % RQ2: physical anatomy. Truth physics are post-hoc only.
        % -------------------------------------------------------------
        for iv=1:numel(cfg.physics_vars)
            vname = cfg.physics_vars{iv};
            x = G.(vname);
            states = unique_state_values(x);

            for iu=1:numel(states)
                % unique_state_values returns a cell array of scalar states.
                % Use content indexing so numeric states remain numeric and
                % string states remain scalar strings.
                st = states{iu};
                sm = state_mask(x,st);

                nf = sum(F & sm);
                nc = sum(captured & sm);
                nr = sum(residual & sm);

                if nf>0
                    residual_given_fail_state = nr/nf;
                else
                    residual_given_fail_state = NaN;
                end

                if nres>0
                    resid_share = nr/nres;
                else
                    resid_share = NaN;
                end

                if total_fail>0
                    allfail_share = nf/total_fail;
                else
                    allfail_share = NaN;
                end

                if isfinite(allfail_share) && allfail_share>0
                    enrichment = resid_share/allfail_share;
                else
                    enrichment = NaN;
                end

                rp=rp+1;
                phys_rows(rp,:) = { ...
                    cfg.primary_source, ap, b, string(vname), ...
                    state_to_string(st), ...
                    sum(sm), nf, nc, nr, ...
                    residual_given_fail_state, ...
                    allfail_share, resid_share, enrichment}; %#ok<AGROW>
            end
        end

        % -------------------------------------------------------------
        % Reconstruction audit against formal B1 G5 and G6
        % -------------------------------------------------------------
        a1 = audit_against_b1(B1, ap, b, "G5_RefinedLR", ...
            slr, sum(residual), cfg);
        ra=ra+1;
        audit_rows(ra,:) = a1;

        a2 = audit_against_b1(B1, ap, b, "G6_All3_MaxRank", ...
            sall, sum(F & ~Tall), cfg);
        ra=ra+1;
        audit_rows(ra,:) = a2;
    end
end

%% 4. Export tables
S = cell2table(summary_rows,'VariableNames',{ ...
    'source','aperture_mode','g5_nominal_budget', ...
    'g5_actual_trigger_fraction','g5_selected_count', ...
    'g0_failure_count','g5_captured_failure_count', ...
    'g5_residual_failure_count','g5_failure_capture_fraction', ...
    'g5_residual_fraction_of_failures','g5_residual_wilson_lo', ...
    'g5_residual_wilson_hi','g5_untriggered_pool_count', ...
    'failure_prevalence_in_untriggered_pool'});

R = cell2table(screen_rows,'VariableNames',{ ...
    'source','aperture_mode','g5_nominal_budget','cost0_signal', ...
    'auc_within_g5_untriggered_pool','residual_screen_nominal_budget', ...
    'residual_screen_actual_fraction_of_pool', ...
    'extra_trigger_fraction_of_all_trials','selected_count', ...
    'residual_failures_selected','residual_failure_count', ...
    'conditional_residual_capture','capture_wilson_lo','capture_wilson_hi', ...
    'selected_failure_count','screen_precision', ...
    'precision_wilson_lo','precision_wilson_hi'});

P = cell2table(disp_rows,'VariableNames',{ ...
    'source','aperture_mode','nominal_budget', ...
    'g5_actual_trigger_fraction','g6_actual_trigger_fraction', ...
    'g5_failure_capture_count','g6_failure_capture_count', ...
    'overlap_failure_count','g5_caught_g6_lost_failure_count', ...
    'g5_missed_g6_gained_failure_count', ...
    'net_g6_minus_g5_failure_capture', ...
    'g6_promoted_nonfailure_count','g6_demoted_nonfailure_count', ...
    'trigger_intersection_count','trigger_union_count'});

H = cell2table(phys_rows,'VariableNames',{ ...
    'source','aperture_mode','g5_nominal_budget','physical_variable', ...
    'state_value','trial_count_state','g0_failure_count_state', ...
    'g5_captured_failure_count_state','g5_residual_failure_count_state', ...
    'residual_fraction_given_failure_state','all_failure_share', ...
    'residual_failure_share','residual_enrichment_ratio'});

T = cell2table(trial_rows,'VariableNames',{ ...
    'source','aperture_mode','g5_nominal_budget','trial_id', ...
    'g0_failure','g5_trigger','g6_trigger','g5_captured_failure', ...
    'g5_residual_failure','fivebin_peak_fraction','local_entropy5', ...
    'refined_lr_asymmetry','relative_phase_rad','Gamma_PA4', ...
    'true_eta_bins','weak_to_strong_ratio','delta_velocity_mps', ...
    'strong_velocity_side'});

A = cell2table(audit_rows,'VariableNames',{ ...
    'source','aperture_mode','nominal_budget','policy', ...
    'reconstructed_selected_count','b1_selected_count', ...
    'selected_count_match','reconstructed_actual_trigger_fraction', ...
    'b1_actual_trigger_fraction','actual_trigger_match', ...
    'reconstructed_missed_g0_failure_count', ...
    'b1_missed_g0_failure_count','missed_failure_match', ...
    'b1_persistent_after_fallback_count'});

writetable(S,fullfile(cfg.output_dir,"pa5jb2_residual_summary.csv"));
writetable(R,fullfile(cfg.output_dir,"pa5jb2_residual_cost0_screen.csv"));
writetable(P,fullfile(cfg.output_dir,"pa5jb2_policy_displacement.csv"));
writetable(H,fullfile(cfg.output_dir,"pa5jb2_physical_anatomy.csv"));
writetable(T,fullfile(cfg.output_dir,"pa5jb2_trial_membership.csv"));
writetable(A,fullfile(cfg.output_dir,"pa5jb2_reconstruction_audit.csv"));

%% 5. Smoke tests
Smoke = build_smoke_tests(D,S,R,P,A,cfg);
writetable(Smoke,fullfile(cfg.output_dir,"pa5jb2_smoke_test.csv"));
assert(all(Smoke.pass), ...
    'PA5J-B2 smoke test failed. Do not interpret formal results.');

%% 6. Figures
make_summary_figures(S,R,P,cfg);
make_physics_heatmaps(D,T,cfg);

%% 7. Factual summary only
write_summary(D,S,R,P,A,Smoke,cfg,p_dense,p_b1);

fprintf('\nPA5J-B2 formal run completed.\n');
fprintf('Output: %s\n',cfg.output_dir);
fprintf('No automatic research-branch interpretation was performed.\n');

end

%% =========================================================================
% Reconstruction audit
% =========================================================================
function row = audit_against_b1(B1,ap,b,policy,sel,missed_fail,cfg)
Q = B1(string(B1.source)==cfg.primary_source & ...
       string(B1.aperture_mode)==ap & ...
       string(B1.policy)==policy & ...
       abs(double(B1.nominal_budget)-b)<=cfg.audit_tol,:);
assert(height(Q)==1, ...
    'Expected one B1 row for %s / %.3f / %s.',ap,b,policy);

count_match = sel.selected_count == Q.selected_count(1);
frac_match = abs(sel.actual_fraction-Q.actual_trigger_fraction(1)) ...
    <= cfg.audit_tol;
miss_match = missed_fail == Q.missed_g0_failure_count(1);

assert(count_match && frac_match && miss_match, ...
    'B2 reconstruction differs from B1 for %s / %.3f / %s.',ap,b,policy);

row = {cfg.primary_source,ap,b,policy, ...
    sel.selected_count,Q.selected_count(1),count_match, ...
    sel.actual_fraction,Q.actual_trigger_fraction(1),frac_match, ...
    missed_fail,Q.missed_g0_failure_count(1),miss_match, ...
    Q.persistent_after_fallback_count(1)};
end

%% =========================================================================
% Figures
% =========================================================================
function make_summary_figures(S,R,P,cfg)

% Fig 1: G5 residual fraction vs anchor budget
fig=figure('Visible','off','Color','w');
hold on; grid on; box on;
for ia=1:numel(cfg.aperture_modes)
    ap=cfg.aperture_modes(ia);
    Q=S(string(S.aperture_mode)==ap,:);
    plot(Q.g5_actual_trigger_fraction,Q.g5_residual_fraction_of_failures, ...
        '-o','LineWidth',1.3,'DisplayName',ap);
end
xlabel('G5 actual trigger fraction');
ylabel('Residual fraction of G0 failures');
title('PA5J-B2: Refined-LR residual failure tail');
legend('Location','best','Interpreter','none');
exportgraphics(fig,fullfile(cfg.figure_dir, ...
    "fig01_g5_residual_fraction.png"),'Resolution',180);
close(fig);

% Fig 2: residual-pool Cost-0 AUC
for ia=1:numel(cfg.aperture_modes)
    ap=cfg.aperture_modes(ia);
    Q=R(string(R.aperture_mode)==ap,:);
    % AUC is repeated across screen budgets; keep one row per anchor/signal.
    [~,ix]=unique(string(Q.g5_nominal_budget)+"|"+string(Q.cost0_signal),'stable');
    Q=Q(ix,:);

    fig=figure('Visible','off','Color','w');
    hold on; grid on; box on;
    sigs=unique(string(Q.cost0_signal),'stable');
    for is=1:numel(sigs)
        Z=Q(string(Q.cost0_signal)==sigs(is),:);
        [x,ord]=sort(Z.g5_nominal_budget);
        plot(x,Z.auc_within_g5_untriggered_pool(ord), ...
            '-o','LineWidth',1.3,'DisplayName',sigs(is));
    end
    yline(0.5,'--','Chance');
    xlabel('G5 nominal budget');
    ylabel('AUC inside G5-untriggered pool');
    title(sprintf('%s: residual Cost-0 discriminability',ap),'Interpreter','none');
    legend('Location','best','Interpreter','none');
    exportgraphics(fig,fullfile(cfg.figure_dir, ...
        "fig02_residual_auc_"+ap+".png"),'Resolution',180);
    close(fig);
end

% Fig 3: G6-vs-G5 displacement
for ia=1:numel(cfg.aperture_modes)
    ap=cfg.aperture_modes(ia);
    Q=P(string(P.aperture_mode)==ap,:);
    fig=figure('Visible','off','Color','w');
    hold on; grid on; box on;
    plot(Q.nominal_budget,Q.g5_caught_g6_lost_failure_count, ...
        '-o','LineWidth',1.3,'DisplayName','G5-caught / G6-lost');
    plot(Q.nominal_budget,Q.g5_missed_g6_gained_failure_count, ...
        '-s','LineWidth',1.3,'DisplayName','G5-missed / G6-gained');
    yline(0,'--');
    xlabel('Nominal budget');
    ylabel('Failure count');
    title(sprintf('%s: All3 rank displacement vs Refined-LR',ap), ...
        'Interpreter','none');
    legend('Location','best','Interpreter','none');
    exportgraphics(fig,fullfile(cfg.figure_dir, ...
        "fig03_g6_vs_g5_displacement_"+ap+".png"),'Resolution',180);
    close(fig);
end

end

function make_physics_heatmaps(D,T,cfg)
% Primary mechanism heatmaps at the two central anchors.
heat_budgets=[0.20,0.30];

for ia=1:numel(cfg.aperture_modes)
    ap=cfg.aperture_modes(ia);
    G=D(string(D.aperture_mode)==ap,:);
    phases=sort(unique(double(G.relative_phase_rad)));
    etas=sort(unique(double(G.true_eta_bins)));
    gammas=sort(unique(double(G.Gamma_PA4)));

    for ib=1:numel(heat_budgets)
        b=heat_budgets(ib);
        Q=T(string(T.aperture_mode)==ap & ...
            abs(double(T.g5_nominal_budget)-b)<1e-12,:);

        M_eta=nan(numel(phases),numel(etas));
        M_gamma=nan(numel(phases),numel(gammas));

        for ip=1:numel(phases)
            for ie=1:numel(etas)
                idx=abs(double(Q.relative_phase_rad)-phases(ip))<1e-12 & ...
                    abs(double(Q.true_eta_bins)-etas(ie))<1e-12 & ...
                    Q.g0_failure==1;
                if any(idx)
                    M_eta(ip,ie)=mean(Q.g5_residual_failure(idx));
                end
            end
            for ig=1:numel(gammas)
                idx=abs(double(Q.relative_phase_rad)-phases(ip))<1e-12 & ...
                    abs(double(Q.Gamma_PA4)-gammas(ig))<1e-12 & ...
                    Q.g0_failure==1;
                if any(idx)
                    M_gamma(ip,ig)=mean(Q.g5_residual_failure(idx));
                end
            end
        end

        fig=figure('Visible','off','Color','w');
        tiledlayout(1,2,'Padding','compact','TileSpacing','compact');

        nexttile;
        imagesc(etas,phases,M_eta);
        axis xy; colorbar; caxis([0 1]);
        xlabel('\eta (bin)');
        ylabel('Relative phase (rad)');
        title('P(residual | G0 failure, phase, \eta)');

        nexttile;
        imagesc(gammas,phases,M_gamma);
        axis xy; colorbar; caxis([0 1]);
        xlabel('\Gamma_{PA4}');
        ylabel('Relative phase (rad)');
        title('P(residual | G0 failure, phase, \Gamma)');

        sgtitle(sprintf('%s / G5 budget %.2f',ap,b),'Interpreter','none');
        exportgraphics(fig,fullfile(cfg.figure_dir, ...
            sprintf("fig04_physics_%s_b%02d.png",ap,round(100*b))), ...
            'Resolution',180);
        close(fig);
    end
end
end

%% =========================================================================
% Smoke tests
% =========================================================================
function S=build_smoke_tests(D,Sum,Res,Disp,Audit,cfg)
name=strings(0,1); pass=false(0,1); detail=strings(0,1);

[name,pass,detail]=add_test(name,pass,detail, ...
    "dense_trial_id_unique", ...
    numel(unique(D.trial_id))==height(D), ...
    sprintf('%d / %d unique',numel(unique(D.trial_id)),height(D)));

expected_sum=numel(cfg.aperture_modes)*numel(cfg.anchor_budgets);
[name,pass,detail]=add_test(name,pass,detail, ...
    "residual_summary_row_count",height(Sum)==expected_sum, ...
    sprintf('%d / %d rows',height(Sum),expected_sum));

expected_res=expected_sum*3*numel(cfg.residual_screen_budgets);
[name,pass,detail]=add_test(name,pass,detail, ...
    "residual_screen_row_count",height(Res)==expected_res, ...
    sprintf('%d / %d rows',height(Res),expected_res));

[name,pass,detail]=add_test(name,pass,detail, ...
    "b1_reconstruction_all_pass", ...
    all(Audit.selected_count_match) && ...
    all(Audit.actual_trigger_match) && ...
    all(Audit.missed_failure_match), ...
    sprintf('%d audit rows checked',height(Audit)));

[name,pass,detail]=add_test(name,pass,detail, ...
    "residual_partition_identity", ...
    all(Sum.g5_captured_failure_count+Sum.g5_residual_failure_count ...
        == Sum.g0_failure_count), ...
    'captured + residual == G0 failure count');

[name,pass,detail]=add_test(name,pass,detail, ...
    "displacement_count_identity", ...
    all(Disp.g6_failure_capture_count-Disp.g5_failure_capture_count ...
        == Disp.net_g6_minus_g5_failure_capture), ...
    'G6-G5 capture difference == gained-lost');

ok_auc=all(isnan(Res.auc_within_g5_untriggered_pool) | ...
    (Res.auc_within_g5_untriggered_pool>=0 & ...
     Res.auc_within_g5_untriggered_pool<=1));
[name,pass,detail]=add_test(name,pass,detail, ...
    "auc_range",ok_auc,'All finite AUC values in [0,1].');

S=table(name,pass,detail);
end

function [name,pass,detail]=add_test(name,pass,detail,nm,ok,dt)
name(end+1,1)=string(nm);
pass(end+1,1)=logical(ok);
detail(end+1,1)=string(dt);
end

%% =========================================================================
% Factual summary
% =========================================================================
function write_summary(D,S,R,P,A,Smoke,cfg,p_dense,p_b1)
f=fopen(fullfile(cfg.output_dir,"PA5JB2_FORMAL_METRIC_SUMMARY.txt"),'w');
assert(f>0,'Cannot open PA5J-B2 summary.');
c=onCleanup(@() fclose(f)); %#ok<NASGU>

fprintf(f,'EXP009 / PA5J-B2 formal metric export\n');
fprintf(f,'No automatic research-branch interpretation.\n\n');
fprintf(f,'Input dense trials: %s\n',p_dense);
fprintf(f,'Input B1 sweep: %s\n',p_b1);
fprintf(f,'Dense trials: %d; unique trial_id: %d\n', ...
    height(D),numel(unique(D.trial_id)));
fprintf(f,'All smoke tests pass: %d\n',all(Smoke.pass));
fprintf(f,'B1 reconstruction audit rows: %d; all pass: %d\n\n', ...
    height(A), ...
    all(A.selected_count_match & A.actual_trigger_match & ...
        A.missed_failure_match));

fprintf(f,'G5 residual summary:\n');
for i=1:height(S)
    fprintf(f,'  %s / b=%.2f: actual=%.6f, failures=%d, captured=%d, residual=%d, residual fraction=%.6f\n', ...
        string(S.aperture_mode(i)),S.g5_nominal_budget(i), ...
        S.g5_actual_trigger_fraction(i),S.g0_failure_count(i), ...
        S.g5_captured_failure_count(i),S.g5_residual_failure_count(i), ...
        S.g5_residual_fraction_of_failures(i));
end

fprintf(f,'\nResidual-pool Cost-0 AUC (one value per G5 anchor):\n');
for ia=1:numel(cfg.aperture_modes)
    ap=cfg.aperture_modes(ia);
    for ib=1:numel(cfg.anchor_budgets)
        b=cfg.anchor_budgets(ib);
        Q=R(string(R.aperture_mode)==ap & ...
            abs(double(R.g5_nominal_budget)-b)<1e-12,:);
        sigs=unique(string(Q.cost0_signal),'stable');
        fprintf(f,'  %s / b=%.2f:',ap,b);
        for is=1:numel(sigs)
            z=Q(string(Q.cost0_signal)==sigs(is),:);
            fprintf(f,' %s=%.6f;',sigs(is),z.auc_within_g5_untriggered_pool(1));
        end
        fprintf(f,'\n');
    end
end

fprintf(f,'\nG6-vs-G5 failure displacement:\n');
for i=1:height(P)
    fprintf(f,'  %s / b=%.2f: G5cap=%d, G6cap=%d, lost=%d, gained=%d, net=%d\n', ...
        string(P.aperture_mode(i)),P.nominal_budget(i), ...
        P.g5_failure_capture_count(i),P.g6_failure_capture_count(i), ...
        P.g5_caught_g6_lost_failure_count(i), ...
        P.g5_missed_g6_gained_failure_count(i), ...
        P.net_g6_minus_g5_failure_capture(i));
end

fprintf(f,'\nTruth physics were exported only for post-hoc anatomy.\n');
fprintf(f,'No truth physics entered a gate score or cutoff.\n');
fprintf(f,'No operating point was selected.\n');
end

%% =========================================================================
% Statistics / selection
% =========================================================================
function auc=binary_auc(score,label)
score=double(score(:));
label=logical(label(:));
assert(numel(score)==numel(label),'AUC length mismatch.');
ok=isfinite(score);
score=score(ok); label=label(ok);

np=sum(label); nn=sum(~label);
if np==0 || nn==0
    auc=NaN;
    return;
end

r=midranks(score);
auc=(sum(r(label))-np*(np+1)/2)/(np*nn);
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

function p=risk_percentile(score)
score=double(score(:));
assert(all(isfinite(score)),'Non-finite risk score.');
n=numel(score);
if n==1
    p=1;
    return;
end
r=midranks(score);
p=(r-1)/(n-1);
end

function [mask,s]=tie_inclusive_top(score,b)
score=double(score(:));
n=numel(score);
assert(all(isfinite(score)),'Non-finite policy score.');
assert(b>=0 && b<=1,'Budget outside [0,1].');

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

%% =========================================================================
% Physical state helpers
% =========================================================================
function states=unique_state_values(x)
if isnumeric(x) || islogical(x)
    u=unique(double(x));
    states=num2cell(u(:));
else
    u=unique(string(x),'stable');
    states=num2cell(u(:));
end
end

function m=state_mask(x,st)
% Defensive guard: tolerate a scalar cell if this helper is reused later.
if iscell(st)
    assert(numel(st)==1,'state_mask expects a scalar state.');
    st=st{1};
end
if isnumeric(x) || islogical(x)
    v=double(st);
    m=abs(double(x)-v)<1e-12;
else
    m=string(x)==string(st);
end
end

function s=state_to_string(st)
% Defensive guard: tolerate a scalar cell if this helper is reused later.
if iscell(st)
    assert(numel(st)==1,'state_to_string expects a scalar state.');
    st=st{1};
end
if isnumeric(st) || islogical(st)
    s=string(sprintf('%.12g',double(st)));
else
    s=string(st);
end
end

%% =========================================================================
% Provenance / IO
% =========================================================================
function write_provenance(cfg,p_dense,p_b1)
key = [ ...
    "experiment_id"; ...
    "research_role"; ...
    "primary_source"; ...
    "aperture_modes"; ...
    "anchor_budgets"; ...
    "primary_anchor_budgets"; ...
    "residual_screen_budgets"; ...
    "fivebin_risk_direction"; ...
    "entropy_risk_direction"; ...
    "refined_lr_risk_direction"; ...
    "input_dense"; ...
    "input_b1_sweep"; ...
    "truth_physics_role"; ...
    "selection_rule"];

value = [ ...
    cfg.experiment_id; ...
    "Residual-failure / policy-crossover anatomy"; ...
    cfg.primary_source; ...
    strjoin(cfg.aperture_modes,","); ...
    numvec_string(cfg.anchor_budgets); ...
    numvec_string(cfg.primary_anchor_budgets); ...
    numvec_string(cfg.residual_screen_budgets); ...
    cfg.fivebin_direction; ...
    cfg.entropy_direction; ...
    cfg.refined_lr_direction; ...
    string(p_dense); ...
    string(p_b1); ...
    "post-hoc interpretation only; forbidden in gate"; ...
    "tie-inclusive; no trial-id tie break"];

source = [ ...
    "Frozen PA5J-B2 design"; ...
    "B1 result interpretation"; ...
    "B1 dense-risk stress-test scope"; ...
    "PA5J-B1"; ...
    "Pre-registered B2 anchors"; ...
    "Primary low/mid-budget anchors"; ...
    "Residual information audit"; ...
    "PA5J-A/B0/B1"; ...
    "PA5J-A/B0/B1"; ...
    "PA5J-A/B0/B1"; ...
    "Canonical upstream artifact"; ...
    "Canonical upstream artifact"; ...
    "Research-layer constraint"; ...
    "PA5J-B0/B1 engineering rule"];

T=table(key,value,source);
writetable(T,fullfile(cfg.output_dir,"PARAMETER_PROVENANCE_PA5JB2.csv"));
end

function s=numvec_string(x)
s="[" + strjoin(compose('%.6g',x),",") + "]";
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
