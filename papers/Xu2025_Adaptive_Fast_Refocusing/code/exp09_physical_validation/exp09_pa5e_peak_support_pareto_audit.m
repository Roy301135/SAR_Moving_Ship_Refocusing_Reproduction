function results = exp09_pa5e_peak_support_pareto_audit()
%EXP09_PA5E_PEAK_SUPPORT_PARETO_AUDIT
% EXP009 / PA5E
%
% Peak-Support / Resolution-Cell / Pareto Audit
%
% This experiment is deliberately narrower than PA5D.
%
% It asks:
%
% RQ1. How much of the half-bin degradation is caused by the exact
%      interpretation of Wang's "FindPeak(|g| > 0.7 max)" step?
%
% RQ2. Which coordinate best collapses Paper1s / BeamDerived removal
%      behavior:
%
%          l,
%          l/N,
%          l/W_focus,3dB ?
%
% RQ3. What are the nondominated operating points in
%
%          maximize weak-stage success,
%          minimize waveform error,
%
%      without an arbitrary "balanced-window" rule?
%
% RQ4. Does a nonzero recoverability floor
%
%          r_min = L0 / sqrt(1-D0^2)
%
%      survive after plateau/twin-bin-safe peak handling?
%
% Three peak semantics
% --------------------
% LocalMax:
%   legacy PA5C/PA5D rule. It intentionally preserves the strict-left,
%   non-strict-right local-max convention used previously.
%
% ConnectedSupport:
%   treat all samples satisfying |Y| >= 0.7 max|Y| as detected support;
%   apply the l-bin window as a dilation radius around that support.
%
% PlateauAware:
%   detect local maxima with >= on both sides and at least one strict
%   inequality. Adjacent equal maxima are therefore both retained.
%   An l-bin window is placed around every retained maximum.
%
% Important:
% The paper does not disambiguate these discrete tie/support semantics.
% PA5E treats them as an implementation-sensitivity audit, not as three
% claims about the authors' private code.
%
% Run:
%   results = exp09_pa5e_peak_support_pareto_audit;

cfg = config_exp09_pa5e_peak_support_pareto_audit();
validate_config_complete(cfg);

%% Output path
this_dir = fileparts(mfilename('fullpath'));
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.output_dir)
    out_path = fullfile( ...
        paper_root,'results','exp09_physical_validation', ...
        'exp09_pa5e_peak_support_pareto_audit');
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
    lambda/cfg.antenna_length_m * cfg.beamwidth_scale;

vw = cfg.weak_velocity_mps;

[~,~,Kw] = residual_fm_rates(vw,R0,lambda,cfg);
aw = Kw/(cfg.prf_hz^2);
beta_w = atan(aw);

%% Aperture definitions
T_paper = cfg.paper_aperture_time_s;
N_paper = max(32,round(cfg.prf_hz*T_paper));

T_beam = ...
    R0*beamwidth_rad/cfg.platform_velocity_mps;
N_beam = max(32,round(cfg.prf_hz*T_beam));

aperture_names = ["Paper1s","BeamDerived"];
N_list = [N_paper,N_beam];
T_target_list = [T_paper,T_beam];

%% FrAc width calibration and focused-resolution-cell calibration
frac_width_rows = {};
focus_width_rows = {};
store = struct();

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

    w0 = synth_discrete_lfm(N,1,aw,0,0);

    Rww = pair_frac_response( ...
        w0,w0,beta_grid_width,max_lag,cfg);

    Pweak = sum(abs(Rww).^2,2);

    Wbeta = estimate_3db_width( ...
        beta_grid_width,Pweak,beta_w);

    if ~isfinite(Wbeta) || Wbeta<=0
        error('Could not estimate FrAc Wbeta for %s.',mode);
    end

    frac_width_rows(end+1,:) = { ... %#ok<AGROW>
        char(mode),N,T_target,T_actual,max_lag,Wbeta};

    store.(char(mode)) = struct( ...
        'N',N, ...
        'T_actual',T_actual, ...
        'max_lag',max_lag, ...
        'Wbeta',Wbeta, ...
        'focus_width_by_eta',nan( ...
            size(cfg.fractional_bin_offsets)));

    for io = 1:numel(cfg.fractional_bin_offsets)

        eta = cfg.fractional_bin_offsets(io);
        b = eta/N;

        Wfocus_bins = focused_3db_width_bins( ...
            N,b,cfg);

        Wfocus_hz = Wfocus_bins*cfg.prf_hz/N;

        focus_width_rows(end+1,:) = { ... %#ok<AGROW>
            char(mode),N,eta,b, ...
            Wfocus_bins,Wfocus_hz};

        store.(char(mode)).focus_width_by_eta(io) = ...
            Wfocus_bins;
    end
end

frac_width_table = cell2table( ...
    frac_width_rows, ...
    'VariableNames',{ ...
    'aperture_mode','azimuth_samples', ...
    'target_aperture_time_s','actual_observation_time_s', ...
    'max_frac_lag','weak_single_3db_width_beta_rad'});

focus_width_table = cell2table( ...
    focus_width_rows, ...
    'VariableNames',{ ...
    'aperture_mode','azimuth_samples', ...
    'fractional_bin_offset', ...
    'center_frequency_cycles_per_sample', ...
    'focused_3db_power_width_bins', ...
    'focused_3db_power_width_hz'});

writetable(frac_width_table, ...
    fullfile(out_path,'pa5e_frac_width_calibration.csv'));

writetable(focus_width_table, ...
    fullfile(out_path,'pa5e_focus_resolution_cell_calibration.csv'));

%% Main practical sweep
rows = {};
sides = ["LowV","HighV"];

