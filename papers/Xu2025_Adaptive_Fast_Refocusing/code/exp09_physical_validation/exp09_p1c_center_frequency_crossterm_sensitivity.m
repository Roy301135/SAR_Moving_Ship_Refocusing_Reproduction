function results = exp09_p1c_center_frequency_crossterm_sensitivity()
%EXP09_P1C_CENTER_FREQUENCY_CROSSTERM_SENSITIVITY
% EXP009 / Physical Validation Track / P1C
%
% Center-Frequency / Cross-Term Sensitivity Audit
%
% Research question
% -----------------
% P1B found that the five Wang-2023 velocity components cannot be stably
% recovered from the FrAc energy curve under the reported/derived aperture
% scales when all unreported center frequencies are set to b_i=0.
%
% Wang Eq. (13), however, explicitly models each MC-LFM component as:
%
%   l_i[m] = exp{j2pi(0.5*a_i*m^2 + b_i*m)}
%
% where b_i is a component center frequency. The exact b_i values used in
% the five-point experiment are not reported.
%
% P1C therefore asks:
%
%   Is the P1B failure mainly caused by unresolved b_i / cross-term
%   geometry, or is the aperture-limited auto-term resolution itself
%   already insufficient?
%
% Design
% ------
% 1) Fix all physical chirp rates a_i using the Wang/Xu mapping.
% 2) Fix representative R0/H=sqrt(2).
% 3) Use two aperture modes:
%      - Paper1s
%      - BeamDerived
% 4) Sweep adjacent b_i spacing in Fourier-bin units:
%
%      gamma = [0, 0.5, 1, 2, 4]
%
%      b_i = [-2,-1,0,1,2] * gamma/N
%
% 5) For every gamma/aperture:
%      - compute the ideal INCOHERENT auto-term energy envelope;
%      - compute the coherent total FrAc response;
%      - decompose total response into coherent-auto, cross, and
%        auto-cross interaction contributions;
%      - Monte-Carlo unknown initial phases.
%
% Key interpretation
% ------------------
% If ideal incoherent auto energy itself cannot resolve five peaks, then
% the main limit is aperture/response-width resolution and changing b_i
% cannot fully solve the problem.
%
% If ideal auto resolves five peaks but total response does not at gamma=0,
% and total recovery improves as gamma increases while cross contamination
% decreases, then b_i/cross-term geometry is a credible missing factor.
%
% This is the FINAL reproduction audit. After P1C, proceed to PA4 with
% explicit physical/controlled parameter labels regardless of outcome.
%
% Run:
%   results = exp09_p1c_center_frequency_crossterm_sensitivity;

cfg = config_exp09_p1c_center_frequency_crossterm_sensitivity();

%% Output path
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.output_dir)
    out_path = fullfile( ...
        paper_root,'results','exp09_physical_validation', ...
        'exp09_p1c_center_frequency_crossterm_sensitivity');
else
    out_path = cfg.output_dir;
end

if ~exist(out_path,'dir')
    mkdir(out_path);
end

%% Physical mapping
lambda = cfg.c/cfg.fc_hz;
R0 = cfg.platform_height_m*cfg.slant_range_factor;
beamwidth_rad = cfg.beamwidth_scale*lambda/cfg.antenna_length_m;

v = cfg.target_velocity_mps(:).';
A = cfg.component_amplitudes(:).';

[K_A,K_SAR,K_res] = residual_fm_rates(v,R0,lambda,cfg);

a_true = K_res/(cfg.prf_hz^2);
beta_true = atan(a_true);
alpha_true = beta_true + pi/2;

beta_sorted = sort(beta_true);
min_beta_sep = min(abs(diff(beta_sorted)));

beta_grid = build_beta_grid(beta_true,min_beta_sep,cfg);

%% Aperture prescriptions
T_paper = cfg.paper_aperture_time_s;
N_paper = max(32,round(cfg.prf_hz*T_paper));

T_beam = R0*beamwidth_rad/cfg.platform_velocity_mps;
N_beam = max(32,round(cfg.prf_hz*T_beam));

aperture_names = ["Paper1s","BeamDerived"];
N_list = [N_paper,N_beam];
T_target_list = [T_paper,T_beam];

