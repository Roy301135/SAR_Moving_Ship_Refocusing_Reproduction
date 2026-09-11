function results = exp09c3b1_2_mechanism_observable_audit()
%EXP09C3B1_2_MECHANISM_OBSERVABLE_AUDIT
% EXP009 / Pilot-01 / C3-B1.2
%
% Mechanism-Informed Realization Observable Audit
%
% -------------------------------------------------------------------------
% Why this experiment exists
% -------------------------------------------------------------------------
% C3-B1.1 established:
%
%   physical state
%       -> highly reproducible fallback-value structure
%
% but:
%
%   prominence + entropy
%       -> only weak within-state Beneficial discrimination
%
% and:
%
%   State + prominence + entropy
%       -> only a small matched-budget gain over StateOnly.
%
% Therefore C3-B1.2 does NOT make the policy more complicated.
%
% Instead it asks:
%
%   Which signal-level observables contain genuine realization-level
%   information at FIXED physical state?
%
% The experiment audits three mechanism-informed families:
%
%   A) weak-search q-curve morphology
%   B) strong-residual / weak-competition observables
%   C) sub-aperture q-search stability
%
% Beneficial and Harmful are audited separately.
%
% -------------------------------------------------------------------------
% Controlled boundary
% -------------------------------------------------------------------------
% q_strong remains known/oracle, identical to C3-B1.
%
% Signal trajectory, SNR, Cheap branch, parametric-refit fallback,
% Monte-Carlo seeds, q-grid and recovery criterion all match C3-B1.
%
% The experiment reruns signal-level data because the richer q-curves and
% sub-aperture observables were not saved in the original C3-B1 CSV bank.
%
% -------------------------------------------------------------------------
% Information hierarchy
% -------------------------------------------------------------------------
% StateOnly
%
% BaselinePE:
%   prominence + entropy
%
% MorphologyOnly:
%   richer q-curve shape / competing-peak observables
%
% StrongCompetitionOnly:
%   q_strong-referenced curve and residual-spectrum observables
%
% SubapertureOnly:
%   stability of weak-q evidence across sub-apertures
%
% AllObservable:
%   all practical realization observables, no state
%
% State + each observable family:
%   tests whether richer realization evidence adds information above the
%   physical-state prior.
%
% All models use exactly the same two-headed ridge-logistic architecture:
%
%   pB = P(Beneficial | X)
%   pH = P(Harmful    | X)
%
%   V = pB - pH.
%
% This keeps the focus on INFORMATION rather than model capacity.
%
% -------------------------------------------------------------------------
% Most important metric
% -------------------------------------------------------------------------
% Weighted within-line AUC.
%
% For a fixed line k:
%
%   A_w/A_s, q_s-q_w and state prior are fixed.
%
% Therefore any AUC > 0.5 comes from realization-level variation.
%
% Run:
%   results = exp09c3b1_2_mechanism_observable_audit;

cfg = config_exp09c3b1_2();

%% Resolve paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.output_dir)
    out_dir = fullfile( ...
        paper_root,'results','exp09_pilot01', ...
        'exp09c3b1_2_mechanism_observable_audit');
else
    out_dir = cfg.output_dir;
end

if ~exist(out_dir,'dir')
    mkdir(out_dir);
end

if isempty(cfg.c3b1_result_dir)
    old_c3b1_dir = fullfile( ...
        paper_root,'results','exp09_pilot01', ...
        'exp09c3b1_signal_level_continuous_state');
else
    old_c3b1_dir = cfg.c3b1_result_dir;
end

fprintf('\n============================================================\n');
fprintf(' EXP009-C3-B1.2 / Mechanism-Informed Observable Audit\n');
fprintf('============================================================\n');
fprintf('Output: %s\n',out_dir);
fprintf('Lines/sequence: %d\n',cfg.num_lines);
fprintf('Train MC/regime: %d\n',cfg.num_train_mc);
fprintf('Test  MC/regime: %d\n',cfg.num_test_mc);
fprintf('SNR: %.1f dB\n',cfg.snr_db);
fprintf('Sub-apertures: %d\n\n',cfg.num_subapertures);

%% Common signal setup
N = cfg.N;
n = 0:N-1;
t = (n-N/2)/N;

q_search = cfg.q_search_min:cfg.q_search_step:cfg.q_search_max;
D_search = build_dechirp_dictionary(q_search,t,cfg);

%% Physical trajectories
traj_smooth = build_trajectory("Smooth",cfg);
traj_abrupt = build_trajectory("Abrupt",cfg);

writetable(traj_smooth, ...
    fullfile(out_dir,'trajectory_smooth.csv'));

writetable(traj_abrupt, ...
    fullfile(out_dir,'trajectory_abrupt.csv'));

%% Deterministic signal components
det_smooth = precompute_deterministic_chain( ...
    traj_smooth,t,cfg);

det_abrupt = precompute_deterministic_chain( ...
    traj_abrupt,t,cfg);

%% ------------------------------------------------------------------------
% Signal-level Monte Carlo with rich realization observables
rng(cfg.seed,'twister');

tic;
train_smooth = run_rich_signal_mc_bank( ...
    det_smooth,traj_smooth,cfg.num_train_mc, ...
    cfg.seed+100,D_search,q_search,t,cfg);
runtime_train_smooth = toc;

tic;
train_abrupt = run_rich_signal_mc_bank( ...
    det_abrupt,traj_abrupt,cfg.num_train_mc, ...
    cfg.seed+200,D_search,q_search,t,cfg);
runtime_train_abrupt = toc;

tic;
test_smooth = run_rich_signal_mc_bank( ...
    det_smooth,traj_smooth,cfg.num_test_mc, ...
    cfg.seed+1100,D_search,q_search,t,cfg);
runtime_test_smooth = toc;

tic;
test_abrupt = run_rich_signal_mc_bank( ...
    det_abrupt,traj_abrupt,cfg.num_test_mc, ...
    cfg.seed+1200,D_search,q_search,t,cfg);
runtime_test_abrupt = toc;

writetable(train_smooth, ...
    fullfile(out_dir,'train_rich_trials_smooth.csv'));

writetable(train_abrupt, ...
    fullfile(out_dir,'train_rich_trials_abrupt.csv'));

writetable(test_smooth, ...
    fullfile(out_dir,'test_rich_trials_smooth.csv'));

writetable(test_abrupt, ...
    fullfile(out_dir,'test_rich_trials_abrupt.csv'));

%% Optional exact-continuity guard against C3-B1 labels
continuity = verify_against_c3b1_if_available( ...
    train_smooth,train_abrupt, ...
    test_smooth,test_abrupt, ...
    old_c3b1_dir,cfg);

writetable(continuity, ...
    fullfile(out_dir,'c3b1_continuity_check.csv'));

%% ------------------------------------------------------------------------
% Cross-fitted state prior
[train_smooth,test_smooth,state_smooth] = ...
    attach_crossfit_state_prior( ...
    train_smooth,test_smooth,cfg);

[train_abrupt,test_abrupt,state_abrupt] = ...
    attach_crossfit_state_prior( ...
    train_abrupt,test_abrupt,cfg);

state_smooth.regime = repmat("Smooth",height(state_smooth),1);
state_abrupt.regime = repmat("Abrupt",height(state_abrupt),1);

state_summary = [state_smooth;state_abrupt];
state_summary = movevars(state_summary,'regime','Before',1);

writetable(state_summary, ...
    fullfile(out_dir,'state_prior_reproducibility.csv'));

rho_state_smooth = spearman_manual( ...
    state_smooth.train_state_prior_full, ...
    state_smooth.test_state_utility);

rho_state_abrupt = spearman_manual( ...
    state_abrupt.train_state_prior_full, ...
    state_abrupt.test_state_utility);

%% Regime labels
train_smooth.regime = repmat("Smooth",height(train_smooth),1);
train_abrupt.regime = repmat("Abrupt",height(train_abrupt),1);
test_smooth.regime = repmat("Smooth",height(test_smooth),1);
test_abrupt.regime = repmat("Abrupt",height(test_abrupt),1);

%% ------------------------------------------------------------------------
% Feature scaling/calibration
%
% We intentionally do not percentile-transform every new feature.
% The ridge-logistic models standardize columns on TRAIN. This lets us
% preserve signed physical meaning for features such as asymmetry and
% q-geometry.
%
train_all = [train_smooth;train_abrupt];

%% Single-feature information audit
feature_list = realization_feature_list();

single_feature_audit = audit_single_features( ...
    train_smooth,train_abrupt, ...
    test_smooth,test_abrupt, ...
    feature_list);

writetable(single_feature_audit, ...
    fullfile(out_dir,'single_feature_audit.csv'));

%% ------------------------------------------------------------------------
% Group models
group_names = string(cfg.feature_groups(:));
nGroups = numel(group_names);

train_all = [train_smooth;train_abrupt];

models = cell(nGroups,1);
feature_name_cell = cell(nGroups,1);

train_pred = struct();
smooth_pred = struct();
abrupt_pred = struct();

coef_rows = {};

for ig = 1:nGroups
    group = group_names(ig);

    [Xtr,names] = build_group_features(train_all,group);
    [Xs,~] = build_group_features(test_smooth,group);
    [Xa,~] = build_group_features(test_abrupt,group);

    mdl = fit_two_head_value_model( ...
        Xtr, ...
        train_all.beneficial, ...
        train_all.harmful, ...
        cfg);

    models{ig} = mdl;
    feature_name_cell{ig} = names;

    Ptr = predict_two_head_value(mdl,Xtr);
    Ps = predict_two_head_value(mdl,Xs);
    Pa = predict_two_head_value(mdl,Xa);

    key = char(group);

    train_pred.(key) = Ptr;
    smooth_pred.(key) = Ps;
    abrupt_pred.(key) = Pa;

    coef_names = ["Intercept";string(names(:))];

    for j = 1:numel(coef_names)
        coef_rows(end+1,:) = { ... %#ok<AGROW>
            key,char(coef_names(j)), ...
            mdl.betaB(j),mdl.betaH(j)};
    end
end

coef_table = cell2table(coef_rows, ...
    'VariableNames',{ ...
    'group','term','beta_beneficial','beta_harmful'});

writetable(coef_table, ...
    fullfile(out_dir,'group_model_coefficients.csv'));

%% Group information audit
group_audit = audit_group_models( ...
    test_smooth,test_abrupt, ...
    group_names,smooth_pred,abrupt_pred);

writetable(group_audit, ...
    fullfile(out_dir,'group_information_audit.csv'));

%% ------------------------------------------------------------------------
% State-bin conditional within-regime audit
state_bin_audit = audit_state_bins( ...
    train_smooth,train_abrupt, ...
    test_smooth,test_abrupt, ...
    group_names,smooth_pred,abrupt_pred,cfg);

writetable(state_bin_audit, ...
    fullfile(out_dir,'state_bin_group_audit.csv'));

%% ------------------------------------------------------------------------
% Matched-budget computation allocation
budget_curves = table();

