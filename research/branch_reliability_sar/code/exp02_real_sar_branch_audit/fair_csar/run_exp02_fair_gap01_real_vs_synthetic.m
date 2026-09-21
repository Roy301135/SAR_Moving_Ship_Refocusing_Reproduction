%% run_exp02_fair_gap01_real_vs_synthetic.m
% EXP02-FAIR-GAP01
% Real-vs-Synthetic Gap Audit — Candidate B
%
% A. Parameter-support exact synthetic clones
% B. Real single-quadratic-LFM adequacy + local p_beta relaxation
% C. Paired real/synthetic J(p_beta,nu) landscapes
%
% No new recovery method is tested here.

clear; clc; close all;

%% 0. Paths
this_file = mfilename('fullpath');
fair_code_dir = fileparts(this_file);
exp02_code_dir = fileparts(fair_code_dir);
code_dir = fileparts(exp02_code_dir);
research_dir = fileparts(code_dir);
research_parent = fileparts(research_dir);
repo_root = fileparts(research_parent);

addpath(fair_code_dir);
addpath(genpath(fullfile(research_dir,'functions')));

cfg = config_exp02_fair_gap01(research_dir,repo_root);

if ~exist(cfg.results_dir,'dir')
    mkdir(cfg.results_dir);
end

required_fns = { ...
    'fair_csar_load_complex_mat', ...
    'branch_real_g0_neighbor3_audit'};

for i = 1:numel(required_fns)
    if exist(required_fns{i},'file') ~= 2
        error('EXP02_FAIR_GAP01:MissingFunction', ...
            'Required function not found: %s',required_fns{i});
    end
end

if exist(cfg.r1b_workspace,'file') ~= 2
    error('EXP02_FAIR_GAP01:MissingR1B', ...
        'R1B workspace missing: %s',cfg.r1b_workspace);
end

%% 1. Load exact R1B real states
W = load(cfg.r1b_workspace, ...
    'cfg','R','StateLineIndex','StateRangeColumn','StatePbeta', ...
    'StateFracEnergy','Audit','T','n_states');

required = { ...
    'cfg','R','StateLineIndex','StateRangeColumn', ...
    'StatePbeta','StateFracEnergy','Audit','T'};

for i = 1:numel(required)
    if ~isfield(W,required{i})
        error('EXP02_FAIR_GAP01:R1BSchema', ...
            'R1B workspace missing field: %s',required{i});
    end
end

data_stem = W.cfg.stem;
mat_path = fullfile(cfg.data_root,'SLCMats',[data_stem '.mat']);

if exist(mat_path,'file') ~= 2
    error('EXP02_FAIR_GAP01:MissingMAT', ...
        'Candidate-B MAT missing: %s',mat_path);
end

[S,mat_info] = fair_csar_load_complex_mat(mat_path);
S = double(S);

r1 = W.R.r1;
r2 = W.R.r2;
c1 = W.R.c1;
c2 = W.R.c2;

N = r2-r1+1;
m = 0:N-1;

StatePbeta = W.StatePbeta(:);
StateRangeColumn = W.StateRangeColumn(:);
StateFracEnergy = W.StateFracEnergy(:); %#ok<NASGU>
Taxonomy = string(W.T.Taxonomy);

n_states = numel(StatePbeta);

if n_states ~= numel(W.Audit)
    error('EXP02_FAIR_GAP01:StateCountMismatch', ...
        'State vector and Audit count differ.');
end

is_failure = Taxonomy ~= "SAFE";

fprintf('============================================================\n');
fprintf('EXP02-FAIR-GAP01 REAL-vs-SYNTHETIC GAP AUDIT\n');
fprintf('Candidate        : B\n');
fprintf('States           : %d\n',n_states);
fprintf('Non-SAFE real    : %d\n',sum(is_failure));
fprintf('Real line length : %d\n',N);
fprintf('============================================================\n\n');

