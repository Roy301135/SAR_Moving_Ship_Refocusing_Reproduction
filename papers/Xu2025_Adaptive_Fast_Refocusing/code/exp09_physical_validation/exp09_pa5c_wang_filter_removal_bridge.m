function results = exp09_pa5c_wang_filter_removal_bridge()
%EXP09_PA5C_WANG_FILTER_REMOVAL_BRIDGE
% EXP009 / PA5C
%
% Wang-2023 Algorithm-2 Filter-Removal Bridge
%
% Research question
% -----------------
% Does the PA5B subtraction-tolerance mechanism survive when the analytic
% rank-1 LS projection is replaced by a Wang-style transform-domain
% narrowband removal operator?
%
% Literature-grounded operator structure
% --------------------------------------
% Wang 2023 Algorithm 2:
%   FrFT -> detect peaks > 0.7 max -> narrowband windows of length l
%   -> subtract filtered component in fractional domain -> inverse FrFT.
%
% Two items are NOT fully specified by the paper:
%   (i) one unique numerical l;
%   (ii) the exact discrete-FrFT implementation/scaling.
%
% PA5C therefore does NOT pretend those missing details are known.
% Instead:
%   - l is swept explicitly;
%   - FrFT removal is represented by an LFM-matched unitary bridge:
%
%       U_a{x} = FFTunitary( x .* exp(-j*pi*a*m^2) )
%
%     followed by Wang's threshold + narrowband mask, inverse FFT, and
%     re-chirp.
%
% For the discrete LFM model used in EXP009 this performs the same
% functional action: a matched LFM focuses to an impulse-like peak.
%
% Main comparison
% ---------------
% LS-P:
%   corrected practical one-atom LS projector (PA5B analytic reference).
%
% W-O:
%   Wang-style filter removal using TRUE strong chirp parameter.
%
% W-P:
%   Wang-style filter removal using PRACTICAL FrAc-estimated strong
%   chirp parameter.
%
% For each Wang mask Q:
%
%   r = (I-Q)(s+w)
%   e = r-w = (I-Q)s - Qw.
%
% Because the bridge transform is unitary and the binary mask is an
% orthogonal projector, the two terms are orthogonal for a fixed mask:
%
%   ||e||^2 =
%       ||(I-Q)s||^2 + ||Qw||^2.
%
% Thus PA5C can directly test the same error ownership:
%   strong leakage vs weak projection loss,
% but under the Wang-style multi-bin operator rather than rank-1 LS.
%
% Run:
%   results = exp09_pa5c_wang_filter_removal_bridge;

cfg = config_exp09_pa5c_wang_filter_removal_bridge();

%% Output path
this_dir = fileparts(mfilename('fullpath'));
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.output_dir)
    out_path = fullfile( ...
        paper_root,'results','exp09_physical_validation', ...
        'exp09_pa5c_wang_filter_removal_bridge');
else
    out_path = cfg.output_dir;
end

if ~exist(out_path,'dir')
    mkdir(out_path);
end

%% Physical constants
lambda = cfg.c/cfg.fc_hz;
R0 = cfg.platform_height_m*cfg.slant_range_factor;
beamwidth_rad = ...
    cfg.beamwidth_scale*lambda/cfg.antenna_length_m;

vw = cfg.weak_velocity_mps;

[~,~,Kw] = residual_fm_rates(vw,R0,lambda,cfg);
aw = Kw/(cfg.prf_hz^2);
beta_w = atan(aw);

%% Apertures
T_paper = cfg.paper_aperture_time_s;
N_paper = max(32,round(cfg.prf_hz*T_paper));

T_beam = ...
    R0*beamwidth_rad/cfg.platform_velocity_mps;
N_beam = max(32,round(cfg.prf_hz*T_beam));

aperture_names = ["Paper1s","BeamDerived"];
N_list = [N_paper,N_beam];
T_target_list = [T_paper,T_beam];

%% Weak-only intrinsic FrAc width calibration
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
        error('Could not estimate weak-only FrAc width for %s.',mode);
    end

    width_rows(end+1,:) = { ... %#ok<AGROW>
        char(mode),N,T_target,T_actual,max_lag,Wbeta};

    width_store.(char(mode)) = struct( ...
        'N',N, ...
        'T_actual',T_actual, ...
        'max_lag',max_lag, ...
        'Wbeta',Wbeta);
end

width_table = cell2table(width_rows, ...
    'VariableNames',{ ...
    'aperture_mode','azimuth_samples', ...
    'target_aperture_time_s','actual_observation_time_s', ...
    'max_frac_lag','weak_single_3db_width_beta_rad'});

writetable(width_table, ...
    fullfile(out_path,'pa5c_intrinsic_width_calibration.csv'));

%% Main PA5C sweep
rows = {};
sides = ["LowV","HighV"];

