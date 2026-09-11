function results = exp09c3b3a_rescueability_failure_mode_decomposition()
%EXP09C3B3A_RESCUEABILITY_FAILURE_MODE_DECOMPOSITION
% EXP009 / Pilot-01 / C3-B3A
%
% Rescueability Failure-Mode Decomposition
%
% -------------------------------------------------------------------------
% Motivation from C3-B2
% -------------------------------------------------------------------------
% C3-B2 found:
%   - CheapFailure: moderate within-line observability;
%   - Rescueability: near-random within-line observability.
%
% Therefore C3-B3A does NOT build a larger classifier. It directly audits
% the fallback signal-processing chain.
%
% -------------------------------------------------------------------------
% Exact controlled fallback chain
% -------------------------------------------------------------------------
% Original mixture:
%   strong + weak + noise
%
%       -> known-q_strong off-grid parametric refit
%       -> residual
%       -> full weak-q concentration curve
%       -> global q winner
%
% FallbackSuccess is exactly:
%
%   |q_hat_fallback - q_weak| <= tau_q
%
% There is no later downstream success stage in this controlled C3 chain.
% Thus C3-B3A asks why the GLOBAL q winner leaves the true weak-q basin.
%
% -------------------------------------------------------------------------
% Failure-mode taxonomy among CheapFailure trials
% -------------------------------------------------------------------------
% Success:
%   fallback q winner lies inside the true weak-q success basin.
%
% NearShift:
%   global winner misses tau_q but remains near q_weak.
%
% PeakCompetition:
%   a real local maximum still exists inside the true weak-q basin,
%   but another peak wins globally.
%
% BasinCollapse:
%   no local maximum survives inside the true weak-q basin.
%
% BoundaryFalsePeak:
%   a failed winner occurs at the q-search boundary.
%
% -------------------------------------------------------------------------
% Residual decomposition
% -------------------------------------------------------------------------
% The fallback refit estimates ONE atom from the noisy mixture. Holding
% that fitted atom fixed, the same projection operator is applied to:
%
%   strong, weak, noise
%
% yielding an exact additive residual decomposition:
%
%   r = e_s + e_w + e_n
%
% This lets us test whether rescue failure is associated with:
%   - strong residual leakage;
%   - weak-component attenuation by the refit;
%   - residual noise;
%   - coherent strong/weak or noise/weak cross terms.
%
% Run:
%   results = exp09c3b3a_rescueability_failure_mode_decomposition;

cfg = config_exp09c3b3a();

%% Resolve output path
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.output_dir)
    out_dir = fullfile( ...
        paper_root,'results','exp09_pilot01', ...
        'exp09c3b3a_rescueability_failure_mode_decomposition');
else
    out_dir = cfg.output_dir;
end

if ~exist(out_dir,'dir')
    mkdir(out_dir);
end

fprintf('\n============================================================\n');
fprintf(' EXP009-C3-B3A / Rescueability Failure-Mode Decomposition\n');
fprintf('============================================================\n');
fprintf('Output         : %s\n',out_dir);
fprintf('MC / regime    : %d\n',cfg.num_mc);
fprintf('Lines / MC     : %d\n',cfg.num_lines);
fprintf('SNR            : %.1f dB\n',cfg.snr_db);
fprintf('q success tol  : %.4f\n\n',cfg.tau_q);

%% Common setup
N = cfg.N;
n = 0:N-1;
t = (n-N/2)/N;

q_grid = ( ...
    cfg.q_search_min: ...
    cfg.q_search_step: ...
    cfg.q_search_max).';

D_search = build_dechirp_dictionary(q_grid,t,cfg);

%% Physical trajectories
traj_smooth = build_trajectory("Smooth",cfg);
traj_abrupt = build_trajectory("Abrupt",cfg);

writetable(traj_smooth, ...
    fullfile(out_dir,'trajectory_smooth.csv'));

writetable(traj_abrupt, ...
    fullfile(out_dir,'trajectory_abrupt.csv'));

%% Deterministic signal components
det_smooth = precompute_deterministic_components( ...
    traj_smooth,t,cfg);

det_abrupt = precompute_deterministic_components( ...
    traj_abrupt,t,cfg);

%% Generate diagnostic banks
fprintf('Generating Smooth diagnostic bank...\n');
tic;
[diag_smooth,curves_smooth] = run_regime_bank( ...
    "Smooth",det_smooth,traj_smooth, ...
    cfg.num_mc,cfg.seed+3300, ...
    q_grid,D_search,t,cfg);
time_smooth = toc;

fprintf('Generating Abrupt diagnostic bank...\n');
tic;
[diag_abrupt,curves_abrupt] = run_regime_bank( ...
    "Abrupt",det_abrupt,traj_abrupt, ...
    cfg.num_mc,cfg.seed+4300, ...
    q_grid,D_search,t,cfg);
time_abrupt = toc;

fprintf('Smooth runtime: %.2f s\n',time_smooth);
fprintf('Abrupt runtime: %.2f s\n\n',time_abrupt);

%% Save trial-level diagnostics
writetable(diag_smooth, ...
    fullfile(out_dir,'cheap_failure_diagnostics_smooth.csv'));

writetable(diag_abrupt, ...
    fullfile(out_dir,'cheap_failure_diagnostics_abrupt.csv'));

diag_all = [diag_smooth;diag_abrupt];

writetable(diag_all, ...
    fullfile(out_dir,'cheap_failure_diagnostics_all.csv'));

%% ------------------------------------------------------------------------
% A) Failure-mode composition
mode_summary = summarize_failure_modes(diag_all);

writetable(mode_summary, ...
    fullfile(out_dir,'failure_mode_summary.csv'));

%% ------------------------------------------------------------------------
% B) Success vs failure mechanism audit
mechanism_audit = build_mechanism_audit(diag_all);

writetable(mechanism_audit, ...
    fullfile(out_dir,'rescueability_mechanism_audit.csv'));

%% ------------------------------------------------------------------------
% C) Residual-anatomy audit by failure mode
residual_by_mode = summarize_residual_by_mode(diag_all);

writetable(residual_by_mode, ...
    fullfile(out_dir,'residual_anatomy_by_failure_mode.csv'));

%% ------------------------------------------------------------------------
% D) True-basin local-peak rank audit
rank_summary = summarize_true_peak_rank(diag_all);

writetable(rank_summary, ...
    fullfile(out_dir,'true_basin_peak_rank_summary.csv'));

%% ------------------------------------------------------------------------
% E) State failure maps
map_smooth = build_state_failure_map(diag_smooth,cfg);
map_abrupt = build_state_failure_map(diag_abrupt,cfg);

writetable(map_smooth, ...
    fullfile(out_dir,'state_failure_map_smooth.csv'));

writetable(map_abrupt, ...
    fullfile(out_dir,'state_failure_map_abrupt.csv'));

%% ------------------------------------------------------------------------
% F) Line-level rescueability
line_smooth = summarize_line_rescueability(diag_smooth,traj_smooth);
line_abrupt = summarize_line_rescueability(diag_abrupt,traj_abrupt);

writetable(line_smooth, ...
    fullfile(out_dir,'line_rescueability_smooth.csv'));

writetable(line_abrupt, ...
    fullfile(out_dir,'line_rescueability_abrupt.csv'));