%% A. Exact synthetic clones over actual real-state parameter support
CloneTrueNu = nan(n_states,1);
CloneG0Nu = nan(n_states,1);
CloneN3Nu = nan(n_states,1);
CloneGlobalNu = nan(n_states,1);

CloneG0TruthError = nan(n_states,1);
CloneN3TruthError = nan(n_states,1);
CloneGlobalTruthError = nan(n_states,1);

CloneG0Matches = false(n_states,1);
CloneN3Matches = false(n_states,1);

for i = 1:n_states
    p = StatePbeta(i);
    nu_true = wrap_bin(W.Audit(i).global_nu_bins,N);
    a = pbeta_to_sampled_a(p,N,cfg);

    x_syn = exp(1j*pi*a*m.^2 + 1j*2*pi*nu_true*m/N);

    A = branch_real_g0_neighbor3_audit(x_syn,a,cfg.stage);

    CloneTrueNu(i) = nu_true;
    CloneG0Nu(i) = wrap_bin(A.g0_nu_wrapped,N);
    CloneN3Nu(i) = wrap_bin(A.n3_nu_wrapped,N);
    CloneGlobalNu(i) = wrap_bin(A.global_nu_bins,N);

    CloneG0TruthError(i) = circular_bin_distance(CloneG0Nu(i),nu_true,N);
    CloneN3TruthError(i) = circular_bin_distance(CloneN3Nu(i),nu_true,N);
    CloneGlobalTruthError(i) = circular_bin_distance(CloneGlobalNu(i),nu_true,N);

    CloneG0Matches(i) = CloneG0TruthError(i) <= cfg.clone_truth_tolerance_bins;
    CloneN3Matches(i) = CloneN3TruthError(i) <= cfg.clone_truth_tolerance_bins;

    if mod(i,25)==0 || i==n_states
        fprintf('clone %3d/%3d | p=%.2f nu=%8.3f | G0 err=%.3e\n', ...
            i,n_states,p,nu_true,CloneG0TruthError(i));
    end
end

clone_g0_pass_rate = mean(CloneG0Matches);
clone_n3_pass_rate = mean(CloneN3Matches);
clone_max_g0_error = max(CloneG0TruthError);
clone_max_n3_error = max(CloneN3TruthError);
clone_max_global_error = max(CloneGlobalTruthError);

clone_parameter_support_pass = ...
    all(CloneG0Matches) && all(CloneN3Matches) && ...
    clone_max_global_error <= cfg.clone_truth_tolerance_bins;

fprintf('\n[A] PARAMETER-SUPPORT CLONES\n');
fprintf('G0 match rate     = %d/%d\n',sum(CloneG0Matches),n_states);
fprintf('N3 match rate     = %d/%d\n',sum(CloneN3Matches),n_states);
fprintf('max G0 truth err  = %.6g bin\n',clone_max_g0_error);
fprintf('max N3 truth err  = %.6g bin\n',clone_max_n3_error);
fprintf('max Global err    = %.6g bin\n',clone_max_global_error);
fprintf('parameter support = %s\n\n',passfail(clone_parameter_support_pass));

%% B. Real single-quadratic-LFM adequacy and local p relaxation
% FrozenAtomCoherence is squared normalized complex projection onto the
% frozen quadratic-LFM atom using the evaluation-only global nu at p0.
% It lies in [0,1].
%
% RelaxedAtomCoherence permits only p0 +/- 0.04, while nu is globally
% optimized at each p. This distinguishes a local upstream p_beta issue
% from a broader model/multi-component gap.

FrozenAtomCoherence = nan(n_states,1);
RelaxedAtomCoherence = nan(n_states,1);
RelaxedBestPbeta = nan(n_states,1);
RelaxedBestNu = nan(n_states,1);
PbetaShift = nan(n_states,1);
PRelaxGain = nan(n_states,1);
PRelaxBoundaryHit = false(n_states,1);