for ia = 1:2

    mode = aperture_names(ia);
    N = store.(char(mode)).N;
    max_lag = store.(char(mode)).max_lag;
    Wbeta = store.(char(mode)).Wbeta;

    for io = 1:numel(cfg.fractional_bin_offsets)

        eta = cfg.fractional_bin_offsets(io);
        b_common = eta/N;

        Wfocus_bins = ...
            store.(char(mode)).focus_width_by_eta(io);

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
                    N,cfg.A_strong, ...
                    as,b_common,0);

                %% FrAc basis
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

                        x = s0+cw*w0;
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

                        %% Practical strong-order estimate
                        [~,ihat] = max(P1);
                        beta_hat = beta_grid(ihat);
                        a_hat = tan(beta_hat);

                        beta_error_over_width = ...
                            (beta_hat-beta_s)/Wbeta;

                        %% Peak-semantics x window sweep
                        for isem = 1:numel(cfg.peak_semantics)

                            semantics = ...
                                cfg.peak_semantics(isem);

                            for il = 1:numel( ...
                                    cfg.filter_window_length_bins)

                                Lwin = ...
                                    cfg.filter_window_length_bins(il);

                                [r,~,info] = ...
                                    semantic_filter_remove( ...
                                        x,a_hat,Lwin, ...
                                        semantics,cfg);

                                E = ...
                                    norm(r-w_true) / ...
                                    max(norm(w_true), ...
                                        cfg.small_norm_floor);

                                [weak_ok,weak_peak_ratio] = ...
                                    weak_stage_readiness( ...
                                        r,aw,b_common,cfg);

                                [sr,wr] = ...
                                    apply_fixed_mask_components( ...
                                        s0,w_true,a_hat, ...
                                        info.mask);

                                Ls = ...
                                    norm(sr) / ...
                                    max(norm(s0), ...
                                        cfg.small_norm_floor);

                                Dw = ...
                                    norm(wr) / ...
                                    max(norm(w_true), ...
                                        cfg.small_norm_floor);

                                Epred = sqrt( ...
                                    (Ls/rA)^2+Dw^2);

                                identity_abs_error = ...
                                    abs(Epred-E);

                                denom = ...
                                    (Ls/rA)^2+Dw^2;

                                if denom>0
                                    leak_fraction = ...
                                        (Ls/rA)^2/denom;
                                else
                                    leak_fraction = 0;
                                end

                                rows(end+1,:) = { ... %#ok<AGROW>
                                    char(mode),N, ...
                                    eta,b_common, ...
                                    Wfocus_bins, ...
                                    dv,char(side),vs, ...
                                    Gamma,char(regime), ...
                                    rA,phi,double(pre_hidden), ...
                                    beta_s,beta_hat, ...
                                    beta_error_over_width, ...
                                    char(semantics), ...
                                    Lwin,Lwin/N, ...
                                    Lwin*cfg.prf_hz/N, ...
                                    Lwin/Wfocus_bins, ...
                                    double(weak_ok), ...
                                    weak_peak_ratio,E, ...
                                    double(E<= ...
                                        cfg.error_feasible_threshold), ...
                                    Ls,Dw,leak_fraction, ...
                                    Epred,identity_abs_error, ...
                                    info.num_objects, ...
                                    info.raw_detected_bin_count, ...
                                    info.mask_bin_count, ...
                                    info.mask_fraction};
                            end
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
    'fractional_bin_offset', ...
    'center_frequency_cycles_per_sample', ...
    'focused_3db_width_bins', ...
    'delta_velocity_mps','strong_velocity_side', ...
    'strong_velocity_mps', ...
    'Gamma_sep_over_width','Gamma_regime', ...
    'weak_to_strong_ratio','relative_phase_rad', ...
    'pre_hidden', ...
    'beta_strong_true_rad','beta_strong_hat_rad', ...
    'strong_est_error_over_width', ...
    'peak_semantics', ...
    'window_bins','window_fraction_N', ...
    'window_bandwidth_hz', ...
    'window_resolution_cells', ...
    'weak_stage_success','weak_stage_peak_ratio', ...
    'practical_error_ratio','error_feasible_E_le_1', ...
    'strong_leak_ratio', ...
    'weak_projection_loss_ratio', ...
    'strong_leak_error_fraction', ...
    'predicted_error_ratio','identity_abs_error', ...
    'num_detected_objects', ...
    'raw_detected_bin_count', ...
    'mask_bin_count','mask_fraction'});

writetable(trial_table, ...
    fullfile(out_path,'pa5e_trial_results.csv'));

%% Identity summary
identity_summary = summarize_identity( ...
    trial_table,cfg);

writetable(identity_summary, ...
    fullfile(out_path,'pa5e_projection_identity_summary.csv'));

%% Operating-point summary
operating_summary = summarize_operating_points( ...
    trial_table);

writetable(operating_summary, ...
    fullfile(out_path,'pa5e_operating_point_summary.csv'));

%% Pareto audit
[pareto_all,pareto_front,pareto_semantics] = ...
    build_pareto_tables(operating_summary);

writetable(pareto_all, ...
    fullfile(out_path,'pa5e_pareto_all_points.csv'));

writetable(pareto_front, ...
    fullfile(out_path,'pa5e_pareto_front.csv'));

writetable(pareto_semantics, ...
    fullfile(out_path,'pa5e_pareto_semantics_summary.csv'));

%% Recoverability floor
[floor_trials,floor_summary] = ...
    recoverability_floor_audit( ...
        cfg,store,lambda,R0, ...
        aw,beta_w);

writetable(floor_trials, ...
    fullfile(out_path,'pa5e_recoverability_floor_trials.csv'));

writetable(floor_summary, ...
    fullfile(out_path,'pa5e_recoverability_floor_summary.csv'));

%% Coordinate-collapse audit
[collapse_detail,collapse_summary] = ...
    coordinate_collapse_audit( ...
        operating_summary,cfg);

writetable(collapse_detail, ...
    fullfile(out_path,'pa5e_coordinate_collapse_detail.csv'));

writetable(collapse_summary, ...
    fullfile(out_path,'pa5e_coordinate_collapse_summary.csv'));

%% Peak-semantics audit summary
semantics_summary = ...
    peak_semantics_summary( ...
        operating_summary,floor_summary,cfg);

writetable(semantics_summary, ...
    fullfile(out_path,'pa5e_peak_semantics_summary.csv'));

%% Decision
decision_summary = build_decision_summary( ...
    identity_summary,semantics_summary, ...
    collapse_summary,pareto_front,cfg);

writetable(decision_summary, ...
    fullfile(out_path,'pa5e_decision_summary.csv'));

%% Text summary
write_summary( ...
    out_path,cfg,lambda,R0, ...
    frac_width_table,focus_width_table, ...
    identity_summary,semantics_summary, ...
    collapse_summary,pareto_semantics, ...
    floor_summary,decision_summary);

%% Figures
make_figures( ...
    out_path,cfg,store,lambda,R0, ...
    aw,beta_w,operating_summary, ...
    pareto_all,pareto_front, ...
    floor_summary,collapse_summary, ...
    semantics_summary);

%% Save
results = struct();
results.cfg = cfg;
results.lambda = lambda;
results.R0 = R0;
results.frac_width_table = frac_width_table;
results.focus_width_table = focus_width_table;
results.trial_table = trial_table;
results.identity_summary = identity_summary;
results.operating_summary = operating_summary;
results.pareto_all = pareto_all;
results.pareto_front = pareto_front;
results.pareto_semantics = pareto_semantics;
results.floor_trials = floor_trials;
results.floor_summary = floor_summary;
results.collapse_detail = collapse_detail;
results.collapse_summary = collapse_summary;
results.semantics_summary = semantics_summary;
results.decision_summary = decision_summary;

save(fullfile(out_path,'exp09_pa5e_results.mat'), ...
    'results','-v7.3');

fprintf('\n============================================================\n');
fprintf(' EXP009 PA5E / Peak Support + Resolution Cell + Pareto\n');
fprintf('============================================================\n');
disp(identity_summary);
disp(semantics_summary);
disp(collapse_summary);
disp(pareto_semantics);
disp(decision_summary);
fprintf('============================================================\n');
fprintf('Saved to:\n%s\n\n',out_path);

end

%% ========================================================================
function validate_config_complete(cfg)
% Fail early with one consolidated message if any required cfg field is absent.
required = { ...
    'A_strong', ...
    'antenna_length_m', ...
    'beamwidth_scale', ...
    'beta_margin_widths', ...
    'beta_step_min_width_fraction', ...
    'beta_step_separation_fraction', ...
    'beta_step_width_fraction', ...
    'c', ...
    'collapse_grid_points', ...
    'collapse_metrics', ...
    'delta_velocity_mps', ...
    'error_feasible_threshold', ...
    'fc_hz', ...
    'figure_case_aperture', ...
    'figure_case_delta_velocity_mps', ...
    'figure_case_eta', ...
    'figure_case_side', ...
    'figure_case_window_bins', ...
    'figure_visible', ...
    'filter_window_length_bins', ...
    'focus_spectrum_oversample', ...
    'focus_width_power_fraction', ...
    'frac_domain_peak_gate', ...
    'frac_fft_oversample', ...
    'fractional_bin_offsets', ...
    'gamma_partial_max', ...
    'gamma_unresolved_max', ...
    'identity_max_abs_error_gate', ...
    'max_lag_fraction', ...
    'min_peak_prominence_fraction', ...
    'output_dir', ...
    'paper_aperture_time_s', ...
    'peak_association_fraction_of_separation', ...
    'peak_association_min_width_fraction', ...
    'peak_semantics', ...
    'persistent_floor_rmin_gate', ...
    'platform_height_m', ...
    'platform_velocity_mps', ...
    'prf_hz', ...
    'relative_phase_rad', ...
    'semantic_floor_reduction_ratio_gate', ...
    'slant_range_factor', ...
    'small_norm_floor', ...
    'weak_stage_center_tolerance_bins', ...
    'weak_stage_peak_gate', ...
    'weak_to_strong_ratio', ...
    'weak_velocity_mps', ...
    'width_grid_halfspan_rad', ...
    'width_grid_points'};

