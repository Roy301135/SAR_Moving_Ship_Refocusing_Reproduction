function results = exp09c3b3b_nearshift_mechanism_local_recovery()
%EXP09C3B3B_NEARSHIFT_MECHANISM_LOCAL_RECOVERY
% EXP009 / Pilot-01 / C3-B3B
%
% Near-Shift Mechanism and Local Peak Recovery
%
% -------------------------------------------------------------------------
% Why this experiment exists
% -------------------------------------------------------------------------
% C3-B3A showed that the dominant fallback-failure mode is NearShift:
%
%   the fallback q landscape is usually almost correct,
%   but the winner moves just outside |q-q_weak| <= tau_q.
%
% Strong residual energy is already tiny and weak retention is nearly 1,
% so C3-B3B does NOT continue to optimize strong suppression.
%
% Instead it asks:
%
%   A) Does the A4/B1 first-order perturbation law explain the shift?
%   B) Is the shift merely caused by q-grid discretization?
%   C) Can local observable curve geometry correct it cheaply?
%   D) Are Cheap and fallback q errors coupled?
%
% -------------------------------------------------------------------------
% A4/B1 first-order mechanism diagnostic
% -------------------------------------------------------------------------
% Holding the SAME fitted fallback projection operator fixed:
%
%   R = E_w + E_s + E_n
%
% On an oracle-centered fine matched-response grid:
%
%   P_total(q)
%       = P_w(q)
%       + P_s(q)
%       + P_n(q)
%       + P_ws(q)
%       + P_wn(q)
%       + P_sn(q)
%
% Around the weak-only peak q0:
%
%   delta_q_pred
%       = - DeltaP'(q0) / P_w''(q0)
%
% with exact slope contributions from:
%   strong power,
%   noise power,
%   weak-strong cross term,
%   weak-noise cross term,
%   strong-noise cross term.
%
% -------------------------------------------------------------------------
% Practical local estimators
% -------------------------------------------------------------------------
% These use ONLY the observed coarse fallback q curve:
%
%   1) CoarseTop1
%   2) Parabolic3
%   3) LogQuadratic5
%   4) LocalCentroid7
%
% They never use q_weak.
%
% A separate half-step FULL q search is applied only to coarse fallback
% failures as a diagnostic upper bound on grid-discretization effects.
%
% Run:
%   results = exp09c3b3b_nearshift_mechanism_local_recovery;

cfg = config_exp09c3b3b();

%% Resolve output path
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.output_dir)
    out_path = fullfile( ...
        paper_root,'results','exp09_pilot01', ...
        'exp09c3b3b_nearshift_mechanism_local_recovery');
else
    out_path = cfg.output_dir;
end

if ~exist(out_path,'dir')
    mkdir(out_path);
end

fprintf('\n============================================================\n');
fprintf(' EXP009-C3-B3B / Near-Shift Mechanism + Local Recovery\n');
fprintf('============================================================\n');
fprintf('Output           : %s\n',out_path);
fprintf('MC / regime      : %d\n',cfg.num_mc);
fprintf('Lines / MC       : %d\n',cfg.num_lines);
fprintf('SNR              : %.1f dB\n',cfg.snr_db);
fprintf('coarse q step    : %.6f\n',cfg.q_search_step);
fprintf('half-grid q step : %.6f\n',cfg.q_half_step);
fprintf('success tau_q    : %.6f\n\n',cfg.tau_q);

%% Common setup
N = cfg.N;
n = 0:N-1;
t = (n-N/2)/N;

q_grid = ( ...
    cfg.q_search_min: ...
    cfg.q_search_step: ...
    cfg.q_search_max).';

q_half = ( ...
    cfg.q_search_min: ...
    cfg.q_half_step: ...
    cfg.q_search_max).';

q_diag = ( ...
    cfg.q_weak-cfg.q_diag_halfwidth: ...
    cfg.q_diag_step: ...
    cfg.q_weak+cfg.q_diag_halfwidth).';

D_search = build_dechirp_dictionary(q_grid,t,cfg);
D_half = build_dechirp_dictionary(q_half,t,cfg);
D_match = build_matched_dictionary(q_diag,t,cfg.f_weak,cfg);

%% Physical trajectories
traj_smooth = build_trajectory("Smooth",cfg);
traj_abrupt = build_trajectory("Abrupt",cfg);

writetable(traj_smooth, ...
    fullfile(out_path,'trajectory_smooth.csv'));

writetable(traj_abrupt, ...
    fullfile(out_path,'trajectory_abrupt.csv'));

%% Deterministic signal components
det_smooth = precompute_deterministic_components( ...
    traj_smooth,t,cfg);

det_abrupt = precompute_deterministic_components( ...
    traj_abrupt,t,cfg);

%% Run banks
fprintf('Running Smooth bank...\n');
tic;
T_smooth = run_regime_bank( ...
    "Smooth",det_smooth,traj_smooth, ...
    cfg.num_mc,cfg.seed+5300, ...
    q_grid,q_half,q_diag, ...
    D_search,D_half,D_match,t,cfg);
time_smooth = toc;

fprintf('Running Abrupt bank...\n');
tic;
T_abrupt = run_regime_bank( ...
    "Abrupt",det_abrupt,traj_abrupt, ...
    cfg.num_mc,cfg.seed+6300, ...
    q_grid,q_half,q_diag, ...
    D_search,D_half,D_match,t,cfg);
time_abrupt = toc;

fprintf('Smooth runtime: %.2f s\n',time_smooth);
fprintf('Abrupt runtime: %.2f s\n\n',time_abrupt);

T_all = [T_smooth;T_abrupt];

writetable(T_smooth, ...
    fullfile(out_path,'trial_diagnostics_smooth.csv'));

writetable(T_abrupt, ...
    fullfile(out_path,'trial_diagnostics_abrupt.csv'));

writetable(T_all, ...
    fullfile(out_path,'trial_diagnostics_all.csv'));

%% A) Estimator comparison
estimator_summary = summarize_estimators(T_all);

writetable(estimator_summary, ...
    fullfile(out_path,'estimator_comparison.csv'));

%% B) Half-grid rescue diagnostic
halfgrid_summary = summarize_halfgrid_rescue(T_all);

writetable(halfgrid_summary, ...
    fullfile(out_path,'halfgrid_rescue_diagnostic.csv'));

%% C) First-order perturbation validation
firstorder_summary = summarize_firstorder(T_all,cfg);

writetable(firstorder_summary, ...
    fullfile(out_path,'first_order_validation.csv'));

%% D) Perturbation contribution anatomy
contrib_summary = summarize_contributions(T_all);

writetable(contrib_summary, ...
    fullfile(out_path,'perturbation_contribution_summary.csv'));

%% E) Cheap/fallback error coupling
coupling_summary = summarize_error_coupling(T_all,cfg);

writetable(coupling_summary, ...
    fullfile(out_path,'cheap_fallback_error_coupling.csv'));

%% F) NearShift-only correction audit
nearshift_summary = summarize_nearshift_correction(T_all);

writetable(nearshift_summary, ...
    fullfile(out_path,'nearshift_correction_diagnostics.csv'));

%% G) Compact decision table
decision = build_decision_summary( ...
    T_all,estimator_summary,halfgrid_summary, ...
    firstorder_summary,contrib_summary,coupling_summary);

writetable(decision, ...
    fullfile(out_path,'decision_summary.csv'));

%% Console
fprintf('\n================ ESTIMATOR COMPARISON ========================\n');
disp(estimator_summary);

fprintf('\n================ HALF-GRID DIAGNOSTIC ========================\n');
disp(halfgrid_summary);

fprintf('\n================ FIRST-ORDER VALIDATION ======================\n');
disp(firstorder_summary);