%% ------------------------------------------------------------------------
% G) Representative curves
rep_smooth = select_representative_curves( ...
    diag_smooth,curves_smooth,q_grid,cfg);

rep_abrupt = select_representative_curves( ...
    diag_abrupt,curves_abrupt,q_grid,cfg);

write_representative_curve_csv( ...
    rep_smooth,q_grid, ...
    fullfile(out_dir,'representative_curves_smooth.csv'));

write_representative_curve_csv( ...
    rep_abrupt,q_grid, ...
    fullfile(out_dir,'representative_curves_abrupt.csv'));

%% ------------------------------------------------------------------------
% H) Compact decision summary
decision = build_decision_summary( ...
    diag_all,mechanism_audit,mode_summary,residual_by_mode);

writetable(decision, ...
    fullfile(out_dir,'decision_summary.csv'));

%% Runtime summary
runtime_summary = table( ...
    ["Smooth";"Abrupt"], ...
    [time_smooth;time_abrupt], ...
    'VariableNames',{'regime','runtime_seconds'});

writetable(runtime_summary, ...
    fullfile(out_dir,'runtime_summary.csv'));

%% Console summary
fprintf('\n================ FAILURE MODES ===============================\n');
disp(mode_summary);

fprintf('\n================ MECHANISM AUDIT =============================\n');
disp(mechanism_audit);

fprintf('\n================ TRUE-BASIN RANK =============================\n');
disp(rank_summary);

fprintf('\n================ DECISION ====================================\n');
disp(decision);
fprintf('=============================================================\n');

%% Text summary
write_summary( ...
    out_dir,cfg, ...
    mode_summary,mechanism_audit, ...
    residual_by_mode,rank_summary,decision, ...
    time_smooth,time_abrupt);

%% Figures
make_figures( ...
    out_dir,cfg, ...
    diag_smooth,diag_abrupt, ...
    mode_summary,mechanism_audit, ...
    residual_by_mode,rank_summary, ...
    map_smooth,map_abrupt, ...
    line_smooth,line_abrupt, ...
    rep_smooth,rep_abrupt,q_grid);

%% Save MAT
results = struct();
results.cfg = cfg;
results.mode_summary = mode_summary;
results.mechanism_audit = mechanism_audit;
results.residual_by_mode = residual_by_mode;
results.rank_summary = rank_summary;
results.map_smooth = map_smooth;
results.map_abrupt = map_abrupt;
results.line_smooth = line_smooth;
results.line_abrupt = line_abrupt;
results.decision = decision;
results.runtime_summary = runtime_summary;

save(fullfile(out_dir,'exp09c3b3a_results.mat'), ...
    'results','-v7.3');

fprintf('\nSaved C3-B3A outputs to:\n%s\n\n',out_dir);

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
function [Tdiag,curve_bank] = run_regime_bank( ...
    regime,det,traj,num_mc,seed, ...
    q_grid,D_search,t,cfg)

rng(seed,'twister');

L = height(traj);
N = cfg.N;
Q = numel(q_grid);

% Strong-referenced SNR convention from C3-B1.
s_ref = synth_lfm( ...
    cfg.A_strong,cfg.q_weak-0.05, ...
    cfg.f_strong,cfg.phi_strong,t,cfg);

Pstrong = mean(abs(s_ref).^2);
noise_var = Pstrong/(10^(cfg.snr_db/10));

% Preallocate to maximum possible CheapFailure count, then trim.
max_rows = L*num_mc;

sequence_id = zeros(max_rows,1);
line_index = zeros(max_rows,1);

weak_ratio = nan(max_rows,1);
signed_sep = nan(max_rows,1);
q_strong = nan(max_rows,1);

cheap_q_hat = nan(max_rows,1);
cheap_q_error = nan(max_rows,1);

fallback_q_hat = nan(max_rows,1);
fallback_q_error = nan(max_rows,1);
fallback_success = false(max_rows,1);

failure_class = strings(max_rows,1);

true_basin_score = nan(max_rows,1);
global_score = nan(max_rows,1);
true_to_global_ratio = nan(max_rows,1);
global_minus_true_fraction = nan(max_rows,1);

true_basin_q = nan(max_rows,1);
true_basin_localmax = false(max_rows,1);
true_peak_rank = nan(max_rows,1);

competitor_q = nan(max_rows,1);
competitor_distance = nan(max_rows,1);

curve_entropy = nan(max_rows,1);
global_prominence = nan(max_rows,1);
true_curvature_norm = nan(max_rows,1);
num_local_peaks = nan(max_rows,1);

strong_residual_retention = nan(max_rows,1);
weak_retention = nan(max_rows,1);
noise_retention = nan(max_rows,1);

residual_strong_to_weak = nan(max_rows,1);
residual_noise_to_weak = nan(max_rows,1);

cross_sw_norm = nan(max_rows,1);
cross_wn_norm = nan(max_rows,1);

total_residual_to_weak = nan(max_rows,1);

refit_fhat = nan(max_rows,1);
projection_consistency_error = nan(max_rows,1);

% Curves are stored only for CheapFailure trials.
curve_bank = nan(Q,max_rows);

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

    %% Fallback branch + exact residual decomposition
    Xmix = det.Sstrong + det.Sweak + noise;

    [R,Es,Ew,En,fhat,consistency] = ...
        refit_and_decompose_batch( ...
            Xmix,det.Sstrong,det.Sweak,noise, ...
            traj.q_strong,t,cfg);

    [qhf,M] = search_q_curve_batch( ...
        R,q_grid,D_search, ...
        cfg.q_search_block_lines);

    %% Only retain CheapFailure trials
    idx_fail = find(cheap_failure_all);

    for jj = 1:numel(idx_fail)

        k = idx_fail(jj);
        row0 = row0+1;

        m = M(:,k);

        curve_diag = analyze_fallback_curve( ...
            m,q_grid,cfg.q_weak,cfg);

        sequence_id(row0) = imc;
        line_index(row0) = traj.line_index(k);

        weak_ratio(row0) = traj.weak_ratio(k);
        signed_sep(row0) = traj.signed_sep(k);
        q_strong(row0) = traj.q_strong(k);

        cheap_q_hat(row0) = qhc(k);
        cheap_q_error(row0) = ...
            qhc(k)-cfg.q_weak;

        fallback_q_hat(row0) = qhf(k);
        fallback_q_error(row0) = ...
            qhf(k)-cfg.q_weak;

        fallback_success(row0) = ...
            abs(fallback_q_error(row0)) <= ...
            (cfg.tau_q+cfg.success_tol);

        failure_class(row0) = classify_failure_mode( ...
            fallback_success(row0), ...
            fallback_q_hat(row0), ...
            curve_diag.true_basin_localmax, ...
            cfg);

        true_basin_score(row0) = ...
            curve_diag.true_basin_score;

        global_score(row0) = ...
            curve_diag.global_score;

        true_to_global_ratio(row0) = ...
            curve_diag.true_to_global_ratio;

        global_minus_true_fraction(row0) = ...
            curve_diag.global_minus_true_fraction;

        true_basin_q(row0) = ...
            curve_diag.true_basin_q;

        true_basin_localmax(row0) = ...
            curve_diag.true_basin_localmax;

        true_peak_rank(row0) = ...
            curve_diag.true_peak_rank;

        competitor_q(row0) = ...
            curve_diag.competitor_q;

        competitor_distance(row0) = ...
            curve_diag.competitor_distance;

        curve_entropy(row0) = ...
            curve_diag.curve_entropy;

        global_prominence(row0) = ...
            curve_diag.global_prominence;

        true_curvature_norm(row0) = ...
            curve_diag.true_curvature_norm;

        num_local_peaks(row0) = ...
            curve_diag.num_local_peaks;

        % Residual energy geometry.
        Es_k = Es(k,:);
        Ew_k = Ew(k,:);
        En_k = En(k,:);
        R_k = R(k,:);

        Ss_k = det.Sstrong(k,:);
        Sw_k = det.Sweak(k,:);
        N_k = noise(k,:);

        E_s = sum(abs(Es_k).^2);
        E_w = sum(abs(Ew_k).^2);
        E_n = sum(abs(En_k).^2);

        E_Ss = max(sum(abs(Ss_k).^2),eps);
        E_Sw = max(sum(abs(Sw_k).^2),eps);
        E_N = max(sum(abs(N_k).^2),eps);

        strong_residual_retention(row0) = E_s/E_Ss;
        weak_retention(row0) = E_w/E_Sw;
        noise_retention(row0) = E_n/E_N;

        residual_strong_to_weak(row0) = ...
            E_s/max(E_w,eps);

        residual_noise_to_weak(row0) = ...
            E_n/max(E_w,eps);

        cross_sw_norm(row0) = ...
            2*real(sum(conj(Ew_k).*Es_k)) / ...
            max(E_w,eps);

        cross_wn_norm(row0) = ...
            2*real(sum(conj(Ew_k).*En_k)) / ...
            max(E_w,eps);

        total_residual_to_weak(row0) = ...
            sum(abs(R_k).^2)/E_Sw;

        refit_fhat(row0) = fhat(k);
        projection_consistency_error(row0) = ...
            consistency(k);

        curve_bank(:,row0) = m(:);
    end
