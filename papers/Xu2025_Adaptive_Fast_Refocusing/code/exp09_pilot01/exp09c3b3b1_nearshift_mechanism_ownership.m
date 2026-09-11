function results = exp09c3b3b1_nearshift_mechanism_ownership()
%EXP09C3B3B1_NEARSHIFT_MECHANISM_OWNERSHIP
% EXP009 / Pilot-01 / C3-B3B.1
%
% NearShift Mechanism Ownership Test
%
% Purpose
% -------
% C3-B3B established three facts:
%   1) the A4/B1 first-order perturbation law predicts NearShift very well;
%   2) 2x denser q-grid does not rescue the failures;
%   3) same-curve local interpolation does not recover q_weak.
%
% C3-B3B.1 therefore asks a stricter causal question:
%
%   Who "owns" the NearShift?
%
% We decompose the practical fallback projection into four paired groups,
% all using the SAME underlying strong/weak signals and SAME noise
% realization for every Monte-Carlo trial:
%
%   G0 WeakOnly
%      R0 = S_w + N
%
%   G1 OperatorOnly
%      R1 = E_w + E_n
%
%   G2 ResidualOnly
%      R2 = S_w + N + E_s
%
%   G3 FullCLEAN
%      R3 = E_w + E_n + E_s
%
% where [E_s,E_w,E_n] are produced by the SAME practical fitted projection
% operator estimated from the full mixture:
%
%      X = S_s + S_w + N
%
% Conditional on that fitted atom, the projection is linear and:
%
%      E_s = P_hat S_s
%      E_w = P_hat S_w
%      E_n = P_hat N
%
% so G1/G2/G3 form a controlled operator/residual factorial comparison.
%
% IMPORTANT INTERPRETATION
% ------------------------
% G1 is "operator acting on weak+noise, conditional on the practical
% full-mixture fitted atom". It is NOT a hypothetical independently refitted
% weak-only CLEAN. This is deliberate: it preserves the exact practical
% operator used by G3 and isolates what that operator does to weak/noise.
%
% The experiment reports:
%   - all-trial paired error/failure statistics;
%   - G3-NearShift-conditioned counterfactual statistics;
%   - normalized weak-peak curvature and operator weak retention;
%   - group-wise first-order perturbation decomposition;
%   - paired sequence-cluster bootstrap CIs for:
%         Operator effect
%         Residual effect
%         Operator x Residual interaction
%
% Run:
%   results = exp09c3b3b1_nearshift_mechanism_ownership;
%
% Dependency:
%   Existing config_exp09c3b3b.m from C3-B3B must be on the MATLAB path.

cfg = config_exp09c3b3b();
cfg = add_ownership_defaults(cfg);
assert_required_cfg(cfg);

%% Resolve output path
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.output_dir)
    out_path = fullfile( ...
        paper_root,'results','exp09_pilot01', ...
        'exp09c3b3b1_nearshift_mechanism_ownership');
else
    % Do not overwrite C3-B3B itself if cfg.output_dir points there.
    out_path = fullfile(cfg.output_dir, ...
        'exp09c3b3b1_nearshift_mechanism_ownership');
end

if ~exist(out_path,'dir')
    mkdir(out_path);
end

fprintf('\n============================================================\n');
fprintf(' EXP009-C3-B3B.1 / NearShift Mechanism Ownership Test\n');
fprintf('============================================================\n');
fprintf('Output             : %s\n',out_path);
fprintf('MC / regime        : %d\n',cfg.num_mc);
fprintf('Lines / MC         : %d\n',cfg.num_lines);
fprintf('SNR                : %.1f dB\n',cfg.snr_db);
fprintf('q step             : %.6f\n',cfg.q_search_step);
fprintf('success tau_q      : %.6f\n',cfg.tau_q);
fprintf('near-shift max     : %.6f\n',cfg.near_shift_tol);
fprintf('bootstrap reps     : %d\n\n',cfg.ownership_bootstrap_reps);

%% Common setup
N = cfg.N;
n = 0:N-1;
t = (n-N/2)/N;

q_grid = ( ...
    cfg.q_search_min: ...
    cfg.q_search_step: ...
    cfg.q_search_max).';

q_diag = ( ...
    cfg.q_weak-cfg.q_diag_halfwidth: ...
    cfg.q_diag_step: ...
    cfg.q_weak+cfg.q_diag_halfwidth).';

D_search = build_dechirp_dictionary(q_grid,t,cfg);
D_match = build_matched_dictionary(q_diag,t,cfg.f_weak,cfg);

%% Physical trajectories
traj_smooth = build_trajectory("Smooth",cfg);
traj_abrupt = build_trajectory("Abrupt",cfg);

writetable(traj_smooth,fullfile(out_path,'trajectory_smooth.csv'));
writetable(traj_abrupt,fullfile(out_path,'trajectory_abrupt.csv'));

%% Deterministic signal components
det_smooth = precompute_deterministic_components(traj_smooth,t,cfg);
det_abrupt = precompute_deterministic_components(traj_abrupt,t,cfg);

%% Run paired banks
fprintf('Running Smooth ownership bank...\n');
tic;
[T_smooth,sanity_smooth] = run_ownership_bank( ...
    "Smooth",det_smooth,traj_smooth, ...
    cfg.num_mc,cfg.seed+7310, ...
    q_grid,q_diag,D_search,D_match,t,cfg);
time_smooth = toc;

fprintf('Running Abrupt ownership bank...\n');
tic;
[T_abrupt,sanity_abrupt] = run_ownership_bank( ...
    "Abrupt",det_abrupt,traj_abrupt, ...
    cfg.num_mc,cfg.seed+8310, ...
    q_grid,q_diag,D_search,D_match,t,cfg);
time_abrupt = toc;

fprintf('Smooth runtime: %.2f s\n',time_smooth);
fprintf('Abrupt runtime: %.2f s\n\n',time_abrupt);

T_all = [T_smooth;T_abrupt];

writetable(T_smooth,fullfile(out_path,'trial_ownership_smooth.csv'));
writetable(T_abrupt,fullfile(out_path,'trial_ownership_abrupt.csv'));
writetable(T_all,fullfile(out_path,'trial_ownership_all.csv'));

%% Summaries
group_summary = summarize_groups(T_all);
firstorder_summary = summarize_firstorder_groups(T_all,cfg);
contrib_summary = summarize_contributions_groups(T_all);
g3_cohort_summary = summarize_g3_nearshift_counterfactual(T_all);
ownership_effects = summarize_ownership_effects(T_all,cfg);

sanity_summary = table( ...
    ["Smooth";"Abrupt"], ...
    [sanity_smooth.max_oracle_subtract_mismatch; ...
     sanity_abrupt.max_oracle_subtract_mismatch], ...
    [sanity_smooth.max_full_decomposition_mismatch; ...
     sanity_abrupt.max_full_decomposition_mismatch], ...
    'VariableNames',{ ...
    'regime', ...
    'max_oracle_subtract_mismatch', ...
    'max_full_decomposition_mismatch'});

writetable(group_summary, ...
    fullfile(out_path,'group_summary.csv'));
writetable(firstorder_summary, ...
    fullfile(out_path,'first_order_group_validation.csv'));
writetable(contrib_summary, ...
    fullfile(out_path,'perturbation_contribution_by_group.csv'));
writetable(g3_cohort_summary, ...
    fullfile(out_path,'g3_nearshift_counterfactual.csv'));