missing = required(~isfield(cfg,required));

if ~isempty(missing)
    error('EXP009:PA5E:MissingConfigField', ...
        'Missing config field(s): %s', strjoin(missing, ', '));
end

end

%% ========================================================================
function [K_A,K_SAR,K_res] = ...
    residual_fm_rates(v,R0,lambda,cfg)

V = cfg.platform_velocity_mps;

K_A = -2*(V-v).^2/(lambda*R0);
K_SAR = 2*V^2/(lambda*R0);
K_res = K_SAR.^2./(K_A-K_SAR)+K_SAR;

end

%% ========================================================================
function x = synth_discrete_lfm(N,A,a,b,phi)

m = 0:N-1;

x = A.*exp(1j*2*pi*( ...
    0.5*a*m.^2+b*m)+1j*phi);

x = x(:).';

end

%% ========================================================================
function R = pair_frac_response( ...
    xl,xr,bg,max_lag,cfg)

xl = xl(:).';
xr = xr(:).';

N = numel(xl);

nfft = max(2048, ...
    2^nextpow2(cfg.frac_fft_oversample*N));

f = (-nfft/2:nfft/2-1).'/nfft;
tb = tan(bg(:));

R = complex(zeros(numel(bg),max_lag));

for k = 1:max_lag

    z = ...
        xl(1+k:end).* ...
        conj(xr(1:end-k));

    Z = fftshift(fft(z,nfft));
    Z = Z(:);

    R(:,k) = interp1( ...
        f,Z,k*tb,'linear',0) / ...
        max(numel(z),1);
end

end

%% ========================================================================
function W = estimate_3db_width(bg,P,b0)

P = real(P(:));

[~,i0] = min(abs(bg-b0));

halfwin = max(5,round(0.20*numel(bg)));

i1 = max(1,i0-halfwin);
i2 = min(numel(bg),i0+halfwin);

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
    W = bg(ir)-bg(il);
end

end

%% ========================================================================
function Wbins = focused_3db_width_bins(N,b,cfg)
% Oversampled single-component focused spectrum.
% Width is expressed in ORIGINAL N-point DFT-bin units.

os = cfg.focus_spectrum_oversample;
nfft = os*N;

m = 0:N-1;
z = exp(1j*2*pi*b*m);

P = abs(fftshift(fft(z,nfft))).^2;
P = P/max(P);

xbin = (-nfft/2:nfft/2-1).'/os;
P = P(:);

[~,ip] = max(P);
lev = cfg.focus_width_power_fraction;

il = ip;
while il>1 && P(il)>=lev
    il = il-1;
end

ir = ip;
while ir<numel(P) && P(ir)>=lev
    ir = ir+1;
end

if il==1 || ir==numel(P)
    Wbins = NaN;
    return;
end

xL = crossing_interp( ...
    xbin(il),P(il), ...
    xbin(il+1),P(il+1),lev);

xR = crossing_interp( ...
    xbin(ir-1),P(ir-1), ...
    xbin(ir),P(ir),lev);

Wbins = xR-xL;

end

%% ========================================================================
function x = crossing_interp(x1,y1,x2,y2,y0)

if abs(y2-y1)<eps
    x = 0.5*(x1+x2);
else
    t = (y0-y1)/(y2-y1);
    t = min(max(t,0),1);
    x = x1+t*(x2-x1);
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
    P(2:end-1)>=P(3:end))+1;

if isempty(idx)
    [~,idx] = max(P);
end

pr = zeros(size(idx));