end

% Trim all outputs.
keep = 1:row0;

sequence_id = sequence_id(keep);
line_index = line_index(keep);

weak_ratio = weak_ratio(keep);
signed_sep = signed_sep(keep);
q_strong = q_strong(keep);

cheap_q_hat = cheap_q_hat(keep);
cheap_q_error = cheap_q_error(keep);

fallback_q_hat = fallback_q_hat(keep);
fallback_q_error = fallback_q_error(keep);
fallback_success = fallback_success(keep);

failure_class = failure_class(keep);

true_basin_score = true_basin_score(keep);
global_score = global_score(keep);
true_to_global_ratio = true_to_global_ratio(keep);
global_minus_true_fraction = ...
    global_minus_true_fraction(keep);

true_basin_q = true_basin_q(keep);
true_basin_localmax = true_basin_localmax(keep);
true_peak_rank = true_peak_rank(keep);

competitor_q = competitor_q(keep);
competitor_distance = competitor_distance(keep);

curve_entropy = curve_entropy(keep);
global_prominence = global_prominence(keep);
true_curvature_norm = true_curvature_norm(keep);
num_local_peaks = num_local_peaks(keep);

strong_residual_retention = ...
    strong_residual_retention(keep);

weak_retention = weak_retention(keep);
noise_retention = noise_retention(keep);

residual_strong_to_weak = ...
    residual_strong_to_weak(keep);

residual_noise_to_weak = ...
    residual_noise_to_weak(keep);

cross_sw_norm = cross_sw_norm(keep);
cross_wn_norm = cross_wn_norm(keep);

total_residual_to_weak = ...
    total_residual_to_weak(keep);

refit_fhat = refit_fhat(keep);

projection_consistency_error = ...
    projection_consistency_error(keep);

curve_bank = curve_bank(:,keep);

regime_col = repmat(string(regime),row0,1);

