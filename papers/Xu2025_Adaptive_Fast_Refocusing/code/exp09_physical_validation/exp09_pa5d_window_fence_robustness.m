function results = exp09_pa5d_window_fence_robustness()
%EXP09_PA5D_WINDOW_FENCE_ROBUSTNESS
% EXP009 / PA5D
%
% Window-Normalized and Fence-Effect Robustness of Strong Removal
%
% Research questions
% ------------------
% RQ1. Was PA5C's apparent l=3 balance partly a consequence of comparing
%      identical bin counts across different aperture lengths?
%
% RQ2. Does the strong-leakage / weak-projection-loss tradeoff survive when
%      the focused component is off the FFT grid?
%
% RQ3. Does the subtraction-tolerance law remain approximately
%
%          |delta beta_s| / W_beta  proportional to  A_w/A_s
%
%      after equal-bandwidth normalization and fence-effect perturbation?
%
% RQ4. Is the tolerance symmetric for positive and negative strong-order
%      mismatch once the focused peak is off-grid?
%
% Window families
% ---------------
% FixedBins:
%   l = [1,3,5,9,17] for both apertures (PA5C convention).
%
% BandwidthMatched:
%   use target l/N fractions defined by Paper1s, then convert them to the
%   nearest positive odd bin count for each aperture.
%
% Since PRF is common, equal l/N is also equal l*PRF/N physical bandwidth.
%
% Fence-effect factor
% -------------------
% Both strong and weak components receive the SAME center-frequency offset
%
%       b = eta/N
%
% so their relative physical center frequency remains zero and only the
% off-grid focusing condition changes.
%
% No noise.
%
% Run:
%   results = exp09_pa5d_window_fence_robustness;

cfg = config_exp09_pa5d_window_fence_robustness();

%% Output path
this_dir = fileparts(mfilename('fullpath'));
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.output_dir)
    out_path = fullfile( ...
        paper_root,'results','exp09_physical_validation', ...
        'exp09_pa5d_window_fence_robustness');
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

%% Intrinsic weak FrAc width
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

    % Width is independent of common b, so use b=0.
    w0 = synth_discrete_lfm(N,1,aw,0,0);

    Rww = pair_frac_response( ...
        w0,w0,beta_grid_width,max_lag,cfg);

    Pweak = sum(abs(Rww).^2,2);

    Wbeta = estimate_3db_width( ...
        beta_grid_width,Pweak,beta_w);

    if ~isfinite(Wbeta) || Wbeta<=0
        error('Could not estimate Wbeta for %s.',mode);
    end

    width_rows(end+1,:) = { ... %#ok<AGROW>
        char(mode),N,T_target,T_actual,max_lag,Wbeta};

    width_store.(char(mode)) = struct( ...
        'N',N,'T_actual',T_actual, ...
        'max_lag',max_lag,'Wbeta',Wbeta);
end

width_table = cell2table(width_rows, ...
    'VariableNames',{ ...
    'aperture_mode','azimuth_samples', ...
    'target_aperture_time_s','actual_observation_time_s', ...
    'max_frac_lag','weak_single_3db_width_beta_rad'});

writetable(width_table, ...
    fullfile(out_path,'pa5d_intrinsic_width_calibration.csv'));

%% Construct window specifications
window_table = build_window_table( ...
    cfg,aperture_names,N_list,N_paper);

writetable(window_table, ...
    fullfile(out_path,'pa5d_window_specifications.csv'));

%% Main robustness sweep
rows = {};
sides = ["LowV","HighV"];

for ia = 1:2

    mode = aperture_names(ia);
    N = width_store.(char(mode)).N;
    max_lag = width_store.(char(mode)).max_lag;
    Wbeta = width_store.(char(mode)).Wbeta;

    Wspec = window_table( ...
        string(window_table.aperture_mode)==mode,:);

    for io = 1:numel(cfg.fractional_bin_offsets)

        eta = cfg.fractional_bin_offsets(io);
        b_common = eta/N;

        w0 = synth_discrete_lfm( ...
            N,1,aw,b_common,0);

        for idv = 1:numel(cfg.delta_velocity_mps)

            dv = cfg.delta_velocity_mps(idv);

            for iside = 1:2

                side = sides(iside);

                if side=="LowV"
                    vs = vw-dv;
                else
                    vs = vw+dv;
                end

                [~,~,Ks] = residual_fm_rates( ...
                    vs,R0,lambda,cfg);

                as = Ks/(cfg.prf_hz^2);
                beta_s = atan(as);

                beta_sep = abs(beta_s-beta_w);
                Gamma = beta_sep/Wbeta;
                regime = gamma_regime(Gamma,cfg);

                beta_grid = build_scenario_beta_grid( ...
                    beta_w,beta_s,Wbeta,cfg);

                s0 = synth_discrete_lfm( ...
                    N,cfg.A_strong,as,b_common,0);

                %% FrAc basis for strong-order estimation
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

                        [pre_found,~,~] = associate_peak( ...
                            peaks,beta_w,beta_sep,Wbeta,cfg);

                        pre_hidden = ~pre_found;

                        %% Practical strong beta
                        [~,idx_hat] = max(P1);
                        beta_hat = beta_grid(idx_hat);
                        a_hat = tan(beta_hat);

                        beta_error_over_width = ...
                            (beta_hat-beta_s)/Wbeta;

                        %% Sweep both window families/specifications
                        for iw = 1:height(Wspec)

                            family = string(Wspec.window_family(iw));
                            widx = Wspec.window_index(iw);
                            Lwin = Wspec.actual_window_bins(iw);
                            norm_bw = Wspec.actual_window_fraction_N(iw);
                            phys_bw_hz = Wspec.actual_window_bandwidth_hz(iw);

                            [r_wp,~,info] = ...
                                wang_style_filter_remove( ...
                                    x,a_hat,Lwin,cfg);

                            err_ratio = ...
                                norm(r_wp-w_true) / ...
                                max(norm(w_true),cfg.small_norm_floor);

                            [weak_ok,weak_peak_ratio] = ...
                                weak_stage_readiness( ...
                                    r_wp,aw,b_common,cfg);

                            %% Exact fixed-mask ownership
                            [sr,wr] = apply_fixed_mask_components( ...
                                s0,w_true,a_hat,info.mask);

                            Ls = ...
                                norm(sr) / ...
                                max(norm(s0),cfg.small_norm_floor);

                            Dw = ...
                                norm(wr) / ...
                                max(norm(w_true),cfg.small_norm_floor);

                            Epred = sqrt( ...
                                (Ls/rA)^2 + Dw^2);

                            identity_abs_error = ...
                                abs(Epred-err_ratio);

                            denom = (Ls/rA)^2+Dw^2;

                            if denom>0
                                leak_fraction = ...
                                    (Ls/rA)^2/denom;
                            else
                                leak_fraction = 0;
                            end

                            rows(end+1,:) = { ... %#ok<AGROW>
                                char(mode),N, ...
                                eta,b_common, ...
                                dv,char(side),vs, ...
                                Gamma,char(regime), ...
                                rA,phi,double(pre_hidden), ...
                                beta_s,beta_hat, ...
                                beta_error_over_width, ...
                                char(family),widx,Lwin, ...
                                norm_bw,phys_bw_hz, ...
                                double(weak_ok), ...
                                weak_peak_ratio, ...
                                err_ratio, ...
                                Ls,Dw,leak_fraction, ...
                                Epred,identity_abs_error, ...
                                info.num_detected_peaks, ...
                                info.mask_fraction};
                        end
                    end
                end
            end
        end
    end