for ia = 1:2

    mode = aperture_names(ia);
    N = width_store.(char(mode)).N;
    max_lag = width_store.(char(mode)).max_lag;
    Wbeta = width_store.(char(mode)).Wbeta;

    w0 = synth_discrete_lfm( ...
        N,1,aw,cfg.center_frequency_cycles_per_sample,0);

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

            %% FrAc basis for practical strong-order estimation
            Rss = pair_frac_response( ...
                s0,s0,beta_grid,max_lag,cfg);

            Rww = pair_frac_response( ...
                w0,w0,beta_grid,max_lag,cfg);

            Rsw = pair_frac_response( ...
                s0,w0,beta_grid,max_lag,cfg);

            Rws = pair_frac_response( ...
                w0,s0,beta_grid,max_lag,cfg);

            for ir = 1:numel(cfg.weak_to_strong_ratio)

                rA = cfg.weak_to_strong_ratio(ir);

                for ip = 1:numel(cfg.relative_phase_rad)

                    phi = cfg.relative_phase_rad(ip);
                    cw = rA*exp(1j*phi);

                    x = s0 + cw*w0;
                    w_true = cw*w0;

                    %% Pre-removal hidden label
                    R1 = ...
                        Rss + ...
                        abs(cw)^2*Rww + ...
                        conj(cw)*Rsw + ...
                        cw*Rws;

                    P1 = sum(abs(R1).^2,2);
                    P1n = normalize_curve(P1);

                    peaks = local_peaks_with_prominence( ...
                        beta_grid,P1n, ...
                        cfg.min_peak_prominence_fraction);

                    [pre_weak_found,~,~] = ...
                        associate_peak( ...
                            peaks,beta_w,beta_sep,Wbeta,cfg);

                    pre_hidden = ~pre_weak_found;

                    %% Practical strong parameter from FrAc global maximum
                    [~,idx_hat] = max(P1);
                    beta_hat = beta_grid(idx_hat);
                    a_hat = tan(beta_hat);

                    strong_est_error_over_width = ...
                        (beta_hat-beta_s)/Wbeta;

                    %% PA5B corrected LS practical reference
                    h = synth_discrete_lfm( ...
                        N,1,a_hat, ...
                        cfg.center_frequency_cycles_per_sample,0);

                    c_ls = ...
                        (x*h') / ...
                        max(real(h*h'),cfg.small_norm_floor);

                    r_ls = x-c_ls*h;

                    ls_error_ratio = ...
                        norm(r_ls-w_true) / ...
                        max(norm(w_true),cfg.small_norm_floor);

                    [ls_weak_stage_ok,ls_weak_peak_ratio] = ...
                        weak_stage_readiness( ...
                            r_ls,aw,cfg);

                    %% Wang-style removal for every l
                    for il = 1:numel(cfg.filter_window_length_bins)

                        Lwin = cfg.filter_window_length_bins(il);

                        % W-O: true strong chirp parameter.
                        [r_wo,~,info_wo] = ...
                            wang_style_filter_remove( ...
                                x,as,Lwin,cfg);

                        wo_error_ratio = ...
                            norm(r_wo-w_true) / ...
                            max(norm(w_true),cfg.small_norm_floor);

                        [wo_weak_stage_ok,wo_weak_peak_ratio] = ...
                            weak_stage_readiness( ...
                                r_wo,aw,cfg);

                        % W-P: practical FrAc-estimated strong parameter.
                        [r_wp,~,info_wp] = ...
                            wang_style_filter_remove( ...
                                x,a_hat,Lwin,cfg);

                        wp_error_ratio = ...
                            norm(r_wp-w_true) / ...
                            max(norm(w_true),cfg.small_norm_floor);

                        [wp_weak_stage_ok,wp_weak_peak_ratio] = ...
                            weak_stage_readiness( ...
                                r_wp,aw,cfg);

                        %% Exact operator ownership for W-P fixed mask
                        [strong_residual,weak_removed] = ...
                            apply_fixed_mask_components( ...
                                s0,w_true,a_hat,info_wp.mask);

                        strong_leak_ratio_to_strong = ...
                            norm(strong_residual) / ...
                            max(norm(s0),cfg.small_norm_floor);

                        weak_projection_loss_ratio = ...
                            norm(weak_removed) / ...
                            max(norm(w_true),cfg.small_norm_floor);

                        wp_pred_error_ratio = sqrt( ...
                            (strong_leak_ratio_to_strong/rA)^2 + ...
                            weak_projection_loss_ratio^2);

                        identity_abs_error = ...
                            abs(wp_pred_error_ratio-wp_error_ratio);

                        denom = ...
                            (strong_leak_ratio_to_strong/rA)^2 + ...
                            weak_projection_loss_ratio^2;

                        if denom>0
                            strong_leak_error_fraction = ...
                                (strong_leak_ratio_to_strong/rA)^2/denom;
                        else
                            strong_leak_error_fraction = 0;
                        end

                        %% Oracle mask ownership
                        [strong_residual_o,weak_removed_o] = ...
                            apply_fixed_mask_components( ...
                                s0,w_true,as,info_wo.mask);

                        oracle_strong_leak_ratio = ...
                            norm(strong_residual_o) / ...
                            max(norm(s0),cfg.small_norm_floor);

                        oracle_weak_loss_ratio = ...
                            norm(weak_removed_o) / ...
                            max(norm(w_true),cfg.small_norm_floor);

                        rows(end+1,:) = { ... %#ok<AGROW>
                            char(mode),N, ...
                            dv,char(side),vs, ...
                            Gamma,char(regime), ...
                            rA,phi,double(pre_hidden), ...
                            beta_s,beta_hat, ...
                            strong_est_error_over_width, ...
                            Lwin,Lwin/N, ...
                            ls_error_ratio, ...
                            double(ls_weak_stage_ok), ...
                            ls_weak_peak_ratio, ...
                            wo_error_ratio, ...
                            double(wo_weak_stage_ok), ...
                            wo_weak_peak_ratio, ...
                            info_wo.num_detected_peaks, ...
                            info_wo.mask_fraction, ...
                            oracle_strong_leak_ratio, ...
                            oracle_weak_loss_ratio, ...
                            wp_error_ratio, ...
                            double(wp_weak_stage_ok), ...
                            wp_weak_peak_ratio, ...
                            info_wp.num_detected_peaks, ...
                            info_wp.mask_fraction, ...
                            strong_leak_ratio_to_strong, ...
                            weak_projection_loss_ratio, ...
                            strong_leak_error_fraction, ...
                            wp_pred_error_ratio, ...
                            identity_abs_error};
                    end
                end
            end
        end
    end
end

trial_table = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','azimuth_samples', ...
    'delta_velocity_mps','strong_velocity_side', ...
    'strong_velocity_mps', ...
    'Gamma_sep_over_width','Gamma_regime', ...
    'weak_to_strong_ratio','relative_phase_rad', ...
    'pre_hidden', ...
    'beta_strong_true_rad','beta_strong_hat_rad', ...
    'strong_est_error_over_width', ...
    'filter_window_length_bins','filter_window_fraction_N', ...
    'LS_practical_error_ratio', ...
    'LS_weak_stage_success','LS_weak_stage_peak_ratio', ...
    'Wang_oracle_error_ratio', ...
    'Wang_oracle_weak_stage_success', ...
    'Wang_oracle_weak_stage_peak_ratio', ...
    'Wang_oracle_num_detected_peaks', ...
    'Wang_oracle_mask_fraction', ...
    'Wang_oracle_strong_leak_ratio', ...
    'Wang_oracle_weak_projection_loss_ratio', ...
    'Wang_practical_error_ratio', ...
    'Wang_practical_weak_stage_success', ...
    'Wang_practical_weak_stage_peak_ratio', ...
    'Wang_practical_num_detected_peaks', ...
    'Wang_practical_mask_fraction', ...
    'Wang_practical_strong_leak_ratio', ...
    'Wang_practical_weak_projection_loss_ratio', ...
    'Wang_practical_strong_leak_error_fraction', ...
    'Wang_practical_predicted_error_ratio', ...
    'Wang_projection_identity_abs_error'});

writetable(trial_table, ...
    fullfile(out_path,'pa5c_trial_results.csv'));

%% Summaries
identity_summary = summarize_identity(trial_table,cfg);
window_summary = summarize_windows(trial_table);
contrast_window_summary = summarize_contrast_windows(trial_table);
regime_window_summary = summarize_regime_windows(trial_table);
balanced_summary = select_balanced_windows(window_summary);

writetable(identity_summary, ...
    fullfile(out_path,'pa5c_projection_identity_summary.csv'));

writetable(window_summary, ...
    fullfile(out_path,'pa5c_window_tradeoff_summary.csv'));

writetable(contrast_window_summary, ...
    fullfile(out_path,'pa5c_contrast_window_summary.csv'));

writetable(regime_window_summary, ...
    fullfile(out_path,'pa5c_regime_window_summary.csv'));

writetable(balanced_summary, ...
    fullfile(out_path,'pa5c_balanced_window_summary.csv'));

%% Controlled mismatch tolerance bridge
[tolerance_trials,tolerance_summary] = ...
    controlled_tolerance_bridge( ...
        cfg,width_store,lambda,R0,beta_w,aw);

writetable(tolerance_trials, ...
    fullfile(out_path,'pa5c_tolerance_trials.csv'));

writetable(tolerance_summary, ...
    fullfile(out_path,'pa5c_tolerance_summary.csv'));

%% Decision summary
decision_summary = build_decision_summary( ...
    identity_summary,window_summary,balanced_summary, ...
    tolerance_summary);

writetable(decision_summary, ...
    fullfile(out_path,'pa5c_decision_summary.csv'));

%% Text summary
write_summary( ...
    out_path,cfg,lambda,R0,width_table, ...
    identity_summary,window_summary,balanced_summary, ...
    tolerance_summary,decision_summary);

%% Figures
make_figures( ...
    out_path,cfg,trial_table,window_summary, ...
    contrast_window_summary,regime_window_summary, ...
    balanced_summary,tolerance_trials,tolerance_summary);

%% Save
results = struct();
results.cfg = cfg;
results.lambda = lambda;
results.R0 = R0;
results.width_table = width_table;
results.trial_table = trial_table;
results.identity_summary = identity_summary;
results.window_summary = window_summary;
results.contrast_window_summary = contrast_window_summary;
results.regime_window_summary = regime_window_summary;
results.balanced_summary = balanced_summary;
results.tolerance_trials = tolerance_trials;
results.tolerance_summary = tolerance_summary;
results.decision_summary = decision_summary;

save(fullfile(out_path,'exp09_pa5c_results.mat'), ...
    'results','-v7.3');

fprintf('\n============================================================\n');
fprintf(' EXP009 PA5C / Wang Algorithm-2 Filter-Removal Bridge\n');
fprintf('============================================================\n');
disp(identity_summary);
disp(window_summary);
disp(balanced_summary);
disp(tolerance_summary);
disp(decision_summary);
fprintf('============================================================\n');
fprintf('Saved to:\n%s\n\n',out_path);

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

N = numel(x_left);
nBeta = numel(beta_grid);

nfft = max(2048, ...
    2^nextpow2(cfg.frac_fft_oversample*N));

f = (-nfft/2:nfft/2-1).'/nfft;
tan_beta = tan(beta_grid(:));

R = complex(zeros(nBeta,max_lag));

for k = 1:max_lag

    z = ...
        x_left(1+k:end).* ...
        conj(x_right(1:end-k));

    Z = fftshift(fft(z,nfft));
    Z = Z(:);

    R(:,k) = interp1( ...
        f,Z,k*tan_beta,'linear',0) / ...
        max(numel(z),1);
end

end

%% ========================================================================
function W = estimate_3db_width(beta_grid,P,beta0)

P = real(P(:));

[~,i0] = min(abs(beta_grid-beta0));

halfwin = max(5,round(0.20*numel(beta_grid)));
i1 = max(1,i0-halfwin);
i2 = min(numel(beta_grid),i0+halfwin);

[~,j] = max(P(i1:i2));
ip = i1+j-1;

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
    step,cfg.beta_step_min_width_fraction*Wbeta);

