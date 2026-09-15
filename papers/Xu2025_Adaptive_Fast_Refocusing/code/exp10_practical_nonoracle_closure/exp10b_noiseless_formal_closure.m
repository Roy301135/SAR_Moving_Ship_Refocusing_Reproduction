function results = exp10b_noiseless_formal_closure()
%EXP10B_NOISELESS_FORMAL_CLOSURE
% EXP010-B — Noiseless Practical Non-Oracle Formal Closure
%
% PURPOSE
% -------
% Formal deterministic closure after EXP010-A smoke-test implementation pass.
% This run contains two validation sets:
%
%   OriginalGrid : complete PA5 physical grid;
%   DenseRisk    : PA5I-R1 frozen risk states x eta=0:0.01:0.5.
%
% The Proposed path remains fully non-oracle:
%
%   observed mixture
%     -> fixed-domain practical strong-beta search
%     -> G0 reliability state
%     -> Refined-LR top 20%
%     -> residual FiveBin top 10% of untriggered pool
%     -> optional Neighbor-3
%     -> practical recenter + frozen 3-bin removal
%     -> global practical weak-beta search
%
% Truth is introduced only after the practical batch method has returned.
%
% PRIMARY CLAIMS SERVED
% ---------------------
% Claim 1: quantify practical-chain operator / estimation gaps without noise.
% Claim 2: validate the frozen staged reliability allocation in a complete
%          practical non-oracle chain, on both nominal and prior-frozen
%          dense-risk stress sets.
%
% NOISE / CLUTTER ARE OFF.  SNR remains PENDING-DEFINITION.

cfg = config_exp10b_noiseless_formal_closure();

fprintf('\n============================================================\n');
fprintf('EXP010-B Noiseless Practical Non-Oracle Formal Closure\n');
fprintf('============================================================\n');
fprintf('Noise / clutter: OFF\n');
fprintf('Validation sets: %s\n',strjoin(cfg.validation_sets,', '));
fprintf('Policy: Refined-LR b1=%.2f -> FiveBin b2=%.2f -> N3\n', ...
    cfg.stage1_budget,cfg.stage2_conditional_budget);
fprintf('Removal width: %d bins (FROZEN)\n',cfg.removal_window_bins);
fprintf('SNR definition: PENDING-DEFINITION; not used here.\n\n');

validate_cfg_contract(cfg);
ensure_output_dirs(cfg);
run_startup_self_tests(cfg);

truth_all = table();
online_all = table();
eval_all = table();

apertures = ["Paper1s","BeamDerived"];

for iv = 1:numel(cfg.validation_sets)
    validation_set = cfg.validation_sets(iv);

    for ia = 1:numel(apertures)
        mode = apertures(ia);
        proc = build_processing_context(mode,cfg);

        fprintf('\n--- %s / %s: N=%d, beta-grid=%d, maxLag=%d ---\n', ...
            validation_set,mode,proc.N,numel(proc.beta_grid),proc.max_lag);

        truth = build_truth_table(validation_set,mode,proc,cfg);
        fprintf('Physical trials in batch: %d\n',height(truth));

        X = synthesize_observed_batch(truth,proc,cfg);

        % CRITICAL ORACLE FIREWALL:
        % practical_batch_method receives observed samples + processing config only.
        online = practical_batch_method(X,proc,cfg);
        online.validation_set = repmat(validation_set,height(online),1);

        % Truth / global-reference / oracle controls enter only here.
        Eval = evaluate_with_truth(X,truth,online,proc,cfg);

        truth_all = [truth_all; truth]; %#ok<AGROW>
        online_all = [online_all; online]; %#ok<AGROW>
        eval_all = [eval_all; Eval]; %#ok<AGROW>

        % Save each completed natural batch immediately.
        batch_tag = sprintf('%s_%s',lower(char(validation_set)),lower(char(mode)));
        writetable(truth,fullfile(cfg.output_dir,[batch_tag '_truth.csv']));
        writetable(online,fullfile(cfg.output_dir,[batch_tag '_online.csv']));
        writetable(Eval,fullfile(cfg.output_dir,[batch_tag '_evaluation.csv']));
    end
end

summary = summarize_methods(eval_all,cfg);
paired = summarize_paired(eval_all,cfg);
stage = summarize_stage_allocation(eval_all);
risk = summarize_risk_direction(online_all,eval_all,cfg);
operator_gap = summarize_operator_gap(eval_all);
upstream = summarize_upstream_errors(eval_all);
firewall = oracle_firewall_audit(online_all,eval_all,cfg);
verdict = build_formal_verdict(summary,paired,stage,risk,firewall,cfg);

writetable(truth_all,fullfile(cfg.output_dir,'truth_metadata_all.csv'));
writetable(online_all,fullfile(cfg.output_dir,'practical_online_outputs_all.csv'));
writetable(eval_all,fullfile(cfg.output_dir,'evaluation_trials_all.csv'));

writetable(summary,fullfile(cfg.output_dir,'method_summary.csv'));
writetable(paired,fullfile(cfg.output_dir,'paired_outcome_summary.csv'));
writetable(stage,fullfile(cfg.output_dir,'stage_allocation_summary.csv'));
writetable(risk,fullfile(cfg.output_dir,'risk_direction_audit.csv'));
writetable(operator_gap,fullfile(cfg.output_dir,'operator_gap_summary.csv'));
writetable(upstream,fullfile(cfg.output_dir,'upstream_estimation_summary.csv'));
writetable(firewall,fullfile(cfg.output_dir,'oracle_firewall_audit.csv'));
writetable(verdict,fullfile(cfg.output_dir,'formal_verdict.csv'));

write_feedback_bundle(cfg,summary,paired,stage,risk,operator_gap, ...
    upstream,firewall,verdict,eval_all);
make_figures(eval_all,summary,risk,operator_gap,stage,cfg);

save(fullfile(cfg.output_dir,'exp10b_formal_results.mat'), ...
    'cfg','summary','paired','stage','risk','operator_gap', ...
    'upstream','firewall','verdict','-v7.3');

