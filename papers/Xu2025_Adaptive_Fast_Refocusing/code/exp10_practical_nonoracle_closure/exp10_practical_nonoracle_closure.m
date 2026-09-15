function results = exp09_practical_nonoracle_closure()
%EXP10_PRACTICAL_NONORACLE_CLOSURE
% EXP010 — Noiseless Practical Non-Oracle Sequential Closure
%
% PRIMARY QUESTION
% ----------------
% After freezing the PA5J staged reliability policy, can the whole chain
%
%   observed mixture
%     -> fixed-domain practical strong-beta search
%     -> G0 reliability state
%     -> Refined-LR 20% + FiveBin 10% conditional scheduler
%     -> optional Neighbor-3
%     -> practical recentering
%     -> frozen 3-bin Wang-style removal
%     -> global practical weak-beta search
%
% run without reading truth quantities inside the Proposed method?
%
% DEFAULT STATUS
% --------------
% This file defaults to a SMOKE integration test. It is not paper-ready
% evidence until the smoke test passes and cfg.run_mode is deliberately
% changed to "formal" in the config.

cfg = config_exp10_practical_nonoracle_closure();

fprintf('\n============================================================\n');
fprintf('EXP010 Practical Non-Oracle Closure — %s\n', upper(cfg.run_mode));
fprintf('============================================================\n');
fprintf('Noise / clutter: OFF\n');
fprintf('Primary policy: Refined-LR b1=%.2f -> FiveBin b2=%.2f -> N3\n', ...
    cfg.stage1_budget,cfg.stage2_conditional_budget);
fprintf('Removal width: %d bins (FROZEN)\n',cfg.removal_window_bins);
fprintf('SNR definition: PENDING-DEFINITION; not used here.\n\n');

ensure_output_dirs(cfg);
run_startup_self_tests(cfg);

% Truth is intentionally created outside the practical method.
truth_all = table();
online_all = table();
eval_all = table();

apertures = ["Paper1s","BeamDerived"];

for ia = 1:numel(apertures)
    mode = apertures(ia);
    proc = build_processing_context(mode,cfg);

    fprintf('--- %s: N=%d, beta-grid=%d, maxLag=%d ---\n', ...
        mode,proc.N,numel(proc.beta_grid),proc.max_lag);

    truth = build_truth_table(mode,proc,cfg);
    X = synthesize_observed_batch(truth,proc,cfg);

    % CRITICAL FIREWALL:
    % practical_batch_method receives observed X + processing config only.
    online = practical_batch_method(X,proc,cfg);

    % Truth / global-reference / oracle quantities are introduced only here.
    Eval = evaluate_with_truth(X,truth,online,proc,cfg);

    truth_all = [truth_all; truth]; %#ok<AGROW>
    online_all = [online_all; online]; %#ok<AGROW>
    eval_all = [eval_all; Eval]; %#ok<AGROW>
end

summary = summarize_methods(eval_all,cfg);
paired = summarize_paired(eval_all,cfg);
firewall = oracle_firewall_audit(online_all,eval_all,cfg);

writetable(truth_all,fullfile(cfg.output_dir,'truth_metadata.csv'));
writetable(online_all,fullfile(cfg.output_dir,'practical_online_outputs.csv'));
writetable(eval_all,fullfile(cfg.output_dir,'evaluation_trials.csv'));
writetable(summary,fullfile(cfg.output_dir,'method_summary.csv'));
writetable(paired,fullfile(cfg.output_dir,'paired_outcome_summary.csv'));
writetable(firewall,fullfile(cfg.output_dir,'oracle_firewall_audit.csv'));

write_text_summary(cfg,summary,paired,firewall,eval_all);
make_figures(eval_all,summary,cfg);

results = struct();
results.cfg = cfg;
results.truth = truth_all;
results.online = online_all;
results.evaluation = eval_all;
results.summary = summary;
results.paired = paired;
results.firewall = firewall;

fprintf('\nOutputs saved to:\n%s\n',cfg.output_dir);
fprintf('ORACLE_FIREWALL = %s\n',string(firewall.overall_pass(1)));

if cfg.oracle_firewall_required && ~firewall.overall_pass(1)
    error('EXP009:PracticalClosure:OracleFirewallFailed', ...
        'Oracle firewall audit failed. Do not interpret this run.');
end

end

%% =========================================================================
function ensure_output_dirs(cfg)
if ~exist(cfg.output_dir,'dir'), mkdir(cfg.output_dir); end
if ~exist(cfg.figure_dir,'dir'), mkdir(cfg.figure_dir); end
end

%% =========================================================================
function proc = build_processing_context(mode,cfg)
lambda = cfg.c/cfg.fc_hz;
R0 = cfg.platform_height_m*cfg.slant_range_factor;

if mode=="Paper1s"
    N = max(32,round(cfg.prf_hz*cfg.paper_aperture_time_s));
    Wbeta = cfg.pa4_beta_width_paper_rad;
elseif mode=="BeamDerived"
    beamwidth_rad = cfg.beamwidth_scale*lambda/cfg.antenna_length_m;
    Tbeam = R0*beamwidth_rad/cfg.platform_velocity_mps;
    N = max(32,round(cfg.prf_hz*Tbeam));
    Wbeta = cfg.pa4_beta_width_beam_rad;
else
    error('Unknown aperture mode: %s',mode);
end

[~,~,K1] = residual_fm_rates(cfg.search_velocity_min_mps,R0,lambda,cfg);
[~,~,K2] = residual_fm_rates(cfg.search_velocity_max_mps,R0,lambda,cfg);

b1 = atan(K1/(cfg.prf_hz^2));
b2 = atan(K2/(cfg.prf_hz^2));
lo = min(b1,b2)-cfg.beta_search_margin_widths*Wbeta;
hi = max(b1,b2)+cfg.beta_search_margin_widths*Wbeta;
step = Wbeta*cfg.beta_search_step_width_fraction;

nBeta = ceil((hi-lo)/step)+1;
beta_grid = linspace(lo,hi,nBeta).';