rng(cfg.phase_seed,'twister');

%% Sweep
rows = {};
store = struct();
row = 0;

for ia = 1:2

    aperture_name = aperture_names(ia);
    N = N_list(ia);
    T_target = T_target_list(ia);
    T_actual = (N-1)/cfg.prf_hz;

    max_lag = max(2,min(N-2, ...
        round(cfg.max_lag_fraction*N)));

    for ig = 1:numel(cfg.gamma_bins)

        gamma = cfg.gamma_bins(ig);

        delta_b = gamma/N;
        b = cfg.center_frequency_index*delta_b;

        % Build zero-phase component bank. Unknown phase enters only as a
        % complex scalar per component.
        S0 = complex(zeros(5,N));

        for ic = 1:5
            S0(ic,:) = synth_discrete_lfm( ...
                N,A(ic),a_true(ic),b(ic),0);
        end

        % Precompute component auto responses.
        % Rii: beta x lag x component
        Rii = component_auto_response( ...
            S0,beta_grid,max_lag,cfg);

        % "Ideal incoherent auto" excludes all inter-component coherent
        % interference and therefore diagnoses pure response-width limits.
        E_auto_incoherent = ...
            squeeze(sum(sum(abs(Rii).^2,2),3));

        E_auto_incoherent = normalize_curve(E_auto_incoherent);

        [ideal_hit,ideal_err] = match_true_beta_to_peaks( ...
            beta_grid,E_auto_incoherent,beta_true, ...
            cfg.peak_match_tolerance_fraction*min_beta_sep, ...
            cfg.min_peak_prominence_fraction);

        ideal_all5 = all(ideal_hit);

        % Coherent auto response is sum_i R_ii. Its energy can differ from
        % the incoherent auto baseline because different auto terms can
        % interfere in the integrated statistic.
        R_auto = sum(Rii,3);

        E_auto_coherent = sum(abs(R_auto).^2,2);
        E_auto_coherent = normalize_curve(E_auto_coherent);

        % Phase Monte Carlo
        E_total_acc = zeros(numel(beta_grid),1);
        E_cross_acc = zeros(numel(beta_grid),1);
        E_interaction_acc = zeros(numel(beta_grid),1);

        all5_hit = false(cfg.num_phase_mc,1);

        cross_ratio_global = nan(cfg.num_phase_mc,1);
        cross_ratio_true = nan(cfg.num_phase_mc,1);
        interaction_ratio_true = nan(cfg.num_phase_mc,1);

        for imc = 1:cfg.num_phase_mc

            phi = 2*pi*rand(5,1);
            phase_vec = exp(1j*phi);

            xmix = phase_vec.'*S0;

            R_total = total_frac_response( ...
                xmix,beta_grid,max_lag,cfg);

            % R_auto is independent of initial component phase because each
            % self-product x_i[m+k] conj(x_i[m]) cancels phi_i.
            R_cross = R_total-R_auto;

            E_total_raw = sum(abs(R_total).^2,2);
            E_auto_raw = sum(abs(R_auto).^2,2);
            E_cross_raw = sum(abs(R_cross).^2,2);

            E_interaction_raw = ...
                E_total_raw-E_auto_raw-E_cross_raw;

            E_total = normalize_curve(E_total_raw);

            E_total_acc = E_total_acc+E_total;
            E_cross_acc = E_cross_acc + ...
                E_cross_raw/max(max(E_auto_raw),eps);

            E_interaction_acc = E_interaction_acc + ...
                E_interaction_raw/max(max(E_auto_raw),eps);

            [hit,~] = match_true_beta_to_peaks( ...
                beta_grid,E_total,beta_true, ...
                cfg.peak_match_tolerance_fraction*min_beta_sep, ...
                cfg.min_peak_prominence_fraction);

            all5_hit(imc) = all(hit);

            cross_ratio_global(imc) = ...
                sum(E_cross_raw)/max(sum(E_auto_raw),eps);

            [~,idx_true] = nearest_indices( ...
                beta_grid,beta_true);

            auto_true = E_auto_raw(idx_true);
            cross_true = E_cross_raw(idx_true);
            int_true = E_interaction_raw(idx_true);

            cross_ratio_true(imc) = ...
                median(cross_true./max(auto_true,eps));

            interaction_ratio_true(imc) = ...
                median(abs(int_true)./max(auto_true,eps));
        end

        E_total_avg = E_total_acc/cfg.num_phase_mc;
        E_cross_avg = E_cross_acc/cfg.num_phase_mc;
        E_interaction_avg = E_interaction_acc/cfg.num_phase_mc;

        [avg_hit,avg_err] = match_true_beta_to_peaks( ...
            beta_grid,E_total_avg,beta_true, ...
            cfg.peak_match_tolerance_fraction*min_beta_sep, ...
            cfg.min_peak_prominence_fraction);

        avg_all5 = all(avg_hit);
        phase_all5_rate = mean(all5_hit);

        ideal_err_valid = ideal_err(isfinite(ideal_err));
        avg_err_valid = avg_err(isfinite(avg_err));

        if isempty(ideal_err_valid)
            ideal_rmse = NaN;
        else
            ideal_rmse = sqrt(mean(ideal_err_valid.^2));
        end

        if isempty(avg_err_valid)
            avg_rmse = NaN;
        else
            avg_rmse = sqrt(mean(avg_err_valid.^2));
        end

        % Compare cross contamination to gamma=0 later in decision summary.
        row = row+1;

        rows(end+1,:) = { ... %#ok<AGROW>
            char(aperture_name), ...
            N,T_target,T_actual, ...
            gamma,delta_b,delta_b*cfg.prf_hz, ...
            double(ideal_all5),ideal_rmse, ...
            double(avg_all5),avg_rmse, ...
            phase_all5_rate, ...
            median(cross_ratio_global,'omitnan'), ...
            median(cross_ratio_true,'omitnan'), ...
            median(interaction_ratio_true,'omitnan')};

        key = sprintf('A%d_G%d',ia,ig);

        store.(key) = struct( ...
            'aperture_name',aperture_name, ...
            'N',N, ...
            'T_target',T_target, ...
            'T_actual',T_actual, ...
            'gamma',gamma, ...
            'delta_b',delta_b, ...
            'b',b, ...
            'beta_grid',beta_grid, ...
            'beta_true',beta_true, ...
            'E_auto_incoherent',E_auto_incoherent, ...
            'E_auto_coherent',E_auto_coherent, ...
            'E_total_avg',E_total_avg, ...
            'E_cross_avg',E_cross_avg, ...
            'E_interaction_avg',E_interaction_avg, ...
            'ideal_all5',ideal_all5, ...
            'avg_all5',avg_all5, ...
            'phase_all5_rate',phase_all5_rate);
    end