results = struct();
results.cfg = cfg;
results.summary = summary;
results.paired = paired;
results.stage = stage;
results.risk = risk;
results.operator_gap = operator_gap;
results.upstream = upstream;
results.firewall = firewall;
results.verdict = verdict;

fprintf('\nOutputs saved to:\n%s\n',cfg.output_dir);
fprintf('Feedback bundle:\n%s\n',fullfile(cfg.output_dir,cfg.feedback_bundle_name));
fprintf('ORACLE_FIREWALL = %d\n',firewall.overall_pass(1));
fprintf('FORMAL VERDICT = %s\n',string(verdict.overall_verdict(1)));

if cfg.oracle_firewall_required && ~firewall.overall_pass(1)
    error('EXP010B:OracleFirewallFailed', ...
        'Oracle firewall audit failed. Do not interpret this run.');
end

end

function ensure_output_dirs(cfg)
if ~exist(cfg.output_dir,'dir'), mkdir(cfg.output_dir); end
if ~exist(cfg.figure_dir,'dir'), mkdir(cfg.figure_dir); end
end

%% =========================================================================

function validate_cfg_contract(cfg)

required=[ ...
    "validation_sets","weak_velocity_mps","full_delta_velocity_mps", ...
    "full_weak_to_strong_ratio","full_relative_phase_rad", ...
    "full_fractional_bin_offsets","dense_eta_bins", ...
    "search_velocity_min_mps","search_velocity_max_mps", ...
    "pa4_beta_width_paper_rad","pa4_beta_width_beam_rad", ...
    "stage1_budget","stage2_conditional_budget", ...
    "removal_window_bins","dense_risk_states_path", ...
    "output_dir","figure_dir","feedback_bundle_name"];

for i=1:numel(required)
    if ~isfield(cfg,required(i))
        error('EXP010B:MissingConfigField','Missing config field: %s',required(i));
    end
end

assert(abs(cfg.stage1_budget-0.20)<eps, ...
    'Frozen Stage-1 budget changed.');
assert(abs(cfg.stage2_conditional_budget-0.10)<eps, ...
    'Frozen Stage-2 budget changed.');
assert(cfg.removal_window_bins==3, ...
    'Frozen removal width changed.');
assert(cfg.neighbor_radius==1, ...
    'Neighbor-3 candidate count changed.');
assert(abs(cfg.catastrophic_error_threshold_bins-0.10)<eps, ...
    'Catastrophic threshold changed.');
assert(abs(cfg.branch_match_tolerance_bins-0.02)<eps, ...
    'Branch-match tolerance changed.');
assert(isequal(cfg.dense_eta_bins,0:0.01:0.5), ...
    'DenseRisk eta sweep changed from PA5I-R1 freeze.');

end

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

function T = build_truth_table(validation_set,mode,proc,cfg)
%BUILD_TRUTH_TABLE Simulation/evaluation metadata only.
% This table is NEVER passed into practical_batch_method.

if validation_set=="OriginalGrid"
    T = build_original_truth_table(mode,proc,cfg);
elseif validation_set=="DenseRisk"
    T = build_dense_risk_truth_table(mode,proc,cfg);
else
    error('EXP010B:UnknownValidationSet','Unknown validation set: %s',validation_set);
end

T.validation_set = repmat(validation_set,height(T),1);
T = movevars(T,'validation_set','Before','trial_id');

end

%% =========================================================================
function T = build_original_truth_table(mode,proc,cfg)

dV = cfg.full_delta_velocity_mps;
rList = cfg.full_weak_to_strong_ratio;
pList = cfg.full_relative_phase_rad;
eList = cfg.full_fractional_bin_offsets;
sides = ["LowV","HighV"];

rows = {};
id = 0;

[~,~,Kw] = residual_fm_rates(cfg.weak_velocity_mps,proc.R0,proc.lambda,cfg);
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
                        as,aw,beta_s,beta_w,Gamma,NaN};
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
    'truth_beta_s_rad','truth_beta_w_rad','truth_Gamma','risk_state_id'});

end

%% =========================================================================
function T = build_dense_risk_truth_table(mode,proc,cfg)

if ~exist(cfg.dense_risk_states_path,'file')
    if cfg.require_dense_risk_input
        error('EXP010B:MissingDenseRiskStates', ...
            ['Frozen PA5I-R1 risk-state table not found:\n%s\n\n' ...
             'Run / restore PA5I-R1 results before EXP010-B.'], ...
             cfg.dense_risk_states_path);
    else
        T=table();
        return;
    end
end

R=readtable(cfg.dense_risk_states_path,'TextType','string');
validate_dense_risk_storage_schema(R);

R=R(string(R.aperture_mode)==mode,:);
if isempty(R)
    error('EXP010B:NoDenseRiskStatesForAperture', ...
        'No PA5I-R1 DenseRisk states found for %s.',mode);
end

validate_dense_risk_consumer_schema(R);

if any(double(R.azimuth_samples)~=proc.N)
    error('EXP010B:DenseRiskApertureMismatch', ...
        'Frozen DenseRisk azimuth_samples disagree with current %s N=%d.',mode,proc.N);
end

if ismember('Gamma_PA4',R.Properties.VariableNames)
    gsrc=double(R.Gamma_PA4);
    grecalc=abs(atan(double(R.strong_chirp_rate_discrete))- ...
        atan(double(R.weak_chirp_rate_discrete)))/proc.Wbeta;
    if max(abs(gsrc-grecalc),[],'omitnan')>1e-8
        error('EXP010B:DenseRiskGammaMismatch', ...
            'Frozen DenseRisk Gamma_PA4 cross-check failed for %s.',mode);
    end
end

% The stress-state list was frozen upstream from PA5I-R1. Its truth
% metadata defines the evaluation sample family only. None of these fields
% is passed into practical_batch_method.
rows={};
id=0;