writetable(ownership_effects, ...
    fullfile(out_path,'ownership_effects_with_cluster_bootstrap.csv'));
writetable(sanity_summary, ...
    fullfile(out_path,'sanity_checks.csv'));

decision = build_decision_summary( ...
    group_summary,ownership_effects,g3_cohort_summary, ...
    firstorder_summary,contrib_summary);

writetable(decision, ...
    fullfile(out_path,'decision_summary.csv'));

%% Console
fprintf('\n================ GROUP SUMMARY ==============================\n');
disp(group_summary);

fprintf('\n================ OWNERSHIP EFFECTS ==========================\n');
disp(ownership_effects);

fprintf('\n================ G3 NEARSHIFT COUNTERFACTUAL ================\n');
disp(g3_cohort_summary);

fprintf('\n================ DECISION ===================================\n');
disp(decision);
fprintf('=============================================================\n');

%% Text summary
write_summary( ...
    out_path,cfg,group_summary,firstorder_summary, ...
    contrib_summary,g3_cohort_summary,ownership_effects, ...
    sanity_summary,decision,time_smooth,time_abrupt);

%% Save numerical results BEFORE plotting
results = struct();
results.cfg = cfg;
results.group_summary = group_summary;
results.firstorder_summary = firstorder_summary;
results.contrib_summary = contrib_summary;
results.g3_cohort_summary = g3_cohort_summary;
results.ownership_effects = ownership_effects;
results.sanity_summary = sanity_summary;
results.decision = decision;

save(fullfile(out_path,'exp09c3b3b1_results.mat'), ...
    'results','-v7.3');

%% Figures
try
    make_figures( ...
        out_path,cfg,T_smooth,T_abrupt, ...
        group_summary,contrib_summary, ...
        g3_cohort_summary,ownership_effects);
catch ME
    warning('C3B3B1:PlottingFailed', ...
        ['Numerical experiment completed and was saved, but figure ' ...
         'generation failed: %s'],ME.message);

    fid_plot = fopen(fullfile(out_path,'plotting_error.txt'),'w');
    if fid_plot>=0
        fprintf(fid_plot,'C3-B3B.1 plotting error\n');
        fprintf(fid_plot,'========================\n\n');
        fprintf(fid_plot,'%s\n\n',ME.message);
        fprintf(fid_plot,'%s\n', ...
            getReport(ME,'extended','hyperlinks','off'));
        fclose(fid_plot);
    end
end

fprintf('\nSaved C3-B3B.1 outputs to:\n%s\n\n',out_path);

end

%% ========================================================================
function cfg = add_ownership_defaults(cfg)

if ~isfield(cfg,'ownership_bootstrap_reps')
    cfg.ownership_bootstrap_reps = 2000;
end

if ~isfield(cfg,'ownership_bootstrap_seed')
    cfg.ownership_bootstrap_seed = cfg.seed + 9900;
end

if ~isfield(cfg,'ownership_cdf_points')
    cfg.ownership_cdf_points = 300;
end

end

%% ========================================================================
function assert_required_cfg(cfg)

required = { ...
    'N','num_lines','num_mc','seed', ...
    'q_ref','mu_scale','q_weak', ...
    'A_strong','f_strong','f_weak','phi_strong','phi_weak', ...
    'snr_db', ...
    'q_search_min','q_search_step','q_search_max', ...
    'q_diag_halfwidth','q_diag_step', ...
    'q_search_block_lines', ...
    'tau_q','success_tol','near_shift_tol', ...
    'refit_nfft_factor', ...
    'max_firstorder_abs_shift','min_validation_samples', ...
    'weak_ratio_center','weak_ratio_sin1','weak_ratio_sin2', ...
    'weak_ratio_min','weak_ratio_max', ...
    'sep_center','sep_sin1','sep_sin2','sep_min','sep_max', ...
    'jump_fraction','jump_weak_ratio_step','jump_sep_step', ...
    'figure_visible','output_dir'};

for i = 1:numel(required)
    if ~isfield(cfg,required{i})
        error(['C3-B3B.1 requires cfg.%s. ' ...
               'Use the same config_exp09c3b3b.m as the completed C3-B3B.'], ...
               required{i});
    end
end

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

for k = 1:L
    qs = traj.q_strong(k);
    rA = traj.weak_ratio(k);

    ss = synth_lfm( ...
        cfg.A_strong,qs, ...
        cfg.f_strong,cfg.phi_strong,t,cfg);

    sw = synth_lfm( ...
        cfg.A_strong*rA,cfg.q_weak, ...
        cfg.f_weak,cfg.phi_weak,t,cfg);

    Sstrong(k,:) = ss(:).';
    Sweak(k,:) = sw(:).';
end

det = struct();
det.Sstrong = Sstrong;
det.Sweak = Sweak;

end

%% ========================================================================
function [T,sanity] = run_ownership_bank( ...
    regime,det,traj,num_mc,seed, ...
    q_grid,q_diag,D_search,D_match,t,cfg)

rng(seed,'twister');

L = height(traj);
N = cfg.N;

s_ref = synth_lfm( ...
    cfg.A_strong,cfg.q_weak-0.05, ...
    cfg.f_strong,cfg.phi_strong,t,cfg);

Pstrong = mean(abs(s_ref).^2);
noise_var = Pstrong/(10^(cfg.snr_db/10));

group_names = ["G0_WeakOnly","G1_OperatorOnly", ...
               "G2_ResidualOnly","G3_FullCLEAN"];
G = numel(group_names);

rows_per_mc = L*G;
max_rows = rows_per_mc*num_mc;

regime_col = strings(max_rows,1);
group_col = strings(max_rows,1);

sequence_id = zeros(max_rows,1);
base_trial_id = zeros(max_rows,1);
line_index = zeros(max_rows,1);

weak_ratio = nan(max_rows,1);
signed_sep = nan(max_rows,1);

q_hat = nan(max_rows,1);
q_error = nan(max_rows,1);
success = false(max_rows,1);
nearshift = false(max_rows,1);

weak_retention = nan(max_rows,1);

matched_q0_weak = nan(max_rows,1);
weak_baseline_bias = nan(max_rows,1);
matched_q_total = nan(max_rows,1);
matched_total_q_error = nan(max_rows,1);
matched_shift_measured = nan(max_rows,1);
matched_shift_predicted = nan(max_rows,1);
matched_total_error_predicted = nan(max_rows,1);
firstorder_valid = false(max_rows,1);

weak_peak_power = nan(max_rows,1);
weak_curvature_raw = nan(max_rows,1);
weak_curvature_normalized = nan(max_rows,1);

pred_shift_strong_power = nan(max_rows,1);
pred_shift_noise_power = nan(max_rows,1);
pred_shift_weak_strong_cross = nan(max_rows,1);
pred_shift_weak_noise_cross = nan(max_rows,1);
pred_shift_strong_noise_cross = nan(max_rows,1);

row0 = 0;
max_oracle_subtract_mismatch = 0;
max_full_decomposition_mismatch = 0;

Z0 = complex(zeros(L,N));