for ir = 1:2
    if ir==1
        regime = "Smooth";
        Ttr = train_smooth;
        Tte = test_smooth;
        train_mask = train_all.regime=="Smooth";
        Ptest = smooth_pred;
    else
        regime = "Abrupt";
        Ttr = train_abrupt;
        Tte = test_abrupt;
        train_mask = train_all.regime=="Abrupt";
        Ptest = abrupt_pred;
    end

    for ig = 1:nGroups
        key = char(group_names(ig));

        score_train = ...
            train_pred.(key).value(train_mask);

        score_test = ...
            Ptest.(key).value;

        C = evaluate_policy_curve( ...
            Ttr,Tte,score_train,score_test, ...
            cfg.budget_grid);

        C.regime = repmat(regime,height(C),1);
        C.policy = repmat(group_names(ig),height(C),1);

        budget_curves = [budget_curves;C]; %#ok<AGROW>
    end

    Cto = trial_oracle_curve(Tte,cfg.budget_grid);
    Cto.regime = repmat(regime,height(Cto),1);
    Cto.policy = repmat("TrialOracle",height(Cto),1);

    Cr = random_expected_curve(Tte,cfg.budget_grid);
    Cr.regime = repmat(regime,height(Cr),1);
    Cr.policy = repmat("RandomExpected",height(Cr),1);

    budget_curves = [budget_curves;Cto;Cr]; %#ok<AGROW>
end

budget_curves = movevars( ...
    budget_curves,{'regime','policy'},'Before',1);

writetable(budget_curves, ...
    fullfile(out_dir,'mechanism_observable_budget_curves.csv'));

reported = extract_reported_budget_points( ...
    budget_curves,cfg.report_budgets);

writetable(reported, ...
    fullfile(out_dir,'reported_budget_points.csv'));

oracle_gap = compute_oracle_gap_capture( ...
    reported,cfg.report_budgets,group_names);

writetable(oracle_gap, ...
    fullfile(out_dir,'oracle_gap_capture.csv'));

%% ------------------------------------------------------------------------
% Compact decision summary
decision_summary = build_decision_summary( ...
    group_audit,reported,oracle_gap,cfg);

writetable(decision_summary, ...
    fullfile(out_dir,'decision_summary.csv'));

%% Runtime
runtime_summary = table( ...
    {'TrainSmooth';'TrainAbrupt';'TestSmooth';'TestAbrupt'}, ...
    [runtime_train_smooth;runtime_train_abrupt; ...
     runtime_test_smooth;runtime_test_abrupt], ...
    'VariableNames',{'bank','runtime_seconds'});

writetable(runtime_summary, ...
    fullfile(out_dir,'runtime_summary.csv'));

%% Console
fprintf('\n================ C3-B1.2 STATE ===============================\n');
fprintf('Smooth rho(train state,test utility) = %.4f\n',rho_state_smooth);
fprintf('Abrupt rho(train state,test utility) = %.4f\n',rho_state_abrupt);

fprintf('\n================ C3-B1.2 GROUP AUDIT =========================\n');
disp(group_audit);

fprintf('\n================ C3-B1.2 25%% BUDGET =========================\n');
rows25 = reported(abs(reported.target_budget-cfg.primary_budget)<1e-12,:);
disp(rows25(:,{ ...
    'regime','policy','policy_recall','beneficial_capture', ...
    'benefit_precision','harmful_fraction_among_triggers'}));

fprintf('\n================ C3-B1.2 DECISION ============================\n');
disp(decision_summary);
fprintf('==============================================================\n');

%% Summary text
write_summary( ...
    out_dir,cfg,rho_state_smooth,rho_state_abrupt, ...
    continuity,single_feature_audit,group_audit, ...
    reported,oracle_gap,decision_summary);

%% Figures
make_figures( ...
    out_dir,cfg,single_feature_audit, ...
    group_audit,state_bin_audit, ...
    budget_curves,reported,oracle_gap, ...
    test_smooth,test_abrupt);

%% Save
results = struct();
results.cfg = cfg;
results.state_summary = state_summary;
results.continuity = continuity;
results.single_feature_audit = single_feature_audit;
results.group_audit = group_audit;
results.state_bin_audit = state_bin_audit;
results.budget_curves = budget_curves;
results.reported = reported;
results.oracle_gap = oracle_gap;
results.decision_summary = decision_summary;
results.runtime_summary = runtime_summary;
results.models = models;
results.feature_names = feature_name_cell;

save(fullfile(out_dir,'exp09c3b1_2_results.mat'), ...
    'results','-v7.3');

fprintf('\nSaved EXP009-C3-B1.2 outputs to:\n%s\n\n',out_dir);

end

%% ========================================================================
function T = build_trajectory(regime,cfg)

L = cfg.num_lines;

line_index = (1:L).';
x = linspace(0,1,L).';

weak_ratio = ...
    cfg.weak_ratio_center + ...
    cfg.weak_ratio_sin1*sin(2*pi*x - 0.30) + ...
    cfg.weak_ratio_sin2*sin(4*pi*x + 0.70);

signed_sep = ...
    cfg.sep_center + ...
    cfg.sep_sin1*sin(2*pi*x + 0.80) + ...
    cfg.sep_sin2*sin(6*pi*x - 0.40);

is_jump_start = false(L,1);

if string(regime)=="Abrupt"
    jump_line = max(2,min(L,round(cfg.jump_fraction*L)));

    idx = line_index>=jump_line;

    weak_ratio(idx) = ...
        weak_ratio(idx) + cfg.jump_weak_ratio_step;

    signed_sep(idx) = ...
        signed_sep(idx) + cfg.jump_sep_step;

    is_jump_start(jump_line) = true;
end

weak_ratio = min(max( ...
    weak_ratio,cfg.weak_ratio_min), ...
    cfg.weak_ratio_max);

signed_sep = min(max( ...
    signed_sep,cfg.sep_min), ...
    cfg.sep_max);

q_strong = cfg.q_weak + signed_sep;

snr_db = cfg.snr_db*ones(L,1);

T = table( ...
    line_index,x,weak_ratio,signed_sep, ...
    q_strong,snr_db,is_jump_start);

end

%% ========================================================================
function det = precompute_deterministic_chain(traj,t,cfg)

L = height(traj);
N = cfg.N;

Sstrong = complex(zeros(L,N));
Sweak = complex(zeros(L,N));
Estrong = complex(zeros(L,N));

for k = 1:L
    qs = traj.q_strong(k);
    rA = traj.weak_ratio(k);

    ss = synth_lfm( ...
        cfg.A_strong,qs, ...
        cfg.f_strong,cfg.phi_strong,t,cfg);

    sw = synth_lfm( ...
        cfg.A_strong*rA,cfg.q_weak, ...
        cfg.f_weak,cfg.phi_weak,t,cfg);

    k0 = get_strong_notch_bin( ...
        ss,qs,t,cfg);

    es = apply_fixed_notch_operator( ...
        ss,qs,k0, ...
        cfg.notch_halfwidth_bins,t,cfg);

    Sstrong(k,:) = ss(:).';
    Sweak(k,:) = sw(:).';
    Estrong(k,:) = es(:).';
end

det = struct();
det.Sstrong = Sstrong;
det.Sweak = Sweak;
det.Estrong = Estrong;

end

%% ========================================================================
function Tbank = run_rich_signal_mc_bank( ...
    det,traj,num_mc,seed,D_search,q_search,t,cfg)

rng(seed,'twister');

L = height(traj);
N = cfg.N;
nRows = L*num_mc;

% Core identifiers / physical state
sequence_id = zeros(nRows,1);
line_index = zeros(nRows,1);

weak_ratio = nan(nRows,1);
signed_sep = nan(nRows,1);
q_strong = nan(nRows,1);
snr_db = nan(nRows,1);

% Outcomes
cheap_q_hat = nan(nRows,1);
fallback_q_hat = nan(nRows,1);

cheap_success = false(nRows,1);
fallback_success = false(nRows,1);

beneficial = false(nRows,1);
harmful = false(nRows,1);

signed_value = nan(nRows,1);

allocation_tiebreak = rand(nRows,1);

% Baseline PE
cheap_prominence = nan(nRows,1);
cheap_entropy = nan(nRows,1);

% q-curve morphology
peak_second_ratio = nan(nRows,1);
peak_margin_norm = nan(nRows,1);
top2_q_separation = nan(nRows,1);
width50_q = nan(nRows,1);
local_curvature_norm = nan(nRows,1);
local_asymmetry = nan(nRows,1);
peak_robust_z = nan(nRows,1);

% Strong competition / geometry
strong_q_response_ratio = nan(nRows,1);
strong_q_neighborhood_fraction = nan(nRows,1);
peak_to_strong_q_distance = nan(nRows,1);

% q_strong-dechirped Cheap residual spectrum
strong_spec_peak_fraction = nan(nRows,1);
strong_spec_local_fraction = nan(nRows,1);
strong_spec_entropy = nan(nRows,1);

% Sub-aperture stability
subap_q_std_norm = nan(nRows,1);
subap_q_range_norm = nan(nRows,1);
subap_consensus_fraction = nan(nRows,1);
subap_prominence_cv = nan(nRows,1);

% Strong-referenced SNR convention identical to C3-B1
s_ref = synth_lfm( ...
    cfg.A_strong,cfg.q_weak-0.05, ...
    cfg.f_strong,cfg.phi_strong,t,cfg);

Pstrong = mean(abs(s_ref).^2);
noise_var = Pstrong/(10^(cfg.snr_db/10));

row0 = 0;

for imc = 1:num_mc

    noise = sqrt(noise_var/2) * ...
        (randn(L,N)+1j*randn(L,N));

    Xcheap = det.Sweak + det.Estrong + noise;
    Xmix = det.Sstrong + det.Sweak + noise;

    % Rich full-aperture q-search features
    F = search_q_rich_features_batch( ...
        Xcheap,q_search,D_search, ...
        traj.q_strong, ...
        cfg.q_search_block_lines,cfg);

    % q_strong-referenced residual-spectrum diagnostics
    Sdiag = strong_residual_spectrum_features_batch( ...
        Xcheap,traj.q_strong,t,cfg);

    % Sub-aperture consistency
    Sub = subaperture_stability_features_batch( ...
        Xcheap,q_search,t,F.q_hat,cfg);

    % Fallback branch: identical C3-B1 parametric refit
    Xrefit = refit_strong_batch( ...
        Xmix,traj.q_strong,t,cfg);

    [qhat_fb,~,~] = search_q_basic_batch( ...
        Xrefit,q_search,D_search, ...
        cfg.q_search_block_lines);

    sc = abs(F.q_hat-cfg.q_weak) <= ...
        (cfg.tau_q+cfg.success_tol);

    sf = abs(qhat_fb-cfg.q_weak) <= ...
        (cfg.tau_q+cfg.success_tol);

    idx = row0 + (1:L);

    sequence_id(idx) = imc;
    line_index(idx) = traj.line_index;

    weak_ratio(idx) = traj.weak_ratio;
    signed_sep(idx) = traj.signed_sep;
    q_strong(idx) = traj.q_strong;
    snr_db(idx) = traj.snr_db;

    cheap_q_hat(idx) = F.q_hat;
    fallback_q_hat(idx) = qhat_fb;

    cheap_success(idx) = sc;
    fallback_success(idx) = sf;

    beneficial(idx) = (~sc) & sf;
    harmful(idx) = sc & (~sf);

    signed_value(idx) = double(sf)-double(sc);

    cheap_prominence(idx) = F.prominence;
    cheap_entropy(idx) = F.curve_entropy;

    peak_second_ratio(idx) = F.peak_second_ratio;
    peak_margin_norm(idx) = F.peak_margin_norm;
    top2_q_separation(idx) = F.top2_q_separation;
    width50_q(idx) = F.width50_q;
    local_curvature_norm(idx) = F.local_curvature_norm;
    local_asymmetry(idx) = F.local_asymmetry;
    peak_robust_z(idx) = F.peak_robust_z;

    strong_q_response_ratio(idx) = F.strong_q_response_ratio;
    strong_q_neighborhood_fraction(idx) = ...
        F.strong_q_neighborhood_fraction;
    peak_to_strong_q_distance(idx) = ...
        F.peak_to_strong_q_distance;

    strong_spec_peak_fraction(idx) = ...
        Sdiag.strong_spec_peak_fraction;
    strong_spec_local_fraction(idx) = ...
        Sdiag.strong_spec_local_fraction;
    strong_spec_entropy(idx) = ...
        Sdiag.strong_spec_entropy;

    subap_q_std_norm(idx) = Sub.subap_q_std_norm;
    subap_q_range_norm(idx) = Sub.subap_q_range_norm;
    subap_consensus_fraction(idx) = ...
        Sub.subap_consensus_fraction;
    subap_prominence_cv(idx) = ...
        Sub.subap_prominence_cv;

    row0 = row0 + L;
