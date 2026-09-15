function results = exp10c_noise_robustness(run_mode)
%EXP10C_NOISE_ROBUSTNESS
% EXP010-C — Frozen-Policy Additive-Noise Robustness
%
% Usage:
%   results = exp10c_noise_robustness("smoke");
%   results = exp10c_noise_robustness("dense_formal");
%   results = exp10c_noise_robustness("original_anchor");
%   results = exp10c_noise_robustness("all_formal");
%
% SCIENTIFIC PURPOSE
% ------------------
% Validate the already-frozen practical non-oracle chain under additive
% circular complex Gaussian noise. The method itself is NOT redesigned.
%
% FROZEN causal reading:
%
%   SNR_s
%     -> practical strong-beta error
%     -> branch-recovery validity
%     -> weak-component recovery
%
% IMPORTANT:
%   * AWGN is NOT used as a sea-clutter model.
%   * Truth may evaluate, but truth may not decide.
%   * The rank-budget scheduler does NOT receive true SNR.
%   * Ranking is performed once over the complete
%       validation-set x aperture heterogeneous-SNR processing pool.

if nargin < 1
    run_mode = "smoke";
end
cfg = config_exp10c_noise_robustness(run_mode);

fprintf('\n============================================================\n');
fprintf('EXP010-C Frozen-Policy Additive-Noise Robustness\n');
fprintf('============================================================\n');
fprintf('Run mode: %s\n',cfg.run_mode);
fprintf('Noise: circular complex AWGN\n');
fprintf('SNR reference: strong-component per-sample input power\n');
fprintf('Policy: Refined-LR b1=%.2f -> FiveBin b2=%.2f -> N3\n', ...
    cfg.stage1_budget,cfg.stage2_conditional_budget);
fprintf('Scheduler: one heterogeneous-SNR pool per validation-set/aperture\n');
fprintf('Sea clutter: OUT OF SCOPE for EXP010-C\n\n');

validate_cfg_contract_exp10c(cfg);
ensure_output_dirs_exp10c(cfg);
run_startup_self_tests_exp10c(cfg);

jobSummaries = table();
jobPaired = table();
jobStage = table();
jobRisk = table();
jobUpstream = table();
jobValidity = table();
jobFirewalls = table();
jobInventory = table();

for iv = 1:numel(cfg.validation_sets)
    validation_set = cfg.validation_sets(iv);

    for ia = 1:numel(cfg.aperture_modes)
        aperture_mode = cfg.aperture_modes(ia);
        proc = build_processing_context(aperture_mode,cfg);

        truth = build_truth_table(validation_set,aperture_mode,proc,cfg);
        if cfg.run_mode=="smoke" && height(truth)>cfg.smoke_physical_cap_per_job
            idx = unique(round(linspace(1,height(truth),cfg.smoke_physical_cap_per_job)));
            truth = truth(idx,:);
            truth.trial_id = (1:height(truth)).';
        end

        [snr_grid_db,mc_count] = protocol_for_job(validation_set,cfg);
        cases = build_noise_case_table(truth,snr_grid_db,mc_count,proc,cfg, ...
            validation_set,aperture_mode);

        job_tag = sprintf('%s_%s',lower(char(validation_set)), ...
            lower(char(aperture_mode)));
        job_dir = fullfile(cfg.output_dir,job_tag);
        checkpoint_dir = fullfile(cfg.checkpoint_root,job_tag);
        if ~exist(job_dir,'dir'), mkdir(job_dir); end
        if ~exist(checkpoint_dir,'dir'), mkdir(checkpoint_dir); end

        fprintf('\n------------------------------------------------------------\n');
        fprintf('JOB: %s / %s\n',validation_set,aperture_mode);
        fprintf('Physical states: %d\n',height(truth));
        fprintf('SNR levels: %s dB\n',mat2str(snr_grid_db));
        fprintf('MC/state/SNR: %d\n',mc_count);
        fprintf('Noise cases: %d\n',height(cases));
        fprintf('------------------------------------------------------------\n');

        writetable(truth,fullfile(job_dir,'truth_physical_states.csv'));
        writetable(cases,fullfile(job_dir,'seed_ledger_and_snr_metadata.csv'));

        % -----------------------------
        % PASS 1: online-safe features
        % -----------------------------
        job_tic=tic;
        stage0_tic=tic;
        O0 = run_stage0_with_checkpoints(truth,cases,proc,cfg, ...
            checkpoint_dir,job_tag);
        stage0_seconds=toc(stage0_tic);

        % Frozen scheduler sees ONLY online-safe O0.
        O = apply_frozen_scheduler_exp10c(O0,cfg);

        % This online file intentionally contains no SNR / truth metadata.
        writetable(O,fullfile(job_dir,'online_features_and_scheduler.csv'));

        % -----------------------------
        % PASS 2: downstream + evaluation
        % -----------------------------
        downstream_tic=tic;
        E = run_downstream_evaluation_with_checkpoints( ...
            truth,cases,O,proc,cfg,checkpoint_dir,job_tag);
        downstream_seconds=toc(downstream_tic);
        job_seconds=toc(job_tic);

        if cfg.write_case_level_csv
            writetable(E,fullfile(job_dir,'evaluation_trials.csv'));
        end

        % Per-SNR summaries.
        S = summarize_methods_by_snr(E,cfg);
        P = summarize_paired_by_snr(E);
        Stage = summarize_stage_by_snr(E);
        Risk = summarize_risk_by_snr(O,cases,E,cfg);
        U = summarize_upstream_by_snr(E);
        F = oracle_firewall_audit_exp10c(O,E,cfg);
        V = summarize_noise_validity(S,P,Risk,F,cfg);

        writetable(S,fullfile(job_dir,'method_summary_by_snr.csv'));
        writetable(P,fullfile(job_dir,'paired_outcomes_by_snr.csv'));
        writetable(Stage,fullfile(job_dir,'stage_allocation_by_snr.csv'));
        writetable(Risk,fullfile(job_dir,'risk_direction_by_snr.csv'));
        writetable(U,fullfile(job_dir,'upstream_errors_by_snr.csv'));
        writetable(F,fullfile(job_dir,'oracle_firewall_audit.csv'));
        writetable(V,fullfile(job_dir,'noise_validity_summary.csv'));

        J = table(string(validation_set),string(aperture_mode), ...
            height(truth),height(cases),numel(snr_grid_db),mc_count, ...
            stage0_seconds,downstream_seconds,job_seconds,job_seconds/max(height(cases),1), ...
            'VariableNames',{'validation_set','aperture_mode', ...
            'n_physical_states','n_noise_cases','n_snr_levels','mc_count', ...
            'stage0_seconds','downstream_seconds','job_seconds','seconds_per_noise_case'});

        jobSummaries = [jobSummaries; S]; %#ok<AGROW>
        jobPaired = [jobPaired; P]; %#ok<AGROW>
        jobStage = [jobStage; Stage]; %#ok<AGROW>
        jobRisk = [jobRisk; Risk]; %#ok<AGROW>
        jobUpstream = [jobUpstream; U]; %#ok<AGROW>
        jobValidity = [jobValidity; V]; %#ok<AGROW>
        jobFirewalls = [jobFirewalls; add_job_identity(F,validation_set,aperture_mode)]; %#ok<AGROW>
        jobInventory = [jobInventory; J]; %#ok<AGROW>

        save(fullfile(job_dir,'job_summary.mat'), ...
            'S','P','Stage','Risk','U','F','V','J','-v7.3');

        fprintf('JOB COMPLETE: %s / %s\n',validation_set,aperture_mode);
    end
end
1
% Aggregate compact outputs.
writetable(jobInventory,fullfile(cfg.output_dir,'run_inventory.csv'));
writetable(jobSummaries,fullfile(cfg.output_dir,'method_summary_by_snr_all.csv'));
writetable(jobPaired,fullfile(cfg.output_dir,'paired_outcomes_by_snr_all.csv'));
writetable(jobStage,fullfile(cfg.output_dir,'stage_allocation_by_snr_all.csv'));
writetable(jobRisk,fullfile(cfg.output_dir,'risk_direction_by_snr_all.csv'));
writetable(jobUpstream,fullfile(cfg.output_dir,'upstream_errors_by_snr_all.csv'));
writetable(jobValidity,fullfile(cfg.output_dir,'noise_validity_summary_all.csv'));
writetable(jobFirewalls,fullfile(cfg.output_dir,'oracle_firewall_audit_all.csv'));

overall = build_overall_status(jobValidity,jobFirewalls,cfg);
writetable(overall,fullfile(cfg.output_dir,'overall_status.csv'));