fprintf('\n================ CONTRIBUTION ANATOMY ========================\n');
disp(contrib_summary);

fprintf('\n================ ERROR COUPLING ==============================\n');
disp(coupling_summary);

fprintf('\n================ NEARSHIFT CORRECTION ========================\n');
disp(nearshift_summary);

fprintf('\n================ DECISION ====================================\n');
disp(decision);
fprintf('=============================================================\n');

%% Text summary
write_summary( ...
    out_path,cfg, ...
    estimator_summary,halfgrid_summary, ...
    firstorder_summary,contrib_summary, ...
    coupling_summary,nearshift_summary,decision, ...
    time_smooth,time_abrupt);

%% Save numerical results BEFORE plotting
% Plotting should never invalidate a completed Monte-Carlo experiment.
% If a MATLAB-version-specific graphics error occurs, all CSV/TXT/MAT
% numerical outputs remain available and the plotting error is recorded.
results = struct();
results.cfg = cfg;
results.estimator_summary = estimator_summary;
results.halfgrid_summary = halfgrid_summary;
results.firstorder_summary = firstorder_summary;
results.contrib_summary = contrib_summary;
results.coupling_summary = coupling_summary;
results.nearshift_summary = nearshift_summary;
results.decision = decision;

save(fullfile(out_path,'exp09c3b3b_results.mat'), ...
    'results','-v7.3');

%% Figures
try
    make_figures( ...
        out_path,cfg,T_smooth,T_abrupt, ...
        estimator_summary,halfgrid_summary, ...
        firstorder_summary,contrib_summary, ...
        coupling_summary,nearshift_summary);
catch ME
    warning('C3-B3B:PlottingFailed', ...
        ['Numerical experiment completed and was saved, but figure ' ...
         'generation failed: %s'],ME.message);

    fid_plot = fopen(fullfile(out_path,'plotting_error.txt'),'w');
    if fid_plot>=0
        fprintf(fid_plot,'C3-B3B plotting error\n');
        fprintf(fid_plot,'=====================\n\n');
        fprintf(fid_plot,'%s\n\n',ME.message);
        fprintf(fid_plot,'%s\n',getReport(ME,'extended','hyperlinks','off'));
        fclose(fid_plot);
    end
end

fprintf('\nSaved C3-B3B outputs to:\n%s\n\n',out_path);

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
function det = precompute_deterministic_components(traj,t,cfg)

L = height(traj);
N = cfg.N;

Sstrong = complex(zeros(L,N));
Sweak = complex(zeros(L,N));
EstrongCheap = complex(zeros(L,N));

for k = 1:L
    qs = traj.q_strong(k);
    rA = traj.weak_ratio(k);

    ss = synth_lfm( ...
        cfg.A_strong,qs, ...
        cfg.f_strong,cfg.phi_strong,t,cfg);

    sw = synth_lfm( ...
        cfg.A_strong*rA,cfg.q_weak, ...
        cfg.f_weak,cfg.phi_weak,t,cfg);

    k0 = get_strong_notch_bin(ss,qs,t,cfg);

    es = apply_fixed_notch_operator( ...
        ss,qs,k0,cfg.notch_halfwidth_bins,t,cfg);

    Sstrong(k,:) = ss(:).';
    Sweak(k,:) = sw(:).';
    EstrongCheap(k,:) = es(:).';
end

det = struct();
det.Sstrong = Sstrong;
det.Sweak = Sweak;
det.EstrongCheap = EstrongCheap;

end

%% ========================================================================
function T = run_regime_bank( ...
    regime,det,traj,num_mc,seed, ...
    q_grid,q_half,q_diag, ...
    D_search,D_half,D_match,t,cfg)

rng(seed,'twister');

L = height(traj);
N = cfg.N;

s_ref = synth_lfm( ...
    cfg.A_strong,cfg.q_weak-0.05, ...
    cfg.f_strong,cfg.phi_strong,t,cfg);

Pstrong = mean(abs(s_ref).^2);
noise_var = Pstrong/(10^(cfg.snr_db/10));

max_rows = L*num_mc;

sequence_id = zeros(max_rows,1);
line_index = zeros(max_rows,1);

weak_ratio = nan(max_rows,1);
signed_sep = nan(max_rows,1);

cheap_q_hat = nan(max_rows,1);
cheap_q_error = nan(max_rows,1);

coarse_q_hat = nan(max_rows,1);
coarse_q_error = nan(max_rows,1);
coarse_success = false(max_rows,1);
nearshift_failure = false(max_rows,1);

parabolic_q_hat = nan(max_rows,1);
parabolic_q_error = nan(max_rows,1);
parabolic_success = false(max_rows,1);
parabolic_offset = nan(max_rows,1);

logquad_q_hat = nan(max_rows,1);
logquad_q_error = nan(max_rows,1);
logquad_success = false(max_rows,1);
logquad_offset = nan(max_rows,1);

centroid_q_hat = nan(max_rows,1);
centroid_q_error = nan(max_rows,1);
centroid_success = false(max_rows,1);
centroid_offset = nan(max_rows,1);

local_peak_asymmetry = nan(max_rows,1);

halfgrid_q_hat = nan(max_rows,1);
halfgrid_q_error = nan(max_rows,1);
halfgrid_success = false(max_rows,1);
halfgrid_evaluated = false(max_rows,1);

matched_q0_weak = nan(max_rows,1);
matched_q_total = nan(max_rows,1);
matched_shift_measured = nan(max_rows,1);
matched_shift_predicted = nan(max_rows,1);
firstorder_valid = false(max_rows,1);

pred_shift_strong_power = nan(max_rows,1);
pred_shift_noise_power = nan(max_rows,1);
pred_shift_weak_strong_cross = nan(max_rows,1);
pred_shift_weak_noise_cross = nan(max_rows,1);
pred_shift_strong_noise_cross = nan(max_rows,1);

matched_total_to_weak_peak_ratio = nan(max_rows,1);

row0 = 0;