for is=1:height(R)
    for ie=1:numel(cfg.dense_eta_bins)
        eta=cfg.dense_eta_bins(ie);
        id=id+1;

        aS=double(R.strong_chirp_rate_discrete(is));
        aW=double(R.weak_chirp_rate_discrete(is));
        betaS=atan(aS);
        betaW=atan(aW);
        Gamma=abs(betaS-betaW)/proc.Wbeta;

        rows(end+1,:)={ ... %#ok<AGROW>
            id,char(mode),proc.N, ...
            double(R.delta_velocity_mps(is)), ...
            char(string(R.strong_velocity_side(is))), ...
            double(R.strong_velocity_mps(is)), ...
            cfg.weak_velocity_mps, ...
            double(R.weak_to_strong_ratio(is)), ...
            double(R.relative_phase_rad(is)),eta, ...
            aS,aW,betaS,betaW,Gamma,double(R.risk_state_id(is))};
    end
end

T=cell2table(rows,'VariableNames',{ ...
    'trial_id','aperture_mode','azimuth_samples', ...
    'delta_velocity_mps','strong_velocity_side','strong_velocity_mps', ...
    'weak_velocity_mps','weak_to_strong_ratio','relative_phase_rad', ...
    'true_eta_bins','true_a_strong','true_a_weak', ...
    'truth_beta_s_rad','truth_beta_w_rad','truth_Gamma','risk_state_id'});

end

%% =========================================================================
function validate_dense_risk_storage_schema(R)

required=[ ...
    "risk_state_id","aperture_mode","azimuth_samples", ...
    "delta_velocity_mps","strong_velocity_side","strong_velocity_mps", ...
    "weak_to_strong_ratio","relative_phase_rad", ...
    "strong_chirp_rate_discrete","weak_chirp_rate_discrete"];

missing=setdiff(required,string(R.Properties.VariableNames));
if ~isempty(missing)
    error('EXP010B:DenseRiskStorageSchemaMismatch', ...
        'DenseRisk storage schema missing: %s',strjoin(missing,', '));
end

end

%% =========================================================================
function validate_dense_risk_consumer_schema(R)

required=[ ...
    "risk_state_id","aperture_mode","delta_velocity_mps", ...
    "strong_velocity_side","strong_velocity_mps", ...
    "weak_to_strong_ratio","relative_phase_rad", ...
    "strong_chirp_rate_discrete","weak_chirp_rate_discrete"];

missing=setdiff(required,string(R.Properties.VariableNames));
if ~isempty(missing)
    error('EXP010B:DenseRiskConsumerSchemaMismatch', ...
        'DenseRisk consumer schema missing: %s',strjoin(missing,', '));
end

if numel(unique(R.risk_state_id))~=height(R)
    error('EXP010B:DenseRiskDuplicateState','risk_state_id must be unique.');
end

end

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
    if mod(i,cfg.progress_every)==0 || i==1 || i==n
        fprintf('  practical search: %d / %d\n',i,n);
    end
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
    if mod(i,cfg.progress_every)==0 || i==1 || i==n
        fprintf('  downstream chain: %d / %d\n',i,n);
    end
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
%EVALUATE_WITH_TRUTH Evaluation/reference layer only.
% Proposed decisions have already been completed before entering here.

n=height(T);
methods=["G0_OriginalTop1","Proposed_Frozen_Staged","Always_Neighbor3"];
rows={};

for i=1:n
    if mod(i,cfg.progress_every)==0 || i==1 || i==n
        fprintf('  evaluation: %d / %d\n',i,n);
    end

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
        phase_err=abs(wrap_to_pi(P_vec(im)));

        rows(end+1,:)={ ... %#ok<AGROW>
            char(T.validation_set(i)),T.trial_id(i),char(T.aperture_mode(i)), ...
            char(methods(im)), ...
            O.stage1_trigger(i),O.stage2_trigger(i),O.fallback_trigger(i), ...
            O.beta_hat_strong_rad(i),T.truth_beta_s_rad(i), ...
            beta_err/proc.Wbeta,nu,T.true_eta_bins(i),eta_err, ...
            Gref.nu_hat_bins,branch_err,catastrophic, ...
            A_vec(im),amp_err,P_vec(im),phase_err, ...
            info.mask_fraction,wave_err, ...
            wave_err<=cfg.error_feasible_threshold, ...
            bw_vec(im),T.truth_beta_w_rad(i),weak_beta_err, ...
            eval_vec(im),T.risk_state_id(i), ...
            T.delta_velocity_mps(i),T.strong_velocity_side(i), ...
            T.weak_to_strong_ratio(i),T.relative_phase_rad(i), ...
            T.true_eta_bins(i),T.truth_Gamma(i)};
    end

    if cfg.run_oracle_controls
        % Oracle exact subtraction.
        re=x-s_true;
        bwe=estimate_beta_fixed_domain(re,proc,cfg);
        we=norm(re-w_true)/max(norm(w_true),cfg.small_norm_floor);
        rows(end+1,:)={ ... %#ok<AGROW>
            char(T.validation_set(i)),T.trial_id(i),char(T.aperture_mode(i)), ...
            'ORACLE_ExactSubtraction',false,false,false, ...
            T.truth_beta_s_rad(i),T.truth_beta_s_rad(i),0, ...
            T.true_eta_bins(i),T.true_eta_bins(i),0,T.true_eta_bins(i),0,false, ...
            1,0,0,0,0,we,we<=cfg.error_feasible_threshold, ...
            bwe,T.truth_beta_w_rad(i),abs(bwe-T.truth_beta_w_rad(i))/proc.Wbeta, ...
            NaN,T.risk_state_id(i), ...
            T.delta_velocity_mps(i),T.strong_velocity_side(i), ...
            T.weak_to_strong_ratio(i),T.relative_phase_rad(i), ...
            T.true_eta_bins(i),T.truth_Gamma(i)};

        % Oracle true beta/eta with SAME frozen practical finite-window operator.
        [ro,infoo]=practical_recenter_notch_remove( ...
            x,T.true_a_strong(i),T.true_eta_bins(i), ...
            cfg.removal_window_bins,cfg);
        bwo=estimate_beta_fixed_domain(ro,proc,cfg);
        wo=norm(ro-w_true)/max(norm(w_true),cfg.small_norm_floor);
        rows(end+1,:)={ ... %#ok<AGROW>
            char(T.validation_set(i)),T.trial_id(i),char(T.aperture_mode(i)), ...
            'ORACLE_TrueBetaEta_Notch3',false,false,false, ...
            T.truth_beta_s_rad(i),T.truth_beta_s_rad(i),0, ...
            T.true_eta_bins(i),T.true_eta_bins(i),0,T.true_eta_bins(i),0,false, ...
            1,0,0,0,infoo.mask_fraction,wo, ...
            wo<=cfg.error_feasible_threshold, ...
            bwo,T.truth_beta_w_rad(i),abs(bwo-T.truth_beta_w_rad(i))/proc.Wbeta, ...
            NaN,T.risk_state_id(i), ...
            T.delta_velocity_mps(i),T.strong_velocity_side(i), ...
            T.weak_to_strong_ratio(i),T.relative_phase_rad(i), ...
            T.true_eta_bins(i),T.truth_Gamma(i)};
    end
