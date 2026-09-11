function results = exp09_pa5i_r1_gamma_denseeta_tail_audit()
%EXP09_PA5I_R1_GAMMA_DENSEETA_TAIL_AUDIT
%
% EXP009 / PA5I-R1
%
% Three-part audit:
%
%   R1-A  Restore PA4-consistent Gamma.
%   R1-B  Dense eta sweep on PA5I's empirically observed G0 risk states.
%   R1-C  Rare-tail metrics beyond p95.
%
% Required upstream file:
%   results/exp09_physical_validation/
%     exp09_pa5i_branchsafe_multicandidate_ml/pa5i_trials.csv
%
% Run:
%   results = exp09_pa5i_r1_gamma_denseeta_tail_audit;

cfg = config_exp09_pa5i_r1_audit();
validate_config(cfg);

%% Paths
this_dir = fileparts(mfilename('fullpath'));
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

prior_dir = fullfile( ...
    paper_root,'results','exp09_physical_validation', ...
    cfg.prior_pa5i_folder_name);

prior_file = fullfile( ...
    prior_dir,cfg.prior_pa5i_trials_name);

if ~exist(prior_file,'file')
    error('EXP009:PA5IR1:MissingPA5ITrials', ...
        ['Required upstream PA5I trial file was not found:\n%s\n\n' ...
         'Run PA5I first or place this R1 code under the same ' ...
         'Xu2025 paper tree.'],prior_file);
end

if isempty(cfg.output_dir)
    out_path = fullfile( ...
        paper_root,'results','exp09_physical_validation', ...
        'exp09_pa5i_r1_gamma_denseeta_tail_audit');
else
    out_path = cfg.output_dir;
end

if ~exist(out_path,'dir')
    mkdir(out_path);
end

%% Read and validate upstream trials
T0 = readtable(prior_file,'TextType','string');

validate_upstream_table(T0);

%% =======================================================================
% R1-A: restore PA4 Gamma exactly
% ========================================================================
Tcorr = restore_pa4_gamma(T0,cfg);

writetable(Tcorr, ...
    fullfile(out_path, ...
    'pa5i_r1_trials_with_corrected_gamma.csv'));

gamma_state = build_corrected_gamma_state_table(Tcorr);

writetable(gamma_state, ...
    fullfile(out_path, ...
    'pa5i_r1_corrected_gamma_states.csv'));

anchor_audit = build_pa4_anchor_audit(gamma_state,cfg);

writetable(anchor_audit, ...
    fullfile(out_path, ...
    'pa5i_r1_pa4_gamma_anchor_audit.csv'));

if any(~anchor_audit.pass)
    bad = anchor_audit(~anchor_audit.pass,:);
    error('EXP009:PA5IR1:PA4GammaAnchorFailed', ...
        ['PA4 Gamma consistency audit failed for %d anchor(s). ' ...
         'Do not interpret the corrected phase diagram until fixed.'], ...
         height(bad));
end

%% Corrected-Gamma failure phase data
phase_corr = build_corrected_gamma_phase_table(Tcorr);

writetable(phase_corr, ...
    fullfile(out_path, ...
    'pa5i_r1_corrected_gamma_failure_phase.csv'));

%% =======================================================================
% R1-C first: recompute rare-tail metrics on original full PA5I grid
% ========================================================================
tail_original = build_rare_tail_summary(Tcorr,'original_grid',cfg);

writetable(tail_original, ...
    fullfile(out_path, ...
    'pa5i_r1_rare_tail_original_grid.csv'));

%% =======================================================================
% R1-B: derive risk manifold from actual PA5I catastrophic G0 states
% ========================================================================
risk_states = extract_unique_g0_risk_states(Tcorr);

writetable(risk_states, ...
    fullfile(out_path, ...
    'pa5i_r1_dense_eta_risk_states.csv'));

if isempty(risk_states)
    error('EXP009:PA5IR1:NoRiskStates', ...
        ['No G0 catastrophic state was found in the upstream PA5I ' ...
         'trials. PA5I-R1 dense-risk audit has nothing to sweep.']);
end

%% Global-reference acceleration must be validated before dense sweep.
global_validation = validate_dense_global_reference( ...
    risk_states,cfg);

writetable(global_validation, ...
    fullfile(out_path, ...
    'pa5i_r1_global_reference_validation.csv'));

if any(~global_validation.pass)
    error('EXP009:PA5IR1:GlobalReferenceValidationFailed', ...
        ['Moderate-grid global reference did not match the high-' ...
         'resolution reference. Tighten cfg.global_grid_step_bins.']);
end

%% Dense eta sweep
Tdense = run_dense_eta_risk_sweep(risk_states,cfg);

writetable(Tdense, ...
    fullfile(out_path, ...
    'pa5i_r1_dense_eta_trials.csv'));

dense_eta_summary = summarize_dense_eta(Tdense);

writetable(dense_eta_summary, ...
    fullfile(out_path, ...
    'pa5i_r1_dense_eta_failure_profile.csv'));