lo = min(beta_w,beta_s)-cfg.beta_margin_widths*Wbeta;
hi = max(beta_w,beta_s)+cfg.beta_margin_widths*Wbeta;

beta_grid = linspace( ...
    lo,hi,ceil((hi-lo)/step)+1).';

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

P = real(P(:));

idx = find( ...
    P(2:end-1)>P(1:end-2) & ...
    P(2:end-1)>=P(3:end)) + 1;

if isempty(idx)
    [~,idx] = max(P);
end

pr = zeros(size(idx));

for j = 1:numel(idx)

    ii = idx(j);

    pr(j) = P(ii) - max( ...
        min(P(1:ii)), ...
        min(P(ii:end)));
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

peaks.beta = beta_grid(idx);
peaks.prominence = pr(:);

end

%% ========================================================================
function [found,beta_peak,prom] = ...
    associate_peak(peaks,beta_true,sep,Wbeta,cfg)

radius = max( ...
    cfg.peak_association_fraction_of_separation*sep, ...
    cfg.peak_association_min_width_fraction*Wbeta);

d = abs(peaks.beta-beta_true);
inside = find(d<=radius);

if isempty(inside)
    found = false;
    beta_peak = NaN;
    prom = NaN;
    return;
end

[~,ord] = sortrows([ ...
    d(inside), ...
    -peaks.prominence(inside)], ...
    [1 2]);

j = inside(ord(1));

found = true;
beta_peak = peaks.beta(j);
prom = peaks.prominence(j);

end

%% ========================================================================
function y = normalize_curve(y)

y = real(y(:));
m = max(y);

if m>0
    y = y/m;
end

end

%% ========================================================================
function Y = matched_lfm_transform(x,a)
% Unitary dechirp + FFT bridge.
%
% x[m] = exp(j*pi*a*m^2 + j*2*pi*b*m)
% becomes a spectral impulse at b when a is matched.

x = x(:).';
N = numel(x);
m = 0:N-1;

z = x .* exp(-1j*pi*a*m.^2);