proc = struct();
proc.aperture_mode = mode;
proc.N = N;
proc.Wbeta = Wbeta;
proc.R0 = R0;
proc.lambda = lambda;
proc.max_lag = max(1,min(N-2,round(cfg.max_lag_fraction*N)));
proc.beta_grid = beta_grid;
proc.beta_search_lo = lo;
proc.beta_search_hi = hi;
proc.beta_search_step = median(diff(beta_grid));
end

%% =========================================================================
function T = build_truth_table(mode,proc,cfg)
% Simulation-only metadata. This table is NEVER passed into the Proposed
% practical method.

if lower(cfg.run_mode)=="smoke"
    dV = cfg.smoke_delta_velocity_mps;
    rList = cfg.smoke_weak_to_strong_ratio;
    pList = cfg.smoke_relative_phase_rad;
    eList = cfg.smoke_fractional_bin_offsets;
elseif lower(cfg.run_mode)=="formal"
    dV = cfg.full_delta_velocity_mps;
    rList = cfg.full_weak_to_strong_ratio;
    pList = cfg.full_relative_phase_rad;
    eList = cfg.full_fractional_bin_offsets;
else
    error('Unknown run_mode: %s',cfg.run_mode);
end

sides = ["LowV","HighV"];
rows = {};
id = 0;

[~,~,Kw] = residual_fm_rates( ...
    cfg.weak_velocity_mps,proc.R0,proc.lambda,cfg);
aw = Kw/(cfg.prf_hz^2);
beta_w = atan(aw);

for idv=1:numel(dV)
    dv=dV(idv);
    for is=1:numel(sides)
        side=sides(is);
        if side=="LowV"
            vs=cfg.weak_velocity_mps-dv;
        else
            vs=cfg.weak_velocity_mps+dv;
        end
        [~,~,Ks] = residual_fm_rates(vs,proc.R0,proc.lambda,cfg);
        as=Ks/(cfg.prf_hz^2);
        beta_s=atan(as);
        Gamma=abs(beta_s-beta_w)/proc.Wbeta;

        for ir=1:numel(rList)
            rA=rList(ir);
            for ip=1:numel(pList)
                phi=pList(ip);
                for ie=1:numel(eList)
                    eta=eList(ie);
                    id=id+1;
                    rows(end+1,:)={ ... %#ok<AGROW>
                        id,char(mode),proc.N,dv,char(side),vs, ...
                        cfg.weak_velocity_mps,rA,phi,eta, ...
                        as,aw,beta_s,beta_w,Gamma};
                end
            end
        end
    end
end

T=cell2table(rows,'VariableNames',{ ...
    'trial_id','aperture_mode','azimuth_samples', ...
    'delta_velocity_mps','strong_velocity_side','strong_velocity_mps', ...
    'weak_velocity_mps','weak_to_strong_ratio','relative_phase_rad', ...
    'true_eta_bins','true_a_strong','true_a_weak', ...
    'truth_beta_s_rad','truth_beta_w_rad','truth_Gamma'});
end

%% =========================================================================
function X = synthesize_observed_batch(T,proc,cfg)
n=height(T);
X=complex(zeros(n,proc.N));
for i=1:n
    eta=T.true_eta_bins(i);
    b=eta/proc.N;
    s=synth_discrete_lfm(proc.N,1,T.true_a_strong(i),b,0);
    w=synth_discrete_lfm(proc.N,T.weak_to_strong_ratio(i), ...
        T.true_a_weak(i),b,T.relative_phase_rad(i));
    X(i,:)=s+w;
end
end

%% =========================================================================
function O = practical_batch_method(X,proc,cfg)
%PRACTICAL_BATCH_METHOD
% IMPORTANT: no truth table is in this function signature.
% Inputs are observed samples X and fixed processing configuration only.

n=size(X,1);

beta_hat=nan(n,1);
beta_score=nan(n,1);
g0_nu=nan(n,1);
g0_obj=nan(n,1);
g0_evals=nan(n,1);
coarse_seed=nan(n,1);
fivebin=nan(n,1);
refined_lr=nan(n,1);

for i=1:n
    x=X(i,:);
    [beta_hat(i),beta_score(i)] = estimate_beta_fixed_domain(x,proc,cfg);
    a_hat=tan(beta_hat(i));
    G=g0_with_risk_state(x,a_hat,cfg);
    g0_nu(i)=G.nu_hat_bins;
    g0_obj(i)=G.objective_at_hat;
    g0_evals(i)=G.n_objective_evals;
    coarse_seed(i)=G.coarse_seed_primary;
    fivebin(i)=G.fivebin_peak_fraction;
    refined_lr(i)=G.refined_lr_asymmetry;
end

% Natural batch = all processing units under the same known aperture
% configuration. No split by truth eta/Gamma/contrast/phase/SNR.
[stage1,sel1] = tie_inclusive_top(refined_lr,cfg.stage1_budget);
remaining=~stage1;
stage2=false(n,1);

if any(remaining)
    risk2=-fivebin(remaining); % low raw FiveBin -> high risk
    [m2,sel2] = tie_inclusive_top(risk2,cfg.stage2_conditional_budget);
    idx=find(remaining);
    stage2(idx(m2))=true;
else
    sel2=empty_selection();
end
trigger=stage1|stage2;

n3_nu=nan(n,1);
n3_obj=nan(n,1);
n3_evals=nan(n,1);
final_nu=nan(n,1);
final_obj=nan(n,1);
final_evals=nan(n,1);

Ahat_g0=nan(n,1); Phat_g0=nan(n,1);
Ahat_prop=nan(n,1); Phat_prop=nan(n,1);
Ahat_n3=nan(n,1); Phat_n3=nan(n,1);

weak_beta_g0=nan(n,1); weak_beta_prop=nan(n,1); weak_beta_n3=nan(n,1);
residual_norm_g0=nan(n,1); residual_norm_prop=nan(n,1); residual_norm_n3=nan(n,1);
mask_frac_g0=nan(n,1); mask_frac_prop=nan(n,1); mask_frac_n3=nan(n,1);