Tdiag = table( ...
    regime_col,sequence_id,line_index, ...
    weak_ratio,signed_sep,q_strong, ...
    cheap_q_hat,cheap_q_error, ...
    fallback_q_hat,fallback_q_error, ...
    fallback_success,failure_class, ...
    true_basin_score,global_score, ...
    true_to_global_ratio,global_minus_true_fraction, ...
    true_basin_q,true_basin_localmax,true_peak_rank, ...
    competitor_q,competitor_distance, ...
    curve_entropy,global_prominence, ...
    true_curvature_norm,num_local_peaks, ...
    strong_residual_retention, ...
    weak_retention,noise_retention, ...
    residual_strong_to_weak, ...
    residual_noise_to_weak, ...
    cross_sw_norm,cross_wn_norm, ...
    total_residual_to_weak, ...
    refit_fhat,projection_consistency_error, ...
    'VariableNames',{ ...
    'regime','sequence_id','line_index', ...
    'weak_ratio','signed_sep','q_strong', ...
    'cheap_q_hat','cheap_q_error', ...
    'fallback_q_hat','fallback_q_error', ...
    'fallback_success','failure_class', ...
    'true_basin_score','global_score', ...
    'true_to_global_ratio','global_minus_true_fraction', ...
    'true_basin_q','true_basin_localmax','true_peak_rank', ...
    'competitor_q','competitor_distance', ...
    'curve_entropy','global_prominence', ...
    'true_curvature_norm','num_local_peaks', ...
    'strong_residual_retention', ...
    'weak_retention','noise_retention', ...
    'residual_strong_to_weak', ...
    'residual_noise_to_weak', ...
    'cross_sw_norm','cross_wn_norm', ...
    'total_residual_to_weak', ...
    'refit_fhat','projection_consistency_error'});

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
function [qhat,Mall] = search_q_curve_batch(X,q_grid,D,block_lines)

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
function [R,Es,Ew,En,fhat,consistency] = ...
    refit_and_decompose_batch( ...
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

alpha_total = sum(conj(atom).*Xmix,2)./den_a;
R_direct = Xmix - bsxfun(@times,alpha_total,atom);

num = sqrt(sum(abs(R-R_direct).^2,2));
denr = sqrt(sum(abs(R_direct).^2,2));
consistency = num./max(denr,eps);

if any(~isfinite(consistency))
    error('Non-finite projection consistency diagnostic.');
end

end

%% ========================================================================
function D = analyze_fallback_curve(m,q_grid,q_weak,cfg)

m = double(m(:));
q_grid = double(q_grid(:));

if numel(m)~=numel(q_grid)
    error('Curve/q-grid length mismatch.');
end

if any(~isfinite(m))
    error('Fallback curve contains non-finite values.');
end

Q = numel(m);

[global_score,ig] = max(m);
global_score = max(global_score,eps);

qhat = q_grid(ig);

true_mask = ...
    abs(q_grid-q_weak) <= ...
    (cfg.tau_q+cfg.success_tol);

idx_true = find(true_mask);

if isempty(idx_true)
    error('True weak-q basin does not overlap search grid.');
end

[true_basin_score,iloc] = max(m(idx_true));
itrue = idx_true(iloc);
true_basin_q = q_grid(itrue);

is_local = false(Q,1);

if Q>=3
    is_local(2:Q-1) = ...
        (m(2:Q-1)>=m(1:Q-2)) & ...
        (m(2:Q-1)>=m(3:Q));
end

local_idx = find(is_local);
num_local_peaks = numel(local_idx);

true_local_idx = local_idx(true_mask(local_idx));

true_basin_localmax = ~isempty(true_local_idx);

true_peak_rank = NaN;

if true_basin_localmax
    [~,jj] = max(m(true_local_idx));
    itrue_local = true_local_idx(jj);

    [~,ord] = sort(m(local_idx),'descend');

    ranked_idx = local_idx(ord);
    rank_pos = find(ranked_idx==itrue_local,1);

    if isempty(rank_pos)
        error('Internal rank assignment failed.');
    end

    true_peak_rank = rank_pos;
end

% Best competitor outside the true success basin.
outside = ~true_mask;
idx_out = find(outside);

if isempty(idx_out)
    competitor_q = NaN;
    competitor_distance = NaN;
else
    [~,jo] = max(m(idx_out));
    icomp = idx_out(jo);

    competitor_q = q_grid(icomp);
    competitor_distance = ...
        abs(competitor_q-q_weak);
end

% Normalized entropy.
pp = m/max(sum(m),eps);
pp = max(pp,realmin);

curve_entropy = ...
    -sum(pp.*log(pp))/log(Q);

% Global prominence relative to median floor.
med_floor = median(m);

global_prominence = ...
    (global_score-med_floor)/global_score;

% Local curvature at best true-basin q-grid sample.
if itrue>1 && itrue<Q
    true_curvature_norm = ...
        (2*m(itrue)-m(itrue-1)-m(itrue+1)) / ...
        max(m(itrue),eps);
else
    true_curvature_norm = NaN;
end

D = struct();

D.global_score = global_score;
D.qhat = qhat;

D.true_basin_score = true_basin_score;
D.true_basin_q = true_basin_q;
D.true_basin_localmax = true_basin_localmax;
D.true_peak_rank = true_peak_rank;

D.true_to_global_ratio = ...
    true_basin_score/global_score;

D.global_minus_true_fraction = ...
    (global_score-true_basin_score)/global_score;

D.competitor_q = competitor_q;
D.competitor_distance = competitor_distance;

D.curve_entropy = curve_entropy;
D.global_prominence = global_prominence;
D.true_curvature_norm = true_curvature_norm;
D.num_local_peaks = num_local_peaks;

end

%% ========================================================================
function cls = classify_failure_mode( ...
    success,qhat,true_basin_localmax,cfg)

if success
    cls = "Success";
    return;
end

qerr = abs(qhat-cfg.q_weak);

if qerr <= cfg.near_shift_tol
    cls = "NearShift";
    return;
end

near_boundary = ...
    (qhat-cfg.q_search_min <= cfg.boundary_margin_q) || ...
    (cfg.q_search_max-qhat <= cfg.boundary_margin_q);

if near_boundary
    cls = "BoundaryFalsePeak";
    return;
end

if true_basin_localmax
    cls = "PeakCompetition";
else
    cls = "BasinCollapse";
end

end

%% ========================================================================
function S = summarize_failure_modes(T)

regimes = unique(string(T.regime),'stable');
classes = [ ...
    "Success","NearShift","PeakCompetition", ...
    "BasinCollapse","BoundaryFalsePeak"];

rows = {};

for ir = 1:numel(regimes)
    r = regimes(ir);
    Tr = T(string(T.regime)==r,:);

    N = height(Tr);

    for ic = 1:numel(classes)
        c = classes(ic);
        n = sum(string(Tr.failure_class)==c);

        rows(end+1,:) = { ... %#ok<AGROW>
            char(r),char(c),n,n/max(N,1)};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','failure_class','count','fraction_of_cheapfailure'});

end

%% ========================================================================
function A = build_mechanism_audit(T)

features = { ...
    'weak_ratio', ...
    'signed_sep', ...
    'abs_signed_sep', ...
    'cheap_abs_q_error', ...
    'true_to_global_ratio', ...
    'global_minus_true_fraction', ...
    'curve_entropy', ...
    'global_prominence', ...
    'true_curvature_norm', ...
    'num_local_peaks', ...
    'strong_residual_retention', ...
    'weak_retention', ...
    'noise_retention', ...
    'residual_strong_to_weak', ...
    'residual_noise_to_weak', ...
    'cross_sw_norm', ...
    'cross_wn_norm', ...
    'total_residual_to_weak'};

regimes = unique(string(T.regime),'stable');
rows = {};

for ir = 1:numel(regimes)
    r = regimes(ir);
    Tr = T(string(T.regime)==r,:);

    y = logical(Tr.fallback_success);

    for jf = 1:numel(features)
        fname = features{jf};

        x = diagnostic_feature_vector(Tr,fname);

        valid = isfinite(x);

        xv = x(valid);
        yv = y(valid);

        if numel(unique(yv))<2
            auc_raw = NaN;
            auc_oriented = NaN;
            direction = 0;
        else
            auc_raw = binary_auc(yv,xv);

            if auc_raw>=0.5
                auc_oriented = auc_raw;
                direction = +1;
            else
                auc_oriented = 1-auc_raw;
                direction = -1;
            end
        end

        xs = xv(yv);
        xf = xv(~yv);

        med_success = median(xs,'omitnan');
        med_failure = median(xf,'omitnan');

        q25_success = percentile_manual(xs,25);
        q75_success = percentile_manual(xs,75);

        q25_failure = percentile_manual(xf,25);
        q75_failure = percentile_manual(xf,75);

        rows(end+1,:) = { ... %#ok<AGROW>
            char(r),fname, ...
            auc_raw,auc_oriented,direction, ...
            med_success,med_failure, ...
            q25_success,q75_success, ...
            q25_failure,q75_failure, ...
            sum(valid)};
    end
end

A = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','feature', ...
    'auc_success_raw','auc_oriented','success_direction', ...
    'median_success','median_failure', ...
    'q25_success','q75_success', ...
    'q25_failure','q75_failure', ...
    'n_valid'});

end

%% ========================================================================
function x = diagnostic_feature_vector(T,name)

switch name
    case 'abs_signed_sep'
        x = abs(double(T.signed_sep));

    case 'cheap_abs_q_error'
        x = abs(double(T.cheap_q_error));

    otherwise
        if ~ismember(name,T.Properties.VariableNames)
            error('Unknown diagnostic feature: %s',name);
        end

        x = double(T.(name));
end

x = x(:);

end

%% ========================================================================
function S = summarize_residual_by_mode(T)

regimes = unique(string(T.regime),'stable');
classes = unique(string(T.failure_class),'stable');

features = { ...
    'strong_residual_retention', ...
    'weak_retention', ...
    'residual_strong_to_weak', ...
    'residual_noise_to_weak', ...
    'cross_sw_norm', ...
    'cross_wn_norm', ...
    'total_residual_to_weak', ...
    'true_to_global_ratio'};

rows = {};

