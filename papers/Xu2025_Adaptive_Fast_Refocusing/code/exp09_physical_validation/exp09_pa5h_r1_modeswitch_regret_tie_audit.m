function results = exp09_pa5h_r1_modeswitch_regret_tie_audit()
%EXP09_PA5H_R1_MODESWITCH_REGRET_TIE_AUDIT
% EXP009 / PA5H-R1
%
% Targeted audit of:
%
%   1) PA5H high-contrast translation-collapse outliers;
%   2) PA5H best-window tie-selection logic.
%
% -------------------------------------------------------------------------
% RQ1
% -------------------------------------------------------------------------
% For every high-contrast physical state:
%
%   aperture x Delta-v x side x Aw/As x phase
%
% repeat the PA5H local continuous-ML estimate for:
%
%   eta = [0, .125, .25, .375, .5].
%
% Record:
%   - local measured bias delta_local = hat(eta)-eta;
%   - integer coarse-bin branch;
%   - exact signal translation error after oracle de-shifting eta.
%
% If the local bias spread exceeds the diagnostic outlier threshold,
% perform a broad oracle GLOBAL objective audit on the eta=0 canonical
% signal:
%
%   J(delta) = |sum z[n] exp(-j 2pi delta n/N)|^2.
%
% Extract the top continuous local maxima, then ask whether the PA5H
% estimator changes peak branch as eta changes.
%
% Key distinction:
%
%   signal/objective translation invariance
%       versus
%   local estimator branch invariance.
%
% -------------------------------------------------------------------------
% RQ2
% -------------------------------------------------------------------------
% Read PA5H pa5h_regret_summary.csv and redo "best window" selection
% lexicographically:
%
%   1) minimum median regret;
%   2) among ties, minimum p90 regret;
%   3) among ties, minimum mean regret;
%   4) among ties, maximum action agreement;
%   5) remaining tie -> smaller window.
%
% This removes the previous "first zero median -> L=1" artifact.
%
% Run:
%   results = exp09_pa5h_r1_modeswitch_regret_tie_audit;

cfg = config_exp09_pa5h_r1_modeswitch_audit();

validate_config(cfg);
run_startup_self_test(cfg);

%% Paths
this_dir = fileparts(mfilename('fullpath'));
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.pa5h_results_dir)
    pa5h_dir = fullfile( ...
        paper_root,'results','exp09_physical_validation', ...
        'exp09_pa5h_bias_regret_audit');
else
    pa5h_dir = cfg.pa5h_results_dir;
end

if isempty(cfg.output_dir)
    out_path = fullfile( ...
        paper_root,'results','exp09_physical_validation', ...
        'exp09_pa5h_r1_modeswitch_regret_tie_audit');
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

T_paper = cfg.paper_aperture_time_s;
N_paper = max(32,round(cfg.prf_hz*T_paper));

T_beam = ...
    R0*beamwidth_rad/cfg.platform_velocity_mps;
N_beam = max(32,round(cfg.prf_hz*T_beam));

aperture_names = ["Paper1s","BeamDerived"];
N_list = [N_paper,N_beam];

sides = ["LowV","HighV"];

%% =======================================================================
% RQ1 — High-contrast local-estimator collapse audit
% =======================================================================
trial_rows = {};
state_rows = {};
global_rows = {};