for i=1:n
    x=X(i,:);
    a_hat=tan(beta_hat(i));

    % Always-N3 comparator. Candidate branches are adjacency-only.
    G3=estimate_neighbor3(x,a_hat,cfg);
    n3_nu(i)=G3.nu_hat_bins;
    n3_obj(i)=G3.objective_at_hat;
    n3_evals(i)=G3.n_objective_evals;

    if trigger(i)
        final_nu(i)=n3_nu(i);
        final_obj(i)=n3_obj(i);
        final_evals(i)=g0_evals(i)+cfg.refined_lr_extra_evals + ...
            (n3_evals(i)-g0_evals(i));
    else
        final_nu(i)=g0_nu(i);
        final_obj(i)=g0_obj(i);
        final_evals(i)=g0_evals(i)+cfg.refined_lr_extra_evals;
    end

    % Practical complex-amplitude / phase estimates. These are not used by
    % the primary notch-removal operator; they close the Oracle Ledger and
    % are retained for audit / future reconstruction comparisons.
    [Ahat_g0(i),Phat_g0(i)] = estimate_amp_phase_ls(x,a_hat,g0_nu(i));
    [Ahat_prop(i),Phat_prop(i)] = estimate_amp_phase_ls(x,a_hat,final_nu(i));
    [Ahat_n3(i),Phat_n3(i)] = estimate_amp_phase_ls(x,a_hat,n3_nu(i));

    [r0,info0]=practical_recenter_notch_remove( ...
        x,a_hat,g0_nu(i),cfg.removal_window_bins,cfg);
    [rp,infop]=practical_recenter_notch_remove( ...
        x,a_hat,final_nu(i),cfg.removal_window_bins,cfg);
    [r3,info3]=practical_recenter_notch_remove( ...
        x,a_hat,n3_nu(i),cfg.removal_window_bins,cfg);

    residual_norm_g0(i)=norm(r0)/max(norm(x),cfg.small_norm_floor);
    residual_norm_prop(i)=norm(rp)/max(norm(x),cfg.small_norm_floor);
    residual_norm_n3(i)=norm(r3)/max(norm(x),cfg.small_norm_floor);
    mask_frac_g0(i)=info0.mask_fraction;
    mask_frac_prop(i)=infop.mask_fraction;
    mask_frac_n3(i)=info3.mask_fraction;

    weak_beta_g0(i)=estimate_beta_fixed_domain(r0,proc,cfg);
    weak_beta_prop(i)=estimate_beta_fixed_domain(rp,proc,cfg);
    weak_beta_n3(i)=estimate_beta_fixed_domain(r3,proc,cfg);
end

O=table();
O.trial_id=(1:n).';
O.aperture_mode=repmat(string(proc.aperture_mode),n,1);
O.beta_hat_strong_rad=beta_hat;
O.beta_search_score=beta_score;
O.g0_coarse_seed_bins=coarse_seed;
O.g0_nu_hat_bins=g0_nu;
O.g0_objective=g0_obj;
O.g0_objective_evals=g0_evals;
O.fivebin_peak_fraction=fivebin;
O.refined_lr_asymmetry=refined_lr;
O.stage1_trigger=stage1;
O.stage2_trigger=stage2;
O.fallback_trigger=trigger;
O.stage1_actual_fraction=repmat(sel1.actual_fraction,n,1);
O.stage2_actual_fraction=repmat(sel2.actual_fraction,n,1);
O.n3_nu_hat_bins=n3_nu;
O.n3_objective=n3_obj;
O.n3_objective_evals=n3_evals;
O.proposed_nu_hat_bins=final_nu;
O.proposed_objective=final_obj;
O.proposed_branch_objective_evals=final_evals;
O.g0_Ahat=Ahat_g0; O.g0_phihat_rad=Phat_g0;
O.proposed_Ahat=Ahat_prop; O.proposed_phihat_rad=Phat_prop;
O.n3_Ahat=Ahat_n3; O.n3_phihat_rad=Phat_n3;
O.g0_weak_beta_hat_rad=weak_beta_g0;
O.proposed_weak_beta_hat_rad=weak_beta_prop;
O.n3_weak_beta_hat_rad=weak_beta_n3;
O.g0_residual_norm_ratio=residual_norm_g0;
O.proposed_residual_norm_ratio=residual_norm_prop;
O.n3_residual_norm_ratio=residual_norm_n3;
O.g0_mask_fraction=mask_frac_g0;
O.proposed_mask_fraction=mask_frac_prop;
O.n3_mask_fraction=mask_frac_n3;
end

%% =========================================================================
function E = evaluate_with_truth(X,T,O,proc,cfg)
% Truth/reference layer. This function may use truth. Proposed decisions
% have already been completed before entering here.

n=height(T);
methods=["G0_OriginalTop1","Proposed_Frozen_Staged","Always_Neighbor3"];
rows={};