end

trial_table = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','azimuth_samples', ...
    'fractional_bin_offset','center_frequency_cycles_per_sample', ...
    'delta_velocity_mps','strong_velocity_side', ...
    'strong_velocity_mps', ...
    'Gamma_sep_over_width','Gamma_regime', ...
    'weak_to_strong_ratio','relative_phase_rad', ...
    'pre_hidden', ...
    'beta_strong_true_rad','beta_strong_hat_rad', ...
    'strong_est_error_over_width', ...
    'window_family','window_index','actual_window_bins', ...
    'actual_window_fraction_N','actual_window_bandwidth_hz', ...
    'weak_stage_success','weak_stage_peak_ratio', ...
    'practical_error_ratio', ...
    'strong_leak_ratio','weak_projection_loss_ratio', ...
    'strong_leak_error_fraction', ...
    'predicted_error_ratio','identity_abs_error', ...
    'num_detected_peaks','mask_fraction'});

writetable(trial_table, ...
    fullfile(out_path,'pa5d_trial_results.csv'));

%% Identity
identity_summary = summarize_identity( ...
    trial_table,cfg);

writetable(identity_summary, ...
    fullfile(out_path,'pa5d_projection_identity_summary.csv'));

%% Robustness summaries
window_offset_summary = summarize_window_offset( ...
    trial_table);

balanced_summary = choose_balanced_windows( ...
    window_offset_summary,cfg);

family_comparison = summarize_family_comparison( ...
    balanced_summary);

writetable(window_offset_summary, ...
    fullfile(out_path,'pa5d_window_offset_summary.csv'));

writetable(balanced_summary, ...
    fullfile(out_path,'pa5d_balanced_window_by_offset.csv'));

writetable(family_comparison, ...
    fullfile(out_path,'pa5d_window_family_comparison.csv'));

%% Adaptive tolerance
[tolerance_trials,tolerance_summary] = ...
    adaptive_tolerance_stage( ...
        cfg,width_store,window_table, ...
        lambda,R0,beta_w,aw);

writetable(tolerance_trials, ...
    fullfile(out_path,'pa5d_tolerance_trials.csv'));

writetable(tolerance_summary, ...
    fullfile(out_path,'pa5d_tolerance_summary.csv'));

%% Scaling fits
scaling_summary = fit_tolerance_scaling( ...
    tolerance_summary,cfg);

writetable(scaling_summary, ...
    fullfile(out_path,'pa5d_tolerance_scaling_summary.csv'));

%% Decision
decision_summary = build_decision_summary( ...
    identity_summary,family_comparison, ...
    balanced_summary,scaling_summary,cfg);

writetable(decision_summary, ...
    fullfile(out_path,'pa5d_decision_summary.csv'));

%% Text summary
write_summary( ...
    out_path,cfg,lambda,R0,width_table, ...
    window_table,identity_summary, ...
    family_comparison,balanced_summary, ...
    tolerance_summary,scaling_summary, ...
    decision_summary);

%% Figures
make_figures( ...
    out_path,cfg,trial_table, ...
    window_offset_summary,balanced_summary, ...
    family_comparison,tolerance_summary, ...
    scaling_summary);

%% Save
results = struct();
results.cfg = cfg;
results.lambda = lambda;
results.R0 = R0;
results.width_table = width_table;
results.window_table = window_table;
results.trial_table = trial_table;
results.identity_summary = identity_summary;
results.window_offset_summary = window_offset_summary;
results.balanced_summary = balanced_summary;
results.family_comparison = family_comparison;
results.tolerance_trials = tolerance_trials;
results.tolerance_summary = tolerance_summary;
results.scaling_summary = scaling_summary;
results.decision_summary = decision_summary;

save(fullfile(out_path,'exp09_pa5d_results.mat'), ...
    'results','-v7.3');

fprintf('\n============================================================\n');
fprintf(' EXP009 PA5D / Window Normalization + Fence Effect\n');
fprintf('============================================================\n');
disp(identity_summary);
disp(family_comparison);
disp(balanced_summary);
disp(scaling_summary);
disp(decision_summary);
fprintf('============================================================\n');
fprintf('Saved to:\n%s\n\n',out_path);

end

%% ========================================================================
function W = build_window_table( ...
    cfg,modes,Nlist,Npaper)

ref_frac = cfg.fixed_window_bins/Npaper;

rows = {};

for ia = 1:numel(modes)

    mode = modes(ia);
    N = Nlist(ia);

    for j = 1:numel(cfg.fixed_window_bins)

        % Family A: fixed bins
        L = cfg.fixed_window_bins(j);

        rows(end+1,:) = { ... %#ok<AGROW>
            char(mode),'FixedBins',j, ...
            L,L/N,L*cfg.prf_hz/N, ...
            L/N};

        % Family B: bandwidth matched to Paper1s target fraction
        target_frac = ref_frac(j);
        Lb = nearest_positive_odd( ...
            target_frac*N);

        rows(end+1,:) = { ... %#ok<AGROW>
            char(mode),'BandwidthMatched',j, ...
            Lb,Lb/N,Lb*cfg.prf_hz/N, ...
            target_frac};
    end
end

W = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','window_family','window_index', ...
    'actual_window_bins','actual_window_fraction_N', ...
    'actual_window_bandwidth_hz', ...
    'target_window_fraction_N'});

end

%% ========================================================================
function L = nearest_positive_odd(x)

L = max(1,round(x));

if mod(L,2)==0
    low = max(1,L-1);
    high = L+1;

    if abs(low-x)<=abs(high-x)
        L = low;
    else
        L = high;
    end
end

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

nfft = max(2048, ...
    2^nextpow2(cfg.frac_fft_oversample*N));

f = (-nfft/2:nfft/2-1).'/nfft;
tb = tan(beta_grid(:));