for ia = 1:numel(aperture_names)

    mode = aperture_names(ia);
    N = N_list(ia);

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

            for ir = 1:numel( ...
                    cfg.audit_weak_to_strong_ratio)

                rA = cfg.audit_weak_to_strong_ratio(ir);

                for ip = 1:numel( ...
                        cfg.relative_phase_rad)

                    phi = cfg.relative_phase_rad(ip);

                    eta_vec = cfg.fractional_bin_offsets(:);
                    nEta = numel(eta_vec);

                    bias_wrapped = zeros(nEta,1);
                    bias_raw = zeros(nEta,1);
                    coarse_bin = zeros(nEta,1);
                    nu_hat_vec = zeros(nEta,1);
                    trans_err = zeros(nEta,1);

                    % Canonical eta=0 signal for exact translation check.
                    s_ref = synth_discrete_lfm( ...
                        N,cfg.A_strong,as,0,0);

                    w_ref = synth_discrete_lfm( ...
                        N,rA,aw,0,phi);

                    x_ref = s_ref+w_ref;

                    for ie = 1:nEta

                        eta = eta_vec(ie);
                        b = eta/N;

                        s = synth_discrete_lfm( ...
                            N,cfg.A_strong,as,b,0);

                        w = synth_discrete_lfm( ...
                            N,rA,aw,b,phi);

                        x = s+w;

                        [nu_hat,diag] = ...
                            estimate_continuous_ml( ...
                                x,as,cfg);

                        eta_hat = ...
                            fractional_component(nu_hat);

                        bias_wrapped(ie) = ...
                            fractional_error(eta_hat,eta);

                        % Raw delta before modulo wrapping. This is useful
                        % for branch diagnosis.
                        bias_raw(ie) = nu_hat-eta;

                        coarse_bin(ie) = ...
                            diag.coarse_integer_bin;

                        nu_hat_vec(ie) = nu_hat;

                        xr = recenter_by_true_eta(x,eta);

                        trans_err(ie) = ...
                            norm(xr-x_ref) / ...
                            max(norm(x_ref),eps);

                        trial_rows(end+1,:) = { ... %#ok<AGROW>
                            char(mode),N,dv,char(side),vs, ...
                            rA,phi,eta, ...
                            nu_hat,eta_hat, ...
                            bias_wrapped(ie), ...
                            bias_raw(ie), ...
                            coarse_bin(ie), ...
                            diag.objective_at_hat, ...
                            diag.objective_at_integer, ...
                            trans_err(ie)};
                    end

                    wrapped_spread = ...
                        max(bias_wrapped)-min(bias_wrapped);

                    raw_spread = ...
                        max(bias_raw)-min(bias_raw);

                    max_trans_err = max(trans_err);

                    outlier = ...
                        wrapped_spread > ...
                        cfg.collapse_outlier_threshold_bins;

                    % Broad global audit only for states that produced
                    % collapse anomalies.
                    global_delta = NaN;
                    top2_ratio = NaN;
                    top1_top2_sep = NaN;
                    branch_switch = 0;
                    any_local_not_global = 0;
                    n_distinct_branch = NaN;
                    near_degenerate = 0;

                    if outlier

                        G = global_objective_audit( ...
                            x_ref,as,cfg);

                        global_delta = G.top_delta_bins(1);

                        if numel(G.top_delta_bins)>=2
                            top2_ratio = ...
                                G.top_objective(2) / ...
                                max(G.top_objective(1),eps);

                            top1_top2_sep = abs( ...
                                circular_bin_error( ...
                                    G.top_delta_bins(1), ...
                                    G.top_delta_bins(2)));
                        end

                        near_degenerate = ...
                            double(top2_ratio >= ...
                                cfg.near_degenerate_peak_ratio);

                        branch_id = zeros(nEta,1);
                        global_match = zeros(nEta,1);

                        for ie = 1:nEta

                            [branch_id(ie),dnear] = ...
                                nearest_peak_branch( ...
                                    bias_raw(ie), ...
                                    G.top_delta_bins);

                            global_match(ie) = ...
                                double( ...
                                abs(circular_bin_error( ...
                                    bias_raw(ie), ...
                                    global_delta)) <= ...
                                cfg.branch_match_tolerance_bins);

                            global_rows(end+1,:) = { ... %#ok<AGROW>
                                char(mode),N,dv,char(side),vs, ...
                                rA,phi,eta_vec(ie), ...
                                bias_wrapped(ie), ...
                                bias_raw(ie), ...
                                coarse_bin(ie), ...
                                branch_id(ie),dnear, ...
                                global_delta, ...
                                global_match(ie), ...
                                top2_ratio, ...
                                top1_top2_sep, ...
                                near_degenerate, ...
                                max_trans_err};
                        end

                        n_distinct_branch = ...
                            numel(unique(branch_id));

                        branch_switch = ...
                            double(n_distinct_branch>1);

                        any_local_not_global = ...
                            double(any(global_match==0));
                    end

                    state_rows(end+1,:) = { ... %#ok<AGROW>
                        char(mode),N,dv,char(side),vs, ...
                        rA,phi, ...
                        wrapped_spread,raw_spread, ...
                        max_trans_err,outlier, ...
                        global_delta,top2_ratio, ...
                        top1_top2_sep, ...
                        near_degenerate, ...
                        n_distinct_branch, ...
                        branch_switch, ...
                        any_local_not_global};
                end
            end
        end
    end
end

trial_table = cell2table(trial_rows, ...
    'VariableNames',{ ...
    'aperture_mode','azimuth_samples', ...
    'delta_velocity_mps','strong_velocity_side', ...
    'strong_velocity_mps', ...
    'weak_to_strong_ratio','relative_phase_rad', ...
    'true_eta_bins','continuous_nu_hat_bins', ...
    'fractional_eta_hat_bins', ...
    'wrapped_bias_bins','raw_delta_bins', ...
    'coarse_integer_bin', ...
    'objective_at_local_hat', ...
    'objective_at_integer', ...
    'translation_signal_error'});

state_table = cell2table(state_rows, ...
    'VariableNames',{ ...
    'aperture_mode','azimuth_samples', ...
    'delta_velocity_mps','strong_velocity_side', ...
    'strong_velocity_mps', ...
    'weak_to_strong_ratio','relative_phase_rad', ...
    'wrapped_bias_spread_bins', ...
    'raw_delta_spread_bins', ...
    'maximum_translation_signal_error', ...
    'collapse_outlier', ...
    'global_top1_delta_bins', ...
    'top2_to_top1_objective_ratio', ...
    'top1_top2_separation_bins', ...
    'near_degenerate_peaks', ...
    'n_distinct_local_peak_branches', ...
    'local_branch_switch', ...
    'any_local_not_global_top1'});

if isempty(global_rows)
    global_table = cell2table(cell(0,19), ...
        'VariableNames',{ ...
        'aperture_mode','azimuth_samples', ...
        'delta_velocity_mps','strong_velocity_side', ...
        'strong_velocity_mps', ...
        'weak_to_strong_ratio','relative_phase_rad', ...
        'true_eta_bins','wrapped_bias_bins', ...
        'raw_delta_bins','coarse_integer_bin', ...
        'nearest_global_peak_rank', ...
        'distance_to_nearest_global_peak_bins', ...
        'global_top1_delta_bins', ...
        'local_matches_global_top1', ...
        'top2_to_top1_objective_ratio', ...
        'top1_top2_separation_bins', ...
        'near_degenerate_peaks', ...
        'maximum_translation_signal_error'});