for i=1:n
    x=X(i,:);
    a_hat=tan(O.beta_hat_strong_rad(i));

    % Evaluation-only global continuous-frequency reference under the SAME
    % practical beta_hat. It never feeds back into the practical chain.
    Gref=estimate_global_reference(x,a_hat,cfg);

    eta_vec=[O.g0_nu_hat_bins(i),O.proposed_nu_hat_bins(i),O.n3_nu_hat_bins(i)];
    eval_vec=[O.g0_objective_evals(i),O.proposed_branch_objective_evals(i),O.n3_objective_evals(i)];
    A_vec=[O.g0_Ahat(i),O.proposed_Ahat(i),O.n3_Ahat(i)];
    P_vec=[O.g0_phihat_rad(i),O.proposed_phihat_rad(i),O.n3_phihat_rad(i)];
    bw_vec=[O.g0_weak_beta_hat_rad(i),O.proposed_weak_beta_hat_rad(i),O.n3_weak_beta_hat_rad(i)];

    b=T.true_eta_bins(i)/proc.N;
    s_true=synth_discrete_lfm(proc.N,1,T.true_a_strong(i),b,0);
    w_true=synth_discrete_lfm(proc.N,T.weak_to_strong_ratio(i), ...
        T.true_a_weak(i),b,T.relative_phase_rad(i));

    for im=1:numel(methods)
        nu=eta_vec(im);
        [r,info]=practical_recenter_notch_remove( ...
            x,a_hat,nu,cfg.removal_window_bins,cfg);

        branch_err=abs(circular_bin_error(nu,Gref.nu_hat_bins));
        catastrophic=branch_err>cfg.catastrophic_error_threshold_bins;
        eta_err=abs(circular_bin_error(nu,T.true_eta_bins(i)));
        beta_err=abs(O.beta_hat_strong_rad(i)-T.truth_beta_s_rad(i));
        wave_err=norm(r-w_true)/max(norm(w_true),cfg.small_norm_floor);
        weak_beta_err=abs(bw_vec(im)-T.truth_beta_w_rad(i))/proc.Wbeta;
        amp_err=abs(A_vec(im)-1);
        phase_err=abs(wrap_to_pi(P_vec(im)-0));

        rows(end+1,:)={ ... %#ok<AGROW>
            T.trial_id(i),char(T.aperture_mode(i)),char(methods(im)), ...
            O.stage1_trigger(i),O.stage2_trigger(i),O.fallback_trigger(i), ...
            O.beta_hat_strong_rad(i),T.truth_beta_s_rad(i), ...
            beta_err/proc.Wbeta,nu,T.true_eta_bins(i),eta_err, ...
            Gref.nu_hat_bins,branch_err,catastrophic, ...
            A_vec(im),amp_err,P_vec(im),phase_err, ...
            info.mask_fraction,wave_err, ...
            wave_err<=cfg.error_feasible_threshold, ...
            bw_vec(im),T.truth_beta_w_rad(i),weak_beta_err, ...
            eval_vec(im), ...
            T.delta_velocity_mps(i),T.strong_velocity_side(i), ...
            T.weak_to_strong_ratio(i),T.relative_phase_rad(i), ...
            T.true_eta_bins(i),T.truth_Gamma(i)};
    end

    if cfg.run_oracle_controls
        % OracleExact: true waveform subtraction; only a search/control upper bound.
        re=x-s_true;
        bwe=estimate_beta_fixed_domain(re,proc,cfg);
        we=norm(re-w_true)/max(norm(w_true),cfg.small_norm_floor);
        rows(end+1,:)={ ... %#ok<AGROW>
            T.trial_id(i),char(T.aperture_mode(i)),'ORACLE_ExactSubtraction', ...
            false,false,false,T.truth_beta_s_rad(i),T.truth_beta_s_rad(i),0, ...
            T.true_eta_bins(i),T.true_eta_bins(i),0,T.true_eta_bins(i),0,false, ...
            1,0,0,0,0,we,we<=cfg.error_feasible_threshold, ...
            bwe,T.truth_beta_w_rad(i),abs(bwe-T.truth_beta_w_rad(i))/proc.Wbeta, ...
            NaN,T.delta_velocity_mps(i),T.strong_velocity_side(i), ...
            T.weak_to_strong_ratio(i),T.relative_phase_rad(i), ...
            T.true_eta_bins(i),T.truth_Gamma(i)};

        % OracleNotch3: true beta/eta but the SAME frozen finite-window operator.
        [ro,infoo]=practical_recenter_notch_remove( ...
            x,T.true_a_strong(i),T.true_eta_bins(i), ...
            cfg.removal_window_bins,cfg);
        bwo=estimate_beta_fixed_domain(ro,proc,cfg);
        wo=norm(ro-w_true)/max(norm(w_true),cfg.small_norm_floor);
        rows(end+1,:)={ ... %#ok<AGROW>
            T.trial_id(i),char(T.aperture_mode(i)),'ORACLE_TrueBetaEta_Notch3', ...
            false,false,false,T.truth_beta_s_rad(i),T.truth_beta_s_rad(i),0, ...
            T.true_eta_bins(i),T.true_eta_bins(i),0,T.true_eta_bins(i),0,false, ...
            1,0,0,0,infoo.mask_fraction,wo,wo<=cfg.error_feasible_threshold, ...
            bwo,T.truth_beta_w_rad(i),abs(bwo-T.truth_beta_w_rad(i))/proc.Wbeta, ...
            NaN,T.delta_velocity_mps(i),T.strong_velocity_side(i), ...
            T.weak_to_strong_ratio(i),T.relative_phase_rad(i), ...
            T.true_eta_bins(i),T.truth_Gamma(i)};
    end
end

E=cell2table(rows,'VariableNames',{ ...
    'trial_id','aperture_mode','method', ...
    'stage1_trigger','stage2_trigger','fallback_trigger', ...
    'beta_hat_strong_rad','truth_beta_s_rad','strong_beta_abs_error_over_W', ...
    'eta_hat_bins','truth_eta_bins','eta_abs_error_bins', ...
    'reference_global_nu_bins','branch_error_to_reference_bins', ...
    'catastrophic_branch_failure', ...
    'strong_Ahat','strong_amp_abs_error','strong_phihat_rad', ...
    'strong_phase_abs_error_rad','removal_mask_fraction', ...
    'weak_waveform_error_ratio','weak_waveform_feasible', ...
    'weak_beta_hat_rad','truth_beta_w_rad','weak_beta_abs_error_over_W', ...
    'branch_objective_evals', ...
    'truth_delta_velocity_mps','truth_strong_velocity_side', ...
    'truth_weak_to_strong_ratio','truth_relative_phase_rad', ...
    'truth_fractional_bin_offset','truth_Gamma'});
end

%% =========================================================================
function S = summarize_methods(E,cfg)
methods=unique(string(E.method),'stable');
aps=unique(string(E.aperture_mode),'stable');
rows={};

