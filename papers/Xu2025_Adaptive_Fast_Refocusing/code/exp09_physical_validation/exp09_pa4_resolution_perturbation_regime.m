function results = exp09_pa4_resolution_perturbation_regime()
%EXP09_PA4_PHYSICAL_TWO_COMPONENT_RESOLUTION_PERTURBATION_REGIME
% EXP009 / Physical Validation Track / PA4
%
% Physical Two-Component Resolution-Perturbation Regime Validation
%
% Background
% ----------
% P0: Xu velocity->ORO scale/convention calibrated.
% P1: Wang velocity->residual-FM mapping validated.
% P1B: Wang-like short apertures do not robustly resolve five components.
% P1C: even ideal incoherent auto energy is unresolved; b_i/cross-term
%      suppression does not restore five peaks.
%
% Therefore PA4 does NOT assume that an isolated weak peak always exists.
%
% Research question
% -----------------
% How does a two-component strong/weak FrAc landscape change as the
% physical separation crosses the intrinsic response-width boundary?
%
% The dimensionless coordinate is:
%
%       Gamma = |beta_s - beta_w| / W_beta,weak
%
% where W_beta,weak is the isolated weak-component 3-dB FrAc width under
% the current aperture mode.
%
% Three diagnostic regimes are allowed to emerge:
%
%   Gamma < 0.5:
%       resolution-limited / merged-response regime
%
%   0.5 <= Gamma < 1.5:
%       partially resolved / non-perturbative interaction regime
%
%   Gamma >= 1.5:
%       resolved / perturbative peak-shift candidate regime
%
% The numerical boundaries are only analysis labels; the measured
% transition is determined from peak topology and first-order validity.
%
% Physical setup
% --------------
% Weak velocity is fixed at 15 m/s.
% Strong velocity is mirrored in velocity:
%
%       v_s = v_w +/- Delta v
%
% Delta v = [2.5,5,7.5,10,15,20] m/s.
%
% Strong amplitude = 1.
% Weak/strong amplitude ratio is swept.
% Relative phase is swept over [0,2pi).
%
% No noise. No CLEAN.
%
% FrAc energy
% -----------
% For x = s + r*exp(jphi)*w, precompute lag/beta responses:
%
%   R_ss, R_ww, R_sw, R_ws
%
% and assemble:
%
%   R_total =
%       R_ss
%     + r^2 R_ww
%     + r exp(-jphi) R_sw
%     + r exp(+jphi) R_ws.
%
% Then:
%
%   P(beta) = sum_k |R_total(beta,k)|^2.
%
% First-order weak-peak shift
% ---------------------------
% In cases where a weak-associated total peak exists:
%
%   delta_beta_pred =
%       - DeltaP'(beta_w) / P_w''(beta_w)
%
% with:
%
%   P_w = energy of the weak-only response,
%   DeltaP = P_total - P_w.
%
% The first-order law is NOT forced onto merged cases.
%
% Run:
%   results = ...
%       exp09_pa4_resolution_perturbation_regime;

cfg = config_exp09_pa4_resolution_perturbation_regime();

%% Output path
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.output_dir)
    out_path = fullfile( ...
        paper_root,'results','exp09_physical_validation', ...
        'exp09_pa4_physical_two_component_resolution_perturbation_regime');
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

[~,K_SAR,Kw] = residual_fm_rates(vw,R0,lambda,cfg);
aw = Kw/(cfg.prf_hz^2);
beta_w = atan(aw);

%% Aperture definitions
T_paper = cfg.paper_aperture_time_s;
N_paper = max(32,round(cfg.prf_hz*T_paper));

T_beam = R0*beamwidth_rad/cfg.platform_velocity_mps;
N_beam = max(32,round(cfg.prf_hz*T_beam));

aperture_names = ["Paper1s","BeamDerived"];
N_list = [N_paper,N_beam];
T_target_list = [T_paper,T_beam];

%% Calibrate intrinsic weak-only width per aperture
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

    sw = synth_discrete_lfm( ...
        N,1,aw,cfg.center_frequency_cycles_per_sample,0);

    Rww = pair_frac_response( ...
        sw,sw,beta_grid_width,max_lag,cfg);

    Pweak_unit = sum(abs(Rww).^2,2);

    Wbeta = estimate_3db_width( ...
        beta_grid_width,Pweak_unit,beta_w);

    if ~isfinite(Wbeta) || Wbeta<=0
        error('Could not estimate weak-only 3-dB width for %s.',mode);
    end

    width_rows(end+1,:) = { ... %#ok<AGROW>
        char(mode),N,T_target,T_actual,max_lag,Wbeta};

    width_store.(char(mode)) = struct( ...
        'N',N,'T_target',T_target,'T_actual',T_actual, ...
        'max_lag',max_lag,'Wbeta',Wbeta, ...
        'beta_grid',beta_grid_width, ...
        'Pweak_unit',normalize_curve(Pweak_unit));