R = complex(zeros(numel(beta_grid),max_lag));

for k = 1:max_lag

    z = ...
        x_left(1+k:end).* ...
        conj(x_right(1:end-k));

    Z = fftshift(fft(z,nfft));
    Z = Z(:);

    R(:,k) = interp1( ...
        f,Z,k*tb,'linear',0) / ...
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

lev = P(ip)/2;

il = ip;
while il>1 && P(il)>=lev
    il = il-1;
end

ir = ip;
while ir<numel(P) && P(ir)>=lev
    ir = ir+1;
end

if il==1 || ir==numel(P)
    W = NaN;
else
    W = beta_grid(ir)-beta_grid(il);
end

end

%% ========================================================================
function bg = build_scenario_beta_grid( ...
    bw,bs,W,cfg)

sep = abs(bs-bw);

step = min( ...
    cfg.beta_step_width_fraction*W, ...
    cfg.beta_step_separation_fraction*max(sep,eps));

step = max( ...
    step,cfg.beta_step_min_width_fraction*W);

lo = min(bw,bs)-cfg.beta_margin_widths*W;
hi = max(bw,bs)+cfg.beta_margin_widths*W;

bg = linspace( ...
    lo,hi,ceil((hi-lo)/step)+1).';

end

%% ========================================================================
function s = gamma_regime(G,cfg)

if G<cfg.gamma_unresolved_max
    s = "Unresolved";
elseif G<cfg.gamma_partial_max
    s = "Partial";
else
    s = "ResolvedCandidate";
end

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
function p = local_peaks_with_prominence( ...
    bg,P,pfrac)

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

    pr(j) = ...
        P(ii) - max( ...
        min(P(1:ii)), ...
        min(P(ii:end)));
end

rg = max(P)-min(P);

if rg>0
    keep = pr>=pfrac*rg;
else
    keep = true(size(pr));
end

idx = idx(keep);
pr = pr(keep);

if isempty(idx)
    [~,idx] = max(P);
    pr = max(P)-min(P);
end

p.beta = bg(idx);
p.prominence = pr(:);

end

%% ========================================================================
function [found,bp,prom] = ...
    associate_peak(p,btrue,sep,W,cfg)

rad = max( ...
    cfg.peak_association_fraction_of_separation*sep, ...
    cfg.peak_association_min_width_fraction*W);

d = abs(p.beta-btrue);
ii = find(d<=rad);

if isempty(ii)
    found = false;
    bp = NaN;
    prom = NaN;
    return;
end

[~,o] = sortrows([ ...
    d(ii),-p.prominence(ii)], ...
    [1 2]);

j = ii(o(1));

found = true;
bp = p.beta(j);
prom = p.prominence(j);

end

%% ========================================================================
function Y = matched_lfm_transform(x,a)

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

Yext = zeros(size(Y));
Yext(mask) = Y(mask);

extracted = ...
    inverse_matched_lfm_transform( ...
        Yext,a_hat);

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

if numel(amp)>=2

    if amp(1)>=amp(2)
        idx = [1 idx]; %#ok<AGROW>
    end

    if amp(end)>amp(end-1)
        idx = [idx numel(amp)]; %#ok<AGROW>
    end
end

idx = unique(idx);

keep = amp(idx)>=gate*mx;
pk = idx(keep);

if isempty(pk)
    [~,pk] = max(amp);
end

end

%% ========================================================================
function [sr,wr] = ...
    apply_fixed_mask_components(s,w,a_hat,mask)

Ys = matched_lfm_transform(s,a_hat);
Yw = matched_lfm_transform(w,a_hat);

Ysq = zeros(size(Ys));
Ysq(mask) = Ys(mask);

Ywq = zeros(size(Yw));
Ywq(mask) = Yw(mask);

Qs = inverse_matched_lfm_transform( ...
    Ysq,a_hat);

Qw = inverse_matched_lfm_transform( ...
    Ywq,a_hat);

sr = s-Qs;
wr = Qw;

end

%% ========================================================================
function [ok,ratio] = ...
    weak_stage_readiness(residual,aweak,bweak,cfg)

Y = matched_lfm_transform( ...
    residual,aweak);

amp = abs(Y);
N = numel(amp);

% Expected weak focused frequency is bweak.
% Convert normalized cycles/sample to fftshift index.
freq_bin = bweak*N;

dc = floor(N/2)+1;
idx_expected = round(dc+freq_bin);

idx_expected = min(max(idx_expected,1),N);

i1 = max(1, ...
    idx_expected-cfg.weak_stage_center_tolerance_bins);

i2 = min(N, ...
    idx_expected+cfg.weak_stage_center_tolerance_bins);

local_peak = max(amp(i1:i2));
global_peak = max(amp);

ratio = ...
    local_peak/max(global_peak,cfg.small_norm_floor);

ok = ratio>=cfg.weak_stage_peak_gate;

end

%% ========================================================================
function S = summarize_identity(T,cfg)

modes = unique(string(T.aperture_mode),'stable');
families = unique(string(T.window_family),'stable');

rows = {};

for i = 1:numel(modes)

    for j = 1:numel(families)

        M = T( ...
            string(T.aperture_mode)==modes(i) & ...
            string(T.window_family)==families(j),:);

        e = M.identity_abs_error;
        e = e(isfinite(e));

        rows(end+1,:) = { ... %#ok<AGROW>
            char(modes(i)),char(families(j)), ...
            height(M),median(e),max(e), ...
            double(max(e)<= ...
            cfg.identity_max_abs_error_gate)};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','window_family','n', ...
    'median_identity_abs_error', ...
    'max_identity_abs_error', ...
    'identity_gate_pass'});

end

%% ========================================================================
function S = summarize_window_offset(T)

modes = unique(string(T.aperture_mode),'stable');
families = unique(string(T.window_family),'stable');
offsets = unique(T.fractional_bin_offset).';
widxs = unique(T.window_index).';

rows = {};