tail_dense = build_rare_tail_summary(Tdense,'dense_risk',cfg);

writetable(tail_dense, ...
    fullfile(out_path, ...
    'pa5i_r1_rare_tail_dense_risk.csv'));

cost_dense = summarize_dense_cost_reliability(Tdense);

writetable(cost_dense, ...
    fullfile(out_path, ...
    'pa5i_r1_dense_cost_reliability.csv'));

%% Decision
decision = build_r1_decision( ...
    anchor_audit,Tdense,tail_dense,cost_dense,cfg);

writetable(decision, ...
    fullfile(out_path, ...
    'pa5i_r1_decision_summary.csv'));

%% Figures
make_figures( ...
    out_path,cfg,gamma_state,phase_corr, ...
    dense_eta_summary,tail_original,tail_dense, ...
    cost_dense,global_validation);

%% Summary
write_summary( ...
    out_path,cfg,risk_states,anchor_audit, ...
    tail_original,tail_dense,cost_dense,decision);

%% Save
results = struct();
results.cfg = cfg;
results.corrected_trials = Tcorr;
results.gamma_state = gamma_state;
results.anchor_audit = anchor_audit;
results.phase_corr = phase_corr;
results.risk_states = risk_states;
results.global_validation = global_validation;
results.dense_trials = Tdense;
results.dense_eta_summary = dense_eta_summary;
results.tail_original = tail_original;
results.tail_dense = tail_dense;
results.cost_dense = cost_dense;
results.decision = decision;

save(fullfile(out_path,'exp09_pa5i_r1_results.mat'), ...
    'results','-v7.3');

fprintf('\n============================================================\n');
fprintf(' EXP009 PA5I-R1 / Gamma + Dense-Eta + Rare-Tail Audit\n');
fprintf('============================================================\n');
fprintf('Unique G0 risk states: %d\n',height(risk_states));
disp(anchor_audit);
disp(tail_dense);
disp(cost_dense);
disp(decision);
fprintf('Saved to:\n%s\n',out_path);
fprintf('============================================================\n\n');

end

%% ========================================================================
function validate_config(cfg)

required = { ...
    'pa4_beta_width_paper_rad', ...
    'pa4_beta_width_beam_rad', ...
    'pa4_anchor_dv_mps', ...
    'pa4_anchor_paper_high', ...
    'pa4_anchor_beam_high', ...
    'pa4_anchor_relative_tolerance', ...
    'dense_eta_step_bins', ...
    'dense_eta_bins', ...
    'local_search_halfwidth_bins', ...
    'local_bracket_points', ...
    'local_tolx_bins', ...
    'local_max_fun_evals', ...
    'neighbor_radius', ...
    'coarse_candidate_use_localmax', ...
    'global_search_halfwidth_bins', ...
    'global_grid_step_bins', ...
    'global_tolx_bins', ...
    'global_max_fun_evals', ...
    'global_validation_step_bins', ...
    'global_validation_n_states', ...
    'global_validation_tolerance_bins', ...
    'branch_match_tolerance_bins', ...
    'catastrophic_error_threshold_bins', ...
    'objective_loss_floor', ...
    'tail_percentiles', ...
    'prior_pa5i_folder_name', ...
    'prior_pa5i_trials_name', ...
    'figure_visible', ...
    'output_dir'};

missing = required(~isfield(cfg,required));

if ~isempty(missing)
    error('EXP009:PA5IR1:MissingConfigField', ...
        'Missing config field(s): %s',strjoin(missing,', '));
end

end

%% ========================================================================
function validate_upstream_table(T)

required = { ...
    'aperture_mode','azimuth_samples', ...
    'delta_velocity_mps','strong_velocity_side', ...
    'strong_velocity_mps','weak_to_strong_ratio', ...
    'relative_phase_rad','true_eta_bins', ...
    'strong_chirp_rate_discrete', ...
    'weak_chirp_rate_discrete', ...
    'method','nu_hat_bins','objective_at_hat', ...
    'n_local_refinements','n_objective_evals', ...
    'global_reference_nu_bins', ...
    'branch_error_to_global_bins', ...
    'branch_recovered','catastrophic_branch_failure', ...
    'relative_objective_loss'};

missing = required(~ismember(required,T.Properties.VariableNames));

if ~isempty(missing)
    error('EXP009:PA5IR1:MissingUpstreamColumn', ...
        'PA5I trial table is missing column(s): %s', ...
        strjoin(missing,', '));
end

end

%% ========================================================================
function T = restore_pa4_gamma(T,cfg)

aS = T.strong_chirp_rate_discrete;
aW = T.weak_chirp_rate_discrete;

betaS = atan(aS);
betaW = atan(aW);

deltaBeta = abs(betaS-betaW);

width = nan(height(T),1);

isPaper = string(T.aperture_mode)=="Paper1s";
isBeam  = string(T.aperture_mode)=="BeamDerived";

width(isPaper) = cfg.pa4_beta_width_paper_rad;
width(isBeam)  = cfg.pa4_beta_width_beam_rad;