end

width_table = cell2table(width_rows, ...
    'VariableNames',{ ...
    'aperture_mode','azimuth_samples', ...
    'target_aperture_time_s','actual_observation_time_s', ...
    'max_frac_lag','weak_single_3db_width_beta_rad'});

writetable(width_table, ...
    fullfile(out_path,'pa4_intrinsic_width_calibration.csv'));

%% Main physical two-component sweep
rows = {};
curve_store = struct();
row = 0;

sides = ["LowV","HighV"];

for ia = 1:2

    mode = aperture_names(ia);
    Wbeta = width_store.(char(mode)).Wbeta;
    N = width_store.(char(mode)).N;
    max_lag = width_store.(char(mode)).max_lag;

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

            sw0 = synth_discrete_lfm( ...
                N,1,aw,cfg.center_frequency_cycles_per_sample,0);

            ss0 = synth_discrete_lfm( ...
                N,1,as,cfg.center_frequency_cycles_per_sample,0);

            % Pair-response basis.
            Rss = pair_frac_response( ...
                ss0,ss0,beta_grid,max_lag,cfg);

            Rww = pair_frac_response( ...
                sw0,sw0,beta_grid,max_lag,cfg);

            Rsw = pair_frac_response( ...
                ss0,sw0,beta_grid,max_lag,cfg);

            Rws = pair_frac_response( ...
                sw0,ss0,beta_grid,max_lag,cfg);

            Pstrong_unit = sum(abs(Rss).^2,2);
            Pweak_unit = sum(abs(Rww).^2,2);

            for ir = 1:numel(cfg.weak_to_strong_ratio)

                r = cfg.weak_to_strong_ratio(ir);

                % Weak-only baseline at actual amplitude.
                Pw = (r^4)*Pweak_unit;

                for ip = 1:numel(cfg.relative_phase_rad)

                    phi = cfg.relative_phase_rad(ip);

                    Rtotal = ...
                        Rss + ...
                        (r^2)*Rww + ...
                        r*exp(-1j*phi)*Rsw + ...
                        r*exp(+1j*phi)*Rws;

                    Ptotal = sum(abs(Rtotal).^2,2);
                    Pdelta = Ptotal-Pw;

                    Pnorm = normalize_curve(Ptotal);

                    peaks = local_peaks_with_prominence( ...
                        beta_grid,Pnorm, ...
                        cfg.min_peak_prominence_fraction);

                    [weak_found,weak_peak,weak_peak_prom] = ...
                        associate_peak( ...
                            peaks,beta_w,beta_sep,Wbeta,cfg);

                    [strong_found,strong_peak,strong_peak_prom] = ...
                        associate_peak( ...
                            peaks,beta_s,beta_sep,Wbeta,cfg);

                    two_component_resolved = ...
                        weak_found && strong_found && ...
                        abs(weak_peak-strong_peak)> ...
                            0.25*max(beta_sep,eps);

                    if weak_found
                        weak_shift = weak_peak-beta_w;
                        weak_shift_norm = weak_shift/Wbeta;
                    else
                        weak_shift = NaN;
                        weak_shift_norm = NaN;
                    end

                    if strong_found
                        strong_shift = strong_peak-beta_s;
                    else
                        strong_shift = NaN;
                    end

                    % First-order prediction around the weak-only peak.
                    h = median(diff(beta_grid));

                    [Pw_dd,Pdelta_d] = local_derivatives( ...
                        beta_grid,Pw,Pdelta,beta_w,h);

                    if isfinite(Pw_dd) && Pw_dd<0 && ...
                            isfinite(Pdelta_d) && abs(Pw_dd)>eps

                        shift_pred = -Pdelta_d/Pw_dd;
                    else
                        shift_pred = NaN;
                    end

                    firstorder_valid = ...
                        weak_found && ...
                        isfinite(shift_pred) && ...
                        abs(shift_pred) <= ...
                            cfg.firstorder_max_abs_shift_widths*Wbeta;

                    perturbative_case = ...
                        firstorder_valid && ...
                        abs(weak_shift) <= ...
                            cfg.perturbative_measured_shift_widths*Wbeta;

                    row = row+1;

                    rows(end+1,:) = { ... %#ok<AGROW>
                        char(mode),N, ...
                        dv,char(side), ...
                        vw,vs, ...
                        beta_w,beta_s,beta_sep,Wbeta,Gamma,char(regime), ...
                        r,phi, ...
                        numel(peaks.beta), ...
                        double(weak_found), ...
                        double(strong_found), ...
                        double(two_component_resolved), ...
                        weak_peak,strong_peak, ...
                        weak_peak_prom,strong_peak_prom, ...
                        weak_shift,weak_shift_norm,strong_shift, ...
                        shift_pred, ...
                        double(firstorder_valid), ...
                        double(perturbative_case)};
                end
            end

            % Save a small set of representative curves:
            % r=0.3, phi=0 for each geometry.
            rrep = 0.30;
            phirep = 0;

            Rrep = ...
                Rss + ...
                (rrep^2)*Rww + ...
                rrep*Rsw + ...
                rrep*Rws;

            Prep = sum(abs(Rrep).^2,2);

            key = sprintf('A%d_D%d_S%d',ia,idv,iside);

            curve_store.(key) = struct( ...
                'mode',mode,'dv',dv,'side',side, ...
                'vs',vs,'beta_s',beta_s,'beta_w',beta_w, ...
                'Gamma',Gamma,'Wbeta',Wbeta, ...
                'beta_grid',beta_grid, ...
                'Ptotal',normalize_curve(Prep), ...
                'Pweak',normalize_curve((rrep^4)*Pweak_unit), ...
                'Pstrong',normalize_curve(Pstrong_unit));
        end
    end