end

sweep_table = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','azimuth_samples', ...
    'target_aperture_time_s','actual_observation_time_s', ...
    'gamma_adjacent_bin_spacing', ...
    'delta_b_cycles_per_sample', ...
    'delta_center_frequency_hz', ...
    'ideal_incoherent_auto_all5_detected', ...
    'ideal_auto_localization_rmse_rad', ...
    'phase_averaged_total_all5_detected', ...
    'phase_averaged_total_localization_rmse_rad', ...
    'phase_mc_all5_detection_rate', ...
    'median_cross_to_auto_global', ...
    'median_cross_to_auto_at_true_beta', ...
    'median_abs_interaction_to_auto_at_true_beta'});

writetable(sweep_table, ...
    fullfile(out_path,'p1c_sweep_summary.csv'));

%% Component parameter table
component_table = table( ...
    (1:5).', ...
    v(:), ...
    K_A(:), ...
    repmat(K_SAR,5,1), ...
    K_res(:), ...
    a_true(:), ...
    beta_true(:), ...
    alpha_true(:), ...
    'VariableNames',{ ...
    'component','azimuth_velocity_mps', ...
    'K_A_Hz_per_s','K_SAR_Hz_per_s', ...
    'K_residual_Hz_per_s', ...
    'discrete_chirp_rate_a_cycles_per_sample2', ...
    'predicted_FrAc_beta_rad', ...
    'predicted_FrFT_alpha_rad'});

writetable(component_table, ...
    fullfile(out_path,'representative_component_parameters.csv'));