else
    global_table = cell2table(global_rows, ...
        'VariableNames',{ ...
        'aperture_mode','azimuth_samples', ...
        'delta_velocity_mps','strong_velocity_side', ...
        'strong_velocity_mps', ...
        'weak_to_strong_ratio','relative_phase_rad', ...
        'true_eta_bins','wrapped_bias_bins', ...
        'raw_delta_bins','coarse_integer_bin', ...
        'nearest_global_peak_rank', ...
        'distance_to_nearest_global_peak_bins', ...
        'global_top1_delta_bins', ...
        'local_matches_global_top1', ...
        'top2_to_top1_objective_ratio', ...
        'top1_top2_separation_bins', ...
        'near_degenerate_peaks', ...
        'maximum_translation_signal_error'});
end

writetable(trial_table, ...
    fullfile(out_path,'pa5h_r1_modeswitch_trials.csv'));

writetable(state_table, ...
    fullfile(out_path,'pa5h_r1_modeswitch_state_summary.csv'));

writetable(global_table, ...
    fullfile(out_path,'pa5h_r1_global_peak_audit.csv'));

mode_summary = summarize_mode_switch( ...
    state_table,cfg);

writetable(mode_summary, ...
    fullfile(out_path,'pa5h_r1_modeswitch_decision_summary.csv'));

%% =======================================================================
% RQ2 — Re-tie PA5H best-window regret summary
% =======================================================================
regret_summary_file = fullfile( ...
    pa5h_dir,'pa5h_regret_summary.csv');

if ~isfile(regret_summary_file)
    error('EXP009:PA5HR1:MissingPA5HRegretSummary', ...
        ['Required PA5H file not found:\n%s\n' ...
         'Run PA5H first or set cfg.pa5h_results_dir.'], ...
        regret_summary_file);
end

R = readtable(regret_summary_file);

required_cols = { ...
    'aperture_mode','true_eta_bins','window_bins', ...
    'median_decision_regret','p90_decision_regret', ...
    'mean_decision_regret','action_agreement_rate', ...
    'false_recenter_rate','missed_recenter_rate', ...
    'median_E_gate','median_E_binary_oracle'};

missing_cols = ...
    required_cols(~ismember(required_cols,R.Properties.VariableNames));

if ~isempty(missing_cols)
    error('EXP009:PA5HR1:MissingPA5HColumns', ...
        'Missing PA5H regret column(s): %s', ...
        strjoin(missing_cols,', '));
end

retie = retie_best_windows(R,cfg);

writetable(retie, ...
    fullfile(out_path,'pa5h_r1_best_window_retie.csv'));

old_file = fullfile( ...
    pa5h_dir,'pa5h_best_window_regret.csv');

comparison = table();

if isfile(old_file)
    old = readtable(old_file);
    comparison = compare_old_new_best_windows(old,retie);
    writetable(comparison, ...
        fullfile(out_path,'pa5h_r1_best_window_old_vs_new.csv'));
end

%% Final R1 decision
decision = build_r1_decision( ...
    mode_summary,retie,cfg);

writetable(decision, ...
    fullfile(out_path,'pa5h_r1_final_decision_summary.csv'));

write_summary( ...
    out_path,cfg,mode_summary,retie,comparison,decision);

make_figures( ...
    out_path,cfg,trial_table,state_table, ...
    global_table,mode_summary,retie,comparison);

results = struct();
results.cfg = cfg;
results.trial_table = trial_table;
results.state_table = state_table;
results.global_table = global_table;
results.mode_summary = mode_summary;
results.retied_best_window = retie;
results.old_vs_new = comparison;
results.decision = decision;

save(fullfile(out_path,'exp09_pa5h_r1_results.mat'), ...
    'results','-v7.3');

fprintf('\n============================================================\n');
fprintf(' EXP009 PA5H-R1 / Mode-Switch + Regret Tie Audit\n');
fprintf('============================================================\n');
disp(mode_summary);
disp(retie);
disp(decision);
fprintf('============================================================\n');
fprintf('Saved to:\n%s\n\n',out_path);

end

%% ========================================================================
function validate_config(cfg)

required = { ...
    'c','fc_hz','prf_hz','bandwidth_hz', ...
    'platform_height_m','antenna_length_m', ...
    'platform_velocity_mps','pulse_width_s', ...
    'slant_range_factor','paper_aperture_time_s', ...
    'beamwidth_scale','weak_velocity_mps', ...
    'delta_velocity_mps','A_strong', ...
    'audit_weak_to_strong_ratio', ...
    'num_relative_phases','relative_phase_rad', ...
    'fractional_bin_offsets', ...
    'ml_search_halfwidth_bins','ml_bracket_points', ...
    'ml_tolx_bins','ml_max_fun_evals', ...
    'collapse_outlier_threshold_bins', ...
    'translation_signal_error_gate', ...
    'global_search_halfwidth_bins', ...
    'global_grid_step_bins', ...
    'global_top_peak_count', ...
    'branch_match_tolerance_bins', ...
    'near_degenerate_peak_ratio', ...
    'regret_tie_tolerance', ...
    'pa5h_results_dir','output_dir','figure_visible'};

missing = required(~isfield(cfg,required));

if ~isempty(missing)
    error('EXP009:PA5HR1:MissingConfigField', ...
        'Missing config field(s): %s', ...
        strjoin(missing,', '));
end

end