end

E=cell2table(rows,'VariableNames',{ ...
    'validation_set','trial_id','aperture_mode','method', ...
    'stage1_trigger','stage2_trigger','fallback_trigger', ...
    'beta_hat_strong_rad','truth_beta_s_rad','strong_beta_abs_error_over_W', ...
    'eta_hat_bins','truth_eta_bins','eta_abs_error_bins', ...
    'reference_global_nu_bins','branch_error_to_reference_bins', ...
    'catastrophic_branch_failure', ...
    'strong_Ahat','strong_amp_abs_error','strong_phihat_rad', ...
    'strong_phase_abs_error_rad','removal_mask_fraction', ...
    'weak_waveform_error_ratio','weak_waveform_feasible', ...
    'weak_beta_hat_rad','truth_beta_w_rad','weak_beta_abs_error_over_W', ...
    'branch_objective_evals','risk_state_id', ...
    'truth_delta_velocity_mps','truth_strong_velocity_side', ...
    'truth_weak_to_strong_ratio','truth_relative_phase_rad', ...
    'truth_fractional_bin_offset','truth_Gamma'});

end

function S = summarize_methods(E,cfg)

sets=unique(string(E.validation_set),'stable');
aps=unique(string(E.aperture_mode),'stable');
methods=unique(string(E.method),'stable');
rows={};

for iv=1:numel(sets)
    for ia=1:numel(aps)
        for im=1:numel(methods)
            M=E(string(E.validation_set)==sets(iv) & ...
                string(E.aperture_mode)==aps(ia) & ...
                string(E.method)==methods(im),:);
            if isempty(M), continue; end

            method=methods(im);
            practical=~startsWith(method,"ORACLE_");

            if practical
                meanCost=mean(M.branch_objective_evals,'omitnan');
                catCount=sum(M.catastrophic_branch_failure);
                catRate=catCount/height(M);

                if method=="G0_OriginalTop1"
                    fallback=0;
                elseif method=="Proposed_Frozen_Staged"
                    fallback=mean(M.fallback_trigger);
                elseif method=="Always_Neighbor3"
                    fallback=1;
                else
                    fallback=NaN;
                end
            else
                meanCost=NaN;
                catCount=NaN;
                catRate=NaN;
                fallback=NaN;
            end

            rows(end+1,:)={ ... %#ok<AGROW>
                char(sets(iv)),char(aps(ia)),char(method),height(M), ...
                sum(M.weak_waveform_feasible),mean(M.weak_waveform_feasible), ...
                median(M.weak_waveform_error_ratio,'omitnan'), ...
                local_percentile(M.weak_waveform_error_ratio,90), ...
                local_percentile(M.weak_waveform_error_ratio,99), ...
                median(M.weak_beta_abs_error_over_W,'omitnan'), ...
                local_percentile(M.weak_beta_abs_error_over_W,90), ...
                median(M.strong_beta_abs_error_over_W,'omitnan'), ...
                local_percentile(M.strong_beta_abs_error_over_W,90), ...
                local_percentile(M.strong_beta_abs_error_over_W,99), ...
                median(M.eta_abs_error_bins,'omitnan'), ...
                local_percentile(M.eta_abs_error_bins,90), ...
                local_percentile(M.eta_abs_error_bins,99), ...
                catCount,catRate,meanCost,fallback};
        end
    end
end

S=cell2table(rows,'VariableNames',{ ...
    'validation_set','aperture_mode','method','n_trials', ...
    'n_weak_waveform_feasible','weak_waveform_feasible_rate', ...
    'median_weak_waveform_error_ratio','p90_weak_waveform_error_ratio', ...
    'p99_weak_waveform_error_ratio','median_weak_beta_error_over_W', ...
    'p90_weak_beta_error_over_W','median_strong_beta_error_over_W', ...
    'p90_strong_beta_error_over_W','p99_strong_beta_error_over_W', ...
    'median_eta_error_bins','p90_eta_error_bins','p99_eta_error_bins', ...
    'n_catastrophic_branch_failures','catastrophic_branch_failure_rate', ...
    'mean_branch_objective_evals','fallback_fraction'});

S.normalized_branch_cost=nan(height(S),1);

for iv=1:numel(sets)
    for ia=1:numel(aps)
        idx=string(S.validation_set)==sets(iv) & ...
            string(S.aperture_mode)==aps(ia);

        g0=S(idx & string(S.method)=="G0_OriginalTop1",:);
        n3=S(idx & string(S.method)=="Always_Neighbor3",:);
        if isempty(g0) || isempty(n3), continue; end

        den=n3.mean_branch_objective_evals-g0.mean_branch_objective_evals;

        for j=find(idx).'
            if startsWith(string(S.method(j)),"ORACLE_") || ...
                    ~isfinite(den) || den<=0
                continue;
            end
            S.normalized_branch_cost(j)= ...
                (S.mean_branch_objective_evals(j)- ...
                g0.mean_branch_objective_evals)/den;
        end
    end
end

S.removal_window_bins=repmat(cfg.removal_window_bins,height(S),1);

end

function P = summarize_paired(E,cfg) %#ok<INUSD>

sets=unique(string(E.validation_set),'stable');
aps=unique(string(E.aperture_mode),'stable');
rows={};