%% Decision summary
decision = build_decision_summary( ...
    sweep_table,cfg);

writetable(decision, ...
    fullfile(out_path,'p1c_decision_summary.csv'));

%% Text summary
write_summary( ...
    out_path,cfg,lambda,R0,beamwidth_rad, ...
    component_table,sweep_table,decision);

%% Figures
make_figures( ...
    out_path,cfg,sweep_table,store);

%% Save
results = struct();
results.cfg = cfg;
results.lambda = lambda;
results.R0 = R0;
results.beamwidth_rad = beamwidth_rad;
results.component_table = component_table;
results.sweep_table = sweep_table;
results.decision = decision;
results.store = store;

save(fullfile(out_path,'exp09_p1c_results.mat'), ...
    'results','-v7.3');

%% Console
fprintf('\n============================================================\n');
fprintf(' EXP009 P1C / Center-Frequency Cross-Term Sensitivity\n');
fprintf('============================================================\n');
disp(decision);
fprintf('============================================================\n\n');

fprintf('Saved P1C outputs to:\n%s\n\n',out_path);

end

%% ========================================================================
function [K_A,K_SAR,K_res] = residual_fm_rates(v,R0,lambda,cfg)
% Xu 2025 Eq. (7),(8),(11), range acceleration neglected.

V = cfg.platform_velocity_mps;

K_A = -2*(V-v).^2/(lambda*R0);
K_SAR = 2*V^2/(lambda*R0);
K_res = K_SAR.^2./(K_A-K_SAR) + K_SAR;

end

%% ========================================================================
function beta_grid = build_beta_grid(beta_true,min_sep,cfg)

lo = min(beta_true)- ...
    cfg.beta_grid_margin_separations*min_sep;
hi = max(beta_true)+ ...
    cfg.beta_grid_margin_separations*min_sep;

step = min_sep/cfg.beta_grid_oversample;

beta_grid = (lo:step:hi).';

end

%% ========================================================================
function x = synth_discrete_lfm(N,A,a,b,phi)
% Wang Eq. (13)-compatible discrete LFM.

m = 0:N-1;

x = A.*exp(1j*2*pi*( ...
    0.5*a*m.^2 + b*m) + 1j*phi);

x = x(:).';

end

%% ========================================================================
function Rii = component_auto_response( ...
    S,beta_grid,max_lag,cfg)
% Returns beta x lag x component self-FrAc responses.

[nComp,N] = size(S);
nBeta = numel(beta_grid);

Rii = complex(zeros(nBeta,max_lag,nComp));

[f,nfft] = frac_frequency_axis(N,cfg);
tan_beta = tan(beta_grid(:));

for ic = 1:nComp

    x = S(ic,:);

    for k = 1:max_lag

        z = x(1+k:end).*conj(x(1:end-k));

        Z = fftshift(fft(z,nfft));
        Z = Z(:);

        nu_target = k*tan_beta;

        rk = interp1( ...
            f,Z,nu_target,'linear',0);

        overlap = numel(z);
        Rii(:,k,ic) = rk/max(overlap,1);
    end
end

end

%% ========================================================================
function R = total_frac_response( ...
    x,beta_grid,max_lag,cfg)
% Returns beta x lag complex FrAc response.

x = x(:).';
N = numel(x);

nBeta = numel(beta_grid);
R = complex(zeros(nBeta,max_lag));

[f,nfft] = frac_frequency_axis(N,cfg);
tan_beta = tan(beta_grid(:));

for k = 1:max_lag

    z = x(1+k:end).*conj(x(1:end-k));

    Z = fftshift(fft(z,nfft));
    Z = Z(:);

    nu_target = k*tan_beta;

    rk = interp1( ...
        f,Z,nu_target,'linear',0);

    overlap = numel(z);
    R(:,k) = rk/max(overlap,1);
end

end

%% ========================================================================
function [f,nfft] = frac_frequency_axis(N,cfg)

nfft = max(2048, ...
    2^nextpow2(cfg.frac_fft_oversample*N));

if mod(nfft,2)==0
    f = (-nfft/2:nfft/2-1).'/nfft;