end

Tbank = table( ...
    sequence_id,line_index, ...
    weak_ratio,signed_sep,q_strong,snr_db, ...
    cheap_q_hat,fallback_q_hat, ...
    cheap_success,fallback_success, ...
    beneficial,harmful,signed_value, ...
    cheap_prominence,cheap_entropy, ...
    peak_second_ratio,peak_margin_norm, ...
    top2_q_separation,width50_q, ...
    local_curvature_norm,local_asymmetry,peak_robust_z, ...
    strong_q_response_ratio, ...
    strong_q_neighborhood_fraction, ...
    peak_to_strong_q_distance, ...
    strong_spec_peak_fraction, ...
    strong_spec_local_fraction, ...
    strong_spec_entropy, ...
    subap_q_std_norm, ...
    subap_q_range_norm, ...
    subap_consensus_fraction, ...
    subap_prominence_cv, ...
    allocation_tiebreak);

end

%% ========================================================================
function D = build_dechirp_dictionary(q_grid,t,cfg)

q_grid = q_grid(:);
t = t(:).';

mu = cfg.mu_scale*(q_grid-cfg.q_ref);

D = exp(-1j*pi*bsxfun(@times,mu,t.^2));

end

%% ========================================================================
function s = synth_lfm(A,q,f0,phi0,t,cfg)

t = t(:).';

mu = cfg.mu_scale*(q-cfg.q_ref);

s = A.*exp(1j*( ...
    pi*mu*t.^2 + ...
    2*pi*f0*t + ...
    phi0));

s = s(:).';

end

%% ========================================================================
function k0 = get_strong_notch_bin( ...
    s_strong,q_strong,t,cfg)

t = t(:).';
s_strong = s_strong(:).';

mu = cfg.mu_scale*(q_strong-cfg.q_ref);
dechirp = exp(-1j*pi*mu*t.^2);

Z = fft(s_strong.*dechirp);

[~,k0] = max(abs(Z).^2);

if ~isscalar(k0)
    error('get_strong_notch_bin must return a scalar.');
end

end

%% ========================================================================
function r = apply_fixed_notch_operator( ...
    x,q_used,k_fixed,halfwidth_bins,t,cfg)

x = x(:).';
t = t(:).';

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
r = r(:).';

end

%% ========================================================================
function F = search_q_rich_features_batch( ...
    X,q_grid,D,q_strong,block_lines,cfg)

X = double_complex_guard(X,'X');

[L,N] = size(X);
[Q,ND] = size(D);

if ND~=N
    error('D/X sample dimension mismatch.');
end

q_grid = q_grid(:);
q_strong = q_strong(:);

if numel(q_grid)~=Q
    error('q_grid length mismatch.');
end

if numel(q_strong)~=L
    error('q_strong must have one value per signal row.');
end

% Outputs
q_hat = nan(L,1);
prominence = nan(L,1);
curve_entropy = nan(L,1);

peak_second_ratio = nan(L,1);
peak_margin_norm = nan(L,1);
top2_q_separation = nan(L,1);
width50_q = nan(L,1);
local_curvature_norm = nan(L,1);
local_asymmetry = nan(L,1);
peak_robust_z = nan(L,1);

strong_q_response_ratio = nan(L,1);
strong_q_neighborhood_fraction = nan(L,1);
peak_to_strong_q_distance = nan(L,1);

D3 = reshape(D,[Q,N,1]);