Y = fftshift(fft(z))/sqrt(N);

end

%% ========================================================================
function x = inverse_matched_lfm_transform(Y,a)

Y = Y(:).';
N = numel(Y);
m = 0:N-1;

z = ifft(ifftshift(Y))*sqrt(N);

x = z .* exp(1j*pi*a*m.^2);

end

%% ========================================================================
function [residual,extracted,info] = ...
    wang_style_filter_remove(x,a_hat,Lwin,cfg)
% Wang-Algorithm-2 bridge:
%   matched transform
%   -> local peaks above 0.7 max
%   -> narrowband windows
%   -> inverse transform
%   -> subtraction.

Y = matched_lfm_transform(x,a_hat);
amp = abs(Y);

pk = find_transform_peaks( ...
    amp,cfg.frac_domain_peak_gate);

mask = false(size(Y));

half = floor((Lwin-1)/2);

for k = 1:numel(pk)

    i1 = max(1,pk(k)-half);
    i2 = min(numel(Y),pk(k)+half);

    mask(i1:i2) = true;
end

Y_extract = zeros(size(Y));
Y_extract(mask) = Y(mask);

extracted = inverse_matched_lfm_transform( ...
    Y_extract,a_hat);

residual = x-extracted;

info = struct();
info.mask = mask;
info.num_detected_peaks = numel(pk);
info.mask_fraction = mean(mask);
info.detected_peak_indices = pk;

end

%% ========================================================================
function pk = find_transform_peaks(amp,gate)

amp = real(amp(:).');

mx = max(amp);

idx = find( ...
    amp(2:end-1)>amp(1:end-2) & ...
    amp(2:end-1)>=amp(3:end)) + 1;

% Include endpoints only if they are local maxima.
if numel(amp)>=2
    if amp(1)>=amp(2)
        idx = [1 idx]; %#ok<AGROW>
    end

    if amp(end)>amp(end-1)
        idx = [idx numel(amp)]; %#ok<AGROW>
    end
end

idx = unique(idx);

keep = amp(idx) >= gate*mx;
pk = idx(keep);

if isempty(pk)
    [~,pk] = max(amp);
end

end

%% ========================================================================
function [strong_residual,weak_removed] = ...
    apply_fixed_mask_components(s,w,a_hat,mask)
% For fixed data-derived mask Q:
% strong_residual = (I-Q)s
% weak_removed    = Qw

Ys = matched_lfm_transform(s,a_hat);
Yw = matched_lfm_transform(w,a_hat);

Ys_keep = zeros(size(Ys));
Ys_keep(mask) = Ys(mask);

Yw_keep = zeros(size(Yw));
Yw_keep(mask) = Yw(mask);

Qs = inverse_matched_lfm_transform( ...
    Ys_keep,a_hat);

Qw = inverse_matched_lfm_transform( ...
    Yw_keep,a_hat);

strong_residual = s-Qs;
weak_removed = Qw;

end

%% ========================================================================
function [ok,peak_ratio] = ...
    weak_stage_readiness(residual,a_weak,cfg)
% Source-aligned stage-readiness metric:
% at the true weak matched order, is the focused weak-bin peak within the
% paper's 0.7*global-max peak gate?

Y = matched_lfm_transform(residual,a_weak);
amp = abs(Y);

N = numel(amp);
dc = floor(N/2)+1;

i1 = max(1,dc-cfg.weak_stage_center_tolerance_bins);
i2 = min(N,dc+cfg.weak_stage_center_tolerance_bins);

local_peak = max(amp(i1:i2));
global_peak = max(amp);

peak_ratio = ...
    local_peak/max(global_peak,cfg.small_norm_floor);

ok = peak_ratio >= cfg.weak_stage_peak_gate;

end

%% ========================================================================
function S = summarize_identity(T,cfg)

modes = unique(string(T.aperture_mode),'stable');
rows = {};

for i = 1:numel(modes)

    M = T(string(T.aperture_mode)==modes(i),:);

    e = M.Wang_projection_identity_abs_error;
    e = e(isfinite(e));

    rows(end+1,:) = { ... %#ok<AGROW>
        char(modes(i)),height(M), ...
        median(e),max(e), ...
        double(max(e)<=cfg.identity_max_abs_error_gate)};
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','n', ...
    'median_identity_abs_error', ...
    'max_identity_abs_error', ...
    'identity_gate_pass'});

end

%% ========================================================================
function S = summarize_windows(T)

modes = unique(string(T.aperture_mode),'stable');
wins = unique(T.filter_window_length_bins).';

rows = {};

for i = 1:numel(modes)

    for j = 1:numel(wins)

        M = T( ...
            string(T.aperture_mode)==modes(i) & ...
            T.filter_window_length_bins==wins(j),:);

        H = M(logical(M.pre_hidden),:);

        if isempty(H)
            rows(end+1,:) = { ... %#ok<AGROW>
                char(modes(i)),wins(j),0, ...
                NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN};
            continue;
        end

        rows(end+1,:) = { ... %#ok<AGROW>
            char(modes(i)),wins(j),height(H), ...
            mean(H.LS_weak_stage_success), ...
            median(H.LS_practical_error_ratio,'omitnan'), ...
            mean(H.Wang_oracle_weak_stage_success), ...
            median(H.Wang_oracle_error_ratio,'omitnan'), ...
            mean(H.Wang_practical_weak_stage_success), ...
            median(H.Wang_practical_error_ratio,'omitnan'), ...
            median(H.Wang_practical_strong_leak_ratio,'omitnan'), ...
            median(H.Wang_practical_weak_projection_loss_ratio,'omitnan'), ...
            median(H.Wang_practical_strong_leak_error_fraction,'omitnan'), ...
            median(H.Wang_practical_mask_fraction,'omitnan')};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','filter_window_length_bins','n_hidden', ...
    'LS_weak_stage_success_rate', ...
    'LS_median_error_ratio', ...
    'Wang_oracle_weak_stage_success_rate', ...
    'Wang_oracle_median_error_ratio', ...
    'Wang_practical_weak_stage_success_rate', ...
    'Wang_practical_median_error_ratio', ...
    'Wang_practical_median_strong_leak_ratio', ...
    'Wang_practical_median_weak_projection_loss_ratio', ...
    'Wang_practical_median_strong_leak_error_fraction', ...
    'Wang_practical_median_mask_fraction'});