for ir = 1:numel(regimes)
    r = regimes(ir);

    for ic = 1:numel(classes)
        c = classes(ic);

        mm = string(T.regime)==r & ...
             string(T.failure_class)==c;

        Tc = T(mm,:);

        if isempty(Tc)
            continue;
        end

        for jf = 1:numel(features)
            fname = features{jf};
            x = double(Tc.(fname));
            x = x(isfinite(x));

            rows(end+1,:) = { ... %#ok<AGROW>
                char(r),char(c),fname, ...
                numel(x), ...
                mean(x,'omitnan'), ...
                median(x,'omitnan'), ...
                percentile_manual(x,25), ...
                percentile_manual(x,75)};
        end
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','failure_class','feature', ...
    'n','mean','median','q25','q75'});

end

%% ========================================================================
function S = summarize_true_peak_rank(T)

regimes = unique(string(T.regime),'stable');

rows = {};

for ir = 1:numel(regimes)
    r = regimes(ir);
    Tr = T(string(T.regime)==r,:);

    is_fail = ~logical(Tr.fallback_success);
    Tf = Tr(is_fail,:);

    N = height(Tf);

    no_peak = ~Tf.true_basin_localmax;

    rank2 = Tf.true_peak_rank==2;
    rank3 = Tf.true_peak_rank==3;
    rank4plus = Tf.true_peak_rank>=4;

    % Rank-1 among failures can occur only if the local maximum is inside
    % the success basin but the discrete global winner lies just outside;
    % retain it as a diagnostic rather than silently dropping it.
    rank1 = Tf.true_peak_rank==1;

    rows(end+1,:) = { ... %#ok<AGROW>
        char(r),N, ...
        sum(rank1)/max(N,1), ...
        sum(rank2)/max(N,1), ...
        sum(rank3)/max(N,1), ...
        sum(rank4plus)/max(N,1), ...
        sum(no_peak)/max(N,1)};
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','n_fallback_failures', ...
    'fraction_true_peak_rank1', ...
    'fraction_true_peak_rank2', ...
    'fraction_true_peak_rank3', ...
    'fraction_true_peak_rank4plus', ...
    'fraction_no_true_local_peak'});

end

%% ========================================================================
function M = build_state_failure_map(T,cfg)

wr_edges = cfg.weak_ratio_edges(:);
sp_edges = cfg.sep_edges(:);

rows = {};

for iw = 1:numel(wr_edges)-1
    for is = 1:numel(sp_edges)-1

        wr1 = wr_edges(iw);
        wr2 = wr_edges(iw+1);

        sp1 = sp_edges(is);
        sp2 = sp_edges(is+1);

        if iw<numel(wr_edges)-1
            mw = T.weak_ratio>=wr1 & T.weak_ratio<wr2;
        else
            mw = T.weak_ratio>=wr1 & T.weak_ratio<=wr2;
        end

        if is<numel(sp_edges)-1
            ms = T.signed_sep>=sp1 & T.signed_sep<sp2;
        else
            ms = T.signed_sep>=sp1 & T.signed_sep<=sp2;
        end

        mm = mw & ms;

        n = sum(mm);

        if n>=cfg.min_bin_trials
            rescue_rate = mean(double(T.fallback_success(mm)));

            basin_collapse_rate = mean( ...
                double(string(T.failure_class(mm))=="BasinCollapse"));

            peak_competition_rate = mean( ...
                double(string(T.failure_class(mm))=="PeakCompetition"));

            near_shift_rate = mean( ...
                double(string(T.failure_class(mm))=="NearShift"));

            mean_true_ratio = mean( ...
                T.true_to_global_ratio(mm),'omitnan');

            mean_residual_sw = mean( ...
                T.residual_strong_to_weak(mm),'omitnan');
        else
            rescue_rate = NaN;
            basin_collapse_rate = NaN;
            peak_competition_rate = NaN;
            near_shift_rate = NaN;
            mean_true_ratio = NaN;
            mean_residual_sw = NaN;
        end

        rows(end+1,:) = { ... %#ok<AGROW>
            iw,is, ...
            wr1,wr2,(wr1+wr2)/2, ...
            sp1,sp2,(sp1+sp2)/2, ...
            n,rescue_rate, ...
            basin_collapse_rate, ...
            peak_competition_rate, ...
            near_shift_rate, ...
            mean_true_ratio, ...
            mean_residual_sw};
    end
end

M = cell2table(rows, ...
    'VariableNames',{ ...
    'weak_bin','sep_bin', ...
    'weak_ratio_low','weak_ratio_high','weak_ratio_center', ...
    'sep_low','sep_high','sep_center', ...
    'n_trials','rescue_rate', ...
    'basin_collapse_rate','peak_competition_rate','near_shift_rate', ...
    'mean_true_to_global_ratio', ...
    'mean_residual_strong_to_weak'});

end

%% ========================================================================
function L = summarize_line_rescueability(T,traj)

lines = traj.line_index(:);

n_cheapfailure = zeros(numel(lines),1);
rescue_rate = nan(numel(lines),1);

peak_competition_rate = nan(numel(lines),1);
basin_collapse_rate = nan(numel(lines),1);
near_shift_rate = nan(numel(lines),1);

for i = 1:numel(lines)
    k = lines(i);
    mm = T.line_index==k;

    n = sum(mm);
    n_cheapfailure(i) = n;

    if n>0
        rescue_rate(i) = ...
            mean(double(T.fallback_success(mm)));

        peak_competition_rate(i) = ...
            mean(double(string(T.failure_class(mm))=="PeakCompetition"));

        basin_collapse_rate(i) = ...
            mean(double(string(T.failure_class(mm))=="BasinCollapse"));

        near_shift_rate(i) = ...
            mean(double(string(T.failure_class(mm))=="NearShift"));
    end
end

L = table( ...
    lines,traj.weak_ratio,traj.signed_sep, ...
    n_cheapfailure,rescue_rate, ...
    peak_competition_rate, ...
    basin_collapse_rate,near_shift_rate, ...
    'VariableNames',{ ...
    'line_index','weak_ratio','signed_sep', ...
    'n_cheapfailure','rescue_rate', ...
    'peak_competition_rate', ...
    'basin_collapse_rate','near_shift_rate'});

end

%% ========================================================================
function Rep = select_representative_curves(T,curve_bank,q_grid,cfg)

classes = [ ...
    "Success","NearShift","PeakCompetition", ...
    "BasinCollapse","BoundaryFalsePeak"];

rep_rows = [];
rep_classes = strings(0,1);
rep_curves = [];

for ic = 1:numel(classes)
    c = classes(ic);
    idx = find(string(T.failure_class)==c);

    if isempty(idx)
        continue;
    end

    X = [ ...
        T.true_to_global_ratio(idx), ...
        log10(max(T.residual_strong_to_weak(idx),1e-12)), ...
        abs(T.fallback_q_error(idx))];

    med = median(X,1,'omitnan');
    scl = std(X,0,1,'omitnan');
    scl(~isfinite(scl) | scl<1e-12) = 1;

    Z = bsxfun(@rdivide, ...
        bsxfun(@minus,X,med),scl);

    d2 = sum(Z.^2,2);
    d2(~isfinite(d2)) = Inf;

    [~,jj] = min(d2);
    row = idx(jj);

    curve = curve_bank(:,row);
    curve = curve/max(max(curve),eps);

    rep_rows(end+1,1) = row; %#ok<AGROW>
    rep_classes(end+1,1) = c; %#ok<AGROW>
    rep_curves(:,end+1) = curve; %#ok<AGROW>