if any(~isfinite(width))
    bad = unique(string(T.aperture_mode(~isfinite(width))));
    error('EXP009:PA5IR1:UnknownApertureMode', ...
        'Unknown aperture mode(s): %s',strjoin(cellstr(bad),', '));
end

T.beta_strong_rad = betaS;
T.beta_weak_rad = betaW;
T.delta_beta_pa4_rad = deltaBeta;
T.beta_width_pa4_rad = width;
T.Gamma_PA4 = deltaBeta./width;

end

%% ========================================================================
function S = build_corrected_gamma_state_table(T)

vars = { ...
    'aperture_mode','azimuth_samples', ...
    'delta_velocity_mps','strong_velocity_side', ...
    'strong_velocity_mps', ...
    'strong_chirp_rate_discrete', ...
    'weak_chirp_rate_discrete', ...
    'beta_strong_rad','beta_weak_rad', ...
    'delta_beta_pa4_rad','beta_width_pa4_rad','Gamma_PA4'};

S = unique(T(:,vars),'rows','stable');

end

%% ========================================================================
function A = build_pa4_anchor_audit(S,cfg)

rows = {};

for ia = 1:2

    if ia==1
        aperture = "Paper1s";
        expected = cfg.pa4_anchor_paper_high;
    else
        aperture = "BeamDerived";
        expected = cfg.pa4_anchor_beam_high;
    end

    for id = 1:numel(cfg.pa4_anchor_dv_mps)

        dv = cfg.pa4_anchor_dv_mps(id);

        M = S( ...
            string(S.aperture_mode)==aperture & ...
            abs(S.delta_velocity_mps-dv)<1e-12 & ...
            string(S.strong_velocity_side)=="HighV",:);

        if isempty(M)
            measured = NaN;
        else
            measured = median(M.Gamma_PA4);
        end

        relerr = abs(measured-expected(id))/max(abs(expected(id)),eps);
        pass = isfinite(relerr) && ...
            relerr<=cfg.pa4_anchor_relative_tolerance;

        rows(end+1,:) = { ... %#ok<AGROW>
            char(aperture),dv,expected(id),measured,relerr,pass};
    end
end

A = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','delta_velocity_mps', ...
    'PA4_expected_Gamma','R1_measured_Gamma', ...
    'relative_error','pass'});

end

%% ========================================================================
function P = build_corrected_gamma_phase_table(T)

methods = unique(string(T.method),'stable');
ratios = unique(T.weak_to_strong_ratio).';
gammas = unique(round(T.Gamma_PA4,6)).';

rows = {};

for im = 1:numel(methods)
    for ir = 1:numel(ratios)
        for ig = 1:numel(gammas)

            M = T( ...
                string(T.method)==methods(im) & ...
                abs(T.weak_to_strong_ratio-ratios(ir))<1e-12 & ...
                abs(round(T.Gamma_PA4,6)-gammas(ig))<1e-12,:);

            if isempty(M)
                continue;
            end

            rows(end+1,:) = { ... %#ok<AGROW>
                char(methods(im)),ratios(ir),gammas(ig), ...
                height(M), ...
                mean(M.catastrophic_branch_failure), ...
                mean(M.branch_recovered)};
        end
    end
end

P = cell2table(rows, ...
    'VariableNames',{ ...
    'method','weak_to_strong_ratio','Gamma_PA4','n_trials', ...
    'catastrophic_failure_rate','branch_recovery_rate'});

end

%% ========================================================================
function R = extract_unique_g0_risk_states(T)

G0 = T( ...
    string(T.method)=="G0_OriginalTop1" & ...
    T.catastrophic_branch_failure==1,:);

vars = { ...
    'aperture_mode','azimuth_samples', ...
    'delta_velocity_mps','strong_velocity_side', ...
    'strong_velocity_mps','weak_to_strong_ratio', ...
    'relative_phase_rad', ...
    'strong_chirp_rate_discrete', ...
    'weak_chirp_rate_discrete', ...
    'beta_strong_rad','beta_weak_rad', ...
    'delta_beta_pa4_rad','beta_width_pa4_rad','Gamma_PA4'};

R = unique(G0(:,vars),'rows','stable');
R.risk_state_id = (1:height(R)).';

R = movevars(R,'risk_state_id','Before',1);

end

%% ========================================================================
function V = validate_dense_global_reference(R,cfg)

nstate = height(R);
ncheck = min(cfg.global_validation_n_states,nstate);

idx = unique(round(linspace(1,nstate,ncheck)));
etas = [0,0.125,0.25,0.375,0.5];

rows = {};