make_noise_figures(jobSummaries,jobRisk,jobUpstream,cfg);
write_feedback_bundle_exp10c(cfg,jobInventory,jobSummaries,jobPaired, ...
    jobStage,jobRisk,jobUpstream,jobValidity,jobFirewalls,overall);

save(fullfile(cfg.output_dir,'exp10c_noise_robustness_results.mat'), ...
    'cfg','jobInventory','jobSummaries','jobPaired','jobStage', ...
    'jobRisk','jobUpstream','jobValidity','jobFirewalls','overall','-v7.3');

results = struct();
results.cfg = cfg;
results.inventory = jobInventory;
results.summary = jobSummaries;
results.paired = jobPaired;
results.stage = jobStage;
results.risk = jobRisk;
results.upstream = jobUpstream;
results.validity = jobValidity;
results.firewall = jobFirewalls;
results.overall = overall;

fprintf('\n============================================================\n');
fprintf('EXP010-C %s COMPLETE\n',upper(char(cfg.run_mode)));
fprintf('Outputs: %s\n',cfg.output_dir);
fprintf('Feedback bundle: %s\n',fullfile(cfg.output_dir,cfg.feedback_bundle_name));
fprintf('OVERALL STATUS: %s\n',string(overall.overall_status(1)));
fprintf('============================================================\n');

if ~all(jobFirewalls.overall_pass)
    error('EXP010C:OracleFirewallFailed', ...
        'Oracle firewall audit failed. Do not interpret this run.');
end

end

%% =========================================================================
function ensure_output_dirs_exp10c(cfg)
if ~exist(cfg.output_dir,'dir'), mkdir(cfg.output_dir); end
if ~exist(cfg.figure_dir,'dir'), mkdir(cfg.figure_dir); end
if ~exist(cfg.checkpoint_root,'dir'), mkdir(cfg.checkpoint_root); end
end

%% =========================================================================
function validate_cfg_contract_exp10c(cfg)

assert(cfg.noise_model=="circular_complex_AWGN", ...
    'Noise model changed from protocol freeze.');
assert(cfg.snr_reference=="strong_component_per_sample_input_power", ...
    'SNR reference changed from protocol freeze.');
assert(isequal(cfg.snr_grid_dense_db,[-10 -5 0 5 10 15 20]), ...
    'DenseRisk SNR grid changed.');
assert(isequal(cfg.snr_grid_original_db,[-10 0 10 20]), ...
    'OriginalGrid anchor SNR grid changed.');
assert(cfg.mc_dense==10,'DenseRisk MC count changed.');
assert(cfg.mc_original==5,'OriginalGrid MC count changed.');
assert(abs(cfg.stage1_budget-0.20)<eps,'Stage-1 budget changed.');
assert(abs(cfg.stage2_conditional_budget-0.10)<eps,'Stage-2 budget changed.');
assert(cfg.neighbor_radius==1,'Neighbor-3 changed.');
assert(cfg.removal_window_bins==3,'Removal width changed.');
assert(abs(cfg.catastrophic_error_threshold_bins-0.10)<eps, ...
    'Catastrophic threshold changed.');
assert(abs(cfg.branch_match_tolerance_bins-0.02)<eps, ...
    'Branch match tolerance changed.');

end

%% =========================================================================
function [snr_grid_db,mc_count] = protocol_for_job(validation_set,cfg)

if cfg.run_mode=="smoke"
    snr_grid_db = cfg.smoke_snr_db;
    mc_count = cfg.smoke_mc;
    return;
end

if validation_set=="DenseRisk"
    snr_grid_db = cfg.snr_grid_dense_db;
    mc_count = cfg.mc_dense;
elseif validation_set=="OriginalGrid"
    snr_grid_db = cfg.snr_grid_original_db;
    mc_count = cfg.mc_original;
else
    error('EXP010C:UnknownValidationSet','Unknown validation set.');
end

end

%% =========================================================================
function C = build_noise_case_table(T,snr_grid_db,mc_count,proc,cfg, ...
    validation_set,aperture_mode)
% Truth/SNR metadata table. This table is NEVER passed into the frozen
% scheduler. It is used for synthesis, audit, and evaluation only.

nPhys = height(T);
nS = numel(snr_grid_db);
nCases = nPhys*nS*mc_count;

case_id = zeros(nCases,1);
physical_trial_id = zeros(nCases,1);
snr_db = zeros(nCases,1);
snr_index = zeros(nCases,1);
mc_index = zeros(nCases,1);
seed = zeros(nCases,1,'uint32');
noise_variance_expected = zeros(nCases,1);
strong_power = zeros(nCases,1);
weak_power = zeros(nCases,1);
mixture_power = zeros(nCases,1);
weak_snr_db = zeros(nCases,1);
mixture_snr_db = zeros(nCases,1);

% Physical powers are noise-independent.
Ps=zeros(nPhys,1); Pw=zeros(nPhys,1); Pm=zeros(nPhys,1);
for ip=1:nPhys
    [s,w] = synth_clean_components(T(ip,:),proc);
    Ps(ip)=mean(abs(s).^2);
    Pw(ip)=mean(abs(w).^2);
    Pm(ip)=mean(abs(s+w).^2);
end

k=0;
vcode = validation_code(validation_set);
acode = aperture_code(aperture_mode);

for ip=1:nPhys
    for is=1:nS
        for imc=1:mc_count
            k=k+1;
            thisSNR=snr_grid_db(is);
            sigma2=Ps(ip)/(10^(thisSNR/10));

            case_id(k)=k;
            physical_trial_id(k)=ip;
            snr_db(k)=thisSNR;
            snr_index(k)=is;
            mc_index(k)=imc;
            seed(k)=make_case_seed(cfg.base_seed,vcode,acode,ip,is,imc);
            noise_variance_expected(k)=sigma2;
            strong_power(k)=Ps(ip);
            weak_power(k)=Pw(ip);
            mixture_power(k)=Pm(ip);
            weak_snr_db(k)=10*log10(Pw(ip)/sigma2);
            mixture_snr_db(k)=10*log10(Pm(ip)/sigma2);
        end
    end
end

C=table(case_id,physical_trial_id,snr_db,snr_index,mc_index,seed, ...
    noise_variance_expected,strong_power,weak_power,mixture_power, ...
    weak_snr_db,mixture_snr_db);

end

%% =========================================================================
function c = validation_code(validation_set)
if validation_set=="DenseRisk"
    c=uint64(17);
elseif validation_set=="OriginalGrid"
    c=uint64(29);
else
    c=uint64(43);
end
end

function c = aperture_code(aperture_mode)
if aperture_mode=="Paper1s"
    c=uint64(101);
elseif aperture_mode=="BeamDerived"
    c=uint64(211);
else
    c=uint64(307);
end
end

function s = make_case_seed(base,vcode,acode,physical_id,snr_index,mc_index)
% Stable seed; method identity is intentionally absent.
M=uint64(4294967291); % largest 32-bit prime < 2^32
u=uint64(base);
u=u + uint64(vcode)*uint64(1000003);
u=u + uint64(acode)*uint64(1000033);
u=u + uint64(physical_id)*uint64(1000037);
u=u + uint64(snr_index)*uint64(1000039);
u=u + uint64(mc_index)*uint64(1000081);
u=mod(u,M);
if u==0, u=uint64(1); end
s=uint32(u);
end

%% =========================================================================
function [s,w] = synth_clean_components(Trow,proc)

eta=Trow.true_eta_bins;
b=eta/proc.N;
s=synth_discrete_lfm(proc.N,1,Trow.true_a_strong,b,0);
w=synth_discrete_lfm(proc.N,Trow.weak_to_strong_ratio, ...
    Trow.true_a_weak,b,Trow.relative_phase_rad);

end

%% =========================================================================
function [X,realized_noise_power] = synthesize_noisy_cases(T,C,idx,proc)
% Synthesis/evaluation layer. Truth is allowed here, but this function's
% output X is the only signal input to the online method.

n=numel(idx);
X=complex(zeros(n,proc.N));
realized_noise_power=zeros(n,1);

for j=1:n
    ic=idx(j);
    ip=C.physical_trial_id(ic);
    [s,w]=synth_clean_components(T(ip,:),proc);

    sigma2=C.noise_variance_expected(ic);
    stream=RandStream('mt19937ar','Seed',double(C.seed(ic)));
    noise=sqrt(sigma2/2) .* ...
        (randn(stream,1,proc.N)+1j*randn(stream,1,proc.N));

    X(j,:)=s+w+noise;
    realized_noise_power(j)=mean(abs(noise).^2);
end

end

%% =========================================================================
function O = run_stage0_with_checkpoints(T,C,proc,cfg,checkpoint_dir,job_tag)