for im = 1:numel(modes)

    for jf = 1:numel(families)

        for io = 1:numel(offsets)

            for iw = 1:numel(widxs)

                M = T( ...
                    string(T.aperture_mode)==modes(im) & ...
                    string(T.window_family)==families(jf) & ...
                    abs(T.fractional_bin_offset-offsets(io))<1e-12 & ...
                    T.window_index==widxs(iw),:);

                H = M(logical(M.pre_hidden),:);

                if isempty(H)
                    continue;
                end

                rows(end+1,:) = { ... %#ok<AGROW>
                    char(modes(im)),char(families(jf)), ...
                    offsets(io),widxs(iw), ...
                    median(H.actual_window_bins), ...
                    median(H.actual_window_fraction_N), ...
                    median(H.actual_window_bandwidth_hz), ...
                    height(H), ...
                    mean(H.weak_stage_success), ...
                    median(H.practical_error_ratio,'omitnan'), ...
                    median(H.strong_leak_ratio,'omitnan'), ...
                    median(H.weak_projection_loss_ratio,'omitnan'), ...
                    median(H.strong_leak_error_fraction,'omitnan'), ...
                    median(abs(H.strong_est_error_over_width),'omitnan')};
            end
        end
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','window_family', ...
    'fractional_bin_offset','window_index', ...
    'actual_window_bins','actual_window_fraction_N', ...
    'actual_window_bandwidth_hz','n_hidden', ...
    'weak_stage_success_rate', ...
    'median_practical_error_ratio', ...
    'median_strong_leak_ratio', ...
    'median_weak_projection_loss_ratio', ...
    'median_strong_leak_error_fraction', ...
    'median_abs_strong_est_error_over_width'});

end

%% ========================================================================
function B = choose_balanced_windows(S,cfg)

modes = unique(string(S.aperture_mode),'stable');
families = unique(string(S.window_family),'stable');
offsets = unique(S.fractional_bin_offset).';

rows = {};

for im = 1:numel(modes)

    for jf = 1:numel(families)

        for io = 1:numel(offsets)

            M = S( ...
                string(S.aperture_mode)==modes(im) & ...
                string(S.window_family)==families(jf) & ...
                abs(S.fractional_bin_offset-offsets(io))<1e-12,:);

            if isempty(M)
                continue;
            end

            maxsucc = max(M.weak_stage_success_rate);

            eligible = ...
                M.weak_stage_success_rate >= ...
                cfg.balanced_success_fraction*maxsucc;

            idx = find(eligible);

            [~,jj] = min( ...
                M.median_practical_error_ratio(idx));

            ib = idx(jj);

            rows(end+1,:) = { ... %#ok<AGROW>
                char(modes(im)),char(families(jf)), ...
                offsets(io), ...
                M.window_index(ib), ...
                M.actual_window_bins(ib), ...
                M.actual_window_fraction_N(ib), ...
                M.actual_window_bandwidth_hz(ib), ...
                M.weak_stage_success_rate(ib), ...
                M.median_practical_error_ratio(ib), ...
                M.median_strong_leak_ratio(ib), ...
                M.median_weak_projection_loss_ratio(ib)};
        end
    end
end

B = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','window_family', ...
    'fractional_bin_offset', ...
    'balanced_window_index', ...
    'balanced_window_bins', ...
    'balanced_window_fraction_N', ...
    'balanced_window_bandwidth_hz', ...
    'balanced_success_rate', ...
    'balanced_median_error_ratio', ...
    'balanced_strong_leak_ratio', ...
    'balanced_weak_projection_loss_ratio'});

end

%% ========================================================================
function F = summarize_family_comparison(B)

modes = unique(string(B.aperture_mode),'stable');
families = unique(string(B.window_family),'stable');

rows = {};

for im = 1:numel(modes)

    for jf = 1:numel(families)

        M = B( ...
            string(B.aperture_mode)==modes(im) & ...
            string(B.window_family)==families(jf),:);

        rows(end+1,:) = { ... %#ok<AGROW>
            char(modes(im)),char(families(jf)), ...
            median(M.balanced_window_bins,'omitnan'), ...
            median(M.balanced_window_fraction_N,'omitnan'), ...
            median(M.balanced_window_bandwidth_hz,'omitnan'), ...
            median(M.balanced_success_rate,'omitnan'), ...
            median(M.balanced_median_error_ratio,'omitnan'), ...
            max(M.balanced_median_error_ratio)- ...
                min(M.balanced_median_error_ratio)};
    end
end

F = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','window_family', ...
    'median_balanced_window_bins', ...
    'median_balanced_window_fraction_N', ...
    'median_balanced_window_bandwidth_hz', ...
    'median_balanced_success_rate', ...
    'median_balanced_error_ratio', ...
    'balanced_error_span_across_offsets'});

end

%% ========================================================================
function [T,S] = adaptive_tolerance_stage( ...
    cfg,width_store,window_table, ...
    lambda,R0,beta_w,aw)

modes = ["Paper1s","BeamDerived"];
families = ["FixedBins","BandwidthMatched"];

dv = cfg.tolerance_delta_velocity_mps;

rows = {};
sumrows = {};

for im = 1:numel(modes)

    mode = modes(im);
    N = width_store.(char(mode)).N;
    Wbeta = width_store.(char(mode)).Wbeta;

    if strcmpi(cfg.tolerance_side,'HighV')
        vs = cfg.weak_velocity_mps+dv;
    else
        vs = cfg.weak_velocity_mps-dv;
    end

    [~,~,Ks] = residual_fm_rates( ...
        vs,R0,lambda,cfg);

    as = Ks/(cfg.prf_hz^2);
    beta_s = atan(as);

    Wspec = window_table( ...
        string(window_table.aperture_mode)==mode,:);

    for jf = 1:numel(families)

        fam = families(jf);

        WF = Wspec( ...
            string(Wspec.window_family)==fam,:);

        for iw = 1:height(WF)

            widx = WF.window_index(iw);
            Lwin = WF.actual_window_bins(iw);
            normbw = WF.actual_window_fraction_N(iw);
            physbw = WF.actual_window_bandwidth_hz(iw);

            for io = 1:numel(cfg.tolerance_fractional_bin_offsets)

                eta = cfg.tolerance_fractional_bin_offsets(io);
                b = eta/N;

                s0 = synth_discrete_lfm( ...
                    N,1,as,b,0);

                w0 = synth_discrete_lfm( ...
                    N,1,aw,b,0);

                for ir = 1:numel(cfg.weak_to_strong_ratio)

                    rA = cfg.weak_to_strong_ratio(ir);
                    w = rA*w0;

                    [dgrid,Egrid,Lgrid,Dgrid] = ...
                        adaptive_error_curve( ...
                            s0,w,as,beta_s,Wbeta, ...
                            Lwin,rA,cfg);

                    for k = 1:numel(dgrid)

                        rows(end+1,:) = { ... %#ok<AGROW>
                            char(mode),char(fam), ...
                            widx,Lwin,normbw,physbw, ...
                            eta,rA,dgrid(k), ...
                            Lgrid(k),Dgrid(k),Egrid(k)};
                    end

                    [negTol,posTol,symTol,E0, ...
                        negCensored,posCensored] = ...
                        connected_tolerance( ...
                            dgrid,Egrid, ...
                            cfg.tolerance_error_threshold, ...
                            cfg.tolerance_max_abs_delta_over_width);

                    asym = ...
                        abs(posTol-negTol) / ...
                        max(0.5*(posTol+negTol),eps);

                    sumrows(end+1,:) = { ... %#ok<AGROW>
                        char(mode),char(fam), ...
                        widx,Lwin,normbw,physbw, ...
                        eta,rA,E0, ...
                        negTol,posTol,symTol,asym, ...
                        double(negCensored), ...
                        double(posCensored)};
                end
            end
        end
    end