for ii = idx(:).'

    N = R.azimuth_samples(ii);
    aS = R.strong_chirp_rate_discrete(ii);
    aW = R.weak_chirp_rate_discrete(ii);
    rA = R.weak_to_strong_ratio(ii);
    phi = R.relative_phase_rad(ii);

    eta = etas(mod(ii-1,numel(etas))+1);

    x = synth_two_component(N,aS,aW,rA,phi,eta);

    Gfast = estimate_global_reference( ...
        x,aS,cfg.global_grid_step_bins,cfg);

    Ghi = estimate_global_reference( ...
        x,aS,cfg.global_validation_step_bins,cfg);

    err = abs(circular_bin_error( ...
        Gfast.nu_hat_bins,Ghi.nu_hat_bins));

    rows(end+1,:) = { ... %#ok<AGROW>
        R.risk_state_id(ii),eta, ...
        Gfast.nu_hat_bins,Ghi.nu_hat_bins, ...
        err,err<=cfg.global_validation_tolerance_bins};
end

V = cell2table(rows, ...
    'VariableNames',{ ...
    'risk_state_id','eta_bins', ...
    'moderate_global_nu','highres_global_nu', ...
    'difference_bins','pass'});

end

%% ========================================================================
function T = run_dense_eta_risk_sweep(R,cfg)

method_names = [ ...
    "G0_OriginalTop1", ...
    "G1_Neighbor3", ...
    "G2_Top2Coarse", ...
    "G3_Top3Coarse", ...
    "G4_GlobalReference"];

rows = {};

for is = 1:height(R)

    N = R.azimuth_samples(is);
    aS = R.strong_chirp_rate_discrete(is);
    aW = R.weak_chirp_rate_discrete(is);
    rA = R.weak_to_strong_ratio(is);
    phi = R.relative_phase_rad(is);

    for ie = 1:numel(cfg.dense_eta_bins)

        eta = cfg.dense_eta_bins(ie);

        x = synth_two_component(N,aS,aW,rA,phi,eta);

        G4 = estimate_global_reference( ...
            x,aS,cfg.global_grid_step_bins,cfg);

        G0 = estimate_original_top1(x,aS,cfg);
        G1 = estimate_neighbor3(x,aS,cfg);
        G2 = estimate_topk_coarse(x,aS,2,cfg);
        G3 = estimate_topk_coarse(x,aS,3,cfg);

        groups = {G0,G1,G2,G3,G4};

        for ig = 1:numel(groups)

            G = groups{ig};

            err = abs(circular_bin_error( ...
                G.nu_hat_bins,G4.nu_hat_bins));

            recovered = double( ...
                err<=cfg.branch_match_tolerance_bins);

            catastrophic = double( ...
                err>cfg.catastrophic_error_threshold_bins);

            obj_loss = max(0, ...
                (G4.objective_at_hat-G.objective_at_hat) / ...
                max(G4.objective_at_hat, ...
                    cfg.objective_loss_floor));

            rows(end+1,:) = { ... %#ok<AGROW>
                R.risk_state_id(is), ...
                char(R.aperture_mode(is)), ...
                N,R.delta_velocity_mps(is), ...
                char(R.strong_velocity_side(is)), ...
                R.strong_velocity_mps(is), ...
                rA,phi,eta,R.Gamma_PA4(is), ...
                char(method_names(ig)), ...
                G.nu_hat_bins,G4.nu_hat_bins,err, ...
                recovered,catastrophic,obj_loss, ...
                G.n_local_refinements, ...
                G.n_objective_evals};
        end
    end
end

T = cell2table(rows, ...
    'VariableNames',{ ...
    'risk_state_id','aperture_mode','azimuth_samples', ...
    'delta_velocity_mps','strong_velocity_side', ...
    'strong_velocity_mps','weak_to_strong_ratio', ...
    'relative_phase_rad','true_eta_bins','Gamma_PA4', ...
    'method','nu_hat_bins','global_reference_nu_bins', ...
    'branch_error_to_global_bins', ...
    'branch_recovered','catastrophic_branch_failure', ...
    'relative_objective_loss', ...
    'n_local_refinements','n_objective_evals'});

end

%% ========================================================================
function S = summarize_dense_eta(T)

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
            mean(M.catastrophic_branch_failure), ...
            mean(M.branch_recovered), ...
            max(M.branch_error_to_global_bins), ...
            local_percentile(M.branch_error_to_global_bins,99.9)};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'method','true_eta_bins','n_trials', ...
    'catastrophic_failure_rate', ...
    'branch_recovery_rate', ...
    'maximum_branch_error_bins', ...
    'p99_9_branch_error_bins'});

end

%% ========================================================================
function S = build_rare_tail_summary(T,source_name,cfg)

methods = unique(string(T.method),'stable');

rows = {};

for im = 1:numel(methods)

    M = T(string(T.method)==methods(im),:);

    x = M.branch_error_to_global_bins;

    p95  = local_percentile(x,95);
    p99  = local_percentile(x,99);
    p995 = local_percentile(x,99.5);
    p999 = local_percentile(x,99.9);

    rows(end+1,:) = { ... %#ok<AGROW>
        source_name,char(methods(im)),height(M), ...
        p95,p99,p995,p999,max(x), ...
        mean(M.catastrophic_branch_failure), ...
        mean(M.branch_recovered)};
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'source','method','n_trials', ...
    'p95_branch_error_bins', ...
    'p99_branch_error_bins', ...
    'p99_5_branch_error_bins', ...
    'p99_9_branch_error_bins', ...
    'maximum_branch_error_bins', ...
    'catastrophic_failure_rate', ...
    'branch_recovery_rate'});