n=height(C);
blocks=make_blocks(n,cfg.checkpoint_block_size);
chunkTables=cell(numel(blocks),1);
signature=job_signature(cfg,job_tag,C,proc);

for ib=1:numel(blocks)
    idx=blocks{ib};
    path=fullfile(checkpoint_dir,sprintf('stage0_%04d.mat',ib));

    if cfg.resume && exist(path,'file')
        Q=load(path,'Ochunk','signature_saved');
        if ~isfield(Q,'signature_saved') || ~strcmp(Q.signature_saved,signature)
            error('EXP010C:CheckpointSignatureMismatch', ...
                'Stage-0 checkpoint signature mismatch: %s',path);
        end
        chunkTables{ib}=Q.Ochunk;
        fprintf('  stage0 resume: block %d/%d (%d cases)\n', ...
            ib,numel(blocks),numel(idx));
        continue;
    end

    [X,~]=synthesize_noisy_cases(T,C,idx,proc);
    Ochunk=extract_online_features_exp10c(X,C.case_id(idx),proc,cfg);

    signature_saved=signature; %#ok<NASGU>
    save(path,'Ochunk','signature_saved','-v7.3');
    chunkTables{ib}=Ochunk;

    fprintf('  stage0 computed: block %d/%d (%d cases)\n', ...
        ib,numel(blocks),numel(idx));
end

O=vertcat(chunkTables{:});
O=sortrows(O,'case_id');
assert(isequal(O.case_id,C.case_id),'Stage-0 case ordering mismatch.');

end

%% =========================================================================
function O = extract_online_features_exp10c(X,case_ids,proc,cfg)
% ONLINE-SAFE. No truth/SNR metadata is accepted.

n=size(X,1);
[beta_hat,beta_score]=estimate_beta_fixed_domain_batch(X,proc,cfg);

g0_nu=nan(n,1);
g0_obj=nan(n,1);
g0_evals=nan(n,1);
coarse_seed=nan(n,1);
fivebin=nan(n,1);
refined_lr=nan(n,1);

for i=1:n
    a_hat=tan(beta_hat(i));
    G=g0_with_risk_state(X(i,:),a_hat,cfg);
    g0_nu(i)=G.nu_hat_bins;
    g0_obj(i)=G.objective_at_hat;
    g0_evals(i)=G.n_objective_evals;
    coarse_seed(i)=G.coarse_seed_primary;
    fivebin(i)=G.fivebin_peak_fraction;
    refined_lr(i)=G.refined_lr_asymmetry;
end

O=table(case_ids(:),beta_hat,beta_score,coarse_seed,g0_nu,g0_obj, ...
    g0_evals,fivebin,refined_lr, ...
    'VariableNames',{'case_id','beta_hat_strong_rad','beta_search_score', ...
    'g0_coarse_seed_bins','g0_nu_hat_bins','g0_objective', ...
    'g0_objective_evals','fivebin_peak_fraction','refined_lr_asymmetry'});

end

%% =========================================================================
function O = apply_frozen_scheduler_exp10c(O,cfg)
% ONLINE-SAFE.
% Crucially, this function receives neither C nor T, and therefore cannot
% split/rank by true SNR or any other truth metadata.

[stage1,sel1]=tie_inclusive_top(O.refined_lr_asymmetry,cfg.stage1_budget);
remaining=~stage1;
stage2=false(height(O),1);

if any(remaining)
    risk2=-O.fivebin_peak_fraction(remaining); % low raw -> high risk
    [m2,sel2]=tie_inclusive_top(risk2,cfg.stage2_conditional_budget);
    idx=find(remaining);
    stage2(idx(m2))=true;
else
    sel2=empty_selection();
end

O.stage1_trigger=stage1;
O.stage2_trigger=stage2;
O.fallback_trigger=stage1|stage2;
O.stage1_actual_fraction=repmat(sel1.actual_fraction,height(O),1);
O.stage2_actual_fraction_conditional=repmat(sel2.actual_fraction,height(O),1);
O.total_fallback_fraction_global=repmat(mean(O.fallback_trigger),height(O),1);

end

%% =========================================================================
function E = run_downstream_evaluation_with_checkpoints( ...
    T,C,O,proc,cfg,checkpoint_dir,job_tag)

n=height(C);
blocks=make_blocks(n,cfg.checkpoint_block_size);
chunkTables=cell(numel(blocks),1);
signature=job_signature(cfg,[job_tag '_downstream'],C,proc);

for ib=1:numel(blocks)
    idx=blocks{ib};
    path=fullfile(checkpoint_dir,sprintf('downstream_eval_%04d.mat',ib));

    if cfg.resume && exist(path,'file')
        Q=load(path,'Echunk','signature_saved');
        if ~isfield(Q,'signature_saved') || ~strcmp(Q.signature_saved,signature)
            error('EXP010C:CheckpointSignatureMismatch', ...
                'Downstream checkpoint signature mismatch: %s',path);
        end
        chunkTables{ib}=Q.Echunk;
        fprintf('  downstream resume: block %d/%d (%d cases)\n', ...
            ib,numel(blocks),numel(idx));
        continue;
    end

    [X,realized_noise_power]=synthesize_noisy_cases(T,C,idx,proc);
    Osub=O(idx,:);

    [OnlineDown,Residual] = run_online_downstream_exp10c(X,Osub,proc,cfg);

    % Truth enters only after all decisions / residuals are fixed.
    Echunk=evaluate_noise_chunk(T,C,idx,X,realized_noise_power, ...
        Osub,OnlineDown,Residual,proc,cfg);

    signature_saved=signature; %#ok<NASGU>
    save(path,'Echunk','signature_saved','-v7.3');
    chunkTables{ib}=Echunk;

    fprintf('  downstream computed: block %d/%d (%d cases)\n', ...
        ib,numel(blocks),numel(idx));
end

E=vertcat(chunkTables{:});
E=sortrows(E,{'case_id','method_order'});
E.method_order=[];

end

%% =========================================================================
function [D,R] = run_online_downstream_exp10c(X,O,proc,cfg)
% ONLINE-SAFE. No truth/SNR metadata is accepted.

n=size(X,1);

n3_nu=nan(n,1); n3_obj=nan(n,1); n3_evals=nan(n,1);
final_nu=nan(n,1); final_obj=nan(n,1); final_evals=nan(n,1);

Ahat_g0=nan(n,1); Phat_g0=nan(n,1);
Ahat_prop=nan(n,1); Phat_prop=nan(n,1);
Ahat_n3=nan(n,1); Phat_n3=nan(n,1);

r0=complex(zeros(n,proc.N));
rp=complex(zeros(n,proc.N));
r3=complex(zeros(n,proc.N));

mask0=nan(n,1); maskp=nan(n,1); mask3=nan(n,1);
resnorm0=nan(n,1); resnormp=nan(n,1); resnorm3=nan(n,1);

for i=1:n
    x=X(i,:);
    a_hat=tan(O.beta_hat_strong_rad(i));

    G3=estimate_neighbor3(x,a_hat,cfg);
    n3_nu(i)=G3.nu_hat_bins;
    n3_obj(i)=G3.objective_at_hat;
    n3_evals(i)=G3.n_objective_evals;

    if O.fallback_trigger(i)
        final_nu(i)=n3_nu(i);
        final_obj(i)=n3_obj(i);
        final_evals(i)=O.g0_objective_evals(i)+cfg.refined_lr_extra_evals + ...
            (n3_evals(i)-O.g0_objective_evals(i));
    else
        final_nu(i)=O.g0_nu_hat_bins(i);
        final_obj(i)=O.g0_objective(i);
        final_evals(i)=O.g0_objective_evals(i)+cfg.refined_lr_extra_evals;
    end

    [Ahat_g0(i),Phat_g0(i)] = estimate_amp_phase_ls( ...
        x,a_hat,O.g0_nu_hat_bins(i));
    [Ahat_prop(i),Phat_prop(i)] = estimate_amp_phase_ls( ...
        x,a_hat,final_nu(i));
    [Ahat_n3(i),Phat_n3(i)] = estimate_amp_phase_ls( ...
        x,a_hat,n3_nu(i));

    [r0(i,:),info0]=practical_recenter_notch_remove( ...
        x,a_hat,O.g0_nu_hat_bins(i),cfg.removal_window_bins,cfg);
    [rp(i,:),infop]=practical_recenter_notch_remove( ...
        x,a_hat,final_nu(i),cfg.removal_window_bins,cfg);
    [r3(i,:),info3]=practical_recenter_notch_remove( ...
        x,a_hat,n3_nu(i),cfg.removal_window_bins,cfg);

    mask0(i)=info0.mask_fraction;
    maskp(i)=infop.mask_fraction;
    mask3(i)=info3.mask_fraction;
    nx=max(norm(x),cfg.small_norm_floor);
    resnorm0(i)=norm(r0(i,:))/nx;
    resnormp(i)=norm(rp(i,:))/nx;
    resnorm3(i)=norm(r3(i,:))/nx;