for i1 = 1:block_lines:L

    i2 = min(L,i1+block_lines-1);
    idx = i1:i2;

    B = numel(idx);

    Xb = X(idx,:);

    X3 = reshape(Xb.',[1,N,B]);

    Y = fft(bsxfun(@times,D3,X3),[],2);

    M3 = max(abs(Y).^2,[],2);
    M = reshape(M3,[Q,B]);

    for ib = 1:B

        row = idx(ib);
        m = double(M(:,ib));

        [peak1,iPeak] = max(m);

        q_hat(row) = q_grid(iPeak);

        medm = median(m);

        prominence(row) = ...
            (peak1-medm)/max(peak1,eps);

        pcurve = m/max(sum(m),eps);
        pcurve = max(pcurve,realmin);

        curve_entropy(row) = ...
            -sum(pcurve.*log(pcurve))/log(Q);

        % Robust peak z-score
        mad0 = median(abs(m-medm));

        peak_robust_z(row) = ...
            (peak1-medm)/max(1.4826*mad0,eps);

        % Competing second peak excluding the main lobe neighborhood
        keep = true(Q,1);

        k1 = max(1,iPeak-cfg.second_peak_exclusion_bins);
        k2 = min(Q,iPeak+cfg.second_peak_exclusion_bins);

        keep(k1:k2) = false;

        if any(keep)
            tmp = m;
            tmp(~keep) = -Inf;

            [peak2,iSecond] = max(tmp);

            if isfinite(peak2)
                peak_second_ratio(row) = ...
                    peak2/max(peak1,eps);

                peak_margin_norm(row) = ...
                    (peak1-peak2)/max(peak1,eps);

                top2_q_separation(row) = ...
                    abs(q_grid(iPeak)-q_grid(iSecond));
            end
        end

        % Contiguous half-maximum width around the dominant peak
        thr = 0.5*peak1;

        il = iPeak;
        while il>1 && m(il-1)>=thr
            il = il-1;
        end

        ir = iPeak;
        while ir<Q && m(ir+1)>=thr
            ir = ir+1;
        end

        width50_q(row) = ...
            (ir-il)*cfg.q_search_step;

        % Local normalized curvature
        if iPeak>1 && iPeak<Q
            local_curvature_norm(row) = ...
                max(0, ...
                (2*m(iPeak)-m(iPeak-1)-m(iPeak+1)) / ...
                max(m(iPeak),eps));
        else
            local_curvature_norm(row) = 0;
        end

        % Local left/right energy asymmetry
        hw = cfg.curve_local_halfwidth_bins;

        lidx = max(1,iPeak-hw):(iPeak-1);
        ridx = (iPeak+1):min(Q,iPeak+hw);

        El = sum(m(lidx));
        Er = sum(m(ridx));

        local_asymmetry(row) = ...
            abs(El-Er)/max(El+Er,eps);

        % q_strong-referenced competition in the q-search curve
        [~,iqs] = min(abs(q_grid-q_strong(row)));

        strong_q_response_ratio(row) = ...
            m(iqs)/max(peak1,eps);

        ks1 = max(1,iqs-cfg.strong_q_neighborhood_bins);
        ks2 = min(Q,iqs+cfg.strong_q_neighborhood_bins);

        strong_q_neighborhood_fraction(row) = ...
            sum(m(ks1:ks2))/max(sum(m),eps);

        peak_to_strong_q_distance(row) = ...
            abs(q_grid(iPeak)-q_strong(row));
    end
end

F = struct();

F.q_hat = q_hat;
F.prominence = prominence;
F.curve_entropy = curve_entropy;

F.peak_second_ratio = peak_second_ratio;
F.peak_margin_norm = peak_margin_norm;
F.top2_q_separation = top2_q_separation;
F.width50_q = width50_q;
F.local_curvature_norm = local_curvature_norm;
F.local_asymmetry = local_asymmetry;
F.peak_robust_z = peak_robust_z;

F.strong_q_response_ratio = strong_q_response_ratio;
F.strong_q_neighborhood_fraction = ...
    strong_q_neighborhood_fraction;
F.peak_to_strong_q_distance = ...
    peak_to_strong_q_distance;

end

%% ========================================================================
function [q_hat,prominence,curve_entropy] = ...
    search_q_basic_batch(X,q_grid,D,block_lines)

X = double_complex_guard(X,'X');

[L,N] = size(X);
[Q,ND] = size(D);

if ND~=N
    error('search_q_basic_batch dimension mismatch.');
end

q_grid = q_grid(:);

q_hat = nan(L,1);
prominence = nan(L,1);
curve_entropy = nan(L,1);

D3 = reshape(D,[Q,N,1]);

for i1 = 1:block_lines:L

    i2 = min(L,i1+block_lines-1);
    idx = i1:i2;
    B = numel(idx);

    Xb = X(idx,:);
    X3 = reshape(Xb.',[1,N,B]);

    Y = fft(bsxfun(@times,D3,X3),[],2);

    M3 = max(abs(Y).^2,[],2);
    M = reshape(M3,[Q,B]);

    [peak,ii] = max(M,[],1);

    qhat_block = q_grid(ii(:));
    q_hat(idx) = qhat_block(:);

    floor_med = median(M,1);

    prominence(idx) = ...
        ((peak-floor_med)./max(peak,eps)).';

    denom = max(sum(M,1),eps);
    PP = bsxfun(@rdivide,M,denom);
    PP = max(PP,realmin);

    ent = -sum(PP.*log(PP),1)/log(Q);

    curve_entropy(idx) = ent.';
end

end

%% ========================================================================
function S = strong_residual_spectrum_features_batch( ...
    X,q_strong,t,cfg)

X = double_complex_guard(X,'X');

[L,N] = size(X);

q_strong = q_strong(:);
t = t(:).';

if numel(q_strong)~=L
    error('q_strong length mismatch in spectrum features.');
end

mu = cfg.mu_scale*(q_strong-cfg.q_ref);

D = exp(-1j*pi*bsxfun(@times,mu,t.^2));

nfft = cfg.strong_spectrum_nfft_factor*N;

Z = fft(X.*D,nfft,2);
P = abs(Z).^2;

total = max(sum(P,2),eps);

[peak,ipeak] = max(P,[],2);

strong_spec_peak_fraction = peak./total;

% Local energy around the strongest residual spectral mode.
local_fraction = nan(L,1);

for i = 1:L
    k0 = ipeak(i);

    idx = wrapped_bin_neighborhood( ...
        k0,cfg.strong_spectral_local_halfwidth_bins,nfft);

    local_fraction(i) = ...
        sum(P(i,idx))/total(i);
end

% Normalized spectral entropy
PP = bsxfun(@rdivide,P,total);
PP = max(PP,realmin);

strong_spec_entropy = ...
    -sum(PP.*log(PP),2)/log(nfft);

S = struct();
S.strong_spec_peak_fraction = ...
    strong_spec_peak_fraction(:);
S.strong_spec_local_fraction = ...
    local_fraction(:);
S.strong_spec_entropy = ...
    strong_spec_entropy(:);

end

%% ========================================================================
function idx = wrapped_bin_neighborhood(k0,halfwidth,N)

offs = -halfwidth:halfwidth;

idx = mod((k0-1)+offs,N)+1;
idx = unique(idx,'stable');

end

%% ========================================================================
function Sub = subaperture_stability_features_batch( ...
    X,q_grid,t,q_hat_full,cfg)

X = double_complex_guard(X,'X');

[L,N] = size(X);

S = cfg.num_subapertures;

if mod(N,S)~=0
    error('N must be divisible by num_subapertures.');
end

q_grid = q_grid(:);
q_hat_full = q_hat_full(:);
t = t(:).';

if numel(q_hat_full)~=L
    error('q_hat_full length mismatch.');
end

segN = N/S;

q_sub = nan(L,S);
prom_sub = nan(L,S);

for is = 1:S
    ii = (is-1)*segN + (1:segN);

    tsub = t(ii);
    Xsub = X(:,ii);

    Dsub = build_dechirp_dictionary( ...
        q_grid,tsub,cfg);

    [qh,prom,~] = search_q_basic_batch( ...
        Xsub,q_grid,Dsub, ...
        cfg.q_search_block_lines);

    q_sub(:,is) = qh;
    prom_sub(:,is) = prom;
end

q_std = std(q_sub,0,2);

q_range = max(q_sub,[],2)-min(q_sub,[],2);

consensus = mean( ...
    abs(bsxfun(@minus,q_sub,q_hat_full)) <= ...
    (cfg.tau_q+cfg.success_tol),2);

prom_mean = mean(prom_sub,2);
prom_std = std(prom_sub,0,2);

prom_cv = prom_std./max(abs(prom_mean),eps);

Sub = struct();

Sub.subap_q_std_norm = ...
    q_std/max(cfg.tau_q,eps);

Sub.subap_q_range_norm = ...
    q_range/max(cfg.tau_q,eps);

Sub.subap_consensus_fraction = ...
    consensus(:);

Sub.subap_prominence_cv = ...
    prom_cv(:);

end

%% ========================================================================
function R = refit_strong_batch(X,q_strong,t,cfg)

X = double_complex_guard(X,'X');

[L,N] = size(X);

t = t(:).';
q_strong = q_strong(:);

if numel(q_strong)~=L
    error('refit_strong_batch requires one q_strong per row.');
end

mu = cfg.mu_scale*(q_strong-cfg.q_ref);

dechirp_phase = ...
    -1j*pi*bsxfun(@times,mu,t.^2);

D = exp(dechirp_phase);

Z = fft( ...
    X.*D, ...
    cfg.refit_nfft_factor*N,2);

P = abs(Z).^2;

[~,k0] = max(P,[],2);

nfft = size(Z,2);

lin0 = sub2ind([L,nfft],(1:L).',k0);

km = mod(k0-2,nfft)+1;
kp = mod(k0,nfft)+1;

linm = sub2ind([L,nfft],(1:L).',km);
linp = sub2ind([L,nfft],(1:L).',kp);

ym = P(linm);
y0 = P(lin0);
yp = P(linp);

den = ym - 2*y0 + yp;

delta = zeros(L,1);

valid = abs(den)>eps;

delta(valid) = ...
    0.5*(ym(valid)-yp(valid))./den(valid);

delta = min(max(delta,-1),1);

bin0 = k0-1;

wrap = bin0>nfft/2;
bin0(wrap) = bin0(wrap)-nfft;

fhat = (bin0+delta)*(N/nfft);
fhat = fhat(:);

phase_q = bsxfun(@times,pi*mu,t.^2);
phase_f = bsxfun(@times,2*pi*fhat,t);

atom = exp(1j*(phase_q+phase_f));

den_a = max(sum(abs(atom).^2,2),eps);

alpha = ...
    sum(conj(atom).*X,2)./den_a;

R = X - bsxfun(@times,alpha,atom);

if ~isequal(size(R),size(X))
    error('refit_strong_batch changed dimensions unexpectedly.');
end

end

%% ========================================================================
function X = double_complex_guard(X,label)

if ~ismatrix(X)
    error('%s must be a 2-D matrix.',label);
end

X = double(X);

if isempty(X)
    error('%s is empty.',label);
end

end

%% ========================================================================
function continuity = verify_against_c3b1_if_available( ...
    train_smooth,train_abrupt, ...
    test_smooth,test_abrupt, ...
    old_dir,cfg)

names = { ...
    'TrainSmooth',train_smooth,'train_trials_smooth.csv'; ...
    'TrainAbrupt',train_abrupt,'train_trials_abrupt.csv'; ...
    'TestSmooth',test_smooth,'test_trials_smooth.csv'; ...
    'TestAbrupt',test_abrupt,'test_trials_abrupt.csv'};

bank = strings(size(names,1),1);
reference_available = false(size(names,1),1);
cheap_success_mismatch_rate = nan(size(names,1),1);
fallback_success_mismatch_rate = nan(size(names,1),1);
beneficial_mismatch_rate = nan(size(names,1),1);
harmful_mismatch_rate = nan(size(names,1),1);

for i = 1:size(names,1)
    bank(i) = string(names{i,1});
    Tnew = names{i,2};
    file = fullfile(old_dir,names{i,3});

    if cfg.verify_against_c3b1 && exist(file,'file')
        Told = readtable(file);

        required = { ...
            'sequence_id','line_index', ...
            'cheap_success','fallback_success', ...
            'beneficial','harmful'};

        assert_table_vars(Told,required,file);

        if height(Told)~=height(Tnew)
            warning('C3-B1 continuity check skipped for %s: height differs.', ...
                bank(i));
            continue;
        end

        same_id = ...
            all(Told.sequence_id==Tnew.sequence_id) && ...
            all(Told.line_index==Tnew.line_index);

        if ~same_id
            warning('C3-B1 continuity check skipped for %s: row IDs differ.', ...
                bank(i));
            continue;
        end

        reference_available(i) = true;

        cheap_success_mismatch_rate(i) = mean( ...
            logical(Told.cheap_success) ~= ...
            logical(Tnew.cheap_success));

        fallback_success_mismatch_rate(i) = mean( ...
            logical(Told.fallback_success) ~= ...
            logical(Tnew.fallback_success));

        beneficial_mismatch_rate(i) = mean( ...
            logical(Told.beneficial) ~= ...
            logical(Tnew.beneficial));

        harmful_mismatch_rate(i) = mean( ...
            logical(Told.harmful) ~= ...
            logical(Tnew.harmful));
    end
end

continuity = table( ...
    bank,reference_available, ...
    cheap_success_mismatch_rate, ...
    fallback_success_mismatch_rate, ...
    beneficial_mismatch_rate, ...
    harmful_mismatch_rate);

if any(reference_available)
    max_mismatch = max([ ...
        cheap_success_mismatch_rate(reference_available); ...
        fallback_success_mismatch_rate(reference_available); ...
        beneficial_mismatch_rate(reference_available); ...
        harmful_mismatch_rate(reference_available)]);

    if max_mismatch>0
        warning(['C3-B1.2 regenerated labels are not exactly identical ' ...
            'to saved C3-B1 labels. Maximum mismatch rate = %.6g.'], ...
            max_mismatch);
    end
end

end

%% ========================================================================
function [Ttrain,Ttest,S] = attach_crossfit_state_prior( ...
    Ttrain,Ttest,cfg)

lines = unique(Ttrain.line_index).';
seqs = unique(Ttrain.sequence_id).';

L = numel(lines);
M = numel(seqs);

if M<2
    error('Cross-fitted state prior requires >= 2 TRAIN sequences.');
end

Y = nan(M,L);

for is = 1:M
    sid = seqs(is);

    for ik = 1:L
        k = lines(ik);

        idx = find( ...
            Ttrain.sequence_id==sid & ...
            Ttrain.line_index==k);

        if numel(idx)~=1
            error(['Expected one TRAIN row for sequence %g line %g; ' ...
                'found %d.'],sid,k,numel(idx));
        end

        Y(is,ik) = double(Ttrain.signed_value(idx));
    end
end

train_raw = mean(Y,1).';

train_full = moving_average_shrink( ...
    train_raw,cfg.state_utility_smooth_window);

test_raw = nan(L,1);

for ik = 1:L
    k = lines(ik);
    mm = Ttest.line_index==k;

    test_raw(ik) = mean( ...
        double(Ttest.signed_value(mm)),'omitnan');
end

test_utility = moving_average_shrink( ...
    test_raw,cfg.state_utility_smooth_window);

Ttrain.state_prior = nan(height(Ttrain),1);

sumY = sum(Y,1);

for is = 1:M
    sid = seqs(is);

    cf_raw = ((sumY-Y(is,:))/(M-1)).';

    cf_smooth = moving_average_shrink( ...
        cf_raw,cfg.state_utility_smooth_window);

    for ik = 1:L
        k = lines(ik);

        idx = find( ...
            Ttrain.sequence_id==sid & ...
            Ttrain.line_index==k);

        Ttrain.state_prior(idx) = cf_smooth(ik);
    end
end

Ttest.state_prior = nan(height(Ttest),1);

for ik = 1:L
    k = lines(ik);
    mm = Ttest.line_index==k;

    Ttest.state_prior(mm) = train_full(ik);
end

line_index = lines(:);

weak_ratio = nan(L,1);
signed_sep = nan(L,1);

for ik = 1:L
    k = lines(ik);
    mm = Ttrain.line_index==k;

    weak_ratio(ik) = scalar_unique( ...
        Ttrain.weak_ratio(mm), ...
        sprintf('weak ratio line %d',k));

    signed_sep(ik) = scalar_unique( ...
        Ttrain.signed_sep(mm), ...
        sprintf('signed separation line %d',k));
end

train_state_prior_full = train_full;
test_state_utility = test_utility;

S = table( ...
    line_index,weak_ratio,signed_sep, ...
    train_raw,train_state_prior_full, ...
    test_raw,test_state_utility, ...
    'VariableNames',{ ...
    'line_index','weak_ratio','signed_sep', ...
    'train_utility_raw','train_state_prior_full', ...
    'test_utility_raw','test_state_utility'});

end

%% ========================================================================
function y = moving_average_shrink(x,w)

x = double(x(:));
w = max(1,round(w));

N = numel(x);
y = nan(N,1);

left = floor((w-1)/2);
right = w-1-left;

for i = 1:N
    i1 = max(1,i-left);
    i2 = min(N,i+right);

    y(i) = mean(x(i1:i2),'omitnan');
end

end

%% ========================================================================
function names = realization_feature_list()

names = { ...
    'cheap_prominence', ...
    'cheap_entropy', ...
    'peak_second_ratio', ...
    'peak_margin_norm', ...
    'top2_q_separation', ...
    'width50_q', ...
    'local_curvature_norm', ...
    'local_asymmetry', ...
    'peak_robust_z', ...
    'strong_q_response_ratio', ...
    'strong_q_neighborhood_fraction', ...
    'peak_to_strong_q_distance', ...
    'strong_spec_peak_fraction', ...
    'strong_spec_local_fraction', ...
    'strong_spec_entropy', ...
    'subap_q_std_norm', ...
    'subap_q_range_norm', ...
    'subap_consensus_fraction', ...
    'subap_prominence_cv'};

end

%% ========================================================================
function [X,names] = build_group_features(T,group)

baseline = { ...
    'cheap_prominence', ...
    'cheap_entropy'};

morph = { ...
    'cheap_prominence', ...
    'cheap_entropy', ...
    'peak_second_ratio', ...
    'peak_margin_norm', ...
    'top2_q_separation', ...
    'width50_q', ...
    'local_curvature_norm', ...
    'local_asymmetry', ...
    'peak_robust_z'};

strong = { ...
    'cheap_prominence', ...
    'cheap_entropy', ...
    'strong_q_response_ratio', ...
    'strong_q_neighborhood_fraction', ...
    'peak_to_strong_q_distance', ...
    'strong_spec_peak_fraction', ...
    'strong_spec_local_fraction', ...
    'strong_spec_entropy'};

subap = { ...
    'cheap_prominence', ...
    'cheap_entropy', ...
    'subap_q_std_norm', ...
    'subap_q_range_norm', ...
    'subap_consensus_fraction', ...
    'subap_prominence_cv'};

allobs = realization_feature_list();

switch string(group)

    case "StateOnly"
        names = {'state_prior'};

    case "BaselinePE"
        names = baseline;

    case "StateBaseline"
        names = [{'state_prior'},baseline];

    case "MorphologyOnly"
        names = morph;

    case "StateMorphology"
        names = [{'state_prior'},morph];

    case "StrongCompetitionOnly"
        names = strong;

    case "StateStrongCompetition"
        names = [{'state_prior'},strong];

    case "SubapertureOnly"
        names = subap;

    case "StateSubaperture"
        names = [{'state_prior'},subap];

    case "AllObservable"
        names = allobs;

    case "StateAll"
        names = [{'state_prior'},allobs];

    otherwise
        error('Unknown feature group: %s',string(group));
end

X = table_columns_to_matrix(T,names);

end

%% ========================================================================
function X = table_columns_to_matrix(T,names)

N = height(T);
P = numel(names);

X = nan(N,P);

for j = 1:P
    name = names{j};

    if ~ismember(name,T.Properties.VariableNames)
        error('Missing feature "%s".',name);
    end

    v = double(T.(name));
    v = v(:);

    if numel(v)~=N
        error('Feature "%s" length mismatch.',name);
    end

    X(:,j) = v;
end

% Do not impute here. The predictive model learns imputation values from
% TRAIN only and applies the same values to TEST, avoiding test-distribution
% leakage.

end

%% ========================================================================
function A = audit_single_features( ...
    train_smooth,train_abrupt, ...
    test_smooth,test_abrupt,feature_list)

rows = {};

for ir = 1:2
    if ir==1
        Ttr = train_smooth;
        Tte = test_smooth;
        regime = "Smooth";
    else
        Ttr = train_abrupt;
        Tte = test_abrupt;
        regime = "Abrupt";
    end

    for jf = 1:numel(feature_list)
        fname = feature_list{jf};

        xtr = double(Ttr.(fname));
        xte = double(Tte.(fname));

        % Beneficial direction learned from TRAIN only.
        auc_train_B = binary_auc(Ttr.beneficial,xtr);

        if isnan(auc_train_B) || auc_train_B>=0.5
            dirB = 1;
        else
            dirB = -1;
        end

        pooled_B = binary_auc( ...
            Tte.beneficial,dirB*xte);

        [within_B,nLineB] = ...
            weighted_within_line_auc( ...
            Tte,dirB*xte,Tte.beneficial);

        % Harmful direction learned from TRAIN only.
        auc_train_H = binary_auc(Ttr.harmful,xtr);

        if isnan(auc_train_H) || auc_train_H>=0.5
            dirH = 1;
        else
            dirH = -1;
        end

        pooled_H = binary_auc( ...
            Tte.harmful,dirH*xte);

        [within_H,nLineH] = ...
            weighted_within_line_auc( ...
            Tte,dirH*xte,Tte.harmful);

        rows(end+1,:) = { ... %#ok<AGROW>
            char(regime),fname, ...
            auc_train_B,dirB,pooled_B,within_B,nLineB, ...
            auc_train_H,dirH,pooled_H,within_H,nLineH};
    end
end

A = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','feature', ...
    'train_auc_beneficial','beneficial_direction', ...
    'test_auc_beneficial','within_line_auc_beneficial', ...
    'valid_lines_beneficial', ...
    'train_auc_harmful','harmful_direction', ...
    'test_auc_harmful','within_line_auc_harmful', ...
    'valid_lines_harmful'});

end

%% ========================================================================
function A = audit_group_models( ...
    test_smooth,test_abrupt, ...
    group_names,smooth_pred,abrupt_pred)

rows = {};

for ir = 1:2
    if ir==1
        T = test_smooth;
        Pred = smooth_pred;
        regime = "Smooth";
    else
        T = test_abrupt;
        Pred = abrupt_pred;
        regime = "Abrupt";
    end

    for ig = 1:numel(group_names)
        key = char(group_names(ig));
        P = Pred.(key);

        aucB = binary_auc(T.beneficial,P.pB);
        aucH = binary_auc(T.harmful,P.pH);

        [withinB,nLineB] = ...
            weighted_within_line_auc( ...
            T,P.pB,T.beneficial);

        [withinH,nLineH] = ...
            weighted_within_line_auc( ...
            T,P.pH,T.harmful);

        utility_rho = spearman_manual( ...
            P.value,T.signed_value);

        rows(end+1,:) = { ... %#ok<AGROW>
            char(regime),key, ...
            aucB,withinB,nLineB, ...
            aucH,withinH,nLineH, ...
            utility_rho};
    end
end

A = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','group', ...
    'beneficial_auc','within_line_beneficial_auc', ...
    'valid_lines_beneficial', ...
    'harmful_auc','within_line_harmful_auc', ...
    'valid_lines_harmful', ...
    'signed_utility_spearman'});

end

%% ========================================================================
function A = audit_state_bins( ...
    train_smooth,train_abrupt, ...
    test_smooth,test_abrupt, ...
    group_names,smooth_pred,abrupt_pred,cfg)

% Keep only groups that directly answer whether richer realization evidence
% helps within different physical-state regimes.
keep_groups = [ ...
    "BaselinePE", ...
    "MorphologyOnly", ...
    "StrongCompetitionOnly", ...
    "SubapertureOnly", ...
    "AllObservable", ...
    "StateAll"];

rows = {};

for ir = 1:2
    if ir==1
        Ttr = train_smooth;
        Tte = test_smooth;
        Pred = smooth_pred;
        regime = "Smooth";
    else
        Ttr = train_abrupt;
        Tte = test_abrupt;
        Pred = abrupt_pred;
        regime = "Abrupt";
    end

    edges = quantile_edges_unique( ...
        Ttr.state_prior,cfg.num_state_bins);

    bin_id = assign_bins(Tte.state_prior,edges);

    for ib = 1:(numel(edges)-1)
        mm = bin_id==ib;

        for ig = 1:numel(keep_groups)
            group = keep_groups(ig);

            if ~ismember(group,group_names)
                continue;
            end

            P = Pred.(char(group));

            aucB = binary_auc( ...
                Tte.beneficial(mm),P.pB(mm));

            aucH = binary_auc( ...
                Tte.harmful(mm),P.pH(mm));

            rows(end+1,:) = { ... %#ok<AGROW>
                char(regime),char(group),ib, ...
                edges(ib),edges(ib+1), ...
                sum(mm), ...
                mean(Tte.state_prior(mm),'omitnan'), ...
                aucB,aucH};
        end
    end
end

A = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','group','state_bin', ...
    'state_low','state_high','n_trials', ...
    'mean_state_prior', ...
    'beneficial_auc','harmful_auc'});

