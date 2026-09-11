function results = exp09_pa5_sequential_strong_removal_map()
%EXP09_PA5_SEQUENTIAL_STRONG_REMOVAL_MAP
% EXP009 / Physical Validation Track / PA5
%
% Physical Sequential Strong-Removal Recovery Map
%
% Research question
% -----------------
% PA4 showed that many weak components are not observable as independent
% peaks even before noise/CLEAN are introduced.
%
% PA5 therefore asks:
%
%   When a weak component is hidden in the full two-component FrAc
%   landscape, can sequential strong removal reveal it?
%
% Groups
% ------
% G0 WeakOnly
%     Intrinsic weak-only baseline.
%
% G1 FullMixture
%     Pre-removal two-component landscape.
%
% G2 OracleParamCLEAN
%     Use the TRUE strong chirp parameter, fit its complex coefficient by
%     least squares to the full mixture, and subtract the fitted atom.
%     This is the best achievable result inside the one-atom LS-CLEAN
%     operator family, and therefore isolates operator-induced weak
%     distortion even when strong parameter estimation is perfect.
%
% G3 PracticalCLEAN
%     Estimate the strong chirp parameter from the GLOBAL FrAc maximum of
%     G1, synthesize that atom, LS-fit its complex coefficient, subtract,
%     and rerun FrAc on the residual.
%
% Gx ExactOracleSubtract
%     Diagnostic sanity check only:
%         mixture - exact strong component = exact weak component.
%     It is not used as the practical algorithm because its recovery is
%     intentionally trivial.
%
% Why G2 is not exact subtraction
% -------------------------------
% Exact subtraction would make the oracle upper bound identically equal to
% G0 and cannot reveal whether the CLEAN projection/operator itself harms
% the weak component. G2 therefore uses the TRUE strong parameter but the
% same LS subtraction family as G3.
%
% Physical axes
% -------------
% The parameter grid is inherited from PA4:
%
%   weak velocity = 15 m/s
%   strong velocity = weak +/- Delta v
%   Delta v = [2.5,5,7.5,10,15,20] m/s
%   A_w/A_s = [0.1,0.2,0.3,0.5,0.8]
%   16 deterministic relative phases
%   Paper1s and BeamDerived apertures
%
% The primary resolution coordinate remains:
%
%   Gamma = |beta_s-beta_w| / W_beta,weak.
%
% No noise in PA5.
%
% Main outcomes
% -------------
% 1) pre_hidden:
%       no local weak-associated peak in G1.
%
% 2) oracle_operator_rescue:
%       G2 residual GLOBAL maximum is associated with weak, conditional on
%       pre_hidden.
%
% 3) practical_rescue:
%       G3 residual GLOBAL maximum is associated with weak, conditional on
%       pre_hidden.
%
% 4) implementation gap:
%       oracle-operator rescue rate - practical rescue rate.
%
% 5) oracle operator distortion:
%       ||r_G2 - w_true|| / ||w_true||.
%
% 6) practical residual error:
%       ||r_G3 - w_true|| / ||w_true||.
%
% 7) practical strong-estimation error:
%       (beta_hat_s-beta_s)/W_beta.
%
% Run:
%   results = exp09_pa5_sequential_strong_removal_map;

cfg = config_exp09_pa5_sequential_strong_removal_map();

%% Output path
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.output_dir)
    out_path = fullfile( ...
        paper_root,'results','exp09_physical_validation', ...
        'exp09_pa5_sequential_strong_removal_map');
else
    out_path = cfg.output_dir;
end

if ~exist(out_path,'dir')
    mkdir(out_path);
end

%% Physical constants
lambda = cfg.c/cfg.fc_hz;
R0 = cfg.platform_height_m*cfg.slant_range_factor;
beamwidth_rad = cfg.beamwidth_scale*lambda/cfg.antenna_length_m;

vw = cfg.weak_velocity_mps;

[~,~,Kw] = residual_fm_rates(vw,R0,lambda,cfg);
aw = Kw/(cfg.prf_hz^2);
beta_w = atan(aw);

%% Apertures
T_paper = cfg.paper_aperture_time_s;
N_paper = max(32,round(cfg.prf_hz*T_paper));

T_beam = R0*beamwidth_rad/cfg.platform_velocity_mps;
N_beam = max(32,round(cfg.prf_hz*T_beam));

aperture_names = ["Paper1s","BeamDerived"];
N_list = [N_paper,N_beam];
T_target_list = [T_paper,T_beam];

%% Weak-only intrinsic-width calibration
width_rows = {};
width_store = struct();

for ia = 1:2

    mode = aperture_names(ia);
    N = N_list(ia);
    T_target = T_target_list(ia);
    T_actual = (N-1)/cfg.prf_hz;

    max_lag = max(2,min(N-2, ...
        round(cfg.max_lag_fraction*N)));

    beta_grid_width = linspace( ...
        beta_w-cfg.width_grid_halfspan_rad, ...
        beta_w+cfg.width_grid_halfspan_rad, ...
        cfg.width_grid_points).';

    w0 = synth_discrete_lfm( ...
        N,1,aw,cfg.center_frequency_cycles_per_sample,0);

    Rww = pair_frac_response( ...
        w0,w0,beta_grid_width,max_lag,cfg);

    Pweak = sum(abs(Rww).^2,2);

    Wbeta = estimate_3db_width( ...
        beta_grid_width,Pweak,beta_w);

    if ~isfinite(Wbeta) || Wbeta<=0
        error('Could not estimate weak-only 3-dB width for %s.',mode);
    end

    width_rows(end+1,:) = { ... %#ok<AGROW>
        char(mode),N,T_target,T_actual,max_lag,Wbeta};

    width_store.(char(mode)) = struct( ...
        'N',N,'T_target',T_target,'T_actual',T_actual, ...
        'max_lag',max_lag,'Wbeta',Wbeta);
end

width_table = cell2table(width_rows, ...
    'VariableNames',{ ...
    'aperture_mode','azimuth_samples', ...
    'target_aperture_time_s','actual_observation_time_s', ...
    'max_frac_lag','weak_single_3db_width_beta_rad'});

writetable(width_table, ...
    fullfile(out_path,'pa5_intrinsic_width_calibration.csv'));

%% Main sweep
rows = {};
example_store = struct();
row = 0;

sides = ["LowV","HighV"];