end

% Same frozen full-domain weak-beta estimator, vectorized only as an
% engineering acceleration. Startup self-test checks scalar equivalence.
[weak0,~]=estimate_beta_fixed_domain_batch(r0,proc,cfg);
[weakp,~]=estimate_beta_fixed_domain_batch(rp,proc,cfg);
[weak3,~]=estimate_beta_fixed_domain_batch(r3,proc,cfg);

D=table();
D.case_id=O.case_id;
D.n3_nu_hat_bins=n3_nu;
D.n3_objective=n3_obj;
D.n3_objective_evals=n3_evals;
D.proposed_nu_hat_bins=final_nu;
D.proposed_objective=final_obj;
D.proposed_branch_objective_evals=final_evals;
D.g0_Ahat=Ahat_g0; D.g0_phihat_rad=Phat_g0;
D.proposed_Ahat=Ahat_prop; D.proposed_phihat_rad=Phat_prop;
D.n3_Ahat=Ahat_n3; D.n3_phihat_rad=Phat_n3;
D.g0_weak_beta_hat_rad=weak0;
D.proposed_weak_beta_hat_rad=weakp;
D.n3_weak_beta_hat_rad=weak3;
D.g0_residual_norm_ratio=resnorm0;
D.proposed_residual_norm_ratio=resnormp;
D.n3_residual_norm_ratio=resnorm3;
D.g0_mask_fraction=mask0;
D.proposed_mask_fraction=maskp;
D.n3_mask_fraction=mask3;

R=struct('g0',r0,'proposed',rp,'n3',r3);

end

%% =========================================================================
function E=evaluate_noise_chunk(T,C,idx,X,realized_noise_power, ...
    O,D,R,proc,cfg)

methods=["G0_OriginalTop1","Proposed_Frozen_Staged","Always_Neighbor3"];
n=numel(idx);
rows=cell(n*numel(methods),47);
rr=0;

for j=1:n
    ic=idx(j);
    ip=C.physical_trial_id(ic);
    t=T(ip,:);
    x=X(j,:);
    a_hat=tan(O.beta_hat_strong_rad(j));

    Gref=estimate_global_reference(x,a_hat,cfg);

    eta_vec=[O.g0_nu_hat_bins(j),D.proposed_nu_hat_bins(j),D.n3_nu_hat_bins(j)];
    eval_vec=[O.g0_objective_evals(j),D.proposed_branch_objective_evals(j),D.n3_objective_evals(j)];
    A_vec=[D.g0_Ahat(j),D.proposed_Ahat(j),D.n3_Ahat(j)];
    P_vec=[D.g0_phihat_rad(j),D.proposed_phihat_rad(j),D.n3_phihat_rad(j)];
    bw_vec=[D.g0_weak_beta_hat_rad(j),D.proposed_weak_beta_hat_rad(j),D.n3_weak_beta_hat_rad(j)];
    mask_vec=[D.g0_mask_fraction(j),D.proposed_mask_fraction(j),D.n3_mask_fraction(j)];

    [~,w_true]=synth_clean_components(t,proc);

    residuals={R.g0(j,:),R.proposed(j,:),R.n3(j,:)};

    for im=1:numel(methods)
        rr=rr+1;
        nu=eta_vec(im);

        branch_err=abs(circular_bin_error(nu,Gref.nu_hat_bins));
        catastrophic=branch_err>cfg.catastrophic_error_threshold_bins;
        eta_err=abs(circular_bin_error(nu,t.true_eta_bins));
        beta_err=abs(O.beta_hat_strong_rad(j)-t.truth_beta_s_rad);
        wave_err=norm(residuals{im}-w_true)/max(norm(w_true),cfg.small_norm_floor);
        weak_beta_err=abs(bw_vec(im)-t.truth_beta_w_rad)/proc.Wbeta;
        amp_err=abs(A_vec(im)-1);
        phase_err=abs(wrap_to_pi(P_vec(im)));

        realized_snr_s=10*log10(C.strong_power(ic)/realized_noise_power(j));
        realized_snr_mix=10*log10(C.mixture_power(ic)/realized_noise_power(j));

        rrvals={ ...
            char(t.validation_set),t.aperture_mode{1},C.case_id(ic), ...
            C.physical_trial_id(ic),C.snr_db(ic),C.weak_snr_db(ic), ...
            C.mixture_snr_db(ic),realized_snr_s,realized_snr_mix, ...
            C.mc_index(ic),double(C.seed(ic)), ...
            char(methods(im)),im, ...
            O.stage1_trigger(j),O.stage2_trigger(j),O.fallback_trigger(j), ...
            O.beta_hat_strong_rad(j),t.truth_beta_s_rad,beta_err/proc.Wbeta, ...
            nu,t.true_eta_bins,eta_err,Gref.nu_hat_bins,branch_err,catastrophic, ...
            A_vec(im),amp_err,P_vec(im),phase_err,mask_vec(im), ...
            wave_err,wave_err<=cfg.error_feasible_threshold, ...
            bw_vec(im),t.truth_beta_w_rad,weak_beta_err,eval_vec(im), ...
            t.risk_state_id,t.delta_velocity_mps,t.strong_velocity_side{1}, ...
            t.weak_to_strong_ratio,t.relative_phase_rad,t.true_eta_bins, ...
            t.truth_Gamma,C.noise_variance_expected(ic),realized_noise_power(j), ...
            C.strong_power(ic),C.weak_power(ic)};
        rows(rr,:)=rrvals;
    end
end

rows=rows(1:rr,:);
E=cell2table(rows,'VariableNames',{ ...
    'validation_set','aperture_mode','case_id','physical_trial_id', ...
    'snr_strong_db','snr_weak_db','snr_mixture_expected_db', ...
    'snr_strong_realized_db','snr_mixture_realized_db', ...
    'mc_index','noise_seed','method','method_order', ...
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
    'truth_fractional_bin_offset','truth_Gamma', ...
    'noise_variance_expected','noise_power_realized', ...
    'truth_strong_power','truth_weak_power'});

% Normalize text columns as strings.
E.validation_set=string(E.validation_set);
E.aperture_mode=string(E.aperture_mode);
E.method=string(E.method);
E.truth_strong_velocity_side=string(E.truth_strong_velocity_side);

end

%% =========================================================================
function S=summarize_methods_by_snr(E,cfg)

sets=unique(E.validation_set,'stable');
aps=unique(E.aperture_mode,'stable');
snrs=unique(E.snr_strong_db,'sorted');
methods=unique(E.method,'stable');
rows={};

for iv=1:numel(sets)
for ia=1:numel(aps)
for is=1:numel(snrs)
for im=1:numel(methods)
    M=E(E.validation_set==sets(iv) & E.aperture_mode==aps(ia) & ...
        E.snr_strong_db==snrs(is) & E.method==methods(im),:);
    if isempty(M), continue; end

    catCount=sum(M.catastrophic_branch_failure);
    catRate=catCount/height(M);
    [clo,chi]=wilson_interval(catCount,height(M),cfg.wilson_z);

    weakCount=sum(M.weak_waveform_feasible);
    weakRate=weakCount/height(M);
    [wlo,whi]=wilson_interval(weakCount,height(M),cfg.wilson_z);

    if methods(im)=="G0_OriginalTop1"
        fallback=0;
    elseif methods(im)=="Proposed_Frozen_Staged"
        fallback=mean(M.fallback_trigger);
    elseif methods(im)=="Always_Neighbor3"
        fallback=1;
    else
        fallback=NaN;
    end

    rows(end+1,:)={char(sets(iv)),char(aps(ia)),snrs(is), ...
        char(methods(im)),height(M), ...
        catCount,catRate,clo,chi, ...
        weakCount,weakRate,wlo,whi, ...
        median(M.strong_beta_abs_error_over_W,'omitnan'), ...
        local_percentile(M.strong_beta_abs_error_over_W,90), ...
        local_percentile(M.strong_beta_abs_error_over_W,99), ...
        median(M.eta_abs_error_bins,'omitnan'), ...
        local_percentile(M.eta_abs_error_bins,90), ...
        median(M.weak_waveform_error_ratio,'omitnan'), ...
        local_percentile(M.weak_waveform_error_ratio,90), ...
        median(M.weak_beta_abs_error_over_W,'omitnan'), ...
        mean(M.branch_objective_evals,'omitnan'),fallback, ...
        median(M.snr_weak_db,'omitnan'), ...
        min(M.snr_weak_db),max(M.snr_weak_db), ...
        median(M.snr_mixture_expected_db,'omitnan'), ...
        median(M.snr_strong_realized_db,'omitnan')}; %#ok<AGROW>