for imc = 1:num_mc

    noise = sqrt(noise_var/2) * ...
        (randn(L,N)+1j*randn(L,N));

    %% Cheap branch
    Xcheap = det.Sweak + det.EstrongCheap + noise;

    qhc = search_q_hat_batch( ...
        Xcheap,q_grid,D_search, ...
        cfg.q_search_block_lines);

    cheap_success_all = ...
        abs(qhc-cfg.q_weak) <= ...
        (cfg.tau_q+cfg.success_tol);

    cheap_failure_all = ~cheap_success_all;

    %% Fallback residual
    Xmix = det.Sstrong + det.Sweak + noise;

    [R,Es,Ew,En] = ...
        refit_and_decompose_batch( ...
            Xmix,det.Sstrong,det.Sweak,noise, ...
            traj.q_strong,t,cfg);

    [qhf,Mcoarse] = search_q_curve_batch( ...
        R,q_grid,D_search, ...
        cfg.q_search_block_lines);

    idx_cf = find(cheap_failure_all);

    if isempty(idx_cf)
        continue;
    end

    %% Half-grid diagnostic only for COARSE fallback failures
    coarse_fail_all = ...
        abs(qhf-cfg.q_weak) > ...
        (cfg.tau_q+cfg.success_tol);

    idx_half = find(cheap_failure_all & coarse_fail_all);

    qh_half_local = nan(numel(idx_half),1);

    if ~isempty(idx_half)
        qh_half_local = search_q_hat_batch( ...
            R(idx_half,:),q_half,D_half, ...
            cfg.q_search_block_lines);
    end

    %% Exact matched-response first-order diagnostics for CheapFailure rows
    match = matched_firstorder_batch( ...
        Ew(idx_cf,:),Es(idx_cf,:),En(idx_cf,:), ...
        q_diag,D_match,cfg);

    %% Store CheapFailure rows
    for jj = 1:numel(idx_cf)

        k = idx_cf(jj);
        row0 = row0+1;

        m = Mcoarse(:,k);

        q_coarse = qhf(k);

        q_para = parabolic_peak_estimate(q_grid,m);
        q_logq = log_quadratic_peak_estimate( ...
            q_grid,m,cfg.logquad_halfbins);
        q_cent = local_centroid_estimate( ...
            q_grid,m,cfg.centroid_halfbins, ...
            cfg.centroid_power);

        asym = local_peak_asymmetry_metric(q_grid,m);

        sequence_id(row0) = imc;
        line_index(row0) = traj.line_index(k);

        weak_ratio(row0) = traj.weak_ratio(k);
        signed_sep(row0) = traj.signed_sep(k);

        cheap_q_hat(row0) = qhc(k);
        cheap_q_error(row0) = qhc(k)-cfg.q_weak;

        coarse_q_hat(row0) = q_coarse;
        coarse_q_error(row0) = q_coarse-cfg.q_weak;

        coarse_success(row0) = ...
            abs(coarse_q_error(row0)) <= ...
            (cfg.tau_q+cfg.success_tol);

        nearshift_failure(row0) = ...
            (~coarse_success(row0)) && ...
            (abs(coarse_q_error(row0)) <= ...
            cfg.near_shift_tol+cfg.success_tol);

        parabolic_q_hat(row0) = q_para;
        parabolic_q_error(row0) = q_para-cfg.q_weak;
        parabolic_success(row0) = ...
            abs(parabolic_q_error(row0)) <= ...
            (cfg.tau_q+cfg.success_tol);
        parabolic_offset(row0) = q_para-q_coarse;

        logquad_q_hat(row0) = q_logq;
        logquad_q_error(row0) = q_logq-cfg.q_weak;
        logquad_success(row0) = ...
            abs(logquad_q_error(row0)) <= ...
            (cfg.tau_q+cfg.success_tol);
        logquad_offset(row0) = q_logq-q_coarse;

        centroid_q_hat(row0) = q_cent;
        centroid_q_error(row0) = q_cent-cfg.q_weak;
        centroid_success(row0) = ...
            abs(centroid_q_error(row0)) <= ...
            (cfg.tau_q+cfg.success_tol);
        centroid_offset(row0) = q_cent-q_coarse;

        local_peak_asymmetry(row0) = asym;

        % Half-grid row lookup.  Scalar-safe by construction.
        jh = find(idx_half==k,1);

        if ~isempty(jh)
            qhh = qh_half_local(jh);

            halfgrid_evaluated(row0) = true;
            halfgrid_q_hat(row0) = qhh;
            halfgrid_q_error(row0) = qhh-cfg.q_weak;
            halfgrid_success(row0) = ...
                abs(halfgrid_q_error(row0)) <= ...
                (cfg.tau_q+cfg.success_tol);
        end

        % Matched first-order diagnostics.
        matched_q0_weak(row0) = ...
            match.q0_weak(jj);

        matched_q_total(row0) = ...
            match.q_total(jj);

        matched_shift_measured(row0) = ...
            match.shift_measured(jj);

        matched_shift_predicted(row0) = ...
            match.shift_predicted(jj);

        firstorder_valid(row0) = ...
            match.valid(jj);

        pred_shift_strong_power(row0) = ...
            match.shift_strong_power(jj);

        pred_shift_noise_power(row0) = ...
            match.shift_noise_power(jj);

        pred_shift_weak_strong_cross(row0) = ...
            match.shift_weak_strong_cross(jj);

        pred_shift_weak_noise_cross(row0) = ...
            match.shift_weak_noise_cross(jj);

        pred_shift_strong_noise_cross(row0) = ...
            match.shift_strong_noise_cross(jj);

        matched_total_to_weak_peak_ratio(row0) = ...
            match.total_to_weak_peak_ratio(jj);
    end
end

keep = 1:row0;

regime_col = repmat(string(regime),row0,1);

T = table( ...
    regime_col, ...
    sequence_id(keep),line_index(keep), ...
    weak_ratio(keep),signed_sep(keep), ...
    cheap_q_hat(keep),cheap_q_error(keep), ...
    coarse_q_hat(keep),coarse_q_error(keep), ...
    coarse_success(keep),nearshift_failure(keep), ...
    parabolic_q_hat(keep),parabolic_q_error(keep), ...
    parabolic_success(keep),parabolic_offset(keep), ...
    logquad_q_hat(keep),logquad_q_error(keep), ...
    logquad_success(keep),logquad_offset(keep), ...
    centroid_q_hat(keep),centroid_q_error(keep), ...
    centroid_success(keep),centroid_offset(keep), ...
    local_peak_asymmetry(keep), ...
    halfgrid_q_hat(keep),halfgrid_q_error(keep), ...
    halfgrid_success(keep),halfgrid_evaluated(keep), ...
    matched_q0_weak(keep),matched_q_total(keep), ...
    matched_shift_measured(keep), ...
    matched_shift_predicted(keep), ...
    firstorder_valid(keep), ...
    pred_shift_strong_power(keep), ...
    pred_shift_noise_power(keep), ...
    pred_shift_weak_strong_cross(keep), ...
    pred_shift_weak_noise_cross(keep), ...
    pred_shift_strong_noise_cross(keep), ...
    matched_total_to_weak_peak_ratio(keep), ...
    'VariableNames',{ ...
    'regime', ...
    'sequence_id','line_index', ...
    'weak_ratio','signed_sep', ...
    'cheap_q_hat','cheap_q_error', ...
    'coarse_q_hat','coarse_q_error', ...
    'coarse_success','nearshift_failure', ...
    'parabolic_q_hat','parabolic_q_error', ...
    'parabolic_success','parabolic_offset', ...
    'logquad_q_hat','logquad_q_error', ...
    'logquad_success','logquad_offset', ...
    'centroid_q_hat','centroid_q_error', ...
    'centroid_success','centroid_offset', ...
    'local_peak_asymmetry', ...
    'halfgrid_q_hat','halfgrid_q_error', ...
    'halfgrid_success','halfgrid_evaluated', ...
    'matched_q0_weak','matched_q_total', ...
    'matched_shift_measured', ...
    'matched_shift_predicted', ...
    'firstorder_valid', ...
    'pred_shift_strong_power', ...
    'pred_shift_noise_power', ...
    'pred_shift_weak_strong_cross', ...
    'pred_shift_weak_noise_cross', ...
    'pred_shift_strong_noise_cross', ...
    'matched_total_to_weak_peak_ratio'});

end

%% ========================================================================
function M = matched_firstorder_batch(Ew,Es,En,q_diag,D_match,cfg)

Ew = double_complex_guard(Ew,'Ew');
Es = double_complex_guard(Es,'Es');
En = double_complex_guard(En,'En');

if ~isequal(size(Ew),size(Es),size(En))
    error('matched_firstorder_batch: Ew/Es/En size mismatch.');
end

B = size(Ew,1);
Q = numel(q_diag);

if size(D_match,1)~=Q || size(D_match,2)~=size(Ew,2)
    error('matched_firstorder_batch dictionary dimension mismatch.');
end

% Q x B
Cw = D_match * Ew.';
Cs = D_match * Es.';
Cn = D_match * En.';

Pw = abs(Cw).^2;
Ps = abs(Cs).^2;
Pn = abs(Cn).^2;

Pws = 2*real(Cw.*conj(Cs));
Pwn = 2*real(Cw.*conj(Cn));
Psn = 2*real(Cs.*conj(Cn));

Ptotal = Pw + Ps + Pn + Pws + Pwn + Psn;

q0_weak = nan(B,1);
q_total = nan(B,1);

shift_measured = nan(B,1);
shift_predicted = nan(B,1);