for ia = 1:2

    mode = aperture_names(ia);
    Wbeta = width_store.(char(mode)).Wbeta;
    N = width_store.(char(mode)).N;
    max_lag = width_store.(char(mode)).max_lag;

    w0 = synth_discrete_lfm( ...
        N,1,aw,cfg.center_frequency_cycles_per_sample,0);

    norm_w0 = norm(w0);

    for idv = 1:numel(cfg.delta_velocity_mps)

        dv = cfg.delta_velocity_mps(idv);

        for iside = 1:2

            side = sides(iside);

            if side=="LowV"
                vs = vw-dv;
            else
                vs = vw+dv;
            end

            [~,~,Ks] = residual_fm_rates(vs,R0,lambda,cfg);
            as = Ks/(cfg.prf_hz^2);
            beta_s = atan(as);

            beta_sep = abs(beta_s-beta_w);
            Gamma = beta_sep/Wbeta;
            regime = gamma_regime(Gamma,cfg);

            beta_grid = build_scenario_beta_grid( ...
                beta_w,beta_s,Wbeta,cfg);

            s0 = synth_discrete_lfm( ...
                N,cfg.A_strong,as, ...
                cfg.center_frequency_cycles_per_sample,0);

            % Pair-response basis for the full two-component mixture.
            Rss = pair_frac_response( ...
                s0,s0,beta_grid,max_lag,cfg);

            Rww = pair_frac_response( ...
                w0,w0,beta_grid,max_lag,cfg);

            Rsw = pair_frac_response( ...
                s0,w0,beta_grid,max_lag,cfg);

            Rws = pair_frac_response( ...
                w0,s0,beta_grid,max_lag,cfg);

            % Oracle-parameter LS projection can be assembled from the
            % same s/w basis without any extra FFTs.
            s_energy = real(s0*s0');
            sw_inner = s0*w0';

            % Cache practical estimated-atom FrAc pair responses by
            % beta-grid index. Many amplitude/phase cases share beta_hat.
            practical_cache = containers.Map( ...
                'KeyType','char','ValueType','any');

            for ir = 1:numel(cfg.weak_to_strong_ratio)

                r = cfg.weak_to_strong_ratio(ir);
                w_amp = r;

                for ip = 1:numel(cfg.relative_phase_rad)

                    phi = cfg.relative_phase_rad(ip);
                    cw = w_amp*exp(1j*phi);

                    x = s0 + cw*w0;
                    w_true = cw*w0;

                    %% G0 WeakOnly
                    P_g0 = (abs(cw)^4)*sum(abs(Rww).^2,2);
                    g0_global_beta = global_peak_beta( ...
                        beta_grid,P_g0);

                    g0_global_weak = ...
                        abs(g0_global_beta-beta_w) <= ...
                        cfg.post_weak_global_tolerance_widths*Wbeta;

                    %% G1 FullMixture
                    R_g1 = ...
                        Rss + ...
                        (abs(cw)^2)*Rww + ...
                        conj(cw)*Rsw + ...
                        cw*Rws;

                    P_g1 = sum(abs(R_g1).^2,2);
                    P_g1_norm = normalize_curve(P_g1);

                    peaks_g1 = local_peaks_with_prominence( ...
                        beta_grid,P_g1_norm, ...
                        cfg.min_peak_prominence_fraction);

                    [pre_weak_found,pre_weak_beta,~] = ...
                        associate_peak( ...
                            peaks_g1,beta_w,beta_sep,Wbeta,cfg);

                    pre_hidden = ~pre_weak_found;

                    [~,idx_hat] = max(P_g1);
                    beta_hat_s = beta_grid(idx_hat);
                    a_hat_s = tan(beta_hat_s);

                    strong_est_error = ...
                        (beta_hat_s-beta_s)/Wbeta;

                    strong_est_success = ...
                        abs(strong_est_error) <= ...
                        cfg.strong_estimation_success_widths;

                    %% Gx Exact oracle subtraction sanity
                    r_exact = x-s0;
                    exact_error_ratio = ...
                        norm(r_exact-w_true) / ...
                        max(norm(w_true),cfg.small_norm_floor);

                    %% G2 OracleParamCLEAN
                    % Fit the TRUE strong atom to the full mixture.
                    c_oracle = (s0*x')/max(s_energy,cfg.small_norm_floor);
                    r_g2 = x-c_oracle*s0;

                    % r_g2 = alpha_s*s0 + alpha_w*w0.
                    alpha_s_oracle = 1-c_oracle;
                    alpha_w_oracle = cw;

                    R_g2 = ...
                        (abs(alpha_s_oracle)^2)*Rss + ...
                        (abs(alpha_w_oracle)^2)*Rww + ...
                        alpha_s_oracle*conj(alpha_w_oracle)*Rsw + ...
                        alpha_w_oracle*conj(alpha_s_oracle)*Rws;

                    P_g2 = sum(abs(R_g2).^2,2);
                    [g2_global_weak,g2_local_weak,g2_global_beta] = ...
                        weak_recovery_status( ...
                            beta_grid,P_g2,beta_w,Wbeta,cfg);

                    operator_distortion_ratio = ...
                        norm(r_g2-w_true) / ...
                        max(norm(w_true),cfg.small_norm_floor);

                    %% G3 PracticalCLEAN
                    % Estimate strong beta from G1 global maximum.
                    cache_key = sprintf('i%d',idx_hat);

                    if isKey(practical_cache,cache_key)
                        C = practical_cache(cache_key);
                    else
                        h = synth_discrete_lfm( ...
                            N,1,a_hat_s, ...
                            cfg.center_frequency_cycles_per_sample,0);

                        C = build_practical_cache( ...
                            h,s0,w0,beta_grid,max_lag,cfg);

                        practical_cache(cache_key) = C;
                    end

                    h = C.h;
                    h_energy = real(h*h');

                    c_practical = ...
                        (h*x')/max(h_energy,cfg.small_norm_floor);

                    r_g3 = x-c_practical*h;

                    % Assemble B(r_g3,r_g3) without recomputing FFTs.
                    %
                    % x = s + cw*w.
                    %
                    % B(x,x) = R_g1.
                    % B(h,x) = B(h,s) + conj(cw) B(h,w).
                    % B(x,h) = B(s,h) + cw B(w,h).
                    Rhx = C.Rhs + conj(cw)*C.Rhw;
                    Rxh = C.Rsh + cw*C.Rwh;

                    R_g3 = ...
                        R_g1 - ...
                        c_practical*Rhx - ...
                        conj(c_practical)*Rxh + ...
                        abs(c_practical)^2*C.Rhh;

                    P_g3 = sum(abs(R_g3).^2,2);

                    [g3_global_weak,g3_local_weak,g3_global_beta] = ...
                        weak_recovery_status( ...
                            beta_grid,P_g3,beta_w,Wbeta,cfg);

                    practical_error_ratio = ...
                        norm(r_g3-w_true) / ...
                        max(norm(w_true),cfg.small_norm_floor);

                    %% Derived rescue indicators
                    oracle_operator_rescue = ...
                        pre_hidden && g2_global_weak;

                    practical_rescue = ...
                        pre_hidden && g3_global_weak;

                    %% Save row
                    row = row+1;

                    rows(end+1,:) = { ... %#ok<AGROW>
                        char(mode),N, ...
                        dv,char(side), ...
                        vw,vs, ...
                        beta_w,beta_s,beta_sep,Wbeta,Gamma,char(regime), ...
                        r,phi, ...
                        double(g0_global_weak), ...
                        double(pre_weak_found),pre_weak_beta, ...
                        double(pre_hidden), ...
                        beta_hat_s,strong_est_error, ...
                        double(strong_est_success), ...
                        exact_error_ratio, ...
                        double(g2_global_weak), ...
                        double(g2_local_weak), ...
                        g2_global_beta, ...
                        operator_distortion_ratio, ...
                        double(g3_global_weak), ...
                        double(g3_local_weak), ...
                        g3_global_beta, ...
                        practical_error_ratio, ...
                        double(oracle_operator_rescue), ...
                        double(practical_rescue)};
                end
            end

            % Representative examples are selected later from the table.
        end
    end
end

trial_table = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','azimuth_samples', ...
    'delta_velocity_mps','strong_velocity_side', ...
    'weak_velocity_mps','strong_velocity_mps', ...
    'beta_weak_rad','beta_strong_rad','beta_separation_rad', ...
    'weak_3db_width_rad','Gamma_sep_over_width','Gamma_regime', ...
    'weak_to_strong_ratio','relative_phase_rad', ...
    'G0_weak_global_ok', ...
    'G1_pre_weak_local_found','G1_pre_weak_beta_rad', ...
    'pre_hidden', ...
    'G3_beta_hat_strong_rad','G3_strong_est_error_over_width', ...
    'G3_strong_estimation_success', ...
    'Gx_exact_subtraction_error_ratio', ...
    'G2_oracle_global_weak','G2_oracle_local_weak', ...
    'G2_oracle_global_beta_rad','G2_operator_distortion_ratio', ...
    'G3_practical_global_weak','G3_practical_local_weak', ...
    'G3_practical_global_beta_rad','G3_practical_error_ratio', ...
    'oracle_operator_rescue','practical_rescue'});

writetable(trial_table, ...
    fullfile(out_path,'pa5_trial_results.csv'));

%% Summaries
recovery_summary = summarize_recovery(trial_table);
contrast_summary = summarize_contrast(trial_table);
regime_summary = summarize_regime_recovery(trial_table);
estimation_summary = summarize_estimation(trial_table);
decision_summary = build_decision_summary( ...
    recovery_summary,contrast_summary,regime_summary, ...
    estimation_summary,cfg);

writetable(recovery_summary, ...
    fullfile(out_path,'pa5_recovery_summary.csv'));

writetable(contrast_summary, ...
    fullfile(out_path,'pa5_contrast_summary.csv'));

writetable(regime_summary, ...
    fullfile(out_path,'pa5_regime_recovery_summary.csv'));

writetable(estimation_summary, ...
    fullfile(out_path,'pa5_strong_estimation_summary.csv'));

writetable(decision_summary, ...
    fullfile(out_path,'pa5_decision_summary.csv'));

%% Representative examples
examples = select_representative_examples(trial_table);

writetable(examples, ...
    fullfile(out_path,'pa5_representative_examples.csv'));

%% Text summary
write_summary( ...
    out_path,cfg,lambda,R0,beamwidth_rad, ...
    width_table,recovery_summary,contrast_summary, ...
    regime_summary,estimation_summary,decision_summary,examples);

%% Figures
make_figures( ...
    out_path,cfg,trial_table,recovery_summary, ...
    contrast_summary,regime_summary,estimation_summary);

%% Save
results = struct();
results.cfg = cfg;
results.lambda = lambda;
results.R0 = R0;
results.beamwidth_rad = beamwidth_rad;
results.width_table = width_table;
results.trial_table = trial_table;
results.recovery_summary = recovery_summary;
results.contrast_summary = contrast_summary;
results.regime_summary = regime_summary;
results.estimation_summary = estimation_summary;
results.decision_summary = decision_summary;
results.examples = examples;

save(fullfile(out_path,'exp09_pa5_results.mat'), ...
    'results','-v7.3');

%% Console
fprintf('\n============================================================\n');
fprintf(' EXP009 PA5 / Sequential Strong-Removal Recovery Map\n');
fprintf('============================================================\n');
disp(width_table);
disp(recovery_summary);
disp(contrast_summary);
disp(regime_summary);
disp(estimation_summary);
disp(decision_summary);
fprintf('============================================================\n\n');

fprintf('Saved PA5 outputs to:\n%s\n\n',out_path);

end

%% ========================================================================
function [K_A,K_SAR,K_res] = residual_fm_rates(v,R0,lambda,cfg)

V = cfg.platform_velocity_mps;

K_A = -2*(V-v).^2/(lambda*R0);
K_SAR = 2*V^2/(lambda*R0);
K_res = K_SAR.^2./(K_A-K_SAR) + K_SAR;

end

%% ========================================================================
function x = synth_discrete_lfm(N,A,a,b,phi)

m = 0:N-1;

x = A.*exp(1j*2*pi*( ...
    0.5*a*m.^2 + b*m) + 1j*phi);

x = x(:).';

end

%% ========================================================================
function R = pair_frac_response( ...
    x_left,x_right,beta_grid,max_lag,cfg)

x_left = x_left(:).';
x_right = x_right(:).';

if numel(x_left)~=numel(x_right)
    error('Pair components must have equal length.');
end

N = numel(x_left);
nBeta = numel(beta_grid);

R = complex(zeros(nBeta,max_lag));

[f,nfft] = frac_frequency_axis(N,cfg);
tan_beta = tan(beta_grid(:));

for k = 1:max_lag

    z = ...
        x_left(1+k:end).* ...
        conj(x_right(1:end-k));

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
function W = estimate_3db_width(beta_grid,P,beta0)

beta_grid = beta_grid(:);
P = real(P(:));

[~,i0] = min(abs(beta_grid-beta0));

halfwin = max(5,round(0.20*numel(beta_grid)));
i1 = max(1,i0-halfwin);
i2 = min(numel(beta_grid),i0+halfwin);

[~,iloc] = max(P(i1:i2));
ip = i1+iloc-1;

level = P(ip)/2;

il = ip;
while il>1 && P(il)>=level
    il = il-1;
end

ir = ip;
while ir<numel(P) && P(ir)>=level
    ir = ir+1;
end

if il==1 || ir==numel(P)
    W = NaN;
else
    W = beta_grid(ir)-beta_grid(il);
end

end

%% ========================================================================
function beta_grid = build_scenario_beta_grid( ...
    beta_w,beta_s,Wbeta,cfg)

sep = abs(beta_s-beta_w);

step = min( ...
    cfg.beta_step_width_fraction*Wbeta, ...
    cfg.beta_step_separation_fraction*max(sep,eps));

step = max( ...
    step, ...
    cfg.beta_step_min_width_fraction*Wbeta);

lo = min(beta_w,beta_s)-cfg.beta_margin_widths*Wbeta;
hi = max(beta_w,beta_s)+cfg.beta_margin_widths*Wbeta;

n = ceil((hi-lo)/step);
beta_grid = linspace(lo,hi,n+1).';

end

%% ========================================================================
function regime = gamma_regime(Gamma,cfg)

if Gamma<cfg.gamma_unresolved_max
    regime = "Unresolved";
elseif Gamma<cfg.gamma_partial_max
    regime = "Partial";
else
    regime = "ResolvedCandidate";
end

end

%% ========================================================================
function peaks = local_peaks_with_prominence( ...
    beta_grid,P,min_prom_frac)

beta_grid = beta_grid(:);
P = real(P(:));

idx = find( ...
    P(2:end-1)>P(1:end-2) & ...
    P(2:end-1)>=P(3:end)) + 1;

if isempty(idx)
    [~,idx] = max(P);
end

pr = nan(numel(idx),1);

for j = 1:numel(idx)

    ii = idx(j);

    left_min = min(P(1:ii));
    right_min = min(P(ii:end));

    pr(j) = ...
        P(ii)-max(left_min,right_min);
end

rangeP = max(P)-min(P);

if rangeP>0
    keep = pr>=min_prom_frac*rangeP;
else
    keep = true(size(pr));
end

idx = idx(keep);
pr = pr(keep);

if isempty(idx)
    [~,idx] = max(P);
    pr = max(P)-min(P);
end

peaks = struct();
peaks.idx = idx(:);
peaks.beta = beta_grid(idx);
peaks.value = P(idx);
peaks.prominence = pr(:);

end

%% ========================================================================
function [found,beta_peak,prom] = associate_peak( ...
    peaks,beta_true,beta_sep,Wbeta,cfg)

radius = max( ...
    cfg.peak_association_fraction_of_separation*beta_sep, ...
    cfg.peak_association_min_width_fraction*Wbeta);

d = abs(peaks.beta-beta_true);
inside = d<=radius;

if ~any(inside)
    found = false;
    beta_peak = NaN;
    prom = NaN;
    return;
end

idx_inside = find(inside);

[~,ord] = sortrows([ ...
    d(idx_inside), ...
    -peaks.prominence(idx_inside)], ...
    [1 2]);

j = idx_inside(ord(1));

found = true;
beta_peak = peaks.beta(j);
prom = peaks.prominence(j);

end

%% ========================================================================
function beta_peak = global_peak_beta(beta_grid,P)

[~,idx] = max(real(P(:)));
beta_peak = beta_grid(idx);

end

%% ========================================================================
function [global_weak,local_weak,global_beta] = ...
    weak_recovery_status(beta_grid,P,beta_w,Wbeta,cfg)

Pnorm = normalize_curve(P);

global_beta = global_peak_beta(beta_grid,Pnorm);

global_weak = ...
    abs(global_beta-beta_w) <= ...
    cfg.post_weak_global_tolerance_widths*Wbeta;

peaks = local_peaks_with_prominence( ...
    beta_grid,Pnorm,cfg.min_peak_prominence_fraction);

local_weak = any( ...
    abs(peaks.beta-beta_w) <= ...
    cfg.post_weak_local_tolerance_widths*Wbeta);

end

%% ========================================================================
function C = build_practical_cache( ...
    h,s0,w0,beta_grid,max_lag,cfg)

C = struct();
C.h = h;

C.Rhs = pair_frac_response( ...
    h,s0,beta_grid,max_lag,cfg);

C.Rhw = pair_frac_response( ...
    h,w0,beta_grid,max_lag,cfg);

C.Rsh = pair_frac_response( ...
    s0,h,beta_grid,max_lag,cfg);

C.Rwh = pair_frac_response( ...
    w0,h,beta_grid,max_lag,cfg);

C.Rhh = pair_frac_response( ...
    h,h,beta_grid,max_lag,cfg);

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
function S = summarize_recovery(T)

modes = unique(string(T.aperture_mode),'stable');
rows = {};

for im = 1:numel(modes)

    mode = modes(im);
    M = T(string(T.aperture_mode)==mode,:);

    hidden = logical(M.pre_hidden);
    H = M(hidden,:);

    n_total = height(M);
    n_hidden = height(H);

    hidden_rate = n_hidden/max(n_total,1);

    if n_hidden>0
        oracle_rescue = mean(H.oracle_operator_rescue);
        practical_rescue = mean(H.practical_rescue);
        implementation_gap = oracle_rescue-practical_rescue;

        med_op_dist = median( ...
            H.G2_operator_distortion_ratio,'omitnan');

        med_prac_err = median( ...
            H.G3_practical_error_ratio,'omitnan');

        strong_est_success = mean( ...
            H.G3_strong_estimation_success);
    else
        oracle_rescue = NaN;
        practical_rescue = NaN;
        implementation_gap = NaN;
        med_op_dist = NaN;
        med_prac_err = NaN;
        strong_est_success = NaN;
    end

    rows(end+1,:) = { ... %#ok<AGROW>
        char(mode),n_total,n_hidden,hidden_rate, ...
        oracle_rescue,practical_rescue,implementation_gap, ...
        med_op_dist,med_prac_err,strong_est_success};
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','n_total','n_pre_hidden','pre_hidden_rate', ...
    'oracle_operator_rescue_rate_on_hidden', ...
    'practical_rescue_rate_on_hidden', ...
    'implementation_gap_oracle_minus_practical', ...
    'median_oracle_operator_distortion_ratio_on_hidden', ...
    'median_practical_error_ratio_on_hidden', ...
    'practical_strong_estimation_success_rate_on_hidden'});