for j = 1:numel(idx)

    ii = idx(j);

    pr(j) = P(ii)-max( ...
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

[~,o] = sortrows( ...
    [d(ii),-p.prominence(ii)],[1 2]);

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

z = x.*exp(-1j*pi*a*m.^2);

Y = fftshift(fft(z))/sqrt(N);

end

%% ========================================================================
function x = inverse_matched_lfm_transform(Y,a)

Y = Y(:).';

N = numel(Y);
m = 0:N-1;

z = ifft(ifftshift(Y))*sqrt(N);

x = z.*exp(1j*pi*a*m.^2);

end

%% ========================================================================
function [r,extracted,info] = ...
    semantic_filter_remove( ...
        x,a_hat,Lwin,semantics,cfg)

Y = matched_lfm_transform(x,a_hat);

[mask,info] = build_semantic_mask( ...
    Y,Lwin,semantics,cfg);

Yext = zeros(size(Y));
Yext(mask) = Y(mask);

extracted = ...
    inverse_matched_lfm_transform( ...
        Yext,a_hat);

r = x-extracted;

end

%% ========================================================================
function [mask,info] = ...
    build_semantic_mask( ...
        Y,Lwin,semantics,cfg)

amp = abs(Y(:).');
N = numel(amp);

gate = cfg.frac_domain_peak_gate*max(amp);
half = floor((Lwin-1)/2);

semantics = string(semantics);

switch semantics

    case "LocalMax"

        centers = legacy_localmax_peaks(amp,gate);

        mask = false(1,N);

        for k = 1:numel(centers)

            i1 = max(1,centers(k)-half);
            i2 = min(N,centers(k)+half);

            mask(i1:i2) = true;
        end

        raw = centers;
        num_objects = numel(centers);

    case "ConnectedSupport"

        support = amp>=gate;

        if ~any(support)
            [~,imax] = max(amp);
            support(imax) = true;
        end

        mask = dilate_binary_support( ...
            support,half);

        raw = find(support);
        num_objects = ...
            count_connected_components(support);

    case "PlateauAware"

        centers = plateau_aware_peaks(amp,gate);

        mask = false(1,N);

        for k = 1:numel(centers)

            i1 = max(1,centers(k)-half);
            i2 = min(N,centers(k)+half);

            mask(i1:i2) = true;
        end

        raw = centers;
        num_objects = ...
            count_connected_components( ...
                index_to_mask(centers,N));

    otherwise
        error('Unknown peak semantics: %s',semantics);
end

info = struct();
info.mask = mask;
info.raw_detected_bin_count = numel(raw);
info.mask_bin_count = nnz(mask);
info.mask_fraction = mean(mask);
info.num_objects = num_objects;
info.raw_indices = raw;

end

%% ========================================================================
function pk = legacy_localmax_peaks(amp,gate)
% Exact PA5C/PA5D convention retained for audit:
%   strict left, non-strict right.

amp = amp(:).';
N = numel(amp);

idx = find( ...
    amp(2:end-1)>amp(1:end-2) & ...
    amp(2:end-1)>=amp(3:end))+1;

if N>=2

    if amp(1)>=amp(2)
        idx = [1 idx]; %#ok<AGROW>
    end

    if amp(end)>amp(end-1)
        idx = [idx N]; %#ok<AGROW>
    end
end

idx = unique(idx);

pk = idx(amp(idx)>=gate);

if isempty(pk)
    [~,pk] = max(amp);
end

end

%% ========================================================================
function pk = plateau_aware_peaks(amp,gate)
% Symmetric tie-safe local-maximum rule.
%
% Interior sample i is retained if:
%   amp(i) >= left and amp(i) >= right
% and
%   amp(i) is strictly greater than at least one neighbor.
%
% A two-bin equal maximum therefore retains both members.

amp = amp(:).';
N = numel(amp);

pk = [];

if N==1
    pk = 1;
    return;
end

if amp(1)>=amp(2) && amp(1)>=gate
    pk(end+1) = 1; %#ok<AGROW>
end

for i = 2:N-1

    ismax = ...
        amp(i)>=amp(i-1) && ...
        amp(i)>=amp(i+1) && ...
        (amp(i)>amp(i-1) || ...
         amp(i)>amp(i+1));

    if ismax && amp(i)>=gate
        pk(end+1) = i; %#ok<AGROW>
    end
end

if amp(N)>=amp(N-1) && amp(N)>=gate
    pk(end+1) = N; %#ok<AGROW>
end

pk = unique(pk);

if isempty(pk)
    [~,imax] = max(amp);

    plateau = find( ...
        abs(amp-amp(imax)) <= ...
        100*eps(max(amp)));

    pk = plateau;
end

end

%% ========================================================================
function out = dilate_binary_support(mask,half)

mask = logical(mask(:).');
N = numel(mask);

if half<=0
    out = mask;
    return;
end

idx = find(mask);
out = false(1,N);

for k = 1:numel(idx)

    i1 = max(1,idx(k)-half);
    i2 = min(N,idx(k)+half);

    out(i1:i2) = true;
end

end

%% ========================================================================
function n = count_connected_components(mask)

mask = logical(mask(:).');

if isempty(mask)
    n = 0;
    return;
end

d = diff([false mask false]);

n = nnz(d==1);

end

%% ========================================================================
function mask = index_to_mask(idx,N)

mask = false(1,N);

if ~isempty(idx)
    mask(idx) = true;
end

end

%% ========================================================================
function [sr,wr] = ...
    apply_fixed_mask_components( ...
        s,w,a_hat,mask)

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
    weak_stage_readiness( ...
        residual,aweak,bweak,cfg)

Y = matched_lfm_transform( ...
    residual,aweak);

amp = abs(Y);
N = numel(amp);

eta = bweak*N;
dc = floor(N/2)+1;

idx_expected = round(dc+eta);
idx_expected = min(max(idx_expected,1),N);

i1 = max(1, ...
    idx_expected- ...
    cfg.weak_stage_center_tolerance_bins);

i2 = min(N, ...
    idx_expected+ ...
    cfg.weak_stage_center_tolerance_bins);

local_peak = max(amp(i1:i2));
global_peak = max(amp);

ratio = ...
    local_peak / ...
    max(global_peak,cfg.small_norm_floor);

ok = ratio>=cfg.weak_stage_peak_gate;

end

%% ========================================================================
function S = summarize_identity(T,cfg)

modes = unique(string(T.aperture_mode),'stable');
sems = unique(string(T.peak_semantics),'stable');

rows = {};

for im = 1:numel(modes)

    for is = 1:numel(sems)

        M = T( ...
            string(T.aperture_mode)==modes(im) & ...
            string(T.peak_semantics)==sems(is),:);

        e = M.identity_abs_error;
        e = e(isfinite(e));

        rows(end+1,:) = { ... %#ok<AGROW>
            char(modes(im)),char(sems(is)), ...
            height(M),median(e),max(e), ...
            double(max(e)<= ...
                cfg.identity_max_abs_error_gate)};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','peak_semantics', ...
    'n','median_identity_abs_error', ...
    'max_identity_abs_error', ...
    'identity_gate_pass'});

end

%% ========================================================================
function S = summarize_operating_points(T)

modes = unique(string(T.aperture_mode),'stable');
etas = unique(T.fractional_bin_offset).';
sems = unique(string(T.peak_semantics),'stable');
wins = unique(T.window_bins).';

rows = {};

for im = 1:numel(modes)

    for io = 1:numel(etas)

        for is = 1:numel(sems)

            for iw = 1:numel(wins)

                H = T( ...
                    string(T.aperture_mode)==modes(im) & ...
                    abs(T.fractional_bin_offset-etas(io))<1e-12 & ...
                    string(T.peak_semantics)==sems(is) & ...
                    T.window_bins==wins(iw) & ...
                    logical(T.pre_hidden),:);

                if isempty(H)
                    continue;
                end

                rows(end+1,:) = { ... %#ok<AGROW>
                    char(modes(im)), ...
                    etas(io), ...
                    char(sems(is)), ...
                    wins(iw), ...
                    median(H.window_fraction_N), ...
                    median(H.window_bandwidth_hz), ...
                    median(H.window_resolution_cells), ...
                    height(H), ...
                    mean(H.weak_stage_success), ...
                    mean(H.error_feasible_E_le_1), ...
                    median(H.practical_error_ratio,'omitnan'), ...
                    prctile(H.practical_error_ratio,90), ...
                    median(H.strong_leak_ratio,'omitnan'), ...
                    median(H.weak_projection_loss_ratio,'omitnan'), ...
                    median(H.strong_leak_error_fraction,'omitnan'), ...
                    median(H.mask_fraction,'omitnan'), ...
                    median(H.raw_detected_bin_count,'omitnan')};
            end
        end
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','fractional_bin_offset', ...
    'peak_semantics','window_bins', ...
    'window_fraction_N','window_bandwidth_hz', ...
    'window_resolution_cells','n_hidden', ...
    'weak_stage_success_rate', ...
    'E_le_1_trial_fraction', ...
    'median_practical_error_ratio', ...
    'p90_practical_error_ratio', ...
    'median_strong_leak_ratio', ...
    'median_weak_projection_loss_ratio', ...
    'median_strong_leak_error_fraction', ...
    'median_mask_fraction', ...
    'median_raw_detected_bin_count'});

end

%% ========================================================================
function [A,F,SS] = build_pareto_tables(S)

A = S;
A.is_pareto_global = zeros(height(A),1);
A.is_pareto_within_semantics = zeros(height(A),1);
A.median_E_feasible = ...
    double(A.median_practical_error_ratio<=1);

modes = unique(string(A.aperture_mode),'stable');
etas = unique(A.fractional_bin_offset).';
sems = unique(string(A.peak_semantics),'stable');

%% Global Pareto: all semantics x windows
for im = 1:numel(modes)

    for io = 1:numel(etas)

        idx = find( ...
            string(A.aperture_mode)==modes(im) & ...
            abs(A.fractional_bin_offset-etas(io))<1e-12);

        pf = pareto_success_error( ...
            A.weak_stage_success_rate(idx), ...
            A.median_practical_error_ratio(idx));

        A.is_pareto_global(idx(pf)) = 1;
    end
end

%% Within-semantic Pareto
for im = 1:numel(modes)

    for io = 1:numel(etas)

        for is = 1:numel(sems)

            idx = find( ...
                string(A.aperture_mode)==modes(im) & ...
                abs(A.fractional_bin_offset-etas(io))<1e-12 & ...
                string(A.peak_semantics)==sems(is));

            pf = pareto_success_error( ...
                A.weak_stage_success_rate(idx), ...
                A.median_practical_error_ratio(idx));

            A.is_pareto_within_semantics(idx(pf)) = 1;
        end
    end
end

F = A(logical(A.is_pareto_global),:);

%% How often each semantics reaches the global front
rows = {};

for im = 1:numel(modes)

    for is = 1:numel(sems)

        M = A( ...
            string(A.aperture_mode)==modes(im) & ...
            string(A.peak_semantics)==sems(is),:);

        rows(end+1,:) = { ... %#ok<AGROW>
            char(modes(im)),char(sems(is)), ...
            height(M), ...
            sum(M.is_pareto_global), ...
            mean(M.is_pareto_global), ...
            min(M.median_practical_error_ratio), ...
            max(M.weak_stage_success_rate), ...
            max(M.E_le_1_trial_fraction)};
    end
end

SS = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','peak_semantics', ...
    'n_operating_points', ...
    'n_global_pareto_points', ...
    'fraction_on_global_pareto_front', ...
    'minimum_median_error', ...
    'maximum_weak_stage_success', ...
    'maximum_E_le_1_trial_fraction'});

