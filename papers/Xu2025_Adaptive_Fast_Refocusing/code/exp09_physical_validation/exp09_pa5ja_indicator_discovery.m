function results = exp09_pa5ja_indicator_discovery()
%EXP09_PA5JA_INDICATOR_DISCOVERY
%
% EXP009 / PA5J-A
% Internal Unreliability Indicator Discovery
%
% Research question
% -----------------
% Can the original G0 Top-1 estimator internally recognize states that
% are vulnerable to catastrophic branch switching, WITHOUT using the
% global reference and WITHOUT already running Neighbor-3?
%
% This is a discovery experiment, not a gate-design experiment.
%
% Candidate features
% ------------------
% Cost class 0 -- coarse FFT only:
%   neighbor_ratio
%   neighbor_margin
%   lr_asymmetry
%   threebin_central_fraction
%   fivebin_peak_fraction
%   local_entropy5
%   coarse_second_ratio
%   coarse_second_gap
%   second_localmax_ratio
%   remote_competitor_ratio
%   plateau_count90
%   plateau_count95
%
% Cost class 1 -- quantities already available after G0:
%   refine_abs_displacement
%   refine_boundary_fraction
%   refinement_gain_rel
%
% Cost class 2 -- only two extra local objective evaluations:
%   refined_curvature_norm
%   refined_lr_asymmetry
%
% Labels
% ------
% Catastrophic branch failure is inherited from PA5I / PA5I-R1.
% Global-reference quantities are NEVER included in feature inputs.
%
% Two evaluation domains are kept separate:
%   1) original PA5I grid  -- realistic base rate;
%   2) PA5I-R1 dense risk -- stress-test manifold.
%
% Run:
%   results = exp09_pa5ja_indicator_discovery;

cfg = config_exp09_pa5ja_indicator_discovery();
validate_config(cfg);

%% Paths
this_dir = fileparts(mfilename('fullpath'));
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

pa5i_file = fullfile( ...
    paper_root,'results','exp09_physical_validation', ...
    cfg.pa5i_folder_name,cfg.pa5i_trials_name);

dense_file = fullfile( ...
    paper_root,'results','exp09_physical_validation', ...
    cfg.pa5i_r1_folder_name,cfg.pa5i_r1_dense_trials_name);

risk_states_file = fullfile( ...
    paper_root,'results','exp09_physical_validation', ...
    cfg.pa5i_r1_folder_name,cfg.pa5i_r1_risk_states_name);

if ~exist(pa5i_file,'file')
    error('EXP009:PA5JA:MissingPA5I', ...
        'Required PA5I file not found:\n%s',pa5i_file);
end

if ~exist(dense_file,'file')
    error('EXP009:PA5JA:MissingDenseR1', ...
        'Required PA5I-R1 dense file not found:\n%s',dense_file);
end

if ~exist(risk_states_file,'file')
    error('EXP009:PA5JA:MissingRiskStatesR1', ...
        ['PA5I-R1 dense trials intentionally do not repeat the chirp-rate ' ...
         'physics in every row. The companion risk-state table is required:\n%s'], ...
        risk_states_file);
end

if isempty(cfg.output_dir)
    out_path = fullfile( ...
        paper_root,'results','exp09_physical_validation', ...
        'exp09_pa5ja_indicator_discovery');
else
    out_path = cfg.output_dir;
end

if ~exist(out_path,'dir')
    mkdir(out_path);
end

%% Read upstream data
Tbase_all = readtable(pa5i_file,'TextType','string');
Tdense_all = readtable(dense_file,'TextType','string');
Trisk = readtable(risk_states_file,'TextType','string');

% File-level schema checks: validate each CSV against how PA5I/PA5I-R1
% actually stores it.
validate_upstream_base(Tbase_all);
validate_upstream_dense_storage(Tdense_all);
validate_risk_state_table(Trisk);

% PA5I-R1 uses a normalized schema:
%   dense_eta_trials.csv      -> repeated trial/result quantities
%   dense_eta_risk_states.csv -> one copy of physical chirp parameters
% Reconstruct the consumer table by risk_state_id.
Tdense_all = enrich_dense_with_risk_state_physics(Tdense_all,Trisk);

% Consumer-level contract: every field used by indicator extraction must
% exist after normalization. This is deliberately separate from the
% file-level schema validation to prevent this class of bug recurring.
validate_indicator_input_table(Tbase_all,'PA5I original');
validate_indicator_input_table(Tdense_all,'PA5I-R1 dense (enriched)');

% One row per trial: use G0 only.
Tbase = Tbase_all(string(Tbase_all.method)=="G0_OriginalTop1",:);
Tdense = Tdense_all(string(Tdense_all.method)=="G0_OriginalTop1",:);

if isempty(Tbase) || isempty(Tdense)
    error('EXP009:PA5JA:EmptyG0', ...
        'G0_OriginalTop1 rows were not found in an upstream table.');
end

%% Extract internal indicators and audit exact reconstruction
[Fbase,recon_base] = extract_indicator_table( ...
    Tbase,"original_grid",cfg);

[Fdense,recon_dense] = extract_indicator_table( ...
    Tdense,"dense_risk",cfg);

writetable(Fbase, ...
    fullfile(out_path,'pa5ja_indicator_trials_original.csv'));

writetable(Fdense, ...
    fullfile(out_path,'pa5ja_indicator_trials_dense_risk.csv'));

recon = [recon_base;recon_dense];

writetable(recon, ...
    fullfile(out_path,'pa5ja_reconstruction_audit.csv'));

if any(~recon.pass)
    error('EXP009:PA5JA:ReconstructionMismatch', ...
        ['PA5J-A reconstructed G0 does not match upstream PA5I. ' ...
         'Do not interpret indicator results until fixed.']);
end

%% Candidate list and cost classes
[feature_names,cost_class] = candidate_features();

