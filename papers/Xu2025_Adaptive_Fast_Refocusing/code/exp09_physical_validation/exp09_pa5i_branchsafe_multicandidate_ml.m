function results = exp09_pa5i_branchsafe_multicandidate_ml()
%EXP09_PA5I_BRANCHSAFE_MULTICANDIDATE_ML
% EXP009 / PA5I
%
% Branch-Safe Multi-Candidate Continuous ML
%
% Research question
% -----------------
% PA5H-R1 showed that the signal/objective is translation-equivariant,
% while the practical top-1-coarse -> local-refinement estimator can jump
% to a wrong local branch when the fractional-bin offset changes the
% winning integer DFT sample.
%
% PA5I tests whether small multi-candidate refinement sets eliminate this
% sparse catastrophic failure mode at low extra cost.
%
% Groups
% ------
% G0 OriginalTop1
% G1 Neighbor3
% G2 Top2Coarse
% G3 Top3Coarse
% G4 GlobalReference
%
% The global reference is diagnostic only.
%
% Run:
%   results = exp09_pa5i_branchsafe_multicandidate_ml;

cfg = config_exp09_pa5i_branchsafe_ml();

validate_config(cfg);
run_startup_self_tests(cfg);

%% Paths
this_dir = fileparts(mfilename('fullpath'));
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.output_dir)
    out_path = fullfile( ...
        paper_root,'results','exp09_physical_validation', ...
        'exp09_pa5i_branchsafe_multicandidate_ml');
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

[~,~,Kw] = residual_fm_rates(vw,R0,lambda,cfg);
aw = Kw/(cfg.prf_hz^2);

T_paper = cfg.paper_aperture_time_s;
N_paper = max(32,round(cfg.prf_hz*T_paper));

T_beam = R0*beamwidth_rad/cfg.platform_velocity_mps;
N_beam = max(32,round(cfg.prf_hz*T_beam));

aperture_names = ["Paper1s","BeamDerived"];
N_list = [N_paper,N_beam];

sides = ["LowV","HighV"];

method_names = [ ...
    "G0_OriginalTop1", ...
    "G1_Neighbor3", ...
    "G2_Top2Coarse", ...
    "G3_Top3Coarse", ...
    "G4_GlobalReference"];

%% Pre-compute single-component beta 3-dB width for each aperture/strong rate
width_rows = {};
trial_rows = {};

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

            [~,~,Ks] = residual_fm_rates(vs,R0,lambda,cfg);

            as = Ks/(cfg.prf_hz^2);

            beta_width = estimate_beta_3db_width_bins( ...
                N,as,cfg);

            delta_beta = abs((aw-as)*N);

            Gamma = delta_beta / ...
                max(beta_width,eps);

            width_rows(end+1,:) = { ... %#ok<AGROW>
                char(mode),N,dv,char(side),vs, ...
                as,aw,delta_beta,beta_width,Gamma};

            for ir = 1:numel(cfg.weak_to_strong_ratio)

                rA = cfg.weak_to_strong_ratio(ir);

                for ip = 1:numel(cfg.relative_phase_rad)

                    phi = cfg.relative_phase_rad(ip);

                    for ie = 1:numel(cfg.fractional_bin_offsets)

                        eta = cfg.fractional_bin_offsets(ie);
                        b = eta/N;

                        s = synth_discrete_lfm( ...
                            N,cfg.A_strong,as,b,0);

                        w = synth_discrete_lfm( ...
                            N,rA,aw,b,phi);

                        x = s+w;

                        % G4 global reference
                        G4 = estimate_global_reference( ...
                            x,as,cfg);

                        % G0
                        G0 = estimate_original_top1( ...
                            x,as,cfg);

                        % G1
                        G1 = estimate_neighbor3( ...
                            x,as,cfg);

                        % G2 / G3
                        G2 = estimate_topk_coarse( ...
                            x,as,2,cfg);

                        G3 = estimate_topk_coarse( ...
                            x,as,3,cfg);

                        groups = {G0,G1,G2,G3,G4};

                        for ig = 1:numel(groups)

                            G = groups{ig};

                            branch_error = abs( ...
                                circular_bin_error( ...
                                    G.nu_hat_bins, ...
                                    G4.nu_hat_bins));

                            branch_recovered = ...
                                double(branch_error <= ...
                                    cfg.branch_match_tolerance_bins);

                            catastrophic = ...
                                double(branch_error > ...
                                    cfg.catastrophic_error_threshold_bins);

                            obj_loss = max(0, ...
                                (G4.objective_at_hat - ...
                                 G.objective_at_hat) / ...
                                max(G4.objective_at_hat, ...
                                    cfg.objective_loss_floor));

                            eta_hat = ...
                                fractional_component(G.nu_hat_bins);

                            physical_bias = ...
                                fractional_error(eta_hat,eta);

                            trial_rows(end+1,:) = { ... %#ok<AGROW>
                                char(mode),N,dv,char(side),vs, ...
                                rA,phi,eta, ...
                                as,aw,delta_beta,beta_width,Gamma, ...
                                char(method_names(ig)), ...
                                G.nu_hat_bins,eta_hat,physical_bias, ...
                                G.objective_at_hat, ...
                                G.n_local_refinements, ...
                                G.n_objective_evals, ...
                                G.n_coarse_candidates, ...
                                G.coarse_seed_primary, ...
                                G4.nu_hat_bins, ...
                                branch_error, ...
                                branch_recovered, ...
                                catastrophic,obj_loss};
                        end
                    end
                end
            end
        end
    end