end
end
end
end

S=cell2table(rows,'VariableNames',{ ...
    'validation_set','aperture_mode','snr_strong_db','method','n_cases', ...
    'n_branch_fail','branch_fail_rate','branch_fail_wilson_lo','branch_fail_wilson_hi', ...
    'n_weak_feasible','weak_feasible_rate','weak_feasible_wilson_lo','weak_feasible_wilson_hi', ...
    'median_strong_beta_error_over_W','p90_strong_beta_error_over_W', ...
    'p99_strong_beta_error_over_W','median_eta_error_bins','p90_eta_error_bins', ...
    'median_weak_waveform_error_ratio','p90_weak_waveform_error_ratio', ...
    'median_weak_beta_error_over_W','mean_branch_objective_evals', ...
    'fallback_fraction','median_weak_snr_db','min_weak_snr_db','max_weak_snr_db', ...
    'median_mixture_snr_expected_db','median_strong_snr_realized_db'});

S.normalized_branch_cost=nan(height(S),1);

for iv=1:numel(sets)
for ia=1:numel(aps)
for is=1:numel(snrs)
    idx=S.validation_set==sets(iv) & S.aperture_mode==aps(ia) & ...
        S.snr_strong_db==snrs(is);
    G=S(idx & S.method=="G0_OriginalTop1",:);
    N=S(idx & S.method=="Always_Neighbor3",:);
    if isempty(G) || isempty(N), continue; end
    den=N.mean_branch_objective_evals-G.mean_branch_objective_evals;
    for j=find(idx).'
        if isfinite(den) && den>0
            S.normalized_branch_cost(j)= ...
                (S.mean_branch_objective_evals(j)-G.mean_branch_objective_evals)/den;
        end
    end
end
end
end

end

%% =========================================================================
function P=summarize_paired_by_snr(E)

sets=unique(E.validation_set,'stable');
aps=unique(E.aperture_mode,'stable');
snrs=unique(E.snr_strong_db,'sorted');
rows={};

for iv=1:numel(sets)
for ia=1:numel(aps)
for is=1:numel(snrs)
    base=E.validation_set==sets(iv) & E.aperture_mode==aps(ia) & ...
        E.snr_strong_db==snrs(is);

    G=E(base & E.method=="G0_OriginalTop1",:);
    Q=E(base & E.method=="Proposed_Frozen_Staged",:);
    N=E(base & E.method=="Always_Neighbor3",:);
    if isempty(G), continue; end

    G=sortrows(G,'case_id'); Q=sortrows(Q,'case_id'); N=sortrows(N,'case_id');
    assert(isequal(G.case_id,Q.case_id) && isequal(G.case_id,N.case_id));

    gweak=~G.weak_waveform_feasible; qweak=~Q.weak_waveform_feasible; nweak=~N.weak_waveform_feasible;
    gcat=G.catastrophic_branch_failure; qcat=Q.catastrophic_branch_failure; ncat=N.catastrophic_branch_failure;

    wr=sum(gweak & ~qweak); wh=sum(~gweak & qweak);
    br=sum(gcat & ~qcat); bh=sum(~gcat & qcat);

    rows(end+1,:)={char(sets(iv)),char(aps(ia)),snrs(is),height(G), ...
        wr,wh,sum(qweak & ~nweak),sum(qweak & nweak), ...
        br,bh,sum(qcat & ~ncat),sum(qcat & ncat), ...
        paired_exact_pvalue(wr,wh),paired_exact_pvalue(br,bh)}; %#ok<AGROW>
end
end
end

P=cell2table(rows,'VariableNames',{ ...
    'validation_set','aperture_mode','snr_strong_db','n_cases', ...
    'G0_fail_to_Proposed_success','G0_success_to_Proposed_fail', ...
    'Proposed_fail_to_N3_success','persistent_weak_failure_after_N3', ...
    'G0_branch_catastrophe_rescued_by_Proposed','Proposed_induced_branch_catastrophe', ...
    'Proposed_branch_failure_rescued_by_N3','persistent_branch_failure_after_N3', ...
    'weak_paired_exact_p','branch_paired_exact_p'});

end

%% =========================================================================
function S=summarize_stage_by_snr(E)

sets=unique(E.validation_set,'stable');
aps=unique(E.aperture_mode,'stable');
snrs=unique(E.snr_strong_db,'sorted');
rows={};

for iv=1:numel(sets)
for ia=1:numel(aps)
for is=1:numel(snrs)
    base=E.validation_set==sets(iv) & E.aperture_mode==aps(ia) & ...
        E.snr_strong_db==snrs(is);
    G=E(base & E.method=="G0_OriginalTop1",:);
    Q=E(base & E.method=="Proposed_Frozen_Staged",:);
    N=E(base & E.method=="Always_Neighbor3",:);
    if isempty(G), continue; end
    G=sortrows(G,'case_id'); Q=sortrows(Q,'case_id'); N=sortrows(N,'case_id');

    gcat=G.catastrophic_branch_failure; qcat=Q.catastrophic_branch_failure; ncat=N.catastrophic_branch_failure;
    gweak=~G.weak_waveform_feasible; qweak=~Q.weak_waveform_feasible;
    s1=Q.stage1_trigger; s2=Q.stage2_trigger; trig=Q.fallback_trigger;

    rows(end+1,:)={char(sets(iv)),char(aps(ia)),snrs(is),height(G), ...
        sum(s1),mean(s1),sum(s2),mean(s2),sum(trig),mean(trig), ...
        sum(gcat),sum(gcat & ~qcat & s1),sum(gcat & ~qcat & s2), ...
        sum(gcat & ~trig),sum(~gcat & qcat),sum(ncat), ...
        sum(gweak & ~qweak & s1),sum(gweak & ~qweak & s2), ...
        sum(~gweak & qweak)}; %#ok<AGROW>
end
end
end

S=cell2table(rows,'VariableNames',{ ...
    'validation_set','aperture_mode','snr_strong_db','n_cases', ...
    'stage1_trigger_count','stage1_fraction_at_snr', ...
    'stage2_trigger_count','stage2_fraction_at_snr', ...
    'total_trigger_count','fallback_fraction_at_snr', ...
    'G0_branch_catastrophe_count','stage1_branch_rescue_count', ...
    'stage2_incremental_branch_rescue_count','missed_G0_branch_catastrophe_count', ...
    'induced_branch_catastrophe_count','AlwaysN3_branch_catastrophe_count', ...
    'stage1_weak_rescue_count','stage2_incremental_weak_rescue_count', ...
    'induced_weak_failure_count'});

end

%% =========================================================================
function R=summarize_risk_by_snr(O,C,E,cfg)
% Evaluation-only joining by case_id. SNR never enters scheduler.

sets=unique(E.validation_set,'stable');
aps=unique(E.aperture_mode,'stable');
snrs=unique(E.snr_strong_db,'sorted');
rows={};

for iv=1:numel(sets)
for ia=1:numel(aps)
for is=1:numel(snrs)
    G=E(E.validation_set==sets(iv) & E.aperture_mode==aps(ia) & ...
        E.snr_strong_db==snrs(is) & E.method=="G0_OriginalTop1",:);
    if isempty(G), continue; end
    G=sortrows(G,'case_id');

    [tf,loc]=ismember(G.case_id,O.case_id);
    assert(all(tf));
    X=O(loc,:);

    y=logical(G.catastrophic_branch_failure);
    auc1=rank_auc(double(X.refined_lr_asymmetry),y);

    residual=~X.stage1_trigger;
    y2=y(residual);
    score2=-double(X.fivebin_peak_fraction(residual));
    auc2=rank_auc(score2,y2);

    nfail=sum(y); nsuccess=sum(~y);
    nfail2=sum(y2); nsuccess2=sum(~y2);

    if nfail>0
        cap1=sum(y & X.stage1_trigger)/nfail;
        capT=sum(y & X.fallback_trigger)/nfail;
    else
        cap1=NaN; capT=NaN;
    end
    if nfail2>0
        cap2=sum(y2 & X.stage2_trigger(residual))/nfail2;
    else
        cap2=NaN;
    end

    rev1=isfinite(auc1) && nfail>=cfg.min_auc_positive_cases_for_direction_flag && ...
        nsuccess>=cfg.min_auc_positive_cases_for_direction_flag && ...
        auc1<cfg.direction_reversal_auc_threshold;
    rev2=isfinite(auc2) && nfail2>=cfg.min_auc_positive_cases_for_direction_flag && ...
        nsuccess2>=cfg.min_auc_positive_cases_for_direction_flag && ...
        auc2<cfg.direction_reversal_auc_threshold;

    rows(end+1,:)={char(sets(iv)),char(aps(ia)),snrs(is),height(G), ...
        nfail,nsuccess,auc1,cap1,sum(residual),nfail2,nsuccess2, ...
        auc2,cap2,capT,rev1,rev2}; %#ok<AGROW>