%% Univariate, threshold-free discovery metrics
summary = build_indicator_summary( ...
    Fbase,Fdense,feature_names,cost_class,cfg);

writetable(summary, ...
    fullfile(out_path,'pa5ja_indicator_summary.csv'));

%% Fixed trigger-fraction capture curves
capture = build_capture_table( ...
    Fbase,Fdense,summary,cfg);

writetable(capture, ...
    fullfile(out_path,'pa5ja_failure_capture_curves.csv'));

%% Aperture robustness using ORIGINAL risk direction
aperture = build_aperture_robustness( ...
    Fbase,Fdense,summary);

writetable(aperture, ...
    fullfile(out_path,'pa5ja_aperture_robustness.csv'));

%% Contrast and Gamma interpretation -- contextual, not gate features
context = build_context_summary(Fbase,Fdense);

writetable(context, ...
    fullfile(out_path,'pa5ja_context_failure_summary.csv'));

%% Shortlist
shortlist = build_shortlist(summary,cfg);

writetable(shortlist, ...
    fullfile(out_path,'pa5ja_indicator_shortlist.csv'));

%% Decision
decision = build_decision(summary,shortlist,recon,cfg);

writetable(decision, ...
    fullfile(out_path,'pa5ja_decision_summary.csv'));

%% Figures
make_figures( ...
    out_path,cfg,Fbase,Fdense,summary,capture, ...
    aperture,context,shortlist);

%% Summary
write_summary( ...
    out_path,cfg,Fbase,Fdense,summary, ...
    shortlist,decision,recon);

%% Save
results = struct();
results.cfg = cfg;
results.original = Fbase;
results.dense_risk = Fdense;
results.reconstruction_audit = recon;
results.indicator_summary = summary;
results.capture = capture;
results.aperture_robustness = aperture;
results.context = context;
results.shortlist = shortlist;
results.decision = decision;

save(fullfile(out_path,'exp09_pa5ja_results.mat'), ...
    'results','-v7.3');

fprintf('\n============================================================\n');
fprintf(' EXP009 PA5J-A / Internal Unreliability Indicator Discovery\n');
fprintf('============================================================\n');
fprintf('Original grid: %d trials, %d catastrophic failures\n', ...
    height(Fbase),sum(Fbase.catastrophic_branch_failure));
fprintf('Dense risk:    %d trials, %d catastrophic failures\n', ...
    height(Fdense),sum(Fdense.catastrophic_branch_failure));
fprintf('\nTop robust indicators:\n');
disp(shortlist);
fprintf('\nDecision:\n');
disp(decision);
fprintf('Saved to:\n%s\n',out_path);
fprintf('============================================================\n\n');

end

%% ========================================================================
function validate_config(cfg)

required = { ...
    'pa5i_folder_name','pa5i_trials_name', ...
    'pa5i_r1_folder_name','pa5i_r1_dense_trials_name', ...
    'pa5i_r1_risk_states_name', ...
    'pa4_beta_width_paper_rad','pa4_beta_width_beam_rad', ...
    'local_search_halfwidth_bins','local_bracket_points', ...
    'local_tolx_bins','local_max_fun_evals', ...
    'reconstruction_tolerance_bins', ...
    'curvature_probe_bins','plateau_levels', ...
    'branch_match_tolerance_bins', ...
    'catastrophic_error_threshold_bins', ...
    'trigger_fractions','discovery_auc_screen', ...
    'require_direction_consistency', ...
    'max_features_in_capture_plot', ...
    'figure_visible','output_dir'};

missing = required(~isfield(cfg,required));

if ~isempty(missing)
    error('EXP009:PA5JA:MissingConfigField', ...
        'Missing config field(s): %s',strjoin(missing,', '));
end

if numel(cfg.plateau_levels)~=2
    error('EXP009:PA5JA:PlateauLevels', ...
        'cfg.plateau_levels must contain exactly two levels.');
end

end

%% ========================================================================
function validate_upstream_base(T)

% Storage schema of PA5I's monolithic trial table.
required = { ...
    'aperture_mode','azimuth_samples', ...
    'delta_velocity_mps','strong_velocity_side', ...
    'strong_velocity_mps','weak_to_strong_ratio', ...
    'relative_phase_rad','true_eta_bins', ...
    'strong_chirp_rate_discrete','weak_chirp_rate_discrete', ...
    'method','nu_hat_bins', ...
    'branch_error_to_global_bins', ...
    'branch_recovered','catastrophic_branch_failure'};

missing = required(~ismember(required,T.Properties.VariableNames));

if ~isempty(missing)
    error('EXP009:PA5JA:MissingBaseColumn', ...
        'PA5I table missing column(s): %s', ...
        strjoin(missing,', '));
end

end

%% ========================================================================
function validate_upstream_dense_storage(T)

% Storage schema of PA5I-R1 dense trials.
% strong/weak chirp rate are intentionally NOT stored here; they are in
% pa5i_r1_dense_eta_risk_states.csv and are joined by risk_state_id.
required = { ...
    'risk_state_id','aperture_mode','azimuth_samples', ...
    'delta_velocity_mps','strong_velocity_side', ...
    'strong_velocity_mps','weak_to_strong_ratio', ...
    'relative_phase_rad','true_eta_bins','Gamma_PA4', ...
    'method','nu_hat_bins', ...
    'branch_error_to_global_bins', ...
    'branch_recovered','catastrophic_branch_failure'};

missing = required(~ismember(required,T.Properties.VariableNames));

if ~isempty(missing)
    error('EXP009:PA5JA:MissingDenseStorageColumn', ...
        'PA5I-R1 dense trial table missing storage column(s): %s', ...
        strjoin(missing,', '));
end

end

%% ========================================================================
function validate_risk_state_table(T)