shift_strong_power = nan(B,1);
shift_noise_power = nan(B,1);
shift_weak_strong_cross = nan(B,1);
shift_weak_noise_cross = nan(B,1);
shift_strong_noise_cross = nan(B,1);

total_to_weak_peak_ratio = nan(B,1);
valid = false(B,1);

h = cfg.q_diag_step;

for b = 1:B

    [pw_peak,i0] = max(Pw(:,b));
    [pt_peak,it] = max(Ptotal(:,b));

    q0 = q_diag(i0);
    qt = q_diag(it);

    q0_weak(b) = q0;
    q_total(b) = qt;

    shift_measured(b) = qt-q0;

    total_to_weak_peak_ratio(b) = ...
        pt_peak/max(pw_peak,eps);

    if i0<=1 || i0>=Q
        continue;
    end

    P0dd = ...
        (Pw(i0+1,b) - 2*Pw(i0,b) + Pw(i0-1,b)) / ...
        (h^2);

    if ~isfinite(P0dd) || P0dd>=0 || abs(P0dd)<eps
        continue;
    end

    dPs = central_slope(Ps(:,b),i0,h);
    dPn = central_slope(Pn(:,b),i0,h);
    dPws = central_slope(Pws(:,b),i0,h);
    dPwn = central_slope(Pwn(:,b),i0,h);
    dPsn = central_slope(Psn(:,b),i0,h);

    ds = -dPs/P0dd;
    dn = -dPn/P0dd;
    dws = -dPws/P0dd;
    dwn = -dPwn/P0dd;
    dsn = -dPsn/P0dd;

    dpred = ds+dn+dws+dwn+dsn;

    if ~isfinite(dpred) || ...
            abs(dpred)>cfg.max_firstorder_abs_shift
        continue;
    end

    shift_strong_power(b) = ds;
    shift_noise_power(b) = dn;
    shift_weak_strong_cross(b) = dws;
    shift_weak_noise_cross(b) = dwn;
    shift_strong_noise_cross(b) = dsn;

    shift_predicted(b) = dpred;
    valid(b) = true;
end

M = struct();
M.q0_weak = q0_weak;
M.q_total = q_total;
M.shift_measured = shift_measured;
M.shift_predicted = shift_predicted;
M.valid = valid;

M.shift_strong_power = shift_strong_power;
M.shift_noise_power = shift_noise_power;
M.shift_weak_strong_cross = shift_weak_strong_cross;
M.shift_weak_noise_cross = shift_weak_noise_cross;
M.shift_strong_noise_cross = shift_strong_noise_cross;

M.total_to_weak_peak_ratio = total_to_weak_peak_ratio;

end

%% ========================================================================
function v = central_slope(x,i,h)

if i<=1 || i>=numel(x)
    v = NaN;
    return;
end

v = (x(i+1)-x(i-1))/(2*h);

end

%% ========================================================================
function qhat = parabolic_peak_estimate(q,m)

q = q(:);
m = double(m(:));

[~,i] = max(m);

if i<=1 || i>=numel(m)
    qhat = q(i);
    return;
end

ym = m(i-1);
y0 = m(i);
yp = m(i+1);

den = ym - 2*y0 + yp;

if ~isfinite(den) || abs(den)<eps || den>=0
    qhat = q(i);
    return;
end

delta_bins = 0.5*(ym-yp)/den;
delta_bins = min(max(delta_bins,-1),1);

dq = q(i+1)-q(i);

qhat = q(i) + delta_bins*dq;

if ~isscalar(qhat) || ~isfinite(qhat)
    qhat = q(i);
end

end

%% ========================================================================
function qhat = log_quadratic_peak_estimate(q,m,halfbins)

q = q(:);
m = double(m(:));

[~,i] = max(m);

i1 = max(1,i-halfbins);
i2 = min(numel(m),i+halfbins);

idx = (i1:i2).';

if numel(idx)<3
    qhat = q(i);
    return;
end

x = q(idx);
y = log(max(m(idx),realmin));

p = polyfit(x,y,2);

if ~all(isfinite(p)) || p(1)>=0 || abs(p(1))<eps
    qhat = q(i);
    return;
end

qv = -p(2)/(2*p(1));

if qv < min(x) || qv > max(x) || ~isfinite(qv)
    qhat = q(i);
else
    qhat = qv;
end

if ~isscalar(qhat)
    error('log_quadratic_peak_estimate returned non-scalar qhat.');
end

end

%% ========================================================================
function qhat = local_centroid_estimate( ...
    q,m,halfbins,power_exp)

q = q(:);
m = double(m(:));

[~,i] = max(m);

i1 = max(1,i-halfbins);
i2 = min(numel(m),i+halfbins);

idx = (i1:i2).';

x = q(idx);
y = m(idx);

floor_y = min(y);
w = max(y-floor_y,0).^power_exp;

sw = sum(w);

if ~isfinite(sw) || sw<=eps
    qhat = q(i);
else
    qhat = sum(x.*w)/sw;
end

if ~isscalar(qhat) || ~isfinite(qhat)
    qhat = q(i);
end

end

%% ========================================================================
function a = local_peak_asymmetry_metric(q,m)

q = q(:); %#ok<NASGU>
m = double(m(:));

[~,i] = max(m);

if i<=1 || i>=numel(m)
    a = 0;
    return;
end

left_drop = m(i)-m(i-1);
right_drop = m(i)-m(i+1);

den = abs(left_drop)+abs(right_drop)+eps;

a = (left_drop-right_drop)/den;

if ~isscalar(a) || ~isfinite(a)
    a = 0;
end

end

%% ========================================================================
function S = summarize_estimators(T)

regimes = unique(string(T.regime),'stable');

methods = { ...
    'CoarseTop1','coarse_success','coarse_q_error'; ...
    'Parabolic3','parabolic_success','parabolic_q_error'; ...
    'LogQuadratic5','logquad_success','logquad_q_error'; ...
    'LocalCentroid7','centroid_success','centroid_q_error'};

rows = {};

for ir = 1:numel(regimes)
    r = regimes(ir);
    Tr = T(string(T.regime)==r,:);

    for im = 1:size(methods,1)
        name = methods{im,1};
        success_var = methods{im,2};
        err_var = methods{im,3};

        s = logical(Tr.(success_var));
        e = double(Tr.(err_var));

        rows(end+1,:) = { ... %#ok<AGROW>
            char(r),name,height(Tr), ...
            mean(double(s)), ...
            sqrt(mean(e.^2,'omitnan')), ...
            mean(abs(e),'omitnan'), ...
            median(abs(e),'omitnan')};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','method','n_cheapfailure', ...
    'recovery_rate','q_rmse','q_mae','q_median_abs_error'});

end

%% ========================================================================
function S = summarize_halfgrid_rescue(T)

regimes = unique(string(T.regime),'stable');

rows = {};

for ir = 1:numel(regimes)
    r = regimes(ir);
    Tr = T(string(T.regime)==r,:);

    mm = logical(Tr.halfgrid_evaluated);

    n = sum(mm);

    if n==0
        rescue = NaN;
        mae_before = NaN;
        mae_after = NaN;
        near_fraction = NaN;
    else
        rescue = mean(double(Tr.halfgrid_success(mm)));

        mae_before = ...
            mean(abs(Tr.coarse_q_error(mm)),'omitnan');

        mae_after = ...
            mean(abs(Tr.halfgrid_q_error(mm)),'omitnan');

        near_fraction = ...
            mean(double(Tr.nearshift_failure(mm)));
    end

    rows(end+1,:) = { ... %#ok<AGROW>
        char(r),n,rescue, ...
        mae_before,mae_after,near_fraction};
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','n_coarse_fallback_failures', ...
    'fraction_rescued_by_halfgrid', ...
    'coarse_failure_mae','halfgrid_mae', ...
    'nearshift_fraction_among_coarse_failures'});