end

%% ========================================================================
function S = summarize_contrast_windows(T)

modes = unique(string(T.aperture_mode),'stable');
wins = unique(T.filter_window_length_bins).';
ratios = unique(T.weak_to_strong_ratio).';

rows = {};

for i = 1:numel(modes)

    for ir = 1:numel(ratios)

        for j = 1:numel(wins)

            H = T( ...
                string(T.aperture_mode)==modes(i) & ...
                T.filter_window_length_bins==wins(j) & ...
                abs(T.weak_to_strong_ratio-ratios(ir))<1e-12 & ...
                logical(T.pre_hidden),:);

            rows(end+1,:) = { ... %#ok<AGROW>
                char(modes(i)),ratios(ir),wins(j),height(H), ...
                mean(H.Wang_practical_weak_stage_success), ...
                median(H.Wang_practical_error_ratio,'omitnan'), ...
                median(H.Wang_practical_strong_leak_ratio,'omitnan'), ...
                median(H.Wang_practical_weak_projection_loss_ratio,'omitnan')};
        end
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','weak_to_strong_ratio', ...
    'filter_window_length_bins','n_hidden', ...
    'Wang_practical_weak_stage_success_rate', ...
    'Wang_practical_median_error_ratio', ...
    'Wang_practical_median_strong_leak_ratio', ...
    'Wang_practical_median_weak_projection_loss_ratio'});

end

%% ========================================================================
function S = summarize_regime_windows(T)

modes = unique(string(T.aperture_mode),'stable');
wins = unique(T.filter_window_length_bins).';
regs = ["Unresolved","Partial","ResolvedCandidate"];

rows = {};

for i = 1:numel(modes)

    for ig = 1:numel(regs)

        for j = 1:numel(wins)

            M = T( ...
                string(T.aperture_mode)==modes(i) & ...
                string(T.Gamma_regime)==regs(ig) & ...
                T.filter_window_length_bins==wins(j),:);

            H = M(logical(M.pre_hidden),:);

            if isempty(M)
                hidden_rate = NaN;
            else
                hidden_rate = height(H)/height(M);
            end

            rows(end+1,:) = { ... %#ok<AGROW>
                char(modes(i)),char(regs(ig)),wins(j), ...
                height(M),height(H),hidden_rate, ...
                mean(H.Wang_practical_weak_stage_success), ...
                median(H.Wang_practical_error_ratio,'omitnan')};
        end
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','Gamma_regime', ...
    'filter_window_length_bins','n','n_hidden', ...
    'pre_hidden_rate', ...
    'Wang_practical_weak_stage_success_rate', ...
    'Wang_practical_median_error_ratio'});

end

%% ========================================================================
function B = select_balanced_windows(S)
% Do not pretend the paper supplies one l.
% Report:
%   best-error window;
%   best-success window;
%   balanced window = min-error among windows whose success is at least
%   90% of the maximum success for that aperture.

modes = unique(string(S.aperture_mode),'stable');
rows = {};

for i = 1:numel(modes)

    M = S(string(S.aperture_mode)==modes(i),:);

    [~,ie] = min(M.Wang_practical_median_error_ratio);

    maxsucc = max(M.Wang_practical_weak_stage_success_rate);
    eligible = ...
        M.Wang_practical_weak_stage_success_rate >= 0.90*maxsucc;

    idx = find(eligible);

    [~,jj] = min( ...
        M.Wang_practical_median_error_ratio(idx));

    ib = idx(jj);

    [~,is] = max(M.Wang_practical_weak_stage_success_rate);

    rows(end+1,:) = { ... %#ok<AGROW>
        char(modes(i)), ...
        M.filter_window_length_bins(ie), ...
        M.Wang_practical_median_error_ratio(ie), ...
        M.Wang_practical_weak_stage_success_rate(ie), ...
        M.filter_window_length_bins(is), ...
        M.Wang_practical_median_error_ratio(is), ...
        M.Wang_practical_weak_stage_success_rate(is), ...
        M.filter_window_length_bins(ib), ...
        M.Wang_practical_median_error_ratio(ib), ...
        M.Wang_practical_weak_stage_success_rate(ib)};
end

B = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode', ...
    'best_error_window_bins', ...
    'best_error_median_error_ratio', ...
    'best_error_success_rate', ...
    'best_success_window_bins', ...
    'best_success_median_error_ratio', ...
    'best_success_rate', ...
    'balanced_window_bins', ...
    'balanced_median_error_ratio', ...
    'balanced_success_rate'});

end

%% ========================================================================
function [T,S] = controlled_tolerance_bridge( ...
    cfg,width_store,lambda,R0,beta_w,aw)

modes = ["Paper1s","BeamDerived"];
rows = {};

dv = cfg.tolerance_delta_velocity_mps;

for ia = 1:2

    mode = modes(ia);
    N = width_store.(char(mode)).N;
    Wbeta = width_store.(char(mode)).Wbeta;

    if strcmpi(cfg.tolerance_side,'HighV')
        vs = cfg.weak_velocity_mps+dv;
    else
        vs = cfg.weak_velocity_mps-dv;
    end

    [~,~,Ks] = residual_fm_rates(vs,R0,lambda,cfg);

    as = Ks/(cfg.prf_hz^2);
    beta_s = atan(as);

    s0 = synth_discrete_lfm(N,1,as,0,0);
    w0 = synth_discrete_lfm(N,1,aw,0,0);

    for ir = 1:numel(cfg.weak_to_strong_ratio)

        rA = cfg.weak_to_strong_ratio(ir);
        w = rA*w0;

        for il = 1:numel(cfg.filter_window_length_bins)

            Lwin = cfg.filter_window_length_bins(il);

            for id = 1:numel(cfg.tolerance_delta_beta_over_width)

                dnorm = cfg.tolerance_delta_beta_over_width(id);

                beta_hat = beta_s+dnorm*Wbeta;
                a_hat = tan(beta_hat);

                % Build the mask from the STRONG-ONLY transform.
                % This isolates parameter mismatch + window width without
                % phase-dependent data-selection effects.
                Ystrong = matched_lfm_transform(s0,a_hat);
                pk = find_transform_peaks( ...
                    abs(Ystrong),cfg.frac_domain_peak_gate);

                mask = false(size(Ystrong));
                half = floor((Lwin-1)/2);

                for k = 1:numel(pk)
                    i1 = max(1,pk(k)-half);
                    i2 = min(N,pk(k)+half);
                    mask(i1:i2) = true;
                end

                [sr,wr] = apply_fixed_mask_components( ...
                    s0,w,a_hat,mask);

                Ls = norm(sr)/norm(s0);
                Dw = norm(wr)/max(norm(w),cfg.small_norm_floor);

                E = sqrt((Ls/rA)^2+Dw^2);

                rows(end+1,:) = { ... %#ok<AGROW>
                    char(mode),rA,Lwin,dnorm, ...
                    Ls,Dw,E,mean(mask)};
            end
        end
    end