for i = 1:n_states
    col = StateRangeColumn(i);
    x = S(r1:r2,col).';
    x = x(:).';

    p0 = StatePbeta(i);
    nu0 = W.Audit(i).global_nu_bins;

    FrozenAtomCoherence(i) = atom_coherence(x,p0,nu0,cfg);

    p_scan = build_p_scan(p0,cfg);

    bestC = FrozenAtomCoherence(i);
    bestP = p0;
    bestNu = wrap_bin(nu0,N);
    bestIndex = NaN;

    for ip = 1:numel(p_scan)
        p = p_scan(ip);
        [nu_hat,C] = global_tone_reference_for_p(x,p,cfg);

        if C > bestC
            bestC = C;
            bestP = p;
            bestNu = nu_hat;
            bestIndex = ip;
        end
    end

    RelaxedAtomCoherence(i) = bestC;
    RelaxedBestPbeta(i) = bestP;
    RelaxedBestNu(i) = bestNu;
    PbetaShift(i) = circular_order_distance(bestP,p0);
    PRelaxGain(i) = bestC-FrozenAtomCoherence(i);

    if ~isnan(bestIndex)
        PRelaxBoundaryHit(i) = bestIndex==1 || bestIndex==numel(p_scan);
    end

    if mod(i,25)==0 || i==n_states
        fprintf(['real-fit %3d/%3d | p0=%.2f -> %.3f | ' ...
            'C %.4f -> %.4f | gain=%.4f\n'], ...
            i,n_states,p0,bestP, ...
            FrozenAtomCoherence(i),bestC,PRelaxGain(i));
    end
end

median_frozen_coh = median(FrozenAtomCoherence);
median_relaxed_coh = median(RelaxedAtomCoherence);
median_p_gain = median(PRelaxGain);
p90_p_gain = local_percentile(PRelaxGain,90);
material_p_gain_fraction = mean(PRelaxGain >= cfg.material_p_relax_gain);
p_boundary_fraction = mean(PRelaxBoundaryHit);

median_frozen_safe = median(FrozenAtomCoherence(~is_failure));
median_frozen_fail = median(FrozenAtomCoherence(is_failure));
median_gain_safe = median(PRelaxGain(~is_failure));
median_gain_fail = median(PRelaxGain(is_failure));

fprintf('\n[B] REAL QUADRATIC-LFM ADEQUACY\n');
fprintf('median frozen atom coherence = %.6f\n',median_frozen_coh);
fprintf('median relaxed coherence     = %.6f\n',median_relaxed_coh);
fprintf('median p-relax gain          = %.6f\n',median_p_gain);
fprintf('p90 p-relax gain             = %.6f\n',p90_p_gain);
fprintf('gain >= %.3f fraction        = %.4f\n', ...
    cfg.material_p_relax_gain,material_p_gain_fraction);
fprintf('p-scan boundary-hit fraction = %.4f\n\n',p_boundary_fraction);

%% C. Representative paired J(p,nu) landscapes
selected_state_ids = select_landscape_states(W,is_failure,cfg);
Landscape = struct([]);

for ic = 1:numel(selected_state_ids)
    sid = selected_state_ids(ic);

    p0 = StatePbeta(sid);
    nu0 = wrap_bin(W.Audit(sid).global_nu_bins,N);
    a0 = pbeta_to_sampled_a(p0,N,cfg);

    x_real = S(r1:r2,StateRangeColumn(sid)).';
    x_real = x_real(:).';
    x_syn = exp(1j*pi*a0*m.^2 + 1j*2*pi*nu0*m/N);

    p_land = build_landscape_p_grid(p0,cfg);
    [Jreal,bins] = joint_landscape(x_real,p_land,cfg);
    [Jsyn,~] = joint_landscape(x_syn,p_land,cfg);

    L = struct();
    L.state_id = sid;
    L.range_column = StateRangeColumn(sid);
    L.taxonomy = Taxonomy(sid);
    L.p0 = p0;
    L.nu0 = nu0;
    L.p_grid = p_land;
    L.nu_bins = bins;
    L.Jreal = Jreal;
    L.Jsyn = Jsyn;
    L.g0_error_bins = W.Audit(sid).g0_error_bins;
    L.coarse_margin = W.Audit(sid).coarse_top1_top2_margin;

    if ic==1
        Landscape = repmat(L,numel(selected_state_ids),1);
    else
        Landscape(ic) = L;
    end