end
end
end

R=cell2table(rows,'VariableNames',{ ...
    'validation_set','aperture_mode','snr_strong_db','n_cases', ...
    'G0_failure_count','G0_success_count', ...
    'stage1_refinedLR_directional_AUC','stage1_failure_capture_fraction', ...
    'stage2_residual_pool_n','stage2_residual_failure_count', ...
    'stage2_residual_success_count','stage2_FiveBin_directional_AUC', ...
    'stage2_residual_failure_capture_fraction','total_failure_capture_fraction', ...
    'stage1_direction_reversal_flag','stage2_direction_reversal_flag'});

end

%% =========================================================================
function U=summarize_upstream_by_snr(E)

P=E(E.method=="Proposed_Frozen_Staged",:);
sets=unique(P.validation_set,'stable');
aps=unique(P.aperture_mode,'stable');
snrs=unique(P.snr_strong_db,'sorted');
rows={};

for iv=1:numel(sets)
for ia=1:numel(aps)
for is=1:numel(snrs)
    M=P(P.validation_set==sets(iv) & P.aperture_mode==aps(ia) & ...
        P.snr_strong_db==snrs(is),:);
    if isempty(M), continue; end

    rows(end+1,:)={char(sets(iv)),char(aps(ia)),snrs(is),height(M), ...
        median(M.strong_beta_abs_error_over_W,'omitnan'), ...
        local_percentile(M.strong_beta_abs_error_over_W,90), ...
        local_percentile(M.strong_beta_abs_error_over_W,99), ...
        median(M.eta_abs_error_bins,'omitnan'), ...
        local_percentile(M.eta_abs_error_bins,90), ...
        local_percentile(M.eta_abs_error_bins,99), ...
        median(M.snr_weak_db,'omitnan')}; %#ok<AGROW>
end
end
end

U=cell2table(rows,'VariableNames',{ ...
    'validation_set','aperture_mode','snr_strong_db','n_cases', ...
    'median_strong_beta_error_over_W','p90_strong_beta_error_over_W', ...
    'p99_strong_beta_error_over_W','median_eta_error_bins', ...
    'p90_eta_error_bins','p99_eta_error_bins','median_weak_snr_db'});

end

%% =========================================================================
function F=oracle_firewall_audit_exp10c(O,E,cfg)

online_names=string(O.Properties.VariableNames);
forbidden=["truth","oracle","global_reference","Gamma","relative_phase", ...
    "weak_to_strong_ratio","strong_velocity","true_eta","snr","noise_seed", ...
    "mc_index"];

bad=false(size(forbidden));
for i=1:numel(forbidden)
    bad(i)=any(contains(lower(online_names),lower(forbidden(i))));
end

eval_names=string(E.Properties.VariableNames);
has_truth_eval=any(startsWith(eval_names,"truth_"));
has_snr_eval=any(contains(lower(eval_names),"snr"));

policy_ok=abs(cfg.stage1_budget-0.20)<eps && ...
    abs(cfg.stage2_conditional_budget-0.10)<eps && ...
    cfg.neighbor_radius==1 && cfg.removal_window_bins==3;

overall=~any(bad) && has_truth_eval && has_snr_eval && policy_ok;

F=table(overall,~any(bad),has_truth_eval,has_snr_eval,policy_ok, ...
    strjoin(forbidden(bad),';'), ...
    'VariableNames',{'overall_pass', ...
    'online_schema_has_no_forbidden_truth_or_snr_fields', ...
    'evaluation_schema_has_truth_fields','evaluation_schema_has_snr_fields', ...
    'frozen_policy_matches','forbidden_online_matches'});

end

%% =========================================================================
function V=summarize_noise_validity(S,P,R,F,cfg)

setName=string(S.validation_set(1));
ap=string(S.aperture_mode(1));
snrs=unique(S.snr_strong_db,'sorted');

rows={};
for i=1:numel(snrs)
    snr=snrs(i);
    G=S(S.snr_strong_db==snr & S.method=="G0_OriginalTop1",:);
    Q=S(S.snr_strong_db==snr & S.method=="Proposed_Frozen_Staged",:);
    N=S(S.snr_strong_db==snr & S.method=="Always_Neighbor3",:);
    PP=P(P.snr_strong_db==snr,:);
    RR=R(R.snr_strong_db==snr,:);

    gain=G.branch_fail_rate-Q.branch_fail_rate;
    weakGain=Q.weak_feasible_rate-G.weak_feasible_rate;
    rescue=PP.G0_branch_catastrophe_rescued_by_Proposed;
    harm=PP.Proposed_induced_branch_catastrophe;
    noRev=~RR.stage1_direction_reversal_flag && ~RR.stage2_direction_reversal_flag;
    nonWorse=(gain>=0) && (rescue>=harm);
    valid=nonWorse && noRev;

    rows(end+1,:)={char(setName),char(ap),snr, ...
        G.branch_fail_rate,Q.branch_fail_rate,N.branch_fail_rate, ...
        gain,weakGain,rescue,harm, ...
        PP.persistent_branch_failure_after_N3, ...
        RR.stage1_refinedLR_directional_AUC,RR.stage2_FiveBin_directional_AUC, ...
        RR.stage1_direction_reversal_flag,RR.stage2_direction_reversal_flag, ...
        valid}; %#ok<AGROW>
end

V=cell2table(rows,'VariableNames',{ ...
    'validation_set','aperture_mode','snr_strong_db', ...
    'G0_branch_fail_rate','Proposed_branch_fail_rate','N3_branch_fail_rate', ...
    'Proposed_net_branch_gain','Proposed_net_weak_feasible_gain', ...
    'paired_branch_rescue','paired_branch_harm','persistent_N3_branch_failures', ...
    'stage1_AUC','stage2_AUC','stage1_direction_reversal', ...
    'stage2_direction_reversal','validity_criterion_pass'});

% Contiguous validity floor: lowest SNR such that this level and all higher
% tested SNRs satisfy the frozen validity criterion.
floor_db=NaN;
for i=1:height(V)
    if all(V.validity_criterion_pass(i:end))
        floor_db=V.snr_strong_db(i);
        break;
    end
end
V.contiguous_validity_floor_db=repmat(floor_db,height(V),1);
V.oracle_firewall_pass=repmat(F.overall_pass(1),height(V),1);
V.frozen_b1=repmat(cfg.stage1_budget,height(V),1);
V.frozen_b2=repmat(cfg.stage2_conditional_budget,height(V),1);

end

%% =========================================================================
function A=add_job_identity(F,validation_set,aperture_mode)
A=F;
A.validation_set=repmat(string(validation_set),height(A),1);
A.aperture_mode=repmat(string(aperture_mode),height(A),1);
A=movevars(A,{'validation_set','aperture_mode'},'Before',1);
end

%% =========================================================================
function O=build_overall_status(V,F,cfg)

firewall=all(F.overall_pass);

if cfg.run_mode=="smoke"
    status="SMOKE_IMPLEMENTATION_COMPLETE_NO_SCIENTIFIC_INTERPRETATION";
elseif ~firewall
    status="FAIL_ORACLE_FIREWALL";
elseif cfg.run_mode=="original_anchor"
    status="ORIGINALGRID_NOISE_ANCHOR_COMPLETE";
else
    % DenseRisk is the primary noise-validation set. OriginalGrid, when
    % present, remains a broad-regime sanity anchor and does not redefine
    % the DenseRisk validity floor.
    D=V(string(V.validation_set)=="DenseRisk",:);
    if isempty(D)
        status="NO_DENSERISK_VALIDATION_ROWS";
    else
        aps=unique(string(D.aperture_mode),'stable');
        floors=nan(numel(aps),1);
        for i=1:numel(aps)
            M=D(string(D.aperture_mode)==aps(i),:);
            f=unique(M.contiguous_validity_floor_db(isfinite(M.contiguous_validity_floor_db)));
            if ~isempty(f), floors(i)=f(1); end
        end

        if all(isfinite(floors))
            tested_min=min(D.snr_strong_db);
            if all(floors<=tested_min)
                status="PASS_DENSERISK_ALL_TESTED_SNR";
            else
                status="PASS_DENSERISK_WITH_IDENTIFIED_NOISE_VALIDITY_BOUNDARY";
            end
        else
            status="CLAIM2_NOISE_VALIDITY_NOT_ESTABLISHED_ON_DENSERISK";
        end
    end
