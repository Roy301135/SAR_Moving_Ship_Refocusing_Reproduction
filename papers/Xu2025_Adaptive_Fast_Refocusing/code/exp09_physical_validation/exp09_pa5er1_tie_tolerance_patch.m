function results = exp09_pa5er1_tie_tolerance_patch()
%EXP09_PA5ER1_TIE_TOLERANCE_PATCH
% EXP009 / PA5E-R1
%
% Numerical Tie-Tolerance Patch
%
% Research question:
%
%   Did PA5E's PlateauAware result fail to separate from LocalMax merely
%   because exact floating-point comparisons did not recognize the
%   mathematically equal half-bin twin peak?
%
% This is a targeted archival patch, not a new research stage.
%
% It uses the true strong parameter and computes:
%
%   L0  = zero-mismatch strong leakage
%   D0  = zero-mismatch weak projection loss
%
%   r_min = L0 / sqrt(1-D0^2)
%
% under four peak semantics:
%
%   LocalMax
%   ConnectedSupport
%   PlateauAwareExact
%   PlateauAwareTol
%
% Run:
%   results = exp09_pa5er1_tie_tolerance_patch;

cfg = config_exp09_pa5er1_tie_tolerance_patch();

validate_config_complete(cfg);
run_semantics_self_test(cfg);

%% Output path
this_dir = fileparts(mfilename('fullpath'));
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.output_dir)
    out_path = fullfile( ...
        paper_root,'results','exp09_physical_validation', ...
        'exp09_pa5er1_tie_tolerance_patch');
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
    cfg.beamwidth_scale * ...
    lambda/cfg.antenna_length_m;

vw = cfg.weak_velocity_mps;

[~,~,Kw] = residual_fm_rates( ...
    vw,R0,lambda,cfg);

aw = Kw/(cfg.prf_hz^2);

%% Apertures
T_paper = cfg.paper_aperture_time_s;
N_paper = max(32,round(cfg.prf_hz*T_paper));

T_beam = ...
    R0*beamwidth_rad/cfg.platform_velocity_mps;
N_beam = max(32,round(cfg.prf_hz*T_beam));

aperture_names = ["Paper1s","BeamDerived"];
N_list = [N_paper,N_beam];

%% Main zero-mismatch floor sweep
rows = {};
sides = ["LowV","HighV"];

for ia = 1:numel(aperture_names)

    mode = aperture_names(ia);
    N = N_list(ia);

    for io = 1:numel(cfg.fractional_bin_offsets)

        eta = cfg.fractional_bin_offsets(io);
        b = eta/N;

        w0 = synth_discrete_lfm( ...
            N,1,aw,b,0);

        for idv = 1:numel(cfg.delta_velocity_mps)

            dv = cfg.delta_velocity_mps(idv);

            for iside = 1:numel(sides)

                side = sides(iside);

                if side=="LowV"
                    vs = vw-dv;
                else
                    vs = vw+dv;
                end

                [~,~,Ks] = residual_fm_rates( ...
                    vs,R0,lambda,cfg);

                as = Ks/(cfg.prf_hz^2);

                s0 = synth_discrete_lfm( ...
                    N,cfg.A_strong,as,b,0);

                Ys = matched_lfm_transform(s0,as);

                for isem = 1:numel(cfg.peak_semantics)

                    semantics = cfg.peak_semantics(isem);

                    for il = 1:numel( ...
                            cfg.filter_window_length_bins)

                        Lwin = ...
                            cfg.filter_window_length_bins(il);

                        [mask,info] = ...
                            build_semantic_mask( ...
                                Ys,Lwin,semantics,cfg);

                        [sr,wr] = ...
                            apply_fixed_mask_components( ...
                                s0,w0,as,mask);

                        L0 = ...
                            norm(sr) / ...
                            max(norm(s0),cfg.small_norm_floor);

                        D0 = ...
                            norm(wr) / ...
                            max(norm(w0),cfg.small_norm_floor);

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
                            char(mode),N,eta,b, ...
                            dv,char(side),vs, ...
                            char(semantics),Lwin, ...
                            L0,D0,rmin, ...
                            info.raw_detected_bin_count, ...
                            info.mask_bin_count, ...
                            info.num_objects, ...
                            info.tie_tolerance_abs, ...
                            info.twin_peak_relative_difference};
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
    'delta_velocity_mps','strong_velocity_side', ...
    'strong_velocity_mps','peak_semantics', ...
    'window_bins', ...
    'zero_mismatch_strong_leak_L0', ...
    'zero_mismatch_weak_loss_D0', ...
    'recoverability_floor_rmin', ...
    'raw_detected_bin_count', ...
    'mask_bin_count','num_detected_objects', ...
    'tie_tolerance_abs', ...
    'twin_peak_relative_difference'});