end

T = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','weak_to_strong_ratio', ...
    'filter_window_length_bins', ...
    'delta_beta_over_width', ...
    'strong_leak_ratio', ...
    'weak_projection_loss_ratio', ...
    'predicted_error_ratio', ...
    'mask_fraction'});

%% Symmetric E<=1 tolerance
sumrows = {};

for ia = 1:numel(modes)

    for ir = 1:numel(cfg.weak_to_strong_ratio)

        rA = cfg.weak_to_strong_ratio(ir);

        for il = 1:numel(cfg.filter_window_length_bins)

            Lwin = cfg.filter_window_length_bins(il);

            M = T( ...
                string(T.aperture_mode)==modes(ia) & ...
                abs(T.weak_to_strong_ratio-rA)<1e-12 & ...
                T.filter_window_length_bins==Lwin,:);

            M = sortrows(M,'delta_beta_over_width');

            tol = symmetric_tolerance( ...
                M.delta_beta_over_width, ...
                M.predicted_error_ratio, ...
                cfg.tolerance_error_threshold);

            E0 = interp1( ...
                M.delta_beta_over_width, ...
                M.predicted_error_ratio, ...
                0,'linear');

            sumrows(end+1,:) = { ... %#ok<AGROW>
                char(modes(ia)),rA,Lwin,E0,tol};
        end
    end
end

S = cell2table(sumrows, ...
    'VariableNames',{ ...
    'aperture_mode','weak_to_strong_ratio', ...
    'filter_window_length_bins', ...
    'zero_mismatch_error_ratio', ...
    'allowed_abs_beta_error_over_width_for_E_le_1'});

end

%% ========================================================================
function tol = symmetric_tolerance(delta,E,thr)

[delta,ord] = sort(delta(:));
E = E(ord);

[~,i0] = min(abs(delta));

if E(i0)>thr
    tol = 0;
    return;
end

il = i0;
while il>1 && E(il-1)<=thr
    il = il-1;
end

ir = i0;
while ir<numel(E) && E(ir+1)<=thr
    ir = ir+1;
end

tol = min(abs(delta(il)),abs(delta(ir)));

end

%% ========================================================================
function D = build_decision_summary( ...
    I,W,B,Tol)

modes = string(I.aperture_mode);
rows = {};

for i = 1:numel(modes)

    mode = modes(i);

    Wi = W(string(W.aperture_mode)==mode,:);
    Bi = B(string(B.aperture_mode)==mode,:);
    Ti = Tol(string(Tol.aperture_mode)==mode,:);

    % Does a nontrivial window tradeoff exist?
    err_span = ...
        max(Wi.Wang_practical_median_error_ratio) - ...
        min(Wi.Wang_practical_median_error_ratio);

    leak = Wi.Wang_practical_median_strong_leak_ratio;
    loss = Wi.Wang_practical_median_weak_projection_loss_ratio;

    tradeoff_exists = ...
        (leak(1)>leak(end)) && ...
        (loss(1)<loss(end));

    % Does tolerance generally increase with rA at balanced l?
    Lb = Bi.balanced_window_bins;

    Tb = Ti(Ti.filter_window_length_bins==Lb,:);

    rr = Tb.weak_to_strong_ratio;
    tt = Tb.allowed_abs_beta_error_over_width_for_E_le_1;

    [rr,ord] = sort(rr);
    tt = tt(ord);

    monotonic_tol = all(diff(tt)>=-1e-12);

    if I.identity_gate_pass(i)==0
        branch = "OPERATOR_IDENTITY_REVIEW";
    elseif tradeoff_exists && monotonic_tol
        branch = "WINDOW_TRADEOFF_WITH_CONTRAST_SCALED_TOLERANCE";
    elseif tradeoff_exists
        branch = "WINDOW_TRADEOFF_BUT_TOLERANCE_LAW_NOT_MONOTONIC";
    elseif err_span<0.05
        branch = "WINDOW_WIDTH_WEAK_EFFECT";
    else
        branch = "MIXED_OPERATOR_BEHAVIOR";
    end

    rows(end+1,:) = { ... %#ok<AGROW>
        char(mode), ...
        double(tradeoff_exists), ...
        err_span, ...
        Bi.balanced_window_bins, ...
        Bi.balanced_median_error_ratio, ...
        Bi.balanced_success_rate, ...
        double(monotonic_tol), ...
        char(branch)};
end

D = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode', ...
    'strong_leak_vs_weak_loss_tradeoff_detected', ...
    'practical_error_span_across_windows', ...
    'balanced_window_bins', ...
    'balanced_median_error_ratio', ...
    'balanced_weak_stage_success_rate', ...
    'contrast_tolerance_monotonic', ...
    'decision_branch'});

end

%% ========================================================================
function write_summary( ...
    out_path,cfg,lambda,R0,width_table, ...
    I,W,B,Tol,D)

fid = fopen(fullfile(out_path,'summary.txt'),'w');

fprintf(fid,'EXP009 PA5C / Wang Algorithm-2 Filter-Removal Bridge\n');
fprintf(fid,'===================================================\n\n');

fprintf(fid,'SOURCE-GROUNDED ALGORITHM STRUCTURE\n');
fprintf(fid,'----------------------------------\n');
fprintf(fid,['Wang 2023 Algorithm 2 performs FrFT at each optimal order, ' ...
    'detects peaks above 0.7*max, narrowband-filters windows of length l, ' ...
    'subtracts the filtered component, and inverse-transforms the residual.\n\n']);

fprintf(fid,'UNREPORTED / UNDER-SPECIFIED ITEMS\n');
fprintf(fid,'---------------------------------\n');
fprintf(fid,['The paper algorithm text does not provide one unique numerical l, ' ...
    'so l is swept: %s bins.\n'], ...
    mat2str(cfg.filter_window_length_bins));