required = { ...
    'risk_state_id','aperture_mode','azimuth_samples', ...
    'delta_velocity_mps','strong_velocity_side', ...
    'strong_velocity_mps','weak_to_strong_ratio', ...
    'relative_phase_rad', ...
    'strong_chirp_rate_discrete','weak_chirp_rate_discrete', ...
    'Gamma_PA4'};

missing = required(~ismember(required,T.Properties.VariableNames));

if ~isempty(missing)
    error('EXP009:PA5JA:MissingRiskStateColumn', ...
        'PA5I-R1 risk-state table missing column(s): %s', ...
        strjoin(missing,', '));
end

if numel(unique(T.risk_state_id))~=height(T)
    error('EXP009:PA5JA:DuplicateRiskStateID', ...
        'risk_state_id must be unique in the PA5I-R1 risk-state table.');
end

end

%% ========================================================================
function T = enrich_dense_with_risk_state_physics(T,R)

% Explicit ID lookup preserves dense-table row order and multiplicity.
[tf,loc] = ismember(T.risk_state_id,R.risk_state_id);

if any(~tf)
    bad = unique(T.risk_state_id(~tf));
    error('EXP009:PA5JA:UnresolvedRiskState', ...
        ['The dense trial table contains risk_state_id values that are ' ...
         'missing from the risk-state table: %s'], ...
        strjoin(cellstr(string(bad)),', '));
end

fields = { ...
    'strong_chirp_rate_discrete', ...
    'weak_chirp_rate_discrete'};

for i = 1:numel(fields)

    f = fields{i};
    values = R.(f)(loc);

    if ismember(f,T.Properties.VariableNames)

        existing = T.(f);

        if any(abs(existing-values)>1e-12)
            error('EXP009:PA5JA:DenseRiskStateConflict', ...
                ['Field %s exists in both dense trials and risk states ' ...
                 'but values disagree. Refusing silent overwrite.'],f);
        end

    else
        T.(f) = values;
    end
end

% Gamma is duplicated across the two PA5I-R1 outputs. Check that the
% files actually belong to the same run.
gamma_from_risk = R.Gamma_PA4(loc);

if any(abs(T.Gamma_PA4-gamma_from_risk)>1e-12)
    error('EXP009:PA5JA:GammaJoinConflict', ...
        ['Gamma_PA4 disagrees between dense trials and the companion ' ...
         'risk-state table. Check that both files are from the same run.']);
end

end

%% ========================================================================
function validate_indicator_input_table(T,source_name)

% Exact consumer contract for extract_indicator_table().
required = { ...
    'aperture_mode','azimuth_samples', ...
    'delta_velocity_mps','strong_velocity_side', ...
    'strong_velocity_mps','weak_to_strong_ratio', ...
    'relative_phase_rad','true_eta_bins', ...
    'strong_chirp_rate_discrete','weak_chirp_rate_discrete', ...
    'method','nu_hat_bins', ...
    'branch_error_to_global_bins', ...
    'branch_recovered','catastrophic_branch_failure'};

missing = required(~ismember(required,T.Properties.VariableNames));

if ~isempty(missing)
    error('EXP009:PA5JA:IndicatorConsumerSchema', ...
        ['Indicator extraction input "%s" is missing field(s): %s. ' ...
         'This is a schema-contract error, not an experimental result.'], ...
        source_name,strjoin(missing,', '));
end

end

%% ========================================================================
function [F,audit] = extract_indicator_table(T,source_name,cfg)

n = height(T);

% Output arrays
dataset_source = repmat(string(source_name),n,1);
trial_id = (1:n).';

Gamma_PA4 = nan(n,1);

% Cost class 0
neighbor_ratio = nan(n,1);
neighbor_margin = nan(n,1);
lr_asymmetry = nan(n,1);
threebin_central_fraction = nan(n,1);
fivebin_peak_fraction = nan(n,1);
local_entropy5 = nan(n,1);
coarse_second_ratio = nan(n,1);
coarse_second_gap = nan(n,1);
second_localmax_ratio = nan(n,1);
remote_competitor_ratio = nan(n,1);
plateau_count90 = nan(n,1);
plateau_count95 = nan(n,1);

% Cost class 1
refine_abs_displacement = nan(n,1);
refine_boundary_fraction = nan(n,1);
refinement_gain_rel = nan(n,1);

% Cost class 2
refined_curvature_norm = nan(n,1);
refined_lr_asymmetry = nan(n,1);

% Reconstruction audit
nu_reconstructed = nan(n,1);
nu_upstream = T.nu_hat_bins;
nu_difference = nan(n,1);