end

trial_table = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','azimuth_samples', ...
    'delta_velocity_mps','strong_velocity_side', ...
    'weak_velocity_mps','strong_velocity_mps', ...
    'beta_weak_rad','beta_strong_rad', ...
    'beta_separation_rad','weak_3db_width_rad', ...
    'Gamma_sep_over_width','Gamma_regime', ...
    'weak_to_strong_ratio','relative_phase_rad', ...
    'observable_peak_count', ...
    'weak_peak_found','strong_peak_found', ...
    'two_component_resolved', ...
    'weak_peak_beta_rad','strong_peak_beta_rad', ...
    'weak_peak_prominence','strong_peak_prominence', ...
    'weak_shift_rad','weak_shift_over_width', ...
    'strong_shift_rad', ...
    'firstorder_predicted_weak_shift_rad', ...
    'firstorder_valid','perturbative_case'});

writetable(trial_table, ...
    fullfile(out_path,'pa4_trial_results.csv'));

%% Summaries
regime_summary = summarize_regimes(trial_table,cfg);
firstorder_summary = summarize_firstorder(trial_table,cfg);
mirror_summary = summarize_mirror(trial_table,cfg);
decision_summary = build_decision_summary( ...
    trial_table,regime_summary,firstorder_summary,mirror_summary,cfg);

writetable(regime_summary, ...
    fullfile(out_path,'pa4_regime_summary.csv'));
writetable(firstorder_summary, ...
    fullfile(out_path,'pa4_firstorder_summary.csv'));
writetable(mirror_summary, ...
    fullfile(out_path,'pa4_mirror_summary.csv'));
writetable(decision_summary, ...
    fullfile(out_path,'pa4_decision_summary.csv'));

%% Summary text
write_summary( ...
    out_path,cfg,lambda,R0,beamwidth_rad, ...
    width_table,regime_summary,firstorder_summary, ...
    mirror_summary,decision_summary);

%% Figures
make_figures( ...
    out_path,cfg,trial_table,width_table, ...
    firstorder_summary,mirror_summary,curve_store);

%% Save
results = struct();
results.cfg = cfg;
results.lambda = lambda;
results.R0 = R0;
results.beamwidth_rad = beamwidth_rad;
results.width_table = width_table;
results.trial_table = trial_table;
results.regime_summary = regime_summary;
results.firstorder_summary = firstorder_summary;
results.mirror_summary = mirror_summary;
results.decision_summary = decision_summary;
results.curve_store = curve_store;

save(fullfile(out_path,'exp09_pa4_results.mat'), ...
    'results','-v7.3');

%% Console
fprintf('\n============================================================\n');
fprintf(' EXP009 PA4 / Physical Resolution-Perturbation Regimes\n');
fprintf('============================================================\n');
disp(width_table);
disp(regime_summary);
disp(firstorder_summary);
disp(mirror_summary);
disp(decision_summary);
fprintf('============================================================\n\n');

fprintf('Saved PA4 outputs to:\n%s\n\n',out_path);

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
function x = synth_discrete_lfm(N,A,a,b,phi)
% Wang Eq. (13)-compatible discrete LFM.

m = 0:N-1;