else
    f = (-(nfft-1)/2:(nfft-1)/2).'/nfft;
end

end

%% ========================================================================
function y = normalize_curve(y)

y = real(y(:));
mx = max(y);

if isfinite(mx) && mx>0
    y = y/mx;
end

end

%% ========================================================================
function [hit,err] = match_true_beta_to_peaks( ...
    beta_grid,E,beta_true,tol,min_prom_frac)

beta_grid = beta_grid(:);
E = real(E(:));
beta_true = beta_true(:);

idx = local_maxima_indices(E);

if isempty(idx)
    [~,idx] = max(E);
end

emin = min(E);
erange = max(E)-emin;

keep = true(size(idx));

if erange>0
    for j = 1:numel(idx)
        ii = idx(j);

        left_min = min(E(1:ii));
        right_min = min(E(ii:end));

        prom = E(ii)-max(left_min,right_min);

        if prom < min_prom_frac*erange
            keep(j) = false;
        end
    end
end

idx = idx(keep);

if isempty(idx)
    [~,idx] = max(E);
end

[~,ord] = sort(E(idx),'descend');
idx = idx(ord);

peak_beta = beta_grid(idx);
used = false(size(peak_beta));

hit = false(numel(beta_true),1);
err = nan(numel(beta_true),1);

[bt,sort_idx] = sort(beta_true);

for ii = 1:numel(bt)

    d = abs(peak_beta-bt(ii));
    d(used) = inf;

    [dm,j] = min(d);
    orig = sort_idx(ii);

    if isfinite(dm) && dm<=tol
        hit(orig) = true;
        err(orig) = dm;
        used(j) = true;
    end
end

end

%% ========================================================================
function idx = local_maxima_indices(y)

y = y(:);

if numel(y)<3
    [~,idx] = max(y);
    return;
end

idx = find( ...
    y(2:end-1)>y(1:end-2) & ...
    y(2:end-1)>=y(3:end)) + 1;

end

%% ========================================================================
function [d,idx] = nearest_indices(grid,values)

grid = grid(:);
values = values(:);

idx = nan(size(values));
d = nan(size(values));

for i = 1:numel(values)
    [d(i),idx(i)] = min(abs(grid-values(i)));
end

end

%% ========================================================================
function D = build_decision_summary(T,cfg)

modes = ["Paper1s","BeamDerived"];
rows = {};

for im = 1:numel(modes)

    mode = modes(im);

    Tm = T(strcmp(T.aperture_mode,char(mode)),:);
    Tm = sortrows(Tm,'gamma_adjacent_bin_spacing');

    gamma = Tm.gamma_adjacent_bin_spacing;

    ideal_any = any( ...
        Tm.ideal_incoherent_auto_all5_detected>0);

    ideal_at0 = logical( ...
        Tm.ideal_incoherent_auto_all5_detected(gamma==0));

    total_at0 = logical( ...
        Tm.phase_averaged_total_all5_detected(gamma==0));

    rate0 = Tm.phase_mc_all5_detection_rate(gamma==0);

    cross0 = Tm.median_cross_to_auto_at_true_beta(gamma==0);

    success_idx = find( ...
        Tm.phase_mc_all5_detection_rate>= ...
            cfg.phase_mc_all5_rate_gate, ...
        1,'first');

    if isempty(success_idx)
        gamma_recovery = NaN;
        recovery_rate = max(Tm.phase_mc_all5_detection_rate);
    else
        gamma_recovery = ...
            Tm.gamma_adjacent_bin_spacing(success_idx);
        recovery_rate = ...
            Tm.phase_mc_all5_detection_rate(success_idx);
    end

    % Best cross suppression relative to gamma=0.
    cross_min = min( ...
        Tm.median_cross_to_auto_at_true_beta);

    if isfinite(cross0) && cross0>0
        cross_reduction = 1-cross_min/cross0;
    else
        cross_reduction = NaN;
    end

    if ~ideal_any
        branch = "A_RESOLUTION_LIMITED";
    elseif ~ideal_at0
        branch = "A_RESOLUTION_LIMITED_AT_GAMMA0";
    elseif ideal_at0 && ~total_at0 && ...
            isfinite(gamma_recovery)
        branch = "B_CROSSTERM_RECOVERED_BY_bi";
    elseif ideal_at0 && ~total_at0 && ...
            ~isfinite(gamma_recovery)
        branch = "C_PHASE_SENSITIVE_CROSSTERM_PERSISTS";
    elseif total_at0 && rate0>=cfg.phase_mc_all5_rate_gate
        branch = "D_ALREADY_RESOLVED_AT_bi0";
    else
        branch = "E_MIXED_OR_PARTIAL";
    end

    rows(end+1,:) = { ... %#ok<AGROW>
        char(mode), ...
        double(ideal_any),double(ideal_at0), ...
        double(total_at0),rate0, ...
        cross0,cross_min,cross_reduction, ...
        gamma_recovery,recovery_rate,char(branch)};