end

%% ========================================================================
function pf = pareto_success_error(success,errorv)
% Nondominated for:
%   maximize success
%   minimize error

n = numel(success);
pf = true(n,1);

for i = 1:n

    for j = 1:n

        if i==j
            continue;
        end

        dominates = ...
            success(j)>=success(i) && ...
            errorv(j)<=errorv(i) && ...
            (success(j)>success(i) || ...
             errorv(j)<errorv(i));

        if dominates
            pf(i) = false;
            break;
        end
    end
end

end

%% ========================================================================
function [T,S] = recoverability_floor_audit( ...
    cfg,store,lambda,R0,aw,beta_w)

modes = ["Paper1s","BeamDerived"];
sides = ["LowV","HighV"];
sems = cfg.peak_semantics;
wins = cfg.filter_window_length_bins;

rows = {};

for im = 1:numel(modes)

    mode = modes(im);
    N = store.(char(mode)).N;

    for io = 1:numel(cfg.fractional_bin_offsets)

        eta = cfg.fractional_bin_offsets(io);
        b = eta/N;

        Wfocus = ...
            store.(char(mode)).focus_width_by_eta(io);

        w0 = synth_discrete_lfm( ...
            N,1,aw,b,0);

        for idv = 1:numel(cfg.delta_velocity_mps)

            dv = cfg.delta_velocity_mps(idv);

            for iside = 1:2

                side = sides(iside);

                if side=="LowV"
                    vs = cfg.weak_velocity_mps-dv;
                else
                    vs = cfg.weak_velocity_mps+dv;
                end

                [~,~,Ks] = residual_fm_rates( ...
                    vs,R0,lambda,cfg);

                as = Ks/(cfg.prf_hz^2);

                s0 = synth_discrete_lfm( ...
                    N,1,as,b,0);

                Ys = matched_lfm_transform(s0,as);

                for is = 1:numel(sems)

                    semantics = sems(is);

                    for iw = 1:numel(wins)

                        Lwin = wins(iw);

                        [mask,info] = build_semantic_mask( ...
                            Ys,Lwin,semantics,cfg);

                        [sr,wr] = ...
                            apply_fixed_mask_components( ...
                                s0,w0,as,mask);

                        L0 = norm(sr)/norm(s0);
                        D0 = norm(wr)/norm(w0);

                        if D0>=1-1e-12

                            if L0<=1e-12
                                rmin = 0;
                            else
                                rmin = Inf;
                            end

                        else

                            rmin = ...
                                L0 / ...
                                sqrt(max(1-D0^2,eps));
                        end

                        rows(end+1,:) = { ... %#ok<AGROW>
                            char(mode),eta, ...
                            dv,char(side),vs, ...
                            char(semantics), ...
                            Lwin,Lwin/N, ...
                            Lwin*cfg.prf_hz/N, ...
                            Lwin/Wfocus, ...
                            L0,D0,rmin, ...
                            info.raw_detected_bin_count, ...
                            info.mask_bin_count};
                    end
                end
            end
        end
    end
end

T = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','fractional_bin_offset', ...
    'delta_velocity_mps','strong_velocity_side', ...
    'strong_velocity_mps', ...
    'peak_semantics','window_bins', ...
    'window_fraction_N','window_bandwidth_hz', ...
    'window_resolution_cells', ...
    'zero_mismatch_strong_leak_L0', ...
    'zero_mismatch_weak_loss_D0', ...
    'recoverability_floor_rmin', ...
    'raw_detected_bin_count', ...
    'mask_bin_count'});

%% Summary across physical separation geometries
sumrows = {};

for im = 1:numel(modes)

    for io = 1:numel(cfg.fractional_bin_offsets)

        eta = cfg.fractional_bin_offsets(io);

        for is = 1:numel(sems)

            for iw = 1:numel(wins)

                M = T( ...
                    string(T.aperture_mode)==modes(im) & ...
                    abs(T.fractional_bin_offset-eta)<1e-12 & ...
                    string(T.peak_semantics)==sems(is) & ...
                    T.window_bins==wins(iw),:);

                r = M.recoverability_floor_rmin;
                rf = r(isfinite(r));

                if isempty(rf)
                    medr = Inf;
                    maxr = Inf;
                    minr = Inf;
                else
                    medr = median(rf);
                    maxr = max(rf);
                    minr = min(rf);
                end

                sumrows(end+1,:) = { ... %#ok<AGROW>
                    char(modes(im)),eta, ...
                    char(sems(is)),wins(iw), ...
                    median(M.window_fraction_N), ...
                    median(M.window_bandwidth_hz), ...
                    median(M.window_resolution_cells), ...
                    median(M.zero_mismatch_strong_leak_L0), ...
                    median(M.zero_mismatch_weak_loss_D0), ...
                    medr,minr,maxr, ...
                    mean(isfinite(r))};
            end
        end
    end
end

S = cell2table(sumrows, ...
    'VariableNames',{ ...
    'aperture_mode','fractional_bin_offset', ...
    'peak_semantics','window_bins', ...
    'window_fraction_N','window_bandwidth_hz', ...
    'window_resolution_cells', ...
    'median_zero_mismatch_strong_leak_L0', ...
    'median_zero_mismatch_weak_loss_D0', ...
    'median_recoverability_floor_rmin', ...
    'minimum_recoverability_floor_rmin', ...
    'maximum_recoverability_floor_rmin', ...
    'finite_rmin_fraction'});

end

%% ========================================================================
function [D,S] = coordinate_collapse_audit( ...
    O,cfg)

coords = ...
    ["window_bins", ...
     "window_fraction_N", ...
     "window_resolution_cells"];

etas = unique(O.fractional_bin_offset).';
sems = unique(string(O.peak_semantics),'stable');

rows = {};

for io = 1:numel(etas)

    eta = etas(io);

    for is = 1:numel(sems)

        sem = sems(is);

        P = O( ...
            string(O.aperture_mode)=="Paper1s" & ...
            abs(O.fractional_bin_offset-eta)<1e-12 & ...
            string(O.peak_semantics)==sem,:);

        B = O( ...
            string(O.aperture_mode)=="BeamDerived" & ...
            abs(O.fractional_bin_offset-eta)<1e-12 & ...
            string(O.peak_semantics)==sem,:);

        for ic = 1:numel(coords)

            coord = coords(ic);

            xP = P.(coord);
            xB = B.(coord);

            for imet = 1:numel(cfg.collapse_metrics)

                metric = cfg.collapse_metrics(imet);

                yP = P.(metric);
                yB = B.(metric);

                [rmse,nrmse,npts] = ...
                    two_curve_collapse_score( ...
                        xP,yP,xB,yB, ...
                        cfg.collapse_grid_points);

                rows(end+1,:) = { ... %#ok<AGROW>
                    eta,char(sem),char(coord), ...
                    char(metric),rmse,nrmse,npts};
            end
        end
    end
end

D = cell2table(rows, ...
    'VariableNames',{ ...
    'fractional_bin_offset','peak_semantics', ...
    'coordinate','metric','rmse', ...
    'normalized_rmse','interpolation_points'});

%% Aggregate robustness by coordinate + metric
sumrows = {};
metrics = cfg.collapse_metrics;

for ic = 1:numel(coords)

    for imet = 1:numel(metrics)

        M = D( ...
            string(D.coordinate)==coords(ic) & ...
            string(D.metric)==metrics(imet),:);

        sumrows(end+1,:) = { ... %#ok<AGROW>
            char(coords(ic)),char(metrics(imet)), ...
            median(M.normalized_rmse,'omitnan'), ...
            mean(M.normalized_rmse,'omitnan'), ...
            max(M.normalized_rmse), ...
            median(M.rmse,'omitnan')};
    end