end

%% D. Compact engineering route
if ~clone_parameter_support_pass
    gap_route = "IMPLEMENTATION_OR_PARAMETER_SUPPORT_MISMATCH__AUDIT_BEFORE_PHYSICS";
elseif median_p_gain >= cfg.material_p_relax_gain
    gap_route = "UPSTREAM_PBETA_MISMATCH_PLAUSIBLE__LITERATURE_GATE_BETA_ESTIMATION";
else
    gap_route = "LOCAL_PBETA_RELAXATION_SMALL__MODEL_MIXTURE_OR_HIGHER_ORDER_GAP_PLAUSIBLE";
end

%% Tables
Tstate = table( ...
    (1:n_states).',StateRangeColumn,StatePbeta,Taxonomy, ...
    CloneTrueNu,CloneG0TruthError,CloneN3TruthError,CloneGlobalTruthError, ...
    FrozenAtomCoherence,RelaxedAtomCoherence,RelaxedBestPbeta,RelaxedBestNu, ...
    PbetaShift,PRelaxGain,PRelaxBoundaryHit, ...
    'VariableNames',{ ...
    'StateID','RangeColumn','Pbeta','Taxonomy', ...
    'CloneTrueNu','CloneG0TruthError','CloneN3TruthError','CloneGlobalTruthError', ...
    'FrozenAtomCoherence','RelaxedAtomCoherence','RelaxedBestPbeta','RelaxedBestNu', ...
    'PbetaShift','PRelaxGain','PRelaxBoundaryHit'});

writetable(Tstate,fullfile(cfg.results_dir,'EXP02_FAIR_GAP01_state_metrics.csv'));

%% Figure 1 — parameter-support synthetic clones
fig1 = figure('Color','w','Name','GAP01 synthetic clone parameter support');
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');

nexttile;
scatter(StatePbeta,max(CloneG0TruthError,1e-15),25,CloneTrueNu,'filled');
hold on;
yline(cfg.clone_truth_tolerance_bins,'--','match tolerance');
hold off;
set(gca,'YScale','log');
xlabel('Real-state p_\beta used for exact clone');
ylabel('Synthetic-clone G0 error to known \nu (bins)');
title(sprintf('Exact clones | G0 matched %d/%d',sum(CloneG0Matches),n_states));
grid on; colorbar;

nexttile;
scatter(CloneTrueNu,max(CloneG0TruthError,1e-15),25,StatePbeta,'filled');
hold on;
yline(cfg.clone_truth_tolerance_bins,'--','match tolerance');
hold off;
set(gca,'YScale','log');
xlabel('Known clone \nu (DFT bins)');
ylabel('Synthetic-clone G0 error (bins)');
title(sprintf('Parameter-support closure | max err %.2e',clone_max_g0_error));
grid on; colorbar;

exportgraphics(fig1, ...
    fullfile(cfg.results_dir,'01_synthetic_clone_parameter_support.png'), ...
    'Resolution',cfg.figure_resolution);

%% Figure 2 — real single-LFM adequacy
fig2 = figure('Color','w','Name','GAP01 real single-LFM adequacy');
tiledlayout(1,3,'Padding','compact','TileSpacing','compact');

nexttile;
scatter(FrozenAtomCoherence,RelaxedAtomCoherence, ...
    24+18*double(is_failure),double(is_failure),'filled');
hold on;
mx = max([FrozenAtomCoherence;RelaxedAtomCoherence;0.01]);
plot([0 mx],[0 mx],'--','LineWidth',1.0);
hold off;
xlabel('Frozen (p_\beta,\nu_{global}) atom coherence');
ylabel('Best local-p quadratic-LFM coherence');
title('Real-line single-atom adequacy');
grid on;

nexttile;
scatter(StatePbeta,PRelaxGain, ...
    24+18*double(is_failure),double(is_failure),'filled');
