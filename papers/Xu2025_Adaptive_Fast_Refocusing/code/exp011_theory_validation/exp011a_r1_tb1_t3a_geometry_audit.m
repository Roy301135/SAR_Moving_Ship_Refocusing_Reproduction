function results = exp011a_r1_tb1_t3a_geometry_audit(run_mode)
%EXP011A_R1_TB1_T3A_GEOMETRY_AUDIT
% EXP011-A / Theory Bridge 1 / T3A
% Retrospective Objective-Geometry Audit
%
% PURPOSE
% -------
% Replay frozen PA5I-R1 physical risk states under TRUE strong-chirp
% control and inspect the objective geometry required by Theory Bridge 1.
%
% THIS IS NOT A NEW METHOD EXPERIMENT.
% THIS AUDIT DOES NOT FIT THEORY TO DATA.
% NO THEORY PARAMETER MAY BE ESTIMATED FROM FAILURE LABELS.
%
% Questions:
%   H1) Does effective coarse-margin sign agree with the reconstructed
%       coarse branch winner in regular cases?
%   H2) Do discrete-first cases exist (continuous branch correct, coarse
%       G0 branch wrong)?
%   H3) Are mismatches concentrated in pre-declared non-smooth / topology
%       cases rather than silently fitted?

if nargin < 1
    run_mode = "smoke";
end

cfg = config_exp011a_r1_tb1_t3a_geometry_audit(run_mode);

fprintf('\n============================================================\n');
fprintf('EXP011-A-R1 / TB1-T3A Retrospective Objective-Geometry Audit\n');
fprintf('============================================================\n');
fprintf('Run mode              : %s\n',cfg.run_mode);
fprintf('Theory fitting         : FORBIDDEN\n');
fprintf('Noise                  : OFF\n');
fprintf('Strong beta / chirp    : TRUE-CONTROL\n');
fprintf('Upstream risk states   : %s\n',cfg.risk_states_path);
fprintf('Output                 : %s\n\n',cfg.output_dir);

validate_cfg_contract(cfg);
ensure_output_dirs(cfg);

R = read_risk_states(cfg);
T = build_frozen_trials(R,cfg);