end

S = cell2table(sumrows, ...
    'VariableNames',{ ...
    'coordinate','metric', ...
    'median_normalized_rmse', ...
    'mean_normalized_rmse', ...
    'maximum_normalized_rmse', ...
    'median_absolute_rmse'});

end

%% ========================================================================
function [rmse,nrmse,npts] = ...
    two_curve_collapse_score( ...
        x1,y1,x2,y2,ngrid)

[x1,o1] = sort(x1(:));
y1 = y1(o1);

[x2,o2] = sort(x2(:));
y2 = y2(o2);

[x1,iu1] = unique(x1,'stable');
y1 = y1(iu1);

[x2,iu2] = unique(x2,'stable');
y2 = y2(iu2);

lo = max(min(x1),min(x2));
hi = min(max(x1),max(x2));

if ~(hi>lo) || numel(x1)<2 || numel(x2)<2
    rmse = NaN;
    nrmse = NaN;
    npts = 0;
    return;
end

xq = linspace(lo,hi,ngrid).';

q1 = interp1(x1,y1,xq,'linear');
q2 = interp1(x2,y2,xq,'linear');

good = isfinite(q1) & isfinite(q2);

q1 = q1(good);
q2 = q2(good);

if isempty(q1)
    rmse = NaN;
    nrmse = NaN;
    npts = 0;
    return;
end

rmse = sqrt(mean((q1-q2).^2));

scale = ...
    max([q1;q2])-min([q1;q2]);

if scale<=eps
    nrmse = rmse;
else
    nrmse = rmse/scale;
end

npts = numel(q1);

end

%% ========================================================================
function S = peak_semantics_summary( ...
    O,F,cfg)

modes = unique(string(O.aperture_mode),'stable');
sems = cfg.peak_semantics;

rows = {};

for im = 1:numel(modes)

    for is = 1:numel(sems)

        sem = sems(is);

        M0 = O( ...
            string(O.aperture_mode)==modes(im) & ...
            abs(O.fractional_bin_offset-0)<1e-12 & ...
            string(O.peak_semantics)==sem,:);

        Mh = O( ...
            string(O.aperture_mode)==modes(im) & ...
            abs(O.fractional_bin_offset-0.5)<1e-12 & ...
            string(O.peak_semantics)==sem,:);

        F1 = F( ...
            string(F.aperture_mode)==modes(im) & ...
            abs(F.fractional_bin_offset-0.5)<1e-12 & ...
            string(F.peak_semantics)==sem & ...
            F.window_bins==1,:);

        if isempty(F1)
            rmin1 = NaN;
            L01 = NaN;
            D01 = NaN;
        else
            rmin1 = ...
                F1.median_recoverability_floor_rmin;
            L01 = ...
                F1.median_zero_mismatch_strong_leak_L0;
            D01 = ...
                F1.median_zero_mismatch_weak_loss_D0;
        end

        rows(end+1,:) = { ... %#ok<AGROW>
            char(modes(im)),char(sem), ...
            min(M0.median_practical_error_ratio), ...
            min(Mh.median_practical_error_ratio), ...
            max(Mh.weak_stage_success_rate), ...
            max(Mh.E_le_1_trial_fraction), ...
            rmin1,L01,D01, ...
            median(Mh.median_raw_detected_bin_count,'omitnan')};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','peak_semantics', ...
    'minimum_on_grid_median_error', ...
    'minimum_half_bin_median_error', ...
    'maximum_half_bin_weak_stage_success', ...
    'maximum_half_bin_E_le_1_trial_fraction', ...
    'half_bin_L1_median_rmin', ...
    'half_bin_L1_median_L0', ...
    'half_bin_L1_median_D0', ...
    'half_bin_median_raw_detected_bin_count'});

end

%% ========================================================================
function D = build_decision_summary( ...
    I,S,C,P,cfg)

modes = unique(string(I.aperture_mode),'stable');

rows = {};

for im = 1:numel(modes)

    mode = modes(im);

    Ii = I(string(I.aperture_mode)==mode,:);
    identity_pass = all(Ii.identity_gate_pass==1);

    L = S( ...
        string(S.aperture_mode)==mode & ...
        string(S.peak_semantics)=="LocalMax",:);

    Cn = S( ...
        string(S.aperture_mode)==mode & ...
        string(S.peak_semantics)=="ConnectedSupport",:);

    Pa = S( ...
        string(S.aperture_mode)==mode & ...
        string(S.peak_semantics)=="PlateauAware",:);

    local_r = L.half_bin_L1_median_rmin;
    conn_r = Cn.half_bin_L1_median_rmin;
    plat_r = Pa.half_bin_L1_median_rmin;

    conn_ratio = conn_r/max(local_r,eps);
    plat_ratio = plat_r/max(local_r,eps);

    %% Best coordinate for strong-leak collapse
    Csl = C( ...
        string(C.metric)== ...
        "median_strong_leak_ratio",:);

    [~,ib] = min( ...
        Csl.median_normalized_rmse);

    best_coord = ...
        string(Csl.coordinate(ib));

    %% Half-bin global Pareto availability
    Ph = P( ...
        string(P.aperture_mode)==mode & ...
        abs(P.fractional_bin_offset-0.5)<1e-12,:);

    pareto_has_Efeasible = ...
        any(Ph.median_practical_error_ratio<=1);

    if ~identity_pass

        branch = "IDENTITY_IMPLEMENTATION_REVIEW";

    elseif ...
            conn_ratio<= ...
                cfg.semantic_floor_reduction_ratio_gate && ...
            plat_ratio<= ...
                cfg.semantic_floor_reduction_ratio_gate

        if min(conn_r,plat_r)<= ...
                cfg.persistent_floor_rmin_gate

            branch = ...
                "HALFBIN_FAILURE_MAINLY_PEAK_SEMANTICS_ARTIFACT";

        else

            branch = ...
                "PEAK_SEMANTICS_MATTERS_BUT_FENCE_FLOOR_PERSISTS";
        end

    else

        branch = ...
            "FENCE_FLOOR_PERSISTS_ACROSS_PEAK_SEMANTICS";
    end

    rows(end+1,:) = { ... %#ok<AGROW>
        char(mode),double(identity_pass), ...
        local_r,conn_r,plat_r, ...
        conn_ratio,plat_ratio, ...
        char(best_coord), ...
        double(pareto_has_Efeasible), ...
        char(branch)};
end

D = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode', ...
    'projection_identity_all_pass', ...
    'half_bin_L1_rmin_LocalMax', ...
    'half_bin_L1_rmin_ConnectedSupport', ...
    'half_bin_L1_rmin_PlateauAware', ...
    'ConnectedSupport_to_LocalMax_rmin_ratio', ...
    'PlateauAware_to_LocalMax_rmin_ratio', ...
    'best_coordinate_for_strong_leak_collapse', ...
    'half_bin_global_pareto_contains_median_E_le_1', ...
    'decision_branch'});

end

%% ========================================================================
function write_summary( ...
    out_path,cfg,lambda,R0, ...
    FW,Focus,I,S,C,PS,F,D)

fid = fopen(fullfile(out_path,'summary.txt'),'w');

fprintf(fid,'EXP009 PA5E / Peak Support + Resolution Cell + Pareto\n');
fprintf(fid,'====================================================\n\n');

fprintf(fid,'Purpose\n');
fprintf(fid,'-------\n');
fprintf(fid,['Audit whether PA5D half-bin degradation is a true operator ' ...
    'floor, a discrete peak-semantic artifact, or both.\n']);
fprintf(fid,['Audit the natural window coordinate without changing the ' ...
    'underlying actual windows.\n']);
fprintf(fid,['Replace the 90%% balanced rule by Pareto fronts and E<=1 ' ...
    'feasibility.\n\n']);