writetable(trial_table, ...
    fullfile(out_path,'pa5er1_floor_trials.csv'));

%% Summary
summary_table = summarize_floor(trial_table);

writetable(summary_table, ...
    fullfile(out_path,'pa5er1_floor_summary.csv'));

%% Tie diagnostics
tie_table = summarize_tie_diagnostics(trial_table);

writetable(tie_table, ...
    fullfile(out_path,'pa5er1_tie_diagnostics.csv'));

%% Direct semantic comparisons
comparison_table = ...
    compare_semantics(summary_table,cfg);

writetable(comparison_table, ...
    fullfile(out_path,'pa5er1_semantic_comparison.csv'));

%% Decision
decision_table = ...
    build_decision_summary( ...
        comparison_table,cfg);

writetable(decision_table, ...
    fullfile(out_path,'pa5er1_decision_summary.csv'));

%% Text summary
write_summary( ...
    out_path,cfg,lambda,R0, ...
    summary_table,tie_table, ...
    comparison_table,decision_table);

%% Figures
make_figures( ...
    out_path,cfg,lambda,R0, ...
    aw,summary_table);

%% Save
results = struct();
results.cfg = cfg;
results.lambda = lambda;
results.R0 = R0;
results.trial_table = trial_table;
results.summary_table = summary_table;
results.tie_table = tie_table;
results.comparison_table = comparison_table;
results.decision_table = decision_table;

save(fullfile(out_path,'exp09_pa5er1_results.mat'), ...
    'results','-v7.3');

fprintf('\n============================================================\n');
fprintf(' EXP009 PA5E-R1 / Numerical Tie-Tolerance Patch\n');
fprintf('============================================================\n');
disp(tie_table);
disp(comparison_table);
disp(decision_table);
fprintf('============================================================\n');
fprintf('Saved to:\n%s\n\n',out_path);

end

%% ========================================================================
function validate_config_complete(cfg)

required = { ...
    'c', ...
    'fc_hz', ...
    'prf_hz', ...
    'bandwidth_hz', ...
    'platform_height_m', ...
    'antenna_length_m', ...
    'platform_velocity_mps', ...
    'pulse_width_s', ...
    'slant_range_factor', ...
    'paper_aperture_time_s', ...
    'beamwidth_scale', ...
    'weak_velocity_mps', ...
    'delta_velocity_mps', ...
    'A_strong', ...
    'fractional_bin_offsets', ...
    'filter_window_length_bins', ...
    'peak_semantics', ...
    'frac_domain_peak_gate', ...
    'tie_eps_multiplier', ...
    'small_norm_floor', ...
    'semantic_match_rel_tol', ...
    'persistent_floor_rmin_gate', ...
    'figure_aperture', ...
    'figure_delta_velocity_mps', ...
    'figure_side', ...
    'figure_eta', ...
    'figure_window_bins', ...
    'figure_visible', ...
    'output_dir'};

missing = required(~isfield(cfg,required));

if ~isempty(missing)
    error('EXP009:PA5ER1:MissingConfigField', ...
        'Missing config field(s): %s', ...
        strjoin(missing,', '));
end

end

%% ========================================================================
function run_semantics_self_test(cfg)
% Fail early if the intended tie semantics are not implemented.
%
% Synthetic exact two-bin plateau:
%   [0.1, 1, 1, 0.1]
%
% With gate 0.7:
%   legacy LocalMax          -> one center
%   ConnectedSupport        -> two support bins
%   PlateauAwareExact       -> two centers for exact equality
%   PlateauAwareTol         -> two centers
%
% Near-tie test:
%   second peak differs only by a floating-point-scale amount.
%   PlateauAwareTol must still keep both.

Y_exact = [0.1,1,1,0.1];

[~,a] = build_semantic_mask( ...
    Y_exact,1,"LocalMax",cfg);