fprintf('Frozen theory-audit trials: %d\n',height(T));
fprintf('Apertures: %s\n\n',strjoin(unique(string(T.aperture_mode)).',', '));

[A,selftest] = run_geometry_audit(T,cfg);
S = summarize_audit(A);
M = summarize_mismatch_taxonomy(A);
V = form_verdict(A,selftest,cfg);

write_outputs(A,S,M,V,selftest,cfg);
make_figures(A,cfg);

results = struct();
results.trials = A;
results.summary = S;
results.mismatch_taxonomy = M;
results.verdict = V;
results.selftest = selftest;
results.config = cfg;

save(fullfile(cfg.output_dir, ...
    "exp011a_r1_tb1_t3a_results.mat"), ...
    "A","S","M","V","selftest","cfg","-v7.3");

fprintf('\n============================================================\n');
fprintf('EXP011-A-R1 COMPLETE\n');
fprintf('Verdict: %s\n',string(V.overall_verdict(1)));
fprintf('Results: %s\n',cfg.output_dir);
fprintf('============================================================\n');

end

%% ========================================================================
function validate_cfg_contract(cfg)

required = [ ...
    "allow_data_fitting","allow_label_based_parameter_tuning", ...
    "use_true_strong_beta_control","add_noise","reestimate_beta", ...
    "local_search_halfwidth_bins","local_bracket_points", ...
    "global_search_lo_bins","global_search_hi_bins", ...
    "global_grid_step_bins","geometry_grid_step_bins", ...
    "geometry_search_lo_bins","geometry_search_hi_bins", ...
    "branch_match_tolerance_bins", ...
    "catastrophic_error_threshold_bins", ...
    "risk_states_path","output_dir","figure_dir"];

for i=1:numel(required)
    if ~isfield(cfg,required(i))
        error('EXP011A:MissingConfigField', ...
            'Missing cfg.%s',required(i));
    end
end

assert(~cfg.allow_data_fitting, ...
    'EXP011A forbids fitting theory to data.');
assert(~cfg.allow_label_based_parameter_tuning, ...
    'EXP011A forbids label-based parameter tuning.');
assert(cfg.use_true_strong_beta_control, ...
    'TB1-T3A must use true strong-beta/chirp control.');
assert(~cfg.add_noise, ...
    'Noise belongs outside TB1-T3A.');
assert(~cfg.reestimate_beta, ...
    'Practical beta estimation belongs to Theory Bridge 2.');
assert(abs(cfg.local_search_halfwidth_bins-0.75)<eps, ...
    'Frozen PA5I local halfwidth changed.');
assert(cfg.local_bracket_points==33, ...
    'Frozen PA5I bracket count changed.');
assert(abs(cfg.branch_match_tolerance_bins-0.02)<eps, ...
    'Frozen branch-match tolerance changed.');
assert(abs(cfg.catastrophic_error_threshold_bins-0.10)<eps, ...
    'Frozen catastrophic threshold changed.');
assert(isequal(cfg.dense_eta_bins,0:0.01:0.5), ...
    'Frozen PA5I-R1 dense eta grid changed.');

end

%% ========================================================================
function ensure_output_dirs(cfg)
if ~exist(cfg.output_dir,'dir'), mkdir(cfg.output_dir); end
if ~exist(cfg.figure_dir,'dir'), mkdir(cfg.figure_dir); end
end

%% ========================================================================
function R = read_risk_states(cfg)

if ~exist(cfg.risk_states_path,'file')
    error('EXP011A:MissingRiskStates', ...
        ['Frozen PA5I-R1 risk-state table not found:\n%s\n' ...
         'Restore PA5I-R1 results before running EXP011-A.'], ...
        cfg.risk_states_path);
end

R = readtable(cfg.risk_states_path,'TextType','string');

required = [ ...
    "risk_state_id","aperture_mode","azimuth_samples", ...
    "delta_velocity_mps","strong_velocity_side", ...
    "strong_velocity_mps","weak_to_strong_ratio", ...
    "relative_phase_rad","strong_chirp_rate_discrete", ...
    "weak_chirp_rate_discrete"];

missing = setdiff(required,string(R.Properties.VariableNames));
if ~isempty(missing)
    error('EXP011A:RiskStateSchemaMismatch', ...
        'PA5I-R1 risk-state table missing: %s', ...
        strjoin(missing,', '));
end

if numel(unique(R.risk_state_id))~=height(R)
    error('EXP011A:DuplicateRiskState', ...
        'risk_state_id must be unique.');
end

end

%% ========================================================================
function T = build_frozen_trials(R,cfg)

aps = unique(string(R.aperture_mode),'stable');
rows = {};
id = 0;

for ia=1:numel(aps)
    ap = aps(ia);
    Ra = R(string(R.aperture_mode)==ap,:);

    if cfg.run_mode=="smoke"
        Ra = Ra(1:min(cfg.smoke_states_per_aperture,height(Ra)),:);
        eta_list = cfg.smoke_eta_bins;
    else
        eta_list = cfg.dense_eta_bins;
    end

    for is=1:height(Ra)
        for ie=1:numel(eta_list)
            id = id+1;
            rows(end+1,:) = { ... %#ok<AGROW>
                id, ...
                double(Ra.risk_state_id(is)), ...
                char(ap), ...
                double(Ra.azimuth_samples(is)), ...
                double(Ra.delta_velocity_mps(is)), ...
                char(string(Ra.strong_velocity_side(is))), ...
                double(Ra.strong_velocity_mps(is)), ...
                double(Ra.weak_to_strong_ratio(is)), ...
                double(Ra.relative_phase_rad(is)), ...
                double(eta_list(ie)), ...
                double(Ra.strong_chirp_rate_discrete(is)), ...
                double(Ra.weak_chirp_rate_discrete(is))};
        end
    end
end

T = cell2table(rows,'VariableNames',{ ...
    'trial_id','risk_state_id','aperture_mode','azimuth_samples', ...
    'delta_velocity_mps','strong_velocity_side','strong_velocity_mps', ...
    'weak_to_strong_ratio','relative_phase_rad','true_eta_bins', ...
    'true_a_strong','true_a_weak'});

end

%% ========================================================================
function [A,selftest] = run_geometry_audit(T,cfg)

nT = height(T);
rows = cell(nT,57);

identity_max = 0;
identity_fail = 0;

for i=1:nT
    if i==1 || i==nT || mod(i,cfg.progress_every)==0
        fprintf('  geometry audit: %d / %d\n',i,nT);
    end

    N = double(T.azimuth_samples(i));
    m = 0:N-1;

    eta = double(T.true_eta_bins(i));
    r = double(T.weak_to_strong_ratio(i));
    phi = double(T.relative_phase_rad(i));
    aS = double(T.true_a_strong(i));
    aW = double(T.true_a_weak(i));
    da = aW-aS;

    % PA5H / PA5I-consistent mixture.
    b = eta/N;
    s = synth_discrete_lfm(N,1,aS,b,0);
    p_unit = synth_discrete_lfm(N,1,aW,b,phi);
    x = s + r*p_unit;

    % TRUE strong-chirp control for TB1 only.
    z0 = dechirp_signal(s,aS);
    zp = dechirp_signal(p_unit,aS);
    z = dechirp_signal(x,aS);

    % Exact J = J0 + r J1 + r^2 J2 identity check.
    qtest = unique([ ...
        cfg.global_search_lo_bins:0.05:cfg.global_search_hi_bins, ...
        floor(eta)-1, floor(eta), ceil(eta), ceil(eta)+1]);
    iderr = exact_decomposition_error(z,z0,zp,r,m,N,qtest);
    identity_max = max(identity_max,iderr);
    if iderr>cfg.objective_identity_rel_tol
        identity_fail = identity_fail+1;
    end

    % Current continuous objective geometry.
    P = find_continuous_peaks(z,m,N,cfg);
    if isempty(P.nu)
        error('EXP011A:NoContinuousPeak', ...
            'No local maxima found for trial %d.',i);
    end

    % Correct/physical branch: current local peak nearest injected eta.
    [dist_to_eta,ic] = min(abs(P.nu-eta));
    nu_c = P.nu(ic);
    Vc = P.J(ic);

    % Current global continuous winner.
    [Vg,ig] = max(P.J);
    nu_g = P.nu(ig);
    continuous_switch = ig~=ic;

    % Best continuous competitor.
    mask_other = true(size(P.nu));
    mask_other(ic)=false;
    if any(mask_other)
        [Vb_global,ix] = max(P.J(mask_other));
        idx_other = find(mask_other);
        ib_global = idx_other(ix);
        nu_b_global = P.nu(ib_global);
        M_global = Vc-Vb_global;
    else
        Vb_global = NaN;
        nu_b_global = NaN;
        M_global = Inf;
    end

    % Actual G0 reconstruction: integer DFT top-1 -> local refinement.
    [k0,coarse_top,coarse_second,coarse_tie] = ...
        strongest_integer_seed(z,N,cfg);
    G0 = refine_from_seed(z,m,N,k0,cfg);

    % GlobalReference under the same true-beta objective. The continuous
    % peak bank already uses the frozen [-1.5,+1.5] domain and 1e-3 grid
    % followed by fminbnd refinement, so its global winner is the
    % reference. Reusing it avoids a duplicate dense objective scan.
    Gref = struct();
    Gref.nu_hat_bins = nu_g;
    Gref.objective_at_hat = Vg;

    % Neighbor-3 reconstruction.
    N3 = estimate_neighbor3(z,m,N,k0,cfg);

    % Branch-accessible coarse scores C_j.
    B = build_seed_branch_map(z,m,N,P,cfg);

    idx_c = B.branch_id==ic;
    if any(idx_c)
        [Cc,jc] = max(B.coarse_J(idx_c));
        idxc_all = find(idx_c);
        kc = B.seed(idxc_all(jc));
    else
        Cc = -Inf;
        kc = NaN;
    end

    % Keep same competitor branch for M, L and M_tilde identity.
    valid_comp = B.branch_id>0 & B.branch_id~=ic;
    if any(valid_comp)
        comp_rows = find(valid_comp);
        [Cb,jbrow] = max(B.coarse_J(valid_comp));
        rr = comp_rows(jbrow);
        ib_coarse = B.branch_id(rr);
        kb = B.seed(rr);
        Vb_coarse = P.J(ib_coarse);
        nu_b_coarse = P.nu(ib_coarse);

        M_cb = Vc-Vb_coarse;
        Lc = Vc-Cc;
        Lb = Vb_coarse-Cb;
        Mt = Cc-Cb;
        fence_identity = Mt - (M_cb-(Lc-Lb));
    else
        Cb = NaN; kb = NaN;
        Vb_coarse = NaN; nu_b_coarse = NaN;
        M_cb = Inf; Lc = Vc-Cc; Lb = NaN; Mt = Inf;
        fence_identity = NaN;
    end

    % Assign reconstructed estimates to continuous branches.
    g0_branch = assign_to_branch(G0.nu_hat_bins,P.nu,cfg);
    n3_branch = assign_to_branch(N3.nu_hat_bins,P.nu,cfg);
    gref_branch = assign_to_branch(Gref.nu_hat_bins,P.nu,cfg);

    coarse_inversion = g0_branch>0 && g0_branch~=ic;
    n3_recovers_correct = n3_branch==ic;

    branch_error = abs(circular_bin_error( ...
        G0.nu_hat_bins,Gref.nu_hat_bins));
    catastrophic = branch_error>cfg.catastrophic_error_threshold_bins;

    if ~continuous_switch && ~coarse_inversion
        regime = "R0_CONTINUOUS_AND_COARSE_CORRECT";
    elseif ~continuous_switch && coarse_inversion
        regime = "R1_DISCRETE_FIRST";
    elseif continuous_switch && coarse_inversion
        regime = "R2_CONTINUOUS_SWITCH_AND_COARSE_WRONG";
    else
        regime = "R3_CONTINUOUS_SWITCH_COARSE_BASELINE";
    end

    % Pre-declared mismatch taxonomy.
    near_halfbin = abs(abs(eta-round(eta))-0.5)<=0.011;
    topology_flag = P.n_peaks<2 || dist_to_eta>0.75;
    branch_map_unresolved = g0_branch==0 || gref_branch==0;
    no_accessible_competitor = ~isfinite(Cb) || ~isfinite(Mt);
    sign_prediction = sign_with_tol(Mt,cfg.margin_zero_rel_tol);
    observed_coarse_correct = ~coarse_inversion;

    if coarse_tie
        mismatch_type = "TYPE_III_COARSE_TIE_NONSMOOTH";
    elseif topology_flag
        mismatch_type = "TYPE_III_TOPOLOGY_OR_BRANCH_DEFINITION";
    elseif branch_map_unresolved
        mismatch_type = "TYPE_III_BRANCH_ASSIGNMENT_UNRESOLVED";
    elseif no_accessible_competitor
        mismatch_type = "TYPE_III_NO_ACCESSIBLE_COMPETITOR";
    elseif sign_prediction>0 && ~observed_coarse_correct
        mismatch_type = "TYPE_I_POTENTIAL_FALSIFICATION";
    elseif sign_prediction<0 && observed_coarse_correct
        mismatch_type = "TYPE_I_POTENTIAL_FALSIFICATION";
    elseif sign_prediction==0
        mismatch_type = "TYPE_III_MARGIN_NEAR_ZERO";
    else
        mismatch_type = "CONSISTENT_WITH_TB1";
    end

    % Exact component law at current branch coarse representatives.
    if isfinite(kc)
        [J0c,J1c,J2c] = objective_components(z0,zp,m,N,kc);
    else
        J0c=NaN; J1c=NaN; J2c=NaN;
    end
    if isfinite(kb)
        [J0b,J1b,J2b] = objective_components(z0,zp,m,N,kb);
    else
        J0b=NaN; J1b=NaN; J2b=NaN;
    end

    coarse_margin_direct = Mt;
    coarse_margin_component = ...
        (J0c-J0b) + r*(J1c-J1b) + r^2*(J2c-J2b);
    component_margin_error = coarse_margin_direct-coarse_margin_component;

    rows(i,:) = { ...
        double(T.trial_id(i)), ...
        double(T.risk_state_id(i)), ...
        char(string(T.aperture_mode(i))), ...
        N, ...
        double(T.delta_velocity_mps(i)), ...
        char(string(T.strong_velocity_side(i))), ...
        r,phi,eta,aS,aW,da, ...
        P.n_peaks,nu_c,Vc,dist_to_eta, ...
        nu_g,Vg,continuous_switch, ...
        nu_b_global,Vb_global,M_global, ...
        k0,coarse_top,coarse_second,coarse_tie, ...
        G0.nu_hat_bins,G0.objective_at_hat,g0_branch, ...
        Gref.nu_hat_bins,Gref.objective_at_hat,gref_branch, ...
        N3.nu_hat_bins,N3.objective_at_hat,n3_branch, ...
        n3_recovers_correct, ...
        kc,Cc,kb,Cb,nu_b_coarse,Vb_coarse, ...
        M_cb,Lc,Lb,Mt,fence_identity, ...
        branch_error,catastrophic,char(regime), ...
        near_halfbin,char(mismatch_type), ...
        iderr,component_margin_error, ...
        J0c-J0b,J1c-J1b,J2c-J2b};
end

A = cell2table(rows,'VariableNames',{ ...
    'trial_id','risk_state_id','aperture_mode','azimuth_samples', ...
    'delta_velocity_mps','strong_velocity_side', ...
    'weak_to_strong_ratio','relative_phase_rad','true_eta_bins', ...
    'true_a_strong','true_a_weak','delta_a', ...
    'n_continuous_peaks','correct_branch_nu','correct_branch_value', ...
    'correct_branch_abs_offset_from_eta', ...
    'global_branch_nu','global_branch_value','continuous_switch', ...
    'best_continuous_competitor_nu','best_continuous_competitor_value', ...
    'continuous_global_margin', ...
    'g0_coarse_seed','g0_coarse_top_value','g0_coarse_second_value', ...
    'g0_coarse_tie_flag','g0_nu_hat','g0_refined_value','g0_branch_id', ...
    'global_ref_nu','global_ref_value','global_ref_branch_id', ...
    'n3_nu_hat','n3_refined_value','n3_branch_id', ...
    'n3_recovers_correct_branch', ...
    'correct_branch_best_seed','C_correct', ...
    'coarse_competitor_best_seed','C_competitor', ...
    'coarse_competitor_nu','V_coarse_competitor', ...
    'M_continuous_same_competitor','L_correct','L_competitor', ...
    'M_tilde_effective_coarse','fence_decomposition_error', ...
    'g0_branch_error_vs_global','g0_catastrophic','tb1_regime', ...
    'near_halfbin_flag','mismatch_taxonomy', ...
    'objective_identity_rel_error','component_margin_error', ...
    'delta_J0_coarse','delta_J1_coarse','delta_J2_coarse'});

selftest = table();
selftest.n_trials = height(A);
selftest.max_objective_identity_rel_error = identity_max;
selftest.n_objective_identity_fail = identity_fail;
selftest.max_abs_fence_decomposition_error = ...
    max(abs(A.fence_decomposition_error),[],'omitnan');
selftest.max_abs_component_margin_error = ...
    max(abs(A.component_margin_error),[],'omitnan');
selftest.theory_fitting_used = false;
selftest.noise_used = false;
selftest.practical_beta_reestimated = false;

end

%% ========================================================================
function P = find_continuous_peaks(z,m,N,cfg)

q = cfg.geometry_search_lo_bins: ...
    cfg.geometry_grid_step_bins:cfg.geometry_search_hi_bins;

J = zeros(size(q));
for i=1:numel(q)
    J(i)=tone_objective(z,m,N,q(i));
end

idx = [];
for i=2:numel(q)-1
    if J(i)>=J(i-1) && J(i)>=J(i+1) && ...
            (J(i)>J(i-1) || J(i)>J(i+1))
        idx(end+1)=i; %#ok<AGROW>
    end
end

if J(1)>J(2), idx=[1,idx]; end %#ok<AGROW>
if J(end)>J(end-1), idx=[idx,numel(q)]; end %#ok<AGROW>

nu = [];
Jp = [];

for ii=1:numel(idx)
    i=idx(ii);

    if i==1 || i==numel(q)
        nuh=q(i);
        Jh=J(i);
    else
        lb=q(i-1);
        ub=q(i+1);
        opts=optimset('Display','off', ...
            'TolX',cfg.global_tolx_bins, ...
            'MaxFunEvals',cfg.global_max_fun_evals);
        [nuh,fval]=fminbnd(@(x)-tone_objective(z,m,N,x),lb,ub,opts);
        Jh=-fval;
    end

    if isempty(nu) || min(abs(nu-nuh))>cfg.localmax_merge_tolerance_bins
        nu(end+1)=nuh; %#ok<AGROW>
        Jp(end+1)=Jh; %#ok<AGROW>
    else
        [~,jj]=min(abs(nu-nuh));
        if Jh>Jp(jj)
            nu(jj)=nuh;
            Jp(jj)=Jh;
        end
    end
end

[nu,ord]=sort(nu);
Jp=Jp(ord);

P=struct();
P.nu=nu(:).';
P.J=Jp(:).';
P.n_peaks=numel(nu);

end

%% ========================================================================
function B = build_seed_branch_map(z,m,N,P,cfg)

seeds = cfg.seed_min:cfg.seed_max;
n = numel(seeds);

branch_id = zeros(n,1);
nu_ref = nan(n,1);
J_ref = nan(n,1);
coarse_J = nan(n,1);

for i=1:n
    k=seeds(i);
    coarse_J(i)=tone_objective(z,m,N,k);

    G=refine_from_seed(z,m,N,k,cfg);
    nu_ref(i)=G.nu_hat_bins;
    J_ref(i)=G.objective_at_hat;
    branch_id(i)=assign_to_branch(G.nu_hat_bins,P.nu,cfg);
end

B=table(seeds(:),coarse_J,nu_ref,J_ref,branch_id, ...
    'VariableNames',{'seed','coarse_J','refined_nu','refined_J','branch_id'});

end

%% ========================================================================
function id = assign_to_branch(nu,peaks,cfg)

if isempty(peaks) || ~isfinite(nu)
    id=0;
    return;
end

[d,id0]=min(abs(peaks-nu));
if d<=cfg.branch_assignment_tol_bins
    id=id0;
else
    id=0;
end

end

%% ========================================================================
function [k0,J1,J2,tieflag] = strongest_integer_seed(z,N,cfg)

% Exact integer samples of the tone objective are FFT magnitudes.
Y=fft(z);
J=abs(Y).^2/(N^2);

k=0:N-1;
k(k>floor(N/2))=k(k>floor(N/2))-N;

[Js,ord]=sort(J,'descend');
k0=k(ord(1));
J1=Js(1);
if numel(Js)>=2
    J2=Js(2);
else
    J2=NaN;
end

scale=max(abs(J1),1);
tieflag = isfinite(J2) && abs(J1-J2)<=cfg.coarse_tie_rel_tol*scale;

end

%% ========================================================================
function G = refine_from_seed(z,m,N,seed,cfg)

lb=seed-cfg.local_search_halfwidth_bins;
ub=seed+cfg.local_search_halfwidth_bins;

grid=linspace(lb,ub,cfg.local_bracket_points);
J=zeros(size(grid));
for i=1:numel(grid)
    J(i)=tone_objective(z,m,N,grid(i));
end

[~,ib]=max(J);
i1=max(1,ib-1);
i2=min(numel(grid),ib+1);
local_lb=grid(i1);
local_ub=grid(i2);

if local_ub<=local_lb
    nu=grid(ib);
    Jhat=J(ib);
else
    opts=optimset('Display','off', ...
        'TolX',cfg.local_tolx_bins, ...
        'MaxFunEvals',cfg.local_max_fun_evals);
    [nu,fval]=fminbnd(@(q)-tone_objective(z,m,N,q), ...
        local_lb,local_ub,opts);
    Jhat=-fval;
end

G=struct();
G.nu_hat_bins=nu;
G.objective_at_hat=Jhat;

end

%% ========================================================================
function G = estimate_global_reference(z,m,N,cfg)

d=cfg.global_search_lo_bins: ...
    cfg.global_grid_step_bins:cfg.global_search_hi_bins;

J=zeros(size(d));
for i=1:numel(d)
    J(i)=tone_objective(z,m,N,d(i));
end

[~,ig]=max(J);
i1=max(1,ig-1);
i2=min(numel(d),ig+1);
lb=d(i1);
ub=d(i2);

if ub<=lb
    nu=d(ig);
    Jhat=J(ig);
else
    opts=optimset('Display','off', ...
        'TolX',cfg.global_tolx_bins, ...
        'MaxFunEvals',cfg.global_max_fun_evals);
    [nu,fval]=fminbnd(@(q)-tone_objective(z,m,N,q),lb,ub,opts);
    Jhat=-fval;
end

G=struct();
G.nu_hat_bins=nu;
G.objective_at_hat=Jhat;

end

%% ========================================================================
function G = estimate_neighbor3(z,m,N,k0,cfg)

seeds=[k0-1,k0,k0+1];

bestJ=-Inf;
bestNu=NaN;

for i=1:numel(seeds)
    Gi=refine_from_seed(z,m,N,seeds(i),cfg);
    if Gi.objective_at_hat>bestJ
        bestJ=Gi.objective_at_hat;
        bestNu=Gi.nu_hat_bins;
    end
end

G=struct();
G.nu_hat_bins=bestNu;
G.objective_at_hat=bestJ;

end

%% ========================================================================
function err = exact_decomposition_error(z,z0,zp,r,m,N,q)

num=0;
den=0;

for i=1:numel(q)
    J=tone_objective(z,m,N,q(i));
    [J0,J1,J2]=objective_components(z0,zp,m,N,q(i));
    Jd=J0+r*J1+r^2*J2;
    num=max(num,abs(J-Jd));
    den=max(den,abs(J));
end

err=num/max(den,1);

end

%% ========================================================================
function [J0,J1,J2] = objective_components(z0,zp,m,N,nu)

e=exp(-1j*2*pi*nu*m/N);
C0=sum(z0.*e);
Cp=sum(zp.*e);

% Normalize by N^2 for conditioning only. Signs/rankings are unchanged.
J0=abs(C0).^2/(N^2);
J1=2*real(C0*conj(Cp))/(N^2);
J2=abs(Cp).^2/(N^2);

end

%% ========================================================================
function J = tone_objective(z,m,N,nu)

q=sum(z.*exp(-1j*2*pi*nu*m/N));
J=abs(q).^2/(N^2);

end

%% ========================================================================
function z = dechirp_signal(x,a)

x=x(:).';
N=numel(x);
m=0:N-1;
z=x.*exp(-1j*pi*a*m.^2);

end

%% ========================================================================
function x = synth_discrete_lfm(N,A,a,b,phi)

m=0:N-1;
x=A.*exp(1j*2*pi*(0.5*a*m.^2+b*m)+1j*phi);
x=x(:).';

end

%% ========================================================================
function e = circular_bin_error(a,b)
e=mod((a-b)+0.5,1)-0.5;
end

%% ========================================================================
function s = sign_with_tol(x,rel_tol)

if ~isfinite(x)
    s=0;
    return;
end

scale=max(abs(x),1);
tol=rel_tol*scale;

if x>tol
    s=1;
elseif x<-tol
    s=-1;
else
    s=0;
end

end

%% ========================================================================
function S = summarize_audit(A)

aps=unique(string(A.aperture_mode),'stable');
regs=[ ...
    "R0_CONTINUOUS_AND_COARSE_CORRECT", ...
    "R1_DISCRETE_FIRST", ...
    "R2_CONTINUOUS_SWITCH_AND_COARSE_WRONG", ...
    "R3_CONTINUOUS_SWITCH_COARSE_BASELINE"];

rows={};

for ia=1:numel(aps)
    ap=aps(ia);
    idx=string(A.aperture_mode)==ap;
    n=sum(idx);

    for ir=1:numel(regs)
        rg=regs(ir);
        m=idx & string(A.tb1_regime)==rg;

        rows(end+1,:)={ ... %#ok<AGROW>
            char(ap),char(rg),n,sum(m),sum(m)/max(n,1), ...
            sum(A.g0_catastrophic(m)), ...
            sum(A.near_halfbin_flag(m)), ...
            median(A.M_continuous_same_competitor(m),'omitnan'), ...
            median(A.M_tilde_effective_coarse(m),'omitnan')};
    end
end

S=cell2table(rows,'VariableNames',{ ...
    'aperture_mode','tb1_regime','n_aperture_trials','n_regime', ...
    'regime_fraction','n_g0_catastrophic','n_near_halfbin', ...
    'median_continuous_margin','median_effective_coarse_margin'});

n=height(A);
for ir=1:numel(regs)
    rg=regs(ir);
    m=string(A.tb1_regime)==rg;
    S=[S; cell2table({ ...
        'ALL',char(rg),n,sum(m),sum(m)/max(n,1), ...
        sum(A.g0_catastrophic(m)),sum(A.near_halfbin_flag(m)), ...
        median(A.M_continuous_same_competitor(m),'omitnan'), ...
        median(A.M_tilde_effective_coarse(m),'omitnan')}, ...
        'VariableNames',S.Properties.VariableNames)]; %#ok<AGROW>
end

end

%% ========================================================================
function M = summarize_mismatch_taxonomy(A)

cats=unique(string(A.mismatch_taxonomy),'stable');
rows={};

for i=1:numel(cats)
    c=cats(i);
    idx=string(A.mismatch_taxonomy)==c;
    rows(end+1,:)={ ... %#ok<AGROW>
        char(c),sum(idx),mean(idx), ...
        sum(A.g0_catastrophic(idx)), ...
        sum(A.near_halfbin_flag(idx))};
end

M=cell2table(rows,'VariableNames',{ ...
    'mismatch_taxonomy','n_trials','fraction', ...
    'n_g0_catastrophic','n_near_halfbin'});

end

%% ========================================================================
function V = form_verdict(A,selftest,cfg)

nR1=sum(string(A.tb1_regime)=="R1_DISCRETE_FIRST");
nPotential=sum(string(A.mismatch_taxonomy)=="TYPE_I_POTENTIAL_FALSIFICATION");
nConsistent=sum(string(A.mismatch_taxonomy)=="CONSISTENT_WITH_TB1");

identity_pass = selftest.n_objective_identity_fail==0 && ...
    selftest.max_objective_identity_rel_error<=cfg.objective_identity_rel_tol;

if ~identity_pass
    verdict="STOP_IMPLEMENTATION_IDENTITY_FAILURE";
elseif nPotential>0
    verdict="TB1_REQUIRES_REVIEW_POTENTIAL_FALSIFICATION";
elseif nR1>0
    verdict="TB1_SUPPORTED_DISCRETE_FIRST_REGIME_OBSERVED";
else
    verdict="TB1_PARTIAL_SUPPORT_NO_DISCRETE_FIRST_REQUIRED";
end

V=table();
V.overall_verdict=verdict;
V.n_trials=height(A);
V.n_R1_discrete_first=nR1;
V.n_potential_falsification=nPotential;
V.n_consistent=nConsistent;
V.n_g0_catastrophic=sum(A.g0_catastrophic);
V.n_n3_recovers_correct_branch=sum(A.n3_recovers_correct_branch);
V.identity_pass=identity_pass;
V.theory_fitting_used=false;

end

%% ========================================================================
function write_outputs(A,S,M,V,selftest,cfg)

writetable(A,fullfile(cfg.output_dir, ...
    "exp011a_r1_tb1_t3a_trials.csv"));
writetable(S,fullfile(cfg.output_dir, ...
    "exp011a_r1_tb1_t3a_regime_summary.csv"));
writetable(M,fullfile(cfg.output_dir, ...
    "exp011a_r1_tb1_t3a_mismatch_taxonomy.csv"));
writetable(V,fullfile(cfg.output_dir, ...
    "exp011a_r1_tb1_t3a_verdict.csv"));
writetable(selftest,fullfile(cfg.output_dir, ...
    "exp011a_r1_tb1_t3a_selftest.csv"));

path=fullfile(cfg.output_dir,cfg.feedback_bundle_name);
fid=fopen(path,'w');
if fid<0
    error('EXP011A:FeedbackOpenFailed', ...
        'Cannot open feedback bundle.');
end
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP011-A-R1 / THEORY BRIDGE 1 / T3A\n');
fprintf(fid,'RETROSPECTIVE OBJECTIVE-GEOMETRY AUDIT\n');
fprintf(fid,'======================================\n\n');

fprintf(fid,'NON-FITTING DECLARATION\n');
fprintf(fid,'-----------------------\n');
fprintf(fid,'THIS AUDIT DOES NOT FIT THEORY TO DATA.\n');
fprintf(fid,'NO THEORY PARAMETER IS ESTIMATED FROM FAILURE LABELS.\n');
fprintf(fid,'Noise = OFF.\n');
fprintf(fid,'Strong chirp/beta = TRUE-CONTROL.\n');
fprintf(fid,'Practical beta estimation = OFF.\n');
fprintf(fid,'R1 PATCH: geometry domain expanded from frozen seed-window coverage only; GlobalReference remains [-1.5,+1.5].\n');
fprintf(fid,'R1 PATCH: nonfinite/no-competitor margin is no longer mislabeled as near-zero.\n\n');

fprintf(fid,'FORMAL THEORY QUESTIONS\n');
fprintf(fid,'-----------------------\n');
fprintf(fid,'H1: Does effective coarse-margin sign agree with the replayed coarse branch winner in regular cases?\n');
fprintf(fid,'H2: Does an R1 discrete-first regime exist (continuous branch correct, coarse branch wrong)?\n');
fprintf(fid,'H3: Are mismatches concentrated in pre-declared tie/topology/non-smooth cases rather than silently fitted?\n\n');

write_table_tsv(fid,'VERDICT',V);
write_table_tsv(fid,'SELFTEST',selftest);
write_table_tsv(fid,'REGIME SUMMARY',S);
write_table_tsv(fid,'MISMATCH TAXONOMY',M);

fprintf(fid,'\nINTERPRETATION DISCIPLINE\n');
fprintf(fid,'-------------------------\n');
fprintf(fid,'1) R1 > 0 strongly supports the discrete-first branch-failure mechanism, but R1 = 0 does NOT falsify TB1.\n');
fprintf(fid,'2) If R1 = 0 and R2 dominates, report that the frozen PA5I-R1 background is continuous-competition dominated.\n');
fprintf(fid,'3) TYPE_I_POTENTIAL_FALSIFICATION must be inspected before any theory revision.\n');
fprintf(fid,'4) TYPE_III cases are outside the smooth fixed-representative assumption and must not be used to tune the theory.\n');
fprintf(fid,'5) No regression, curve fitting, learned threshold, or label-based coefficient is permitted.\n');
fprintf(fid,'6) EXP010-B/C practical-beta or noise mismatch belongs to Theory Bridge 2 / robustness, not TB1-T3A.\n');

end

%% ========================================================================
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

%% ========================================================================
function s = scalar_to_string(x)

if iscell(x), x=x{1}; end

if isstring(x)
    s=x;
elseif ischar(x)
    s=string(x);
elseif islogical(x)
    s=string(double(x));
elseif isnumeric(x)
    if isempty(x)
        s="";
    elseif isscalar(x)
        s=string(sprintf('%.15g',x));
    else
        s=string(mat2str(x));
    end
else
    s=string(x);
end

end

%% ========================================================================
function make_figures(A,cfg)

if ~cfg.save_figures
    return;
end

f=figure('Visible',cfg.figure_visible);
scatter(A.M_continuous_same_competitor, ...
    A.M_tilde_effective_coarse,16,'filled');
xlabel('Continuous margin $M_{cb}$','Interpreter','latex');
ylabel('Effective coarse margin $\widetilde{M}_{cb}$','Interpreter','latex');
title('TB1-T3A: Continuous vs Coarse Branch Margin');
grid on;
xline(0,'--'); yline(0,'--');
exportgraphics(f,fullfile(cfg.figure_dir, ...
    'fig01_continuous_vs_coarse_margin.png'),'Resolution',180);
close(f);

f=figure('Visible',cfg.figure_visible);
scatter(A.true_eta_bins,A.M_tilde_effective_coarse,16,'filled');
xlabel('Fractional-bin offset $\eta$ (bin)','Interpreter','latex');
ylabel('Effective coarse margin $\widetilde{M}_{cb}$','Interpreter','latex');
title('TB1-T3A: Fence Geometry and Effective Coarse Margin');
grid on;
yline(0,'--');
exportgraphics(f,fullfile(cfg.figure_dir, ...
    'fig02_coarse_margin_vs_eta.png'),'Resolution',180);
close(f);

end