end

%% ========================================================================
function S = summarize_contrast(T)

modes = unique(string(T.aperture_mode),'stable');
ratios = unique(T.weak_to_strong_ratio).';

rows = {};

for im = 1:numel(modes)

    mode = modes(im);

    for ir = 1:numel(ratios)

        r = ratios(ir);

        M = T( ...
            string(T.aperture_mode)==mode & ...
            abs(T.weak_to_strong_ratio-r)<1e-12,:);

        H = M(logical(M.pre_hidden),:);

        hidden_rate = height(H)/max(height(M),1);

        if ~isempty(H)
            oracle_rescue = mean(H.oracle_operator_rescue);
            practical_rescue = mean(H.practical_rescue);
            med_op_dist = median( ...
                H.G2_operator_distortion_ratio,'omitnan');
            med_prac_err = median( ...
                H.G3_practical_error_ratio,'omitnan');
        else
            oracle_rescue = NaN;
            practical_rescue = NaN;
            med_op_dist = NaN;
            med_prac_err = NaN;
        end

        rows(end+1,:) = { ... %#ok<AGROW>
            char(mode),r,height(M),height(H),hidden_rate, ...
            oracle_rescue,practical_rescue, ...
            oracle_rescue-practical_rescue, ...
            med_op_dist,med_prac_err};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','weak_to_strong_ratio','n','n_hidden', ...
    'pre_hidden_rate', ...
    'oracle_operator_rescue_rate_on_hidden', ...
    'practical_rescue_rate_on_hidden', ...
    'implementation_gap', ...
    'median_oracle_operator_distortion_ratio', ...
    'median_practical_error_ratio'});