end

%% ========================================================================
function S = summarize_firstorder(T,cfg)

regimes = unique(string(T.regime),'stable');

subset_names = ["AllCheapFailure","FallbackFailure","NearShift"];

rows = {};

for ir = 1:numel(regimes)
    r = regimes(ir);
    Tr = T(string(T.regime)==r,:);

    for isub = 1:numel(subset_names)
        sname = subset_names(isub);

        switch sname
            case "AllCheapFailure"
                mm = true(height(Tr),1);

            case "FallbackFailure"
                mm = ~logical(Tr.coarse_success);

            case "NearShift"
                mm = logical(Tr.nearshift_failure);

            otherwise
                error('Unknown first-order subset.');
        end

        mm = mm & logical(Tr.firstorder_valid);

        x = Tr.matched_shift_measured(mm);
        y = Tr.matched_shift_predicted(mm);

        valid = isfinite(x) & isfinite(y);

        x = x(valid);
        y = y(valid);

        n = numel(x);

        if n>=cfg.min_validation_samples
            pearson_r = safe_pearson(x,y);
            spearman_r = safe_spearman(x,y);

            p = polyfit(x,y,1);
            slope = p(1);
            intercept = p(2);

            rmse = sqrt(mean((y-x).^2));
            mae = mean(abs(y-x));

            sign_agree = sign_agreement(x,y);
        else
            pearson_r = NaN;
            spearman_r = NaN;
            slope = NaN;
            intercept = NaN;
            rmse = NaN;
            mae = NaN;
            sign_agree = NaN;
        end

        rows(end+1,:) = { ... %#ok<AGROW>
            char(r),char(sname),n, ...
            pearson_r,spearman_r, ...
            slope,intercept,rmse,mae,sign_agree};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','subset','n_valid', ...
    'pearson_r','spearman_r', ...
    'fit_slope_pred_vs_measured', ...
    'fit_intercept', ...
    'prediction_rmse','prediction_mae', ...
    'sign_agreement'});

end

%% ========================================================================
function S = summarize_contributions(T)

regimes = unique(string(T.regime),'stable');

features = { ...
    'StrongPower','pred_shift_strong_power'; ...
    'NoisePower','pred_shift_noise_power'; ...
    'WeakStrongCross','pred_shift_weak_strong_cross'; ...
    'WeakNoiseCross','pred_shift_weak_noise_cross'; ...
    'StrongNoiseCross','pred_shift_strong_noise_cross'};

subset_names = ["AllCheapFailure","NearShift"];

rows = {};

for ir = 1:numel(regimes)
    r = regimes(ir);
    Tr = T(string(T.regime)==r,:);

    for isub = 1:numel(subset_names)
        sname = subset_names(isub);

        switch sname
            case "AllCheapFailure"
                base = logical(Tr.firstorder_valid);

            case "NearShift"
                base = logical(Tr.firstorder_valid) & ...
                    logical(Tr.nearshift_failure);

            otherwise
                error('Unknown contribution subset.');
        end

        for jf = 1:size(features,1)
            fname = features{jf,1};
            varname = features{jf,2};

            x = double(Tr.(varname));
            x = x(base & isfinite(x));

            rows(end+1,:) = { ... %#ok<AGROW>
                char(r),char(sname),fname, ...
                numel(x), ...
                median(x,'omitnan'), ...
                median(abs(x),'omitnan'), ...
                mean(abs(x),'omitnan')};
        end
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','subset','term','n', ...
    'median_signed_shift', ...
    'median_abs_shift','mean_abs_shift'});

end

%% ========================================================================
function S = summarize_error_coupling(T,cfg)

regimes = unique(string(T.regime),'stable');

subset_names = ["AllCheapFailure","FallbackFailure","NearShift"];

rows = {};

for ir = 1:numel(regimes)
    r = regimes(ir);
    Tr = T(string(T.regime)==r,:);

    for isub = 1:numel(subset_names)
        sname = subset_names(isub);

        switch sname
            case "AllCheapFailure"
                mm = true(height(Tr),1);

            case "FallbackFailure"
                mm = ~logical(Tr.coarse_success);

            case "NearShift"
                mm = logical(Tr.nearshift_failure);

            otherwise
                error('Unknown coupling subset.');
        end

        x = Tr.cheap_q_error(mm);
        y = Tr.coarse_q_error(mm);

        valid = isfinite(x) & isfinite(y);

        x = x(valid);
        y = y(valid);

        n = numel(x);

        if n>=cfg.min_validation_samples
            pearson_r = safe_pearson(x,y);
            spearman_r = safe_spearman(x,y);

            p = polyfit(x,y,1);
            slope = p(1);
            intercept = p(2);

            sign_agree = sign_agreement(x,y);
        else
            pearson_r = NaN;
            spearman_r = NaN;
            slope = NaN;
            intercept = NaN;
            sign_agree = NaN;
        end

        rows(end+1,:) = { ... %#ok<AGROW>
            char(r),char(sname),n, ...
            pearson_r,spearman_r, ...
            slope,intercept,sign_agree};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','subset','n', ...
    'pearson_r','spearman_r', ...
    'fallback_error_vs_cheap_error_slope', ...
    'intercept','error_sign_agreement'});

end

%% ========================================================================
function S = summarize_nearshift_correction(T)

regimes = unique(string(T.regime),'stable');

methods = { ...
    'CoarseTop1','coarse_q_error','coarse_success',[]; ...
    'Parabolic3','parabolic_q_error','parabolic_success','parabolic_offset'; ...
    'LogQuadratic5','logquad_q_error','logquad_success','logquad_offset'; ...
    'LocalCentroid7','centroid_q_error','centroid_success','centroid_offset'};

rows = {};

for ir = 1:numel(regimes)
    r = regimes(ir);
    Tr = T(string(T.regime)==r & T.nearshift_failure,:);

    for im = 1:size(methods,1)
        name = methods{im,1};
        errvar = methods{im,2};
        sucvar = methods{im,3};
        offvar = methods{im,4};

        e = double(Tr.(errvar));
        s = logical(Tr.(sucvar));

        if isempty(offvar)
            corr_dir = NaN;
        else
            offset = double(Tr.(offvar));

            % Correct direction points toward q_weak:
            % sign(offset) should equal -sign(coarse error).
            corr_dir = correction_direction_accuracy( ...
                Tr.coarse_q_error,offset);
        end

        rows(end+1,:) = { ... %#ok<AGROW>
            char(r),name,height(Tr), ...
            mean(double(s)), ...
            mean(abs(e),'omitnan'), ...
            median(abs(e),'omitnan'), ...
            corr_dir};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','method','n_nearshift', ...
    'nearshift_recovery_rate', ...
    'nearshift_mae','nearshift_median_abs_error', ...
    'correction_direction_accuracy'});

end

%% ========================================================================
function D = build_decision_summary( ...
    T,estimator_summary,halfgrid_summary, ...
    firstorder_summary,contrib_summary,coupling_summary)

regimes = unique(string(T.regime),'stable');
rows = {};