for imc = 1:num_mc

    % Same noise realization is shared by all four ownership groups.
    noise = sqrt(noise_var/2) * ...
        (randn(L,N)+1j*randn(L,N));

    Xmix = det.Sstrong + det.Sweak + noise;

    % IMPORTANT:
    % The fitted atom is estimated ONCE from the practical full mixture.
    % The same conditional linear projection is then decomposed into:
    % Es = P_hat*Sstrong, Ew = P_hat*Sweak, En = P_hat*noise.
    [Rfull,Es,Ew,En] = refit_and_decompose_batch( ...
        Xmix,det.Sstrong,det.Sweak,noise, ...
        traj.q_strong,t,cfg);

    % Four paired ownership groups.
    X0 = det.Sweak + noise;
    X1 = Ew + En;
    X2 = det.Sweak + noise + Es;
    X3 = Rfull;

    % Sanity checks.
    oracle_sub = Xmix - det.Sstrong;
    max_oracle_subtract_mismatch = max( ...
        max_oracle_subtract_mismatch, ...
        max(abs(oracle_sub(:)-X0(:))));

    full_from_parts = Es + Ew + En;
    max_full_decomposition_mismatch = max( ...
        max_full_decomposition_mismatch, ...
        max(abs(full_from_parts(:)-X3(:))));

    % Batch all four groups in one q search.
    Xcat = [X0;X1;X2;X3];

    qh_cat = search_q_hat_batch( ...
        Xcat,q_grid,D_search,cfg.q_search_block_lines);

    % Batch all four groups in one matched first-order analysis.
    %
    % G0: W=Sw, S=0,  N=noise
    % G1: W=Ew, S=0,  N=En
    % G2: W=Sw, S=Es, N=noise
    % G3: W=Ew, S=Es, N=En
    Wcat = [det.Sweak;Ew;det.Sweak;Ew];
    Scat = [Z0;Z0;Es;Es];
    Ncat = [noise;En;noise;En];

    M = matched_firstorder_batch( ...
        Wcat,Scat,Ncat,q_diag,D_match,cfg);

    retention_proj = ...
        sum(abs(Ew).^2,2) ./ ...
        max(sum(abs(det.Sweak).^2,2),eps);

    for ig = 1:G
        idx = (ig-1)*L + (1:L);

        for k = 1:L
            row0 = row0+1;
            ii = idx(k);

            regime_col(row0) = string(regime);
            group_col(row0) = group_names(ig);

            sequence_id(row0) = imc;
            base_trial_id(row0) = (imc-1)*L + k;
            line_index(row0) = traj.line_index(k);

            weak_ratio(row0) = traj.weak_ratio(k);
            signed_sep(row0) = traj.signed_sep(k);

            q_hat(row0) = qh_cat(ii);
            q_error(row0) = q_hat(row0)-cfg.q_weak;

            success(row0) = ...
                abs(q_error(row0)) <= ...
                (cfg.tau_q+cfg.success_tol);

            nearshift(row0) = ...
                (~success(row0)) && ...
                (abs(q_error(row0)) <= ...
                 cfg.near_shift_tol+cfg.success_tol);

            if ig==1 || ig==3
                weak_retention(row0) = 1.0;
            else
                weak_retention(row0) = retention_proj(k);
            end

            matched_q0_weak(row0) = M.q0_weak(ii);
            weak_baseline_bias(row0) = ...
                M.q0_weak(ii)-cfg.q_weak;

            matched_q_total(row0) = M.q_total(ii);
            matched_total_q_error(row0) = ...
                M.q_total(ii)-cfg.q_weak;

            matched_shift_measured(row0) = ...
                M.shift_measured(ii);

            matched_shift_predicted(row0) = ...
                M.shift_predicted(ii);

            matched_total_error_predicted(row0) = ...
                weak_baseline_bias(row0) + ...
                matched_shift_predicted(row0);

            firstorder_valid(row0) = M.valid(ii);

            weak_peak_power(row0) = ...
                M.weak_peak_power(ii);

            weak_curvature_raw(row0) = ...
                M.weak_curvature_raw(ii);

            weak_curvature_normalized(row0) = ...
                M.weak_curvature_normalized(ii);

            pred_shift_strong_power(row0) = ...
                M.shift_strong_power(ii);

            pred_shift_noise_power(row0) = ...
                M.shift_noise_power(ii);

            pred_shift_weak_strong_cross(row0) = ...
                M.shift_weak_strong_cross(ii);

            pred_shift_weak_noise_cross(row0) = ...
                M.shift_weak_noise_cross(ii);

            pred_shift_strong_noise_cross(row0) = ...
                M.shift_strong_noise_cross(ii);
        end
    end
end

keep = 1:row0;

T = table( ...
    regime_col(keep),group_col(keep), ...
    sequence_id(keep),base_trial_id(keep),line_index(keep), ...
    weak_ratio(keep),signed_sep(keep), ...
    q_hat(keep),q_error(keep),success(keep),nearshift(keep), ...
    weak_retention(keep), ...
    matched_q0_weak(keep),weak_baseline_bias(keep), ...
    matched_q_total(keep),matched_total_q_error(keep), ...
    matched_shift_measured(keep), ...
    matched_shift_predicted(keep), ...
    matched_total_error_predicted(keep), ...
    firstorder_valid(keep), ...
    weak_peak_power(keep), ...
    weak_curvature_raw(keep), ...
    weak_curvature_normalized(keep), ...
    pred_shift_strong_power(keep), ...
    pred_shift_noise_power(keep), ...
    pred_shift_weak_strong_cross(keep), ...
    pred_shift_weak_noise_cross(keep), ...
    pred_shift_strong_noise_cross(keep), ...
    'VariableNames',{ ...
    'regime','group', ...
    'sequence_id','base_trial_id','line_index', ...
    'weak_ratio','signed_sep', ...
    'q_hat','q_error','success','nearshift', ...
    'weak_retention', ...
    'matched_q0_weak','weak_baseline_bias', ...
    'matched_q_total','matched_total_q_error', ...
    'matched_shift_measured', ...
    'matched_shift_predicted', ...
    'matched_total_error_predicted', ...
    'firstorder_valid', ...
    'weak_peak_power', ...
    'weak_curvature_raw', ...
    'weak_curvature_normalized', ...
    'pred_shift_strong_power', ...
    'pred_shift_noise_power', ...
    'pred_shift_weak_strong_cross', ...
    'pred_shift_weak_noise_cross', ...
    'pred_shift_strong_noise_cross'});

sanity = struct();
sanity.max_oracle_subtract_mismatch = ...
    max_oracle_subtract_mismatch;
sanity.max_full_decomposition_mismatch = ...
    max_full_decomposition_mismatch;

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

weak_peak_power = nan(B,1);
weak_curvature_raw = nan(B,1);
weak_curvature_normalized = nan(B,1);

shift_strong_power = nan(B,1);
shift_noise_power = nan(B,1);
shift_weak_strong_cross = nan(B,1);
shift_weak_noise_cross = nan(B,1);
shift_strong_noise_cross = nan(B,1);

valid = false(B,1);

h = cfg.q_diag_step;

for b = 1:B

    [pw_peak,i0] = max(Pw(:,b));
    [~,it] = max(Ptotal(:,b));

    q0 = q_diag(i0);
    qt = q_diag(it);

    q0_weak(b) = q0;
    q_total(b) = qt;
    shift_measured(b) = qt-q0;

    weak_peak_power(b) = pw_peak;

    if i0<=1 || i0>=Q
        continue;
    end

    P0dd = ...
        (Pw(i0+1,b) - 2*Pw(i0,b) + Pw(i0-1,b)) / ...
        (h^2);

    weak_curvature_raw(b) = -P0dd;
    weak_curvature_normalized(b) = ...
        (-P0dd)/max(pw_peak,eps);

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