end

D = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode', ...
    'ideal_auto_fivepeak_exists_any_gamma', ...
    'ideal_auto_fivepeak_at_gamma0', ...
    'phaseavg_total_fivepeak_at_gamma0', ...
    'phase_mc_rate_at_gamma0', ...
    'cross_to_auto_truebeta_at_gamma0', ...
    'minimum_cross_to_auto_truebeta', ...
    'fractional_cross_reduction_best_vs_gamma0', ...
    'first_gamma_reaching_phase_mc_gate', ...
    'best_or_gate_phase_mc_rate', ...
    'decision_branch'});

end

%% ========================================================================
function write_summary( ...
    out_path,cfg,lambda,R0,beamwidth_rad, ...
    component_table,sweep_table,decision)

fid = fopen(fullfile(out_path,'summary.txt'),'w');

fprintf(fid,'EXP009 P1C / Center-Frequency Cross-Term Sensitivity\n');
fprintf(fid,'===================================================\n\n');

fprintf(fid,'Purpose\n');
fprintf(fid,'-------\n');
fprintf(fid,['Final Wang-2023 reproduction audit before PA4: test whether ' ...
    'unreported b_i / cross-term geometry can explain P1B failure.\n\n']);

fprintf(fid,'Paper-grounded physical inputs\n');
fprintf(fid,'------------------------------\n');
fprintf(fid,'fc = %.9g Hz\n',cfg.fc_hz);
fprintf(fid,'PRF = %.9g Hz\n',cfg.prf_hz);
fprintf(fid,'H = %.9g m\n',cfg.platform_height_m);
fprintf(fid,'L_a = %.9g m\n',cfg.antenna_length_m);
fprintf(fid,'V = %.9g m/s\n',cfg.platform_velocity_mps);
fprintf(fid,'v_a = %s m/s\n\n', ...
    mat2str(cfg.target_velocity_mps));

fprintf(fid,'Derived / controlled\n');
fprintf(fid,'--------------------\n');
fprintf(fid,'lambda = %.9g m\n',lambda);
fprintf(fid,'representative R0/H = %.9g\n', ...
    cfg.slant_range_factor);
fprintf(fid,'R0 = %.9g m\n',R0);
fprintf(fid,'beamwidth ~= lambda/L_a = %.9g rad\n', ...
    beamwidth_rad);
fprintf(fid,'gamma bin sweep = %s\n', ...
    mat2str(cfg.gamma_bins));
fprintf(fid,['b_i = [-2,-1,0,1,2]*(gamma/N); exact Wang b_i are ' ...
    'not reported.\n']);
fprintf(fid,'phase MC = %d\n',cfg.num_phase_mc);
fprintf(fid,'No noise. No CLEAN.\n\n');

fprintf(fid,'Physical components\n');
fprintf(fid,'-------------------\n');

for i = 1:height(component_table)
    fprintf(fid,[ ...
        'P%d v=%+.3f Kres=%+.9g a=%+.9g beta=%+.9g\n'], ...
        component_table.component(i), ...
        component_table.azimuth_velocity_mps(i), ...
        component_table.K_residual_Hz_per_s(i), ...
        component_table.discrete_chirp_rate_a_cycles_per_sample2(i), ...
        component_table.predicted_FrAc_beta_rad(i));
end

fprintf(fid,'\nSweep summary\n');
fprintf(fid,'-------------\n');