for iv=1:numel(sets)
    for ia=1:numel(aps)

        setName=sets(iv); ap=aps(ia);

        G=E(string(E.validation_set)==setName & ...
            string(E.aperture_mode)==ap & ...
            string(E.method)=="G0_OriginalTop1",:);
        Q=E(string(E.validation_set)==setName & ...
            string(E.aperture_mode)==ap & ...
            string(E.method)=="Proposed_Frozen_Staged",:);
        N=E(string(E.validation_set)==setName & ...
            string(E.aperture_mode)==ap & ...
            string(E.method)=="Always_Neighbor3",:);

        if isempty(G), continue; end

        G=sortrows(G,'trial_id');
        Q=sortrows(Q,'trial_id');
        N=sortrows(N,'trial_id');
        assert(isequal(G.trial_id,Q.trial_id) && isequal(G.trial_id,N.trial_id));

        gweak=~G.weak_waveform_feasible;
        qweak=~Q.weak_waveform_feasible;
        nweak=~N.weak_waveform_feasible;

        weak_rescue=sum(gweak & ~qweak);
        weak_harm=sum(~gweak & qweak);

        gcat=G.catastrophic_branch_failure;
        qcat=Q.catastrophic_branch_failure;
        ncat=N.catastrophic_branch_failure;

        branch_rescue=sum(gcat & ~qcat);
        branch_harm=sum(~gcat & qcat);

        rows(end+1,:)={ ... %#ok<AGROW>
            char(setName),char(ap),height(G), ...
            weak_rescue,weak_harm, ...
            sum(qweak & ~nweak),sum(qweak & nweak), ...
            branch_rescue,branch_harm, ...
            sum(qcat & ~ncat),sum(qcat & ncat), ...
            paired_exact_pvalue(weak_rescue,weak_harm), ...
            paired_exact_pvalue(branch_rescue,branch_harm)};
    end
end

P=cell2table(rows,'VariableNames',{ ...
    'validation_set','aperture_mode','n_trials', ...
    'G0_fail_to_Proposed_success','G0_success_to_Proposed_fail', ...
    'Proposed_fail_to_N3_success','persistent_weak_failure_after_N3', ...
    'G0_branch_catastrophe_rescued_by_Proposed', ...
    'Proposed_induced_branch_catastrophe', ...
    'Proposed_branch_failure_rescued_by_N3', ...
    'persistent_branch_failure_after_N3', ...
    'weak_paired_exact_p','branch_paired_exact_p'});

end

%% =========================================================================
function p = paired_exact_pvalue(rescue,harm)

n=rescue+harm;
if n==0
    p=NaN;
    return;
end

k=min(rescue,harm);
terms=zeros(k+1,1);
for i=0:k
    terms(i+1)=exp(gammaln(n+1)-gammaln(i+1)-gammaln(n-i+1)-n*log(2));
end
p=min(1,2*sum(terms));

end

function S = summarize_stage_allocation(E)

sets=unique(string(E.validation_set),'stable');
aps=unique(string(E.aperture_mode),'stable');
rows={};

for iv=1:numel(sets)
    for ia=1:numel(aps)

        setName=sets(iv); ap=aps(ia);

        G=E(string(E.validation_set)==setName & ...
            string(E.aperture_mode)==ap & ...
            string(E.method)=="G0_OriginalTop1",:);
        Q=E(string(E.validation_set)==setName & ...
            string(E.aperture_mode)==ap & ...
            string(E.method)=="Proposed_Frozen_Staged",:);
        N=E(string(E.validation_set)==setName & ...
            string(E.aperture_mode)==ap & ...
            string(E.method)=="Always_Neighbor3",:);

        if isempty(G), continue; end

        G=sortrows(G,'trial_id');
        Q=sortrows(Q,'trial_id');
        N=sortrows(N,'trial_id');

        gcat=G.catastrophic_branch_failure;
        qcat=Q.catastrophic_branch_failure;
        ncat=N.catastrophic_branch_failure;

        gweak=~G.weak_waveform_feasible;
        qweak=~Q.weak_waveform_feasible;

        stage1=Q.stage1_trigger;
        stage2=Q.stage2_trigger;
        trig=Q.fallback_trigger;

        rows(end+1,:)={ ... %#ok<AGROW>
            char(setName),char(ap),height(G), ...
            sum(stage1),mean(stage1),sum(stage2),mean(stage2), ...
            sum(trig),mean(trig), ...
            sum(gcat), ...
            sum(gcat & ~qcat & stage1), ...
            sum(gcat & ~qcat & stage2), ...
            sum(gcat & ~trig), ...
            sum(~gcat & qcat), ...
            sum(ncat), ...
            sum(gweak & ~qweak & stage1), ...
            sum(gweak & ~qweak & stage2), ...
            sum(~gweak & qweak)};
    end
end

S=cell2table(rows,'VariableNames',{ ...
    'validation_set','aperture_mode','n_trials', ...
    'stage1_trigger_count','stage1_actual_fraction', ...
    'stage2_trigger_count','stage2_actual_fraction_total', ...
    'total_trigger_count','total_fallback_fraction', ...
    'G0_branch_catastrophe_count', ...
    'stage1_branch_rescue_count','stage2_incremental_branch_rescue_count', ...
    'missed_G0_branch_catastrophe_count', ...
    'induced_branch_catastrophe_count','AlwaysN3_branch_catastrophe_count', ...
    'stage1_weak_rescue_count','stage2_incremental_weak_rescue_count', ...
    'induced_weak_failure_count'});

end

function R = summarize_risk_direction(O,E,cfg)

sets=unique(string(O.validation_set),'stable');
aps=unique(string(O.aperture_mode),'stable');
rows={};