M.weak_peak_power = weak_peak_power;
M.weak_curvature_raw = weak_curvature_raw;
M.weak_curvature_normalized = weak_curvature_normalized;

M.shift_strong_power = shift_strong_power;
M.shift_noise_power = shift_noise_power;
M.shift_weak_strong_cross = shift_weak_strong_cross;
M.shift_weak_noise_cross = shift_weak_noise_cross;
M.shift_strong_noise_cross = shift_strong_noise_cross;

end

%% ========================================================================
function S = summarize_groups(T)

regimes = unique(string(T.regime),'stable');
groups = ["G0_WeakOnly","G1_OperatorOnly", ...
          "G2_ResidualOnly","G3_FullCLEAN"];

rows = {};

for ir = 1:numel(regimes)
    r = regimes(ir);

    for ig = 1:numel(groups)
        g = groups(ig);

        Tr = T(string(T.regime)==r & string(T.group)==g,:);

        e = double(Tr.q_error);
        s = logical(Tr.success);
        ns = logical(Tr.nearshift);
        f = ~s;

        if any(f)
            near_frac_fail = mean(double(ns(f)));
        else
            near_frac_fail = NaN;
        end

        rows(end+1,:) = { ... %#ok<AGROW>
            char(r),char(g),height(Tr), ...
            mean(double(s)), ...
            mean(double(f)), ...
            mean(double(ns)), ...
            near_frac_fail, ...
            mean(abs(e),'omitnan'), ...
            sqrt(mean(e.^2,'omitnan')), ...
            median(abs(e),'omitnan'), ...
            mean(Tr.weak_retention,'omitnan'), ...
            median(Tr.weak_retention,'omitnan'), ...
            mean(Tr.weak_baseline_bias,'omitnan'), ...
            mean(abs(Tr.weak_baseline_bias),'omitnan'), ...
            median(Tr.weak_curvature_normalized,'omitnan')};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','group','n', ...
    'success_rate','failure_rate', ...
    'nearshift_rate_all', ...
    'nearshift_fraction_among_failures', ...
    'q_mae','q_rmse','q_median_abs_error', ...
    'mean_weak_retention','median_weak_retention', ...
    'mean_weak_baseline_bias', ...
    'mean_abs_weak_baseline_bias', ...
    'median_normalized_weak_curvature'});

end

%% ========================================================================
function S = summarize_firstorder_groups(T,cfg)

regimes = unique(string(T.regime),'stable');
groups = ["G0_WeakOnly","G1_OperatorOnly", ...
          "G2_ResidualOnly","G3_FullCLEAN"];
subsets = ["All","Failure","NearShift"];

rows = {};

for ir = 1:numel(regimes)
    r = regimes(ir);

    for ig = 1:numel(groups)
        g = groups(ig);
        Tg = T(string(T.regime)==r & string(T.group)==g,:);

        for is = 1:numel(subsets)
            sn = subsets(is);

            switch sn
                case "All"
                    mm = true(height(Tg),1);
                case "Failure"
                    mm = ~logical(Tg.success);
                case "NearShift"
                    mm = logical(Tg.nearshift);
                otherwise
                    error('Unknown subset.');
            end

            mm = mm & logical(Tg.firstorder_valid);

            x = Tg.matched_shift_measured(mm);
            y = Tg.matched_shift_predicted(mm);

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
                signagree = sign_agreement(x,y);
            else
                pearson_r = NaN;
                spearman_r = NaN;
                slope = NaN;
                intercept = NaN;
                rmse = NaN;
                signagree = NaN;
            end

            rows(end+1,:) = { ... %#ok<AGROW>
                char(r),char(g),char(sn),n, ...
                pearson_r,spearman_r,slope,intercept,rmse,signagree};
        end
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','group','subset','n_valid', ...
    'pearson_r','spearman_r', ...
    'fit_slope_pred_vs_measured','fit_intercept', ...
    'prediction_rmse','sign_agreement'});

end

%% ========================================================================
function S = summarize_contributions_groups(T)

regimes = unique(string(T.regime),'stable');
groups = ["G0_WeakOnly","G1_OperatorOnly", ...
          "G2_ResidualOnly","G3_FullCLEAN"];

features = { ...
    'StrongPower','pred_shift_strong_power'; ...
    'NoisePower','pred_shift_noise_power'; ...
    'WeakStrongCross','pred_shift_weak_strong_cross'; ...
    'WeakNoiseCross','pred_shift_weak_noise_cross'; ...
    'StrongNoiseCross','pred_shift_strong_noise_cross'};

subsets = ["All","Failure","NearShift"];
rows = {};

for ir = 1:numel(regimes)
    r = regimes(ir);

    for ig = 1:numel(groups)
        g = groups(ig);
        Tg = T(string(T.regime)==r & string(T.group)==g,:);

        for is = 1:numel(subsets)
            sn = subsets(is);

            switch sn
                case "All"
                    base = logical(Tg.firstorder_valid);
                case "Failure"
                    base = logical(Tg.firstorder_valid) & ~logical(Tg.success);
                case "NearShift"
                    base = logical(Tg.firstorder_valid) & logical(Tg.nearshift);
                otherwise
                    error('Unknown subset.');
            end

            for jf = 1:size(features,1)
                fname = features{jf,1};
                varname = features{jf,2};

                x = double(Tg.(varname));
                x = x(base & isfinite(x));

                rows(end+1,:) = { ... %#ok<AGROW>
                    char(r),char(g),char(sn),fname, ...
                    numel(x), ...
                    median(x,'omitnan'), ...
                    median(abs(x),'omitnan'), ...
                    mean(abs(x),'omitnan')};
            end
        end
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','group','subset','term','n', ...
    'median_signed_shift', ...
    'median_abs_shift','mean_abs_shift'});

end

%% ========================================================================
function S = summarize_g3_nearshift_counterfactual(T)

regimes = unique(string(T.regime),'stable');
groups = ["G0_WeakOnly","G1_OperatorOnly", ...
          "G2_ResidualOnly","G3_FullCLEAN"];

rows = {};

for ir = 1:numel(regimes)
    r = regimes(ir);

    Tr = T(string(T.regime)==r,:);
    T3 = Tr(string(Tr.group)=="G3_FullCLEAN",:);

    cohort_ids = T3.base_trial_id(logical(T3.nearshift));

    for ig = 1:numel(groups)
        g = groups(ig);

        Tg = Tr(string(Tr.group)==g & ...
            ismember(Tr.base_trial_id,cohort_ids),:);

        if isempty(Tg)
            rows(end+1,:) = { ... %#ok<AGROW>
                char(r),char(g),0, ...
                NaN,NaN,NaN,NaN,NaN};
            continue;
        end

        e = Tg.q_error;

        rows(end+1,:) = { ... %#ok<AGROW>
            char(r),char(g),height(Tg), ...
            mean(double(Tg.success)), ...
            mean(double(Tg.nearshift)), ...
            mean(abs(e),'omitnan'), ...
            median(abs(e),'omitnan'), ...
            mean(abs(Tg.weak_baseline_bias),'omitnan')};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','group','n_g3_nearshift_cohort', ...
    'counterfactual_success_rate', ...
    'counterfactual_nearshift_rate', ...
    'q_mae','q_median_abs_error', ...
    'mean_abs_weak_baseline_bias'});

end

%% ========================================================================
function S = summarize_ownership_effects(T,cfg)

regimes = unique(string(T.regime),'stable');
metric_names = ["AbsError","Failure"];