end

T = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','window_family', ...
    'window_index','actual_window_bins', ...
    'actual_window_fraction_N', ...
    'actual_window_bandwidth_hz', ...
    'fractional_bin_offset', ...
    'weak_to_strong_ratio', ...
    'delta_beta_over_width', ...
    'strong_leak_ratio', ...
    'weak_projection_loss_ratio', ...
    'predicted_error_ratio'});

S = cell2table(sumrows, ...
    'VariableNames',{ ...
    'aperture_mode','window_family', ...
    'window_index','actual_window_bins', ...
    'actual_window_fraction_N', ...
    'actual_window_bandwidth_hz', ...
    'fractional_bin_offset', ...
    'weak_to_strong_ratio', ...
    'zero_mismatch_error_ratio', ...
    'allowed_negative_abs_beta_error_over_width', ...
    'allowed_positive_beta_error_over_width', ...
    'allowed_symmetric_abs_beta_error_over_width', ...
    'tolerance_directional_asymmetry', ...
    'negative_side_censored_at_search_cap', ...
    'positive_side_censored_at_search_cap'});

end

%% ========================================================================
function [dgrid,Egrid,Lgrid,Dgrid] = ...
    adaptive_error_curve( ...
        s0,w,as,beta_s,Wbeta,Lwin,rA,cfg)

dmax = cfg.tolerance_initial_abs_delta_over_width;
cap = cfg.tolerance_max_abs_delta_over_width;
step = cfg.tolerance_grid_step_over_width;

while true

    dgrid = (-dmax:step:dmax).';

    if abs(dgrid(end)-dmax)>1e-12
        dgrid = unique([dgrid;dmax]);
    end

    Egrid = nan(size(dgrid));
    Lgrid = nan(size(dgrid));
    Dgrid = nan(size(dgrid));

    for k = 1:numel(dgrid)

        beta_hat = ...
            beta_s+dgrid(k)*Wbeta;

        a_hat = tan(beta_hat);

        % Strong-only mask: isolates mismatch/window tolerance from
        % data-dependent phase selection.
        Ys = matched_lfm_transform(s0,a_hat);

        pk = find_transform_peaks( ...
            abs(Ys),cfg.frac_domain_peak_gate);

        mask = false(size(Ys));
        half = floor((Lwin-1)/2);

        for j = 1:numel(pk)

            i1 = max(1,pk(j)-half);
            i2 = min(numel(mask),pk(j)+half);

            mask(i1:i2) = true;
        end

        [sr,wr] = apply_fixed_mask_components( ...
            s0,w,a_hat,mask);

        Ls = norm(sr)/norm(s0);

        Dw = ...
            norm(wr)/ ...
            max(norm(w),cfg.small_norm_floor);

        E = sqrt((Ls/rA)^2+Dw^2);

        Lgrid(k) = Ls;
        Dgrid(k) = Dw;
        Egrid(k) = E;
    end

    [~,i0] = min(abs(dgrid));

    left_edge_safe = ...
        any(Egrid(1:i0)<= ...
        cfg.tolerance_error_threshold);

    right_edge_safe = ...
        any(Egrid(i0:end)<= ...
        cfg.tolerance_error_threshold);

    % We specifically need the connected safe component containing zero.
    % Expansion is required only if the connected component reaches an edge.
    reaches_left = connected_reaches_edge( ...
        Egrid,i0,-1,cfg.tolerance_error_threshold);

    reaches_right = connected_reaches_edge( ...
        Egrid,i0,+1,cfg.tolerance_error_threshold);

    if ~(reaches_left || reaches_right)
        break;
    end

    if dmax>=cap-1e-12
        break;
    end

    dmax = min(2*dmax,cap);
end

end

%% ========================================================================
function tf = connected_reaches_edge(E,i0,dir,thr)

if E(i0)>thr
    tf = false;
    return;
end

if dir<0

    i = i0;

    while i>1 && E(i-1)<=thr
        i = i-1;
    end

    tf = (i==1);

else

    i = i0;

    while i<numel(E) && E(i+1)<=thr
        i = i+1;
    end

    tf = (i==numel(E));
end

end

%% ========================================================================
function [negTol,posTol,symTol,E0, ...
    negCensored,posCensored] = ...
    connected_tolerance(d,E,thr,cap)

[d,ord] = sort(d(:));
E = E(ord);

[~,i0] = min(abs(d));
E0 = E(i0);

if E0>thr
    negTol = 0;
    posTol = 0;
    symTol = 0;
    negCensored = false;
    posCensored = false;
    return;
end

%% Negative side
i = i0;

while i>1 && E(i-1)<=thr
    i = i-1;
end

if i==1 && E(i)<=thr

    negTol = abs(d(i));
    negCensored = abs(d(i))>=cap-1e-9;

else

    % Crossing lies between i-1 (unsafe) and i (safe).
    d1 = d(i-1); e1 = E(i-1);
    d2 = d(i);   e2 = E(i);

    dcross = linear_crossing( ...
        d1,e1,d2,e2,thr);

    negTol = abs(dcross);
    negCensored = false;
end

%% Positive side
i = i0;

while i<numel(E) && E(i+1)<=thr
    i = i+1;
end

if i==numel(E) && E(i)<=thr

    posTol = abs(d(i));
    posCensored = abs(d(i))>=cap-1e-9;

else

    % Crossing lies between i (safe) and i+1 (unsafe).
    d1 = d(i);   e1 = E(i);
    d2 = d(i+1); e2 = E(i+1);

    dcross = linear_crossing( ...
        d1,e1,d2,e2,thr);

    posTol = abs(dcross);
    posCensored = false;
end

symTol = min(negTol,posTol);

end

%% ========================================================================
function dcross = linear_crossing(d1,e1,d2,e2,thr)

if abs(e2-e1)<eps
    dcross = 0.5*(d1+d2);
else
    t = (thr-e1)/(e2-e1);
    t = min(max(t,0),1);
    dcross = d1+t*(d2-d1);
end

end

%% ========================================================================
function S = fit_tolerance_scaling(T,cfg)

modes = unique(string(T.aperture_mode),'stable');
families = unique(string(T.window_family),'stable');
offsets = unique(T.fractional_bin_offset).';
widxs = unique(T.window_index).';