%% ========================================================================
function run_startup_self_test(cfg)

N = 188;
aS = 0.0017;
aW = 0.0022;
rA = 0.8;
phi = 1.1;

x0 = ...
    synth_discrete_lfm(N,1,aS,0,0) + ...
    synth_discrete_lfm(N,rA,aW,0,phi);

errs = zeros(size(cfg.fractional_bin_offsets));

for i = 1:numel(cfg.fractional_bin_offsets)

    eta = cfg.fractional_bin_offsets(i);

    x = ...
        synth_discrete_lfm(N,1,aS,eta/N,0) + ...
        synth_discrete_lfm(N,rA,aW,eta/N,phi);

    xr = recenter_by_true_eta(x,eta);

    errs(i) = ...
        norm(xr-x0)/max(norm(x0),eps);
end

if max(errs)>cfg.translation_signal_error_gate
    error('EXP009:PA5HR1:TranslationSelfTestFailed', ...
        ['Exact signal translation self-test failed. ' ...
         'max error=%g'],max(errs));
end

% Global-audit smoke test.
G = global_objective_audit(x0,aS,cfg);

if isempty(G.top_delta_bins) || ...
        any(~isfinite(G.top_delta_bins))
    error('EXP009:PA5HR1:GlobalAuditSelfTestFailed', ...
        'Global objective audit failed startup self-test.');
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
function xr = recenter_by_true_eta(x,eta)

x = x(:).';

N = numel(x);
m = 0:N-1;

xr = x .* exp(-1j*2*pi*eta*m/N);

end

%% ========================================================================
function z = dechirp_signal(x,a)

x = x(:).';

N = numel(x);
m = 0:N-1;

z = x.*exp(-1j*pi*a*m.^2);

end

%% ========================================================================
function [nu_hat,diag] = estimate_continuous_ml(x,a,cfg)

z = dechirp_signal(x,a);

N = numel(z);
m = 0:N-1;

Y = fftshift(fft(z));
[~,i0] = max(abs(Y));

dc = floor(N/2)+1;
k0 = i0-dc;

[nu_hat,Jhat] = ...
    refine_continuous_frequency( ...
        z,m,N,k0,cfg);

Jint = tone_objective( ...
    z,m,N,round(nu_hat));

diag = struct();
diag.coarse_integer_bin = k0;
diag.objective_at_hat = Jhat;
diag.objective_at_integer = Jint;

end

%% ========================================================================
function [nu_hat,Jhat] = ...
    refine_continuous_frequency(z,m,N,center,cfg)

z = z(:).';
m = m(:).';

lb = center-cfg.ml_search_halfwidth_bins;
ub = center+cfg.ml_search_halfwidth_bins;

grid = linspace( ...
    lb,ub,cfg.ml_bracket_points);

J = zeros(size(grid));

for i = 1:numel(grid)
    J(i) = tone_objective( ...
        z,m,N,grid(i));
end

[~,ib] = max(J);

i1 = max(1,ib-1);
i2 = min(numel(grid),ib+1);

local_lb = grid(i1);
local_ub = grid(i2);

if local_ub<=local_lb
    nu_hat = grid(ib);
    Jhat = J(ib);
    return;
end

opts = optimset( ...
    'Display','off', ...
    'TolX',cfg.ml_tolx_bins, ...
    'MaxFunEvals',cfg.ml_max_fun_evals);

obj = @(nu) -tone_objective(z,m,N,nu);

[nu_hat,fval] = ...
    fminbnd(obj,local_lb,local_ub,opts);

Jhat = -fval;

end

%% ========================================================================
function J = tone_objective(z,m,N,nu)

v = exp(-1j*2*pi*nu*m/N);

q = sum(z.*v);

J = abs(q).^2;

end

%% ========================================================================
function f = fractional_component(nu)

f = nu-round(nu);

end

%% ========================================================================
function e = fractional_error(a,b)

e = mod((a-b)+0.5,1)-0.5;

end

%% ========================================================================
function e = circular_bin_error(a,b)
% Period-1 difference in DFT-bin frequency coordinate.

e = fractional_error(a,b);

end

%% ========================================================================
function G = global_objective_audit(x,a,cfg)
% Broad oracle diagnostic search in delta coordinate around the strong
% component. Not used as a practical estimator.

z = dechirp_signal(x,a);

N = numel(z);
m = 0:N-1;

d = ...
    -cfg.global_search_halfwidth_bins : ...
    cfg.global_grid_step_bins : ...
    cfg.global_search_halfwidth_bins;

J = zeros(size(d));

for i = 1:numel(d)
    J(i) = tone_objective(z,m,N,d(i));
end

idx = local_peak_indices(J);

% Always include the global grid maximum.
[~,ig] = max(J);
idx = unique([idx(:);ig]);

[~,ord] = sort(J(idx),'descend');
idx = idx(ord);

nkeep = min(cfg.global_top_peak_count,numel(idx));
idx = idx(1:nkeep);

top_delta = zeros(nkeep,1);
top_obj = zeros(nkeep,1);

opts = optimset( ...
    'Display','off', ...
    'TolX',cfg.ml_tolx_bins, ...
    'MaxFunEvals',cfg.ml_max_fun_evals);