for ia=1:numel(aps)
    for im=1:numel(methods)
        M=E(string(E.aperture_mode)==aps(ia) & string(E.method)==methods(im),:);
        if isempty(M), continue; end
        practical=~startsWith(methods(im),"ORACLE_");
        if practical
            meanCost=mean(M.branch_objective_evals,'omitnan');
            catRate=mean(M.catastrophic_branch_failure);
        else
            meanCost=NaN;
            catRate=NaN;
        end
        rows(end+1,:)={ ... %#ok<AGROW>
            char(aps(ia)),char(methods(im)),height(M), ...
            mean(M.weak_waveform_feasible), ...
            median(M.weak_waveform_error_ratio,'omitnan'), ...
            local_percentile(M.weak_waveform_error_ratio,90), ...
            median(M.weak_beta_abs_error_over_W,'omitnan'), ...
            local_percentile(M.weak_beta_abs_error_over_W,90), ...
            median(M.strong_beta_abs_error_over_W,'omitnan'), ...
            local_percentile(M.strong_beta_abs_error_over_W,90), ...
            median(M.eta_abs_error_bins,'omitnan'), ...
            local_percentile(M.eta_abs_error_bins,90), ...
            catRate,meanCost, ...
            mean(M.fallback_trigger)};
    end
end

S=cell2table(rows,'VariableNames',{ ...
    'aperture_mode','method','n_trials', ...
    'weak_waveform_feasible_rate','median_weak_waveform_error_ratio', ...
    'p90_weak_waveform_error_ratio','median_weak_beta_error_over_W', ...
    'p90_weak_beta_error_over_W','median_strong_beta_error_over_W', ...
    'p90_strong_beta_error_over_W','median_eta_error_bins','p90_eta_error_bins', ...
    'catastrophic_branch_failure_rate','mean_branch_objective_evals', ...
    'fallback_fraction'});

% Add normalized branch-cost for practical rows aperture-wise.
S.normalized_branch_cost=nan(height(S),1);
for ia=1:numel(aps)
    idxA=string(S.aperture_mode)==aps(ia);
    g0=S(idxA & string(S.method)=="G0_OriginalTop1",:);
    n3=S(idxA & string(S.method)=="Always_Neighbor3",:);
    if isempty(g0) || isempty(n3), continue; end
    den=n3.mean_branch_objective_evals-g0.mean_branch_objective_evals;
    for j=find(idxA).'
        if startsWith(string(S.method(j)),"ORACLE_") || ~isfinite(den) || den<=0
            continue;
        end
        S.normalized_branch_cost(j)= ...
            (S.mean_branch_objective_evals(j)-g0.mean_branch_objective_evals)/den;
    end
end

% Keep config referenced so accidental future changes are visible in summary.
S.removal_window_bins=repmat(cfg.removal_window_bins,height(S),1);
end

%% =========================================================================
function P = summarize_paired(E,cfg) %#ok<INUSD>
aps=unique(string(E.aperture_mode),'stable');
rows={};
for ia=1:numel(aps)
    ap=aps(ia);
    G=E(string(E.aperture_mode)==ap & string(E.method)=="G0_OriginalTop1",:);
    Q=E(string(E.aperture_mode)==ap & string(E.method)=="Proposed_Frozen_Staged",:);
    N=E(string(E.aperture_mode)==ap & string(E.method)=="Always_Neighbor3",:);
    G=sortrows(G,'trial_id'); Q=sortrows(Q,'trial_id'); N=sortrows(N,'trial_id');
    assert(isequal(G.trial_id,Q.trial_id) && isequal(G.trial_id,N.trial_id));

    gfail=~G.weak_waveform_feasible;
    qfail=~Q.weak_waveform_feasible;
    nfail=~N.weak_waveform_feasible;

    rows(end+1,:)={ ... %#ok<AGROW>
        char(ap),height(G), ...
        sum(gfail & ~qfail),sum(~gfail & qfail), ...
        sum(qfail & ~nfail),sum(qfail & nfail), ...
        sum(G.catastrophic_branch_failure & ~Q.catastrophic_branch_failure), ...
        sum(~G.catastrophic_branch_failure & Q.catastrophic_branch_failure)};
end
P=cell2table(rows,'VariableNames',{ ...
    'aperture_mode','n_trials', ...
    'G0_fail_to_Proposed_success','G0_success_to_Proposed_fail', ...
    'Proposed_fail_to_N3_success','persistent_after_N3', ...
    'G0_branch_catastrophe_rescued_by_Proposed', ...
    'Proposed_induced_branch_catastrophe'});
end

%% =========================================================================
function F = oracle_firewall_audit(O,E,cfg)
online_names=string(O.Properties.VariableNames);
forbidden=["truth","oracle","global_reference","Gamma","relative_phase", ...
    "weak_to_strong_ratio","strong_velocity","true_eta"];

bad=false(size(forbidden));
for i=1:numel(forbidden)
    bad(i)=any(contains(lower(online_names),lower(forbidden(i))));
end

% Evaluation table MUST contain truth fields; this confirms the split is
% explicit rather than accidentally losing truth metadata entirely.
eval_names=string(E.Properties.VariableNames);
has_truth_eval=any(startsWith(eval_names,"truth_"));

policy_ok = abs(cfg.stage1_budget-0.20)<eps && ...
    abs(cfg.stage2_conditional_budget-0.10)<eps && ...
    cfg.removal_window_bins==3;

overall = ~any(bad) && has_truth_eval && policy_ok;

F=table(overall,~any(bad),has_truth_eval,policy_ok, ...
    strjoin(forbidden(bad),';'), ...
    'VariableNames',{ ...
    'overall_pass','online_schema_has_no_forbidden_truth_fields', ...
    'evaluation_schema_has_truth_fields','frozen_policy_matches', ...
    'forbidden_online_matches'});
end

%% =========================================================================
function [beta_hat,best_score] = estimate_beta_fixed_domain(x,proc,cfg)
P=frac_score_curve(x,proc.beta_grid,proc.max_lag,cfg);
[best_score,idx]=max(P);
beta_hat=proc.beta_grid(idx);
end

%% =========================================================================
function P = frac_score_curve(x,beta_grid,max_lag,cfg)
x=x(:).';
N=numel(x);
nfft=max(2048,2^nextpow2(cfg.frac_fft_oversample*N));
f=(-nfft/2:nfft/2-1).'/nfft;
tb=tan(beta_grid(:));
P=zeros(numel(beta_grid),1);
for k=1:max_lag
    z=x(1+k:end).*conj(x(1:end-k));
    Z=fftshift(fft(z,nfft));
    v=interp1(f,Z(:),k*tb,'linear',0)/max(numel(z),1);
    P=P+abs(v).^2;