end

width_table = cell2table(width_rows, ...
    'VariableNames',{ ...
    'aperture_mode','azimuth_samples', ...
    'delta_velocity_mps','strong_velocity_side', ...
    'strong_velocity_mps', ...
    'strong_chirp_rate_discrete', ...
    'weak_chirp_rate_discrete', ...
    'delta_beta_bins','beta_3db_width_bins','Gamma'});

trial_table = cell2table(trial_rows, ...
    'VariableNames',{ ...
    'aperture_mode','azimuth_samples', ...
    'delta_velocity_mps','strong_velocity_side', ...
    'strong_velocity_mps', ...
    'weak_to_strong_ratio','relative_phase_rad', ...
    'true_eta_bins', ...
    'strong_chirp_rate_discrete', ...
    'weak_chirp_rate_discrete', ...
    'delta_beta_bins','beta_3db_width_bins','Gamma', ...
    'method','nu_hat_bins','eta_hat_bins', ...
    'physical_bias_bins','objective_at_hat', ...
    'n_local_refinements','n_objective_evals', ...
    'n_coarse_candidates','coarse_seed_primary', ...
    'global_reference_nu_bins', ...
    'branch_error_to_global_bins', ...
    'branch_recovered','catastrophic_branch_failure', ...
    'relative_objective_loss'});

writetable(width_table, ...
    fullfile(out_path,'pa5i_resolution_coordinate.csv'));

writetable(trial_table, ...
    fullfile(out_path,'pa5i_trials.csv'));

%% Summaries
method_summary = summarize_methods(trial_table);

writetable(method_summary, ...
    fullfile(out_path,'pa5i_method_summary.csv'));

contrast_summary = ...
    summarize_by_contrast(trial_table);

writetable(contrast_summary, ...
    fullfile(out_path,'pa5i_by_contrast.csv'));

gamma_summary = ...
    summarize_by_gamma(trial_table);

writetable(gamma_summary, ...
    fullfile(out_path,'pa5i_by_gamma.csv'));

eta_summary = ...
    summarize_by_eta(trial_table);

writetable(eta_summary, ...
    fullfile(out_path,'pa5i_by_eta.csv'));

phase_diagram = ...
    build_phase_diagram(trial_table);

writetable(phase_diagram, ...
    fullfile(out_path,'pa5i_failure_phase_diagram.csv'));

tail_summary = ...
    summarize_catastrophic_tail(trial_table);

writetable(tail_summary, ...
    fullfile(out_path,'pa5i_catastrophic_tail.csv'));

pareto_summary = ...
    build_cost_recovery_pareto(method_summary);

writetable(pareto_summary, ...
    fullfile(out_path,'pa5i_cost_recovery_pareto.csv'));

decision = ...
    build_pa5i_decision(method_summary,tail_summary);

writetable(decision, ...
    fullfile(out_path,'pa5i_decision_summary.csv'));

%% Text + figures
write_summary( ...
    out_path,cfg,method_summary, ...
    tail_summary,pareto_summary,decision);

make_figures( ...
    out_path,cfg,trial_table,method_summary, ...
    contrast_summary,gamma_summary,eta_summary, ...
    phase_diagram,pareto_summary,tail_summary);

%% Save
results = struct();
results.cfg = cfg;
results.width_table = width_table;
results.trial_table = trial_table;
results.method_summary = method_summary;
results.contrast_summary = contrast_summary;
results.gamma_summary = gamma_summary;
results.eta_summary = eta_summary;
results.phase_diagram = phase_diagram;
results.tail_summary = tail_summary;
results.pareto_summary = pareto_summary;
results.decision = decision;

save(fullfile(out_path,'exp09_pa5i_results.mat'), ...
    'results','-v7.3');

fprintf('\n============================================================\n');
fprintf(' EXP009 PA5I / Branch-Safe Multi-Candidate Continuous ML\n');
fprintf('============================================================\n');
disp(method_summary);
disp(tail_summary);
disp(pareto_summary);
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
    'weak_to_strong_ratio','num_relative_phases', ...
    'relative_phase_rad','fractional_bin_offsets', ...
    'local_search_halfwidth_bins', ...
    'local_bracket_points','local_tolx_bins', ...
    'local_max_fun_evals','neighbor_radius', ...
    'topk_list','coarse_candidate_use_localmax', ...
    'global_search_halfwidth_bins', ...
    'global_grid_step_bins','global_tolx_bins', ...
    'global_max_fun_evals','branch_match_tolerance_bins', ...
    'catastrophic_error_threshold_bins', ...
    'objective_loss_floor','beta_width_dense_points', ...
    'beta_width_halfspan_bins','figure_visible', ...
    'output_dir','selftest_translation_gate'};