end

if isempty(rep_rows)
    Rep = struct();
    Rep.classes = strings(0,1);
    Rep.row_index = zeros(0,1);
    Rep.curves = zeros(numel(q_grid),0);
    Rep.meta = T([],:);
    return;
end

Rep = struct();
Rep.classes = rep_classes;
Rep.row_index = rep_rows;
Rep.curves = rep_curves;
Rep.meta = T(rep_rows,:);

end

%% ========================================================================
function write_representative_curve_csv(Rep,q_grid,filename)

T = table(q_grid(:),'VariableNames',{'q_candidate'});

for i = 1:numel(Rep.classes)
    vname = matlab.lang.makeValidName( ...
        char("curve_"+Rep.classes(i)));

    T.(vname) = Rep.curves(:,i);
end

writetable(T,filename);

meta_file = strrep(filename,'.csv','_metadata.csv');

if ~isempty(Rep.meta)
    writetable(Rep.meta,meta_file);
end

end

%% ========================================================================
function D = build_decision_summary( ...
    T,mechanism_audit,mode_summary,residual_by_mode)

regimes = unique(string(T.regime),'stable');
rows = {};

for ir = 1:numel(regimes)
    r = regimes(ir);

    Tr = T(string(T.regime)==r,:);

    rescue_rate = mean(double(Tr.fallback_success));

    % Failure composition excluding Success.
    classes = [ ...
        "NearShift","PeakCompetition", ...
        "BasinCollapse","BoundaryFalsePeak"];

    frac = nan(numel(classes),1);

    for ic = 1:numel(classes)
        mm = strcmp(mode_summary.regime,char(r)) & ...
             strcmp(mode_summary.failure_class,char(classes(ic)));

        if any(mm)
            frac(ic) = ...
                mode_summary.fraction_of_cheapfailure(mm);
        else
            frac(ic) = 0;
        end
    end

    [dominant_fraction,ii] = max(frac);
    dominant_failure_mode = char(classes(ii));

    % Key physical/residual AUCs.
    auc_weak_ratio = get_audit_auc( ...
        mechanism_audit,char(r),'weak_ratio');

    auc_abs_sep = get_audit_auc( ...
        mechanism_audit,char(r),'abs_signed_sep');

    auc_strong_resid = get_audit_auc( ...
        mechanism_audit,char(r),'residual_strong_to_weak');

    auc_weak_ret = get_audit_auc( ...
        mechanism_audit,char(r),'weak_retention');

    auc_cross_sw = get_audit_auc( ...
        mechanism_audit,char(r),'cross_sw_norm');

    auc_cross_wn = get_audit_auc( ...
        mechanism_audit,char(r),'cross_wn_norm');

    % Median residual strong/weak ratio by Success vs all failures.
    success_mask = logical(Tr.fallback_success);
    failure_mask = ~success_mask;

    med_resid_success = median( ...
        Tr.residual_strong_to_weak(success_mask),'omitnan');

    med_resid_failure = median( ...
        Tr.residual_strong_to_weak(failure_mask),'omitnan');

    med_weakret_success = median( ...
        Tr.weak_retention(success_mask),'omitnan');

    med_weakret_failure = median( ...
        Tr.weak_retention(failure_mask),'omitnan');

    frac_fail_with_true_peak = ...
        mean(double( ...
        Tr.true_basin_localmax(failure_mask)));

    frac_fail_no_true_peak = ...
        1-frac_fail_with_true_peak;

    rows(end+1,:) = { ... %#ok<AGROW>
        char(r),height(Tr),rescue_rate, ...
        dominant_failure_mode,dominant_fraction, ...
        frac_fail_with_true_peak,frac_fail_no_true_peak, ...
        auc_weak_ratio,auc_abs_sep, ...
        auc_strong_resid,auc_weak_ret, ...
        auc_cross_sw,auc_cross_wn, ...
        med_resid_success,med_resid_failure, ...
        med_weakret_success,med_weakret_failure};
end

D = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','n_cheapfailure_trials','fallback_rescue_rate', ...
    'dominant_failure_mode','dominant_failure_fraction', ...
    'failure_fraction_with_true_local_peak', ...
    'failure_fraction_without_true_local_peak', ...
    'auc_weak_ratio','auc_abs_signed_sep', ...
    'auc_residual_strong_to_weak','auc_weak_retention', ...
    'auc_cross_sw','auc_cross_wn', ...
    'median_residual_strong_to_weak_success', ...
    'median_residual_strong_to_weak_failure', ...
    'median_weak_retention_success', ...
    'median_weak_retention_failure'});

end

%% ========================================================================
function v = get_audit_auc(T,regime,feature)

mm = strcmp(T.regime,regime) & ...
     strcmp(T.feature,feature);

if sum(mm)~=1
    error('Audit row not unique for %s / %s.',regime,feature);
end

v = T.auc_oriented(mm);

end

%% ========================================================================
function write_summary( ...
    out_dir,cfg, ...
    mode_summary,mechanism_audit, ...
    residual_by_mode,rank_summary,decision, ...
    time_smooth,time_abrupt)

fid = fopen(fullfile(out_dir,'summary.txt'),'w');

fprintf(fid,'EXP009-C3-B3A Rescueability Failure-Mode Decomposition\n');
fprintf(fid,'======================================================\n\n');

fprintf(fid,'Research question\n');
fprintf(fid,'-----------------\n');
fprintf(fid,['C3-B2 showed that CheapFailure is moderately observable, ' ...
    'while Rescueability is weakly observable.\n']);
fprintf(fid,['C3-B3A therefore asks WHY fallback rescues some CheapFailure ' ...
    'trials but not others.\n\n']);

fprintf(fid,'Controlled boundary\n');
fprintf(fid,'-------------------\n');
fprintf(fid,'q_strong remains known/oracle.\n');
fprintf(fid,'SNR = %.2f dB.\n',cfg.snr_db);
fprintf(fid,'q_weak = %.6f.\n',cfg.q_weak);
fprintf(fid,'Fallback success tolerance tau_q = %.6f.\n',cfg.tau_q);
fprintf(fid,['Fallback success is defined only by weak-q recovery in this ' ...
    'controlled C3 chain; there is no later downstream success stage.\n\n']);

fprintf(fid,'Failure-mode definitions among CheapFailure trials\n');
fprintf(fid,'--------------------------------------------------\n');
fprintf(fid,'Success          : fallback q winner lies inside tau_q.\n');
fprintf(fid,'NearShift        : failed winner is near q_weak but outside tau_q.\n');
fprintf(fid,['PeakCompetition  : a true-basin local peak survives, but a ' ...
    'different global peak wins.\n']);
fprintf(fid,['BasinCollapse    : no local maximum survives inside the ' ...
    'true weak-q basin.\n']);
fprintf(fid,'BoundaryFalsePeak: failed winner lies near q-search boundary.\n\n');

fprintf(fid,'Failure-mode composition\n');
fprintf(fid,'------------------------\n');
for i = 1:height(mode_summary)
    fprintf(fid,'%-7s %-18s count=%d frac=%.6f\n', ...
        mode_summary.regime{i}, ...
        mode_summary.failure_class{i}, ...
        mode_summary.count(i), ...
        mode_summary.fraction_of_cheapfailure(i));