x = A.*exp(1j*2*pi*( ...
    0.5*a*m.^2 + b*m) + 1j*phi);

x = x(:).';

end

%% ========================================================================
function R = pair_frac_response( ...
    x_left,x_right,beta_grid,max_lag,cfg)
%PAIR_FRAC_RESPONSE
% Complex lag-beta response for:
%
%   x_left[m+k] * conj(x_right[m])
%
% evaluated at nu = k*tan(beta).

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

% Prefer the closest peak; use prominence as a tie-breaker.
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
function [Pw_dd,Pdelta_d] = local_derivatives( ...
    beta_grid,Pw,Pdelta,beta0,h)

bminus = beta0-h;
bplus = beta0+h;

if bminus<beta_grid(1) || bplus>beta_grid(end)
    Pw_dd = NaN;
    Pdelta_d = NaN;
    return;
end

Pw_m = interp1(beta_grid,Pw,bminus,'pchip');
Pw_0 = interp1(beta_grid,Pw,beta0,'pchip');
Pw_p = interp1(beta_grid,Pw,bplus,'pchip');

Pd_m = interp1(beta_grid,Pdelta,bminus,'pchip');
Pd_p = interp1(beta_grid,Pdelta,bplus,'pchip');

Pw_dd = (Pw_p-2*Pw_0+Pw_m)/(h^2);
Pdelta_d = (Pd_p-Pd_m)/(2*h);

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
function S = summarize_regimes(T,cfg)

modes = unique(string(T.aperture_mode),'stable');
regimes = ["Unresolved","Partial","ResolvedCandidate"];

rows = {};

for im = 1:numel(modes)
    mode = modes(im);

    for ir = 1:numel(regimes)
        reg = regimes(ir);

        Tr = T( ...
            string(T.aperture_mode)==mode & ...
            string(T.Gamma_regime)==reg,:);

        if isempty(Tr)
            rows(end+1,:) = { ... %#ok<AGROW>
                char(mode),char(reg),0, ...
                NaN,NaN,NaN,NaN,NaN,NaN};
            continue;
        end

        weak_found_rate = mean(Tr.weak_peak_found);
        resolved_rate = mean(Tr.two_component_resolved);
        perturbative_rate = mean(Tr.perturbative_case);

        abs_shift = abs(Tr.weak_shift_over_width);
        abs_shift = abs_shift(isfinite(abs_shift));

        if isempty(abs_shift)
            med_abs_shift = NaN;
            q90_abs_shift = NaN;
        else
            med_abs_shift = median(abs_shift);
            q90_abs_shift = percentile_local(abs_shift,90);
        end

        rows(end+1,:) = { ... %#ok<AGROW>
            char(mode),char(reg),height(Tr), ...
            median(Tr.Gamma_sep_over_width), ...
            weak_found_rate,resolved_rate,perturbative_rate, ...
            med_abs_shift,q90_abs_shift};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','Gamma_regime','n', ...
    'median_Gamma', ...
    'weak_peak_found_rate', ...
    'two_component_resolved_rate', ...
    'perturbative_case_rate', ...
    'median_abs_weak_shift_over_width', ...
    'p90_abs_weak_shift_over_width'});

end

%% ========================================================================
function S = summarize_firstorder(T,cfg)

modes = unique(string(T.aperture_mode),'stable');
subsets = ["AllValid","PerturbativeOnly","ResolvedCandidate"];

rows = {};

for im = 1:numel(modes)
    mode = modes(im);

    Tm = T(string(T.aperture_mode)==mode,:);

    for is = 1:numel(subsets)

        subset = subsets(is);

        switch subset
            case "AllValid"
                mm = logical(Tm.firstorder_valid);

            case "PerturbativeOnly"
                mm = logical(Tm.perturbative_case);

            case "ResolvedCandidate"
                mm = ...
                    logical(Tm.firstorder_valid) & ...
                    string(Tm.Gamma_regime)=="ResolvedCandidate";

            otherwise
                error('Unknown first-order subset.');
        end

        x = Tm.weak_shift_rad(mm);
        y = Tm.firstorder_predicted_weak_shift_rad(mm);

        valid = isfinite(x) & isfinite(y);
        x = x(valid);
        y = y(valid);

        n = numel(x);

        if n>=cfg.min_firstorder_samples
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
            char(mode),char(subset),n, ...
            pearson_r,spearman_r, ...
            slope,intercept,rmse,signagree};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','subset','n', ...
    'pearson_r','spearman_r', ...
    'fit_slope_pred_vs_measured','fit_intercept', ...
    'prediction_rmse','sign_agreement'});

end

%% ========================================================================
function S = summarize_mirror(T,cfg)