hold on;
yline(cfg.material_p_relax_gain,'--','engineering material gain');
hold off;
xlabel('Frozen p_\beta');
ylabel('\Delta coherence from local p relaxation');
title(sprintf('median gain = %.4f',median_p_gain));
grid on;

nexttile;
boxchart(categorical(Taxonomy),FrozenAtomCoherence);
ylabel('Frozen single-LFM atom coherence');
title('Model adequacy by branch taxonomy');
grid on;

exportgraphics(fig2, ...
    fullfile(cfg.results_dir,'02_real_single_lfm_adequacy.png'), ...
    'Resolution',cfg.figure_resolution);

%% Figure 3 — paired landscapes
fig3 = figure('Color','w','Name','GAP01 paired real synthetic landscapes');
tiledlayout(numel(Landscape),2,'Padding','compact','TileSpacing','compact');

for ic = 1:numel(Landscape)
    L = Landscape(ic);

    nexttile;
    imagesc(L.nu_bins,L.p_grid,normalize_map(L.Jreal));
    axis xy;
    xlabel('\nu (integer DFT bins)'); ylabel('p_\beta');
    title(sprintf('REAL state %d col %d | %s | G0err %.1f', ...
        L.state_id,L.range_column,L.taxonomy,L.g0_error_bins));
    colorbar;

    nexttile;
    imagesc(L.nu_bins,L.p_grid,normalize_map(L.Jsyn));
    axis xy;
    xlabel('\nu (integer DFT bins)'); ylabel('p_\beta');
    title(sprintf('EXACT CLONE | p=%.2f \nu=%.2f',L.p0,L.nu0));
    colorbar;
end

exportgraphics(fig3, ...
    fullfile(cfg.results_dir,'03_joint_landscape_representatives.png'), ...
    'Resolution',cfg.figure_resolution);

%% Figure 4 — compact gap summary
fig4 = figure('Color','w','Name','GAP01 compact summary');
tiledlayout(1,3,'Padding','compact','TileSpacing','compact');

nexttile;
bar([clone_g0_pass_rate clone_n3_pass_rate]);
ylim([0 1.05]); xticks(1:2); xticklabels({'G0','N3'});
ylabel('Exact-clone truth-match fraction');
title('Implementation / parameter support'); grid on;

nexttile;
bar([median_frozen_coh median_relaxed_coh]);
xticks(1:2); xticklabels({'Frozen p','Local-p best'});
ylabel('Median single-LFM atom coherence');
title('Real quadratic-model adequacy'); grid on;

nexttile;
bar([median_gain_safe median_gain_fail]);
xticks(1:2); xticklabels({'SAFE','non-SAFE'});
ylabel('Median local-p coherence gain');
title('Is p_\beta mismatch branch-specific?'); grid on;

exportgraphics(fig4, ...
    fullfile(cfg.results_dir,'04_gap_summary.png'), ...
    'Resolution',cfg.figure_resolution);

%% Save workspace
save(fullfile(cfg.results_dir,'EXP02_FAIR_GAP01_workspace.mat'), ...
    'cfg','W','mat_info','Tstate','Landscape','selected_state_ids', ...
    'clone_parameter_support_pass','clone_g0_pass_rate','clone_n3_pass_rate', ...
    'clone_max_g0_error','clone_max_n3_error','clone_max_global_error', ...
    'median_frozen_coh','median_relaxed_coh','median_p_gain','p90_p_gain', ...
    'material_p_gain_fraction','p_boundary_fraction', ...
    'median_frozen_safe','median_frozen_fail', ...
    'median_gain_safe','median_gain_fail','gap_route');

%% Feedback bundle
txt_path = fullfile(cfg.results_dir,'EXP02_FAIR_GAP01_FEEDBACK.txt');
fid = fopen(txt_path,'w');
if fid < 0
    error('EXP02_FAIR_GAP01:FeedbackOpenFailed','Cannot write GAP01 feedback.');
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP02-FAIR-GAP01 REAL-vs-SYNTHETIC GAP AUDIT\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'candidate=B\n');
fprintf(fid,'new_recovery_method=0\n');
fprintf(fid,'N3_retuned=0\n');
fprintf(fid,'TopK_added=0\n');
fprintf(fid,'higher_order_compensation_added=0\n\n');