rows = {};

rng(cfg.ownership_bootstrap_seed,'twister');

for ir = 1:numel(regimes)
    r = regimes(ir);
    Tr = T(string(T.regime)==r,:);

    [E0,E1,E2,E3,seq] = aligned_group_vectors(Tr,'q_error');
    [F0,F1,F2,F3,seq_f] = aligned_group_vectors(Tr,'failure');

    if any(seq~=seq_f)
        error('Ownership alignment mismatch between error and failure metrics.');
    end

    for im = 1:numel(metric_names)
        mn = metric_names(im);

        switch mn
            case "AbsError"
                A0 = abs(E0);
                A1 = abs(E1);
                A2 = abs(E2);
                A3 = abs(E3);

            case "Failure"
                A0 = F0;
                A1 = F1;
                A2 = F2;
                A3 = F3;

            otherwise
                error('Unknown ownership metric.');
        end

        d_op = A1-A0;
        d_res = A2-A0;
        d_int = A3-A1-A2+A0;
        d_total = A3-A0;

        [m_op,lo_op,hi_op] = ...
            cluster_bootstrap_mean(d_op,seq,cfg.ownership_bootstrap_reps);

        [m_res,lo_res,hi_res] = ...
            cluster_bootstrap_mean(d_res,seq,cfg.ownership_bootstrap_reps);

        [m_int,lo_int,hi_int] = ...
            cluster_bootstrap_mean(d_int,seq,cfg.ownership_bootstrap_reps);

        [m_total,lo_total,hi_total] = ...
            cluster_bootstrap_mean(d_total,seq,cfg.ownership_bootstrap_reps);

        rows(end+1,:) = { ... %#ok<AGROW>
            char(r),char(mn), ...
            mean(A0,'omitnan'),mean(A1,'omitnan'), ...
            mean(A2,'omitnan'),mean(A3,'omitnan'), ...
            m_op,lo_op,hi_op, ...
            m_res,lo_res,hi_res, ...
            m_int,lo_int,hi_int, ...
            m_total,lo_total,hi_total};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'regime','metric', ...
    'G0','G1','G2','G3', ...
    'operator_effect','operator_ci_low','operator_ci_high', ...
    'residual_effect','residual_ci_low','residual_ci_high', ...
    'interaction_effect','interaction_ci_low','interaction_ci_high', ...
    'total_G3_minus_G0','total_ci_low','total_ci_high'});

end

%% ========================================================================
function [A0,A1,A2,A3,seq] = aligned_group_vectors(T,metric)

groups = ["G0_WeakOnly","G1_OperatorOnly", ...
          "G2_ResidualOnly","G3_FullCLEAN"];

Tg = cell(4,1);

for ig = 1:4
    Tg{ig} = sortrows( ...
        T(string(T.group)==groups(ig),:), ...
        {'base_trial_id'});
end

ids = Tg{1}.base_trial_id;

for ig = 2:4
    if ~isequal(ids,Tg{ig}.base_trial_id)
        error('Ownership groups do not have identical base_trial_id sets.');
    end
end

seq = Tg{1}.sequence_id;

switch metric
    case 'q_error'
        A0 = Tg{1}.q_error;
        A1 = Tg{2}.q_error;
        A2 = Tg{3}.q_error;
        A3 = Tg{4}.q_error;

    case 'failure'
        A0 = double(~Tg{1}.success);
        A1 = double(~Tg{2}.success);
        A2 = double(~Tg{3}.success);
        A3 = double(~Tg{4}.success);

    otherwise
        error('Unknown aligned metric.');
end

end

%% ========================================================================
function [m,lo,hi] = cluster_bootstrap_mean(x,seq,B)

x = double(x(:));
seq = double(seq(:));

valid = isfinite(x) & isfinite(seq);
x = x(valid);
seq = seq(valid);

u = unique(seq);
K = numel(u);

if K==0
    m = NaN;
    lo = NaN;
    hi = NaN;
    return;
end

% Collapse to one mean per complete Monte-Carlo sequence.
seq_mean = nan(K,1);

for k = 1:K
    mm = seq==u(k);
    seq_mean(k) = mean(x(mm),'omitnan');
end

m = mean(seq_mean,'omitnan');

if K<2 || B<=0
    lo = NaN;
    hi = NaN;
    return;
end

boot = nan(B,1);

for b = 1:B
    idx = randi(K,K,1);
    boot(b) = mean(seq_mean(idx),'omitnan');
end

lo = percentile_local(boot,2.5);
hi = percentile_local(boot,97.5);

end

%% ========================================================================
function q = percentile_local(x,p)

x = sort(double(x(isfinite(x))));
n = numel(x);

if n==0
    q = NaN;
    return;
end

if n==1
    q = x(1);
    return;
end

p = min(max(p,0),100);
pos = 1 + (n-1)*(p/100);

i1 = floor(pos);
i2 = ceil(pos);

if i1==i2
    q = x(i1);
else
    w = pos-i1;
    q = (1-w)*x(i1) + w*x(i2);
end

end

%% ========================================================================
function D = build_decision_summary( ...
    group_summary,ownership_effects,g3_cohort_summary, ...
    firstorder_summary,contrib_summary)

regimes = unique(string(group_summary.regime),'stable');
rows = {};

for ir = 1:numel(regimes)
    r = char(regimes(ir));

    G0 = get_group_row(group_summary,r,'G0_WeakOnly');
    G1 = get_group_row(group_summary,r,'G1_OperatorOnly');
    G2 = get_group_row(group_summary,r,'G2_ResidualOnly');
    G3 = get_group_row(group_summary,r,'G3_FullCLEAN');

    Eabs = ownership_effects( ...
        strcmp(ownership_effects.regime,r) & ...
        strcmp(ownership_effects.metric,'AbsError'),:);

    Efail = ownership_effects( ...
        strcmp(ownership_effects.regime,r) & ...
        strcmp(ownership_effects.metric,'Failure'),:);

    FO = firstorder_summary( ...
        strcmp(firstorder_summary.regime,r) & ...
        strcmp(firstorder_summary.group,'G3_FullCLEAN') & ...
        strcmp(firstorder_summary.subset,'NearShift'),:);

    C = contrib_summary( ...
        strcmp(contrib_summary.regime,r) & ...
        strcmp(contrib_summary.group,'G3_FullCLEAN') & ...
        strcmp(contrib_summary.subset,'NearShift'),:);

    if isempty(C)
        dominant_term = '';
        dominant_abs_shift = NaN;
    else
        [mx,ii] = max(C.median_abs_shift);
        if isempty(ii) || ~isfinite(mx)
            dominant_term = '';
            dominant_abs_shift = NaN;
        else
            dominant_term = C.term{ii};
            dominant_abs_shift = mx;
        end
    end

    CF0 = g3_cohort_summary( ...
        strcmp(g3_cohort_summary.regime,r) & ...
        strcmp(g3_cohort_summary.group,'G0_WeakOnly'),:);

    CF1 = g3_cohort_summary( ...
        strcmp(g3_cohort_summary.regime,r) & ...
        strcmp(g3_cohort_summary.group,'G1_OperatorOnly'),:);

    CF2 = g3_cohort_summary( ...
        strcmp(g3_cohort_summary.regime,r) & ...
        strcmp(g3_cohort_summary.group,'G2_ResidualOnly'),:);

    rows(end+1,:) = { ... %#ok<AGROW>
        r, ...
        G0.failure_rate,G1.failure_rate,G2.failure_rate,G3.failure_rate, ...
        G0.q_mae,G1.q_mae,G2.q_mae,G3.q_mae, ...
        G1.median_normalized_weak_curvature / ...
            max(G0.median_normalized_weak_curvature,eps), ...
        G1.mean_weak_retention, ...
        Eabs.operator_effect,Eabs.operator_ci_low,Eabs.operator_ci_high, ...
        Eabs.residual_effect,Eabs.residual_ci_low,Eabs.residual_ci_high, ...
        Eabs.interaction_effect,Eabs.interaction_ci_low,Eabs.interaction_ci_high, ...
        Efail.operator_effect,Efail.residual_effect,Efail.interaction_effect, ...
        scalar_or_nan(FO,'pearson_r'), ...
        scalar_or_nan(FO,'sign_agreement'), ...
        dominant_term,dominant_abs_shift, ...
        scalar_or_nan(CF0,'counterfactual_success_rate'), ...
        scalar_or_nan(CF1,'counterfactual_success_rate'), ...
        scalar_or_nan(CF2,'counterfactual_success_rate')};