fprintf(fid,'Physical setup\n');
fprintf(fid,'--------------\n');
fprintf(fid,'fc=%g Hz, PRF=%g Hz, lambda=%g m, R0=%g m\n', ...
    cfg.fc_hz,cfg.prf_hz,lambda,R0);
fprintf(fid,'peak semantics=%s\n', ...
    strjoin(cellstr(cfg.peak_semantics),', '));
fprintf(fid,'windows=%s bins\n', ...
    mat2str(cfg.filter_window_length_bins));
fprintf(fid,'fence offsets=%s bins\n\n', ...
    mat2str(cfg.fractional_bin_offsets));

fprintf(fid,'FrAc widths\n');
fprintf(fid,'------------\n');
for i=1:height(FW)
    fprintf(fid,'%s N=%d Wbeta=%g\n', ...
        FW.aperture_mode{i}, ...
        FW.azimuth_samples(i), ...
        FW.weak_single_3db_width_beta_rad(i));
end

fprintf(fid,'\nFocused resolution-cell calibration\n');
fprintf(fid,'-----------------------------------\n');
for i=1:height(Focus)
    fprintf(fid,'%s eta=%g Wfocus=%g bins (%g Hz)\n', ...
        Focus.aperture_mode{i}, ...
        Focus.fractional_bin_offset(i), ...
        Focus.focused_3db_power_width_bins(i), ...
        Focus.focused_3db_power_width_hz(i));
end

fprintf(fid,'\nIdentity\n');
fprintf(fid,'--------\n');
for i=1:height(I)
    fprintf(fid,'%s %s maxErr=%g pass=%d\n', ...
        I.aperture_mode{i},I.peak_semantics{i}, ...
        I.max_identity_abs_error(i), ...
        I.identity_gate_pass(i));
end

fprintf(fid,'\nPeak-semantics summary\n');
fprintf(fid,'----------------------\n');
for i=1:height(S)
    fprintf(fid,[ ...
        '%s %s: onGridMinE=%g halfBinMinE=%g ' ...
        'halfBinMaxSuccess=%g halfBinMaxFeasibleFrac=%g ' ...
        'L1 rmin=%g L0=%g D0=%g\n'], ...
        S.aperture_mode{i},S.peak_semantics{i}, ...
        S.minimum_on_grid_median_error(i), ...
        S.minimum_half_bin_median_error(i), ...
        S.maximum_half_bin_weak_stage_success(i), ...
        S.maximum_half_bin_E_le_1_trial_fraction(i), ...
        S.half_bin_L1_median_rmin(i), ...
        S.half_bin_L1_median_L0(i), ...
        S.half_bin_L1_median_D0(i));
end

fprintf(fid,'\nCoordinate-collapse summary\n');
fprintf(fid,'---------------------------\n');
for i=1:height(C)
    fprintf(fid,'%s | %s: medianNRMSE=%g maxNRMSE=%g\n', ...
        C.coordinate{i},C.metric{i}, ...
        C.median_normalized_rmse(i), ...
        C.maximum_normalized_rmse(i));
end

fprintf(fid,'\nPareto semantics summary\n');
fprintf(fid,'------------------------\n');
for i=1:height(PS)
    fprintf(fid,[ ...
        '%s %s: globalPareto=%d/%d minMedianE=%g ' ...
        'maxSuccess=%g maxFeasibleFrac=%g\n'], ...
        PS.aperture_mode{i},PS.peak_semantics{i}, ...
        PS.n_global_pareto_points(i), ...
        PS.n_operating_points(i), ...
        PS.minimum_median_error(i), ...
        PS.maximum_weak_stage_success(i), ...
        PS.maximum_E_le_1_trial_fraction(i));
end

fprintf(fid,'\nRecoverability floor: representative half-bin entries\n');
fprintf(fid,'----------------------------------------------------\n');
M = F(abs(F.fractional_bin_offset-0.5)<1e-12,:);
for i=1:height(M)
    fprintf(fid,[ ...
        '%s %s L=%d: L0=%g D0=%g rminMed=%g ' ...
        'rminRange=[%g,%g]\n'], ...
        M.aperture_mode{i},M.peak_semantics{i}, ...
        M.window_bins(i), ...
        M.median_zero_mismatch_strong_leak_L0(i), ...
        M.median_zero_mismatch_weak_loss_D0(i), ...
        M.median_recoverability_floor_rmin(i), ...
        M.minimum_recoverability_floor_rmin(i), ...
        M.maximum_recoverability_floor_rmin(i));
end

fprintf(fid,'\nDecision\n');
fprintf(fid,'--------\n');
for i=1:height(D)
    fprintf(fid,'%s -> %s | best coordinate=%s\n', ...
        D.aperture_mode{i}, ...
        D.decision_branch{i}, ...
        D.best_coordinate_for_strong_leak_collapse{i});
end

fprintf(fid,'\nInterpretation discipline\n');
fprintf(fid,'-------------------------\n');
fprintf(fid,['1) LocalMax is the legacy implementation, not asserted as the ' ...
    'authors'' exact private FindPeak semantics.\n']);
fprintf(fid,['2) ConnectedSupport and PlateauAware are implementation audits, ' ...
    'not retroactive claims about Wang 2023.\n']);
fprintf(fid,['3) Window-coordinate collapse is evaluated on the same actual ' ...
    'operators; PA5E does not create a new equal-Hz operator family.\n']);
fprintf(fid,['4) Pareto dominance replaces the arbitrary 90%% balanced-window ' ...
    'selection rule.\n']);
fprintf(fid,['5) E<=1 remains a diagnostic waveform-feasibility threshold, not ' ...
    'a universal task-performance threshold.\n']);
fprintf(fid,['6) A nonzero rmin that survives tie-safe semantics is evidence ' ...
    'for a genuine fence-aware recoverability floor in this bridge.\n']);
fprintf(fid,['7) Noise remains OFF until this audit is closed.\n']);

fclose(fid);

end

%% ========================================================================
function make_figures( ...
    out_path,cfg,store,lambda,R0, ...
    aw,beta_w,O,A,P,F,C,S)

modes = ["Paper1s","BeamDerived"];
sems = cfg.peak_semantics;

%% Fig 1 — representative half-bin mask semantics
mode = string(cfg.figure_case_aperture);
N = store.(char(mode)).N;

eta = cfg.figure_case_eta;
b = eta/N;

dv = cfg.figure_case_delta_velocity_mps;

if strcmpi(cfg.figure_case_side,'HighV')
    vs = cfg.weak_velocity_mps+dv;
else
    vs = cfg.weak_velocity_mps-dv;
end

[~,~,Ks] = residual_fm_rates( ...
    vs,R0,lambda,cfg);

as = Ks/(cfg.prf_hz^2);

s0 = synth_discrete_lfm(N,1,as,b,0);
Y = matched_lfm_transform(s0,as);

amp = abs(Y);
amp = amp/max(amp);

dc = floor(N/2)+1;
center = round(dc+eta);

idx = max(1,center-8):min(N,center+8);
xrel = idx-dc;

fig = figure('Visible',cfg.figure_visible);
hold on;

plot(xrel,amp(idx),'o-','LineWidth',1.2);

base = [1.08,1.15,1.22];

for is = 1:numel(sems)

    [mask,~] = build_semantic_mask( ...
        Y,cfg.figure_case_window_bins, ...
        sems(is),cfg);

    yy = nan(size(idx));
    yy(mask(idx)) = base(is);

    plot(xrel,yy,'s','LineWidth',1.4);
end

yline(cfg.frac_domain_peak_gate,'--');