[~,b] = build_semantic_mask( ...
    Y_exact,1,"ConnectedSupport",cfg);

[~,c] = build_semantic_mask( ...
    Y_exact,1,"PlateauAwareExact",cfg);

[~,d] = build_semantic_mask( ...
    Y_exact,1,"PlateauAwareTol",cfg);

if a.raw_detected_bin_count~=1 || ...
        b.raw_detected_bin_count~=2 || ...
        c.raw_detected_bin_count~=2 || ...
        d.raw_detected_bin_count~=2

    error('EXP009:PA5ER1:SemanticsSelfTestFailed', ...
        ['Exact-plateau semantics self-test failed. ' ...
         'Counts were LocalMax=%d, Connected=%d, ' ...
         'Exact=%d, Tol=%d.'], ...
        a.raw_detected_bin_count, ...
        b.raw_detected_bin_count, ...
        c.raw_detected_bin_count, ...
        d.raw_detected_bin_count);
end

near_delta = ...
    0.25*cfg.tie_eps_multiplier* ...
    numel(Y_exact)*eps(1);

Y_near = [0.1,1,1-near_delta,0.1];

[~,e] = build_semantic_mask( ...
    Y_near,1,"PlateauAwareTol",cfg);

if e.raw_detected_bin_count~=2
    error('EXP009:PA5ER1:NearTieSelfTestFailed', ...
        ['Tolerance-aware plateau self-test failed. ' ...
         'Expected two retained near-tie bins, got %d.'], ...
        e.raw_detected_bin_count);
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
function [mask,info] = ...
    build_semantic_mask( ...
        Y,Lwin,semantics,cfg)