end

O=table(status,firewall,cfg.run_mode,cfg.protocol_version, ...
    'VariableNames',{'overall_status','oracle_firewall_pass','run_mode','protocol_version'});

end

%% =========================================================================
function [lo,hi]=wilson_interval(k,n,z)
if n<=0
    lo=NaN; hi=NaN; return;
end
p=k/n;
den=1+z^2/n;
center=(p+z^2/(2*n))/den;
half=z*sqrt(p*(1-p)/n + z^2/(4*n^2))/den;
lo=max(0,center-half);
hi=min(1,center+half);
end

%% =========================================================================
function blocks=make_blocks(n,blockSize)
starts=1:blockSize:n;
blocks=cell(numel(starts),1);
for i=1:numel(starts)
    blocks{i}=starts(i):min(n,starts(i)+blockSize-1);
end
end

%% =========================================================================
function s=job_signature(cfg,job_tag,C,proc)

snrs=unique(C.snr_db,'sorted');
mcmax=max(C.mc_index);
firstSeed=double(C.seed(1));
lastSeed=double(C.seed(end));

s=sprintf('%s|%s|%s|N%d|cases%d|snr%s|mc%d|seed%.0f-%.0f|b1%.8f|b2%.8f|L%d', ...
    cfg.protocol_version,cfg.run_mode,job_tag,proc.N,height(C), ...
    mat2str(snrs.'),mcmax,firstSeed,lastSeed, ...
    cfg.stage1_budget,cfg.stage2_conditional_budget,cfg.removal_window_bins);

end

%% =========================================================================
function [beta_hat,best_score]=estimate_beta_fixed_domain_batch(X,proc,cfg)
% Vectorized engineering implementation of the SAME frozen FrAc score.
% A scalar-equivalence self-test is executed before any experiment.

nCases=size(X,1);
beta_hat=nan(nCases,1);
best_score=nan(nCases,1);

for st=1:cfg.beta_vector_chunk_size:nCases
    ix=st:min(nCases,st+cfg.beta_vector_chunk_size-1);
    [beta_hat(ix),best_score(ix)] = estimate_beta_fixed_domain_batch_core( ...
        X(ix,:),proc,cfg);
end

end

function [beta_hat,best_score]=estimate_beta_fixed_domain_batch_core(X,proc,cfg)

nCases=size(X,1);
nBeta=numel(proc.beta_grid);
N=size(X,2);
nfft=max(2048,2^nextpow2(cfg.frac_fft_oversample*N));
tb=tan(proc.beta_grid(:)).';

P=zeros(nCases,nBeta);

for k=1:proc.max_lag
    z=X(:,1+k:end).*conj(X(:,1:end-k));
    Z=fftshift(fft(z,nfft,2),2);

    q=k*tb;
    pos=q*nfft + nfft/2 + 1;
    i1=floor(pos);
    frac=pos-i1;
    valid=i1>=1 & i1<nfft;

    V=complex(zeros(nCases,nBeta));
    if any(valid)
        id1=i1(valid);
        a=frac(valid);
        V(:,valid)=Z(:,id1).*(1-a) + Z(:,id1+1).*a;
    end
    V=V/max(size(z,2),1);
    P=P+abs(V).^2;
end

P=real(P);
[best_score,idx]=max(P,[],2);
beta_hat=proc.beta_grid(idx);

end

%% =========================================================================
function run_startup_self_tests_exp10c(cfg)

% 1) Core inherited amplitude/phase LS.
N=188; a=0.0013; nu=0.37; A=1.7; phi=0.63;
x=synth_discrete_lfm(N,A,a,nu/N,phi);
[Ah,ph]=estimate_amp_phase_ls(x,a,nu);
assert(abs(Ah-A)<1e-10 && abs(wrap_to_pi(ph-phi))<1e-10, ...
    'Amplitude/phase LS self-test failed.');

% 2) Recenter identity.
[xr,phase]=recenter_signal(x,nu);
xback=xr.*conj(phase);
assert(norm(xback-x)/norm(x)<cfg.translation_selftest_gate, ...
    'Recenter translation self-test failed.');

% 3) Tie-inclusive scheduler.
score=[3;2;2;1];
[m,s]=tie_inclusive_top(score,0.5);
assert(isequal(m,[true;true;true;false]) && s.selected_count==3, ...
    'Tie-inclusive scheduler self-test failed.');

% 4) Stable seed repeatability.
seed=make_case_seed(cfg.base_seed,uint64(17),uint64(101),7,3,2);
r1=RandStream('mt19937ar','Seed',double(seed));
r2=RandStream('mt19937ar','Seed',double(seed));
z1=randn(r1,1,32)+1j*randn(r1,1,32);
z2=randn(r2,1,32)+1j*randn(r2,1,32);
assert(max(abs(z1-z2))<=cfg.seed_repeatability_tol, ...
    'Noise seed repeatability self-test failed.');

% 5) Batched fixed-domain beta search vs inherited scalar implementation.
tmpcfg=cfg;
tmpcfg.frac_fft_oversample=8; % self-test speed only; both sides use same value.
proc=struct();
proc.N=64;
proc.max_lag=12;
proc.beta_grid=linspace(-0.006,0.006,61).';
X=complex(randn(3,64),randn(3,64));
[bb,ss]=estimate_beta_fixed_domain_batch_core(X,proc,tmpcfg);
for i=1:3
    [bs,sc]=estimate_beta_fixed_domain(X(i,:),proc,tmpcfg);
    rel=abs(ss(i)-sc)/max(abs(sc),1);
    assert(abs(bb(i)-bs)<1e-14 && rel<cfg.batch_beta_equivalence_rel_tol, ...
        'Vectorized beta-search equivalence self-test failed.');
end

fprintf('Startup self-tests: PASS\n');

end

%% =========================================================================
function write_feedback_bundle_exp10c(cfg,Inventory,S,P,Stage,Risk,U,V,F,O)

path=fullfile(cfg.output_dir,cfg.feedback_bundle_name);
fid=fopen(path,'w');
if fid<0
    error('EXP010C:FeedbackBundleOpenFailed','Cannot open feedback bundle.');
end
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP010-C / FROZEN-POLICY ADDITIVE-NOISE ROBUSTNESS\n');
fprintf(fid,'==================================================\n');
fprintf(fid,'Run mode: %s\n',cfg.run_mode);
fprintf(fid,'Protocol: %s\n',cfg.protocol_version);
fprintf(fid,'Noise model: circular complex AWGN\n');
fprintf(fid,'Sea clutter: NOT MODELED in EXP010-C\n');
fprintf(fid,'SNR reference: strong-component per-sample input power\n');
fprintf(fid,'DenseRisk SNR grid: %s dB\n',mat2str(cfg.snr_grid_dense_db));
fprintf(fid,'OriginalGrid anchor SNR: %s dB\n',mat2str(cfg.snr_grid_original_db));
fprintf(fid,'DenseRisk MC/state/SNR: %d\n',cfg.mc_dense);
fprintf(fid,'OriginalGrid MC/state/SNR: %d\n',cfg.mc_original);
fprintf(fid,'Policy: Refined-LR %.2f -> FiveBin %.2f conditional -> Neighbor-3\n', ...
    cfg.stage1_budget,cfg.stage2_conditional_budget);
fprintf(fid,'Scheduler: heterogeneous-SNR rank pool; NO per-SNR reranking\n');
fprintf(fid,'Removal width: %d bins\n',cfg.removal_window_bins);
fprintf(fid,'OVERALL STATUS = %s\n\n',string(O.overall_status(1)));

write_table_tsv(fid,'RUN INVENTORY',Inventory);
write_table_tsv(fid,'OVERALL STATUS',O);
write_table_tsv(fid,'NOISE VALIDITY SUMMARY',V);
write_table_tsv(fid,'METHOD SUMMARY BY SNR',S);
write_table_tsv(fid,'PAIRED OUTCOMES BY SNR',P);
write_table_tsv(fid,'STAGE ALLOCATION BY SNR',Stage);
write_table_tsv(fid,'RISK-DIRECTION AUDIT BY SNR',Risk);
write_table_tsv(fid,'UPSTREAM ERROR BY SNR',U);
write_table_tsv(fid,'ORACLE FIREWALL',F);