missing = required(~isfield(cfg,required));

if ~isempty(missing)
    error('EXP009:PA5I:MissingConfigField', ...
        'Missing config field(s): %s', ...
        strjoin(missing,', '));
end

end

%% ========================================================================
function run_startup_self_tests(cfg)

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

    xr = recenter_by_eta(x,eta);

    errs(i) = norm(xr-x0)/max(norm(x0),eps);
end

if max(errs)>cfg.selftest_translation_gate
    error('EXP009:PA5I:TranslationSelfTestFailed', ...
        'Translation self-test failed: max error=%g', ...
        max(errs));
end

% All estimators must return finite results.
eta = 0.125;

x = ...
    synth_discrete_lfm(N,1,aS,eta/N,0) + ...
    synth_discrete_lfm(N,rA,aW,eta/N,phi);

Gs = { ...
    estimate_original_top1(x,aS,cfg), ...
    estimate_neighbor3(x,aS,cfg), ...
    estimate_topk_coarse(x,aS,2,cfg), ...
    estimate_topk_coarse(x,aS,3,cfg), ...
    estimate_global_reference(x,aS,cfg)};

for i = 1:numel(Gs)
    if ~isfinite(Gs{i}.nu_hat_bins) || ...
            ~isfinite(Gs{i}.objective_at_hat)
        error('EXP009:PA5I:EstimatorSelfTestFailed', ...
            'Estimator group %d returned non-finite output.',i);
    end
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
function xr = recenter_by_eta(x,eta)

x = x(:).';

N = numel(x);
m = 0:N-1;

xr = x.*exp(-1j*2*pi*eta*m/N);

end

%% ========================================================================
function z = dechirp_signal(x,a)

x = x(:).';

N = numel(x);
m = 0:N-1;

z = x.*exp(-1j*pi*a*m.^2);

end

%% ========================================================================
function Y = coarse_spectrum(x,a)

z = dechirp_signal(x,a);
Y = fftshift(fft(z));

end

%% ========================================================================
function J = tone_objective(z,m,N,nu)

q = sum(z.*exp(-1j*2*pi*nu*m/N));
J = abs(q).^2;

end

%% ========================================================================
function [nu_hat,Jhat,neval] = ...
    refine_from_seed(z,m,N,seed,cfg)

lb = seed-cfg.local_search_halfwidth_bins;
ub = seed+cfg.local_search_halfwidth_bins;

grid = linspace(lb,ub,cfg.local_bracket_points);
J = zeros(size(grid));

for i = 1:numel(grid)
    J(i) = tone_objective(z,m,N,grid(i));
end

neval = numel(grid);

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
    'TolX',cfg.local_tolx_bins, ...
    'MaxFunEvals',cfg.local_max_fun_evals);

count = 0;
obj = @wrapped_obj;

[nu_hat,fval] = ...
    fminbnd(obj,local_lb,local_ub,opts);

Jhat = -fval;
neval = neval + count;

    function y = wrapped_obj(nu)
        count = count + 1;
        y = -tone_objective(z,m,N,nu);
    end

end

%% ========================================================================
function G = estimate_original_top1(x,a,cfg)

z = dechirp_signal(x,a);

N = numel(z);
m = 0:N-1;

Y = fftshift(fft(z));
[~,i0] = max(abs(Y));

dc = floor(N/2)+1;
k0 = i0-dc;

[nu,Jhat,neval] = ...
    refine_from_seed(z,m,N,k0,cfg);

G = make_estimator_result( ...
    nu,Jhat,1,neval,1,k0);

end

%% ========================================================================
function G = estimate_neighbor3(x,a,cfg)

z = dechirp_signal(x,a);

N = numel(z);
m = 0:N-1;

Y = fftshift(fft(z));
[~,i0] = max(abs(Y));

dc = floor(N/2)+1;
k0 = i0-dc;

r = cfg.neighbor_radius;
seeds = (k0-r):(k0+r);

[nu,Jhat,total_eval] = ...
    refine_multiple_seeds(z,m,N,seeds,cfg);

G = make_estimator_result( ...
    nu,Jhat,numel(seeds),total_eval, ...
    numel(seeds),k0);

end

%% ========================================================================
function G = estimate_topk_coarse(x,a,K,cfg)

z = dechirp_signal(x,a);

N = numel(z);
m = 0:N-1;

Y = fftshift(fft(z));
amp = abs(Y);

dc = floor(N/2)+1;

inds = choose_topk_coarse_indices( ...
    amp,K,cfg);

seeds = inds-dc;

[~,imax] = max(amp);
primary = imax-dc;

[nu,Jhat,total_eval] = ...
    refine_multiple_seeds(z,m,N,seeds,cfg);