modes = unique(string(T.aperture_mode),'stable');
dvs = unique(T.delta_velocity_mps).';

rows = {};

for im = 1:numel(modes)
    mode = modes(im);

    for idv = 1:numel(dvs)
        dv = dvs(idv);

        L = T( ...
            string(T.aperture_mode)==mode & ...
            T.delta_velocity_mps==dv & ...
            string(T.strong_velocity_side)=="LowV",:);

        H = T( ...
            string(T.aperture_mode)==mode & ...
            T.delta_velocity_mps==dv & ...
            string(T.strong_velocity_side)=="HighV",:);

        L = sortrows(L,{ ...
            'weak_to_strong_ratio','relative_phase_rad'});
        H = sortrows(H,{ ...
            'weak_to_strong_ratio','relative_phase_rad'});

        if height(L)~=height(H)
            error('Mirror pair count mismatch.');
        end

        valid = ...
            isfinite(L.weak_shift_rad) & ...
            isfinite(H.weak_shift_rad);

        x = L.weak_shift_rad(valid);
        y = H.weak_shift_rad(valid);

        n = numel(x);

        if n>0
            sign_flip = mean( ...
                sign(x)==-sign(y));

            mag_ratio = median( ...
                abs(x)./max(abs(y),eps));

            antisym_error = median( ...
                abs(x+y) ./ ...
                max(0.5*(abs(x)+abs(y)),eps));
        else
            sign_flip = NaN;
            mag_ratio = NaN;
            antisym_error = NaN;
        end

        gamma_low = median(L.Gamma_sep_over_width);
        gamma_high = median(H.Gamma_sep_over_width);

        rows(end+1,:) = { ... %#ok<AGROW>
            char(mode),dv,n, ...
            gamma_low,gamma_high, ...
            sign_flip,mag_ratio,antisym_error};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','delta_velocity_mps', ...
    'n_valid_mirror_pairs', ...
    'Gamma_lowV','Gamma_highV', ...
    'mirror_shift_sign_flip_rate', ...
    'median_abs_shift_magnitude_ratio_low_over_high', ...
    'median_normalized_antisymmetry_error'});

end

%% ========================================================================
function D = build_decision_summary( ...
    T,regime_summary,firstorder_summary,mirror_summary,cfg)

modes = unique(string(T.aperture_mode),'stable');
rows = {};

for im = 1:numel(modes)
    mode = modes(im);

    Tm = T(string(T.aperture_mode)==mode,:);

    high = Tm( ...
        string(Tm.Gamma_regime)=="ResolvedCandidate",:);

    if isempty(high)
        high_resolved_rate = NaN;
    else
        high_resolved_rate = mean(high.two_component_resolved);
    end

    FO = firstorder_summary( ...
        strcmp(firstorder_summary.aperture_mode,char(mode)) & ...
        strcmp(firstorder_summary.subset,'ResolvedCandidate'),:);

    if isempty(FO)
        fo_r = NaN;
        fo_sign = NaN;
    else
        fo_r = FO.pearson_r(1);
        fo_sign = FO.sign_agreement(1);
    end

    M = mirror_summary( ...
        strcmp(mirror_summary.aperture_mode,char(mode)),:);

    valid_m = isfinite(M.mirror_shift_sign_flip_rate);

    if any(valid_m)
        mirror_sign = median( ...
            M.mirror_shift_sign_flip_rate(valid_m));
    else
        mirror_sign = NaN;
    end

    low = regime_summary( ...
        strcmp(regime_summary.aperture_mode,char(mode)) & ...
        strcmp(regime_summary.Gamma_regime,'Unresolved'),:);

    partial = regime_summary( ...
        strcmp(regime_summary.aperture_mode,char(mode)) & ...
        strcmp(regime_summary.Gamma_regime,'Partial'),:);

    if isempty(low)
        low_resolved_rate = NaN;
    else
        low_resolved_rate = low.two_component_resolved_rate(1);
    end

    if isempty(partial)
        partial_resolved_rate = NaN;
    else
        partial_resolved_rate = partial.two_component_resolved_rate(1);
    end

    if isfinite(high_resolved_rate) && ...
            high_resolved_rate>=cfg.high_gamma_resolved_rate_gate

        if isfinite(fo_r) && fo_r>=cfg.firstorder_corr_gate
            branch = "RESOLUTION_TO_PERTURBATIVE_TRANSITION";
        else
            branch = "RESOLVED_BUT_NONPERTURBATIVE_INTERACTION";
        end

    elseif any(Tm.two_component_resolved)
        branch = "PARTIAL_RESOLUTION_ONLY";
    else
        branch = "RESOLUTION_LIMITED_OVER_TESTED_RANGE";
    end

    rows(end+1,:) = { ... %#ok<AGROW>
        char(mode),char(branch), ...
        low_resolved_rate,partial_resolved_rate, ...
        high_resolved_rate, ...
        fo_r,fo_sign,mirror_sign};