rows = {};

for im = 1:numel(modes)

    for jf = 1:numel(families)

        for io = 1:numel(offsets)

            for iw = 1:numel(widxs)

                M = T( ...
                    string(T.aperture_mode)==modes(im) & ...
                    string(T.window_family)==families(jf) & ...
                    abs(T.fractional_bin_offset-offsets(io))<1e-12 & ...
                    T.window_index==widxs(iw),:);

                if isempty(M)
                    continue;
                end

                % Exclude censored points from slope/R2 fit.
                valid = ...
                    M.negative_side_censored_at_search_cap==0 & ...
                    M.positive_side_censored_at_search_cap==0 & ...
                    isfinite(M.allowed_symmetric_abs_beta_error_over_width);

                x = M.weak_to_strong_ratio(valid);
                y = M.allowed_symmetric_abs_beta_error_over_width(valid);

                if numel(x)>=2

                    if cfg.fit_tolerance_through_origin
                        alpha = (x'*y)/(x'*x);
                        yhat = alpha*x;
                        intercept = 0;
                    else
                        p = polyfit(x,y,1);
                        alpha = p(1);
                        intercept = p(2);
                        yhat = polyval(p,x);
                    end

                    sse = sum((y-yhat).^2);
                    sst = sum((y-mean(y)).^2);

                    if sst>0
                        R2 = 1-sse/sst;
                    else
                        R2 = NaN;
                    end

                else
                    alpha = NaN;
                    intercept = NaN;
                    R2 = NaN;
                end

                rows(end+1,:) = { ... %#ok<AGROW>
                    char(modes(im)),char(families(jf)), ...
                    offsets(io),widxs(iw), ...
                    median(M.actual_window_bins), ...
                    median(M.actual_window_fraction_N), ...
                    numel(x),alpha,intercept,R2, ...
                    median(M.tolerance_directional_asymmetry,'omitnan'), ...
                    sum(M.negative_side_censored_at_search_cap | ...
                        M.positive_side_censored_at_search_cap)};
            end
        end
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','window_family', ...
    'fractional_bin_offset','window_index', ...
    'actual_window_bins','actual_window_fraction_N', ...
    'n_uncensored_fit_points', ...
    'tolerance_scaling_slope_alpha', ...
    'tolerance_scaling_intercept', ...
    'tolerance_scaling_R2', ...
    'median_tolerance_directional_asymmetry', ...
    'n_censored_points'});

end

%% ========================================================================
function D = build_decision_summary( ...
    I,F,B,S,cfg)

modes = unique(string(I.aperture_mode),'stable');
rows = {};

for im = 1:numel(modes)

    mode = modes(im);

    Ii = I(string(I.aperture_mode)==mode,:);

    identity_pass = all(Ii.identity_gate_pass==1);

    Fi = F(string(F.aperture_mode)==mode,:);

    fixed = Fi(string(Fi.window_family)=="FixedBins",:);
    matched = Fi(string(Fi.window_family)=="BandwidthMatched",:);

    if isempty(fixed) || isempty(matched)
        family_error_delta = NaN;
    else
        family_error_delta = ...
            matched.median_balanced_error_ratio - ...
            fixed.median_balanced_error_ratio;
    end

    Bi = B( ...
        string(B.aperture_mode)==mode & ...
        string(B.window_family)=="BandwidthMatched",:);

    fence_error_span = ...
        max(Bi.balanced_median_error_ratio) - ...
        min(Bi.balanced_median_error_ratio);

    Si = S( ...
        string(S.aperture_mode)==mode & ...
        string(S.window_family)=="BandwidthMatched",:);

    good_scaling = ...
        Si.tolerance_scaling_R2>=0.90 & ...
        Si.n_uncensored_fit_points>=3;

    scaling_fraction = mean(good_scaling,'omitnan');

    asym = median( ...
        Si.median_tolerance_directional_asymmetry, ...
        'omitnan');

    if ~identity_pass
        branch = "IDENTITY_IMPLEMENTATION_REVIEW";
    elseif scaling_fraction>=0.70 && ...
            fence_error_span<0.20
        branch = ...
            "MECHANISM_ROBUST_TO_WINDOW_NORMALIZATION_AND_FENCE_EFFECT";
    elseif scaling_fraction>=0.50
        branch = ...
            "CORE_TOLERANCE_SCALING_SURVIVES_WITH_FENCE_SENSITIVITY";
    else
        branch = ...
            "FENCE_OR_WINDOW_NORMALIZATION_CHANGES_TOLERANCE_LAW";
    end

    rows(end+1,:) = { ... %#ok<AGROW>
        char(mode),double(identity_pass), ...
        family_error_delta, ...
        fence_error_span, ...
        scaling_fraction, ...
        asym,char(branch)};
end

D = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode', ...
    'projection_identity_all_pass', ...
    'bandwidthMatched_minus_fixed_median_balanced_error', ...
    'bandwidthMatched_balanced_error_span_across_offsets', ...
    'fraction_scaling_fits_with_R2_ge_0p90', ...
    'median_tolerance_directional_asymmetry', ...
    'decision_branch'});

end

%% ========================================================================
function write_summary( ...
    out_path,cfg,lambda,R0,W,Win,I,F,B,Tol,S,D)

fid = fopen(fullfile(out_path,'summary.txt'),'w');

fprintf(fid,'EXP009 PA5D / Window Normalization + Fence Effect\n');
fprintf(fid,'================================================\n\n');

fprintf(fid,'Research questions\n');
fprintf(fid,'------------------\n');
fprintf(fid,['1) Does fixed-bin comparison bias aperture comparison?\n' ...
    '2) Does off-grid focusing change the leakage/loss tradeoff?\n' ...
    '3) Does contrast-scaled beta tolerance survive?\n' ...
    '4) Does off-grid focusing introduce directional mismatch asymmetry?\n\n']);

fprintf(fid,'Physical setup\n');
fprintf(fid,'--------------\n');
fprintf(fid,'fc=%g Hz, PRF=%g Hz, lambda=%g m, R0=%g m\n', ...
    cfg.fc_hz,cfg.prf_hz,lambda,R0);
fprintf(fid,'weak velocity=%g m/s\n',cfg.weak_velocity_mps);
fprintf(fid,'Delta-v=%s m/s\n',mat2str(cfg.delta_velocity_mps));
fprintf(fid,'Aw/As=%s\n',mat2str(cfg.weak_to_strong_ratio));
fprintf(fid,'fence offsets=%s bins\n\n', ...
    mat2str(cfg.fractional_bin_offsets));