for k = 1:nkeep

    ii = idx(k);

    i1 = max(1,ii-1);
    i2 = min(numel(d),ii+1);

    lb = d(i1);
    ub = d(i2);

    if ub<=lb
        top_delta(k) = d(ii);
        top_obj(k) = J(ii);
    else
        obj = @(nu) -tone_objective(z,m,N,nu);
        [nu,fval] = fminbnd(obj,lb,ub,opts);
        top_delta(k) = nu;
        top_obj(k) = -fval;
    end
end

% Re-sort after continuous refinement.
[top_obj,ord] = sort(top_obj,'descend');
top_delta = top_delta(ord);

G = struct();
G.grid_delta_bins = d;
G.grid_objective = J;
G.top_delta_bins = top_delta;
G.top_objective = top_obj;

end

%% ========================================================================
function idx = local_peak_indices(y)

y = y(:);
n = numel(y);

idx = [];

if n==1
    idx = 1;
    return;
end

if y(1)>=y(2)
    idx(end+1,1) = 1; %#ok<AGROW>
end

for i = 2:n-1
    if y(i)>=y(i-1) && y(i)>=y(i+1) && ...
            (y(i)>y(i-1) || y(i)>y(i+1))
        idx(end+1,1) = i; %#ok<AGROW>
    end
end

if y(n)>=y(n-1)
    idx(end+1,1) = n; %#ok<AGROW>
end

if isempty(idx)
    [~,imax] = max(y);
    idx = imax;
end

end

%% ========================================================================
function [rank,dnear] = nearest_peak_branch(delta,peaks)

if isempty(peaks)
    rank = NaN;
    dnear = NaN;
    return;
end

dist = zeros(numel(peaks),1);

for i = 1:numel(peaks)
    dist(i) = abs(circular_bin_error(delta,peaks(i)));
end

[dnear,rank] = min(dist);

end

%% ========================================================================
function S = summarize_mode_switch(T,cfg)

modes = unique(string(T.aperture_mode),'stable');
ratios = unique(T.weak_to_strong_ratio).';

rows = {};

for im = 1:numel(modes)

    for ir = 1:numel(ratios)

        M = T( ...
            string(T.aperture_mode)==modes(im) & ...
            abs(T.weak_to_strong_ratio-ratios(ir))<1e-12,:);

        O = M(M.collapse_outlier==1,:);

        if isempty(O)
            outlier_fraction = 0;
            switch_fraction = NaN;
            nonglobal_fraction = NaN;
            neardeg_fraction = NaN;
            max_trans = max(M.maximum_translation_signal_error);
            max_spread = max(M.wrapped_bias_spread_bins);
        else
            outlier_fraction = height(O)/height(M);
            switch_fraction = mean(O.local_branch_switch);
            nonglobal_fraction = mean(O.any_local_not_global_top1);
            neardeg_fraction = mean(O.near_degenerate_peaks);
            max_trans = max(O.maximum_translation_signal_error);
            max_spread = max(O.wrapped_bias_spread_bins);
        end

        translation_pass = ...
            max_trans <= cfg.translation_signal_error_gate;

        if translation_pass && ...
                outlier_fraction>0 && ...
                (switch_fraction>=0.8 || ...
                 nonglobal_fraction>=0.8)
            branch = ...
                "MODE_SWITCH_EXPLAINS_COLLAPSE_OUTLIERS";
        elseif translation_pass && outlier_fraction==0
            branch = ...
                "NO_HIGH_CONTRAST_COLLAPSE_OUTLIERS";
        elseif ~translation_pass
            branch = ...
                "SIGNAL_TRANSLATION_INVARIANCE_REVIEW";
        else
            branch = ...
                "COLLAPSE_OUTLIER_MECHANISM_NOT_FULLY_RESOLVED";
        end

        rows(end+1,:) = { ... %#ok<AGROW>
            char(modes(im)),ratios(ir),height(M),height(O), ...
            outlier_fraction,max_spread,max_trans, ...
            translation_pass,switch_fraction, ...
            nonglobal_fraction,neardeg_fraction, ...
            char(branch)};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','weak_to_strong_ratio', ...
    'n_physical_states','n_collapse_outlier_states', ...
    'collapse_outlier_fraction', ...
    'maximum_wrapped_bias_spread_bins', ...
    'maximum_translation_signal_error', ...
    'signal_translation_invariance_pass', ...
    'outlier_branch_switch_fraction', ...
    'outlier_local_not_global_fraction', ...
    'outlier_near_degenerate_fraction', ...
    'mechanism_branch'});

end

%% ========================================================================
function B = retie_best_windows(R,cfg)

modes = unique(string(R.aperture_mode),'stable');
etas = unique(R.true_eta_bins).';

rows = {};

for im = 1:numel(modes)

    for ie = 1:numel(etas)

        M = R( ...
            string(R.aperture_mode)==modes(im) & ...
            abs(R.true_eta_bins-etas(ie))<1e-12,:);

        % Lexicographic filtering with explicit tie tolerance.
        candidates = true(height(M),1);

        v = M.median_decision_regret;
        best = min(v(candidates));
        candidates = candidates & ...
            abs(v-best)<=cfg.regret_tie_tolerance;

        v = M.p90_decision_regret;
        best = min(v(candidates));
        candidates = candidates & ...
            abs(v-best)<=cfg.regret_tie_tolerance;

        v = M.mean_decision_regret;
        best = min(v(candidates));
        candidates = candidates & ...
            abs(v-best)<=cfg.regret_tie_tolerance;

        v = M.action_agreement_rate;
        best = max(v(candidates));
        candidates = candidates & ...
            abs(v-best)<=cfg.regret_tie_tolerance;

        idx = find(candidates);

        % Final deterministic tie break: smallest window.
        [~,j] = min(M.window_bins(idx));
        ib = idx(j);

        rows(end+1,:) = { ... %#ok<AGROW>
            char(modes(im)),etas(ie), ...
            M.window_bins(ib), ...
            M.median_decision_regret(ib), ...
            M.p90_decision_regret(ib), ...
            M.mean_decision_regret(ib), ...
            M.action_agreement_rate(ib), ...
            M.false_recenter_rate(ib), ...
            M.missed_recenter_rate(ib), ...
            M.median_E_gate(ib), ...
            M.median_E_binary_oracle(ib), ...
            sum(abs(M.median_decision_regret - ...
                min(M.median_decision_regret)) <= ...
                cfg.regret_tie_tolerance)};
    end