end

D = cell2table(rows, ...
    'VariableNames',{ ...
    'regime', ...
    'G0_failure','G1_failure','G2_failure','G3_failure', ...
    'G0_mae','G1_mae','G2_mae','G3_mae', ...
    'operator_curvature_ratio_G1_over_G0', ...
    'operator_weak_retention_G1', ...
    'abs_operator_effect','abs_operator_ci_low','abs_operator_ci_high', ...
    'abs_residual_effect','abs_residual_ci_low','abs_residual_ci_high', ...
    'abs_interaction_effect','abs_interaction_ci_low','abs_interaction_ci_high', ...
    'failure_operator_effect','failure_residual_effect','failure_interaction_effect', ...
    'G3_nearshift_firstorder_pearson', ...
    'G3_nearshift_firstorder_sign_agreement', ...
    'G3_nearshift_dominant_term', ...
    'G3_nearshift_dominant_abs_shift', ...
    'G3_nearshift_if_G0_success', ...
    'G3_nearshift_if_G1_success', ...
    'G3_nearshift_if_G2_success'});

end

%% ========================================================================
function R = get_group_row(T,regime,group)

mm = strcmp(T.regime,regime) & strcmp(T.group,group);

if sum(mm)~=1
    error('Expected one summary row for %s / %s.',regime,group);
end

R = T(mm,:);

end

%% ========================================================================
function v = scalar_or_nan(T,varname)

if isempty(T)
    v = NaN;
else
    v = T.(varname)(1);
end

end

%% ========================================================================
function write_summary( ...
    out_path,cfg,group_summary,firstorder_summary, ...
    contrib_summary,g3_cohort_summary,ownership_effects, ...
    sanity_summary,decision,time_smooth,time_abrupt)

fid = fopen(fullfile(out_path,'summary.txt'),'w');

fprintf(fid,'EXP009-C3-B3B.1 NearShift Mechanism Ownership Test\n');
fprintf(fid,'=================================================\n\n');

fprintf(fid,'Research boundary\n');
fprintf(fid,'-----------------\n');
fprintf(fid,'q_strong remains known/oracle.\n');
fprintf(fid,'SNR = %.2f dB.\n',cfg.snr_db);
fprintf(fid,'q_weak = %.6f.\n',cfg.q_weak);
fprintf(fid,'q step = %.6f.\n',cfg.q_search_step);
fprintf(fid,'success tau_q = %.6f.\n',cfg.tau_q);
fprintf(fid,'near-shift max = %.6f.\n',cfg.near_shift_tol);
fprintf(fid,'paired noise across G0-G3 = YES.\n');
fprintf(fid,'projection atom is fitted once from full mixture per trial/line.\n');
fprintf(fid,'bootstrap unit = complete Monte-Carlo sequence.\n\n');

fprintf(fid,'Ownership groups\n');
fprintf(fid,'----------------\n');
fprintf(fid,'G0 WeakOnly      = Sw + N\n');
fprintf(fid,'G1 OperatorOnly  = Ew + En\n');
fprintf(fid,'G2 ResidualOnly  = Sw + N + Es\n');
fprintf(fid,'G3 FullCLEAN     = Ew + En + Es\n\n');

fprintf(fid,'Sanity checks\n');
fprintf(fid,'-------------\n');
for i = 1:height(sanity_summary)
    fprintf(fid,[ ...
        '%s oracleSubtractMismatch=%g fullDecompMismatch=%g\n'], ...
        char(sanity_summary.regime(i)), ...
        sanity_summary.max_oracle_subtract_mismatch(i), ...
        sanity_summary.max_full_decomposition_mismatch(i));
end

fprintf(fid,'\nGroup summary\n');
fprintf(fid,'-------------\n');
for i = 1:height(group_summary)
    fprintf(fid,[ ...
        '%s %-18s n=%d success=%.5f failure=%.5f nearAll=%.5f ' ...
        'MAE=%g RMSE=%g medAE=%g retention=%.5f curvNorm=%g ' ...
        'weakBiasAbs=%g\n'], ...
        group_summary.regime{i}, ...
        group_summary.group{i}, ...
        group_summary.n(i), ...
        group_summary.success_rate(i), ...
        group_summary.failure_rate(i), ...
        group_summary.nearshift_rate_all(i), ...
        group_summary.q_mae(i), ...
        group_summary.q_rmse(i), ...
        group_summary.q_median_abs_error(i), ...
        group_summary.mean_weak_retention(i), ...
        group_summary.median_normalized_weak_curvature(i), ...
        group_summary.mean_abs_weak_baseline_bias(i));
end

fprintf(fid,'\nOwnership effects with sequence-cluster bootstrap 95%% CI\n');
fprintf(fid,'------------------------------------------------------\n');
for i = 1:height(ownership_effects)
    fprintf(fid,[ ...
        '%s %-8s | G0=%g G1=%g G2=%g G3=%g | ' ...
        'Operator=%+g [%+g,%+g] | ' ...
        'Residual=%+g [%+g,%+g] | ' ...
        'Interaction=%+g [%+g,%+g] | ' ...
        'Total=%+g [%+g,%+g]\n'], ...
        ownership_effects.regime{i}, ...
        ownership_effects.metric{i}, ...
        ownership_effects.G0(i), ...
        ownership_effects.G1(i), ...
        ownership_effects.G2(i), ...
        ownership_effects.G3(i), ...
        ownership_effects.operator_effect(i), ...
        ownership_effects.operator_ci_low(i), ...
        ownership_effects.operator_ci_high(i), ...
        ownership_effects.residual_effect(i), ...
        ownership_effects.residual_ci_low(i), ...
        ownership_effects.residual_ci_high(i), ...
        ownership_effects.interaction_effect(i), ...
        ownership_effects.interaction_ci_low(i), ...
        ownership_effects.interaction_ci_high(i), ...
        ownership_effects.total_G3_minus_G0(i), ...
        ownership_effects.total_ci_low(i), ...
        ownership_effects.total_ci_high(i));
end