end

D = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','decision_branch', ...
    'unresolved_regime_resolved_rate', ...
    'partial_regime_resolved_rate', ...
    'resolved_candidate_resolved_rate', ...
    'resolved_candidate_firstorder_pearson', ...
    'resolved_candidate_firstorder_sign_agreement', ...
    'median_mirror_shift_sign_flip_rate'});

end

%% ========================================================================
function write_summary( ...
    out_path,cfg,lambda,R0,beamwidth_rad, ...
    width_table,regime_summary,firstorder_summary, ...
    mirror_summary,decision_summary)

fid = fopen(fullfile(out_path,'summary.txt'),'w');

fprintf(fid,'EXP009 PA4 / Physical Two-Component Resolution-Perturbation Regime Validation\n');
fprintf(fid,'============================================================================\n\n');

fprintf(fid,'Research question\n');
fprintf(fid,'-----------------\n');
fprintf(fid,['How does strong-weak interaction change as physical ' ...
    'component separation crosses the intrinsic FrAc resolution boundary?\n\n']);

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

fprintf(fid,'Controlled two-component sweep\n');
fprintf(fid,'------------------------------\n');
fprintf(fid,'weak velocity = %.6g m/s\n',cfg.weak_velocity_mps);
fprintf(fid,'Delta v = %s m/s\n',mat2str(cfg.delta_velocity_mps));
fprintf(fid,'A_w/A_s = %s\n',mat2str(cfg.weak_to_strong_ratio));
fprintf(fid,'relative phases = %d equally spaced values on [0,2pi)\n', ...
    cfg.num_relative_phases);
fprintf(fid,'b_s=b_w=0\n');
fprintf(fid,'No noise. No CLEAN.\n\n');

fprintf(fid,'Intrinsic weak-response widths\n');
fprintf(fid,'------------------------------\n');
for i = 1:height(width_table)
    fprintf(fid,[ ...
        '%s N=%d T=%.6f s W_beta_3dB=%g rad\n'], ...
        width_table.aperture_mode{i}, ...
        width_table.azimuth_samples(i), ...
        width_table.actual_observation_time_s(i), ...
        width_table.weak_single_3db_width_beta_rad(i));
end

fprintf(fid,'\nRegime summary\n');
fprintf(fid,'--------------\n');
for i = 1:height(regime_summary)
    fprintf(fid,[ ...
        '%s %-18s n=%d medGamma=%g weakFound=%.4f resolved=%.4f ' ...
        'perturbative=%.4f med|shift|/W=%g p90=%g\n'], ...
        regime_summary.aperture_mode{i}, ...
        regime_summary.Gamma_regime{i}, ...
        regime_summary.n(i), ...
        regime_summary.median_Gamma(i), ...
        regime_summary.weak_peak_found_rate(i), ...
        regime_summary.two_component_resolved_rate(i), ...
        regime_summary.perturbative_case_rate(i), ...
        regime_summary.median_abs_weak_shift_over_width(i), ...
        regime_summary.p90_abs_weak_shift_over_width(i));
end

fprintf(fid,'\nFirst-order validation\n');
fprintf(fid,'----------------------\n');
for i = 1:height(firstorder_summary)
    fprintf(fid,[ ...
        '%s %-18s n=%d Pearson=%g slope=%g RMSE=%g sign=%g\n'], ...
        firstorder_summary.aperture_mode{i}, ...
        firstorder_summary.subset{i}, ...
        firstorder_summary.n(i), ...
        firstorder_summary.pearson_r(i), ...
        firstorder_summary.fit_slope_pred_vs_measured(i), ...
        firstorder_summary.prediction_rmse(i), ...
        firstorder_summary.sign_agreement(i));
end

fprintf(fid,'\nMirror validation\n');
fprintf(fid,'-----------------\n');
for i = 1:height(mirror_summary)
    fprintf(fid,[ ...
        '%s dv=%g GammaLow=%g GammaHigh=%g n=%d ' ...
        'signFlip=%g magRatio=%g antiErr=%g\n'], ...
        mirror_summary.aperture_mode{i}, ...
        mirror_summary.delta_velocity_mps(i), ...
        mirror_summary.Gamma_lowV(i), ...
        mirror_summary.Gamma_highV(i), ...
        mirror_summary.n_valid_mirror_pairs(i), ...
        mirror_summary.mirror_shift_sign_flip_rate(i), ...
        mirror_summary.median_abs_shift_magnitude_ratio_low_over_high(i), ...
        mirror_summary.median_normalized_antisymmetry_error(i));