end

B = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','true_eta_bins', ...
    'retied_best_window_bins', ...
    'median_decision_regret', ...
    'p90_decision_regret', ...
    'mean_decision_regret', ...
    'action_agreement_rate', ...
    'false_recenter_rate', ...
    'missed_recenter_rate', ...
    'median_E_gate', ...
    'median_E_binary_oracle', ...
    'n_windows_tied_at_min_median_regret'});

end

%% ========================================================================
function C = compare_old_new_best_windows(old,new)

modes = unique(string(new.aperture_mode),'stable');
etas = unique(new.true_eta_bins).';

rows = {};

for im = 1:numel(modes)

    for ie = 1:numel(etas)

        O = old( ...
            string(old.aperture_mode)==modes(im) & ...
            abs(old.true_eta_bins-etas(ie))<1e-12,:);

        N = new( ...
            string(new.aperture_mode)==modes(im) & ...
            abs(new.true_eta_bins-etas(ie))<1e-12,:);

        if isempty(O) || isempty(N)
            continue;
        end

        rows(end+1,:) = { ... %#ok<AGROW>
            char(modes(im)),etas(ie), ...
            O.min_regret_window_bins(1), ...
            N.retied_best_window_bins(1), ...
            O.p90_regret_at_min_regret_window(1), ...
            N.p90_decision_regret(1), ...
            O.mean_regret_at_min_regret_window(1), ...
            N.mean_decision_regret(1), ...
            O.action_agreement_at_min_regret_window(1), ...
            N.action_agreement_rate(1), ...
            double(O.min_regret_window_bins(1) ~= ...
                N.retied_best_window_bins(1))};
    end
end

C = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','true_eta_bins', ...
    'old_selected_window_bins', ...
    'retied_selected_window_bins', ...
    'old_p90_regret','retied_p90_regret', ...
    'old_mean_regret','retied_mean_regret', ...
    'old_action_agreement','retied_action_agreement', ...
    'window_selection_changed'});

end

%% ========================================================================
function D = build_r1_decision(M,B,cfg)

modes = unique(string(M.aperture_mode),'stable');

rows = {};

for im = 1:numel(modes)

    Q = M(string(M.aperture_mode)==modes(im),:);
    W = B(string(B.aperture_mode)==modes(im),:);

    translation_pass = ...
        all(Q.signal_translation_invariance_pass==1);

    outlier_rows = Q(Q.n_collapse_outlier_states>0,:);

    if isempty(outlier_rows)
        mode_switch_support = NaN;
    else
        numer = sum( ...
            outlier_rows.n_collapse_outlier_states .* ...
            max( ...
                outlier_rows.outlier_branch_switch_fraction, ...
                outlier_rows.outlier_local_not_global_fraction));

        denom = sum( ...
            outlier_rows.n_collapse_outlier_states);

        mode_switch_support = numer/max(denom,1);
    end

    med_p90 = median(W.p90_decision_regret);
    max_p90 = max(W.p90_decision_regret);
    med_agree = median(W.action_agreement_rate);

    if ~translation_pass
        branch = "TRANSLATION_MODEL_REVIEW_REQUIRED";
    elseif ~isnan(mode_switch_support) && ...
            mode_switch_support>=0.8
        branch = "MODE_SWITCH_CONFIRMED_PROCEED_TO_BIAS_AWARE_DECISION";
    else
        branch = "MODE_SWITCH_ONLY_PARTIALLY_CONFIRMED";
    end

    rows(end+1,:) = { ... %#ok<AGROW>
        char(modes(im)),translation_pass, ...
        mode_switch_support, ...
        med_p90,max_p90,med_agree, ...
        char(branch)};
end

D = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode', ...
    'exact_signal_translation_pass', ...
    'collapse_outlier_mode_switch_support', ...
    'retied_median_p90_regret', ...
    'retied_maximum_p90_regret', ...
    'retied_median_action_agreement', ...
    'r1_decision_branch'});

end

%% ========================================================================
function write_summary(out_path,cfg,M,B,C,D)

fid = fopen(fullfile(out_path,'summary.txt'),'w');

fprintf(fid,'EXP009 PA5H-R1 / Mode-Switch + Regret Tie Audit\n');
fprintf(fid,'================================================\n\n');

fprintf(fid,'Purpose\n');
fprintf(fid,'-------\n');
fprintf(fid,['RQ1: determine whether high-contrast eta-collapse outliers ' ...
    'are estimator branch switching rather than failure of the ' ...
    'translation-invariant signal model.\n']);
fprintf(fid,['RQ2: remove the PA5H best-window first-tie artifact.\n\n']);