end

fprintf(fid,'\nMechanism audit: oriented AUC for fallback success\n');
fprintf(fid,'--------------------------------------------------\n');

for regime = {'Smooth','Abrupt'}
    r = regime{1};

    fprintf(fid,'\n%s\n',r);

    Tr = mechanism_audit(strcmp(mechanism_audit.regime,r),:);
    [~,ord] = sort(Tr.auc_oriented,'descend');

    Tr = Tr(ord,:);

    for i = 1:height(Tr)
        fprintf(fid,[ ...
            '%-30s AUC=%.6f dir=%+d ' ...
            'medSuccess=%g medFailure=%g\n'], ...
            Tr.feature{i}, ...
            Tr.auc_oriented(i), ...
            Tr.success_direction(i), ...
            Tr.median_success(i), ...
            Tr.median_failure(i));
    end
end

fprintf(fid,'\nTrue-basin local-peak rank among fallback failures\n');
fprintf(fid,'-------------------------------------------------\n');
for i = 1:height(rank_summary)
    fprintf(fid,[ ...
        '%s nFail=%d rank1=%.4f rank2=%.4f rank3=%.4f ' ...
        'rank4+=%.4f noTruePeak=%.4f\n'], ...
        rank_summary.regime{i}, ...
        rank_summary.n_fallback_failures(i), ...
        rank_summary.fraction_true_peak_rank1(i), ...
        rank_summary.fraction_true_peak_rank2(i), ...
        rank_summary.fraction_true_peak_rank3(i), ...
        rank_summary.fraction_true_peak_rank4plus(i), ...
        rank_summary.fraction_no_true_local_peak(i));
end

fprintf(fid,'\nDecision summary\n');
fprintf(fid,'----------------\n');
for i = 1:height(decision)
    fprintf(fid,[ ...
        '%s CheapFailure n=%d rescue=%.4f dominant=%s %.4f | ' ...
        'failWithTruePeak=%.4f failNoTruePeak=%.4f\n'], ...
        decision.regime{i}, ...
        decision.n_cheapfailure_trials(i), ...
        decision.fallback_rescue_rate(i), ...
        decision.dominant_failure_mode{i}, ...
        decision.dominant_failure_fraction(i), ...
        decision.failure_fraction_with_true_local_peak(i), ...
        decision.failure_fraction_without_true_local_peak(i));

    fprintf(fid,[ ...
        '  AUC weakRatio=%.4f | absSep=%.4f | residStrong/Weak=%.4f | ' ...
        'weakRetention=%.4f | crossSW=%.4f | crossWN=%.4f\n'], ...
        decision.auc_weak_ratio(i), ...
        decision.auc_abs_signed_sep(i), ...
        decision.auc_residual_strong_to_weak(i), ...
        decision.auc_weak_retention(i), ...
        decision.auc_cross_sw(i), ...
        decision.auc_cross_wn(i));

    fprintf(fid,[ ...
        '  median residual S/W success=%g failure=%g | ' ...
        'weak retention success=%g failure=%g\n'], ...
        decision.median_residual_strong_to_weak_success(i), ...
        decision.median_residual_strong_to_weak_failure(i), ...
        decision.median_weak_retention_success(i), ...
        decision.median_weak_retention_failure(i));
end

fprintf(fid,'\nInterpretation logic\n');
fprintf(fid,'--------------------\n');
fprintf(fid,['1. Large PeakCompetition fraction -> true weak structure survives ' ...
    'but winner selection is the bottleneck; next test should examine ' ...
    'multi-hypothesis / local verification rather than stronger CLEAN.\n']);
fprintf(fid,['2. Large BasinCollapse fraction -> the weak basin itself is destroyed ' ...
    'after refit; next test should focus on residual strong/weak/noise ' ...
    'geometry and refit operator design.\n']);
fprintf(fid,['3. Large NearShift fraction -> the fallback landscape is mostly right ' ...
    'but the top peak is biased; local q refinement or uncertainty-aware ' ...
    'acceptance may be enough.\n']);
fprintf(fid,['4. Strong residual-geometry AUC with weak pre-fallback state AUC -> ' ...
    'rescueability is created by the refit residual itself and requires a ' ...
    'low-cost proxy/probe of that residual geometry.\n']);
fprintf(fid,['5. If both residual geometry and curve anatomy fail to separate fate, ' ...
    'the current controlled definition may be dominated by noise-realization ' ...
    'randomness; do not escalate directly to a larger classifier.\n']);

fprintf(fid,'\nRuntime\n');
fprintf(fid,'-------\n');
fprintf(fid,'Smooth %.3f s\n',time_smooth);
fprintf(fid,'Abrupt %.3f s\n',time_abrupt);

fclose(fid);

end

%% ========================================================================
function make_figures( ...
    out_dir,cfg, ...
    diag_smooth,diag_abrupt, ...
    mode_summary,mechanism_audit, ...
    residual_by_mode,rank_summary, ...
    map_smooth,map_abrupt, ...
    line_smooth,line_abrupt, ...
    rep_smooth,rep_abrupt,q_grid)

classes = [ ...
    "Success","NearShift","PeakCompetition", ...
    "BasinCollapse","BoundaryFalsePeak"];

regimes = ["Smooth","Abrupt"];

%% Fig 1: failure-mode composition
Y = zeros(2,numel(classes));

for ir = 1:2
    for ic = 1:numel(classes)
        mm = strcmp(mode_summary.regime,char(regimes(ir))) & ...
             strcmp(mode_summary.failure_class,char(classes(ic)));

        if any(mm)
            Y(ir,ic) = ...
                mode_summary.fraction_of_cheapfailure(mm);
        end
    end
end

fig = figure('Visible',cfg.figure_visible);
bar(Y,'stacked');
ylim([0 1]);
xticks(1:2);
xticklabels(regimes);
ylabel('Fraction of CheapFailure trials');
title('C3-B3A Rescueability Failure-Mode Composition');
legend(classes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig01_failure_mode_composition.png'), ...
    'Resolution',180);
close(fig);

%% Fig 2-3: state rescue maps
plot_state_map( ...
    map_smooth,"Smooth",cfg, ...
    fullfile(out_dir,'fig02_smooth_state_rescue_map.png'));

plot_state_map( ...
    map_abrupt,"Abrupt",cfg, ...
    fullfile(out_dir,'fig03_abrupt_state_rescue_map.png'));

%% Fig 4: selected mechanism AUC audit
selected_features = { ...
    'weak_ratio', ...
    'abs_signed_sep', ...
    'cheap_abs_q_error', ...
    'strong_residual_retention', ...
    'weak_retention', ...
    'residual_strong_to_weak', ...
    'residual_noise_to_weak', ...
    'cross_sw_norm', ...
    'cross_wn_norm', ...
    'true_to_global_ratio'};

Y = nan(numel(selected_features),2);

for jf = 1:numel(selected_features)
    for ir = 1:2
        mm = strcmp(mechanism_audit.feature,selected_features{jf}) & ...
             strcmp(mechanism_audit.regime,char(regimes(ir)));

        Y(jf,ir) = mechanism_audit.auc_oriented(mm);
    end
end