fprintf(fid,['The exact authors'' discrete-FrFT implementation/scaling is not ' ...
    'fully specified, so PA5C uses a labelled unitary LFM-matched ' ...
    'dechirp-FFT bridge. Do not call PA5C a bit-exact reproduction.\n\n']);

fprintf(fid,'Physical setup\n');
fprintf(fid,'--------------\n');
fprintf(fid,'fc=%g Hz, PRF=%g Hz, lambda=%g m, R0=%g m\n', ...
    cfg.fc_hz,cfg.prf_hz,lambda,R0);
fprintf(fid,'weak velocity=%g m/s\n',cfg.weak_velocity_mps);
fprintf(fid,'Delta v=%s m/s\n',mat2str(cfg.delta_velocity_mps));
fprintf(fid,'Aw/As=%s\n',mat2str(cfg.weak_to_strong_ratio));
fprintf(fid,'phase count=%d\n\n',cfg.num_relative_phases);

fprintf(fid,'Intrinsic widths\n');
fprintf(fid,'----------------\n');
for i=1:height(width_table)
    fprintf(fid,'%s N=%d T=%g Wbeta=%g\n', ...
        width_table.aperture_mode{i}, ...
        width_table.azimuth_samples(i), ...
        width_table.actual_observation_time_s(i), ...
        width_table.weak_single_3db_width_beta_rad(i));
end

fprintf(fid,'\nProjection identity\n');
fprintf(fid,'-------------------\n');
for i=1:height(I)
    fprintf(fid,'%s maxAbsErr=%g gate=%d\n', ...
        I.aperture_mode{i}, ...
        I.max_identity_abs_error(i), ...
        I.identity_gate_pass(i));
end

fprintf(fid,'\nWindow tradeoff\n');
fprintf(fid,'---------------\n');
for i=1:height(W)
    fprintf(fid,[ ...
        '%s L=%d hiddenN=%d LSsucc=%g LSerr=%g ' ...
        'WOsucc=%g WOerr=%g WPsucc=%g WPerr=%g ' ...
        'strongLeak=%g weakLoss=%g leakFrac=%g maskFrac=%g\n'], ...
        W.aperture_mode{i}, ...
        W.filter_window_length_bins(i), ...
        W.n_hidden(i), ...
        W.LS_weak_stage_success_rate(i), ...
        W.LS_median_error_ratio(i), ...
        W.Wang_oracle_weak_stage_success_rate(i), ...
        W.Wang_oracle_median_error_ratio(i), ...
        W.Wang_practical_weak_stage_success_rate(i), ...
        W.Wang_practical_median_error_ratio(i), ...
        W.Wang_practical_median_strong_leak_ratio(i), ...
        W.Wang_practical_median_weak_projection_loss_ratio(i), ...
        W.Wang_practical_median_strong_leak_error_fraction(i), ...
        W.Wang_practical_median_mask_fraction(i));
end

fprintf(fid,'\nBalanced windows\n');
fprintf(fid,'----------------\n');
for i=1:height(B)
    fprintf(fid,[ ...
        '%s bestErrorL=%d bestSuccessL=%d balancedL=%d ' ...
        'balancedErr=%g balancedSuccess=%g\n'], ...
        B.aperture_mode{i}, ...
        B.best_error_window_bins(i), ...
        B.best_success_window_bins(i), ...
        B.balanced_window_bins(i), ...
        B.balanced_median_error_ratio(i), ...
        B.balanced_success_rate(i));
end

fprintf(fid,'\nControlled tolerance bridge\n');
fprintf(fid,'---------------------------\n');
for i=1:height(Tol)
    fprintf(fid,'%s r=%g L=%d E0=%g tol(E<=1)=%g\n', ...
        Tol.aperture_mode{i}, ...
        Tol.weak_to_strong_ratio(i), ...
        Tol.filter_window_length_bins(i), ...
        Tol.zero_mismatch_error_ratio(i), ...
        Tol.allowed_abs_beta_error_over_width_for_E_le_1(i));
end

fprintf(fid,'\nDecision\n');
fprintf(fid,'--------\n');
for i=1:height(D)
    fprintf(fid,'%s -> %s\n', ...
        D.aperture_mode{i}, ...
        D.decision_branch{i});
end

fprintf(fid,'\nInterpretation discipline\n');
fprintf(fid,'-------------------------\n');
fprintf(fid,['1) PA5C tests Wang Algorithm-2 operator structure, not a private ' ...
    'bit-exact DFrFT implementation.\n']);
fprintf(fid,['2) l is a sensitivity axis because the paper defines it but does ' ...
    'not provide one unique value in Algorithm 2.\n']);
fprintf(fid,['3) Weak-stage success uses the paper-reported 0.7 peak gate at the ' ...
    'true weak matched order.\n']);
fprintf(fid,['4) For a fixed binary mask under a unitary transform, error ' ...
    'ownership remains exactly strong leakage + weak projection loss.\n']);
fprintf(fid,['5) Noise remains OFF. Only after this operator bridge is understood ' ...
    'should stochastic noise/clutter be reintroduced.\n']);

fclose(fid);

end

%% ========================================================================
function make_figures( ...
    out_path,cfg,T,W,C,G,B,Ttol,Stol)

modes = unique(string(T.aperture_mode),'stable');
wins = cfg.filter_window_length_bins;

%% Fig 1 — practical success vs l
fig = figure('Visible',cfg.figure_visible);
hold on;

for i=1:numel(modes)
    M = W(string(W.aperture_mode)==modes(i),:);
    plot(M.filter_window_length_bins, ...
        M.Wang_practical_weak_stage_success_rate, ...
        'o-','LineWidth',1.3);
end

xlabel('Narrowband window length l (bins)');
ylabel('Weak-stage success rate on pre-hidden cohort');
title('EXP009 PA5C — Wang-Style Practical Weak-Stage Success vs Window');
legend(modes,'Location','best');
ylim([0 1]);
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig01_practical_success_vs_window.png'), ...
    'Resolution',180);
close(fig);

%% Fig 2 — practical error vs l
fig = figure('Visible',cfg.figure_visible);
hold on;

for i=1:numel(modes)
    M = W(string(W.aperture_mode)==modes(i),:);
    plot(M.filter_window_length_bins, ...
        M.Wang_practical_median_error_ratio, ...
        'o-','LineWidth',1.3);