G = make_estimator_result( ...
    nu,Jhat,numel(seeds),total_eval, ...
    numel(seeds),primary);

end

%% ========================================================================
function inds = choose_topk_coarse_indices(amp,K,cfg)

amp = amp(:);
N = numel(amp);

if cfg.coarse_candidate_use_localmax
    loc = local_peak_indices(amp);
else
    loc = [];
end

[~,ord_all] = sort(amp,'descend');

inds = [];

if ~isempty(loc)
    [~,ord_loc] = sort(amp(loc),'descend');
    loc = loc(ord_loc);

    nkeep = min(K,numel(loc));
    inds = loc(1:nkeep).';
end

if numel(inds)<K
    for ii = ord_all(:).'
        if ~ismember(ii,inds)
            inds(end+1) = ii; %#ok<AGROW>
            if numel(inds)>=K
                break;
            end
        end
    end
end

inds = inds(1:min(K,N));

end

%% ========================================================================
function [nu_best,Jbest,total_eval] = ...
    refine_multiple_seeds(z,m,N,seeds,cfg)

seeds = unique(seeds(:).');

nu_best = NaN;
Jbest = -Inf;
total_eval = 0;

for i = 1:numel(seeds)

    [nu,J,neval] = ...
        refine_from_seed(z,m,N,seeds(i),cfg);

    total_eval = total_eval + neval;

    if J>Jbest
        Jbest = J;
        nu_best = nu;
    end
end

end

%% ========================================================================
function G = estimate_global_reference(x,a,cfg)

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

[~,ig] = max(J);

i1 = max(1,ig-1);
i2 = min(numel(d),ig+1);

lb = d(i1);
ub = d(i2);

count = 0;

opts = optimset( ...
    'Display','off', ...
    'TolX',cfg.global_tolx_bins, ...
    'MaxFunEvals',cfg.global_max_fun_evals);

obj = @wrapped_obj;

if ub<=lb
    nu_hat = d(ig);
    Jhat = J(ig);
else
    [nu_hat,fval] = ...
        fminbnd(obj,lb,ub,opts);
    Jhat = -fval;
end

neval = numel(d)+count;

G = make_estimator_result( ...
    nu_hat,Jhat,1,neval,1,d(ig));

    function y = wrapped_obj(nu)
        count = count+1;
        y = -tone_objective(z,m,N,nu);
    end

end

%% ========================================================================
function G = make_estimator_result( ...
    nu,Jhat,nrefine,neval,ncand,primary)

G = struct();
G.nu_hat_bins = nu;
G.objective_at_hat = Jhat;
G.n_local_refinements = nrefine;
G.n_objective_evals = neval;
G.n_coarse_candidates = ncand;
G.coarse_seed_primary = primary;

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
function f = fractional_component(nu)

f = nu-round(nu);

end

%% ========================================================================
function e = fractional_error(a,b)

e = mod((a-b)+0.5,1)-0.5;

end

%% ========================================================================
function e = circular_bin_error(a,b)

e = fractional_error(a,b);

end

%% ========================================================================
function W = estimate_beta_3db_width_bins(N,aS,cfg)
% Numerical single-component 3-dB width in the residual-frequency
% / beta-like DFT-bin coordinate after dechirping at the true strong rate.

x = synth_discrete_lfm(N,1,aS,0,0);
z = dechirp_signal(x,aS);

m = 0:N-1;

d = linspace( ...
    -cfg.beta_width_halfspan_bins, ...
     cfg.beta_width_halfspan_bins, ...
     cfg.beta_width_dense_points);

J = zeros(size(d));

for i = 1:numel(d)
    J(i) = tone_objective(z,m,N,d(i));
end

J = J/max(J);

thr = 0.5;

% Left/right crossings around zero.
ic = find(d>=0,1,'first');

left_idx = find(J(1:ic)<=thr,1,'last');
right_rel = find(J(ic:end)<=thr,1,'first');

if isempty(left_idx) || isempty(right_rel)
    W = NaN;
    return;
end

right_idx = ic+right_rel-1;

dl = interp_crossing( ...
    d(left_idx:left_idx+1), ...
    J(left_idx:left_idx+1),thr);

dr = interp_crossing( ...
    d(right_idx-1:right_idx), ...
    J(right_idx-1:right_idx),thr);

W = dr-dl;

end

%% ========================================================================
function x = interp_crossing(x2,y2,thr)

x1 = x2(1);
x2b = x2(2);
y1 = y2(1);
y2b = y2(2);

if abs(y2b-y1)<=eps
    x = 0.5*(x1+x2b);
else
    t = (thr-y1)/(y2b-y1);
    x = x1+t*(x2b-x1);
end

end

%% ========================================================================
function S = summarize_methods(T)

methods = unique(string(T.method),'stable');

rows = {};

for im = 1:numel(methods)

    M = T(string(T.method)==methods(im),:);

    rows(end+1,:) = { ... %#ok<AGROW>
        char(methods(im)),height(M), ...
        mean(M.branch_recovered), ...
        mean(M.catastrophic_branch_failure), ...
        median(M.branch_error_to_global_bins), ...
        local_percentile(M.branch_error_to_global_bins,95), ...
        max(M.branch_error_to_global_bins), ...
        median(M.relative_objective_loss), ...
        local_percentile(M.relative_objective_loss,95), ...
        median(M.n_local_refinements), ...
        median(M.n_objective_evals), ...
        mean(M.n_objective_evals)};
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'method','n_trials', ...
    'branch_recovery_rate', ...
    'catastrophic_failure_rate', ...
    'median_branch_error_bins', ...
    'p95_branch_error_bins', ...
    'maximum_branch_error_bins', ...
    'median_relative_objective_loss', ...
    'p95_relative_objective_loss', ...
    'median_local_refinements', ...
    'median_objective_evals', ...
    'mean_objective_evals'});