for i = 1:height(sweep_table)
    fprintf(fid,[ ...
        '%s gamma=%.3f N=%d Deltaf=%.6g Hz ' ...
        'idealAll5=%d avgTotalAll5=%d phaseAll5=%.4f ' ...
        'cross/auto(true)=%.6g interaction/auto(true)=%.6g\n'], ...
        sweep_table.aperture_mode{i}, ...
        sweep_table.gamma_adjacent_bin_spacing(i), ...
        sweep_table.azimuth_samples(i), ...
        sweep_table.delta_center_frequency_hz(i), ...
        sweep_table.ideal_incoherent_auto_all5_detected(i), ...
        sweep_table.phase_averaged_total_all5_detected(i), ...
        sweep_table.phase_mc_all5_detection_rate(i), ...
        sweep_table.median_cross_to_auto_at_true_beta(i), ...
        sweep_table.median_abs_interaction_to_auto_at_true_beta(i));
end

fprintf(fid,'\nDecision\n');
fprintf(fid,'--------\n');

for i = 1:height(decision)
    fprintf(fid,[ ...
        '%s -> %s | idealAny=%d ideal0=%d total0=%d rate0=%.4f ' ...
        'gammaRecovery=%g crossReduction=%g\n'], ...
        decision.aperture_mode{i}, ...
        decision.decision_branch{i}, ...
        decision.ideal_auto_fivepeak_exists_any_gamma(i), ...
        decision.ideal_auto_fivepeak_at_gamma0(i), ...
        decision.phaseavg_total_fivepeak_at_gamma0(i), ...
        decision.phase_mc_rate_at_gamma0(i), ...
        decision.first_gamma_reaching_phase_mc_gate(i), ...
        decision.fractional_cross_reduction_best_vs_gamma0(i));
end

fprintf(fid,'\nBranch meanings\n');
fprintf(fid,'---------------\n');
fprintf(fid,['A_RESOLUTION_LIMITED: even ideal incoherent auto energy cannot ' ...
    'produce five peaks; aperture/response width is the dominant limit.\n']);
fprintf(fid,['B_CROSSTERM_RECOVERED_BY_bi: ideal auto resolves five peaks, ' ...
    'gamma=0 total does not, and finite b_i spacing restores robust ' ...
    'five-peak detection while cross contamination decreases.\n']);
fprintf(fid,['C_PHASE_SENSITIVE_CROSSTERM_PERSISTS: ideal auto is resolvable ' ...
    'but realistic coherent total remains phase-sensitive across b_i sweep.\n']);
fprintf(fid,['D_ALREADY_RESOLVED_AT_bi0: b_i is not needed to explain five ' ...
    'peaks in this implementation.\n']);
fprintf(fid,['E_MIXED_OR_PARTIAL: no single clean explanation; proceed to PA4 ' ...
    'with an explicit controlled separation framework.\n\n']);

fprintf(fid,'Research discipline\n');
fprintf(fid,'-------------------\n');
fprintf(fid,['P1C is the final reproduction audit. Regardless of the branch, ' ...
    'do not keep tuning Wang-missing parameters to force Fig.8. Proceed ' ...
    'to PA4 and label every non-published quantity as controlled or derived.\n']);

fclose(fid);

end

%% ========================================================================
function make_figures(out_path,cfg,T,store)

modes = ["Paper1s","BeamDerived"];

%% Fig 1 — phase-MC all-five detection rate vs gamma
fig = figure('Visible',cfg.figure_visible);
hold on;

for im = 1:2
    mm = strcmp(T.aperture_mode,char(modes(im)));
    Ts = sortrows(T(mm,:),'gamma_adjacent_bin_spacing');

    plot( ...
        Ts.gamma_adjacent_bin_spacing, ...
        Ts.phase_mc_all5_detection_rate, ...
        'o-','LineWidth',1.3);
end

yline(cfg.phase_mc_all5_rate_gate,'--');
xlabel('Adjacent center-frequency spacing \gamma (DFT bins)');
ylabel('All-five detection rate');
title('EXP009 P1C — Five-Peak Robustness vs Center-Frequency Separation');
legend({'Paper ~1 s','Beam-derived','Diagnostic gate'}, ...
    'Location','best');