amp = abs(Y(:).');
N = numel(amp);

amax = max(amp);
gate = cfg.frac_domain_peak_gate*amax;
half = floor((Lwin-1)/2);

tie_tol = ...
    cfg.tie_eps_multiplier * ...
    N * eps(max(amax,1));

semantics = string(semantics);

switch semantics

    case "LocalMax"

        raw = legacy_localmax_peaks(amp,gate);
        mask = centers_to_mask(raw,N,half);
        nobj = numel(raw);

    case "ConnectedSupport"

        support = amp>=gate;

        if ~any(support)
            [~,imax] = max(amp);
            support(imax) = true;
        end

        raw = find(support);
        mask = dilate_binary_support(support,half);
        nobj = count_connected_components(support);

    case "PlateauAwareExact"

        raw = plateau_aware_exact(amp,gate);
        mask = centers_to_mask(raw,N,half);
        nobj = count_connected_components( ...
            index_to_mask(raw,N));

    case "PlateauAwareTol"

        raw = plateau_aware_tol( ...
            amp,gate,tie_tol);

        mask = centers_to_mask(raw,N,half);

        nobj = count_connected_components( ...
            index_to_mask(raw,N));

    otherwise
        error('Unknown peak semantics: %s',semantics);
end

twin_rel = twin_peak_relative_difference(amp);

info = struct();
info.mask = mask;
info.raw_indices = raw;
info.raw_detected_bin_count = numel(raw);
info.mask_bin_count = nnz(mask);
info.num_objects = nobj;
info.tie_tolerance_abs = tie_tol;
info.twin_peak_relative_difference = twin_rel;

end

%% ========================================================================
function pk = legacy_localmax_peaks(amp,gate)
% PA5C/PA5D legacy convention:
% strict left, non-strict right.

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
function pk = plateau_aware_exact(amp,gate)
% PA5E exact-comparison rule.

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
    [~,pk] = max(amp);
end

end

%% ========================================================================
function pk = plateau_aware_tol( ...
    amp,gate,tol)
% Floating-point-tolerance-aware plateau rule.
%
% "a >= b" becomes:
%   a >= b - tol
%
% "a > b" becomes:
%   a > b + tol
%
% Two samples whose difference is within tol are treated as numerically
% equal for local-maximum topology.

amp = amp(:).';
N = numel(amp);

pk = [];

if N==1
    pk = 1;
    return;
end

if amp(1)>=amp(2)-tol && ...
        amp(1)>=gate-tol
    pk(end+1) = 1; %#ok<AGROW>
end

for i = 2:N-1

    ge_left = ...
        amp(i)>=amp(i-1)-tol;

    ge_right = ...
        amp(i)>=amp(i+1)-tol;

    strict_somewhere = ...
        amp(i)>amp(i-1)+tol || ...
        amp(i)>amp(i+1)+tol;

    if ge_left && ge_right && ...
            strict_somewhere && ...
            amp(i)>=gate-tol

        pk(end+1) = i; %#ok<AGROW>
    end
end

if amp(N)>=amp(N-1)-tol && ...
        amp(N)>=gate-tol
    pk(end+1) = N; %#ok<AGROW>
end

pk = unique(pk);

if isempty(pk)

    [~,imax] = max(amp);

    pk = find( ...
        abs(amp-amp(imax))<=tol & ...
        amp>=gate-tol);
end

end

%% ========================================================================
function mask = centers_to_mask( ...
    centers,N,half)

mask = false(1,N);

for k = 1:numel(centers)

    i1 = max(1,centers(k)-half);
    i2 = min(N,centers(k)+half);

    mask(i1:i2) = true;
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
function d = twin_peak_relative_difference(amp)

amp = amp(:).';

[sv,~] = sort(amp,'descend');

if numel(sv)<2 || sv(1)<=0
    d = NaN;
else
    d = abs(sv(1)-sv(2))/sv(1);
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
function S = summarize_floor(T)

modes = unique(string(T.aperture_mode),'stable');
etas = unique(T.fractional_bin_offset).';
sems = unique(string(T.peak_semantics),'stable');
wins = unique(T.window_bins).';

rows = {};

for im = 1:numel(modes)

    for io = 1:numel(etas)

        for is = 1:numel(sems)

            for iw = 1:numel(wins)

                M = T( ...
                    string(T.aperture_mode)==modes(im) & ...
                    abs(T.fractional_bin_offset-etas(io))<1e-12 & ...
                    string(T.peak_semantics)==sems(is) & ...
                    T.window_bins==wins(iw),:);

                r = M.recoverability_floor_rmin;
                rf = r(isfinite(r));

                if isempty(rf)
                    medr = Inf;
                    minr = Inf;
                    maxr = Inf;
                else
                    medr = median(rf);
                    minr = min(rf);
                    maxr = max(rf);
                end

                rows(end+1,:) = { ... %#ok<AGROW>
                    char(modes(im)),etas(io), ...
                    char(sems(is)),wins(iw), ...
                    median(M.zero_mismatch_strong_leak_L0), ...
                    median(M.zero_mismatch_weak_loss_D0), ...
                    medr,minr,maxr, ...
                    median(M.raw_detected_bin_count), ...
                    median(M.mask_bin_count), ...
                    median(M.tie_tolerance_abs), ...
                    median(M.twin_peak_relative_difference)};
            end
        end
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','fractional_bin_offset', ...
    'peak_semantics','window_bins', ...
    'median_zero_mismatch_strong_leak_L0', ...
    'median_zero_mismatch_weak_loss_D0', ...
    'median_recoverability_floor_rmin', ...
    'minimum_recoverability_floor_rmin', ...
    'maximum_recoverability_floor_rmin', ...
    'median_raw_detected_bin_count', ...
    'median_mask_bin_count', ...
    'median_tie_tolerance_abs', ...
    'median_twin_peak_relative_difference'});

end

%% ========================================================================
function S = summarize_tie_diagnostics(T)

modes = unique(string(T.aperture_mode),'stable');
etas = unique(T.fractional_bin_offset).';

rows = {};

for im = 1:numel(modes)

    for io = 1:numel(etas)

        M = T( ...
            string(T.aperture_mode)==modes(im) & ...
            abs(T.fractional_bin_offset-etas(io))<1e-12,:);

        rel = M.twin_peak_relative_difference;
        tol = M.tie_tolerance_abs;

        % Convert the absolute amplitude tolerance to a conservative
        % relative scale by using the reported twin-relative difference
        % directly for diagnosis. The key question is whether the latter
        % sits at numerical precision scale.
        rows(end+1,:) = { ... %#ok<AGROW>
            char(modes(im)),etas(io), ...
            median(rel,'omitnan'), ...
            max(rel), ...
            median(tol,'omitnan'), ...
            median(M.azimuth_samples)};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','fractional_bin_offset', ...
    'median_twin_peak_relative_difference', ...
    'maximum_twin_peak_relative_difference', ...
    'median_absolute_tie_tolerance', ...
    'azimuth_samples'});

end