fprintf(fid,'Mode-switch summary\n');
fprintf(fid,'-------------------\n');

for i=1:height(M)
    fprintf(fid,[ ...
        '%s r=%g states=%d outliers=%d outlierFrac=%g ' ...
        'maxSpread=%g maxTranslationErr=%g ' ...
        'switchFrac=%g nonGlobalFrac=%g nearDegFrac=%g -> %s\n'], ...
        M.aperture_mode{i}, ...
        M.weak_to_strong_ratio(i), ...
        M.n_physical_states(i), ...
        M.n_collapse_outlier_states(i), ...
        M.collapse_outlier_fraction(i), ...
        M.maximum_wrapped_bias_spread_bins(i), ...
        M.maximum_translation_signal_error(i), ...
        M.outlier_branch_switch_fraction(i), ...
        M.outlier_local_not_global_fraction(i), ...
        M.outlier_near_degenerate_fraction(i), ...
        M.mechanism_branch{i});
end

fprintf(fid,'\nRetied best-window summary\n');
fprintf(fid,'--------------------------\n');

for i=1:height(B)
    fprintf(fid,[ ...
        '%s eta=%g L=%d tiesAtMedian=%d medR=%g p90R=%g ' ...
        'meanR=%g agree=%g false=%g miss=%g\n'], ...
        B.aperture_mode{i}, ...
        B.true_eta_bins(i), ...
        B.retied_best_window_bins(i), ...
        B.n_windows_tied_at_min_median_regret(i), ...
        B.median_decision_regret(i), ...
        B.p90_decision_regret(i), ...
        B.mean_decision_regret(i), ...
        B.action_agreement_rate(i), ...
        B.false_recenter_rate(i), ...
        B.missed_recenter_rate(i));
end

if ~isempty(C)
    fprintf(fid,'\nOld -> retied window changes\n');
    fprintf(fid,'----------------------------\n');

    for i=1:height(C)
        if C.window_selection_changed(i)
            fprintf(fid,[ ...
                '%s eta=%g: L %d -> %d, p90 %g -> %g, ' ...
                'agreement %g -> %g\n'], ...
                C.aperture_mode{i}, ...
                C.true_eta_bins(i), ...
                C.old_selected_window_bins(i), ...
                C.retied_selected_window_bins(i), ...
                C.old_p90_regret(i), ...
                C.retied_p90_regret(i), ...
                C.old_action_agreement(i), ...
                C.retied_action_agreement(i));
        end
    end
end

fprintf(fid,'\nR1 final decision\n');
fprintf(fid,'-----------------\n');

for i=1:height(D)
    fprintf(fid,'%s -> %s\n', ...
        D.aperture_mode{i}, ...
        D.r1_decision_branch{i});
end

fprintf(fid,'\nInterpretation discipline\n');
fprintf(fid,'-------------------------\n');
fprintf(fid,['1) Global objective search is an ORACLE DIAGNOSTIC only.\n']);
fprintf(fid,['2) True eta is used only to test exact translation invariance; ' ...
    'it is not available to the practical algorithm.\n']);
fprintf(fid,['3) No PA5G gate threshold is changed.\n']);
fprintf(fid,['4) The re-tie changes summary selection only; it does not ' ...
    'modify any PA5H trial result.\n']);
fprintf(fid,['5) If mode switching is confirmed, the next actual method ' ...
    'stage is PA5I bias-aware decision, followed by realistic errors.\n']);

fclose(fid);

end

%% ========================================================================
function make_figures( ...
    out_path,cfg,T,S,G,M,B,C)

%% Fig 1 — high-contrast collapse spread distribution
fig = figure('Visible',cfg.figure_visible);
hold on;

modes = ["Paper1s","BeamDerived"];
ratios = unique(S.weak_to_strong_ratio).';

xbase = 1:numel(ratios);

for im = 1:numel(modes)
    med = zeros(size(ratios));
    p95 = zeros(size(ratios));

    for ir = 1:numel(ratios)
        Q = S( ...
            string(S.aperture_mode)==modes(im) & ...
            abs(S.weak_to_strong_ratio-ratios(ir))<1e-12,:);

        med(ir) = median(Q.wrapped_bias_spread_bins);
        p95(ir) = local_percentile( ...
            Q.wrapped_bias_spread_bins,95);
    end

    if im==1
        plot(xbase,med,'o-','LineWidth',1.3);
        plot(xbase,p95,'s--','LineWidth',1.1);
    else
        plot(xbase,med,'o-','LineWidth',1.3);
        plot(xbase,p95,'s--','LineWidth',1.1);
    end
end

set(gca,'XTick',xbase, ...
    'XTickLabel',compose('r=%.1f',ratios));

ylabel('Bias spread across true \eta (bins)');
title('EXP009 PA5H-R1 — High-Contrast Collapse Distribution');
legend({'Paper median','Paper p95', ...
        'Beam median','Beam p95'}, ...
        'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig01_highcontrast_collapse_distribution.png'), ...
    'Resolution',180);
close(fig);

%% Fig 2 — exact translation signal error
fig = figure('Visible',cfg.figure_visible);
hold on;

for im = 1:numel(modes)
    Q = T(string(T.aperture_mode)==modes(im),:);
    scatter( ...
        Q.true_eta_bins, ...
        Q.translation_signal_error, ...
        14,'filled');
end

yline(cfg.translation_signal_error_gate,'k--');