xlabel('Focused transform bin relative to DC');
ylabel('Normalized magnitude / mask markers');
title('EXP009 PA5E — Half-Bin Peak-Semantics Audit');
legend({'Focused strong magnitude', ...
        'LocalMax mask', ...
        'ConnectedSupport mask', ...
        'PlateauAware mask', ...
        '0.7 gate'}, ...
       'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig01_halfbin_peak_semantics_masks.png'), ...
    'Resolution',180);
close(fig);

%% Fig 2 — half-bin L=1 rmin across semantics
fig = figure('Visible',cfg.figure_visible);
hold on;

for im = 1:numel(modes)

    vals = nan(size(sems));

    for is = 1:numel(sems)

        M = F( ...
            string(F.aperture_mode)==modes(im) & ...
            abs(F.fractional_bin_offset-0.5)<1e-12 & ...
            string(F.peak_semantics)==sems(is) & ...
            F.window_bins==1,:);

        vals(is) = M.median_recoverability_floor_rmin;
    end

    plot(1:numel(sems),vals,'o-','LineWidth',1.3);
end

xticks(1:numel(sems));
xticklabels(sems);
ylabel('Median zero-mismatch r_{min}');
title('EXP009 PA5E — Half-Bin Recoverability Floor vs Peak Semantics');
legend(modes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig02_halfbin_rmin_vs_peak_semantics.png'), ...
    'Resolution',180);
close(fig);

%% Fig 3 — Beam half-bin global Pareto front
fig = figure('Visible',cfg.figure_visible);
hold on;

M = A( ...
    string(A.aperture_mode)=="BeamDerived" & ...
    abs(A.fractional_bin_offset-0.5)<1e-12,:);

h = gobjects(numel(sems)+2,1);

for is = 1:numel(sems)

    Q = M(string(M.peak_semantics)==sems(is),:);

    h(is) = scatter( ...
        Q.median_practical_error_ratio, ...
        Q.weak_stage_success_rate,55,'filled');
end

PF = P( ...
    string(P.aperture_mode)=="BeamDerived" & ...
    abs(P.fractional_bin_offset-0.5)<1e-12,:);

[~,ord] = sort(PF.median_practical_error_ratio);
PF = PF(ord,:);

h(numel(sems)+1) = plot( ...
    PF.median_practical_error_ratio, ...
    PF.weak_stage_success_rate, ...
    'k--','LineWidth',1.4);

h(numel(sems)+2) = xline(1,':');

xlabel('Median ||r-w||/||w||');
ylabel('Weak-stage success rate');
title('EXP009 PA5E — Half-Bin Pareto Front (BeamDerived)');

legend_labels = [ ...
    cellstr(sems(:)); ...
    {'Global Pareto front'}; ...
    {'E=1'}];

legend(h,legend_labels,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig03_halfbin_pareto_front_beam.png'), ...
    'Resolution',180);
close(fig);

%% Fig 4 — minimum achievable median error vs eta by semantics
fig = figure('Visible',cfg.figure_visible);
hold on;

for is = 1:numel(sems)

    yy = nan(size(cfg.fractional_bin_offsets));

    for io = 1:numel(cfg.fractional_bin_offsets)

        eta = cfg.fractional_bin_offsets(io);

        M = O( ...
            string(O.aperture_mode)=="BeamDerived" & ...
            abs(O.fractional_bin_offset-eta)<1e-12 & ...
            string(O.peak_semantics)==sems(is),:);

        yy(io) = min(M.median_practical_error_ratio);
    end

    plot(cfg.fractional_bin_offsets, ...
        yy,'o-','LineWidth',1.3);
end

xlabel('Focused fractional-bin offset |\eta|');
ylabel('Minimum median residual error over l');
title('EXP009 PA5E — Best Error Achievable Without Balanced Rule');
legend(sems,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig04_minimum_error_vs_fence_semantics.png'), ...
    'Resolution',180);
close(fig);

%% Fig 5 — maximum success vs eta by semantics
fig = figure('Visible',cfg.figure_visible);
hold on;

for is = 1:numel(sems)

    yy = nan(size(cfg.fractional_bin_offsets));

    for io = 1:numel(cfg.fractional_bin_offsets)

        eta = cfg.fractional_bin_offsets(io);

        M = O( ...
            string(O.aperture_mode)=="BeamDerived" & ...
            abs(O.fractional_bin_offset-eta)<1e-12 & ...
            string(O.peak_semantics)==sems(is),:);

        yy(io) = max(M.weak_stage_success_rate);
    end

    plot(cfg.fractional_bin_offsets, ...
        yy,'o-','LineWidth',1.3);
end

xlabel('Focused fractional-bin offset |\eta|');
ylabel('Maximum weak-stage success over l');
title('EXP009 PA5E — Maximum Weak Recovery vs Fence Effect');
legend(sems,'Location','best');
ylim([0 1]);
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig05_maximum_success_vs_fence_semantics.png'), ...
    'Resolution',180);
close(fig);

%% Fig 6 — coordinate-collapse robustness for strong leakage
M = C(string(C.metric)=="median_strong_leak_ratio",:);

coords = unique(string(M.coordinate),'stable');
Y = nan(numel(coords),1);

for ic = 1:numel(coords)
    Y(ic) = M.median_normalized_rmse( ...
        string(M.coordinate)==coords(ic));
end

fig = figure('Visible',cfg.figure_visible);

bar(Y);
xticks(1:numel(coords));
xticklabels(coords);
ylabel('Median normalized Paper/Beam RMSE');
title('EXP009 PA5E — Window-Coordinate Collapse for Strong Leakage');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig06_coordinate_collapse_strong_leak.png'), ...
    'Resolution',180);
close(fig);

%% Fig 7 — half-bin leakage/loss plane, Beam
fig = figure('Visible',cfg.figure_visible);
hold on;

M = O( ...
    string(O.aperture_mode)=="BeamDerived" & ...
    abs(O.fractional_bin_offset-0.5)<1e-12,:);

for is = 1:numel(sems)

    Q = M(string(M.peak_semantics)==sems(is),:);

    scatter(Q.median_strong_leak_ratio, ...
        Q.median_weak_projection_loss_ratio, ...
        55,'filled');

    for k = 1:height(Q)
        text(Q.median_strong_leak_ratio(k), ...
            Q.median_weak_projection_loss_ratio(k), ...
            sprintf(' %d',Q.window_bins(k)), ...
            'FontSize',8);
    end
end

xlabel('Median strong leakage L_s');
ylabel('Median weak projection loss D_w');
title('EXP009 PA5E — Half-Bin Leakage/Loss Operating Points');
legend(sems,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig07_halfbin_leakage_loss_operating_points.png'), ...
    'Resolution',180);
close(fig);

%% Fig 8 — half-bin floor map: semantics x window, Beam
Z = nan(numel(sems),numel(cfg.filter_window_length_bins));

for is = 1:numel(sems)

    for iw = 1:numel(cfg.filter_window_length_bins)

        M = F( ...
            string(F.aperture_mode)=="BeamDerived" & ...
            abs(F.fractional_bin_offset-0.5)<1e-12 & ...
            string(F.peak_semantics)==sems(is) & ...
            F.window_bins== ...
                cfg.filter_window_length_bins(iw),:);

        Z(is,iw) = M.median_recoverability_floor_rmin;
    end
end

fig = figure('Visible',cfg.figure_visible);

imagesc(cfg.filter_window_length_bins, ...
    1:numel(sems),Z);

set(gca,'YDir','normal');
yticks(1:numel(sems));
yticklabels(sems);
colorbar;

xlabel('Window length l (bins)');
ylabel('Peak semantics');
title('EXP009 PA5E — Half-Bin Recoverability Floor r_{min}');

exportgraphics(fig, ...
    fullfile(out_path,'fig08_halfbin_rmin_map_beam.png'), ...
    'Resolution',180);
close(fig);

end