for it = 1:n

    N = T.azimuth_samples(it);
    aS = T.strong_chirp_rate_discrete(it);
    aW = T.weak_chirp_rate_discrete(it);
    rA = T.weak_to_strong_ratio(it);
    phi = T.relative_phase_rad(it);
    eta = T.true_eta_bins(it);

    x = synth_two_component(N,aS,aW,rA,phi,eta);
    z = dechirp_signal(x,aS);

    m = 0:N-1;
    Y = fftshift(fft(z));
    amp = abs(Y(:));

    [peak_amp,i0] = max(amp);
    dc = floor(N/2)+1;
    k0 = i0-dc;

    % ----------------------
    % PA4 Gamma
    % ----------------------
    if ismember('Gamma_PA4',T.Properties.VariableNames)
        Gamma_PA4(it) = T.Gamma_PA4(it);
    else
        betaS = atan(aS);
        betaW = atan(aW);

        if string(T.aperture_mode(it))=="Paper1s"
            Wb = cfg.pa4_beta_width_paper_rad;
        elseif string(T.aperture_mode(it))=="BeamDerived"
            Wb = cfg.pa4_beta_width_beam_rad;
        else
            error('EXP009:PA5JA:UnknownAperture', ...
                'Unknown aperture mode: %s',T.aperture_mode(it));
        end

        Gamma_PA4(it) = abs(betaS-betaW)/Wb;
    end

    % ----------------------
    % Coarse-only features
    % ----------------------
    il = wrap_index(i0-1,N);
    ir = wrap_index(i0+1,N);

    left = amp(il);
    right = amp(ir);
    neighbor = max(left,right);

    neighbor_ratio(it) = safe_ratio(neighbor,peak_amp);
    neighbor_margin(it) = 1-neighbor_ratio(it);

    lr_asymmetry(it) = ...
        abs(left-right)/max(left+right,eps);

    threebin_central_fraction(it) = ...
        peak_amp/max(left+peak_amp+right,eps);

    idx5 = arrayfun( ...
        @(d) wrap_index(i0+d,N),-2:2);
    a5 = amp(idx5);

    fivebin_peak_fraction(it) = ...
        peak_amp/max(sum(a5),eps);

    p5 = a5.^2;
    p5 = p5/max(sum(p5),eps);
    local_entropy5(it) = ...
        -sum(p5.*log(max(p5,eps)))/log(numel(p5));

    sorted_amp = sort(amp,'descend');

    if numel(sorted_amp)>=2
        coarse_second_ratio(it) = ...
            safe_ratio(sorted_amp(2),sorted_amp(1));
        coarse_second_gap(it) = ...
            1-coarse_second_ratio(it);
    else
        coarse_second_ratio(it) = 0;
        coarse_second_gap(it) = 1;
    end

    loc = local_peak_indices(amp);
    loc = loc(loc~=i0);

    if isempty(loc)
        second_localmax_ratio(it) = 0;
    else
        second_localmax_ratio(it) = ...
            safe_ratio(max(amp(loc)),peak_amp);
    end

    mask_remote = true(N,1);
    mask_remote([il,i0,ir]) = false;

    if any(mask_remote)
        remote_competitor_ratio(it) = ...
            safe_ratio(max(amp(mask_remote)),peak_amp);
    else
        remote_competitor_ratio(it) = 0;
    end

    plateau_count90(it) = ...
        sum(amp>=cfg.plateau_levels(1)*peak_amp);

    plateau_count95(it) = ...
        sum(amp>=cfg.plateau_levels(2)*peak_amp);

    % ----------------------
    % Reconstruct G0
    % ----------------------
    [nu_hat,Jhat,~] = ...
        refine_from_seed(z,m,N,k0,cfg);

    nu_reconstructed(it) = nu_hat;
    nu_difference(it) = ...
        abs(circular_bin_error(nu_hat,nu_upstream(it)));

    % ----------------------
    % G0-internal features
    % ----------------------
    d = circular_bin_error(nu_hat,k0);

    refine_abs_displacement(it) = abs(d);
    refine_boundary_fraction(it) = ...
        abs(d)/cfg.local_search_halfwidth_bins;

    Jcoarse = tone_objective(z,m,N,k0);

    refinement_gain_rel(it) = ...
        max(0,Jhat-Jcoarse)/max(Jhat,eps);

    % Two extra objective evaluations only.
    h = cfg.curvature_probe_bins;

    Jm = tone_objective(z,m,N,nu_hat-h);
    Jp = tone_objective(z,m,N,nu_hat+h);

    refined_curvature_norm(it) = ...
        max(0,2*Jhat-Jm-Jp)/max(Jhat*h^2,eps);

    refined_lr_asymmetry(it) = ...
        abs(Jp-Jm)/max(Jhat,eps);
end

pass = nu_difference<=cfg.reconstruction_tolerance_bins;

audit = table( ...
    dataset_source,trial_id,nu_upstream, ...
    nu_reconstructed,nu_difference,pass, ...
    'VariableNames',{ ...
    'source','trial_id','upstream_nu_bins', ...
    'reconstructed_nu_bins','difference_bins','pass'});

% Preserve source parameters and labels.
F = table( ...
    dataset_source,trial_id, ...
    string(T.aperture_mode),T.azimuth_samples, ...
    T.delta_velocity_mps,string(T.strong_velocity_side), ...
    T.strong_velocity_mps,T.weak_to_strong_ratio, ...
    T.relative_phase_rad,T.true_eta_bins,Gamma_PA4, ...
    T.branch_error_to_global_bins, ...
    T.branch_recovered,T.catastrophic_branch_failure, ...
    neighbor_ratio,neighbor_margin,lr_asymmetry, ...
    threebin_central_fraction,fivebin_peak_fraction, ...
    local_entropy5,coarse_second_ratio,coarse_second_gap, ...
    second_localmax_ratio,remote_competitor_ratio, ...
    plateau_count90,plateau_count95, ...
    refine_abs_displacement,refine_boundary_fraction, ...
    refinement_gain_rel, ...
    refined_curvature_norm,refined_lr_asymmetry, ...
    'VariableNames',{ ...
    'source','trial_id','aperture_mode','azimuth_samples', ...
    'delta_velocity_mps','strong_velocity_side', ...
    'strong_velocity_mps','weak_to_strong_ratio', ...
    'relative_phase_rad','true_eta_bins','Gamma_PA4', ...
    'branch_error_to_global_bins', ...
    'branch_recovered','catastrophic_branch_failure', ...
    'neighbor_ratio','neighbor_margin','lr_asymmetry', ...
    'threebin_central_fraction','fivebin_peak_fraction', ...
    'local_entropy5','coarse_second_ratio','coarse_second_gap', ...
    'second_localmax_ratio','remote_competitor_ratio', ...
    'plateau_count90','plateau_count95', ...
    'refine_abs_displacement','refine_boundary_fraction', ...
    'refinement_gain_rel', ...
    'refined_curvature_norm','refined_lr_asymmetry'});

end

%% ========================================================================
function [names,cost_class] = candidate_features()