ylim([0 1]);
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig01_detection_rate_vs_gamma.png'), ...
    'Resolution',180);
close(fig);

%% Fig 2 — cross-to-auto ratio vs gamma
fig = figure('Visible',cfg.figure_visible);
hold on;

for im = 1:2
    mm = strcmp(T.aperture_mode,char(modes(im)));
    Ts = sortrows(T(mm,:),'gamma_adjacent_bin_spacing');

    plot( ...
        Ts.gamma_adjacent_bin_spacing, ...
        Ts.median_cross_to_auto_at_true_beta, ...
        'o-','LineWidth',1.3);
end

xlabel('Adjacent center-frequency spacing \gamma (DFT bins)');
ylabel('Median cross / auto energy at true \beta');
title('EXP009 P1C — Cross-Term Contamination vs b_i Separation');
legend({'Paper ~1 s','Beam-derived'},'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig02_cross_to_auto_vs_gamma.png'), ...
    'Resolution',180);
close(fig);

%% Fig 3-4 — representative Paper1s gamma 0 and gamma max
plot_case( ...
    store.A1_G1, ...
    fullfile(out_path,'fig03_paper1s_gamma0_decomposition.png'), ...
    cfg);

plot_case( ...
    store.(sprintf('A1_G%d',numel(cfg.gamma_bins))), ...
    fullfile(out_path,'fig04_paper1s_gammaMax_decomposition.png'), ...
    cfg);

%% Fig 5-6 — representative BeamDerived gamma 0 and gamma max
plot_case( ...
    store.A2_G1, ...
    fullfile(out_path,'fig05_beam_gamma0_decomposition.png'), ...
    cfg);

plot_case( ...
    store.(sprintf('A2_G%d',numel(cfg.gamma_bins))), ...
    fullfile(out_path,'fig06_beam_gammaMax_decomposition.png'), ...
    cfg);

%% Fig 7 — ideal-auto vs total detectability
fig = figure('Visible',cfg.figure_visible);

Y = nan(numel(cfg.gamma_bins),4);

for ig = 1:numel(cfg.gamma_bins)

    for im = 1:2
        mm = ...
            strcmp(T.aperture_mode,char(modes(im))) & ...
            abs(T.gamma_adjacent_bin_spacing- ...
                cfg.gamma_bins(ig))<1e-12;

        r = T(mm,:);

        Y(ig,2*im-1) = ...
            r.ideal_incoherent_auto_all5_detected;

        Y(ig,2*im) = ...
            r.phase_mc_all5_detection_rate;
    end
end

bar(cfg.gamma_bins,Y);
xlabel('Adjacent center-frequency spacing \gamma (DFT bins)');
ylabel('Detection indicator / rate');
title('EXP009 P1C — Resolution Limit vs Coherent Cross-Term Limit');
legend({ ...
    'Paper ideal auto','Paper total MC', ...
    'Beam ideal auto','Beam total MC'}, ...
    'Location','best');
ylim([0 1]);
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig07_ideal_auto_vs_total.png'), ...
    'Resolution',180);
close(fig);

end

%% ========================================================================
function plot_case(S,filename,cfg)

fig = figure('Visible',cfg.figure_visible);

plot(S.beta_grid,S.E_auto_incoherent, ...
    'LineWidth',1.3);
hold on;

plot(S.beta_grid,S.E_total_avg, ...
    'LineWidth',1.3);

% Cross curve is not normalized to unit peak; it is normalized to auto
% peak in the decomposition.
plot(S.beta_grid,S.E_cross_avg, ...
    '--','LineWidth',1.0);

for ic = 1:numel(S.beta_true)
    xline(S.beta_true(ic),':');
end

xlabel('FrAc rotation angle \beta (rad)');
ylabel('Normalized / relative energy');
title(sprintf( ...
    'EXP009 P1C — %s, \\gamma=%.2f', ...
    char(S.aperture_name),S.gamma));

legend({'Ideal incoherent auto','Phase-avg total','Cross / auto scale'}, ...
    'Location','best');
grid on;

exportgraphics(fig,filename,'Resolution',180);
close(fig);

end