for ir = 1:numel(regimes)
    r = char(regimes(ir));

    Tr = T(strcmp(T.regime,r),:);

    coarse_recovery = ...
        get_table_value(estimator_summary,r, ...
        'CoarseTop1','recovery_rate');

    best_local_recovery = -Inf;
    best_local_method = '';

    local_methods = {'Parabolic3','LogQuadratic5','LocalCentroid7'};

    for j = 1:numel(local_methods)
        v = get_table_value(estimator_summary,r, ...
            local_methods{j},'recovery_rate');

        if isfinite(v) && v>best_local_recovery
            best_local_recovery = v;
            best_local_method = local_methods{j};
        end
    end

    mmh = strcmp(halfgrid_summary.regime,r);
    halfgrid_rescue = ...
        halfgrid_summary.fraction_rescued_by_halfgrid(mmh);

    mmf = strcmp(firstorder_summary.regime,r) & ...
          strcmp(firstorder_summary.subset,'NearShift');

    firstorder_r = firstorder_summary.pearson_r(mmf);
    firstorder_sign = firstorder_summary.sign_agreement(mmf);

    mmc = strcmp(coupling_summary.regime,r) & ...
          strcmp(coupling_summary.subset,'NearShift');

    cheap_fb_r = coupling_summary.pearson_r(mmc);
    cheap_fb_sign = coupling_summary.error_sign_agreement(mmc);

    % Dominant first-order contribution in NearShift.
    M = contrib_summary( ...
        strcmp(contrib_summary.regime,r) & ...
        strcmp(contrib_summary.subset,'NearShift'),:);

    [mx,ii] = max(M.median_abs_shift);

    if isempty(ii) || ~isfinite(mx)
        dominant_term = '';
        dominant_abs_shift = NaN;
    else
        dominant_term = M.term{ii};
        dominant_abs_shift = mx;
    end

    near_fraction = mean(double(Tr.nearshift_failure));

    rows(end+1,:) = { ... %#ok<AGROW>
        r,height(Tr),near_fraction, ...
        coarse_recovery,best_local_method,best_local_recovery, ...
        best_local_recovery-coarse_recovery, ...
        halfgrid_rescue, ...
        firstorder_r,firstorder_sign, ...
        cheap_fb_r,cheap_fb_sign, ...
        dominant_term,dominant_abs_shift};
end

D = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','n_cheapfailure','nearshift_fraction', ...
    'coarse_recovery_rate', ...
    'best_local_method','best_local_recovery_rate', ...
    'best_local_gain', ...
    'halfgrid_failure_rescue_fraction', ...
    'nearshift_firstorder_pearson', ...
    'nearshift_firstorder_sign_agreement', ...
    'nearshift_cheap_fallback_error_pearson', ...
    'nearshift_cheap_fallback_sign_agreement', ...
    'dominant_firstorder_term', ...
    'dominant_firstorder_median_abs_shift'});

end

%% ========================================================================
function v = get_table_value(T,regime,method,varname)

mm = strcmp(T.regime,regime) & strcmp(T.method,method);

if sum(mm)~=1
    error('Expected one row for %s / %s.',regime,method);
end

v = T.(varname)(mm);

end

%% ========================================================================
function write_summary( ...
    out_path,cfg, ...
    estimator_summary,halfgrid_summary, ...
    firstorder_summary,contrib_summary, ...
    coupling_summary,nearshift_summary,decision, ...
    time_smooth,time_abrupt)

fid = fopen(fullfile(out_path,'summary.txt'),'w');

fprintf(fid,'EXP009-C3-B3B Near-Shift Mechanism and Local Peak Recovery\n');
fprintf(fid,'==========================================================\n\n');

fprintf(fid,'Research boundary\n');
fprintf(fid,'-----------------\n');
fprintf(fid,'q_strong remains known/oracle.\n');
fprintf(fid,'SNR = %.2f dB.\n',cfg.snr_db);
fprintf(fid,'q_weak = %.6f.\n',cfg.q_weak);
fprintf(fid,'coarse q step = %.6f.\n',cfg.q_search_step);
fprintf(fid,'half-grid q step = %.6f.\n',cfg.q_half_step);
fprintf(fid,'success tau_q = %.6f.\n\n',cfg.tau_q);

fprintf(fid,'Core questions\n');
fprintf(fid,'--------------\n');
fprintf(fid,'1. Does the A4/B1 first-order perturbation law predict matched-response q shift?\n');
fprintf(fid,'2. Is coarse-grid discretization responsible for NearShift failure?\n');
fprintf(fid,'3. Can observable local curve fitting reduce error without q_weak?\n');
fprintf(fid,'4. Are Cheap and fallback q errors coupled?\n\n');

fprintf(fid,'Estimator comparison\n');
fprintf(fid,'--------------------\n');
for i = 1:height(estimator_summary)
    fprintf(fid,[ ...
        '%-7s %-16s recovery=%.6f RMSE=%g MAE=%g medAE=%g\n'], ...
        estimator_summary.regime{i}, ...
        estimator_summary.method{i}, ...
        estimator_summary.recovery_rate(i), ...
        estimator_summary.q_rmse(i), ...
        estimator_summary.q_mae(i), ...
        estimator_summary.q_median_abs_error(i));
end

fprintf(fid,'\nHalf-grid rescue diagnostic\n');
fprintf(fid,'---------------------------\n');
for i = 1:height(halfgrid_summary)
    fprintf(fid,[ ...
        '%s nFail=%d rescued=%.6f coarseMAE=%g halfMAE=%g nearFrac=%.6f\n'], ...
        halfgrid_summary.regime{i}, ...
        halfgrid_summary.n_coarse_fallback_failures(i), ...
        halfgrid_summary.fraction_rescued_by_halfgrid(i), ...
        halfgrid_summary.coarse_failure_mae(i), ...
        halfgrid_summary.halfgrid_mae(i), ...
        halfgrid_summary.nearshift_fraction_among_coarse_failures(i));
end

fprintf(fid,'\nFirst-order validation\n');
fprintf(fid,'----------------------\n');
for i = 1:height(firstorder_summary)
    fprintf(fid,[ ...
        '%s %-16s n=%d Pearson=%.6f Spearman=%.6f slope=%.6f ' ...
        'RMSE=%g signAgree=%.6f\n'], ...
        firstorder_summary.regime{i}, ...
        firstorder_summary.subset{i}, ...
        firstorder_summary.n_valid(i), ...
        firstorder_summary.pearson_r(i), ...
        firstorder_summary.spearman_r(i), ...
        firstorder_summary.fit_slope_pred_vs_measured(i), ...
        firstorder_summary.prediction_rmse(i), ...
        firstorder_summary.sign_agreement(i));
end

fprintf(fid,'\nPerturbation contribution anatomy\n');
fprintf(fid,'-------------------------------\n');
for i = 1:height(contrib_summary)
    fprintf(fid,[ ...
        '%s %-16s %-20s medianAbsShift=%g meanAbsShift=%g\n'], ...
        contrib_summary.regime{i}, ...
        contrib_summary.subset{i}, ...
        contrib_summary.term{i}, ...
        contrib_summary.median_abs_shift(i), ...
        contrib_summary.mean_abs_shift(i));
end

fprintf(fid,'\nCheap/fallback error coupling\n');
fprintf(fid,'-----------------------------\n');
for i = 1:height(coupling_summary)
    fprintf(fid,[ ...
        '%s %-16s n=%d Pearson=%.6f Spearman=%.6f slope=%.6f signAgree=%.6f\n'], ...
        coupling_summary.regime{i}, ...
        coupling_summary.subset{i}, ...
        coupling_summary.n(i), ...
        coupling_summary.pearson_r(i), ...
        coupling_summary.spearman_r(i), ...
        coupling_summary.fallback_error_vs_cheap_error_slope(i), ...
        coupling_summary.error_sign_agreement(i));
end

fprintf(fid,'\nNearShift local correction\n');
fprintf(fid,'--------------------------\n');
for i = 1:height(nearshift_summary)
    fprintf(fid,[ ...
        '%s %-16s n=%d recovery=%.6f MAE=%g directionAcc=%g\n'], ...
        nearshift_summary.regime{i}, ...
        nearshift_summary.method{i}, ...
        nearshift_summary.n_nearshift(i), ...
        nearshift_summary.nearshift_recovery_rate(i), ...
        nearshift_summary.nearshift_mae(i), ...
        nearshift_summary.correction_direction_accuracy(i));