end

%% ========================================================================
function S = summarize_by_contrast(T)

methods = unique(string(T.method),'stable');
ratios = unique(T.weak_to_strong_ratio).';

rows = {};

for im = 1:numel(methods)
    for ir = 1:numel(ratios)

        M = T( ...
            string(T.method)==methods(im) & ...
            abs(T.weak_to_strong_ratio-ratios(ir))<1e-12,:);

        rows(end+1,:) = { ... %#ok<AGROW>
            char(methods(im)),ratios(ir),height(M), ...
            mean(M.branch_recovered), ...
            mean(M.catastrophic_branch_failure), ...
            local_percentile(M.branch_error_to_global_bins,95), ...
            mean(M.n_objective_evals)};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'method','weak_to_strong_ratio','n_trials', ...
    'branch_recovery_rate', ...
    'catastrophic_failure_rate', ...
    'p95_branch_error_bins', ...
    'mean_objective_evals'});

end

%% ========================================================================
function S = summarize_by_gamma(T)

methods = unique(string(T.method),'stable');

% Use physical states' unique Gamma values.
gvals = unique(round(T.Gamma,6)).';

rows = {};

for im = 1:numel(methods)
    for ig = 1:numel(gvals)

        M = T( ...
            string(T.method)==methods(im) & ...
            abs(round(T.Gamma,6)-gvals(ig))<1e-12,:);

        if isempty(M)
            continue;
        end

        rows(end+1,:) = { ... %#ok<AGROW>
            char(methods(im)),gvals(ig),height(M), ...
            mean(M.branch_recovered), ...
            mean(M.catastrophic_branch_failure), ...
            local_percentile(M.branch_error_to_global_bins,95)};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'method','Gamma','n_trials', ...
    'branch_recovery_rate', ...
    'catastrophic_failure_rate', ...
    'p95_branch_error_bins'});

end

%% ========================================================================
function S = summarize_by_eta(T)

methods = unique(string(T.method),'stable');
etas = unique(T.true_eta_bins).';

rows = {};

for im = 1:numel(methods)
    for ie = 1:numel(etas)

        M = T( ...
            string(T.method)==methods(im) & ...
            abs(T.true_eta_bins-etas(ie))<1e-12,:);

        rows(end+1,:) = { ... %#ok<AGROW>
            char(methods(im)),etas(ie),height(M), ...
            mean(M.branch_recovered), ...
            mean(M.catastrophic_branch_failure), ...
            local_percentile(M.branch_error_to_global_bins,95)};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'method','true_eta_bins','n_trials', ...
    'branch_recovery_rate', ...
    'catastrophic_failure_rate', ...
    'p95_branch_error_bins'});

end

%% ========================================================================
function P = build_phase_diagram(T)

methods = unique(string(T.method),'stable');
ratios = unique(T.weak_to_strong_ratio).';

% Bin Gamma by exact physical states. Keep continuous Gamma as rows.
gvals = unique(round(T.Gamma,6)).';

rows = {};

for im = 1:numel(methods)
    for ir = 1:numel(ratios)
        for ig = 1:numel(gvals)

            M = T( ...
                string(T.method)==methods(im) & ...
                abs(T.weak_to_strong_ratio-ratios(ir))<1e-12 & ...
                abs(round(T.Gamma,6)-gvals(ig))<1e-12,:);

            if isempty(M)
                continue;
            end

            rows(end+1,:) = { ... %#ok<AGROW>
                char(methods(im)),ratios(ir),gvals(ig), ...
                height(M), ...
                mean(M.catastrophic_branch_failure), ...
                mean(M.branch_recovered)};
        end
    end
end

P = cell2table(rows, ...
    'VariableNames',{ ...
    'method','weak_to_strong_ratio','Gamma','n_trials', ...
    'catastrophic_failure_rate','branch_recovery_rate'});

end

%% ========================================================================
function S = summarize_catastrophic_tail(T)

methods = unique(string(T.method),'stable');
apertures = unique(string(T.aperture_mode),'stable');

rows = {};