names = string({ ...
    'neighbor_ratio', ...
    'neighbor_margin', ...
    'lr_asymmetry', ...
    'threebin_central_fraction', ...
    'fivebin_peak_fraction', ...
    'local_entropy5', ...
    'coarse_second_ratio', ...
    'coarse_second_gap', ...
    'second_localmax_ratio', ...
    'remote_competitor_ratio', ...
    'plateau_count90', ...
    'plateau_count95', ...
    'refine_abs_displacement', ...
    'refine_boundary_fraction', ...
    'refinement_gain_rel', ...
    'refined_curvature_norm', ...
    'refined_lr_asymmetry'}).';

cost_class = [ ...
    0,0,0,0,0,0,0,0,0,0,0,0, ...
    1,1,1, ...
    2,2].';

end

%% ========================================================================
function S = build_indicator_summary( ...
    Fbase,Fdense,names,cost_class,cfg)

yB = Fbase.catastrophic_branch_failure>0;
yD = Fdense.catastrophic_branch_failure>0;

prevB = mean(yB);
prevD = mean(yD);

rows = {};

for i = 1:numel(names)

    name = names(i);

    xB = Fbase.(name);
    xD = Fdense.(name);

    auc_raw_B = roc_auc_binary(xB,yB);

    if auc_raw_B>=0.5
        direction = "high";
        scoreB = xB;
        scoreD = xD;
    else
        direction = "low";
        scoreB = -xB;
        scoreD = -xD;
    end

    auc_B = roc_auc_binary(scoreB,yB);
    auc_D = roc_auc_binary(scoreD,yD);

    ap_B = average_precision(scoreB,yB);
    ap_D = average_precision(scoreD,yD);

    min_trigger95_B = ...
        minimum_trigger_fraction(scoreB,yB,0.95);
    min_trigger100_B = ...
        minimum_trigger_fraction(scoreB,yB,1.00);

    min_trigger95_D = ...
        minimum_trigger_fraction(scoreD,yD,0.95);
    min_trigger100_D = ...
        minimum_trigger_fraction(scoreD,yD,1.00);

    dir_consistent = auc_D>=0.5;

    robust_auc = min(auc_B,auc_D);

    pass_screen = ...
        robust_auc>=cfg.discovery_auc_screen;

    if cfg.require_direction_consistency
        pass_screen = pass_screen && dir_consistent;
    end

    rows(end+1,:) = { ... %#ok<AGROW>
        char(name),cost_class(i),char(direction), ...
        prevB,auc_B,ap_B,ap_B/max(prevB,eps), ...
        median(xB(~yB)),median(xB(yB)), ...
        min_trigger95_B,min_trigger100_B, ...
        prevD,auc_D,ap_D,ap_D/max(prevD,eps), ...
        median(xD(~yD)),median(xD(yD)), ...
        min_trigger95_D,min_trigger100_D, ...
        dir_consistent,robust_auc,pass_screen};
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'feature','cost_class','risk_direction', ...
    'original_prevalence','original_auc', ...
    'original_average_precision','original_ap_enrichment', ...
    'original_median_success','original_median_failure', ...
    'original_min_trigger_for_95pct_capture', ...
    'original_min_trigger_for_100pct_capture', ...
    'dense_prevalence','dense_auc_same_direction', ...
    'dense_average_precision_same_direction', ...
    'dense_ap_enrichment', ...
    'dense_median_success','dense_median_failure', ...
    'dense_min_trigger_for_95pct_capture', ...
    'dense_min_trigger_for_100pct_capture', ...
    'direction_consistent','robust_auc','screen_pass'});

S = sortrows(S, ...
    {'screen_pass','robust_auc','cost_class'}, ...
    {'descend','descend','ascend'});

end

%% ========================================================================
function C = build_capture_table(Fbase,Fdense,S,cfg)

rows = {};

for iset = 1:2

    if iset==1
        F = Fbase;
        source = "original_grid";
    else
        F = Fdense;
        source = "dense_risk";
    end

    y = F.catastrophic_branch_failure>0;
    prevalence = mean(y);

    for i = 1:height(S)

        name = string(S.feature(i));
        direction = string(S.risk_direction(i));
        x = F.(name);

        if direction=="high"
            score = x;
        else
            score = -x;
        end

        for jf = 1:numel(cfg.trigger_fractions)

            frac = cfg.trigger_fractions(jf);

            [capture,precision,actual_frac] = ...
                capture_at_trigger_fraction(score,y,frac);

            rows(end+1,:) = { ... %#ok<AGROW>
                char(source),char(name),char(direction), ...
                frac,actual_frac,capture,precision, ...
                precision/max(prevalence,eps)};
        end
    end
end

C = cell2table(rows, ...
    'VariableNames',{ ...
    'source','feature','risk_direction', ...
    'requested_trigger_fraction','actual_trigger_fraction', ...
    'failure_capture_rate','trigger_precision', ...
    'precision_enrichment'});

end

%% ========================================================================
function A = build_aperture_robustness(Fbase,Fdense,S)

rows = {};
apertures = ["Paper1s","BeamDerived"];

for iset = 1:2

    if iset==1
        F = Fbase;
        source = "original_grid";
    else
        F = Fdense;
        source = "dense_risk";
    end

    for ia = 1:numel(apertures)

        M = F(string(F.aperture_mode)==apertures(ia),:);
        y = M.catastrophic_branch_failure>0;

        for i = 1:height(S)

            name = string(S.feature(i));
            direction = string(S.risk_direction(i));
            x = M.(name);

            if direction=="high"
                score = x;
            else
                score = -x;
            end

            if sum(y)>0 && sum(~y)>0
                auc = roc_auc_binary(score,y);
                ap = average_precision(score,y);
            else
                auc = NaN;
                ap = NaN;
            end

            rows(end+1,:) = { ... %#ok<AGROW>
                char(source),char(apertures(ia)), ...
                char(name),height(M),mean(y),auc,ap};
        end
    end
end

A = cell2table(rows, ...
    'VariableNames',{ ...
    'source','aperture_mode','feature', ...
    'n_trials','failure_prevalence','auc','average_precision'});