fprintf(fid,'Intrinsic widths\n');
fprintf(fid,'----------------\n');
for i=1:height(W)
    fprintf(fid,'%s N=%d T=%g Wbeta=%g\n', ...
        W.aperture_mode{i},W.azimuth_samples(i), ...
        W.actual_observation_time_s(i), ...
        W.weak_single_3db_width_beta_rad(i));
end

fprintf(fid,'\nWindow specifications\n');
fprintf(fid,'---------------------\n');
for i=1:height(Win)
    fprintf(fid,'%s %s idx=%d L=%d L/N=%g BW=%g Hz targetL/N=%g\n', ...
        Win.aperture_mode{i},Win.window_family{i}, ...
        Win.window_index(i),Win.actual_window_bins(i), ...
        Win.actual_window_fraction_N(i), ...
        Win.actual_window_bandwidth_hz(i), ...
        Win.target_window_fraction_N(i));
end

fprintf(fid,'\nProjection identity\n');
fprintf(fid,'-------------------\n');
for i=1:height(I)
    fprintf(fid,'%s %s maxErr=%g pass=%d\n', ...
        I.aperture_mode{i},I.window_family{i}, ...
        I.max_identity_abs_error(i), ...
        I.identity_gate_pass(i));
end

fprintf(fid,'\nFamily comparison\n');
fprintf(fid,'-----------------\n');
for i=1:height(F)
    fprintf(fid,[ ...
        '%s %s medBalancedL=%g medL/N=%g medBW=%gHz ' ...
        'success=%g error=%g offsetSpan=%g\n'], ...
        F.aperture_mode{i},F.window_family{i}, ...
        F.median_balanced_window_bins(i), ...
        F.median_balanced_window_fraction_N(i), ...
        F.median_balanced_window_bandwidth_hz(i), ...
        F.median_balanced_success_rate(i), ...
        F.median_balanced_error_ratio(i), ...
        F.balanced_error_span_across_offsets(i));
end

fprintf(fid,'\nBalanced window by fence offset\n');
fprintf(fid,'-------------------------------\n');
for i=1:height(B)
    fprintf(fid,[ ...
        '%s %s eta=%g idx=%d L=%d L/N=%g BW=%gHz ' ...
        'success=%g error=%g leak=%g weakLoss=%g\n'], ...
        B.aperture_mode{i},B.window_family{i}, ...
        B.fractional_bin_offset(i), ...
        B.balanced_window_index(i), ...
        B.balanced_window_bins(i), ...
        B.balanced_window_fraction_N(i), ...
        B.balanced_window_bandwidth_hz(i), ...
        B.balanced_success_rate(i), ...
        B.balanced_median_error_ratio(i), ...
        B.balanced_strong_leak_ratio(i), ...
        B.balanced_weak_projection_loss_ratio(i));
end

fprintf(fid,'\nAdaptive tolerance summary\n');
fprintf(fid,'--------------------------\n');
for i=1:height(Tol)
    fprintf(fid,[ ...
        '%s %s eta=%g idx=%d L=%d r=%g E0=%g ' ...
        'tolNeg=%g tolPos=%g tolSym=%g asym=%g censored=%d/%d\n'], ...
        Tol.aperture_mode{i},Tol.window_family{i}, ...
        Tol.fractional_bin_offset(i), ...
        Tol.window_index(i),Tol.actual_window_bins(i), ...
        Tol.weak_to_strong_ratio(i), ...
        Tol.zero_mismatch_error_ratio(i), ...
        Tol.allowed_negative_abs_beta_error_over_width(i), ...
        Tol.allowed_positive_beta_error_over_width(i), ...
        Tol.allowed_symmetric_abs_beta_error_over_width(i), ...
        Tol.tolerance_directional_asymmetry(i), ...
        Tol.negative_side_censored_at_search_cap(i), ...
        Tol.positive_side_censored_at_search_cap(i));
end

fprintf(fid,'\nTolerance scaling fits\n');
fprintf(fid,'----------------------\n');
for i=1:height(S)
    fprintf(fid,[ ...
        '%s %s eta=%g idx=%d L=%d alpha=%g R2=%g ' ...
        'medianAsym=%g censored=%d\n'], ...
        S.aperture_mode{i},S.window_family{i}, ...
        S.fractional_bin_offset(i), ...
        S.window_index(i), ...
        S.actual_window_bins(i), ...
        S.tolerance_scaling_slope_alpha(i), ...
        S.tolerance_scaling_R2(i), ...
        S.median_tolerance_directional_asymmetry(i), ...
        S.n_censored_points(i));
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
fprintf(fid,['1) Same bin count across different N is NOT automatically a fair ' ...
    'physical-bandwidth comparison; BandwidthMatched is the fairer bridge.\n']);
fprintf(fid,['2) l=3 from PA5C is not treated as a universal optimum.\n']);
fprintf(fid,['3) eta=0.5 tests the strongest standard FFT fence-effect position.\n']);
fprintf(fid,['4) Tolerance search is adaptive; values at the search cap are marked ' ...
    'censored rather than falsely reported as exact thresholds.\n']);
fprintf(fid,['5) Scaling slope alpha is an experiment-specific descriptor, not a ' ...
    'universal constant.\n']);
fprintf(fid,['6) Noise remains OFF until window normalization and fence robustness ' ...
    'are closed.\n']);

fclose(fid);

end

%% ========================================================================
function make_figures( ...
    out_path,cfg,T,S,B,F,Tol,Scale)

modes = ["Paper1s","BeamDerived"];

%% Fig 1 — balanced error vs fence offset, matched family
fig = figure('Visible',cfg.figure_visible);
hold on;

for im=1:numel(modes)

    M = B( ...
        string(B.aperture_mode)==modes(im) & ...
        string(B.window_family)=="BandwidthMatched",:);

    plot(M.fractional_bin_offset, ...
        M.balanced_median_error_ratio, ...
        'o-','LineWidth',1.3);
end

xlabel('Focused fractional-bin offset |\eta|');
ylabel('Balanced median ||r-w||/||w||');
title('EXP009 PA5D — Fence-Effect Robustness of Balanced Removal');
legend(modes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig01_balanced_error_vs_fence_offset.png'), ...
    'Resolution',180);
close(fig);

%% Fig 2 — balanced success vs fence offset
fig = figure('Visible',cfg.figure_visible);
hold on;

for im=1:numel(modes)

    M = B( ...
        string(B.aperture_mode)==modes(im) & ...
        string(B.window_family)=="BandwidthMatched",:);

    plot(M.fractional_bin_offset, ...
        M.balanced_success_rate, ...
        'o-','LineWidth',1.3);
end