for iv=1:numel(sets)
    for ia=1:numel(aps)

        setName=sets(iv); ap=aps(ia);

        X=O(string(O.validation_set)==setName & ...
            string(O.aperture_mode)==ap,:);
        G=E(string(E.validation_set)==setName & ...
            string(E.aperture_mode)==ap & ...
            string(E.method)=="G0_OriginalTop1",:);

        if isempty(X), continue; end

        X=sortrows(X,'trial_id');
        G=sortrows(G,'trial_id');
        assert(isequal(X.trial_id,G.trial_id));

        y=logical(G.catastrophic_branch_failure);
        auc1=rank_auc(double(X.refined_lr_asymmetry),y);

        residual=~X.stage1_trigger;
        y2=y(residual);
        score2=-double(X.fivebin_peak_fraction(residual)); % low raw -> risky
        auc2=rank_auc(score2,y2);

        nfail=sum(y);
        nsuccess=sum(~y);
        nfail2=sum(y2);
        nsuccess2=sum(~y2);

        if nfail>0
            capture1=sum(y & X.stage1_trigger)/nfail;
            captureTotal=sum(y & X.fallback_trigger)/nfail;
        else
            capture1=NaN;
            captureTotal=NaN;
        end

        if nfail2>0
            capture2=sum(y2 & X.stage2_trigger(residual))/nfail2;
        else
            capture2=NaN;
        end

        direction1_flag=isfinite(auc1) && ...
            nfail>=cfg.min_auc_positive_cases_for_direction_flag && ...
            nsuccess>=cfg.min_auc_positive_cases_for_direction_flag && ...
            auc1<cfg.direction_reversal_auc_threshold;

        direction2_flag=isfinite(auc2) && ...
            nfail2>=cfg.min_auc_positive_cases_for_direction_flag && ...
            nsuccess2>=cfg.min_auc_positive_cases_for_direction_flag && ...
            auc2<cfg.direction_reversal_auc_threshold;

        rows(end+1,:)={ ... %#ok<AGROW>
            char(setName),char(ap),height(X),nfail,nsuccess, ...
            auc1,capture1, ...
            sum(residual),nfail2,nsuccess2,auc2,capture2,captureTotal, ...
            direction1_flag,direction2_flag};
    end
end

R=cell2table(rows,'VariableNames',{ ...
    'validation_set','aperture_mode','n_trials', ...
    'G0_failure_count','G0_success_count', ...
    'stage1_refinedLR_directional_AUC','stage1_failure_capture_fraction', ...
    'stage2_residual_pool_n','stage2_residual_failure_count', ...
    'stage2_residual_success_count','stage2_FiveBin_directional_AUC', ...
    'stage2_residual_failure_capture_fraction', ...
    'total_failure_capture_fraction', ...
    'stage1_direction_reversal_flag','stage2_direction_reversal_flag'});

end

%% =========================================================================
function auc = rank_auc(score,label)

score=double(score(:));
label=logical(label(:));
valid=isfinite(score);
score=score(valid); label=label(valid);

n1=sum(label); n0=sum(~label);
if n1==0 || n0==0
    auc=NaN;
    return;
end

r=tied_ranks(score);
auc=(sum(r(label))-n1*(n1+1)/2)/(n1*n0);

end

%% =========================================================================
function r = tied_ranks(x)

[xs,ord]=sort(x);
r=zeros(size(x));
n=numel(x);
i=1;
while i<=n
    j=i;
    while j<n && xs(j+1)==xs(i)
        j=j+1;
    end
    rr=(i+j)/2;
    r(ord(i:j))=rr;
    i=j+1;
end

end

function O = summarize_operator_gap(E)

sets=unique(string(E.validation_set),'stable');
aps=unique(string(E.aperture_mode),'stable');
rows={};

for iv=1:numel(sets)
    for ia=1:numel(aps)

        idx=string(E.validation_set)==sets(iv) & ...
            string(E.aperture_mode)==aps(ia);

        X=E(idx & string(E.method)=="ORACLE_ExactSubtraction",:);
        N=E(idx & string(E.method)=="ORACLE_TrueBetaEta_Notch3",:);
        P=E(idx & string(E.method)=="Proposed_Frozen_Staged",:);

        if isempty(P), continue; end

        medExact=median(X.weak_waveform_error_ratio,'omitnan');
        medNotch=median(N.weak_waveform_error_ratio,'omitnan');
        medProp=median(P.weak_waveform_error_ratio,'omitnan');

        rows(end+1,:)={ ... %#ok<AGROW>
            char(sets(iv)),char(aps(ia)),height(P), ...
            mean(X.weak_waveform_feasible),medExact, ...
            mean(N.weak_waveform_feasible),medNotch, ...
            mean(P.weak_waveform_feasible),medProp, ...
            medNotch-medExact,medProp-medNotch};
    end
end

O=cell2table(rows,'VariableNames',{ ...
    'validation_set','aperture_mode','n_trials', ...
    'oracle_exact_feasible_rate','oracle_exact_median_E', ...
    'oracle_notch_feasible_rate','oracle_notch_median_E', ...
    'proposed_feasible_rate','proposed_median_E', ...
    'finite_window_operator_floor_increment_medianE', ...
    'practical_estimation_gap_increment_medianE'});

end

function U = summarize_upstream_errors(E)

P=E(string(E.method)=="Proposed_Frozen_Staged",:);
sets=unique(string(P.validation_set),'stable');
aps=unique(string(P.aperture_mode),'stable');
rows={};

for iv=1:numel(sets)
    for ia=1:numel(aps)

        M=P(string(P.validation_set)==sets(iv) & ...
            string(P.aperture_mode)==aps(ia),:);
        if isempty(M), continue; end

        rows(end+1,:)={ ... %#ok<AGROW>
            char(sets(iv)),char(aps(ia)),height(M), ...
            median(M.strong_beta_abs_error_over_W,'omitnan'), ...
            local_percentile(M.strong_beta_abs_error_over_W,90), ...
            local_percentile(M.strong_beta_abs_error_over_W,99), ...
            max(M.strong_beta_abs_error_over_W), ...
            median(M.eta_abs_error_bins,'omitnan'), ...
            local_percentile(M.eta_abs_error_bins,90), ...
            local_percentile(M.eta_abs_error_bins,99), ...
            max(M.eta_abs_error_bins)};
    end
end

U=cell2table(rows,'VariableNames',{ ...
    'validation_set','aperture_mode','n_trials', ...
    'median_strong_beta_error_over_W','p90_strong_beta_error_over_W', ...
    'p99_strong_beta_error_over_W','max_strong_beta_error_over_W', ...
    'median_eta_error_bins','p90_eta_error_bins','p99_eta_error_bins', ...
    'max_eta_error_bins'});

end

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