end

%% ========================================================================
function C = build_context_summary(Fbase,Fdense)

rows = {};

for iset = 1:2

    if iset==1
        F = Fbase;
        source = "original_grid";
    else
        F = Fdense;
        source = "dense_risk";
    end

    apertures = unique(string(F.aperture_mode),'stable');

    for ia = 1:numel(apertures)

        M = F(string(F.aperture_mode)==apertures(ia),:);

        ratios = unique(M.weak_to_strong_ratio).';

        for ir = 1:numel(ratios)

            Q = M(abs(M.weak_to_strong_ratio-ratios(ir))<1e-12,:);

            rows(end+1,:) = { ... %#ok<AGROW>
                char(source),char(apertures(ia)), ...
                ratios(ir),height(Q), ...
                mean(Q.catastrophic_branch_failure), ...
                median(Q.Gamma_PA4), ...
                min(Q.Gamma_PA4),max(Q.Gamma_PA4)};
        end
    end
end

C = cell2table(rows, ...
    'VariableNames',{ ...
    'source','aperture_mode','weak_to_strong_ratio', ...
    'n_trials','catastrophic_failure_rate', ...
    'median_Gamma_PA4','min_Gamma_PA4','max_Gamma_PA4'});

end

%% ========================================================================
function L = build_shortlist(S,cfg)

L = S(S.screen_pass,:);

if isempty(L)
    % Keep the strongest candidates visible even if screening fails.
    L = S(1:min(5,height(S)),:);
    L.discovery_status = ...
        repmat("NO_FEATURE_PASSED_SCREEN_SHOWING_TOP_RANKED",height(L),1);
else
    L.discovery_status = ...
        repmat("PASSED_PRE_REGISTERED_SCREEN",height(L),1);
end

% Prefer high robust AUC. If two candidates are within 0.01, the lower
% cost class is preferred in displayed order.
score = L.robust_auc - 0.01*L.cost_class;
L.display_priority = score;

L = sortrows(L, ...
    {'display_priority','robust_auc'}, ...
    {'descend','descend'});

if height(L)>8
    L = L(1:8,:);
end

end

%% ========================================================================
function D = build_decision(S,L,recon,cfg)

recon_pass = all(recon.pass);

n_screen = sum(S.screen_pass);

if isempty(L)
    best_feature = "";
    best_auc = NaN;
    best_cost = NaN;
else
    best_feature = string(L.feature(1));
    best_auc = L.robust_auc(1);
    best_cost = L.cost_class(1);
end

if recon_pass && n_screen>=1
    branch = ...
        "INDICATORS_FOUND_PROCEED_TO_PA5J_B_GATE_DESIGN";
elseif recon_pass
    branch = ...
        "NO_ROBUST_UNIVARIATE_INDICATOR_TEST_MULTIVARIATE_OR_NEW_OBSERVABLES";
else
    branch = ...
        "STOP_RECONSTRUCTION_AUDIT_FAILED";
end

D = table( ...
    recon_pass,n_screen,best_feature,best_auc,best_cost, ...
    cfg.discovery_auc_screen,string(branch), ...
    'VariableNames',{ ...
    'reconstruction_pass','n_screened_indicators', ...
    'best_indicator','best_robust_auc','best_cost_class', ...
    'screen_auc_threshold','decision_branch'});

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

x = A.*exp(1j*2*pi*(0.5*a*m.^2+b*m)+1j*phi);
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

[nu_hat,fval] = fminbnd(@wrapped_obj,local_lb,local_ub,opts);

Jhat = -fval;
neval = neval+count;

    function y = wrapped_obj(nu)
        count = count+1;
        y = -tone_objective(z,m,N,nu);
    end

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
function i = wrap_index(i,n)

i = mod(i-1,n)+1;

end

%% ========================================================================
function r = safe_ratio(a,b)

r = a/max(b,eps);

end

%% ========================================================================
function e = circular_bin_error(a,b)

e = mod((a-b)+0.5,1)-0.5;

end

%% ========================================================================
function auc = roc_auc_binary(score,label)

score = score(:);
label = logical(label(:));

valid = isfinite(score) & ~isnan(double(label));
score = score(valid);
label = label(valid);

nPos = sum(label);
nNeg = sum(~label);

if nPos==0 || nNeg==0
    auc = NaN;
    return;
end

ranks = average_ranks(score);

sumPos = sum(ranks(label));

auc = (sumPos - nPos*(nPos+1)/2)/(nPos*nNeg);

end

%% ========================================================================
function ranks = average_ranks(x)

[xs,ord] = sort(x,'ascend');
n = numel(x);
r = zeros(n,1);

i = 1;

while i<=n
    j = i;

    while j<n && xs(j+1)==xs(i)
        j = j+1;
    end

    rr = (i+j)/2;
    r(i:j) = rr;

    i = j+1;
end

ranks = zeros(n,1);
ranks(ord) = r;

end

%% ========================================================================
function ap = average_precision(score,label)

score = score(:);
label = logical(label(:));

valid = isfinite(score);
score = score(valid);
label = label(valid);

nPos = sum(label);

if nPos==0
    ap = NaN;
    return;
end

[~,ord] = sort(score,'descend');
y = label(ord);

tp = cumsum(y);
rank = (1:numel(y)).';

precision = tp./rank;

ap = sum(precision(y))/nPos;

end

%% ========================================================================
function frac = minimum_trigger_fraction(score,label,target_capture)

score = score(:);
label = logical(label(:));

nPos = sum(label);

if nPos==0
    frac = NaN;
    return;
end

[~,ord] = sort(score,'descend');
y = label(ord);

cum = cumsum(y)/nPos;

idx = find(cum>=target_capture,1,'first');

if isempty(idx)
    frac = 1;
else
    frac = idx/numel(y);
end

end

%% ========================================================================
function [capture,precision,actual_frac] = ...
    capture_at_trigger_fraction(score,label,frac)