xlabel('True fractional-bin offset |\eta|');
ylabel('Oracle-recentered signal mismatch');
title('EXP009 PA5H-R1 — Exact Translation-Invariance Audit');
legend({'Paper1s','BeamDerived','numerical gate'}, ...
    'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig02_exact_translation_signal_error.png'), ...
    'Resolution',180);
close(fig);

%% Fig 3 — outlier mechanism fractions
fig = figure('Visible',cfg.figure_visible);

labels = strings(0);
vals = zeros(0,3);

for i = 1:height(M)
    if M.n_collapse_outlier_states(i)>0
        labels(end+1,1) = ...
            sprintf('%s r=%.1f', ...
                M.aperture_mode{i}, ...
                M.weak_to_strong_ratio(i));

        vals(end+1,:) = [ ...
            M.outlier_branch_switch_fraction(i), ...
            M.outlier_local_not_global_fraction(i), ...
            M.outlier_near_degenerate_fraction(i)];
    end
end

if isempty(vals)
    bar(0,0);
    xticks([]);
else
    bar(vals,'grouped');
    set(gca,'XTick',1:numel(labels), ...
        'XTickLabel',cellstr(labels));
end

ylim([0 1]);
ylabel('Fraction of collapse-outlier states');
title('EXP009 PA5H-R1 — What Explains the Collapse Outliers?');
legend({'Branch switch','Local not global','Near-degenerate top peaks'}, ...
    'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig03_collapse_outlier_mechanism.png'), ...
    'Resolution',180);
close(fig);

%% Fig 4 — example branch switch if available
fig = figure('Visible',cfg.figure_visible);
hold on;

O = S(S.collapse_outlier==1,:);

if isempty(O)
    text(0.5,0.5,'No collapse outlier state found', ...
        'HorizontalAlignment','center');
    xlim([0 1]); ylim([0 1]);
else
    row = O(1,:);

    Q = T( ...
        string(T.aperture_mode)==string(row.aperture_mode{1}) & ...
        abs(T.delta_velocity_mps-row.delta_velocity_mps)<1e-12 & ...
        string(T.strong_velocity_side)== ...
            string(row.strong_velocity_side{1}) & ...
        abs(T.weak_to_strong_ratio-row.weak_to_strong_ratio)<1e-12 & ...
        abs(T.relative_phase_rad-row.relative_phase_rad)<1e-12,:);

    [~,ord] = sort(Q.true_eta_bins);
    Q = Q(ord,:);

    plot(Q.true_eta_bins,Q.wrapped_bias_bins, ...
        'o-','LineWidth',1.3);

    yline(row.global_top1_delta_bins,'k--', ...
        'Global top-1 branch');

    xlabel('True \eta (bins)');
    ylabel('Estimated bias \hat{\eta}-\eta (bins)');
    title(sprintf( ...
        'EXP009 PA5H-R1 — Example Branch Switch (%s, r=%.1f)', ...
        row.aperture_mode{1}, ...
        row.weak_to_strong_ratio));
    grid on;
end

exportgraphics(fig, ...
    fullfile(out_path,'fig04_example_branch_switch.png'), ...
    'Resolution',180);
close(fig);

%% Fig 5 — retied p90 regret
fig = figure('Visible',cfg.figure_visible);
hold on;

for im = 1:numel(modes)
    Q = B(string(B.aperture_mode)==modes(im),:);
    [~,ord] = sort(Q.true_eta_bins);
    Q = Q(ord,:);

    plot(Q.true_eta_bins,Q.p90_decision_regret, ...
        'o-','LineWidth',1.3);
end

xlabel('True fractional-bin offset |\eta|');
ylabel('Retied best-window p90 regret');
title('EXP009 PA5H-R1 — Corrected Best-Window Gate Regret');
legend(cellstr(modes(:)),'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig05_retied_p90_regret.png'), ...
    'Resolution',180);
close(fig);

%% Fig 6 — selected window old vs new
if ~isempty(C)
    fig = figure('Visible',cfg.figure_visible);
    hold on;

    for im = 1:numel(modes)
        Q = C(string(C.aperture_mode)==modes(im),:);
        [~,ord] = sort(Q.true_eta_bins);
        Q = Q(ord,:);

        plot(Q.true_eta_bins,Q.old_selected_window_bins, ...
            'o--','LineWidth',1.0);
        plot(Q.true_eta_bins,Q.retied_selected_window_bins, ...
            's-','LineWidth',1.3);
    end

    xlabel('True fractional-bin offset |\eta|');
    ylabel('Selected window length (bins)');
    title('EXP009 PA5H-R1 — Old vs Lexicographically Retied Window');
    legend({'Paper old','Paper retied', ...
            'Beam old','Beam retied'}, ...
            'Location','best');
    grid on;

    exportgraphics(fig, ...
        fullfile(out_path,'fig06_old_vs_retied_window.png'), ...
        'Resolution',180);
    close(fig);
end

end

%% ========================================================================
function q = local_percentile(x,p)

x = sort(x(:));
x = x(isfinite(x));

if isempty(x)
    q = NaN;
    return;
end

if numel(x)==1
    q = x;
    return;
end

r = 1 + (p/100)*(numel(x)-1);

i1 = floor(r);
i2 = ceil(r);

if i1==i2
    q = x(i1);
else
    w = r-i1;
    q = (1-w)*x(i1)+w*x(i2);
end

end