for im = 1:numel(methods)
    for ia = 1:numel(apertures)

        M = T( ...
            string(T.method)==methods(im) & ...
            string(T.aperture_mode)==apertures(ia),:);

        C = M(M.catastrophic_branch_failure==1,:);

        if isempty(C)
            minGamma = NaN;
            maxGamma = NaN;
            maxContrast = NaN;
            eta_mode = NaN;
        else
            minGamma = min(C.Gamma);
            maxGamma = max(C.Gamma);
            maxContrast = max(C.weak_to_strong_ratio);
            eta_mode = mode(round(C.true_eta_bins,6));
        end

        rows(end+1,:) = { ... %#ok<AGROW>
            char(methods(im)),char(apertures(ia)), ...
            height(M),height(C), ...
            mean(M.catastrophic_branch_failure), ...
            minGamma,maxGamma,maxContrast,eta_mode};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'method','aperture_mode','n_trials', ...
    'n_catastrophic_failures', ...
    'catastrophic_failure_rate', ...
    'minimum_Gamma_of_failure', ...
    'maximum_Gamma_of_failure', ...
    'maximum_contrast_of_failure', ...
    'modal_eta_of_failure'});

end

%% ========================================================================
function P = build_cost_recovery_pareto(S)

% Exclude G4 from practical Pareto candidates.
M = S(~contains(string(S.method),"GlobalReference"),:);

cost = M.mean_objective_evals;
loss = 1-M.branch_recovery_rate;

isPareto = true(height(M),1);

for i = 1:height(M)
    for j = 1:height(M)
        if i==j
            continue;
        end

        dominates = ...
            cost(j)<=cost(i) && ...
            loss(j)<=loss(i) && ...
            (cost(j)<cost(i) || loss(j)<loss(i));

        if dominates
            isPareto(i)=false;
            break;
        end
    end
end

P = table( ...
    M.method, ...
    M.branch_recovery_rate, ...
    M.catastrophic_failure_rate, ...
    M.mean_objective_evals, ...
    isPareto, ...
    'VariableNames',{ ...
    'method','branch_recovery_rate', ...
    'catastrophic_failure_rate', ...
    'mean_objective_evals','is_pareto'});

end

%% ========================================================================
function D = build_pa5i_decision(S,tail)

% Candidate practical methods.
M = S(~contains(string(S.method),"GlobalReference"),:);

% Desired hierarchy:
% 1) eliminate catastrophic failures;
% 2) maximize branch recovery;
% 3) minimize cost.
zero_fail = M.catastrophic_failure_rate<=1e-12;

if any(zero_fail)
    C = M(zero_fail,:);
else
    minFail = min(M.catastrophic_failure_rate);
    C = M(abs(M.catastrophic_failure_rate-minFail)<=1e-12,:);
end

bestRec = max(C.branch_recovery_rate);
C = C(abs(C.branch_recovery_rate-bestRec)<=1e-12,:);

[~,ib] = min(C.mean_objective_evals);
best = C(ib,:);

if best.catastrophic_failure_rate<=1e-12 && ...
        best.branch_recovery_rate>=0.999
    branch = "BRANCH_SAFE_LOW_COST_METHOD_IDENTIFIED";
elseif best.catastrophic_failure_rate < ...
        S.catastrophic_failure_rate( ...
        string(S.method)=="G0_OriginalTop1")
    branch = "MULTICANDIDATE_REDUCES_BUT_DOES_NOT_ELIMINATE_FAILURE";
else
    branch = "MULTICANDIDATE_NOT_SUFFICIENT";
end

D = table( ...
    best.method, ...
    best.branch_recovery_rate, ...
    best.catastrophic_failure_rate, ...
    best.mean_objective_evals, ...
    string(branch), ...
    'VariableNames',{ ...
    'selected_practical_method', ...
    'branch_recovery_rate', ...
    'catastrophic_failure_rate', ...
    'mean_objective_evals', ...
    'decision_branch'});

end

%% ========================================================================
function write_summary( ...
    out_path,cfg,S,T,P,D)

fid = fopen(fullfile(out_path,'summary.txt'),'w');

fprintf(fid,'EXP009 PA5I / Branch-Safe Multi-Candidate Continuous ML\n');
fprintf(fid,'=======================================================\n\n');

fprintf(fid,'Research question\n');
fprintf(fid,'-----------------\n');
fprintf(fid,['Can a very small number of additional local refinements ' ...
    'eliminate the fence-effect-induced coarse-to-fine branch switching ' ...
    'confirmed in PA5H-R1?\n\n']);

fprintf(fid,'Methods\n');
fprintf(fid,'-------\n');
fprintf(fid,'G0 OriginalTop1\n');
fprintf(fid,'G1 Neighbor3\n');
fprintf(fid,'G2 Top2Coarse\n');
fprintf(fid,'G3 Top3Coarse\n');
fprintf(fid,'G4 GlobalReference (diagnostic only)\n\n');

fprintf(fid,'Method summary\n');
fprintf(fid,'--------------\n');