end

%% ========================================================================
function S = summarize_regime_recovery(T)

modes = unique(string(T.aperture_mode),'stable');
regimes = ["Unresolved","Partial","ResolvedCandidate"];

rows = {};

for im = 1:numel(modes)

    mode = modes(im);

    for ig = 1:numel(regimes)

        reg = regimes(ig);

        M = T( ...
            string(T.aperture_mode)==mode & ...
            string(T.Gamma_regime)==reg,:);

        H = M(logical(M.pre_hidden),:);

        if isempty(M)
            rows(end+1,:) = { ... %#ok<AGROW>
                char(mode),char(reg),0,0, ...
                NaN,NaN,NaN,NaN,NaN};
            continue;
        end

        hidden_rate = height(H)/height(M);

        if ~isempty(H)
            oracle_rescue = mean(H.oracle_operator_rescue);
            practical_rescue = mean(H.practical_rescue);
            med_prac_err = median( ...
                H.G3_practical_error_ratio,'omitnan');
            med_est_abs = median( ...
                abs(H.G3_strong_est_error_over_width),'omitnan');
        else
            oracle_rescue = NaN;
            practical_rescue = NaN;
            med_prac_err = NaN;
            med_est_abs = NaN;
        end

        rows(end+1,:) = { ... %#ok<AGROW>
            char(mode),char(reg),height(M),height(H), ...
            hidden_rate,oracle_rescue,practical_rescue, ...
            med_prac_err,med_est_abs};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','Gamma_regime','n','n_hidden', ...
    'pre_hidden_rate', ...
    'oracle_operator_rescue_rate_on_hidden', ...
    'practical_rescue_rate_on_hidden', ...
    'median_practical_error_ratio_on_hidden', ...
    'median_abs_strong_est_error_over_width_on_hidden'});