end

fprintf(fid,'\nDecision summary\n');
fprintf(fid,'----------------\n');
for i = 1:height(decision)
    fprintf(fid,[ ...
        '%s nearFrac=%.4f coarseRec=%.4f bestLocal=%s %.4f gain=%+.4f | ' ...
        'halfGridRescue=%.4f | FO-r=%.4f FO-sign=%.4f | ' ...
        'cheapFB-r=%.4f cheapFB-sign=%.4f | dominant=%s (%g)\n'], ...
        decision.regime{i}, ...
        decision.nearshift_fraction(i), ...
        decision.coarse_recovery_rate(i), ...
        decision.best_local_method{i}, ...
        decision.best_local_recovery_rate(i), ...
        decision.best_local_gain(i), ...
        decision.halfgrid_failure_rescue_fraction(i), ...
        decision.nearshift_firstorder_pearson(i), ...
        decision.nearshift_firstorder_sign_agreement(i), ...
        decision.nearshift_cheap_fallback_error_pearson(i), ...
        decision.nearshift_cheap_fallback_sign_agreement(i), ...
        decision.dominant_firstorder_term{i}, ...
        decision.dominant_firstorder_median_abs_shift(i));
end

fprintf(fid,'\nInterpretation logic\n');
fprintf(fid,'--------------------\n');
fprintf(fid,['A. High first-order correlation/sign agreement -> A4/B1 perturbation law ' ...
    'survives in stochastic fallback residuals.\n']);
fprintf(fid,['B. Very low half-grid rescue -> NearShift is NOT mainly grid quantization; ' ...
    'the operational peak itself is physically biased.\n']);
fprintf(fid,['C. Large Parabolic/LogQuadratic/Centroid gain -> cheap local curve geometry ' ...
    'contains corrective information and can support a simple method.\n']);
fprintf(fid,['D. Little local-estimator gain but strong first-order law -> the shift is ' ...
    'mechanistically understandable but not recoverable from top-peak geometry alone; ' ...
    'next use extra evidence such as history/subaperture/multi-look.\n']);
fprintf(fid,['E. Strong Cheap-vs-fallback error coupling -> both branches share a perturbation ' ...
    'source; next test should convert that oracle error relation into an observable ' ...
    'history/prior-assisted correction.\n']);
fprintf(fid,['F. Weak first-order validation -> revisit the matched-response model and the ' ...
    'operational max-over-frequency nonlinearity before proposing an algorithm.\n']);

fprintf(fid,'\nRuntime\n');
fprintf(fid,'-------\n');
fprintf(fid,'Smooth %.3f s\n',time_smooth);
fprintf(fid,'Abrupt %.3f s\n',time_abrupt);

fclose(fid);

end

%% ========================================================================
function make_figures( ...
    out_path,cfg,T_smooth,T_abrupt, ...
    estimator_summary,halfgrid_summary, ...
    firstorder_summary,contrib_summary, ...
    coupling_summary,nearshift_summary)

%% Fig 1: first-order measured vs predicted
fig = figure('Visible',cfg.figure_visible);
hold on;

plot_firstorder_scatter(T_smooth,'o');
plot_firstorder_scatter(T_abrupt,'x');

lim = cfg.q_diag_halfwidth;
plot([-lim lim],[-lim lim],'--');

xlabel('Measured matched-response q shift');
ylabel('First-order predicted q shift');
title('C3-B3B First-Order Near-Shift Validation');
legend({'Smooth','Abrupt','y=x'},'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig01_firstorder_measured_vs_predicted.png'), ...
    'Resolution',180);
close(fig);

%% Fig 2: perturbation contributions in NearShift
terms = unique(string(contrib_summary.term),'stable');
regimes = ["Smooth","Abrupt"];

Y = nan(numel(terms),2);

for jt = 1:numel(terms)
    for ir = 1:2
        mm = strcmp(contrib_summary.term,char(terms(jt))) & ...
             strcmp(contrib_summary.regime,char(regimes(ir))) & ...
             strcmp(contrib_summary.subset,'NearShift');

        Y(jt,ir) = contrib_summary.median_abs_shift(mm);
    end
end

fig = figure('Visible',cfg.figure_visible);
bar(Y);
xticks(1:numel(terms));
xticklabels(terms);
xtickangle(25);
ylabel('Median |predicted q-shift contribution|');
title('C3-B3B NearShift Perturbation-Slope Anatomy');
legend(regimes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig02_nearshift_perturbation_contributions.png'), ...
    'Resolution',180);
close(fig);

%% Fig 3: practical estimator recovery
methods = unique(string(estimator_summary.method),'stable');

Y = nan(numel(methods),2);

for jm = 1:numel(methods)
    for ir = 1:2
        mm = strcmp(estimator_summary.method,char(methods(jm))) & ...
             strcmp(estimator_summary.regime,char(regimes(ir)));

        Y(jm,ir) = estimator_summary.recovery_rate(mm);
    end
end

fig = figure('Visible',cfg.figure_visible);
bar(Y);
ylim([0 1]);
xticks(1:numel(methods));
xticklabels(methods);
xtickangle(25);
ylabel('Weak-q recovery rate');
title('C3-B3B Practical Local Estimator Comparison');
legend(regimes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig03_practical_local_estimators.png'), ...
    'Resolution',180);
close(fig);

%% Fig 4: half-grid rescue
fig = figure('Visible',cfg.figure_visible);
bar(halfgrid_summary.fraction_rescued_by_halfgrid);
ylim([0 1]);
xticks(1:height(halfgrid_summary));
xticklabels(string(halfgrid_summary.regime));
ylabel('Fraction of coarse failures rescued');
title('C3-B3B Does 2x Denser q Grid Rescue NearShift?');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig04_halfgrid_failure_rescue.png'), ...
    'Resolution',180);
close(fig);

%% Fig 5: NearShift error distributions
plot_nearshift_error_box(T_smooth,"Smooth",cfg, ...
    fullfile(out_path,'fig05_smooth_nearshift_error_estimators.png'));

plot_nearshift_error_box(T_abrupt,"Abrupt",cfg, ...
    fullfile(out_path,'fig06_abrupt_nearshift_error_estimators.png'));

%% Fig 7: Cheap vs fallback error
fig = figure('Visible',cfg.figure_visible);
hold on;

scatter( ...
    T_smooth.cheap_q_error, ...
    T_smooth.coarse_q_error, ...
    10,'filled');

scatter( ...
    T_abrupt.cheap_q_error, ...
    T_abrupt.coarse_q_error, ...
    10,'filled');

xline(0,'--');
yline(0,'--');

xlabel('Cheap q error');
ylabel('Fallback coarse q error');
title('C3-B3B Cheap/Fallback Error Coupling');
legend({'Smooth','Abrupt'},'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig07_cheap_fallback_error_coupling.png'), ...
    'Resolution',180);
close(fig);

%% Fig 8: local correction direction
methods2 = ["Parabolic3","LogQuadratic5","LocalCentroid7"];
Y = nan(numel(methods2),2);

for jm = 1:numel(methods2)
    for ir = 1:2
        mm = strcmp(nearshift_summary.method,char(methods2(jm))) & ...
             strcmp(nearshift_summary.regime,char(regimes(ir)));

        Y(jm,ir) = ...
            nearshift_summary.correction_direction_accuracy(mm);
    end
end

fig = figure('Visible',cfg.figure_visible);
bar(Y);
yline(0.5,'--');
ylim([0 1]);
xticks(1:numel(methods2));
xticklabels(methods2);
xtickangle(20);
ylabel('Correct direction fraction');
title('C3-B3B Can Local Curve Geometry Point Back Toward q_w?');
legend(regimes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig08_local_correction_direction.png'), ...
    'Resolution',180);