end

xlabel('Narrowband window length l (bins)');
ylabel('Median ||r-w|| / ||w||');
title('EXP009 PA5C — Wang-Style Practical Residual Error vs Window');
legend(modes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig02_practical_error_vs_window.png'), ...
    'Resolution',180);
close(fig);

%% Fig 3 — leakage/loss tradeoff
fig = figure('Visible',cfg.figure_visible);
hold on;

for i=1:numel(modes)

    M = W(string(W.aperture_mode)==modes(i),:);

    plot(M.filter_window_length_bins, ...
        M.Wang_practical_median_strong_leak_ratio, ...
        'o-','LineWidth',1.2);

    plot(M.filter_window_length_bins, ...
        M.Wang_practical_median_weak_projection_loss_ratio, ...
        's--','LineWidth',1.2);
end

xlabel('Narrowband window length l (bins)');
ylabel('Median normalized component error');
title('EXP009 PA5C — Strong Leakage / Weak Projection-Loss Tradeoff');
legend({'Paper strong leak','Paper weak loss', ...
        'Beam strong leak','Beam weak loss'}, ...
       'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig03_leakage_loss_tradeoff.png'), ...
    'Resolution',180);
close(fig);

%% Fig 4 — exact operator identity
fig = figure('Visible',cfg.figure_visible);
hold on;
vals = [];

for i=1:numel(modes)
    M = T(string(T.aperture_mode)==modes(i),:);
    scatter(M.Wang_practical_predicted_error_ratio, ...
        M.Wang_practical_error_ratio,12,'filled');
    vals = [vals; ...
        M.Wang_practical_predicted_error_ratio; ...
        M.Wang_practical_error_ratio]; %#ok<AGROW>
end

vals = vals(isfinite(vals));

if ~isempty(vals)
    lo=min(vals); hi=max(vals);
    plot([lo hi],[lo hi],'--');
end

xlabel('Predicted Wang-filter error');
ylabel('Measured Wang-filter error');
title('EXP009 PA5C — Transform-Domain Projection Identity');
legend([cellstr(modes);{'y=x'}],'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig04_operator_identity.png'), ...
    'Resolution',180);
close(fig);

%% Fig 5 — corrected LS vs Wang practical at balanced l
fig = figure('Visible',cfg.figure_visible);
hold on;
vals=[];

for i=1:numel(modes)

    Lb = B.balanced_window_bins( ...
        string(B.aperture_mode)==modes(i));

    M = T( ...
        string(T.aperture_mode)==modes(i) & ...
        T.filter_window_length_bins==Lb & ...
        logical(T.pre_hidden),:);

    scatter(M.LS_practical_error_ratio, ...
        M.Wang_practical_error_ratio,14,'filled');

    vals=[vals;M.LS_practical_error_ratio; ...
        M.Wang_practical_error_ratio]; %#ok<AGROW>
end

vals=vals(isfinite(vals));

if ~isempty(vals)
    lo=min(vals); hi=max(vals);
    plot([lo hi],[lo hi],'--');
end

xlabel('Corrected LS practical error');
ylabel('Wang-style practical error');
title('EXP009 PA5C — Rank-1 LS vs Wang-Style Removal');
legend([cellstr(modes);{'y=x'}],'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig05_ls_vs_wang_error.png'), ...
    'Resolution',180);
close(fig);

%% Fig 6 — contrast x window error map, BeamDerived
mode="BeamDerived";
M=C(string(C.aperture_mode)==mode,:);

rr=unique(M.weak_to_strong_ratio).';
LL=unique(M.filter_window_length_bins).';

Z=nan(numel(rr),numel(LL));

for ir=1:numel(rr)
    for il=1:numel(LL)
        q = ...
            abs(M.weak_to_strong_ratio-rr(ir))<1e-12 & ...
            M.filter_window_length_bins==LL(il);
        Z(ir,il)=M.Wang_practical_median_error_ratio(q);
    end
end

fig=figure('Visible',cfg.figure_visible);
imagesc(LL,rr,Z);
set(gca,'YDir','normal');
colorbar;
xlabel('Window length l (bins)');
ylabel('A_w/A_s');
title('EXP009 PA5C — BeamDerived Practical Error Map');

exportgraphics(fig, ...
    fullfile(out_path,'fig06_beam_contrast_window_error_map.png'), ...
    'Resolution',180);
close(fig);

%% Fig 7 — controlled tolerance vs contrast for each l, Beam
fig=figure('Visible',cfg.figure_visible);
hold on;

for il=1:numel(wins)

    M=Stol( ...
        string(Stol.aperture_mode)=="BeamDerived" & ...
        Stol.filter_window_length_bins==wins(il),:);

    plot(M.weak_to_strong_ratio, ...
        M.allowed_abs_beta_error_over_width_for_E_le_1, ...
        'o-','LineWidth',1.2);
end

xlabel('A_w/A_s');
ylabel('Allowed |\delta\beta_s|/W_\beta for E\leq1');
title('EXP009 PA5C — Wang-Style Subtraction Tolerance vs Contrast');
legend(arrayfun(@(x)sprintf('l=%d',x),wins, ...
    'UniformOutput',false),'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig07_tolerance_vs_contrast_by_window.png'), ...
    'Resolution',180);
close(fig);

%% Fig 8 — regime success at balanced l
regs={'Unresolved','Partial','ResolvedCandidate'};
Y=nan(numel(regs),numel(modes));

for i=1:numel(modes)

    Lb=B.balanced_window_bins( ...
        string(B.aperture_mode)==modes(i));

    for j=1:numel(regs)

        q = ...
            strcmp(G.aperture_mode,char(modes(i))) & ...
            strcmp(G.Gamma_regime,regs{j}) & ...
            G.filter_window_length_bins==Lb;

        if any(q)
            Y(j,i)=G.Wang_practical_weak_stage_success_rate(q);
        end
    end
end

fig=figure('Visible',cfg.figure_visible);
bar(Y);
xticks(1:numel(regs));
xticklabels(regs);
ylabel('Weak-stage success rate');
title('EXP009 PA5C — Wang-Style Success Across Resolution Regimes');
legend(modes,'Location','best');
ylim([0 1]);
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig08_regime_success_balanced_window.png'), ...
    'Resolution',180);
close(fig);

end