fprintf(fid,'[FROZEN INPUT]\n');
fprintf(fid,'stem=%s\n',data_stem);
fprintf(fid,'crop_rows=%d:%d\n',r1,r2);
fprintf(fid,'crop_columns=%d:%d\n',c1,c2);
fprintf(fid,'accepted_real_states=%d\n',n_states);
fprintf(fid,'real_nonSAFE_states=%d\n\n',sum(is_failure));

fprintf(fid,'[A_PARAMETER_SUPPORT_SYNTHETIC_CLONES]\n');
fprintf(fid,'clone_definition=exact_quadratic_LFM_at_each_real_state_pbeta_globalnu\n');
fprintf(fid,'G0_truth_match=%d/%d\n',sum(CloneG0Matches),n_states);
fprintf(fid,'N3_truth_match=%d/%d\n',sum(CloneN3Matches),n_states);
fprintf(fid,'G0_truth_match_rate=%.12g\n',clone_g0_pass_rate);
fprintf(fid,'N3_truth_match_rate=%.12g\n',clone_n3_pass_rate);
fprintf(fid,'max_G0_truth_error_bins=%.12g\n',clone_max_g0_error);
fprintf(fid,'max_N3_truth_error_bins=%.12g\n',clone_max_n3_error);
fprintf(fid,'max_Global_truth_error_bins=%.12g\n',clone_max_global_error);
fprintf(fid,'parameter_support_PASS=%d\n\n',clone_parameter_support_pass);

fprintf(fid,'[B_REAL_SINGLE_QUADRATIC_LFM_ADEQUACY]\n');
fprintf(fid,'coherence_definition=squared_normalized_projection_energy_of_best_complex_scalar_atom\n');
fprintf(fid,'p_relax_halfwidth=%.9g\n',cfg.p_relax_halfwidth);
fprintf(fid,'p_relax_step=%.9g\n',cfg.p_relax_step);
fprintf(fid,'median_frozen_atom_coherence=%.12g\n',median_frozen_coh);
fprintf(fid,'median_relaxed_atom_coherence=%.12g\n',median_relaxed_coh);
fprintf(fid,'median_p_relax_gain=%.12g\n',median_p_gain);
fprintf(fid,'p90_p_relax_gain=%.12g\n',p90_p_gain);
fprintf(fid,'material_gain_threshold=%.12g\n',cfg.material_p_relax_gain);
fprintf(fid,'material_gain_fraction=%.12g\n',material_p_gain_fraction);
fprintf(fid,'p_scan_boundary_hit_fraction=%.12g\n',p_boundary_fraction);
fprintf(fid,'median_frozen_coherence_SAFE=%.12g\n',median_frozen_safe);
fprintf(fid,'median_frozen_coherence_nonSAFE=%.12g\n',median_frozen_fail);
fprintf(fid,'median_p_relax_gain_SAFE=%.12g\n',median_gain_safe);
fprintf(fid,'median_p_relax_gain_nonSAFE=%.12g\n\n',median_gain_fail);