end

%% ========================================================================
function [aucW,nValid] = weighted_within_line_auc(T,score,label)

score = double(score(:));
label = logical(label(:));

lines = unique(T.line_index).';

auc_num = 0;
weight_sum = 0;
nValid = 0;

for ik = 1:numel(lines)
    mm = T.line_index==lines(ik);

    y = label(mm);
    s = score(mm);

    valid = isfinite(s);
    y = y(valid);
    s = s(valid);

    nPos = sum(y);
    nNeg = sum(~y);

    if nPos>0 && nNeg>0
        a = binary_auc(y,s);
        w = nPos*nNeg;

        auc_num = auc_num+w*a;
        weight_sum = weight_sum+w;
        nValid = nValid+1;
    end
end

if weight_sum<=0
    aucW = NaN;
else
    aucW = auc_num/weight_sum;
end

end

%% ========================================================================
function mdl = fit_two_head_value_model(X,yB,yH,cfg)

X = double(X);

yB = double(logical(yB(:)));
yH = double(logical(yH(:)));

if size(X,1)~=numel(yB) || numel(yB)~=numel(yH)
    error('Feature/label dimensions are inconsistent.');
end

% Robust finite imputation learned from TRAIN.
P = size(X,2);
impute = nan(1,P);

for j = 1:P
    v = X(:,j);
    finite = isfinite(v);

    if any(finite)
        impute(j) = median(v(finite));
    else
        impute(j) = 0;
    end

    v(~finite) = impute(j);
    X(:,j) = v;
end

mu = mean(X,1);
sigma = std(X,0,1);

sigma(~isfinite(sigma) | sigma<1e-12) = 1;

Xz = bsxfun(@rdivide, ...
    bsxfun(@minus,X,mu),sigma);

betaB = fit_ridge_logistic_irls( ...
    Xz,yB,cfg.ridge_lambda, ...
    cfg.irls_max_iter,cfg.irls_tol,cfg.prob_clip);

betaH = fit_ridge_logistic_irls( ...
    Xz,yH,cfg.ridge_lambda, ...
    cfg.irls_max_iter,cfg.irls_tol,cfg.prob_clip);

mdl = struct();
mdl.impute = impute;
mdl.mu = mu;
mdl.sigma = sigma;
mdl.betaB = betaB;
mdl.betaH = betaH;

end

%% ========================================================================
function beta = fit_ridge_logistic_irls( ...
    X,y,lambda,max_iter,tol,pclip)

[N,P] = size(X);

Xd = [ones(N,1),X];

beta = zeros(P+1,1);

penalty = lambda*eye(P+1);
penalty(1,1) = 0;

for it = 1:max_iter

    eta = Xd*beta;
    eta = min(max(eta,-30),30);

    p = 1./(1+exp(-eta));
    p = min(max(p,pclip),1-pclip);

    w = p.*(1-p);

    g = Xd.'*(p-y) + penalty*beta;

    Xw = bsxfun(@times,Xd,w);
    H = Xd.'*Xw + penalty;

    step = H\g;

    if any(~isfinite(step))
        error('Non-finite logistic Newton step.');
    end

    beta_new = beta-step;

    if norm(beta_new-beta) <= ...
            tol*(1+norm(beta))
        beta = beta_new;
        return;
    end

    beta = beta_new;
end

end

%% ========================================================================
function P = predict_two_head_value(mdl,X)

X = double(X);

if size(X,2)~=numel(mdl.mu)
    error('Prediction feature dimension mismatch.');
end

for j = 1:size(X,2)
    v = X(:,j);
    v(~isfinite(v)) = mdl.impute(j);
    X(:,j) = v;
end

Xz = bsxfun(@rdivide, ...
    bsxfun(@minus,X,mdl.mu),mdl.sigma);

Xd = [ones(size(Xz,1),1),Xz];