end

%% ========================================================================
function C = summarize_dense_cost_reliability(T)

methods = unique(string(T.method),'stable');

rows = {};

for im = 1:numel(methods)

    M = T(string(T.method)==methods(im),:);

    rows(end+1,:) = { ... %#ok<AGROW>
        char(methods(im)),height(M), ...
        mean(M.branch_recovered), ...
        mean(M.catastrophic_branch_failure), ...
        mean(M.n_objective_evals), ...
        median(M.n_objective_evals), ...
        median(M.n_local_refinements)};
end

C = cell2table(rows, ...
    'VariableNames',{ ...
    'method','n_trials', ...
    'branch_recovery_rate','catastrophic_failure_rate', ...
    'mean_objective_evals','median_objective_evals', ...
    'median_local_refinements'});

end

%% ========================================================================
function D = build_r1_decision( ...
    A,Tdense,tail_dense,cost_dense,cfg)

gamma_pass = all(A.pass);

G1 = Tdense(string(Tdense.method)=="G1_Neighbor3",:);

g1_fail = mean(G1.catastrophic_branch_failure);
g1_max = max(G1.branch_error_to_global_bins);
g1_recovery = mean(G1.branch_recovered);

G0cost = cost_dense.mean_objective_evals( ...
    string(cost_dense.method)=="G0_OriginalTop1");

G1cost = cost_dense.mean_objective_evals( ...
    string(cost_dense.method)=="G1_Neighbor3");

G4cost = cost_dense.mean_objective_evals( ...
    string(cost_dense.method)=="G4_GlobalReference");

g1_over_g0 = G1cost/G0cost;
g1_over_g4 = G1cost/G4cost;

if gamma_pass && ...
        g1_fail==0 && ...
        g1_max<=cfg.branch_match_tolerance_bins

    branch = ...
        "PA5I_CONFIRMED_PROCEED_TO_PA5J_ADAPTIVE_CONFIDENCE_GATE";

elseif gamma_pass && ...
        g1_fail < mean(Tdense( ...
        string(Tdense.method)=="G0_OriginalTop1",:). ...
        catastrophic_branch_failure)

    branch = ...
        "NEIGHBOR3_REDUCES_BUT_DOES_NOT_ELIMINATE_DENSE_FENCE_FAILURE";

else
    branch = ...
        "PA5I_REQUIRES_METHOD_REVISION_BEFORE_PA5J";
end

D = table( ...
    gamma_pass,g1_recovery,g1_fail,g1_max, ...
    g1_over_g0,g1_over_g4,string(branch), ...
    'VariableNames',{ ...
    'pa4_gamma_consistency_pass', ...
    'G1_dense_branch_recovery_rate', ...
    'G1_dense_catastrophic_failure_rate', ...
    'G1_dense_max_branch_error_bins', ...
    'G1_cost_over_G0', ...
    'G1_cost_over_G4', ...
    'decision_branch'});

end

%% ========================================================================
function x = synth_two_component(N,aS,aW,rA,phi,eta)

b = eta/N;

s = synth_discrete_lfm(N,1,aS,b,0);
w = synth_discrete_lfm(N,rA,aW,b,phi);

x = s+w;

end

%% ========================================================================
function x = synth_discrete_lfm(N,A,a,b,phi)

m = 0:N-1;

x = A.*exp(1j*2*pi*( ...
    0.5*a*m.^2+b*m)+1j*phi);

x = x(:).';

end

%% ========================================================================
function z = dechirp_signal(x,a)

x = x(:).';

N = numel(x);
m = 0:N-1;

z = x.*exp(-1j*pi*a*m.^2);

end

%% ========================================================================
function J = tone_objective(z,m,N,nu)

q = sum(z.*exp(-1j*2*pi*nu*m/N));
J = abs(q).^2;

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

[nu,Jhat,neval] = refine_from_seed(z,m,N,k0,cfg);

G = make_result(nu,Jhat,1,neval);

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

seeds = (k0-cfg.neighbor_radius):(k0+cfg.neighbor_radius);

[nu,Jhat,neval] = ...
    refine_multiple_seeds(z,m,N,seeds,cfg);

G = make_result(nu,Jhat,numel(seeds),neval);

end

%% ========================================================================
function G = estimate_topk_coarse(x,a,K,cfg)

z = dechirp_signal(x,a);
N = numel(z);
m = 0:N-1;

Y = fftshift(fft(z));
amp = abs(Y);

dc = floor(N/2)+1;

inds = choose_topk_coarse_indices(amp,K,cfg);
seeds = inds-dc;

[nu,Jhat,neval] = ...
    refine_multiple_seeds(z,m,N,seeds,cfg);

G = make_result(nu,Jhat,numel(seeds),neval);

end

%% ========================================================================
function G = estimate_global_reference(x,a,grid_step,cfg)