score = score(:);
label = logical(label(:));

n = numel(score);
nTrig = max(1,min(n,ceil(frac*n)));

[~,ord] = sort(score,'descend');
sel = ord(1:nTrig);

nPos = sum(label);

if nPos==0
    capture = NaN;
else
    capture = sum(label(sel))/nPos;
end

precision = mean(label(sel));
actual_frac = nTrig/n;

end

%% ========================================================================
function make_figures( ...
    out_path,cfg,Fbase,Fdense,S,Capture,Aperture, ...
    Context,Shortlist)

%% Fig 1 — AUC transfer original -> dense
fig = figure('Visible',cfg.figure_visible);

scatter( ...
    S.original_auc, ...
    S.dense_auc_same_direction, ...
    60, ...
    S.cost_class+1, ...
    'filled');

hold on;
plot([0.5 1],[0.5 1],'--');

for i = 1:height(S)
    text( ...
        S.original_auc(i), ...
        S.dense_auc_same_direction(i), ...
        ['  ',S.feature{i}], ...
        'Interpreter','none', ...
        'FontSize',8);
end

xline(cfg.discovery_auc_screen,':');
yline(cfg.discovery_auc_screen,':');

xlabel('Original-grid ROC AUC');
ylabel('Dense-risk ROC AUC using same direction');
title('EXP009 PA5J-A — Indicator Transfer Robustness');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig01_indicator_auc_transfer.png'), ...
    'Resolution',180);
close(fig);

%% Fig 2 — AP enrichment
fig = figure('Visible',cfg.figure_visible);

scatter( ...
    S.original_ap_enrichment, ...
    S.dense_ap_enrichment, ...
    60,S.cost_class+1,'filled');

for i = 1:height(S)
    text( ...
        S.original_ap_enrichment(i), ...
        S.dense_ap_enrichment(i), ...
        ['  ',S.feature{i}], ...
        'Interpreter','none', ...
        'FontSize',8);
end

xlabel('Original AP / failure prevalence');
ylabel('Dense-risk AP / failure prevalence');
title('EXP009 PA5J-A — Precision Enrichment');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig02_indicator_ap_enrichment.png'), ...
    'Resolution',180);
close(fig);

%% Select top feature for diagnostic plots
if isempty(Shortlist)
    top_name = string(S.feature(1));
else
    top_name = string(Shortlist.feature(1));
end

top_row = S(string(S.feature)==top_name,:);
direction = string(top_row.risk_direction(1));

%% Fig 3 — top feature distribution / original
plot_feature_distribution( ...
    Fbase,top_name,direction,cfg, ...
    fullfile(out_path,'fig03_top_indicator_original_distribution.png'), ...
    'EXP009 PA5J-A — Top Indicator on Original Grid');

%% Fig 4 — top feature distribution / dense risk
plot_feature_distribution( ...
    Fdense,top_name,direction,cfg, ...
    fullfile(out_path,'fig04_top_indicator_dense_distribution.png'), ...
    'EXP009 PA5J-A — Top Indicator on Dense Risk');

%% Fig 5 — failure capture vs trigger fraction
fig = figure('Visible',cfg.figure_visible);
hold on;

nplot = min(cfg.max_features_in_capture_plot,height(S));
top_features = string(S.feature(1:nplot));

for i = 1:numel(top_features)

    Q = Capture( ...
        string(Capture.source)=="original_grid" & ...
        string(Capture.feature)==top_features(i),:);

    plot( ...
        Q.actual_trigger_fraction, ...
        Q.failure_capture_rate, ...
        '-','LineWidth',1.2);
end

xlabel('Triggered fraction of all trials');
ylabel('Captured fraction of catastrophic failures');
title('EXP009 PA5J-A — Original-Grid Failure Capture');
legend(cellstr(top_features), ...
    'Interpreter','none','Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig05_original_capture_curves.png'), ...
    'Resolution',180);
close(fig);

%% Fig 6 — dense-risk failure capture
fig = figure('Visible',cfg.figure_visible);
hold on;

for i = 1:numel(top_features)

    Q = Capture( ...
        string(Capture.source)=="dense_risk" & ...
        string(Capture.feature)==top_features(i),:);

    plot( ...
        Q.actual_trigger_fraction, ...
        Q.failure_capture_rate, ...
        '-','LineWidth',1.2);
end

xlabel('Triggered fraction of dense-risk trials');
ylabel('Captured fraction of catastrophic failures');
title('EXP009 PA5J-A — Dense-Risk Failure Capture');
legend(cellstr(top_features), ...
    'Interpreter','none','Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig06_dense_capture_curves.png'), ...
    'Resolution',180);
close(fig);

%% Fig 7 — aperture robustness for top feature
Q = Aperture(string(Aperture.feature)==top_name,:);

fig = figure('Visible',cfg.figure_visible);

cats = categorical( ...
    strcat(string(Q.source)," / ",string(Q.aperture_mode)));

bar(cats,Q.auc);

ylim([0 1]);
yline(0.5,'--');
yline(cfg.discovery_auc_screen,':');

ylabel('ROC AUC using original-grid risk direction');
title(['EXP009 PA5J-A — Aperture Robustness: ',char(top_name)], ...
    'Interpreter','none');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig07_top_indicator_aperture_robustness.png'), ...
    'Resolution',180);
close(fig);

%% Fig 8 — contextual failure map (NOT a gate feature)
fig = figure('Visible',cfg.figure_visible);
hold on;

apertures = ["Paper1s","BeamDerived"];

for ia = 1:numel(apertures)

    Q = Context( ...
        string(Context.source)=="original_grid" & ...
        string(Context.aperture_mode)==apertures(ia),:);

    plot( ...
        Q.weak_to_strong_ratio, ...
        Q.catastrophic_failure_rate, ...
        'o-','LineWidth',1.2);
end