%% ========================================================================
function C = compare_semantics(S,cfg)

modes = unique(string(S.aperture_mode),'stable');

rows = {};

for im = 1:numel(modes)

    mode = modes(im);

    for Lwin = cfg.filter_window_length_bins

        base = pick_value( ...
            S,mode,0.5,"LocalMax",Lwin);

        conn = pick_value( ...
            S,mode,0.5,"ConnectedSupport",Lwin);

        exact = pick_value( ...
            S,mode,0.5,"PlateauAwareExact",Lwin);

        tol = pick_value( ...
            S,mode,0.5,"PlateauAwareTol",Lwin);

        rows(end+1,:) = { ... %#ok<AGROW>
            char(mode),Lwin, ...
            base,conn,exact,tol, ...
            rel_diff(exact,base), ...
            rel_diff(tol,conn), ...
            rel_diff(tol,base)};
    end
end

C = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','window_bins', ...
    'half_bin_rmin_LocalMax', ...
    'half_bin_rmin_ConnectedSupport', ...
    'half_bin_rmin_PlateauAwareExact', ...
    'half_bin_rmin_PlateauAwareTol', ...
    'Exact_vs_LocalMax_relative_difference', ...
    'Tol_vs_Connected_relative_difference', ...
    'Tol_vs_LocalMax_relative_difference'});

end

%% ========================================================================
function v = pick_value( ...
    S,mode,eta,sem,Lwin)

M = S( ...
    string(S.aperture_mode)==mode & ...
    abs(S.fractional_bin_offset-eta)<1e-12 & ...
    string(S.peak_semantics)==sem & ...
    S.window_bins==Lwin,:);

if isempty(M)
    v = NaN;
else
    v = M.median_recoverability_floor_rmin(1);
end

end

%% ========================================================================
function d = rel_diff(a,b)

if ~isfinite(a) || ~isfinite(b)
    d = NaN;
elseif abs(b)<=eps
    d = abs(a-b);
else
    d = abs(a-b)/abs(b);
end

end

%% ========================================================================
function D = build_decision_summary(C,cfg)

modes = unique(string(C.aperture_mode),'stable');

rows = {};

for im = 1:numel(modes)

    mode = modes(im);

    M = C(string(C.aperture_mode)==mode,:);

    L1 = M(M.window_bins==1,:);

    tol_matches_conn = ...
        L1.Tol_vs_Connected_relative_difference <= ...
        cfg.semantic_match_rel_tol;

    exact_matches_local = ...
        L1.Exact_vs_LocalMax_relative_difference <= ...
        cfg.semantic_match_rel_tol;

    all_tol_floor = ...
        M.half_bin_rmin_PlateauAwareTol;

    min_tol_floor = min(all_tol_floor(isfinite(all_tol_floor)));

    floor_persists = ...
        min_tol_floor > ...
        cfg.persistent_floor_rmin_gate;

    if tol_matches_conn && ...
            exact_matches_local && ...
            floor_persists

        branch = ...
            "NUMERICAL_TIE_CONFIRMED_AND_OPERATOR_FLOOR_PERSISTS";

    elseif tol_matches_conn && ...
            ~floor_persists

        branch = ...
            "NUMERICAL_TIE_CONFIRMED_AND_FLOOR_COLLAPSES";

    elseif ~tol_matches_conn && ...
            floor_persists

        branch = ...
            "TIE_PATCH_CHANGES_SEMANTICS_BUT_FLOOR_PERSISTS";

    else

        branch = ...
            "SEMANTICS_REQUIRES_FURTHER_REVIEW";
    end

    rows(end+1,:) = { ... %#ok<AGROW>
        char(mode), ...
        double(exact_matches_local), ...
        double(tol_matches_conn), ...
        min_tol_floor, ...
        double(floor_persists), ...
        char(branch)};
end

D = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode', ...
    'PlateauAwareExact_matches_LocalMax_at_L1', ...
    'PlateauAwareTol_matches_ConnectedSupport_at_L1', ...
    'minimum_half_bin_rmin_PlateauAwareTol', ...
    'finite_window_floor_persists', ...
    'decision_branch'});

end

%% ========================================================================
function write_summary( ...
    out_path,cfg,lambda,R0,S,T,C,D)

fid = fopen(fullfile(out_path,'summary.txt'),'w');