end
P=real(P);
end

%% =========================================================================
function G = g0_with_risk_state(x,a,cfg)
z=dechirp_signal(x,a);
N=numel(z); m=0:N-1;
Y=fftshift(fft(z)); amp=abs(Y(:));
[peak_amp,i0]=max(amp);
dc=floor(N/2)+1;
k0=i0-dc;

[nu,Jhat,neval]=refine_from_seed(z,m,N,k0,cfg);

idx5=arrayfun(@(d) wrap_index(i0+d,N),-2:2);
a5=amp(idx5);
fivebin=peak_amp/max(sum(a5),eps);

h=cfg.refined_lr_probe_bins;
Jm=tone_objective(z,m,N,nu-h);
Jp=tone_objective(z,m,N,nu+h);
refined_lr=abs(Jp-Jm)/max(Jhat,eps);

G=struct();
G.nu_hat_bins=nu;
G.objective_at_hat=Jhat;
G.n_objective_evals=neval;
G.coarse_seed_primary=k0;
G.fivebin_peak_fraction=fivebin;
G.refined_lr_asymmetry=refined_lr;
end

%% =========================================================================
function G = estimate_neighbor3(x,a,cfg)
z=dechirp_signal(x,a);
N=numel(z); m=0:N-1;
Y=fftshift(fft(z));
[~,i0]=max(abs(Y));
dc=floor(N/2)+1;
k0=i0-dc;
seeds=(k0-cfg.neighbor_radius):(k0+cfg.neighbor_radius);

nu_best=NaN; Jbest=-Inf; total=0;
for s=seeds
    [nu,J,neval]=refine_from_seed(z,m,N,s,cfg);
    total=total+neval;
    if J>Jbest
        Jbest=J; nu_best=nu;
    end
end
G=struct('nu_hat_bins',nu_best,'objective_at_hat',Jbest, ...
    'n_objective_evals',total,'coarse_seed_primary',k0);
end

%% =========================================================================
function G = estimate_global_reference(x,a,cfg)
z=dechirp_signal(x,a);
N=numel(z); m=0:N-1;
d=-cfg.global_search_halfwidth_bins:cfg.global_grid_step_bins:cfg.global_search_halfwidth_bins;
J=zeros(size(d));
for i=1:numel(d), J(i)=tone_objective(z,m,N,d(i)); end
[~,ig]=max(J);
i1=max(1,ig-1); i2=min(numel(d),ig+1);
lb=d(i1); ub=d(i2);
count=0;
opts=optimset('Display','off','TolX',cfg.global_tolx_bins, ...
    'MaxFunEvals',cfg.global_max_fun_evals);
if ub<=lb
    nu=d(ig); Jhat=J(ig);
else
    [nu,fval]=fminbnd(@wrapped_obj,lb,ub,opts);
    Jhat=-fval;
end
G=struct('nu_hat_bins',nu,'objective_at_hat',Jhat, ...
    'n_objective_evals',numel(d)+count);
    function y=wrapped_obj(q)
        count=count+1;
        y=-tone_objective(z,m,N,q);
    end
end

%% =========================================================================
function [nu_hat,Jhat,neval] = refine_from_seed(z,m,N,seed,cfg)
lb=seed-cfg.local_search_halfwidth_bins;
ub=seed+cfg.local_search_halfwidth_bins;
grid=linspace(lb,ub,cfg.local_bracket_points);
J=zeros(size(grid));
for i=1:numel(grid), J(i)=tone_objective(z,m,N,grid(i)); end
neval=numel(grid);
[~,ib]=max(J);
i1=max(1,ib-1); i2=min(numel(grid),ib+1);
local_lb=grid(i1); local_ub=grid(i2);
if local_ub<=local_lb
    nu_hat=grid(ib); Jhat=J(ib); return;
end
count=0;
opts=optimset('Display','off','TolX',cfg.local_tolx_bins, ...
    'MaxFunEvals',cfg.local_max_fun_evals);
[nu_hat,fval]=fminbnd(@wrapped_obj,local_lb,local_ub,opts);
Jhat=-fval; neval=neval+count;
    function y=wrapped_obj(q)
        count=count+1;
        y=-tone_objective(z,m,N,q);
    end
end

%% =========================================================================
function J = tone_objective(z,m,N,nu)
q=sum(z.*exp(-1j*2*pi*nu*m/N));
J=abs(q).^2;
end

%% =========================================================================
function z = dechirp_signal(x,a)
x=x(:).'; N=numel(x); m=0:N-1;
z=x.*exp(-1j*pi*a*m.^2);
end

%% =========================================================================
function [Ahat,phihat] = estimate_amp_phase_ls(x,a,nu)
N=numel(x); m=0:N-1;
h=exp(1j*2*pi*(0.5*a*m.^2+(nu/N)*m));
c=sum(conj(h).*x)/max(sum(abs(h).^2),eps);
Ahat=abs(c); phihat=angle(c);
end

%% =========================================================================
function [residual,info] = practical_recenter_notch_remove(x,a,nu,Lwin,cfg)
[xr,phase]=recenter_signal(x,nu);
Y=matched_lfm_transform(xr,a);
[mask,maskinfo]=build_plateau_tol_mask(Y,Lwin,cfg);
Yext=zeros(size(Y)); Yext(mask)=Y(mask);
ext=inverse_matched_lfm_transform(Yext,a);
rrec=xr-ext;
residual=rrec.*conj(phase);
info=maskinfo;
end

%% =========================================================================
function [xr,phase] = recenter_signal(x,nu)
x=x(:).'; N=numel(x); m=0:N-1;
phase=exp(-1j*2*pi*nu*m/N);
xr=x.*phase;
end

%% =========================================================================
function Y = matched_lfm_transform(x,a)
x=x(:).'; N=numel(x); m=0:N-1;
z=x.*exp(-1j*pi*a*m.^2);
Y=fftshift(fft(z))/sqrt(N);
end