xlabel('Focused fractional-bin offset |\eta|');
ylabel('Balanced weak-stage success rate');
title('EXP009 PA5D — Weak Recovery vs Fence Effect');
legend(modes,'Location','best');
ylim([0 1]);
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig02_balanced_success_vs_fence_offset.png'), ...
    'Resolution',180);
close(fig);

%% Fig 3 — matched-family leakage/loss versus physical BW at eta=0.5
fig = figure('Visible',cfg.figure_visible);
hold on;

eta = 0.5;

for im=1:numel(modes)

    M = S( ...
        string(S.aperture_mode)==modes(im) & ...
        string(S.window_family)=="BandwidthMatched" & ...
        abs(S.fractional_bin_offset-eta)<1e-12,:);

    [~,o] = sort(M.actual_window_bandwidth_hz);
    M = M(o,:);

    plot(M.actual_window_bandwidth_hz, ...
        M.median_strong_leak_ratio, ...
        'o-','LineWidth',1.2);

    plot(M.actual_window_bandwidth_hz, ...
        M.median_weak_projection_loss_ratio, ...
        's--','LineWidth',1.2);
end

xlabel('Transform-domain window bandwidth (Hz)');
ylabel('Median normalized component error');
title('EXP009 PA5D — Leakage/Loss Tradeoff at Half-Bin Offset');
legend({'Paper strong leak','Paper weak loss', ...
        'Beam strong leak','Beam weak loss'}, ...
       'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig03_halfbin_leakage_loss_vs_bandwidth.png'), ...
    'Resolution',180);
close(fig);

%% Fig 4 — fixed bins vs bandwidth matched, Beam
fig = figure('Visible',cfg.figure_visible);
hold on;

for fam = ["FixedBins","BandwidthMatched"]

    M = B( ...
        string(B.aperture_mode)=="BeamDerived" & ...
        string(B.window_family)==fam,:);

    plot(M.fractional_bin_offset, ...
        M.balanced_median_error_ratio, ...
        'o-','LineWidth',1.3);
end

xlabel('Focused fractional-bin offset |\eta|');
ylabel('Balanced median error');
title('EXP009 PA5D — Fixed-Bin vs Equal-Bandwidth Comparison');
legend({'Fixed bins','Bandwidth matched'},'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig04_fixed_vs_bandwidth_matched.png'), ...
    'Resolution',180);
close(fig);

%% Fig 5 — balanced window bandwidth vs offset
fig = figure('Visible',cfg.figure_visible);
hold on;

for im=1:numel(modes)

    M = B( ...
        string(B.aperture_mode)==modes(im) & ...
        string(B.window_family)=="BandwidthMatched",:);

    plot(M.fractional_bin_offset, ...
        M.balanced_window_bandwidth_hz, ...
        'o-','LineWidth',1.3);
end

xlabel('Focused fractional-bin offset |\eta|');
ylabel('Selected balanced bandwidth (Hz)');
title('EXP009 PA5D — Balanced Removal Bandwidth vs Fence Effect');
legend(modes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig05_balanced_bandwidth_vs_fence_offset.png'), ...
    'Resolution',180);
close(fig);

%% Fig 6 — tolerance vs contrast at matched family, index 2
fig = figure('Visible',cfg.figure_visible);
hold on;

for eta = cfg.tolerance_fractional_bin_offsets

    M = Tol( ...
        string(Tol.aperture_mode)=="BeamDerived" & ...
        string(Tol.window_family)=="BandwidthMatched" & ...
        Tol.window_index==2 & ...
        abs(Tol.fractional_bin_offset-eta)<1e-12,:);

    [~,o] = sort(M.weak_to_strong_ratio);
    M = M(o,:);

    plot(M.weak_to_strong_ratio, ...
        M.allowed_symmetric_abs_beta_error_over_width, ...
        'o-','LineWidth',1.2);
end

xlabel('A_w/A_s');
ylabel('Allowed symmetric |\delta\beta_s|/W_\beta for E\leq1');
title('EXP009 PA5D — Fence-Aware Subtraction Tolerance');
legend(arrayfun(@(x)sprintf('|\\eta|=%.3g',x), ...
    cfg.tolerance_fractional_bin_offsets, ...
    'UniformOutput',false),'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig06_tolerance_vs_contrast_and_offset.png'), ...
    'Resolution',180);
close(fig);

%% Fig 7 — tolerance directional asymmetry at half-bin
fig = figure('Visible',cfg.figure_visible);
hold on;

eta = 0.5;

for im=1:numel(modes)

    M = Tol( ...
        string(Tol.aperture_mode)==modes(im) & ...
        string(Tol.window_family)=="BandwidthMatched" & ...
        Tol.window_index==2 & ...
        abs(Tol.fractional_bin_offset-eta)<1e-12,:);

    [~,o] = sort(M.weak_to_strong_ratio);
    M = M(o,:);

    plot(M.weak_to_strong_ratio, ...
        M.allowed_negative_abs_beta_error_over_width, ...
        'o-','LineWidth',1.2);

    plot(M.weak_to_strong_ratio, ...
        M.allowed_positive_beta_error_over_width, ...
        's--','LineWidth',1.2);
end

xlabel('A_w/A_s');
ylabel('Allowed one-sided |\delta\beta_s|/W_\beta');
title('EXP009 PA5D — Directional Tolerance at Half-Bin Offset');
legend({'Paper negative','Paper positive', ...
        'Beam negative','Beam positive'}, ...
       'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig07_halfbin_directional_tolerance.png'), ...
    'Resolution',180);
close(fig);

%% Fig 8 — scaling R2 heatmap, Beam matched
M = Scale( ...
    string(Scale.aperture_mode)=="BeamDerived" & ...
    string(Scale.window_family)=="BandwidthMatched",:);

offs = unique(M.fractional_bin_offset).';
idxs = unique(M.window_index).';

Z = nan(numel(offs),numel(idxs));

for io=1:numel(offs)
    for iw=1:numel(idxs)

        q = ...
            abs(M.fractional_bin_offset-offs(io))<1e-12 & ...
            M.window_index==idxs(iw);

        if any(q)
            Z(io,iw) = M.tolerance_scaling_R2(q);
        end
    end
end

fig = figure('Visible',cfg.figure_visible);

imagesc(idxs,offs,Z);
set(gca,'YDir','normal');
colorbar;
caxis([0 1]);

xlabel('Bandwidth-matched window index');
ylabel('Focused fractional-bin offset |\eta|');
title('EXP009 PA5D — Contrast-Scaling R^2 Robustness');

exportgraphics(fig, ...
    fullfile(out_path,'fig08_tolerance_scaling_R2_map.png'), ...
    'Resolution',180);
close(fig);

end