end

%% ========================================================================
function S = summarize_estimation(T)

modes = unique(string(T.aperture_mode),'stable');
rows = {};

for im = 1:numel(modes)

    mode = modes(im);
    M = T(string(T.aperture_mode)==mode,:);

    err = M.G3_strong_est_error_over_width;
    ok = isfinite(err);

    if any(ok)
        med_abs = median(abs(err(ok)));
        p90_abs = percentile_local(abs(err(ok)),90);
        success = mean(M.G3_strong_estimation_success(ok));
    else
        med_abs = NaN;
        p90_abs = NaN;
        success = NaN;
    end

    hidden = logical(M.pre_hidden) & ok;

    if any(hidden)
        med_hidden = median(abs(err(hidden)));
        success_hidden = mean( ...
            M.G3_strong_estimation_success(hidden));
    else
        med_hidden = NaN;
        success_hidden = NaN;
    end

    rows(end+1,:) = { ... %#ok<AGROW>
        char(mode),sum(ok), ...
        med_abs,p90_abs,success, ...
        sum(hidden),med_hidden,success_hidden};
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','n', ...
    'median_abs_strong_est_error_over_width', ...
    'p90_abs_strong_est_error_over_width', ...
    'strong_estimation_success_rate', ...
    'n_pre_hidden', ...
    'median_abs_strong_est_error_over_width_on_hidden', ...
    'strong_estimation_success_rate_on_hidden'});

end

%% ========================================================================
function D = build_decision_summary( ...
    recovery_summary,contrast_summary,regime_summary, ...
    estimation_summary,cfg)

modes = string(recovery_summary.aperture_mode);
rows = {};