close(fig);

end

%% ========================================================================
function plot_firstorder_scatter(T,marker)

mm = logical(T.firstorder_valid) & ...
     logical(T.nearshift_failure);

x = T.matched_shift_measured(mm);
y = T.matched_shift_predicted(mm);

plot(x,y,marker,'LineStyle','none');

end

%% ========================================================================
function plot_nearshift_error_box(T,regime,cfg,filename)
% MATLAB compatibility note:
% Never combine numeric xticks(...) with a categorical axis produced by
% boxchart. This function builds an explicit categorical grouping variable.

mm = logical(T.nearshift_failure);
Tr = T(mm,:);

X = [ ...
    Tr.coarse_q_error, ...
    Tr.parabolic_q_error, ...
    Tr.logquad_q_error, ...
    Tr.centroid_q_error];

fig = figure('Visible',cfg.figure_visible);

% Robust categorical grouping for boxchart.
% Some MATLAB releases create a categorical x-axis for boxchart(X).
% Numeric xticks(1:4) is then invalid. We explicitly construct the
% categorical grouping variable and leave category ticks under boxchart
% control.
labels = { ...
    'CoarseTop1', ...
    'Parabolic3', ...
    'LogQuadratic5', ...
    'LocalCentroid7'};

n_rows = size(X,1);
values = X(:);

% X(:) is column-major:
% all CoarseTop1 values, then Parabolic3, then LogQuadratic5,
% then LocalCentroid7.
group_index = repelem((1:4).',n_rows,1);

group_cat = categorical( ...
    group_index, ...
    1:4, ...
    labels);

valid = isfinite(values);

boxchart(group_cat(valid),values(valid));

yline(0,'--');
yline(cfg.tau_q,':');
yline(-cfg.tau_q,':');

xtickangle(20);

ylabel('q estimate - q_w');
title(sprintf( ...
    'C3-B3B %s NearShift Error After Local Estimation', ...
    char(regime)));

grid on;

exportgraphics(fig,filename,'Resolution',180);
close(fig);

end

%% ========================================================================
function D = build_dechirp_dictionary(q_grid,t,cfg)

q_grid = q_grid(:);
t = t(:).';

mu = cfg.mu_scale*(q_grid-cfg.q_ref);

D = exp(-1j*pi*bsxfun(@times,mu,t.^2));

end

%% ========================================================================
function D = build_matched_dictionary(q_grid,t,f0,cfg)

q_grid = q_grid(:);
t = t(:).';

mu = cfg.mu_scale*(q_grid-cfg.q_ref);

phase_q = pi*bsxfun(@times,mu,t.^2);
phase_f = 2*pi*f0*t;

D = exp(-1j*bsxfun(@plus,phase_q,phase_f));

end

%% ========================================================================
function qhat = search_q_hat_batch(X,q_grid,D,block_lines)

X = double_complex_guard(X,'X');

[L,N] = size(X);
[Q,ND] = size(D);

if ND~=N
    error(['search_q_hat_batch dimension mismatch: ' ...
        'D has %d columns but X has %d samples.'],ND,N);
end

q_grid = q_grid(:);

if numel(q_grid)~=Q
    error('q_grid length does not match dictionary rows.');
end

qhat = nan(L,1);

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

    [~,ii] = max(M,[],1);

    qb = q_grid(ii(:));
    qhat(idx) = qb(:);
end

qhat = qhat(:);

end

%% ========================================================================
function [qhat,Mall] = search_q_curve_batch( ...
    X,q_grid,D,block_lines)

X = double_complex_guard(X,'X');

[L,N] = size(X);
[Q,ND] = size(D);

if ND~=N
    error(['search_q_curve_batch dimension mismatch: ' ...
        'D has %d columns but X has %d samples.'],ND,N);
end

q_grid = q_grid(:);

if numel(q_grid)~=Q
    error('q_grid length does not match dictionary rows.');
end

qhat = nan(L,1);
Mall = nan(Q,L);

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

    Mall(:,idx) = M;

    [~,ii] = max(M,[],1);

    qb = q_grid(ii(:));
    qhat(idx) = qb(:);
end

qhat = qhat(:);

end

%% ========================================================================
function [R,Es,Ew,En] = refit_and_decompose_batch( ...
    Xmix,Sstrong,Sweak,noise,q_strong,t,cfg)

Xmix = double_complex_guard(Xmix,'Xmix');
Sstrong = double_complex_guard(Sstrong,'Sstrong');
Sweak = double_complex_guard(Sweak,'Sweak');
noise = double_complex_guard(noise,'noise');

if ~isequal(size(Xmix),size(Sstrong),size(Sweak),size(noise))
    error('Refit decomposition inputs must have identical matrix size.');
end

[L,N] = size(Xmix);

t = t(:).';
q_strong = q_strong(:);

if numel(q_strong)~=L
    error('q_strong must have one scalar per signal row.');
end

mu = cfg.mu_scale*(q_strong-cfg.q_ref);

dechirp_phase = -1j*pi*bsxfun(@times,mu,t.^2);
D = exp(dechirp_phase);

Z = fft(Xmix.*D,cfg.refit_nfft_factor*N,2);
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
delta(valid) = 0.5*(ym(valid)-yp(valid))./den(valid);
delta = min(max(delta,-1),1);

bin0 = k0-1;
wrap = bin0>nfft/2;
bin0(wrap) = bin0(wrap)-nfft;

fhat = (bin0+delta)*(N/nfft);
fhat = fhat(:);

phase_q = bsxfun(@times,pi*mu,t.^2);
phase_f = bsxfun(@times,2*pi*fhat,t);

atom = exp(1j*(phase_q+phase_f));

den_a = sum(abs(atom).^2,2);
den_a = max(den_a,eps);

alpha_s = sum(conj(atom).*Sstrong,2)./den_a;
alpha_w = sum(conj(atom).*Sweak,2)./den_a;
alpha_n = sum(conj(atom).*noise,2)./den_a;

Es = Sstrong - bsxfun(@times,alpha_s,atom);
Ew = Sweak - bsxfun(@times,alpha_w,atom);
En = noise - bsxfun(@times,alpha_n,atom);

R = Es + Ew + En;

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
    error('get_strong_notch_bin must return one scalar.');
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
function r = safe_pearson(x,y)

x = double(x(:));
y = double(y(:));

valid = isfinite(x) & isfinite(y);

x = x(valid);
y = y(valid);

if numel(x)<3 || std(x)<eps || std(y)<eps
    r = NaN;
    return;
end

C = corrcoef(x,y);
r = C(1,2);

end

%% ========================================================================
function r = safe_spearman(x,y)

x = double(x(:));
y = double(y(:));

valid = isfinite(x) & isfinite(y);

x = x(valid);
y = y(valid);

if numel(x)<3
    r = NaN;
    return;
end

rx = average_ranks(x);
ry = average_ranks(y);

r = safe_pearson(rx,ry);

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
function a = sign_agreement(x,y)

x = double(x(:));
y = double(y(:));

valid = ...
    isfinite(x) & isfinite(y) & ...
    abs(x)>eps & abs(y)>eps;

if ~any(valid)
    a = NaN;
    return;
end

a = mean(sign(x(valid))==sign(y(valid)));

end

%% ========================================================================
function a = correction_direction_accuracy(coarse_error,offset)

e = double(coarse_error(:));
o = double(offset(:));

valid = ...
    isfinite(e) & isfinite(o) & ...
    abs(e)>eps & abs(o)>eps;

if ~any(valid)
    a = NaN;
    return;
end

desired = -sign(e(valid));
actual = sign(o(valid));

a = mean(desired==actual);

end