%% =========================================================================
function x = inverse_matched_lfm_transform(Y,a)
Y=Y(:).'; N=numel(Y); m=0:N-1;
z=ifft(ifftshift(Y))*sqrt(N);
x=z.*exp(1j*pi*a*m.^2);
end

%% =========================================================================
function [mask,info] = build_plateau_tol_mask(Y,Lwin,cfg)
amp=abs(Y(:).'); N=numel(amp);
amax=max(amp); gate=cfg.frac_domain_peak_gate*amax;
tol=cfg.tie_eps_multiplier*N*eps(max(amax,1));
centers=plateau_aware_tol(amp,gate,tol);
half=floor((Lwin-1)/2);
mask=false(1,N);
for k=1:numel(centers)
    i1=max(1,centers(k)-half); i2=min(N,centers(k)+half);
    mask(i1:i2)=true;
end
info=struct('detected_centers',centers,'mask_bin_count',nnz(mask), ...
    'mask_fraction',mean(mask),'tie_tolerance_abs',tol);
end

%% =========================================================================
function pk = plateau_aware_tol(amp,gate,tol)
amp=amp(:).'; N=numel(amp); pk=[];
if N==1, pk=1; return; end
if amp(1)>=amp(2)-tol && amp(1)>=gate-tol, pk(end+1)=1; end %#ok<AGROW>
for i=2:N-1
    geL=amp(i)>=amp(i-1)-tol; geR=amp(i)>=amp(i+1)-tol;
    strict=amp(i)>amp(i-1)+tol || amp(i)>amp(i+1)+tol;
    if geL && geR && strict && amp(i)>=gate-tol, pk(end+1)=i; end %#ok<AGROW>
end
if amp(N)>=amp(N-1)-tol && amp(N)>=gate-tol, pk(end+1)=N; end %#ok<AGROW>
pk=unique(pk);
if isempty(pk)
    [~,imax]=max(amp);
    pk=find(abs(amp-amp(imax))<=tol & amp>=gate-tol);
end
end

%% =========================================================================
function [mask,s] = tie_inclusive_top(score,b)
score=double(score(:)); n=numel(score);
assert(all(isfinite(score)),'Non-finite policy score.');
assert(b>=0 && b<=1,'Budget outside [0,1].');
if b==0
    mask=false(n,1); s=selection_struct(0,0,0,NaN,0,0); return;
elseif b==1
    mask=true(n,1); cutoff=min(score); tie_n=sum(score==cutoff);
    s=selection_struct(n,n,1,cutoff,tie_n,0); return;
end
target=ceil(b*n); ss=sort(score,'descend'); cutoff=ss(target);
mask=score>=cutoff; selected=sum(mask); actual=selected/n;
tie_n=sum(score==cutoff); inflation=actual-b;
s=selection_struct(target,selected,actual,cutoff,tie_n,inflation);
end

function s = selection_struct(target,selected,actual,cutoff,tie_n,inflation)
s=struct('target_count',target,'selected_count',selected, ...
    'actual_fraction',actual,'cutoff_score',cutoff, ...
    'cutoff_tie_count',tie_n,'budget_inflation',inflation);
end

function s = empty_selection()
s=selection_struct(0,0,0,NaN,0,0);
end

%% =========================================================================
function idx = wrap_index(i,N)
idx=mod(i-1,N)+1;
end

function e = circular_bin_error(a,b)
% Inherited PA5I semantics for frequency coordinates with period N are
% implemented locally at the caller's numerical scale. Here all practical
% nu values live within a few bins of DC, so nearest-period wrapping is
% equivalent to the direct fractional branch comparison.
e=mod((a-b)+0.5,1)-0.5;
end

function y = wrap_to_pi(x)
y=mod(x+pi,2*pi)-pi;
end

%% =========================================================================
function x = synth_discrete_lfm(N,A,a,b,phi)
m=0:N-1;
x=A.*exp(1j*2*pi*(0.5*a*m.^2+b*m)+1j*phi);
x=x(:).';
end

function [K_A,K_SAR,K_res] = residual_fm_rates(v,R0,lambda,cfg)
V=cfg.platform_velocity_mps;
K_A=-2*(V-v).^2/(lambda*R0);
K_SAR=2*V^2/(lambda*R0);
K_res=K_SAR.^2./(K_A-K_SAR)+K_SAR;
end

%% =========================================================================
function run_startup_self_tests(cfg)
% 1) LS amplitude/phase sanity.
N=188; a=0.0013; nu=0.37; A=1.7; phi=0.63;
x=synth_discrete_lfm(N,A,a,nu/N,phi);
[Ah,ph]=estimate_amp_phase_ls(x,a,nu);
assert(abs(Ah-A)<1e-10 && abs(wrap_to_pi(ph-phi))<1e-10, ...
    'Amplitude/phase LS self-test failed.');

% 2) Recenter + unitary transform identity.
[xr,phase]=recenter_signal(x,nu);
xback=xr.*conj(phase);
assert(norm(xback-x)/norm(x)<cfg.translation_selftest_gate, ...
    'Recenter translation self-test failed.');

% 3) Tie-inclusive budget semantics.
score=[3;2;2;1];
[m,s]=tie_inclusive_top(score,0.5);
assert(isequal(m,[true;true;true;false]) && s.selected_count==3, ...
    'Tie-inclusive scheduler self-test failed.');

fprintf('Startup self-tests: PASS\n');
end

%% =========================================================================
function q = local_percentile(x,p)
x=x(isfinite(x));
if isempty(x), q=NaN; return; end
x=sort(x(:));
pos=1+(numel(x)-1)*p/100;
lo=floor(pos); hi=ceil(pos);
if lo==hi, q=x(lo); else, q=x(lo)+(pos-lo)*(x(hi)-x(lo)); end
end

%% =========================================================================
function write_text_summary(cfg,S,P,F,E)
fid=fopen(fullfile(cfg.output_dir,'summary.txt'),'w');
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'EXP009 Practical Non-Oracle Closure — %s\n',upper(cfg.run_mode));
fprintf(fid,'Noise/clutter OFF. SNR remains PENDING-DEFINITION.\n');
fprintf(fid,'Policy: Refined-LR %.2f -> FiveBin %.2f conditional -> N3\n', ...
    cfg.stage1_budget,cfg.stage2_conditional_budget);