for im = 1:numel(modes)

    mode = modes(im);

    R = recovery_summary(im,:);

    if ~isfinite(R.oracle_operator_rescue_rate_on_hidden)
        branch = "NO_HIDDEN_COHORT";
    elseif R.oracle_operator_rescue_rate_on_hidden < ...
            cfg.oracle_operator_rescue_gate
        branch = "OPERATOR_LIMITED_RECOVERY";
    elseif R.practical_rescue_rate_on_hidden >= ...
            cfg.practical_rescue_gate && ...
            R.median_practical_error_ratio_on_hidden <= ...
            cfg.max_median_practical_error_ratio
        branch = "PRACTICAL_STRONG_REMOVAL_REVEALS_HIDDEN_WEAK";
    elseif R.implementation_gap_oracle_minus_practical > 0.20
        branch = "STRONG_ESTIMATION_IMPLEMENTATION_GAP";
    else
        branch = "MIXED_RECOVERY_LIMIT";
    end

    rows(end+1,:) = { ... %#ok<AGROW>
        char(mode),char(branch), ...
        R.pre_hidden_rate, ...
        R.oracle_operator_rescue_rate_on_hidden, ...
        R.practical_rescue_rate_on_hidden, ...
        R.implementation_gap_oracle_minus_practical, ...
        R.median_oracle_operator_distortion_ratio_on_hidden, ...
        R.median_practical_error_ratio_on_hidden, ...
        R.practical_strong_estimation_success_rate_on_hidden};
end

D = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','decision_branch', ...
    'pre_hidden_rate', ...
    'oracle_operator_rescue_rate_on_hidden', ...
    'practical_rescue_rate_on_hidden', ...
    'implementation_gap', ...
    'median_oracle_operator_distortion_ratio_on_hidden', ...
    'median_practical_error_ratio_on_hidden', ...
    'practical_strong_estimation_success_rate_on_hidden'});

end

%% ========================================================================
function E = select_representative_examples(T)

rows = {};

modes = unique(string(T.aperture_mode),'stable');

for im = 1:numel(modes)

    mode = modes(im);
    M = T(string(T.aperture_mode)==mode,:);

    % Example A: hidden -> practically rescued.
    A = M( ...
        logical(M.pre_hidden) & ...
        logical(M.practical_rescue),:);

    if ~isempty(A)
        [~,i] = min(abs(A.weak_to_strong_ratio-0.3));
        x = A(i,:);
        rows(end+1,:) = make_example_row( ...
            char(mode),'Hidden_PracticalRescue',x); %#ok<AGROW>
    end

    % Example B: hidden -> oracle rescued, practical not rescued.
    B = M( ...
        logical(M.pre_hidden) & ...
        logical(M.oracle_operator_rescue) & ...
        ~logical(M.practical_rescue),:);

    if ~isempty(B)
        [~,i] = min(abs(B.weak_to_strong_ratio-0.3));
        x = B(i,:);
        rows(end+1,:) = make_example_row( ...
            char(mode),'Hidden_ImplementationGap',x); %#ok<AGROW>
    end

    % Example C: hidden -> even oracle-parameter operator fails.
    C = M( ...
        logical(M.pre_hidden) & ...
        ~logical(M.oracle_operator_rescue),:);

    if ~isempty(C)
        [~,i] = min(abs(C.weak_to_strong_ratio-0.3));
        x = C(i,:);
        rows(end+1,:) = make_example_row( ...
            char(mode),'Hidden_OperatorLimit',x); %#ok<AGROW>
    end
end

if isempty(rows)
    E = table();
    return;
end

E = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','example_type', ...
    'delta_velocity_mps','strong_velocity_side', ...
    'Gamma','weak_to_strong_ratio','relative_phase_rad', ...
    'strong_est_error_over_width', ...
    'oracle_operator_distortion_ratio', ...
    'practical_error_ratio'});

end

%% ========================================================================
function r = make_example_row(mode,label,x)

r = { ...
    mode,label, ...
    x.delta_velocity_mps, ...
    x.strong_velocity_side{1}, ...
    x.Gamma_sep_over_width, ...
    x.weak_to_strong_ratio, ...
    x.relative_phase_rad, ...
    x.G3_strong_est_error_over_width, ...
    x.G2_operator_distortion_ratio, ...
    x.G3_practical_error_ratio};

end

%% ========================================================================
function write_summary( ...
    out_path,cfg,lambda,R0,beamwidth_rad, ...
    width_table,recovery_summary,contrast_summary, ...
    regime_summary,estimation_summary,decision_summary,examples)

fid = fopen(fullfile(out_path,'summary.txt'),'w');

fprintf(fid,'EXP009 PA5 / Physical Sequential Strong-Removal Recovery Map\n');
fprintf(fid,'===========================================================\n\n');

fprintf(fid,'Research question\n');
fprintf(fid,'-----------------\n');
fprintf(fid,['Can sequential strong removal reveal a weak component that ' ...
    'was hidden in the pre-removal FrAc landscape?\n\n']);

fprintf(fid,'Paper-grounded / derived physics\n');
fprintf(fid,'--------------------------------\n');
fprintf(fid,'fc = %.9g Hz\n',cfg.fc_hz);
fprintf(fid,'PRF = %.9g Hz\n',cfg.prf_hz);
fprintf(fid,'H = %.9g m\n',cfg.platform_height_m);
fprintf(fid,'L_a = %.9g m\n',cfg.antenna_length_m);
fprintf(fid,'V = %.9g m/s\n',cfg.platform_velocity_mps);
fprintf(fid,'lambda = %.9g m\n',lambda);
fprintf(fid,'representative R0/H = %.9g\n',cfg.slant_range_factor);
fprintf(fid,'R0 = %.9g m\n',R0);
fprintf(fid,'beamwidth ~= %.9g rad\n\n',beamwidth_rad);

fprintf(fid,'Controlled sweep inherited from PA4\n');
fprintf(fid,'-----------------------------------\n');
fprintf(fid,'weak velocity = %.6g m/s\n',cfg.weak_velocity_mps);
fprintf(fid,'Delta v = %s m/s\n',mat2str(cfg.delta_velocity_mps));
fprintf(fid,'A_w/A_s = %s\n',mat2str(cfg.weak_to_strong_ratio));
fprintf(fid,'relative phases = %d uniform values\n', ...
    cfg.num_relative_phases);
fprintf(fid,'b_s=b_w=0\n');
fprintf(fid,'No noise.\n\n');

fprintf(fid,'Groups\n');
fprintf(fid,'------\n');
fprintf(fid,'G0 WeakOnly\n');
fprintf(fid,'G1 FullMixture\n');
fprintf(fid,['G2 OracleParamCLEAN: true strong chirp parameter + LS ' ...
    'coefficient fit + subtraction\n']);
fprintf(fid,['G3 PracticalCLEAN: global-FrAc strong beta estimate + LS ' ...
    'coefficient fit + subtraction\n']);