function V = build_formal_verdict(S,P,Stage,Risk,F,cfg)

firewall_pass=F.overall_pass(1);

direction_reversal=any(Risk.stage1_direction_reversal_flag) || ...
    any(Risk.stage2_direction_reversal_flag);

induced_branch=sum(P.Proposed_induced_branch_catastrophe);
persistent_n3_branch=sum(P.persistent_branch_failure_after_N3);

% Claim-2 practical-chain check on DenseRisk:
D=S(string(S.validation_set)=="DenseRisk" & ...
    ismember(string(S.method),["G0_OriginalTop1","Proposed_Frozen_Staged"]),:);

strict_dense_gain=false;
if ~isempty(D)
    aps=unique(string(D.aperture_mode),'stable');
    gain=zeros(numel(aps),1);
    for i=1:numel(aps)
        G=D(string(D.aperture_mode)==aps(i) & ...
            string(D.method)=="G0_OriginalTop1",:);
        Q=D(string(D.aperture_mode)==aps(i) & ...
            string(D.method)=="Proposed_Frozen_Staged",:);
        if ~isempty(G) && ~isempty(Q)
            gain(i)=G.catastrophic_branch_failure_rate- ...
                Q.catastrophic_branch_failure_rate;
        end
    end
    strict_dense_gain=all(gain>0);
end

if ~firewall_pass
    verdict="FAIL_ORACLE_FIREWALL";
elseif direction_reversal
    verdict="POLICY_FREEZE_FALSIFIED_RISK_DIRECTION";
elseif persistent_n3_branch>0
    verdict="LIMITATION_NEIGHBOR3_NOT_BRANCH_SAFE";
elseif induced_branch>0
    verdict="PASS_WITH_INDUCED_BRANCH_EVENTS_REVIEW";
elseif ~strict_dense_gain
    verdict="CLAIM2_WEAKENED_NO_STRICT_DENSERISK_GAIN";
else
    verdict="PASS_NOISELESS_FORMAL_CLOSURE";
end

V=table(verdict,firewall_pass,direction_reversal, ...
    induced_branch,persistent_n3_branch,strict_dense_gain, ...
    cfg.stage1_budget,cfg.stage2_conditional_budget,cfg.removal_window_bins, ...
    'VariableNames',{ ...
    'overall_verdict','oracle_firewall_pass','risk_direction_reversal', ...
    'total_proposed_induced_branch_catastrophes', ...
    'total_persistent_branch_failures_after_N3', ...
    'strict_positive_branch_gain_on_both_DenseRisk_apertures', ...
    'frozen_b1','frozen_b2','frozen_removal_window_bins'});

end

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

function write_feedback_bundle(cfg,S,P,Stage,Risk,Gap,U,F,V,E)

path=fullfile(cfg.output_dir,cfg.feedback_bundle_name);
fid=fopen(path,'w');
if fid<0
    error('EXP010B:FeedbackBundleOpenFailed','Cannot open feedback bundle.');
end
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP010-B / NOISELESS PRACTICAL NON-ORACLE FORMAL CLOSURE\n');
fprintf(fid,'=======================================================\n');
fprintf(fid,'Noise/clutter: OFF\n');
fprintf(fid,'SNR: PENDING-DEFINITION\n');
fprintf(fid,'Policy: Refined-LR %.2f -> FiveBin %.2f conditional -> Neighbor-3\n', ...
    cfg.stage1_budget,cfg.stage2_conditional_budget);
fprintf(fid,'Removal: recenter -> PlateauAwareTol %.2f -> %d-bin notch -> inverse -> undo recenter\n', ...
    cfg.frac_domain_peak_gate,cfg.removal_window_bins);
fprintf(fid,'Validation sets: %s\n',strjoin(cfg.validation_sets,', '));
fprintf(fid,'DenseRisk source: %s\n',cfg.dense_risk_states_path);
fprintf(fid,'ORACLE_FIREWALL = %d\n',F.overall_pass(1));
fprintf(fid,'FORMAL_VERDICT = %s\n\n',string(V.overall_verdict(1)));

write_table_tsv(fid,'FORMAL VERDICT',V);
write_table_tsv(fid,'METHOD SUMMARY',S);
write_table_tsv(fid,'PAIRED OUTCOMES',P);
write_table_tsv(fid,'STAGE ALLOCATION / RESCUE',Stage);
write_table_tsv(fid,'RISK-DIRECTION AUDIT',Risk);
write_table_tsv(fid,'OPERATOR / ESTIMATION GAP',Gap);
write_table_tsv(fid,'UPSTREAM ESTIMATION ERRORS',U);
write_table_tsv(fid,'ORACLE FIREWALL',F);

fprintf(fid,'\nCLAIM-CLOSURE INTERPRETATION RULES\n');
fprintf(fid,'1) Truth may evaluate, but truth may not decide.\n');
fprintf(fid,'2) DenseRisk is a frozen evaluation stress set; its truth metadata never enters Proposed.\n');
fprintf(fid,'3) AUC < 0.5 with sufficient positive/negative cases flags risk-direction reversal; do not retune.\n');
fprintf(fid,'4) Any induced or persistent Neighbor-3 branch failure is reported as a limitation; do not upgrade to Neighbor-5.\n');
fprintf(fid,'5) Proposed branch gain must be interpreted together with paired rescue/harm and normalized cost.\n');
fprintf(fid,'6) If this formal noiseless closure passes, STOP deterministic expansion and proceed to SNR/noise-definition audit.\n');

fprintf(fid,'\nTOTAL EVALUATION ROWS = %d\n',height(E));

end

%% =========================================================================
function write_table_tsv(fid,titleText,T)

fprintf(fid,'\n[%s]\n',titleText);
vars=string(T.Properties.VariableNames);
fprintf(fid,'%s\n',strjoin(vars,char(9)));

for i=1:height(T)
    vals=strings(1,width(T));
    for j=1:width(T)
        vals(j)=scalar_to_string(T{i,j});
    end
    fprintf(fid,'%s\n',strjoin(vals,char(9)));
end

end

%% =========================================================================
function s = scalar_to_string(x)

if iscell(x)
    x=x{1};
end