etaB = Xd*mdl.betaB;
etaH = Xd*mdl.betaH;

etaB = min(max(etaB,-30),30);
etaH = min(max(etaH,-30),30);

pB = 1./(1+exp(-etaB));
pH = 1./(1+exp(-etaH));

P = struct();
P.pB = pB(:);
P.pH = pH(:);
P.value = (pB-pH);
P.value = P.value(:);

end

%% ========================================================================
function C = evaluate_policy_curve( ...
    Ttrain,Ttest,score_train,score_test,budgets)

score_train = add_tiebreak(score_train,Ttrain);
score_test = add_tiebreak(score_test,Ttest);

budgets = double(budgets(:));

nB = numel(budgets);

target_budget = budgets;
actual_trigger_rate = nan(nB,1);
policy_recall = nan(nB,1);
beneficial_capture = nan(nB,1);
benefit_precision = nan(nB,1);
harmful_fraction_among_triggers = nan(nB,1);
normalized_q_search_budget = nan(nB,1);

cheap = logical(Ttest.cheap_success(:));
fallback = logical(Ttest.fallback_success(:));

beneficial = logical(Ttest.beneficial(:));
harmful = logical(Ttest.harmful(:));

nBeneficial = sum(beneficial);

for ib = 1:nB

    b = budgets(ib);

    if b<=0
        trigger = false(size(score_test));
    elseif b>=1
        trigger = true(size(score_test));
    else
        thr = empirical_quantile( ...
            score_train,1-b);

        trigger = score_test>=thr;
    end

    actual_trigger_rate(ib) = mean(trigger);

    out = cheap;
    out(trigger) = fallback(trigger);

    policy_recall(ib) = mean(out);

    if nBeneficial>0
        beneficial_capture(ib) = ...
            sum(trigger & beneficial)/nBeneficial;
    end

    nTrig = sum(trigger);

    if nTrig>0
        benefit_precision(ib) = ...
            sum(trigger & beneficial)/nTrig;

        harmful_fraction_among_triggers(ib) = ...
            sum(trigger & harmful)/nTrig;
    end

    normalized_q_search_budget(ib) = ...
        1+actual_trigger_rate(ib);
end

C = table( ...
    target_budget,actual_trigger_rate, ...
    policy_recall,beneficial_capture, ...
    benefit_precision,harmful_fraction_among_triggers, ...
    normalized_q_search_budget);

end

%% ========================================================================
function score = add_tiebreak(score,T)

score = double(score(:));

if numel(score)~=height(T)
    error('Score length does not match table height.');
end

if ismember('allocation_tiebreak',T.Properties.VariableNames)
    tb = double(T.allocation_tiebreak(:));

    score = score + 1e-9*(tb-0.5);
end

end

%% ========================================================================
function C = trial_oracle_curve(T,budgets)

budgets = double(budgets(:));

cheap_recall = mean(T.cheap_success);
benefit_rate = mean(T.beneficial);

nB = numel(budgets);

target_budget = budgets;
actual_trigger_rate = nan(nB,1);
policy_recall = nan(nB,1);
beneficial_capture = nan(nB,1);
benefit_precision = nan(nB,1);
harmful_fraction_among_triggers = zeros(nB,1);
normalized_q_search_budget = nan(nB,1);

for ib = 1:nB

    used = min(max(budgets(ib),0),benefit_rate);

    actual_trigger_rate(ib) = used;
    policy_recall(ib) = cheap_recall+used;

    if benefit_rate>0
        beneficial_capture(ib) = ...
            min(1,used/benefit_rate);
    end

    if used>0
        benefit_precision(ib) = 1;
    end

    normalized_q_search_budget(ib) = 1+used;
end

C = table( ...
    target_budget,actual_trigger_rate, ...
    policy_recall,beneficial_capture, ...
    benefit_precision,harmful_fraction_among_triggers, ...
    normalized_q_search_budget);

end

%% ========================================================================
function C = random_expected_curve(T,budgets)

budgets = double(budgets(:));

cheap_recall = mean(T.cheap_success);
benefit_rate = mean(T.beneficial);
harm_rate = mean(T.harmful);

target_budget = budgets;
actual_trigger_rate = budgets;

policy_recall = ...
    cheap_recall + ...
    budgets*(benefit_rate-harm_rate);

beneficial_capture = budgets;

benefit_precision = ...
    repmat(benefit_rate,numel(budgets),1);

harmful_fraction_among_triggers = ...
    repmat(harm_rate,numel(budgets),1);

benefit_precision(budgets==0) = NaN;
harmful_fraction_among_triggers(budgets==0) = NaN;

normalized_q_search_budget = 1+budgets;

C = table( ...
    target_budget,actual_trigger_rate, ...
    policy_recall,beneficial_capture, ...
    benefit_precision,harmful_fraction_among_triggers, ...
    normalized_q_search_budget);

end

%% ========================================================================
function R = extract_reported_budget_points(C,budgets)

budgets = double(budgets(:));

regimes = unique(C.regime,'stable');
policies = unique(C.policy,'stable');

rows = {};

for ir = 1:numel(regimes)
    for ip = 1:numel(policies)

        Cp = C( ...
            C.regime==regimes(ir) & ...
            C.policy==policies(ip),:);

        if isempty(Cp)
            continue;
        end

        for ib = 1:numel(budgets)

            b = budgets(ib);
            [~,ii] = min(abs(Cp.target_budget-b));

            rows(end+1,:) = { ... %#ok<AGROW>
                char(regimes(ir)), ...
                char(policies(ip)), ...
                b, ...
                Cp.actual_trigger_rate(ii), ...
                Cp.policy_recall(ii), ...
                Cp.beneficial_capture(ii), ...
                Cp.benefit_precision(ii), ...
                Cp.harmful_fraction_among_triggers(ii), ...
                Cp.normalized_q_search_budget(ii)};
        end
    end
end

R = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','policy','target_budget', ...
    'actual_trigger_rate','policy_recall', ...
    'beneficial_capture','benefit_precision', ...
    'harmful_fraction_among_triggers', ...
    'normalized_q_search_budget'});

end

%% ========================================================================
function G = compute_oracle_gap_capture( ...
    R,budgets,group_names)

budgets = double(budgets(:));
regimes = ["Smooth","Abrupt"];

rows = {};

for ir = 1:numel(regimes)
    regime = regimes(ir);

    for ib = 1:numel(budgets)
        b = budgets(ib);

        rr = get_reported_recall( ...
            R,regime,"RandomExpected",b);

        ro = get_reported_recall( ...
            R,regime,"TrialOracle",b);

        denom = ro-rr;

        for ig = 1:numel(group_names)
            policy = group_names(ig);

            rm = get_reported_recall( ...
                R,regime,policy,b);

            if abs(denom)<eps
                frac = NaN;
            else
                frac = (rm-rr)/denom;
            end

            rows(end+1,:) = { ... %#ok<AGROW>
                char(regime),char(policy),b, ...
                rr,rm,ro,frac};
        end
    end
end

G = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','policy','target_budget', ...
    'random_recall','model_recall','oracle_recall', ...
    'oracle_selection_advantage_fraction'});

end

%% ========================================================================
function r = get_reported_recall( ...
    R,regime,policy,budget)

mm = strcmp(R.regime,char(regime)) & ...
     strcmp(R.policy,char(policy)) & ...
     abs(R.target_budget-budget)<1e-12;

if sum(mm)~=1
    error('Could not uniquely locate recall for %s/%s.', ...
        regime,policy);
end

r = R.policy_recall(mm);

end

%% ========================================================================
function D = build_decision_summary( ...
    group_audit,reported,oracle_gap,cfg)

regimes = ["Smooth","Abrupt"];

rows = {};

for ir = 1:numel(regimes)
    regime = regimes(ir);

    baseline = get_group_metric( ...
        group_audit,regime,"BaselinePE");

    morph = get_group_metric( ...
        group_audit,regime,"MorphologyOnly");

    strong = get_group_metric( ...
        group_audit,regime,"StrongCompetitionOnly");

    subap = get_group_metric( ...
        group_audit,regime,"SubapertureOnly");

    allobs = get_group_metric( ...
        group_audit,regime,"AllObservable");

    state = get_group_metric( ...
        group_audit,regime,"StateOnly");

    stateall = get_group_metric( ...
        group_audit,regime,"StateAll");

    b = cfg.primary_budget;

    rState = get_reported_recall( ...
        reported,regime,"StateOnly",b);

    rBase = get_reported_recall( ...
        reported,regime,"BaselinePE",b);

    rAll = get_reported_recall( ...
        reported,regime,"AllObservable",b);

    rStateAll = get_reported_recall( ...
        reported,regime,"StateAll",b);

    fState = get_gap_fraction( ...
        oracle_gap,regime,"StateOnly",b);

    fBase = get_gap_fraction( ...
        oracle_gap,regime,"BaselinePE",b);

    fAll = get_gap_fraction( ...
        oracle_gap,regime,"AllObservable",b);

    fStateAll = get_gap_fraction( ...
        oracle_gap,regime,"StateAll",b);

    rows(end+1,:) = { ... %#ok<AGROW>
        char(regime), ...
        baseline.within_line_beneficial_auc, ...
        morph.within_line_beneficial_auc, ...
        strong.within_line_beneficial_auc, ...
        subap.within_line_beneficial_auc, ...
        allobs.within_line_beneficial_auc, ...
        baseline.within_line_harmful_auc, ...
        morph.within_line_harmful_auc, ...
        strong.within_line_harmful_auc, ...
        subap.within_line_harmful_auc, ...
        allobs.within_line_harmful_auc, ...
        state.beneficial_auc, ...
        stateall.beneficial_auc, ...
        stateall.beneficial_auc-state.beneficial_auc, ...
        rState,rBase,rAll,rStateAll, ...
        rStateAll-max([rState,rAll]), ...
        fState,fBase,fAll,fStateAll};
end

D = cell2table(rows, ...
    'VariableNames',{ ...
    'regime', ...
    'withinB_baseline','withinB_morphology', ...
    'withinB_strongCompetition','withinB_subaperture', ...
    'withinB_allObservable', ...
    'withinH_baseline','withinH_morphology', ...
    'withinH_strongCompetition','withinH_subaperture', ...
    'withinH_allObservable', ...
    'pooledB_stateOnly','pooledB_stateAll', ...
    'pooledB_stateAll_gain', ...
    'recall25_stateOnly','recall25_baseline', ...
    'recall25_allObservable','recall25_stateAll', ...
    'recall25_stateAll_gain_over_best_source', ...
    'oracleFrac_stateOnly','oracleFrac_baseline', ...
    'oracleFrac_allObservable','oracleFrac_stateAll'});

end

%% ========================================================================
function row = get_group_metric(A,regime,group)

mm = strcmp(A.regime,char(regime)) & ...
     strcmp(A.group,char(group));

if sum(mm)~=1
    error('Could not uniquely locate group metric %s/%s.', ...
        regime,group);
end

row = A(mm,:);

end

%% ========================================================================
function f = get_gap_fraction( ...
    G,regime,policy,budget)

mm = strcmp(G.regime,char(regime)) & ...
     strcmp(G.policy,char(policy)) & ...
     abs(G.target_budget-budget)<1e-12;

if sum(mm)~=1
    error('Could not uniquely locate oracle-gap fraction.');
end

f = G.oracle_selection_advantage_fraction(mm);