for i=1:height(S)
    fprintf(fid,[ ...
        '%s recovery=%g catastrophic=%g p95err=%g maxerr=%g ' ...
        'meanEval=%g refinements=%g\n'], ...
        S.method{i}, ...
        S.branch_recovery_rate(i), ...
        S.catastrophic_failure_rate(i), ...
        S.p95_branch_error_bins(i), ...
        S.maximum_branch_error_bins(i), ...
        S.mean_objective_evals(i), ...
        S.median_local_refinements(i));
end

fprintf(fid,'\nCatastrophic-tail summary\n');
fprintf(fid,'-------------------------\n');

for i=1:height(T)
    fprintf(fid,[ ...
        '%s / %s: failures=%d/%d rate=%g ' ...
        'Gamma=[%g,%g] maxContrast=%g etaMode=%g\n'], ...
        T.method{i},T.aperture_mode{i}, ...
        T.n_catastrophic_failures(i), ...
        T.n_trials(i), ...
        T.catastrophic_failure_rate(i), ...
        T.minimum_Gamma_of_failure(i), ...
        T.maximum_Gamma_of_failure(i), ...
        T.maximum_contrast_of_failure(i), ...
        T.modal_eta_of_failure(i));
end

fprintf(fid,'\nPractical cost-recovery Pareto\n');
fprintf(fid,'------------------------------\n');

for i=1:height(P)
    fprintf(fid,[ ...
        '%s recovery=%g catastrophic=%g cost=%g pareto=%d\n'], ...
        P.method{i}, ...
        P.branch_recovery_rate(i), ...
        P.catastrophic_failure_rate(i), ...
        P.mean_objective_evals(i), ...
        P.is_pareto(i));
end

fprintf(fid,'\nDecision\n');
fprintf(fid,'--------\n');
fprintf(fid,'Selected practical method: %s\n', ...
    D.selected_practical_method{1});
fprintf(fid,'Decision branch: %s\n', ...
    D.decision_branch{1});

fprintf(fid,'\nInterpretation discipline\n');
fprintf(fid,'-------------------------\n');
fprintf(fid,['1) G4 is a diagnostic global reference, not a proposed ' ...
    'practical estimator.\n']);
fprintf(fid,['2) No gate threshold is tuned in PA5I.\n']);
fprintf(fid,['3) Branch recovery is evaluated against G4, not against a ' ...
    'pre-assumed true mixture bias.\n']);
fprintf(fid,['4) A practical method must be judged jointly by catastrophic ' ...
    'failure rate and computational cost.\n']);
fprintf(fid,['5) PA5I does not select the strong-removal window.\n']);

fclose(fid);

end

%% ========================================================================
function make_figures( ...
    out_path,cfg,T,S,CS,GS,ES,P,PAR,TS)

methods = unique(string(S.method),'stable');

%% Fig 1 — branch recovery vs cost
fig = figure('Visible',cfg.figure_visible);
hold on;

practical = ~contains(string(S.method),"GlobalReference");

scatter( ...
    S.mean_objective_evals(practical), ...
    S.branch_recovery_rate(practical), ...
    80,'filled');

for i=find(practical).'
    text( ...
        S.mean_objective_evals(i), ...
        S.branch_recovery_rate(i), ...
        ['  ',S.method{i}], ...
        'Interpreter','none');
end

xlabel('Mean objective evaluations');
ylabel('Global-branch recovery rate');
title('EXP009 PA5I — Branch Recovery / Computational Cost');
ylim([0 1.01]);
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig01_branch_recovery_vs_cost.png'), ...
    'Resolution',180);
close(fig);

%% Fig 2 — catastrophic failure vs contrast
fig = figure('Visible',cfg.figure_visible);
hold on;

plot_methods = methods(~contains(methods,"GlobalReference"));
h = gobjects(numel(plot_methods),1);

for im = 1:numel(plot_methods)
    Q = CS(string(CS.method)==plot_methods(im),:);
    [~,o] = sort(Q.weak_to_strong_ratio);
    Q = Q(o,:);

    h(im) = plot( ...
        Q.weak_to_strong_ratio, ...
        Q.catastrophic_failure_rate, ...
        'o-','LineWidth',1.2);
end

xlabel('A_w/A_s');
ylabel('Catastrophic branch-failure rate');
title('EXP009 PA5I — Failure Rate vs Contrast');
legend(h,cellstr(plot_methods(:)), ...
    'Interpreter','none','Location','best');
ylim([0 1]);
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig02_failure_vs_contrast.png'), ...
    'Resolution',180);
close(fig);

%% Fig 3 — catastrophic failure vs eta
fig = figure('Visible',cfg.figure_visible);
hold on;

h = gobjects(numel(plot_methods),1);

for im = 1:numel(plot_methods)
    Q = ES(string(ES.method)==plot_methods(im),:);
    [~,o] = sort(Q.true_eta_bins);
    Q = Q(o,:);

    h(im) = plot( ...
        Q.true_eta_bins, ...
        Q.catastrophic_failure_rate, ...
        'o-','LineWidth',1.2);