z = dechirp_signal(x,a);
N = numel(z);
m = 0:N-1;

d = ...
    -cfg.global_search_halfwidth_bins : ...
    grid_step : ...
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

if ub<=lb
    nu_hat = d(ig);
    Jhat = J(ig);
else
    [nu_hat,fval] = fminbnd(@wrapped_obj,lb,ub,opts);
    Jhat = -fval;
end

G = make_result( ...
    nu_hat,Jhat,1,numel(d)+count);

    function y = wrapped_obj(nu)
        count = count+1;
        y = -tone_objective(z,m,N,nu);
    end

end

%% ========================================================================
function [nu_hat,Jhat,neval] = refine_from_seed(z,m,N,seed,cfg)

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

count = 0;

opts = optimset( ...
    'Display','off', ...
    'TolX',cfg.local_tolx_bins, ...
    'MaxFunEvals',cfg.local_max_fun_evals);

[nu_hat,fval] = ...
    fminbnd(@wrapped_obj,local_lb,local_ub,opts);

Jhat = -fval;
neval = neval+count;

    function y = wrapped_obj(nu)
        count = count+1;
        y = -tone_objective(z,m,N,nu);
    end

end

%% ========================================================================
function [nu_best,Jbest,total_eval] = ...
    refine_multiple_seeds(z,m,N,seeds,cfg)

seeds = unique(seeds(:).');

nu_best = NaN;
Jbest = -Inf;
total_eval = 0;

for i = 1:numel(seeds)

    [nu,J,neval] = refine_from_seed( ...
        z,m,N,seeds(i),cfg);

    total_eval = total_eval+neval;

    if J>Jbest
        Jbest = J;
        nu_best = nu;
    end
end

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
function G = make_result(nu,J,nref,neval)

G = struct();
G.nu_hat_bins = nu;
G.objective_at_hat = J;
G.n_local_refinements = nref;
G.n_objective_evals = neval;

end

%% ========================================================================
function e = circular_bin_error(a,b)

e = mod((a-b)+0.5,1)-0.5;

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

r = 1+(p/100)*(numel(x)-1);
i1 = floor(r);
i2 = ceil(r);

if i1==i2
    q = x(i1);
else
    w = r-i1;
    q = (1-w)*x(i1)+w*x(i2);
end

end

%% ========================================================================
function make_figures( ...
    out_path,cfg,Gstate,P,DenseEta,TailOrig,TailDense, ...
    CostDense,GlobalVal)

%% Fig 1 — PA4-consistent Gamma
fig = figure('Visible',cfg.figure_visible);
hold on;

apertures = ["Paper1s","BeamDerived"];
sides = ["LowV","HighV"];

h = gobjects(4,1);
labels = strings(4,1);
ih = 0;

for ia = 1:numel(apertures)
    for is = 1:numel(sides)

        M = Gstate( ...
            string(Gstate.aperture_mode)==apertures(ia) & ...
            string(Gstate.strong_velocity_side)==sides(is),:);

        [~,u] = unique(M.delta_velocity_mps,'stable');
        M = M(u,:);
        [~,o] = sort(M.delta_velocity_mps);
        M = M(o,:);

        ih = ih+1;
        h(ih) = plot( ...
            M.delta_velocity_mps,M.Gamma_PA4, ...
            'o-','LineWidth',1.2);

        labels(ih) = apertures(ia)+" "+sides(is);
    end
end

yline(0.5,'--');
yline(1.5,':');

xlabel('\Delta v (m/s)');
ylabel('\Gamma = |\Delta\beta|/W_{\beta,3dB}');
title('EXP009 PA5I-R1 — Restored PA4 Resolution Coordinate');
legend(h,cellstr(labels),'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig01_restored_pa4_gamma.png'), ...
    'Resolution',180);
close(fig);

%% Fig 2 — corrected G0 phase diagram
make_phase_heatmap(P,"G0_OriginalTop1",cfg, ...
    fullfile(out_path,'fig02_G0_corrected_gamma_phase.png'), ...
    'EXP009 PA5I-R1 — G0 Failure Phase Diagram (PA4 \Gamma)');

%% Fig 3 — corrected G1 phase diagram
make_phase_heatmap(P,"G1_Neighbor3",cfg, ...
    fullfile(out_path,'fig03_G1_corrected_gamma_phase.png'), ...
    'EXP009 PA5I-R1 — G1 Failure Phase Diagram (PA4 \Gamma)');

%% Fig 4 — dense eta failure profile
fig = figure('Visible',cfg.figure_visible);
hold on;

methods = ["G0_OriginalTop1","G1_Neighbor3", ...
           "G2_Top2Coarse","G3_Top3Coarse"];

h = gobjects(numel(methods),1);

for im = 1:numel(methods)
    M = DenseEta(string(DenseEta.method)==methods(im),:);
    [~,o] = sort(M.true_eta_bins);
    M = M(o,:);

    h(im) = plot( ...
        M.true_eta_bins,M.catastrophic_failure_rate, ...
        '-','LineWidth',1.3);