end

%% ========================================================================
function write_summary( ...
    out_dir,cfg,rho_s,rho_a, ...
    continuity,singleA,groupA, ...
    reported,oracle_gap,decision)

fid = fopen(fullfile(out_dir,'summary.txt'),'w');

fprintf(fid,'EXP009-C3-B1.2 Mechanism-Informed Realization Observable Audit\n');
fprintf(fid,'==============================================================\n\n');

fprintf(fid,'Research question\n');
fprintf(fid,'-----------------\n');
fprintf(fid,['Which practical signal-level observables carry genuine ' ...
    'within-state realization information for Beneficial and Harmful ' ...
    'fallback outcomes?\n\n']);

fprintf(fid,'Controlled boundary\n');
fprintf(fid,'-------------------\n');
fprintf(fid,['Signal trajectory, q-grid, SNR, Cheap chain, parametric ' ...
    'fallback, Monte-Carlo seeds and recovery threshold match C3-B1. ' ...
    'q_strong remains oracle/known.\n\n']);

fprintf(fid,'State reproducibility\n');
fprintf(fid,'---------------------\n');
fprintf(fid,'Smooth rho: %.6f\n',rho_s);
fprintf(fid,'Abrupt rho: %.6f\n\n',rho_a);

fprintf(fid,'C3-B1 continuity check\n');
fprintf(fid,'----------------------\n');

for i = 1:height(continuity)
    fprintf(fid,[ ...
        '%s available=%d cheapMismatch=%.6g fallbackMismatch=%.6g ' ...
        'beneficialMismatch=%.6g harmfulMismatch=%.6g\n'], ...
        char(continuity.bank(i)), ...
        continuity.reference_available(i), ...
        continuity.cheap_success_mismatch_rate(i), ...
        continuity.fallback_success_mismatch_rate(i), ...
        continuity.beneficial_mismatch_rate(i), ...
        continuity.harmful_mismatch_rate(i));
end

fprintf(fid,'\nBest single features by within-line Beneficial AUC\n');
fprintf(fid,'--------------------------------------------------\n');

for regime = ["Smooth","Abrupt"]
    T = singleA(strcmp(singleA.regime,char(regime)),:);

    [vals,ord] = sort( ...
        T.within_line_auc_beneficial,'descend');

    K = min(8,height(T));

    fprintf(fid,'%s\n',char(regime));

    for k = 1:K
        ii = ord(k);

        fprintf(fid,'  %-34s withinB=%.6f pooledB=%.6f\n', ...
            T.feature{ii},vals(k), ...
            T.test_auc_beneficial(ii));
    end
end

fprintf(fid,'\nBest single features by within-line Harmful AUC\n');
fprintf(fid,'------------------------------------------------\n');

for regime = ["Smooth","Abrupt"]
    T = singleA(strcmp(singleA.regime,char(regime)),:);

    [vals,ord] = sort( ...
        T.within_line_auc_harmful,'descend');

    K = min(8,height(T));

    fprintf(fid,'%s\n',char(regime));

    for k = 1:K
        ii = ord(k);

        fprintf(fid,'  %-34s withinH=%.6f pooledH=%.6f\n', ...
            T.feature{ii},vals(k), ...
            T.test_auc_harmful(ii));
    end
end

fprintf(fid,'\nGroup information audit\n');
fprintf(fid,'-----------------------\n');

for i = 1:height(groupA)
    fprintf(fid,[ ...
        '%s %-24s aucB=%.6f withinB=%.6f ' ...
        'aucH=%.6f withinH=%.6f utilityRho=%.6f\n'], ...
        groupA.regime{i},groupA.group{i}, ...
        groupA.beneficial_auc(i), ...
        groupA.within_line_beneficial_auc(i), ...
        groupA.harmful_auc(i), ...
        groupA.within_line_harmful_auc(i), ...
        groupA.signed_utility_spearman(i));
end

fprintf(fid,'\n25%% budget\n');
fprintf(fid,'----------\n');

rows25 = reported( ...
    abs(reported.target_budget-cfg.primary_budget)<1e-12,:);

for i = 1:height(rows25)
    fprintf(fid,[ ...
        '%s %-24s recall=%.6f capture=%.6f precision=%.6f ' ...
        'harm=%.6f actual=%.6f\n'], ...
        rows25.regime{i},rows25.policy{i}, ...
        rows25.policy_recall(i), ...
        rows25.beneficial_capture(i), ...
        rows25.benefit_precision(i), ...
        rows25.harmful_fraction_among_triggers(i), ...
        rows25.actual_trigger_rate(i));
end

fprintf(fid,'\nDecision summary\n');
fprintf(fid,'----------------\n');

for i = 1:height(decision)
    fprintf(fid,[ ...
        '%s withinB: base %.3f morph %.3f strong %.3f subap %.3f all %.3f | ' ...
        'withinH: base %.3f morph %.3f strong %.3f subap %.3f all %.3f | ' ...
        'stateAll recall gain %.4f | oracleFrac %.3f -> %.3f\n'], ...
        decision.regime{i}, ...
        decision.withinB_baseline(i), ...
        decision.withinB_morphology(i), ...
        decision.withinB_strongCompetition(i), ...
        decision.withinB_subaperture(i), ...
        decision.withinB_allObservable(i), ...
        decision.withinH_baseline(i), ...
        decision.withinH_morphology(i), ...
        decision.withinH_strongCompetition(i), ...
        decision.withinH_subaperture(i), ...
        decision.withinH_allObservable(i), ...
        decision.recall25_stateAll_gain_over_best_source(i), ...
        decision.oracleFrac_stateOnly(i), ...
        decision.oracleFrac_stateAll(i));
end

fprintf(fid,'\nInterpretation notices\n');
fprintf(fid,'----------------------\n');

for i = 1:height(decision)
    regime = decision.regime{i};

    if decision.withinB_allObservable(i) >= ...
            cfg.notice_within_beneficial
        fprintf(fid,[ ...
            '%s: richer observables reach meaningful within-state ' ...
            'Beneficial discrimination (%.3f >= %.3f).\n'], ...
            regime,decision.withinB_allObservable(i), ...
            cfg.notice_within_beneficial);
    else
        fprintf(fid,[ ...
            '%s: richer observables still show limited within-state ' ...
            'Beneficial discrimination (%.3f < %.3f).\n'], ...
            regime,decision.withinB_allObservable(i), ...
            cfg.notice_within_beneficial);
    end

    if decision.withinH_allObservable(i) >= ...
            cfg.notice_within_harmful
        fprintf(fid,[ ...
            '%s: richer observables reach strong Harmful discrimination ' ...
            '(%.3f >= %.3f), supporting harm-aware gating.\n'], ...
            regime,decision.withinH_allObservable(i), ...
            cfg.notice_within_harmful);
    else
        fprintf(fid,[ ...
            '%s: Harmful discrimination remains below the strong notice ' ...
            'level (%.3f < %.3f).\n'], ...
            regime,decision.withinH_allObservable(i), ...
            cfg.notice_within_harmful);
    end
end

fprintf(fid,'\nScientific boundary\n');
fprintf(fid,'-------------------\n');
fprintf(fid,['This is an observable-information audit under oracle q_strong. ' ...
    'Any feature gain is evidence that the signal contains exploitable ' ...
    'realization information; it is not yet a deployable final policy.\n']);

fclose(fid);

end

%% ========================================================================
function make_figures( ...
    out_dir,cfg,singleA,groupA,stateBinA, ...
    budget_curves,reported,oracle_gap, ...
    test_smooth,test_abrupt)

regimes = ["Smooth","Abrupt"];

%% Fig 1: top single Beneficial features, within-line AUC
features = unique(string(singleA.feature),'stable');

score = nan(numel(features),1);

for i = 1:numel(features)
    mm = string(singleA.feature)==features(i);

    score(i) = mean( ...
        singleA.within_line_auc_beneficial(mm), ...
        'omitnan');
end

[~,ord] = sort(score,'descend');
K = min(10,numel(ord));

sel = features(ord(1:K));

Y = nan(K,2);

for k = 1:K
    for ir = 1:2
        mm = string(singleA.feature)==sel(k) & ...
             string(singleA.regime)==regimes(ir);

        Y(k,ir) = ...
            singleA.within_line_auc_beneficial(mm);
    end
end

fig = figure('Visible',cfg.figure_visible);
bar(Y);

yline(0.5,'--');
ylim([0.45 1]);

xticks(1:K);
xticklabels(sel);
xtickangle(35);

ylabel('Weighted within-line Beneficial AUC');
title('C3-B1.2 Top Realization Observables for Beneficial Fate');

legend(regimes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig01_top_single_withinB.png'), ...
    'Resolution',180);

close(fig);

%% Fig 2: top single Harmful features, within-line AUC
score = nan(numel(features),1);

for i = 1:numel(features)
    mm = string(singleA.feature)==features(i);

    score(i) = mean( ...
        singleA.within_line_auc_harmful(mm), ...
        'omitnan');
end

[~,ord] = sort(score,'descend');
K = min(10,numel(ord));

sel = features(ord(1:K));

Y = nan(K,2);

for k = 1:K
    for ir = 1:2
        mm = string(singleA.feature)==sel(k) & ...
             string(singleA.regime)==regimes(ir);

        Y(k,ir) = ...
            singleA.within_line_auc_harmful(mm);
    end
end

fig = figure('Visible',cfg.figure_visible);
bar(Y);

yline(0.5,'--');
ylim([0.45 1]);

xticks(1:K);
xticklabels(sel);
xtickangle(35);

ylabel('Weighted within-line Harmful AUC');
title('C3-B1.2 Top Realization Observables for Harmful Fate');

legend(regimes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig02_top_single_withinH.png'), ...
    'Resolution',180);

close(fig);

%% Fig 3: group within-line Beneficial AUC
plot_groups = [ ...
    "StateOnly", ...
    "BaselinePE", ...
    "MorphologyOnly", ...
    "StrongCompetitionOnly", ...
    "SubapertureOnly", ...
    "AllObservable", ...
    "StateAll"];

Y = nan(numel(plot_groups),2);

for ig = 1:numel(plot_groups)
    for ir = 1:2
        mm = string(groupA.group)==plot_groups(ig) & ...
             string(groupA.regime)==regimes(ir);

        Y(ig,ir) = ...
            groupA.within_line_beneficial_auc(mm);
    end
end

fig = figure('Visible',cfg.figure_visible);
bar(Y);

yline(0.5,'--');
ylim([0.45 1]);

xticks(1:numel(plot_groups));
xticklabels(plot_groups);
xtickangle(30);

ylabel('Weighted within-line Beneficial AUC');
title('C3-B1.2 Observable-Group Beneficial Audit');

legend(regimes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig03_group_withinB.png'), ...
    'Resolution',180);

close(fig);

%% Fig 4: group within-line Harmful AUC
Y = nan(numel(plot_groups),2);

for ig = 1:numel(plot_groups)
    for ir = 1:2
        mm = string(groupA.group)==plot_groups(ig) & ...
             string(groupA.regime)==regimes(ir);

        Y(ig,ir) = ...
            groupA.within_line_harmful_auc(mm);
    end
end

fig = figure('Visible',cfg.figure_visible);
bar(Y);

yline(0.5,'--');
ylim([0.45 1]);

xticks(1:numel(plot_groups));
xticklabels(plot_groups);
xtickangle(30);