end

fprintf(fid,'\nDecision\n');
fprintf(fid,'--------\n');
for i = 1:height(decision_summary)
    fprintf(fid,[ ...
        '%s -> %s | resolvedRate low/partial/high=%g/%g/%g ' ...
        '| highGamma FO-r=%g FO-sign=%g mirrorSign=%g\n'], ...
        decision_summary.aperture_mode{i}, ...
        decision_summary.decision_branch{i}, ...
        decision_summary.unresolved_regime_resolved_rate(i), ...
        decision_summary.partial_regime_resolved_rate(i), ...
        decision_summary.resolved_candidate_resolved_rate(i), ...
        decision_summary.resolved_candidate_firstorder_pearson(i), ...
        decision_summary.resolved_candidate_firstorder_sign_agreement(i), ...
        decision_summary.median_mirror_shift_sign_flip_rate(i));
end

fprintf(fid,'\nInterpretation discipline\n');
fprintf(fid,'-------------------------\n');
fprintf(fid,['1) Do not call a case "NearShift" unless a weak-associated ' ...
    'observable total peak actually exists.\n']);
fprintf(fid,['2) Gamma is the primary separation coordinate; absolute beta/q ' ...
    'differences are secondary.\n']);
fprintf(fid,['3) First-order perturbation is evaluated only where a weak peak ' ...
    'exists and the predicted shift is locally bounded.\n']);
fprintf(fid,['4) Failure of old normalized A4 under physical parameters is a ' ...
    'valid result; do not tune parameters to preserve the old mechanism.\n']);
fprintf(fid,['5) PA4 is noiseless and pre-CLEAN. Noise/CLEAN are reintroduced ' ...
    'only after the physical topology is established.\n']);

fclose(fid);

end

%% ========================================================================
function make_figures( ...
    out_path,cfg,T,width_table,firstorder_summary, ...
    mirror_summary,curve_store)

%% Fig 1 — physical Delta-v to Gamma
fig = figure('Visible',cfg.figure_visible);
hold on;

modes = unique(string(T.aperture_mode),'stable');

for im = 1:numel(modes)
    mode = modes(im);

    for side = ["LowV","HighV"]
        Ts = T( ...
            string(T.aperture_mode)==mode & ...
            string(T.strong_velocity_side)==side,:);

        G = groupsummary( ...
            Ts,'delta_velocity_mps','median','Gamma_sep_over_width');

        plot( ...
            G.delta_velocity_mps, ...
            G.median_Gamma_sep_over_width, ...
            'o-','LineWidth',1.2);
    end
end

yline(cfg.gamma_unresolved_max,'--');
yline(cfg.gamma_partial_max,':');

xlabel('\Delta v (m/s)');
ylabel('\Gamma = |\Delta\beta| / W_{\beta,3dB}');
title('EXP009 PA4 — Physical Velocity Separation to Resolution Coordinate');
legend({ ...
    'Paper LowV','Paper HighV', ...
    'Beam LowV','Beam HighV', ...
    '\Gamma=0.5','\Gamma=1.5'}, ...
    'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig01_deltaV_to_Gamma.png'), ...
    'Resolution',180);
close(fig);

%% Fig 2 — resolved rate vs Gamma grouped by amplitude ratio
fig = figure('Visible',cfg.figure_visible);

ratios = cfg.weak_to_strong_ratio;
Y = nan(numel(ratios),2);

for ir = 1:numel(ratios)
    r = ratios(ir);

    for im = 1:2
        mode = modes(im);

        Tr = T( ...
            string(T.aperture_mode)==mode & ...
            abs(T.weak_to_strong_ratio-r)<1e-12,:);

        high = Tr.Gamma_sep_over_width>=cfg.gamma_partial_max;

        if any(high)
            Y(ir,im) = mean(Tr.two_component_resolved(high));
        end
    end
end

bar(ratios,Y);
ylim([0 1]);
xlabel('Weak / strong amplitude ratio');
ylabel('Resolved rate for \Gamma >= 1.5');
title('EXP009 PA4 — High-\Gamma Two-Component Resolvability');
legend(modes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig02_highGamma_resolved_rate.png'), ...
    'Resolution',180);
close(fig);

%% Fig 3 — weak shift magnitude vs Gamma
fig = figure('Visible',cfg.figure_visible);
hold on;