end

xlabel('True fractional-bin offset |\eta|');
ylabel('Catastrophic branch-failure rate');
title('EXP009 PA5I — Fence-Offset Failure Profile');
legend(h,cellstr(plot_methods(:)), ...
    'Interpreter','none','Location','best');
ylim([0 1]);
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig03_failure_vs_eta.png'), ...
    'Resolution',180);
close(fig);

%% Fig 4 — G0 phase diagram
make_phase_heatmap( ...
    P,"G0_OriginalTop1",cfg, ...
    fullfile(out_path,'fig04_G0_failure_phase_diagram.png'), ...
    'EXP009 PA5I — G0 Failure Phase Diagram');

%% Fig 5 — G2 phase diagram
make_phase_heatmap( ...
    P,"G2_Top2Coarse",cfg, ...
    fullfile(out_path,'fig05_G2_failure_phase_diagram.png'), ...
    'EXP009 PA5I — G2 Top-2 Failure Phase Diagram');

%% Fig 6 — G1 phase diagram
make_phase_heatmap( ...
    P,"G1_Neighbor3",cfg, ...
    fullfile(out_path,'fig06_G1_failure_phase_diagram.png'), ...
    'EXP009 PA5I — G1 Neighbor-3 Failure Phase Diagram');

%% Fig 7 — p95 branch error vs Gamma
fig = figure('Visible',cfg.figure_visible);
hold on;

for im = 1:numel(plot_methods)
    Q = GS(string(GS.method)==plot_methods(im),:);
    [~,o] = sort(Q.Gamma);
    Q = Q(o,:);

    plot(Q.Gamma,Q.p95_branch_error_bins, ...
        'o-','LineWidth',1.1);
end

xlabel('\Gamma = |\Delta\beta|/W_{\beta,3dB}');
ylabel('95th-percentile branch error (bins)');
title('EXP009 PA5I — Tail Error vs Resolution Coordinate');
legend(cellstr(plot_methods(:)), ...
    'Interpreter','none','Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig07_tail_error_vs_gamma.png'), ...
    'Resolution',180);
close(fig);

%% Fig 8 — practical method Pareto
fig = figure('Visible',cfg.figure_visible);
hold on;

scatter( ...
    PAR.mean_objective_evals, ...
    1-PAR.branch_recovery_rate, ...
    85,'filled');

for i = 1:height(PAR)
    text( ...
        PAR.mean_objective_evals(i), ...
        1-PAR.branch_recovery_rate(i), ...
        ['  ',PAR.method{i}], ...
        'Interpreter','none');
end

xlabel('Mean objective evaluations');
ylabel('Branch failure probability');
title('EXP009 PA5I — Practical Cost / Reliability Pareto');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig08_cost_reliability_pareto.png'), ...
    'Resolution',180);
close(fig);

%% Fig 9 — aperture tail failures
fig = figure('Visible',cfg.figure_visible);

Q = TS(~contains(string(TS.method),"GlobalReference"),:);

method_labels = unique(string(Q.method),'stable');
ap_labels = unique(string(Q.aperture_mode),'stable');

A = zeros(numel(method_labels),numel(ap_labels));

for im = 1:numel(method_labels)
    for ia = 1:numel(ap_labels)
        R = Q( ...
            string(Q.method)==method_labels(im) & ...
            string(Q.aperture_mode)==ap_labels(ia),:);

        if ~isempty(R)
            A(im,ia) = R.catastrophic_failure_rate(1);
        end
    end
end

bar(A,'grouped');
set(gca,'XTick',1:numel(method_labels), ...
    'XTickLabel',cellstr(method_labels));

ylabel('Catastrophic failure rate');
title('EXP009 PA5I — Aperture Robustness');
legend(cellstr(ap_labels(:)),'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig09_aperture_robustness.png'), ...
    'Resolution',180);
close(fig);

end

%% ========================================================================
function make_phase_heatmap(P,method,cfg,outfile,ttl)

Q = P(string(P.method)==method,:);

ratios = unique(Q.weak_to_strong_ratio).';
gvals = unique(Q.Gamma).';

Z = nan(numel(ratios),numel(gvals));

for ir = 1:numel(ratios)
    for ig = 1:numel(gvals)

        R = Q( ...
            abs(Q.weak_to_strong_ratio-ratios(ir))<1e-12 & ...
            abs(Q.Gamma-gvals(ig))<1e-12,:);

        if ~isempty(R)
            Z(ir,ig) = R.catastrophic_failure_rate(1);
        end
    end
end

fig = figure('Visible',cfg.figure_visible);

imagesc(gvals,ratios,Z);
set(gca,'YDir','normal');
colorbar;

xlabel('\Gamma');
ylabel('A_w/A_s');
title(ttl);

exportgraphics(fig,outfile,'Resolution',180);
close(fig);

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