xlabel('A_w/A_s');
ylabel('Catastrophic branch-failure rate');
title('EXP009 PA5J-A — Context Only: Failure vs Contrast');
legend(cellstr(apertures),'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig08_context_failure_vs_contrast.png'), ...
    'Resolution',180);
close(fig);

%% Fig 9 — shortlist robust AUC / cost class
Q = S(1:min(10,height(S)),:);

fig = figure('Visible',cfg.figure_visible);

scatter( ...
    Q.cost_class,Q.robust_auc,80,'filled');

for i = 1:height(Q)
    text( ...
        Q.cost_class(i),Q.robust_auc(i), ...
        ['  ',Q.feature{i}], ...
        'Interpreter','none');
end

yline(cfg.discovery_auc_screen,':');

xlabel('Indicator cost class (0=FFT, 1=G0 free, 2=+2 objectives)');
ylabel('min(original AUC, dense-risk AUC)');
title('EXP009 PA5J-A — Reliability / Indicator-Cost Map');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig09_indicator_cost_robustness.png'), ...
    'Resolution',180);
close(fig);

end

%% ========================================================================
function plot_feature_distribution( ...
    F,name,direction,cfg,outfile,ttl)

x = F.(name);
y = F.catastrophic_branch_failure>0;

success = x(~y);
failure = x(y);

allx = x(isfinite(x));

if isempty(allx)
    edges = linspace(0,1,21);
else
    lo = min(allx);
    hi = max(allx);

    if hi<=lo
        hi = lo+1;
    end

    edges = linspace(lo,hi,31);
end

fig = figure('Visible',cfg.figure_visible);
hold on;

histogram(success,edges,'Normalization','probability');
histogram(failure,edges,'Normalization','probability');

xlabel(char(name),'Interpreter','none');
ylabel('Probability');
title([ttl,' / risk direction=',char(direction)], ...
    'Interpreter','none');
legend({'G0 success','G0 catastrophic failure'}, ...
    'Location','best');
grid on;

exportgraphics(fig,outfile,'Resolution',180);
close(fig);

end

%% ========================================================================
function write_summary( ...
    out_path,cfg,Fbase,Fdense,S,L,D,recon)

fid = fopen(fullfile(out_path,'summary.txt'),'w');

fprintf(fid,'EXP009 PA5J-A\n');
fprintf(fid,'Internal Unreliability Indicator Discovery\n');
fprintf(fid,'===========================================\n\n');

fprintf(fid,'Research question\n');
fprintf(fid,'-----------------\n');
fprintf(fid,['Can G0 recognize impending catastrophic branch switching ' ...
    'from its own internal observables, before Neighbor-3 is run?\n\n']);

fprintf(fid,'Dataset roles\n');
fprintf(fid,'-------------\n');
fprintf(fid,['Original grid: representative PA5I base-rate evaluation. ' ...
    'n=%d, failures=%d, prevalence=%g\n'], ...
    height(Fbase),sum(Fbase.catastrophic_branch_failure), ...
    mean(Fbase.catastrophic_branch_failure));

fprintf(fid,['Dense risk: PA5I-R1 stress manifold. ' ...
    'n=%d, failures=%d, prevalence=%g\n\n'], ...
    height(Fdense),sum(Fdense.catastrophic_branch_failure), ...
    mean(Fdense.catastrophic_branch_failure));

fprintf(fid,'Reconstruction audit\n');
fprintf(fid,'--------------------\n');
fprintf(fid,'All upstream G0 reconstructions passed = %d\n',all(recon.pass));
fprintf(fid,'Maximum reconstruction mismatch = %.12g bins\n\n', ...
    max(recon.difference_bins));

fprintf(fid,'Important discipline\n');
fprintf(fid,'--------------------\n');
fprintf(fid,['Gamma, contrast, true eta, and global-reference branch error ' ...
    'are context/labels only. They are NOT candidate gate features.\n']);
fprintf(fid,['PA5J-A does not tune a final threshold and does not claim an ' ...
    'adaptive algorithm yet.\n\n']);

fprintf(fid,'Top indicator summary\n');
fprintf(fid,'---------------------\n');

nshow = min(10,height(S));
for i=1:nshow
    fprintf(fid,[ ...
        '%s cost=%d dir=%s AUCbase=%g AUCdense=%g ' ...
        'APenrichBase=%g APenrichDense=%g screen=%d\n'], ...
        S.feature{i},S.cost_class(i),S.risk_direction{i}, ...
        S.original_auc(i),S.dense_auc_same_direction(i), ...
        S.original_ap_enrichment(i),S.dense_ap_enrichment(i), ...
        S.screen_pass(i));
end

fprintf(fid,'\nShortlist\n');
fprintf(fid,'---------\n');

for i=1:height(L)
    fprintf(fid,[ ...
        '%s cost=%d robustAUC=%g status=%s\n'], ...
        L.feature{i},L.cost_class(i),L.robust_auc(i), ...
        L.discovery_status{i});
end

fprintf(fid,'\nDecision\n');
fprintf(fid,'--------\n');
fprintf(fid,'Screen AUC threshold = %g\n',cfg.discovery_auc_screen);
fprintf(fid,'Number of screened indicators = %d\n', ...
    D.n_screened_indicators(1));
fprintf(fid,'Best indicator = %s\n',D.best_indicator{1});
fprintf(fid,'Best robust AUC = %g\n',D.best_robust_auc(1));
fprintf(fid,'Best cost class = %g\n',D.best_cost_class(1));
fprintf(fid,'Decision branch = %s\n',D.decision_branch{1});

fprintf(fid,'\nNext-step rule\n');
fprintf(fid,'--------------\n');
fprintf(fid,['Only if at least one internal-only indicator transfers ' ...
    'consistently to the dense-risk set should PA5J-B tune an ' ...
    'adaptive trigger threshold / composite gate.\n']);

fclose(fid);

end