fprintf(fid,'Removal: recenter -> PlateauAwareTol 0.70 -> %d-bin notch -> inverse -> undo recenter\n\n', ...
    cfg.removal_window_bins);
fprintf(fid,'ORACLE_FIREWALL = %d\n\n',F.overall_pass(1));

for i=1:height(S)
    fprintf(fid,['%s / %s: n=%d weakFeasible=%.4f medE=%.4f p90E=%.4f ' ...
        'medWeakBeta/W=%.4f p90=%.4f medStrongBeta/W=%.4f ' ...
        'medEtaErr=%.4f branchCat=%.4f branchCost=%.3f normCost=%.3f\n'], ...
        string(S.aperture_mode(i)),string(S.method(i)),S.n_trials(i), ...
        S.weak_waveform_feasible_rate(i),S.median_weak_waveform_error_ratio(i), ...
        S.p90_weak_waveform_error_ratio(i),S.median_weak_beta_error_over_W(i), ...
        S.p90_weak_beta_error_over_W(i),S.median_strong_beta_error_over_W(i), ...
        S.median_eta_error_bins(i),S.catastrophic_branch_failure_rate(i), ...
        S.mean_branch_objective_evals(i),S.normalized_branch_cost(i));
end

fprintf(fid,'\nPAIRED OUTCOMES\n');
for i=1:height(P)
    fprintf(fid,['%s: G0fail->PropSuccess=%d | G0success->PropFail=%d | ' ...
        'PropFail->N3Success=%d | persistentN3=%d | ' ...
        'branchRescue=%d | inducedBranchCat=%d\n'], ...
        string(P.aperture_mode(i)),P.G0_fail_to_Proposed_success(i), ...
        P.G0_success_to_Proposed_fail(i),P.Proposed_fail_to_N3_success(i), ...
        P.persistent_after_N3(i), ...
        P.G0_branch_catastrophe_rescued_by_Proposed(i), ...
        P.Proposed_induced_branch_catastrophe(i));
end

fprintf(fid,'\nSMOKE-TEST INTERPRETATION RULES\n');
fprintf(fid,'1) This run is implementation closure, not final paper evidence.\n');
fprintf(fid,'2) If strong-beta fixed-domain estimation is poor, STOP and repair upstream practical strong search.\n');
fprintf(fid,'3) If Refined-LR/FiveBin risk directions reverse under practical beta_hat, POLICY FREEZE is falsified; do not silently retune.\n');
fprintf(fid,'4) If N3 induces systematic downstream weak damage, report the boundary; do not upgrade to Neighbor-5 in this run.\n');
fprintf(fid,'5) Truth columns are evaluation-only. Online output schema must remain truth-free.\n');
fprintf(fid,'\nTotal evaluation rows = %d\n',height(E));
end

%% =========================================================================
function make_figures(E,S,cfg)
practical=E(~startsWith(string(E.method),"ORACLE_"),:);
aps=unique(string(practical.aperture_mode),'stable');
methods=["G0_OriginalTop1","Proposed_Frozen_Staged","Always_Neighbor3"];

% Fig 1: weak waveform feasibility.
fig=figure('Visible',cfg.figure_visible);
hold on;
for im=1:numel(methods)
    y=nan(size(aps));
    for ia=1:numel(aps)
        M=practical(string(practical.aperture_mode)==aps(ia) & ...
            string(practical.method)==methods(im),:);
        y(ia)=mean(M.weak_waveform_feasible);
    end
    plot(1:numel(aps),y,'-o','LineWidth',1.2,'DisplayName',methods(im));
end
xticks(1:numel(aps)); xticklabels(aps); ylim([0,1]); grid on;
ylabel('Weak waveform feasible rate (E <= 1)');
title('Practical-chain weak recovery'); legend('Location','best');
exportgraphics(fig,fullfile(cfg.figure_dir,'fig01_weak_recovery.png'),'Resolution',200);
close(fig);

% Fig 2: branch catastrophe vs normalized cost.
fig=figure('Visible',cfg.figure_visible); hold on;
for ia=1:numel(aps)
    M=S(string(S.aperture_mode)==aps(ia) & ...
        ismember(string(S.method),methods),:);
    scatter(M.normalized_branch_cost,M.catastrophic_branch_failure_rate,55,'filled', ...
        'DisplayName',aps(ia));
    for j=1:height(M)
        text(M.normalized_branch_cost(j),M.catastrophic_branch_failure_rate(j), ...
            " "+string(M.method(j)),'FontSize',8);
    end
end
grid on; xlabel('Normalized branch cost: G0=0, N3=1');
ylabel('Catastrophic branch failure rate');
title('Branch reliability after practical strong-beta estimation');
legend('Location','best');
exportgraphics(fig,fullfile(cfg.figure_dir,'fig02_branch_cost_reliability.png'),'Resolution',200);
close(fig);

% Fig 3: beta and eta estimation error distributions for Proposed.
P=practical(string(practical.method)=="Proposed_Frozen_Staged",:);
fig=figure('Visible',cfg.figure_visible);
scatter(P.strong_beta_abs_error_over_W,P.eta_abs_error_bins,18,'filled');
grid on; xlabel('|beta_s hat-beta_s| / W_beta'); ylabel('|eta hat-eta| [bin]');
title('Proposed upstream estimation errors');
exportgraphics(fig,fullfile(cfg.figure_dir,'fig03_beta_eta_errors.png'),'Resolution',200);
close(fig);

% Fig 4: weak beta error vs waveform error.
fig=figure('Visible',cfg.figure_visible);
scatter(P.weak_beta_abs_error_over_W,P.weak_waveform_error_ratio,18,'filled');
hold on; yline(cfg.error_feasible_threshold,'--'); grid on;
xlabel('|beta_w hat-beta_w| / W_beta'); ylabel('Weak waveform error ratio E');
title('Weak-search error versus residual recoverability');
exportgraphics(fig,fullfile(cfg.figure_dir,'fig04_weak_search_vs_residual.png'),'Resolution',200);
close(fig);
end