if isstring(x)
    s=x(1);
elseif ischar(x)
    s=string(x);
elseif islogical(x)
    s=string(double(x));
elseif isnumeric(x)
    if isempty(x)
        s="";
    elseif isscalar(x)
        if isnan(x)
            s="NaN";
        elseif isinf(x)
            s=string(x);
        else
            s=string(sprintf('%.12g',x));
        end
    else
        s=string(mat2str(x));
    end
elseif iscategorical(x)
    s=string(x);
else
    s=string(x);
end

end

function make_figures(E,S,Risk,Gap,Stage,cfg)

sets=unique(string(E.validation_set),'stable');
aps=unique(string(E.aperture_mode),'stable');
methods=["G0_OriginalTop1","Proposed_Frozen_Staged","Always_Neighbor3"];

% Figure 1 — branch reliability versus normalized cost.
for iv=1:numel(sets)
    fig=figure('Visible',cfg.figure_visible);
    hold on;
    for ia=1:numel(aps)
        M=S(string(S.validation_set)==sets(iv) & ...
            string(S.aperture_mode)==aps(ia) & ...
            ismember(string(S.method),methods),:);

        scatter(M.normalized_branch_cost, ...
            M.catastrophic_branch_failure_rate,55,'filled', ...
            'DisplayName',char(aps(ia)));

        for j=1:height(M)
            text(M.normalized_branch_cost(j), ...
                M.catastrophic_branch_failure_rate(j), ...
                " "+string(M.method(j)),'FontSize',8, ...
                'Interpreter','none');
        end
    end

    grid on;
    xlabel('Normalized branch cost: G0=0, Always-N3=1');
    ylabel('Catastrophic branch failure rate');
    title("EXP010-B "+sets(iv)+": practical branch reliability", ...
        'Interpreter','none');
    legend('Location','best','Interpreter','none');

    exportgraphics(fig,fullfile(cfg.figure_dir, ...
        sprintf('fig01_branch_cost_%s.png',lower(char(sets(iv))))), ...
        'Resolution',200);
    close(fig);
end

% Figure 2 — downstream weak feasibility.
for iv=1:numel(sets)
    fig=figure('Visible',cfg.figure_visible);
    hold on;
    for im=1:numel(methods)
        y=nan(size(aps));
        for ia=1:numel(aps)
            M=S(string(S.validation_set)==sets(iv) & ...
                string(S.aperture_mode)==aps(ia) & ...
                string(S.method)==methods(im),:);
            if ~isempty(M), y(ia)=M.weak_waveform_feasible_rate; end
        end
        plot(1:numel(aps),y,'-o','LineWidth',1.2, ...
            'DisplayName',char(methods(im)));
    end

    xticks(1:numel(aps)); xticklabels(aps);
    ylim([0,1]); grid on;
    ylabel('Weak waveform feasible rate (E <= 1)');
    title("EXP010-B "+sets(iv)+": downstream weak recovery", ...
        'Interpreter','none');
    legend('Location','best','Interpreter','none');

    exportgraphics(fig,fullfile(cfg.figure_dir, ...
        sprintf('fig02_weak_recovery_%s.png',lower(char(sets(iv))))), ...
        'Resolution',200);
    close(fig);
end

% Figure 3 — risk-direction AUC.
fig=figure('Visible',cfg.figure_visible);
x=1:height(Risk);
plot(x,Risk.stage1_refinedLR_directional_AUC,'-o','LineWidth',1.2, ...
    'DisplayName','Stage1 Refined-LR');
hold on;
plot(x,Risk.stage2_FiveBin_directional_AUC,'-s','LineWidth',1.2, ...
    'DisplayName','Stage2 FiveBin residual pool');
yline(0.5,'--','Chance / reversal boundary');
grid on; ylim([0,1]);
xticks(x);
xticklabels(string(Risk.validation_set)+" / "+string(Risk.aperture_mode));
xtickangle(20);
ylabel('Directional AUC');
title('Frozen risk-direction audit');
legend('Location','best','Interpreter','none');
exportgraphics(fig,fullfile(cfg.figure_dir,'fig03_risk_direction_auc.png'), ...
    'Resolution',200);
close(fig);

% Figure 4 — operator ownership ladder.
fig=figure('Visible',cfg.figure_visible);
x=1:height(Gap);
plot(x,Gap.oracle_exact_median_E,'-o','LineWidth',1.2, ...
    'DisplayName','Oracle exact subtraction');
hold on;
plot(x,Gap.oracle_notch_median_E,'-s','LineWidth',1.2, ...
    'DisplayName','Oracle true beta/eta + notch3');
plot(x,Gap.proposed_median_E,'-d','LineWidth',1.2, ...
    'DisplayName','Proposed practical');
grid on;
xticks(x);
xticklabels(string(Gap.validation_set)+" / "+string(Gap.aperture_mode));
xtickangle(20);
ylabel('Median weak waveform error E');
title('Practical-chain ownership ladder');
legend('Location','best','Interpreter','none');
exportgraphics(fig,fullfile(cfg.figure_dir,'fig04_operator_gap_ladder.png'), ...
    'Resolution',200);
close(fig);

% Figure 5 — branch rescue allocation.
fig=figure('Visible',cfg.figure_visible);
x=1:height(Stage);
plot(x,Stage.stage1_branch_rescue_count,'-o','LineWidth',1.2, ...
    'DisplayName','Stage-1 branch rescue');
hold on;
plot(x,Stage.stage2_incremental_branch_rescue_count,'-s','LineWidth',1.2, ...
    'DisplayName','Stage-2 incremental rescue');
plot(x,Stage.missed_G0_branch_catastrophe_count,'-d','LineWidth',1.2, ...
    'DisplayName','Missed G0 catastrophes');
grid on;
xticks(x);
xticklabels(string(Stage.validation_set)+" / "+string(Stage.aperture_mode));
xtickangle(20);
ylabel('Trial count');
title('Frozen staged-policy branch outcome');
legend('Location','best','Interpreter','none');
exportgraphics(fig,fullfile(cfg.figure_dir,'fig05_stage_branch_rescue.png'), ...
    'Resolution',200);
close(fig);

end