end

xlabel('True fractional-bin offset |\eta|');
ylabel('Catastrophic branch-failure rate');
title('EXP009 PA5I-R1 — Dense Fence-Offset Failure Profile');
legend(h,cellstr(methods),'Interpreter','none','Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig04_dense_eta_failure_profile.png'), ...
    'Resolution',180);
close(fig);

%% Fig 5 — dense eta maximum branch error
fig = figure('Visible',cfg.figure_visible);
hold on;

for im = 1:numel(methods)
    M = DenseEta(string(DenseEta.method)==methods(im),:);
    [~,o] = sort(M.true_eta_bins);
    M = M(o,:);

    plot( ...
        M.true_eta_bins,M.maximum_branch_error_bins, ...
        '-','LineWidth',1.2);
end

yline(cfg.branch_match_tolerance_bins,'--');

xlabel('True fractional-bin offset |\eta|');
ylabel('Maximum branch error (bins)');
title('EXP009 PA5I-R1 — Dense-Eta Worst-Case Branch Error');
legend(cellstr(methods),'Interpreter','none','Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig05_dense_eta_max_branch_error.png'), ...
    'Resolution',180);
close(fig);

%% Fig 6 — rare tail original grid
plot_tail_bars( ...
    TailOrig,cfg, ...
    fullfile(out_path,'fig06_rare_tail_original_grid.png'), ...
    'EXP009 PA5I-R1 — Rare Tail on Original PA5I Grid');

%% Fig 7 — rare tail dense risk
plot_tail_bars( ...
    TailDense,cfg, ...
    fullfile(out_path,'fig07_rare_tail_dense_risk.png'), ...
    'EXP009 PA5I-R1 — Rare Tail on Dense Risk Sweep');

%% Fig 8 — dense cost reliability
fig = figure('Visible',cfg.figure_visible);
hold on;

practical = ~contains(string(CostDense.method),"GlobalReference");

scatter( ...
    CostDense.mean_objective_evals(practical), ...
    CostDense.catastrophic_failure_rate(practical), ...
    85,'filled');

idx = find(practical).';
for i = idx
    text( ...
        CostDense.mean_objective_evals(i), ...
        CostDense.catastrophic_failure_rate(i), ...
        ['  ',CostDense.method{i}], ...
        'Interpreter','none');
end

xlabel('Mean objective evaluations');
ylabel('Catastrophic branch-failure rate');
title('EXP009 PA5I-R1 — Dense-Risk Cost / Reliability');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig08_dense_cost_reliability.png'), ...
    'Resolution',180);
close(fig);

%% Fig 9 — global reference cross-check
fig = figure('Visible',cfg.figure_visible);

scatter( ...
    GlobalVal.highres_global_nu, ...
    GlobalVal.moderate_global_nu, ...
    55,'filled');

hold on;

lo = min([ ...
    GlobalVal.highres_global_nu; ...
    GlobalVal.moderate_global_nu]);

hi = max([ ...
    GlobalVal.highres_global_nu; ...
    GlobalVal.moderate_global_nu]);

plot([lo hi],[lo hi],'--');

xlabel('High-resolution global reference');
ylabel('Moderate-grid global reference');
title('EXP009 PA5I-R1 — Global Reference Cross-Check');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig09_global_reference_crosscheck.png'), ...
    'Resolution',180);
close(fig);

end

%% ========================================================================
function make_phase_heatmap(P,method,cfg,outfile,ttl)

Q = P(string(P.method)==method,:);

ratios = unique(Q.weak_to_strong_ratio).';
gammas = unique(Q.Gamma_PA4).';

Z = nan(numel(ratios),numel(gammas));

for ir = 1:numel(ratios)
    for ig = 1:numel(gammas)

        M = Q( ...
            abs(Q.weak_to_strong_ratio-ratios(ir))<1e-12 & ...
            abs(Q.Gamma_PA4-gammas(ig))<1e-12,:);

        if ~isempty(M)
            Z(ir,ig) = M.catastrophic_failure_rate(1);
        end
    end
end

fig = figure('Visible',cfg.figure_visible);

imagesc(gammas,ratios,Z);
set(gca,'YDir','normal');
colorbar;

xlabel('\Gamma = |\Delta\beta|/W_{\beta,3dB}');
ylabel('A_w/A_s');
title(ttl);

exportgraphics(fig,outfile,'Resolution',180);
close(fig);

end

%% ========================================================================
function plot_tail_bars(T,cfg,outfile,ttl)

methods = string(T.method);
P = [ ...
    T.p95_branch_error_bins, ...
    T.p99_branch_error_bins, ...
    T.p99_5_branch_error_bins, ...
    T.p99_9_branch_error_bins, ...
    T.maximum_branch_error_bins];

fig = figure('Visible',cfg.figure_visible);

bar(P,'grouped');

set(gca,'XTick',1:height(T), ...
    'XTickLabel',cellstr(methods));