ylabel('Weighted within-line Harmful AUC');
title('C3-B1.2 Observable-Group Harmful Audit');

legend(regimes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig04_group_withinH.png'), ...
    'Resolution',180);

close(fig);

%% Fig 5: Smooth quality-cost
policy_list = [ ...
    "StateOnly","BaselinePE", ...
    "StateMorphology","StateStrongCompetition", ...
    "StateSubaperture","StateAll", ...
    "TrialOracle","RandomExpected"];

fig = figure('Visible',cfg.figure_visible);
hold on;

for ip = 1:numel(policy_list)

    C = budget_curves( ...
        budget_curves.regime=="Smooth" & ...
        budget_curves.policy==policy_list(ip),:);

    plot( ...
        C.normalized_q_search_budget, ...
        C.policy_recall, ...
        'LineWidth',1.25);
end

xlabel('Normalized q-search budget');
ylabel('Weak recovery rate');
title('C3-B1.2 Smooth: Mechanism-Observable Quality-Cost');

legend(policy_list,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig05_smooth_quality_cost.png'), ...
    'Resolution',180);

close(fig);

%% Fig 6: Abrupt quality-cost
fig = figure('Visible',cfg.figure_visible);
hold on;

for ip = 1:numel(policy_list)

    C = budget_curves( ...
        budget_curves.regime=="Abrupt" & ...
        budget_curves.policy==policy_list(ip),:);

    plot( ...
        C.normalized_q_search_budget, ...
        C.policy_recall, ...
        'LineWidth',1.25);
end

xlabel('Normalized q-search budget');
ylabel('Weak recovery rate');
title('C3-B1.2 Abrupt: Mechanism-Observable Quality-Cost');

legend(policy_list,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig06_abrupt_quality_cost.png'), ...
    'Resolution',180);

close(fig);

%% Fig 7: 25% comparison
rows25 = reported( ...
    abs(reported.target_budget-cfg.primary_budget)<1e-12,:);

bars = [ ...
    "StateOnly", ...
    "BaselinePE", ...
    "StateMorphology", ...
    "StateStrongCompetition", ...
    "StateSubaperture", ...
    "StateAll"];

Y = nan(numel(bars),2);

for ip = 1:numel(bars)
    for ir = 1:2

        mm = strcmp(rows25.policy,char(bars(ip))) & ...
             strcmp(rows25.regime,char(regimes(ir)));

        Y(ip,ir) = rows25.policy_recall(mm);
    end
end

fig = figure('Visible',cfg.figure_visible);
bar(Y);

ylim([0 1]);

xticks(1:numel(bars));
xticklabels(bars);
xtickangle(30);

ylabel('Weak recovery rate');
title('C3-B1.2 Policy Comparison at 25% Budget');

legend(regimes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig07_policy_comparison_25pct.png'), ...
    'Resolution',180);

close(fig);

%% Fig 8: Oracle gap capture at 25%
G = oracle_gap( ...
    abs(oracle_gap.target_budget-cfg.primary_budget)<1e-12,:);

bars = [ ...
    "StateOnly", ...
    "BaselinePE", ...
    "AllObservable", ...
    "StateAll"];

Y = nan(numel(bars),2);

for ip = 1:numel(bars)
    for ir = 1:2

        mm = strcmp(G.policy,char(bars(ip))) & ...
             strcmp(G.regime,char(regimes(ir)));

        Y(ip,ir) = ...
            G.oracle_selection_advantage_fraction(mm);
    end
end

fig = figure('Visible',cfg.figure_visible);
bar(Y);

xticks(1:numel(bars));
xticklabels(bars);
xtickangle(25);

ylabel('Fraction of TrialOracle selection advantage');
title('C3-B1.2 Oracle Opportunity Explained at 25% Budget');

legend(regimes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig08_oracle_gap_capture_25pct.png'), ...
    'Resolution',180);

close(fig);

%% Fig 9-10: state-bin AUC for selected observable groups
state_plot_groups = [ ...
    "BaselinePE", ...
    "MorphologyOnly", ...
    "StrongCompetitionOnly", ...
    "SubapertureOnly", ...
    "AllObservable"];

for ir = 1:2

    regime = regimes(ir);

    fig = figure('Visible',cfg.figure_visible);
    hold on;

    for ig = 1:numel(state_plot_groups)

        C = stateBinA( ...
            string(stateBinA.regime)==regime & ...
            string(stateBinA.group)==state_plot_groups(ig),:);

        plot( ...
            C.mean_state_prior, ...
            C.beneficial_auc, ...
            '-o','LineWidth',1.15);
    end

    yline(0.5,'--');

    xlabel('Mean physical-state prior in bin');
    ylabel('Conditional Beneficial AUC');

    title(sprintf( ...
        'C3-B1.2 %s: Beneficial Information Across State', ...
        char(regime)));

    legend(state_plot_groups,'Location','best');
    grid on;

    exportgraphics(fig, ...
        fullfile(out_dir,sprintf( ...
        'fig%02d_%s_state_bin_B.png', ...
        8+ir,lower(char(regime)))), ...
        'Resolution',180);

    close(fig);
end

%% Fig 11-12: Harmful state-bin AUC
for ir = 1:2

    regime = regimes(ir);

    fig = figure('Visible',cfg.figure_visible);
    hold on;

    for ig = 1:numel(state_plot_groups)

        C = stateBinA( ...
            string(stateBinA.regime)==regime & ...
            string(stateBinA.group)==state_plot_groups(ig),:);

        plot( ...
            C.mean_state_prior, ...
            C.harmful_auc, ...
            '-o','LineWidth',1.15);
    end

    yline(0.5,'--');

    xlabel('Mean physical-state prior in bin');
    ylabel('Conditional Harmful AUC');

    title(sprintf( ...
        'C3-B1.2 %s: Harmful Information Across State', ...
        char(regime)));

    legend(state_plot_groups,'Location','best');
    grid on;

    exportgraphics(fig, ...
        fullfile(out_dir,sprintf( ...
        'fig%02d_%s_state_bin_H.png', ...
        10+ir,lower(char(regime)))), ...
        'Resolution',180);

    close(fig);
end

%% Fig 13: representative competition plane, Smooth
class_id = zeros(height(test_smooth),1);
class_id(logical(test_smooth.beneficial)) = 1;
class_id(logical(test_smooth.harmful)) = -1;

fig = figure('Visible',cfg.figure_visible);

scatter( ...
    test_smooth.peak_second_ratio, ...
    test_smooth.strong_q_response_ratio, ...
    15,class_id,'filled');

xlabel('Second / first q-curve peak');
ylabel('Response at q_s / dominant response');
title('C3-B1.2 Smooth Peak-Competition Geometry');

cb = colorbar;
cb.Ticks = [-1 0 1];
cb.TickLabels = {'Harmful','Neutral','Beneficial'};

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig13_smooth_peak_competition_plane.png'), ...
    'Resolution',180);

close(fig);

%% Fig 14: representative sub-aperture plane, Abrupt
class_id = zeros(height(test_abrupt),1);
class_id(logical(test_abrupt.beneficial)) = 1;
class_id(logical(test_abrupt.harmful)) = -1;

fig = figure('Visible',cfg.figure_visible);

scatter( ...
    test_abrupt.subap_q_std_norm, ...
    test_abrupt.subap_consensus_fraction, ...
    15,class_id,'filled');

xlabel('Sub-aperture q std / \tau_q');
ylabel('Sub-aperture consensus fraction');
title('C3-B1.2 Abrupt Sub-Aperture Stability Plane');

cb = colorbar;
cb.Ticks = [-1 0 1];
cb.TickLabels = {'Harmful','Neutral','Beneficial'};

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig14_abrupt_subaperture_plane.png'), ...
    'Resolution',180);

close(fig);

end

%% ========================================================================
function edges = quantile_edges_unique(x,nBins)

x = double(x(:));
x = x(isfinite(x));

if isempty(x)
    error('No finite values for state binning.');
end

pp = linspace(0,1,nBins+1);

edges = nan(size(pp));

for i = 1:numel(pp)
    edges(i) = empirical_quantile(x,pp(i));
end

edges = unique(edges,'stable');

if numel(edges)<2
    mn = min(x);
    mx = max(x);

    if abs(mx-mn)<eps
        edges = [mn-0.5,mx+0.5];
    else
        edges = [mn,mx];
    end
end

span = max(1,abs(edges(end)-edges(1)));

edges(1) = edges(1)-1e-12*span;
edges(end) = edges(end)+1e-12*span;

end

%% ========================================================================
function bin_id = assign_bins(x,edges)

x = double(x(:));
edges = double(edges(:).');

B = numel(edges)-1;

bin_id = nan(size(x));

for ib = 1:B
    if ib<B
        mm = x>=edges(ib) & x<edges(ib+1);
    else
        mm = x>=edges(ib) & x<=edges(ib+1);
    end

    bin_id(mm) = ib;
end

end

%% ========================================================================
function auc = binary_auc(y,score)

y = logical(y(:));
score = double(score(:));

valid = isfinite(score);

y = y(valid);
score = score(valid);

nPos = sum(y);
nNeg = sum(~y);

if nPos==0 || nNeg==0
    auc = NaN;
    return;
end

r = average_ranks(score);

sumPos = sum(r(y));

auc = ...
    (sumPos - nPos*(nPos+1)/2) / ...
    (nPos*nNeg);

end

%% ========================================================================
function rho = spearman_manual(x,y)

x = double(x(:));
y = double(y(:));

valid = isfinite(x) & isfinite(y);

x = x(valid);
y = y(valid);

if numel(x)<3
    rho = NaN;
    return;
end

rx = average_ranks(x);
ry = average_ranks(y);

C = corrcoef(rx,ry);

if numel(C)<4
    rho = NaN;
else
    rho = C(1,2);
end

end

%% ========================================================================
function r = average_ranks(x)

x = double(x(:));

[xs,ord] = sort(x);
rs = nan(size(xs));

i = 1;

while i<=numel(xs)
    j = i;

    while j<numel(xs) && xs(j+1)==xs(i)
        j = j+1;
    end

    rs(i:j) = (i+j)/2;
    i = j+1;
end

r = nan(size(x));
r(ord) = rs;

end

%% ========================================================================
function q = empirical_quantile(x,p)

x = double(x(:));
x = x(isfinite(x));

if isempty(x)
    q = NaN;
    return;
end

x = sort(x);

p = min(max(double(p),0),1);

if numel(x)==1
    q = x(1);
    return;
end

pos = 1+p*(numel(x)-1);

lo = floor(pos);
hi = ceil(pos);

if lo==hi
    q = x(lo);
else
    w = pos-lo;

    q = ...
        (1-w)*x(lo) + ...
        w*x(hi);
end

if ~isscalar(q)
    error('empirical_quantile must return a scalar.');
end

end

%% ========================================================================
function v = scalar_unique(x,label)

x = double(x(:));
x = x(isfinite(x));

if isempty(x)
    error('No finite values for %s.',label);
end

v = x(1);

if any(abs(x-v)>1e-12)
    error('%s is not constant.',label);
end

end

%% ========================================================================
function assert_table_vars(T,names,filename)

vars = T.Properties.VariableNames;

for i = 1:numel(names)
    if ~ismember(names{i},vars)
        error('Missing variable "%s" in %s.', ...
            names{i},filename);
    end
end

end