fprintf(fid,'[C_REPRESENTATIVE_LANDSCAPES]\n');
fprintf(fid,'selected_state_ids=%s\n',mat2str(selected_state_ids.'));
for ic = 1:numel(Landscape)
    L = Landscape(ic);
    fprintf(fid,['state=%d col=%d taxonomy=%s p=%.6f nu=%.9g ' ...
        'G0err=%.9g coarse_margin=%.9g\n'], ...
        L.state_id,L.range_column,L.taxonomy,L.p0,L.nu0, ...
        L.g0_error_bins,L.coarse_margin);
end

fprintf(fid,'\n[GAP ROUTE]\n');
fprintf(fid,'gap_route=%s\n\n',gap_route);

fprintf(fid,'[INTERPRETATION BOUNDARY]\n');
fprintf(fid,['Synthetic-clone PASS establishes implementation compatibility over ' ...
    'the actual real-state p_beta/nu support. It does not prove that real ' ...
    'ship lines are exact quadratic LFM.\n']);
fprintf(fid,['Real-line atom coherence is computed on the full observed azimuth ' ...
    'line. Low coherence can arise from higher-order phase, multiple ' ...
    'components, clutter, range-cell mixing, or other model mismatch; it ' ...
    'must not be interpreted as unique proof of one mechanism.\n']);
fprintf(fid,['Local p relaxation is intentionally small (+/-0.04). A substantial ' ...
    'gain makes upstream p_beta mismatch plausible; a small gain with low ' ...
    'absolute coherence points instead toward a broader model/mixing gap.\n']);
fprintf(fid,['The 2D landscapes are descriptive geometry diagnostics only. No ' ...
    'new search policy is proposed from them in GAP01.\n']);

fprintf(fid,'\n[UPLOAD REQUEST]\n');
fprintf(fid,'1) EXP02_FAIR_GAP01_FEEDBACK.txt\n');
fprintf(fid,'2) 01_synthetic_clone_parameter_support.png\n');
fprintf(fid,'3) 02_real_single_lfm_adequacy.png\n');
fprintf(fid,'4) 03_joint_landscape_representatives.png\n');
fprintf(fid,'5) 04_gap_summary.png\n');

fprintf('\n============================================================\n');
fprintf('GAP01 complete.\n');
fprintf('Parameter-support clone closure : %s\n',passfail(clone_parameter_support_pass));
fprintf('Median frozen coherence         : %.4f\n',median_frozen_coh);
fprintf('Median local-p gain             : %.4f\n',median_p_gain);
fprintf('Route                           : %s\n',gap_route);
fprintf('Feedback                        : %s\n',txt_path);
fprintf('============================================================\n');

%% Local helpers
function a = pbeta_to_sampled_a(p,N,cfg)
scale = cfg.tnorm_full_span/(N-1);
a = tan(pi*p/2)*scale^2;
end

function C = atom_coherence(x,p,nu,cfg)
x = x(:).';
N = numel(x);
m = 0:N-1;
a = pbeta_to_sampled_a(p,N,cfg);
h = exp(1j*pi*a*m.^2 + 1j*2*pi*nu*m/N);
num = abs(sum(conj(h).*x)).^2;
den = sum(abs(h).^2)*sum(abs(x).^2);
C = num/max(den,eps);
end

function [nu_hat,C] = global_tone_reference_for_p(x,p,cfg)
x = x(:).';
N = numel(x);
m = 0:N-1;
a = pbeta_to_sampled_a(p,N,cfg);
z = x .* exp(-1j*pi*a*m.^2);

os = cfg.p_relax_nu_oversample;
L = N*os;
Y = fftshift(fft(z,L));
if mod(L,2)==0
    k_os = -L/2:(L/2-1);
else
    k_os = -floor(L/2):floor(L/2);
end
qgrid = k_os*(N/L);
J = abs(Y).^2;
[~,ig] = max(J);
i1 = max(1,ig-1);
i2 = min(numel(qgrid),ig+1);
lb = qgrid(i1); ub = qgrid(i2);

if ub<=lb
    nu_hat = qgrid(ig);
    Jhat = J(ig);
else
    opts = optimset('Display','off', ...
        'TolX',cfg.p_relax_nu_tolx_bins, ...
        'MaxFunEvals',cfg.p_relax_nu_max_fun_evals);
    [nu_hat,fval] = fminbnd(@(q)-tone_objective_local(z,q),lb,ub,opts);
    Jhat = -fval;
end

C = Jhat/(N*max(sum(abs(x).^2),eps));
nu_hat = wrap_bin(nu_hat,N);
end

function J = tone_objective_local(z,nu)
N = numel(z);
m = 0:N-1;
q = sum(z.*exp(-1j*2*pi*nu*m/N));
J = abs(q).^2;
end

function p_scan = build_p_scan(p0,cfg)
p_scan = p0 + (-cfg.p_relax_halfwidth:cfg.p_relax_step:cfg.p_relax_halfwidth);
p_scan = p_scan(p_scan>0.02 & p_scan<1.98 & abs(p_scan-1)>1e-8);
p_scan = unique([p_scan(:);p0]);
p_scan = sort(p_scan).';
end

function p_grid = build_landscape_p_grid(p0,cfg)
p_grid = p0 + (-cfg.landscape_p_halfwidth:cfg.landscape_p_step:cfg.landscape_p_halfwidth);
p_grid = p_grid(p_grid>0.02 & p_grid<1.98 & abs(p_grid-1)>1e-8);
p_grid = unique([p_grid(:);p0]);
p_grid = sort(p_grid).';
end

function [J,bins] = joint_landscape(x,p_grid,cfg)
x = x(:).';
N = numel(x);
m = 0:N-1;
bins = -floor(N/2):(ceil(N/2)-1);
J = zeros(numel(p_grid),N);
for ip = 1:numel(p_grid)
    a = pbeta_to_sampled_a(p_grid(ip),N,cfg);
    z = x.*exp(-1j*pi*a*m.^2);
    Y = fftshift(fft(z));
    J(ip,:) = abs(Y).^2/(N*max(sum(abs(x).^2),eps));
end
end

function ids = select_landscape_states(W,is_failure,cfg)
n = numel(is_failure);
g0err = reshape(arrayfun(@(s) s.g0_error_bins,W.Audit),[],1);
margin = reshape(arrayfun(@(s) s.coarse_top1_top2_margin,W.Audit),[],1);
ids = [];
fail_idx = find(is_failure);
safe_idx = find(~is_failure);

if ~isempty(fail_idx)
    [~,ii] = max(g0err(fail_idx));
    ids(end+1,1) = fail_idx(ii); %#ok<AGROW>
end
if ~isempty(fail_idx)
    candidates = setdiff(fail_idx,ids,'stable');
    if ~isempty(candidates)
        [~,ii] = min(margin(candidates));
        ids(end+1,1) = candidates(ii); %#ok<AGROW>
    end
end
if ~isempty(safe_idx)
    [~,ii] = min(margin(safe_idx));
    ids(end+1,1) = safe_idx(ii); %#ok<AGROW>
end
if ~isempty(safe_idx)
    candidates = setdiff(safe_idx,ids,'stable');
    if ~isempty(candidates)
        med = median(margin(candidates));
        [~,ii] = min(abs(margin(candidates)-med));
        ids(end+1,1) = candidates(ii); %#ok<AGROW>
    end
end
if numel(ids)<cfg.n_landscape_cases
    remain = setdiff((1:n).',ids,'stable');
    need = min(cfg.n_landscape_cases-numel(ids),numel(remain));
    ids = [ids;remain(1:need)];
end
ids = ids(1:min(cfg.n_landscape_cases,numel(ids)));
end

function q = wrap_bin(q,N)
q = mod(q+N/2,N)-N/2;
end

function d = circular_bin_distance(a,b,N)
d = abs(mod((a-b)+N/2,N)-N/2);
end

function d = circular_order_distance(a,b)
d = abs(mod((a-b)+1,2)-1);
end

function y = normalize_map(X)
mx = max(X(:));
if mx<=eps
    y = zeros(size(X));
else
    y = X/mx;
end
end

function q = local_percentile(x,p)
x = sort(x(:));
n = numel(x);
if n==0
    q = NaN; return;
elseif n==1
    q = x; return;
end
pos = 1+(n-1)*p/100;
lo = floor(pos); hi = ceil(pos);
if lo==hi
    q = x(lo);
else
    w = pos-lo;
    q = (1-w)*x(lo)+w*x(hi);
end
end

function s = passfail(tf)
if tf
    s = 'PASS';
else
    s = 'FAIL';
end
end