fprintf(fid,'\nINTERPRETATION RULES\n');
fprintf(fid,'1) AWGN robustness is signal-level; it is not a sea-clutter claim.\n');
fprintf(fid,'2) Truth/SNR may evaluate, but truth/SNR may not decide.\n');
fprintf(fid,'3) Scheduler ranking is never stratified by true SNR.\n');
fprintf(fid,'4) Low-SNR degradation defines a validity boundary; do not retune feature/budget/N3.\n');
fprintf(fid,'5) Interpret branch gain with paired rescue/harm, Wilson CI, cost, and upstream beta error.\n');
fprintf(fid,'6) The primary causal chain is SNR_s -> strong-beta error -> branch validity -> weak recovery.\n');

end

%% =========================================================================
function make_noise_figures(S,Risk,U,cfg)

if isempty(S), return; end

sets=unique(string(S.validation_set),'stable');

% Fig 1: branch failure vs SNR.
fig=figure('Visible',cfg.figure_visible);
tiledlayout(numel(sets),2,'TileSpacing','compact','Padding','compact');
for iv=1:numel(sets)
    for ia=1:numel(cfg.aperture_modes)
        nexttile;
        setName=sets(iv); ap=cfg.aperture_modes(ia);
        hold on;
        methods=["G0_OriginalTop1","Proposed_Frozen_Staged","Always_Neighbor3"];
        for im=1:numel(methods)
            M=S(string(S.validation_set)==setName & ...
                string(S.aperture_mode)==ap & string(S.method)==methods(im),:);
            if isempty(M), continue; end
            M=sortrows(M,'snr_strong_db');
            y=M.branch_fail_rate;
            lo=y-M.branch_fail_wilson_lo;
            hi=M.branch_fail_wilson_hi-y;
            errorbar(M.snr_strong_db,y,lo,hi,'-o','DisplayName',char(methods(im)));
        end
        grid on; xlabel('Strong-referenced input SNR (dB)');
        ylabel('Branch catastrophe probability');
        title(sprintf('%s / %s',setName,ap),'Interpreter','none');
        legend('Interpreter','none','Location','best');
    end
end
exportgraphics(fig,fullfile(cfg.figure_dir,'fig01_branch_failure_vs_snr.png'),'Resolution',180);
close(fig);

% Fig 2: upstream strong-beta error.
fig=figure('Visible',cfg.figure_visible);
tiledlayout(numel(sets),2,'TileSpacing','compact','Padding','compact');
for iv=1:numel(sets)
    for ia=1:numel(cfg.aperture_modes)
        nexttile;
        M=U(string(U.validation_set)==sets(iv) & ...
            string(U.aperture_mode)==cfg.aperture_modes(ia),:);
        if isempty(M), continue; end
        M=sortrows(M,'snr_strong_db');
        plot(M.snr_strong_db,M.median_strong_beta_error_over_W,'-o','DisplayName','median');
        hold on;
        plot(M.snr_strong_db,M.p90_strong_beta_error_over_W,'-s','DisplayName','p90');
        grid on; xlabel('Strong-referenced input SNR (dB)');
        ylabel('|\beta-hat-\beta| / W_\beta');
        title(sprintf('%s / %s',sets(iv),cfg.aperture_modes(ia)),'Interpreter','none');
        legend('Location','best');
    end
end
exportgraphics(fig,fullfile(cfg.figure_dir,'fig02_upstream_beta_error_vs_snr.png'),'Resolution',180);
close(fig);

% Fig 3: weak feasible rate.
fig=figure('Visible',cfg.figure_visible);
tiledlayout(numel(sets),2,'TileSpacing','compact','Padding','compact');
for iv=1:numel(sets)
    for ia=1:numel(cfg.aperture_modes)
        nexttile; hold on;
        setName=sets(iv); ap=cfg.aperture_modes(ia);
        methods=["G0_OriginalTop1","Proposed_Frozen_Staged","Always_Neighbor3"];
        for im=1:numel(methods)
            M=S(string(S.validation_set)==setName & ...
                string(S.aperture_mode)==ap & string(S.method)==methods(im),:);
            if isempty(M), continue; end
            M=sortrows(M,'snr_strong_db');
            plot(M.snr_strong_db,M.weak_feasible_rate,'-o','DisplayName',char(methods(im)));
        end
        grid on; xlabel('Strong-referenced input SNR (dB)');
        ylabel('Weak waveform feasible rate');
        ylim([0 1]);
        title(sprintf('%s / %s',setName,ap),'Interpreter','none');
        legend('Interpreter','none','Location','best');
    end
end
exportgraphics(fig,fullfile(cfg.figure_dir,'fig03_weak_feasible_vs_snr.png'),'Resolution',180);
close(fig);

% Fig 4: Proposed fallback / normalized cost.
fig=figure('Visible',cfg.figure_visible);
tiledlayout(numel(sets),2,'TileSpacing','compact','Padding','compact');
for iv=1:numel(sets)
    for ia=1:numel(cfg.aperture_modes)
        nexttile;
        M=S(string(S.validation_set)==sets(iv) & ...
            string(S.aperture_mode)==cfg.aperture_modes(ia) & ...
            string(S.method)=="Proposed_Frozen_Staged",:);
        if isempty(M), continue; end
        M=sortrows(M,'snr_strong_db');
        plot(M.snr_strong_db,M.fallback_fraction,'-o','DisplayName','fallback fraction');
        hold on;
        plot(M.snr_strong_db,M.normalized_branch_cost,'-s','DisplayName','normalized cost');
        grid on; xlabel('Strong-referenced input SNR (dB)');
        ylabel('Fraction / normalized cost');
        title(sprintf('%s / %s',sets(iv),cfg.aperture_modes(ia)),'Interpreter','none');
        legend('Location','best');
    end
end
exportgraphics(fig,fullfile(cfg.figure_dir,'fig04_fallback_cost_vs_snr.png'),'Resolution',180);
close(fig);

% Fig 5: reliability AUC.
fig=figure('Visible',cfg.figure_visible);
tiledlayout(numel(sets),2,'TileSpacing','compact','Padding','compact');
for iv=1:numel(sets)
    for ia=1:numel(cfg.aperture_modes)
        nexttile;
        M=Risk(string(Risk.validation_set)==sets(iv) & ...
            string(Risk.aperture_mode)==cfg.aperture_modes(ia),:);
        if isempty(M), continue; end
        M=sortrows(M,'snr_strong_db');
        plot(M.snr_strong_db,M.stage1_refinedLR_directional_AUC,'-o','DisplayName','Refined-LR');
        hold on;
        plot(M.snr_strong_db,M.stage2_FiveBin_directional_AUC,'-s','DisplayName','FiveBin residual');
        yline(0.5,'--','DisplayName','AUC=0.5');
        grid on; xlabel('Strong-referenced input SNR (dB)');
        ylabel('Directional AUC');
        ylim([0 1]);
        title(sprintf('%s / %s',sets(iv),cfg.aperture_modes(ia)),'Interpreter','none');
        legend('Location','best');
    end
end
exportgraphics(fig,fullfile(cfg.figure_dir,'fig05_risk_auc_vs_snr.png'),'Resolution',180);
close(fig);

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
    error('EXP010C:UnknownValidationSet','Unknown validation set: %s',validation_set);
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
        error('EXP010C:MissingDenseRiskStates', ...
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
    error('EXP010C:NoDenseRiskStatesForAperture', ...
        'No PA5I-R1 DenseRisk states found for %s.',mode);
end

validate_dense_risk_consumer_schema(R);

if any(double(R.azimuth_samples)~=proc.N)
    error('EXP010C:DenseRiskApertureMismatch', ...
        'Frozen DenseRisk azimuth_samples disagree with current %s N=%d.',mode,proc.N);
end

if ismember('Gamma_PA4',R.Properties.VariableNames)
    gsrc=double(R.Gamma_PA4);
    grecalc=abs(atan(double(R.strong_chirp_rate_discrete))- ...
        atan(double(R.weak_chirp_rate_discrete)))/proc.Wbeta;
    if max(abs(gsrc-grecalc),[],'omitnan')>1e-8
        error('EXP010C:DenseRiskGammaMismatch', ...
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
    error('EXP010C:DenseRiskStorageSchemaMismatch', ...
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
    error('EXP010C:DenseRiskConsumerSchemaMismatch', ...
        'DenseRisk consumer schema missing: %s',strjoin(missing,', '));
end

if numel(unique(R.risk_state_id))~=height(R)
    error('EXP010C:DenseRiskDuplicateState','risk_state_id must be unique.');
end

end


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


function q = local_percentile(x,p)
x=x(isfinite(x));
if isempty(x), q=NaN; return; end
x=sort(x(:));
pos=1+(numel(x)-1)*p/100;
lo=floor(pos); hi=ceil(pos);
if lo==hi, q=x(lo); else, q=x(lo)+(pos-lo)*(x(hi)-x(lo)); end
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