fig = figure('Visible',cfg.figure_visible);
bar(Y);
yline(0.5,'--');
ylim([0.45 1]);

xticks(1:numel(selected_features));
xticklabels(string(selected_features));
xtickangle(30);

ylabel('Oriented AUC for fallback success');
title('C3-B3A Which Mechanism Separates Rescue Success?');
legend(regimes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig04_mechanism_auc_audit.png'), ...
    'Resolution',180);
close(fig);

%% Fig 5: true-basin rank anatomy
Y = [ ...
    rank_summary.fraction_true_peak_rank1, ...
    rank_summary.fraction_true_peak_rank2, ...
    rank_summary.fraction_true_peak_rank3, ...
    rank_summary.fraction_true_peak_rank4plus, ...
    rank_summary.fraction_no_true_local_peak];

fig = figure('Visible',cfg.figure_visible);
bar(Y,'stacked');
ylim([0 1]);
xticks(1:height(rank_summary));
xticklabels(string(rank_summary.regime));

ylabel('Fraction of fallback failures');
title('C3-B3A What Happened to the True Weak-q Peak?');

legend( ...
    ["Rank1-near miss","Rank2","Rank3","Rank4+","No true local peak"], ...
    'Location','best');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig05_true_peak_rank_anatomy.png'), ...
    'Resolution',180);
close(fig);

%% Fig 6-7: representative curves
plot_representative_curves( ...
    rep_smooth,q_grid,cfg.q_weak, ...
    "Smooth",cfg, ...
    fullfile(out_dir,'fig06_smooth_representative_curves.png'));

plot_representative_curves( ...
    rep_abrupt,q_grid,cfg.q_weak, ...
    "Abrupt",cfg, ...
    fullfile(out_dir,'fig07_abrupt_representative_curves.png'));

%% Fig 8-9: residual geometry plane
plot_residual_geometry_plane( ...
    diag_smooth,"Smooth",cfg, ...
    fullfile(out_dir,'fig08_smooth_residual_geometry_plane.png'));

plot_residual_geometry_plane( ...
    diag_abrupt,"Abrupt",cfg, ...
    fullfile(out_dir,'fig09_abrupt_residual_geometry_plane.png'));

%% Fig 10-11: line rescueability
plot_line_rescueability( ...
    line_smooth,"Smooth",cfg, ...
    fullfile(out_dir,'fig10_smooth_line_rescueability.png'));

plot_line_rescueability( ...
    line_abrupt,"Abrupt",cfg, ...
    fullfile(out_dir,'fig11_abrupt_line_rescueability.png'));

%% Fig 12: median residual anatomy by failure mode
features = [ ...
    "residual_strong_to_weak", ...
    "weak_retention", ...
    "cross_sw_norm", ...
    "cross_wn_norm"];

fig = figure('Visible',cfg.figure_visible);

% Normalize each feature by robust all-mode scale only for joint display.
Y = nan(numel(classes),numel(features));

for ic = 1:numel(classes)
    c = classes(ic);

    for jf = 1:numel(features)
        f = features(jf);

        mm = strcmp(residual_by_mode.regime,'Smooth') & ...
             strcmp(residual_by_mode.failure_class,char(c)) & ...
             strcmp(residual_by_mode.feature,char(f));

        if any(mm)
            Y(ic,jf) = residual_by_mode.median(mm);
        end
    end
end

% Robust scale per column so unlike units can share one diagnostic plot.
for jf = 1:size(Y,2)
    s = median(abs(Y(:,jf)),'omitnan');
    if ~isfinite(s) || s<1e-12
        s = 1;
    end
    Y(:,jf) = Y(:,jf)/s;
end

bar(Y);
xticks(1:numel(classes));
xticklabels(classes);
xtickangle(25);

ylabel('Median / robust feature scale');
title('C3-B3A Smooth Residual Anatomy by Failure Mode');
legend(features,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig12_smooth_residual_anatomy_by_mode.png'), ...
    'Resolution',180);
close(fig);

end

%% ========================================================================
function plot_state_map(M,regime,cfg,filename)

wr = unique(M.weak_ratio_center);
sp = unique(M.sep_center);

Z = nan(numel(wr),numel(sp));

for i = 1:height(M)
    iw = find(abs(wr-M.weak_ratio_center(i))<1e-12,1);
    is = find(abs(sp-M.sep_center(i))<1e-12,1);

    Z(iw,is) = M.rescue_rate(i);
end

fig = figure('Visible',cfg.figure_visible);

imagesc(sp,wr,Z);
axis xy;
caxis([0 1]);
colorbar;

xlabel('q_s - q_w');
ylabel('A_w / A_s');

title(sprintf( ...
    'C3-B3A %s: Rescue Rate Within CheapFailure', ...
    char(regime)));

exportgraphics(fig,filename,'Resolution',180);
close(fig);

end

%% ========================================================================
function plot_representative_curves( ...
    Rep,q_grid,q_weak,regime,cfg,filename)

fig = figure('Visible',cfg.figure_visible);
hold on;

for i = 1:numel(Rep.classes)
    plot(q_grid,Rep.curves(:,i),'LineWidth',1.2);
end

xline(q_weak,':','True q_w');

xlabel('q candidate');
ylabel('Normalized fallback concentration');

title(sprintf( ...
    'C3-B3A %s Representative Fallback Landscapes', ...
    char(regime)));

if ~isempty(Rep.classes)
    legend(Rep.classes,'Location','best');
end

grid on;

exportgraphics(fig,filename,'Resolution',180);
close(fig);

end

%% ========================================================================
function plot_residual_geometry_plane(T,regime,cfg,filename)

class_id = zeros(height(T),1);
class_id(logical(T.fallback_success)) = 1;

fig = figure('Visible',cfg.figure_visible);

scatter( ...
    T.residual_strong_to_weak, ...
    T.true_to_global_ratio, ...
    16,class_id,'filled');

xlabel('Residual strong energy / residual weak energy');
ylabel('True-basin / global concentration');

title(sprintf( ...
    'C3-B3A %s Residual Geometry vs Weak-q Survival', ...
    char(regime)));

cb = colorbar;
cb.Ticks = [0 1];
cb.TickLabels = {'Fallback failure','Fallback success'};

grid on;

exportgraphics(fig,filename,'Resolution',180);
close(fig);

end

%% ========================================================================
function plot_line_rescueability(L,regime,cfg,filename)

fig = figure('Visible',cfg.figure_visible);

plot(L.line_index,L.rescue_rate,'LineWidth',1.2);

xlabel('Azimuth-line index');
ylabel('Fallback rescue rate | CheapFailure');

title(sprintf( ...
    'C3-B3A %s Line-Level Rescueability', ...
    char(regime)));

ylim([0 1]);
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
function q = percentile_manual(x,p)

x = double(x(:));
x = x(isfinite(x));

if isempty(x)
    q = NaN;
    return;
end

x = sort(x);

if numel(x)==1
    q = x(1);
    return;
end

p = min(max(double(p),0),100);

pos = 1 + (numel(x)-1)*(p/100);

lo = floor(pos);
hi = ceil(pos);

if lo==hi
    q = x(lo);
else
    w = pos-lo;
    q = (1-w)*x(lo) + w*x(hi);
end

end