fprintf(fid,'\nG3-NearShift-conditioned counterfactual\n');
fprintf(fid,'--------------------------------------\n');
for i = 1:height(g3_cohort_summary)
    fprintf(fid,[ ...
        '%s %-18s n=%d success=%.5f near=%.5f MAE=%g medAE=%g\n'], ...
        g3_cohort_summary.regime{i}, ...
        g3_cohort_summary.group{i}, ...
        g3_cohort_summary.n_g3_nearshift_cohort(i), ...
        g3_cohort_summary.counterfactual_success_rate(i), ...
        g3_cohort_summary.counterfactual_nearshift_rate(i), ...
        g3_cohort_summary.q_mae(i), ...
        g3_cohort_summary.q_median_abs_error(i));
end

fprintf(fid,'\nG3 NearShift first-order validation\n');
fprintf(fid,'----------------------------------\n');
for regime = ["Smooth","Abrupt"]
    mm = strcmp(firstorder_summary.regime,char(regime)) & ...
         strcmp(firstorder_summary.group,'G3_FullCLEAN') & ...
         strcmp(firstorder_summary.subset,'NearShift');

    if any(mm)
        i = find(mm,1);
        fprintf(fid,[ ...
            '%s n=%d Pearson=%.6f slope=%.6f RMSE=%g sign=%.6f\n'], ...
            char(regime), ...
            firstorder_summary.n_valid(i), ...
            firstorder_summary.pearson_r(i), ...
            firstorder_summary.fit_slope_pred_vs_measured(i), ...
            firstorder_summary.prediction_rmse(i), ...
            firstorder_summary.sign_agreement(i));
    end
end

fprintf(fid,'\nG3 NearShift perturbation anatomy\n');
fprintf(fid,'--------------------------------\n');
for i = 1:height(contrib_summary)
    if strcmp(contrib_summary.group{i},'G3_FullCLEAN') && ...
       strcmp(contrib_summary.subset{i},'NearShift')

        fprintf(fid,[ ...
            '%s %-20s medianAbsShift=%g meanAbsShift=%g\n'], ...
            contrib_summary.regime{i}, ...
            contrib_summary.term{i}, ...
            contrib_summary.median_abs_shift(i), ...
            contrib_summary.mean_abs_shift(i));
    end
end

fprintf(fid,'\nDecision summary\n');
fprintf(fid,'----------------\n');
for i = 1:height(decision)
    fprintf(fid,[ ...
        '%s | failure G0/G1/G2/G3=%.4f/%.4f/%.4f/%.4f | ' ...
        'MAE G0/G1/G2/G3=%g/%g/%g/%g | ' ...
        'curvRatio=%.4f retention=%.4f | ' ...
        'AbsEff op/res/int=%+g/%+g/%+g | ' ...
        'FailEff op/res/int=%+g/%+g/%+g | ' ...
        'G3FO-r=%.4f dominant=%s (%g)\n'], ...
        decision.regime{i}, ...
        decision.G0_failure(i), ...
        decision.G1_failure(i), ...
        decision.G2_failure(i), ...
        decision.G3_failure(i), ...
        decision.G0_mae(i), ...
        decision.G1_mae(i), ...
        decision.G2_mae(i), ...
        decision.G3_mae(i), ...
        decision.operator_curvature_ratio_G1_over_G0(i), ...
        decision.operator_weak_retention_G1(i), ...
        decision.abs_operator_effect(i), ...
        decision.abs_residual_effect(i), ...
        decision.abs_interaction_effect(i), ...
        decision.failure_operator_effect(i), ...
        decision.failure_residual_effect(i), ...
        decision.failure_interaction_effect(i), ...
        decision.G3_nearshift_firstorder_pearson(i), ...
        decision.G3_nearshift_dominant_term{i}, ...
        decision.G3_nearshift_dominant_abs_shift(i));
end

fprintf(fid,'\nInterpretation branches\n');
fprintf(fid,'-----------------------\n');
fprintf(fid,['Branch A / intrinsic noise-limited: G0~G1~G2~G3, ' ...
    'WeakNoiseCross dominates, little operator/residual/interaction excess.\n']);
fprintf(fid,['Branch B / operator amplification: G1~G3 >> G0 while G2~G0; ' ...
    'check weak retention and normalized curvature loss.\n']);
fprintf(fid,['Branch C / residual dominated: G2~G3 >> G0 while G1~G0; ' ...
    'expect WeakStrongCross/residual geometry to strengthen.\n']);
fprintf(fid,['Branch D / interaction dominated: G1>G0 and/or G2>G0, but G3 exceeds ' ...
    'their additive expectation; interaction CI should exclude zero.\n']);
fprintf(fid,['Do not select a branch from bar height alone. Use paired effect sizes, ' ...
    'cluster-bootstrap CIs, the G3-conditioned counterfactual, and first-order anatomy together.\n']);

fprintf(fid,'\nRuntime\n');
fprintf(fid,'-------\n');
fprintf(fid,'Smooth %.3f s\n',time_smooth);
fprintf(fid,'Abrupt %.3f s\n',time_abrupt);

fclose(fid);

end

%% ========================================================================
function make_figures( ...
    out_path,cfg,T_smooth,T_abrupt, ...
    group_summary,contrib_summary, ...
    g3_cohort_summary,ownership_effects)

plot_abs_error_cdf( ...
    T_smooth,"Smooth",cfg, ...
    fullfile(out_path,'fig01_smooth_abs_error_cdf.png'));

plot_abs_error_cdf( ...
    T_abrupt,"Abrupt",cfg, ...
    fullfile(out_path,'fig02_abrupt_abs_error_cdf.png'));

%% Fig 3: failure rate
groups = ["G0_WeakOnly","G1_OperatorOnly", ...
          "G2_ResidualOnly","G3_FullCLEAN"];
regimes = ["Smooth","Abrupt"];

Y = nan(4,2);
for ig = 1:4
    for ir = 1:2
        mm = strcmp(group_summary.group,char(groups(ig))) & ...
             strcmp(group_summary.regime,char(regimes(ir)));
        Y(ig,ir) = group_summary.failure_rate(mm);
    end
end

fig = figure('Visible',cfg.figure_visible);
bar(Y);
ylim([0 1]);
xticks(1:4);
xticklabels({'G0 WeakOnly','G1 OperatorOnly', ...
             'G2 ResidualOnly','G3 FullCLEAN'});
xtickangle(20);
ylabel('Failure rate');
title('C3-B3B.1 Ownership Group Failure Rates');
legend(regimes,'Location','best');
grid on;
exportgraphics(fig, ...
    fullfile(out_path,'fig03_group_failure_rates.png'), ...
    'Resolution',180);
close(fig);

%% Fig 4-5: G3 NearShift paired counterfactual error
plot_g3_cohort_box( ...
    T_smooth,"Smooth",cfg, ...
    fullfile(out_path,'fig04_smooth_g3_nearshift_counterfactual.png'));

plot_g3_cohort_box( ...
    T_abrupt,"Abrupt",cfg, ...
    fullfile(out_path,'fig05_abrupt_g3_nearshift_counterfactual.png'));

%% Fig 6: normalized weak curvature
Y = nan(4,2);
for ig = 1:4
    for ir = 1:2
        mm = strcmp(group_summary.group,char(groups(ig))) & ...
             strcmp(group_summary.regime,char(regimes(ir)));
        Y(ig,ir) = ...
            group_summary.median_normalized_weak_curvature(mm);
    end
end

fig = figure('Visible',cfg.figure_visible);
bar(Y);
xticks(1:4);
xticklabels({'G0 WeakOnly','G1 OperatorOnly', ...
             'G2 ResidualOnly','G3 FullCLEAN'});