ylabel('Branch error (bins)');
title(ttl);
legend({'p95','p99','p99.5','p99.9','max'}, ...
    'Location','best');
grid on;

exportgraphics(fig,outfile,'Resolution',180);
close(fig);

end

%% ========================================================================
function write_summary( ...
    out_path,cfg,R,A,TailOrig,TailDense,Cost,D)

fid = fopen(fullfile(out_path,'summary.txt'),'w');

fprintf(fid,'EXP009 PA5I-R1\n');
fprintf(fid,'Gamma consistency + dense eta + rare-tail audit\n');
fprintf(fid,'================================================\n\n');

fprintf(fid,'R1-A / PA4 Gamma consistency\n');
fprintf(fid,'----------------------------\n');
fprintf(fid,'Paper1s W_beta,3dB = %.8g rad\n', ...
    cfg.pa4_beta_width_paper_rad);
fprintf(fid,'BeamDerived W_beta,3dB = %.8g rad\n\n', ...
    cfg.pa4_beta_width_beam_rad);

for i=1:height(A)
    fprintf(fid,[ ...
        '%s dv=%g expected=%g measured=%g relerr=%g pass=%d\n'], ...
        A.aperture_mode{i}, ...
        A.delta_velocity_mps(i), ...
        A.PA4_expected_Gamma(i), ...
        A.R1_measured_Gamma(i), ...
        A.relative_error(i), ...
        A.pass(i));
end

fprintf(fid,'\nR1-B / dense eta risk audit\n');
fprintf(fid,'---------------------------\n');
fprintf(fid,'Unique upstream G0 risk states = %d\n',height(R));
fprintf(fid,'Dense eta step = %g bins\n\n',cfg.dense_eta_step_bins);

for i=1:height(Cost)
    fprintf(fid,[ ...
        '%s recovery=%g catastrophic=%g meanEval=%g\n'], ...
        Cost.method{i}, ...
        Cost.branch_recovery_rate(i), ...
        Cost.catastrophic_failure_rate(i), ...
        Cost.mean_objective_evals(i));
end

fprintf(fid,'\nR1-C / rare tail\n');
fprintf(fid,'----------------\n');
fprintf(fid,'Original-grid summary:\n');
for i=1:height(TailOrig)
    fprintf(fid,[ ...
        '%s p95=%g p99=%g p99.5=%g p99.9=%g max=%g Pcat=%g\n'], ...
        TailOrig.method{i}, ...
        TailOrig.p95_branch_error_bins(i), ...
        TailOrig.p99_branch_error_bins(i), ...
        TailOrig.p99_5_branch_error_bins(i), ...
        TailOrig.p99_9_branch_error_bins(i), ...
        TailOrig.maximum_branch_error_bins(i), ...
        TailOrig.catastrophic_failure_rate(i));
end

fprintf(fid,'\nDense-risk summary:\n');
for i=1:height(TailDense)
    fprintf(fid,[ ...
        '%s p95=%g p99=%g p99.5=%g p99.9=%g max=%g Pcat=%g\n'], ...
        TailDense.method{i}, ...
        TailDense.p95_branch_error_bins(i), ...
        TailDense.p99_branch_error_bins(i), ...
        TailDense.p99_5_branch_error_bins(i), ...
        TailDense.p99_9_branch_error_bins(i), ...
        TailDense.maximum_branch_error_bins(i), ...
        TailDense.catastrophic_failure_rate(i));
end

fprintf(fid,'\nDecision\n');
fprintf(fid,'--------\n');
fprintf(fid,'PA4 Gamma consistency pass = %d\n', ...
    D.pa4_gamma_consistency_pass(1));
fprintf(fid,'G1 dense recovery = %g\n', ...
    D.G1_dense_branch_recovery_rate(1));
fprintf(fid,'G1 dense catastrophic rate = %g\n', ...
    D.G1_dense_catastrophic_failure_rate(1));
fprintf(fid,'G1 dense max branch error = %g bins\n', ...
    D.G1_dense_max_branch_error_bins(1));
fprintf(fid,'G1/G0 cost ratio = %g\n', ...
    D.G1_cost_over_G0(1));
fprintf(fid,'G1/G4 cost ratio = %g\n', ...
    D.G1_cost_over_G4(1));
fprintf(fid,'Decision branch = %s\n', ...
    D.decision_branch{1});

fprintf(fid,'\nInterpretation discipline\n');
fprintf(fid,'-------------------------\n');
fprintf(fid,['1) The corrected Gamma is the PA4 beta-coordinate Gamma, ' ...
    'not the PA5I frequency-bin surrogate.\n']);
fprintf(fid,['2) Dense eta is run only on the empirically observed G0 ' ...
    'risk manifold from PA5I.\n']);
fprintf(fid,['3) Zero dense-risk failure supports branch safety on this ' ...
    'tested risk manifold; it is not a proof for arbitrary parameters.\n']);
fprintf(fid,['4) p95 alone is not accepted as a rare-tail reliability ' ...
    'metric in this experiment.\n']);

fclose(fid);

end