fprintf(fid,'EXP009 PA5E-R1 / Numerical Tie-Tolerance Patch\n');
fprintf(fid,'=============================================\n\n');

fprintf(fid,'Purpose\n');
fprintf(fid,'-------\n');
fprintf(fid,['Determine whether PA5E PlateauAware failed to separate from ' ...
    'LocalMax because exact floating-point equality was too strict.\n\n']);

fprintf(fid,'Numerical tie rule\n');
fprintf(fid,'------------------\n');
fprintf(fid,[ ...
    'tie_tol = %g * N * eps(max(abs(Y)))\n\n'], ...
    cfg.tie_eps_multiplier);

fprintf(fid,'Physical setup\n');
fprintf(fid,'--------------\n');
fprintf(fid,'lambda=%g m, R0=%g m, PRF=%g Hz\n', ...
    lambda,R0,cfg.prf_hz);
fprintf(fid,'eta=%s\n', ...
    mat2str(cfg.fractional_bin_offsets));
fprintf(fid,'windows=%s bins\n\n', ...
    mat2str(cfg.filter_window_length_bins));

fprintf(fid,'Tie diagnostics\n');
fprintf(fid,'---------------\n');
for i=1:height(T)
    fprintf(fid,[ ...
        '%s eta=%g twinRelDiff(med/max)=%g/%g ' ...
        'absTieTol=%g N=%d\n'], ...
        T.aperture_mode{i}, ...
        T.fractional_bin_offset(i), ...
        T.median_twin_peak_relative_difference(i), ...
        T.maximum_twin_peak_relative_difference(i), ...
        T.median_absolute_tie_tolerance(i), ...
        T.azimuth_samples(i));
end

fprintf(fid,'\nHalf-bin semantic comparison\n');
fprintf(fid,'----------------------------\n');
for i=1:height(C)
    fprintf(fid,[ ...
        '%s L=%d Local=%g Conn=%g Exact=%g Tol=%g ' ...
        'Exact-vs-Local=%g Tol-vs-Conn=%g\n'], ...
        C.aperture_mode{i}, ...
        C.window_bins(i), ...
        C.half_bin_rmin_LocalMax(i), ...
        C.half_bin_rmin_ConnectedSupport(i), ...
        C.half_bin_rmin_PlateauAwareExact(i), ...
        C.half_bin_rmin_PlateauAwareTol(i), ...
        C.Exact_vs_LocalMax_relative_difference(i), ...
        C.Tol_vs_Connected_relative_difference(i));
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
fprintf(fid,[ ...
    '1) The tie tolerance is machine-precision-scaled, not a fitted ' ...
    'physical threshold.\n']);
fprintf(fid,[ ...
    '2) PlateauAwareTol is an implementation audit, not a claim about ' ...
    'Wang authors'' private code.\n']);
fprintf(fid,[ ...
    '3) This patch uses true strong parameters only; it isolates zero-' ...
    'mismatch floor behavior.\n']);
fprintf(fid,[ ...
    '4) If PlateauAwareTol approaches ConnectedSupport while a nonzero ' ...
    'minimum rmin remains, the archive-level conclusion is: numerical ' ...
    'tie handling mattered, but did not create the finite-window floor.\n']);
fprintf(fid,[ ...
    '5) After this archival patch, the next research stage is PA5F: ' ...
    'sub-bin recentered / fence-aware strong removal.\n']);

fclose(fid);

end

%% ========================================================================
function make_figures( ...
    out_path,cfg,lambda,R0,aw,S)

sems = cfg.peak_semantics;
modes = ["Paper1s","BeamDerived"];

%% Representative transform and masks
mode = string(cfg.figure_aperture);

if mode=="Paper1s"
    N = max(32,round( ...
        cfg.prf_hz*cfg.paper_aperture_time_s));
else
    beamwidth_rad = ...
        cfg.beamwidth_scale * ...
        lambda/cfg.antenna_length_m;

    Tbeam = ...
        R0*beamwidth_rad/ ...
        cfg.platform_velocity_mps;

    N = max(32,round(cfg.prf_hz*Tbeam));
end

eta = cfg.figure_eta;
b = eta/N;

if strcmpi(cfg.figure_side,'HighV')
    vs = cfg.weak_velocity_mps + ...
        cfg.figure_delta_velocity_mps;