for im = 1:numel(modes)
    mode = modes(im);

    Tm = T( ...
        string(T.aperture_mode)==mode & ...
        isfinite(T.weak_shift_over_width),:);

    scatter( ...
        Tm.Gamma_sep_over_width, ...
        Tm.weak_shift_over_width, ...
        14,'filled');
end

xline(cfg.gamma_unresolved_max,'--');
xline(cfg.gamma_partial_max,':');
yline(0,'--');

xlabel('\Gamma');
ylabel('Weak peak shift / W_{\beta,3dB}');
title('EXP009 PA4 — Weak-Peak Displacement Across Resolution Regimes');
legend(modes,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig03_weak_shift_vs_Gamma.png'), ...
    'Resolution',180);
close(fig);

%% Fig 4 — first-order predicted vs measured
fig = figure('Visible',cfg.figure_visible);
hold on;

allvals = [];

for im = 1:numel(modes)
    mode = modes(im);

    Tm = T( ...
        string(T.aperture_mode)==mode & ...
        logical(T.firstorder_valid) & ...
        string(T.Gamma_regime)=="ResolvedCandidate",:);

    x = Tm.weak_shift_rad;
    y = Tm.firstorder_predicted_weak_shift_rad;

    valid = isfinite(x) & isfinite(y);

    scatter(x(valid),y(valid),16,'filled');

    allvals = [allvals;x(valid);y(valid)]; %#ok<AGROW>
end

if ~isempty(allvals)
    lo = min(allvals);
    hi = max(allvals);
    plot([lo hi],[lo hi],'--','LineWidth',1.0);
end

xlabel('Measured weak shift \Delta\beta');
ylabel('First-order predicted shift');
title('EXP009 PA4 — First-Order Validation in Resolved-Candidate Regime');
legend([cellstr(modes);{'y=x'}],'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig04_firstorder_scatter.png'), ...
    'Resolution',180);
close(fig);

%% Fig 5 — mirror sign-flip rate
fig = figure('Visible',cfg.figure_visible);
hold on;

for im = 1:numel(modes)
    mode = modes(im);
    M = mirror_summary( ...
        strcmp(mirror_summary.aperture_mode,char(mode)),:);

    plot( ...
        M.delta_velocity_mps, ...
        M.mirror_shift_sign_flip_rate, ...
        'o-','LineWidth',1.2);
end

yline(cfg.mirror_sign_gate,'--');

xlabel('\Delta v (m/s)');
ylabel('Mirror shift sign-flip rate');
title('EXP009 PA4 — Mirror Symmetry of Weak-Peak Shift');
legend([cellstr(modes);{'Diagnostic gate'}],'Location','best');
ylim([0 1]);
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig05_mirror_sign_flip.png'), ...
    'Resolution',180);
close(fig);

%% Fig 6-9 — representative landscapes
% Use Delta-v nearest 5 m/s and max tested Delta-v, HighV side.
dvs = cfg.delta_velocity_mps;
[~,id_small] = min(abs(dvs-5));
id_large = numel(dvs);

plot_landscape_case( ...
    curve_store.(sprintf('A1_D%d_S2',id_small)), ...
    fullfile(out_path,'fig06_paper_dv5_landscape.png'),cfg);

plot_landscape_case( ...
    curve_store.(sprintf('A1_D%d_S2',id_large)), ...
    fullfile(out_path,'fig07_paper_dvMax_landscape.png'),cfg);

plot_landscape_case( ...
    curve_store.(sprintf('A2_D%d_S2',id_small)), ...
    fullfile(out_path,'fig08_beam_dv5_landscape.png'),cfg);

plot_landscape_case( ...
    curve_store.(sprintf('A2_D%d_S2',id_large)), ...
    fullfile(out_path,'fig09_beam_dvMax_landscape.png'),cfg);

end

%% ========================================================================
function plot_landscape_case(S,filename,cfg)

fig = figure('Visible',cfg.figure_visible);

plot(S.beta_grid,S.Pstrong,'LineWidth',1.1);
hold on;
plot(S.beta_grid,S.Pweak,'LineWidth',1.1);
plot(S.beta_grid,S.Ptotal,'LineWidth',1.4);

xline(S.beta_w,':');
xline(S.beta_s,':');

xlabel('FrAc rotation angle \beta (rad)');
ylabel('Normalized energy');
title(sprintf( ...
    'EXP009 PA4 — %s, \\Delta v=%.1f m/s, %s, \\Gamma=%.2f', ...
    char(S.mode),S.dv,char(S.side),S.Gamma));

legend({'Strong-only','Weak-only','Two-component total'}, ...
    'Location','best');
grid on;

exportgraphics(fig,filename,'Resolution',180);
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