fprintf(fid,['Gx ExactOracleSubtract: diagnostic only; should reproduce ' ...
    'the exact weak component up to numerical precision.\n\n']);

fprintf(fid,'Intrinsic widths\n');
fprintf(fid,'----------------\n');
for i = 1:height(width_table)
    fprintf(fid,'%s N=%d T=%.6f s Wbeta=%g rad\n', ...
        width_table.aperture_mode{i}, ...
        width_table.azimuth_samples(i), ...
        width_table.actual_observation_time_s(i), ...
        width_table.weak_single_3db_width_beta_rad(i));
end

fprintf(fid,'\nOverall recovery summary\n');
fprintf(fid,'------------------------\n');
for i = 1:height(recovery_summary)
    fprintf(fid,[ ...
        '%s hidden=%.4f oracleRescue=%.4f practicalRescue=%.4f ' ...
        'gap=%.4f opDist=%g practicalErr=%g strongEstOK=%.4f\n'], ...
        recovery_summary.aperture_mode{i}, ...
        recovery_summary.pre_hidden_rate(i), ...
        recovery_summary.oracle_operator_rescue_rate_on_hidden(i), ...
        recovery_summary.practical_rescue_rate_on_hidden(i), ...
        recovery_summary.implementation_gap_oracle_minus_practical(i), ...
        recovery_summary.median_oracle_operator_distortion_ratio_on_hidden(i), ...
        recovery_summary.median_practical_error_ratio_on_hidden(i), ...
        recovery_summary.practical_strong_estimation_success_rate_on_hidden(i));
end

fprintf(fid,'\nContrast summary\n');
fprintf(fid,'----------------\n');
for i = 1:height(contrast_summary)
    fprintf(fid,[ ...
        '%s r=%.3f hidden=%.4f oracle=%.4f practical=%.4f ' ...
        'gap=%.4f opDist=%g practicalErr=%g\n'], ...
        contrast_summary.aperture_mode{i}, ...
        contrast_summary.weak_to_strong_ratio(i), ...
        contrast_summary.pre_hidden_rate(i), ...
        contrast_summary.oracle_operator_rescue_rate_on_hidden(i), ...
        contrast_summary.practical_rescue_rate_on_hidden(i), ...
        contrast_summary.implementation_gap(i), ...
        contrast_summary.median_oracle_operator_distortion_ratio(i), ...
        contrast_summary.median_practical_error_ratio(i));
end

fprintf(fid,'\nRegime summary\n');
fprintf(fid,'--------------\n');
for i = 1:height(regime_summary)
    fprintf(fid,[ ...
        '%s %-18s n=%d hidden=%.4f oracle=%.4f practical=%.4f ' ...
        'practicalErr=%g strongEstErr/W=%g\n'], ...
        regime_summary.aperture_mode{i}, ...
        regime_summary.Gamma_regime{i}, ...
        regime_summary.n(i), ...
        regime_summary.pre_hidden_rate(i), ...
        regime_summary.oracle_operator_rescue_rate_on_hidden(i), ...
        regime_summary.practical_rescue_rate_on_hidden(i), ...
        regime_summary.median_practical_error_ratio_on_hidden(i), ...
        regime_summary.median_abs_strong_est_error_over_width_on_hidden(i));
end

fprintf(fid,'\nStrong-estimation summary\n');
fprintf(fid,'-------------------------\n');
for i = 1:height(estimation_summary)
    fprintf(fid,[ ...
        '%s med|err|/W=%g p90=%g success=%.4f ' ...
        'hiddenMed=%g hiddenSuccess=%.4f\n'], ...
        estimation_summary.aperture_mode{i}, ...
        estimation_summary.median_abs_strong_est_error_over_width(i), ...
        estimation_summary.p90_abs_strong_est_error_over_width(i), ...
        estimation_summary.strong_estimation_success_rate(i), ...
        estimation_summary.median_abs_strong_est_error_over_width_on_hidden(i), ...
        estimation_summary.strong_estimation_success_rate_on_hidden(i));
end

fprintf(fid,'\nDecision\n');
fprintf(fid,'--------\n');
for i = 1:height(decision_summary)
    fprintf(fid,'%s -> %s\n', ...
        decision_summary.aperture_mode{i}, ...
        decision_summary.decision_branch{i});
end

if ~isempty(examples)
    fprintf(fid,'\nRepresentative examples\n');
    fprintf(fid,'-----------------------\n');
    for i = 1:height(examples)
        fprintf(fid,[ ...
            '%s %s dv=%g side=%s Gamma=%g r=%g phi=%g ' ...
            'estErr/W=%g opDist=%g practicalErr=%g\n'], ...
            examples.aperture_mode{i}, ...
            examples.example_type{i}, ...
            examples.delta_velocity_mps(i), ...
            examples.strong_velocity_side{i}, ...
            examples.Gamma(i), ...
            examples.weak_to_strong_ratio(i), ...
            examples.relative_phase_rad(i), ...
            examples.strong_est_error_over_width(i), ...
            examples.oracle_operator_distortion_ratio(i), ...
            examples.practical_error_ratio(i));
    end
end

fprintf(fid,'\nInterpretation discipline\n');
fprintf(fid,'-------------------------\n');
fprintf(fid,['1) Hidden means no pre-removal LOCAL weak-associated FrAc peak. ' ...
    'It is an analysis label, not something the practical algorithm knows.\n']);
fprintf(fid,['2) Recovery is strongest when the post-removal GLOBAL residual ' ...
    'maximum is associated with the true weak component, matching the next ' ...
    'sequential extraction step.\n']);
fprintf(fid,['3) G2 uses true strong parameter but practical LS subtraction. ' ...
    'Therefore G0-vs-G2 measures operator distortion; G2-vs-G3 measures ' ...
    'strong-parameter estimation / implementation gap.\n']);
fprintf(fid,['4) Exact subtraction is only a sanity check and must not be used ' ...
    'to claim practical recoverability.\n']);
fprintf(fid,['5) Noise remains OFF. PA5 decides whether deterministic strong ' ...
    'removal is structurally useful before stochastic mechanisms return.\n']);

fclose(fid);

end

%% ========================================================================
function make_figures( ...
    out_path,cfg,T,recovery_summary, ...
    contrast_summary,regime_summary,estimation_summary)