else
    vs = cfg.weak_velocity_mps - ...
        cfg.figure_delta_velocity_mps;
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

h = gobjects(numel(sems)+2,1);

h(1) = plot( ...
    xrel,amp(idx),'o-','LineWidth',1.2);

marker_levels = [1.08,1.14,1.20,1.26];

for is = 1:numel(sems)

    [mask,~] = build_semantic_mask( ...
        Y,cfg.figure_window_bins, ...
        sems(is),cfg);

    yy = nan(size(idx));
    yy(mask(idx)) = marker_levels(is);

    h(is+1) = plot( ...
        xrel,yy,'s','LineWidth',1.4);
end

h(end) = yline( ...
    cfg.frac_domain_peak_gate,'--');

xlabel('Focused transform bin relative to DC');
ylabel('Normalized magnitude / mask markers');
title('EXP009 PA5E-R1 — Numerical Tie-Tolerance Audit');

labels = [ ...
    {'Focused strong magnitude'}; ...
    cellstr(sems(:)); ...
    {'0.7 gate'}];

legend(h,labels,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path, ...
        'fig01_halfbin_tie_tolerance_masks.png'), ...
    'Resolution',180);
close(fig);

%% Fig 2 — L=1 rmin semantics
fig = figure('Visible',cfg.figure_visible);
hold on;

h = gobjects(numel(modes),1);

for im = 1:numel(modes)

    vals = nan(numel(sems),1);

    for is = 1:numel(sems)

        M = S( ...
            string(S.aperture_mode)==modes(im) & ...
            abs(S.fractional_bin_offset-0.5)<1e-12 & ...
            string(S.peak_semantics)==sems(is) & ...
            S.window_bins==1,:);

        vals(is) = ...
            M.median_recoverability_floor_rmin;
    end

    h(im) = plot( ...
        1:numel(sems),vals, ...
        'o-','LineWidth',1.3);
end

xticks(1:numel(sems));
xticklabels(sems);
ylabel('Median zero-mismatch r_{min}');
title('EXP009 PA5E-R1 — Half-Bin L=1 Floor vs Semantics');
legend(h,cellstr(modes(:)),'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path, ...
        'fig02_halfbin_L1_rmin_vs_semantics.png'), ...
    'Resolution',180);
close(fig);

%% Fig 3 — Beam half-bin floor vs window
fig = figure('Visible',cfg.figure_visible);
hold on;

h = gobjects(numel(sems),1);

for is = 1:numel(sems)

    M = S( ...
        string(S.aperture_mode)=="BeamDerived" & ...
        abs(S.fractional_bin_offset-0.5)<1e-12 & ...
        string(S.peak_semantics)==sems(is),:);

    [~,ord] = sort(M.window_bins);
    M = M(ord,:);

    h(is) = plot( ...
        M.window_bins, ...
        M.median_recoverability_floor_rmin, ...
        'o-','LineWidth',1.3);
end

xlabel('Window length l (bins)');
ylabel('Median zero-mismatch r_{min}');
title('EXP009 PA5E-R1 — Half-Bin Floor vs Window (BeamDerived)');
legend(h,cellstr(sems(:)),'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path, ...
        'fig03_halfbin_rmin_vs_window_beam.png'), ...
    'Resolution',180);
close(fig);

%% Fig 4 — on-grid vs half-bin min floor
fig = figure('Visible',cfg.figure_visible);
hold on;

h = gobjects(numel(sems),1);

for is = 1:numel(sems)

    y = nan(2,1);

    for io = 1:2

        eta = cfg.fractional_bin_offsets(io);

        M = S( ...
            string(S.aperture_mode)=="BeamDerived" & ...
            abs(S.fractional_bin_offset-eta)<1e-12 & ...
            string(S.peak_semantics)==sems(is),:);

        y(io) = min( ...
            M.median_recoverability_floor_rmin);
    end

    h(is) = plot( ...
        cfg.fractional_bin_offsets, ...
        y,'o-','LineWidth',1.3);
end

xlabel('Focused fractional-bin offset |\eta|');
ylabel('Minimum median r_{min} over l');
title('EXP009 PA5E-R1 — Best Floor: On-Grid vs Half-Bin');
legend(h,cellstr(sems(:)),'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path, ...
        'fig04_best_rmin_ongrid_vs_halfbin.png'), ...
    'Resolution',180);
close(fig);

end