xtickangle(20);
ylabel('Median normalized weak curvature');
title('C3-B3B.1 Weak-Peak Curvature Under Ownership Groups');
legend(regimes,'Location','best');
grid on;
exportgraphics(fig, ...
    fullfile(out_path,'fig06_group_weak_curvature.png'), ...
    'Resolution',180);
close(fig);

%% Fig 7-8: contribution anatomy by group/regime
plot_group_contributions( ...
    contrib_summary,"Smooth",cfg, ...
    fullfile(out_path,'fig07_smooth_contribution_anatomy.png'));

plot_group_contributions( ...
    contrib_summary,"Abrupt",cfg, ...
    fullfile(out_path,'fig08_abrupt_contribution_anatomy.png'));

%% Fig 9: ownership effect sizes for AbsError
plot_ownership_effects( ...
    ownership_effects,'AbsError',cfg, ...
    fullfile(out_path,'fig09_abs_error_ownership_effects.png'));

%% Fig 10: G3 cohort success rate
Y = nan(4,2);
for ig = 1:4
    for ir = 1:2
        mm = strcmp(g3_cohort_summary.group,char(groups(ig))) & ...
             strcmp(g3_cohort_summary.regime,char(regimes(ir)));
        Y(ig,ir) = ...
            g3_cohort_summary.counterfactual_success_rate(mm);
    end
end

fig = figure('Visible',cfg.figure_visible);
bar(Y);
ylim([0 1]);
xticks(1:4);
xticklabels({'G0 WeakOnly','G1 OperatorOnly', ...
             'G2 ResidualOnly','G3 FullCLEAN'});
xtickangle(20);
ylabel('Success rate on G3-NearShift cohort');
title('C3-B3B.1 Counterfactual Rescue of G3 NearShift Trials');
legend(regimes,'Location','best');
grid on;
exportgraphics(fig, ...
    fullfile(out_path,'fig10_g3_cohort_counterfactual_success.png'), ...
    'Resolution',180);
close(fig);

end

%% ========================================================================
function plot_abs_error_cdf(T,regime,cfg,filename)

groups = ["G0_WeakOnly","G1_OperatorOnly", ...
          "G2_ResidualOnly","G3_FullCLEAN"];

fig = figure('Visible',cfg.figure_visible);
hold on;

for ig = 1:4
    Tg = T(string(T.group)==groups(ig),:);
    x = sort(abs(Tg.q_error));
    x = x(isfinite(x));

    if isempty(x)
        continue;
    end

    y = (1:numel(x)).'/numel(x);
    plot(x,y,'LineWidth',1.2);
end

xline(cfg.tau_q,'--');
xline(cfg.near_shift_tol,':');

xlabel('|q estimate - q_w|');
ylabel('Empirical CDF');
title(sprintf( ...
    'C3-B3B.1 %s Absolute q-Error CDF',char(regime)));
legend({'G0 WeakOnly','G1 OperatorOnly', ...
        'G2 ResidualOnly','G3 FullCLEAN', ...
        'success \tau_q','NearShift max'}, ...
        'Location','best');
grid on;

exportgraphics(fig,filename,'Resolution',180);
close(fig);

end

%% ========================================================================
function plot_g3_cohort_box(T,regime,cfg,filename)

T3 = T(string(T.group)=="G3_FullCLEAN",:);
cohort_ids = T3.base_trial_id(logical(T3.nearshift));

groups = ["G0_WeakOnly","G1_OperatorOnly", ...
          "G2_ResidualOnly","G3_FullCLEAN"];

labels = {'G0 WeakOnly','G1 OperatorOnly', ...
          'G2 ResidualOnly','G3 FullCLEAN'};

values = [];
group_index = [];

for ig = 1:4
    Tg = T(string(T.group)==groups(ig) & ...
           ismember(T.base_trial_id,cohort_ids),:);

    e = abs(Tg.q_error);
    values = [values;e]; %#ok<AGROW>
    group_index = [group_index;ig*ones(numel(e),1)]; %#ok<AGROW>
end

group_cat = categorical(group_index,1:4,labels);
valid = isfinite(values);

fig = figure('Visible',cfg.figure_visible);
boxchart(group_cat(valid),values(valid));

yline(cfg.tau_q,'--');
yline(cfg.near_shift_tol,':');

xtickangle(20);
ylabel('|q estimate - q_w|');
title(sprintf( ...
    'C3-B3B.1 %s G3-NearShift Counterfactual',char(regime)));
grid on;

exportgraphics(fig,filename,'Resolution',180);
close(fig);

end

%% ========================================================================
function plot_group_contributions(contrib_summary,regime,cfg,filename)

groups = ["G0_WeakOnly","G1_OperatorOnly", ...
          "G2_ResidualOnly","G3_FullCLEAN"];
terms = ["StrongPower","NoisePower","WeakStrongCross", ...
         "WeakNoiseCross","StrongNoiseCross"];

Y = nan(numel(terms),numel(groups));

for it = 1:numel(terms)
    for ig = 1:numel(groups)
        mm = strcmp(contrib_summary.regime,char(regime)) & ...
             strcmp(contrib_summary.group,char(groups(ig))) & ...
             strcmp(contrib_summary.subset,'NearShift') & ...
             strcmp(contrib_summary.term,char(terms(it)));

        if any(mm)
            Y(it,ig) = contrib_summary.median_abs_shift(find(mm,1));
        end
    end
end

fig = figure('Visible',cfg.figure_visible);
bar(Y);

xticks(1:numel(terms));
xticklabels(terms);
xtickangle(25);

ylabel('Median |predicted q-shift contribution|');
title(sprintf( ...
    'C3-B3B.1 %s NearShift Perturbation Anatomy',char(regime)));
legend({'G0','G1','G2','G3'},'Location','best');
grid on;

exportgraphics(fig,filename,'Resolution',180);
close(fig);

end

%% ========================================================================
function plot_ownership_effects(S,metric,cfg,filename)

regimes = ["Smooth","Abrupt"];
effects = ["Operator","Residual","Interaction"];

Y = nan(3,2);
EL = nan(3,2);
EU = nan(3,2);

for ir = 1:2
    mm = strcmp(S.regime,char(regimes(ir))) & ...
         strcmp(S.metric,metric);

    if ~any(mm)
        continue;
    end

    i = find(mm,1);

    vals = [ ...
        S.operator_effect(i); ...
        S.residual_effect(i); ...
        S.interaction_effect(i)];

    los = [ ...
        S.operator_ci_low(i); ...
        S.residual_ci_low(i); ...
        S.interaction_ci_low(i)];

    his = [ ...
        S.operator_ci_high(i); ...
        S.residual_ci_high(i); ...
        S.interaction_ci_high(i)];

    Y(:,ir) = vals;
    EL(:,ir) = vals-los;
    EU(:,ir) = his-vals;
end

fig = figure('Visible',cfg.figure_visible);
b = bar(Y);
hold on;

for ir = 1:2
    x = b(ir).XEndPoints;
    errorbar(x,Y(:,ir),EL(:,ir),EU(:,ir), ...
        'k','LineStyle','none','CapSize',4);
end

yline(0,'--');
xticks(1:3);
xticklabels(effects);
ylabel(sprintf('%s effect',metric));
title(sprintf('C3-B3B.1 %s Ownership Effects',metric));
legend(regimes,'Location','best');
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
function v = central_slope(x,i,h)

if i<=1 || i>=numel(x)
    v = NaN;
    return;
end

v = (x(i+1)-x(i-1))/(2*h);

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