modes = unique(string(T.aperture_mode),'stable');

%% Fig 1 — hidden rate by contrast
fig = figure('Visible',cfg.figure_visible);
hold on;

for im = 1:numel(modes)
    mode = modes(im);

    C = contrast_summary( ...
        strcmp(contrast_summary.aperture_mode,char(mode)),:);

    plot(C.weak_to_strong_ratio,C.pre_hidden_rate, ...
        'o-','LineWidth',1.3);
end

xlabel('Weak / strong amplitude ratio');
ylabel('Pre-removal hidden rate');
title('EXP009 PA5 — Weak Hidden Rate Before Strong Removal');
legend(modes,'Location','best');
ylim([0 1]);
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig01_pre_hidden_rate_vs_contrast.png'), ...
    'Resolution',180);
close(fig);

%% Fig 2 — oracle vs practical rescue by contrast
fig = figure('Visible',cfg.figure_visible);
hold on;

for im = 1:numel(modes)
    mode = modes(im);

    C = contrast_summary( ...
        strcmp(contrast_summary.aperture_mode,char(mode)),:);

    plot(C.weak_to_strong_ratio, ...
        C.oracle_operator_rescue_rate_on_hidden, ...
        'o-','LineWidth',1.2);

    plot(C.weak_to_strong_ratio, ...
        C.practical_rescue_rate_on_hidden, ...
        's--','LineWidth',1.2);
end

xlabel('Weak / strong amplitude ratio');
ylabel('Rescue rate conditioned on pre-hidden');
title('EXP009 PA5 — Oracle-Operator vs Practical Strong-Removal Rescue');
legend({ ...
    'Paper Oracle','Paper Practical', ...
    'Beam Oracle','Beam Practical'}, ...
    'Location','best');
ylim([0 1]);
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig02_rescue_rate_vs_contrast.png'), ...
    'Resolution',180);
close(fig);

%% Fig 3 — implementation gap by contrast
fig = figure('Visible',cfg.figure_visible);
hold on;

for im = 1:numel(modes)
    mode = modes(im);

    C = contrast_summary( ...
        strcmp(contrast_summary.aperture_mode,char(mode)),:);

    plot(C.weak_to_strong_ratio,C.implementation_gap, ...
        'o-','LineWidth',1.3);
end

xlabel('Weak / strong amplitude ratio');
ylabel('Oracle rescue - practical rescue');
title('EXP009 PA5 — Strong-Removal Implementation Gap');
legend(modes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig03_implementation_gap_vs_contrast.png'), ...
    'Resolution',180);
close(fig);

%% Fig 4 — rescue by Gamma regime
fig = figure('Visible',cfg.figure_visible);

regimes = {'Unresolved','Partial','ResolvedCandidate'};
Y = nan(numel(regimes),2);

for ir = 1:numel(regimes)
    for im = 1:numel(modes)
        mm = ...
            strcmp(regime_summary.Gamma_regime,regimes{ir}) & ...
            strcmp(regime_summary.aperture_mode,char(modes(im)));

        if any(mm)
            Y(ir,im) = ...
                regime_summary.practical_rescue_rate_on_hidden(mm);
        end
    end
end

bar(Y);
xticks(1:numel(regimes));
xticklabels(regimes);
ylabel('Practical rescue rate on hidden cohort');
title('EXP009 PA5 — Practical Rescue Across Resolution Regimes');
legend(modes,'Location','best');
ylim([0 1]);
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig04_practical_rescue_by_regime.png'), ...
    'Resolution',180);
close(fig);

%% Fig 5 — operator distortion vs practical residual error
fig = figure('Visible',cfg.figure_visible);
hold on;

for im = 1:numel(modes)
    mode = modes(im);

    M = T( ...
        string(T.aperture_mode)==mode & ...
        logical(T.pre_hidden),:);

    scatter( ...
        M.G2_operator_distortion_ratio, ...
        M.G3_practical_error_ratio, ...
        14,'filled');
end

xlabel('Oracle-parameter operator distortion ||r_{G2}-w||/||w||');
ylabel('Practical residual error ||r_{G3}-w||/||w||');
title('EXP009 PA5 — Operator Distortion vs Practical Residual Error');
legend(modes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig05_operator_vs_practical_error.png'), ...
    'Resolution',180);
close(fig);

%% Fig 6 — strong-estimation error vs Gamma
fig = figure('Visible',cfg.figure_visible);
hold on;

for im = 1:numel(modes)
    mode = modes(im);

    M = T( ...
        string(T.aperture_mode)==mode & ...
        logical(T.pre_hidden),:);

    scatter( ...
        M.Gamma_sep_over_width, ...
        M.G3_strong_est_error_over_width, ...
        14,'filled');
end

yline(0,'--');
xline(cfg.gamma_unresolved_max,'--');
xline(cfg.gamma_partial_max,':');

xlabel('\Gamma');
ylabel('Practical strong \beta estimation error / W_\beta');
title('EXP009 PA5 — Strong-Parameter Bias on Hidden-Weak Trials');
legend(modes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig06_strong_est_error_vs_Gamma.png'), ...
    'Resolution',180);
close(fig);

%% Fig 7 — overall recovery summary
fig = figure('Visible',cfg.figure_visible);

Y = [ ...
    recovery_summary.pre_hidden_rate, ...
    recovery_summary.oracle_operator_rescue_rate_on_hidden, ...
    recovery_summary.practical_rescue_rate_on_hidden];

bar(Y);

xticks(1:height(recovery_summary));
xticklabels(recovery_summary.aperture_mode);

ylabel('Rate');
title('EXP009 PA5 — Hidden Weak and Sequential Recovery');
legend({'Pre-hidden','Oracle-operator rescue','Practical rescue'}, ...
    'Location','best');
ylim([0 1]);
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig07_overall_recovery_summary.png'), ...
    'Resolution',180);
close(fig);

end

%% ========================================================================
function p = percentile_local(x,q)

x = sort(double(x(isfinite(x))));

if isempty(x)
    p = NaN;
    return;
end

if numel(x)==1
    p = x(1);
    return;
end

pos = 1+(numel(x)-1)*(q/100);

i1 = floor(pos);
i2 = ceil(pos);

if i1==i2
    p = x(i1);
else
    w = pos-i1;
    p = (1-w)*x(i1)+w*x(i2);
end

end
