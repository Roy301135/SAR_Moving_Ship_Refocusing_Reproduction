function run_exp01_stageB3_natural_line_audit()
%RUN_EXP01_STAGEB3_NATURAL_LINE_AUDIT
% EXP01 Stage-B3 — Canonical full target-line natural mechanism audit.
%
% Research question:
%   In the already accepted, untuned canonical yawing-ship SAR scene, do
%   naturally selected target range lines contain the discrete-first branch
%   failure mechanism targeted by Neighbor-3?
%
% This stage is deliberately narrow:
%   - no scene retuning;
%   - no DenseRisk embedding;
%   - no Proposed scheduler;
%   - no noise/clutter;
%   - no new threshold sweep.
%
% If a natural D-class line with Neighbor-3 rescue exists, Stage-C is
% authorized. Otherwise the yaw-only canonical scene is closed for the
% selective-N3 image-level claim.

clc;

%% Resolve repository-local paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
research_root = fileparts(code_dir);
functions_dir = fullfile(research_root,'functions');
addpath(this_dir);
addpath(functions_dir);

cfg = config_exp01_stageB3(research_root);
if ~exist(cfg.results_dir,'dir'), mkdir(cfg.results_dir); end

fprintf('============================================================\n');
fprintf('EXP01 SAR Branch Translation - Stage B3\n');
fprintf('Canonical full target-line natural mechanism audit\n');
fprintf('Scene retuning: NONE\n');
fprintf('Proposed scheduler: NOT RUN\n');
fprintf('Noise / clutter: OFF\n');
fprintf('============================================================\n\n');

%% 1. Load the accepted canonical Stage-A realization
if ~exist(cfg.stageB3.stageA_mat,'file')
    error('EXP01_STAGEB3:MissingStageA', ...
        'Stage-A MAT not found:\n%s',cfg.stageB3.stageA_mat);
end
S = load(cfg.stageB3.stageA_mat, ...
    'cfg','ranges_moving','img_moving');

validate_stageA_contract(cfg,S);

%% 2. Select target range lines from the moving BP SLC by energy
% img_moving is Ny x Nx: rows are range, columns are azimuth.
line_energy = sum(abs(S.img_moving).^2,2);
mean_line_energy = mean(line_energy);
selected_mask = line_energy > mean_line_energy;
selected_rows = find(selected_mask);

if isempty(selected_rows)
    error('EXP01_STAGEB3:NoSelectedLines', ...
        'Energy-above-mean selection returned zero target lines.');
end

fprintf('Selected target lines: %d / %d (energy > mean)\n', ...
    numel(selected_rows),numel(line_energy));

%% 3. Audit every naturally selected range line
n = numel(selected_rows);

line_id = (1:n).';
image_row = selected_rows(:);
y_ref_m = cfg.image.y_axis_m(selected_rows).';
y_offset_m = y_ref_m - cfg.ship_center_y;
line_energy_sel = line_energy(selected_rows);
line_energy_over_mean = line_energy_sel ./ max(mean_line_energy,eps);

dominant_scatterer_idx = nan(n,1);
dominant_energy_fraction = nan(n,1);
second_to_first_component_energy_ratio = nan(n,1);
dominant_a = nan(n,1);
dominant_beta_rad = nan(n,1);
dominant_nu_fit_bins = nan(n,1);
dominant_phase_fit_nrmse = nan(n,1);
dominant_phase_fit_r2 = nan(n,1);
strong_reference_nu_bins = nan(n,1);
mixture_global_nu_bins = nan(n,1);
coarse_top1_bin = nan(n,1);
g0_nu_bins = nan(n,1);
n3_nu_bins = nan(n,1);
g0_error_to_strong_bins = nan(n,1);
n3_error_to_strong_bins = nan(n,1);
mixture_global_error_to_strong_bins = nan(n,1);
g0_error_to_mixture_global_bins = nan(n,1);
n3_error_to_mixture_global_bins = nan(n,1);
coarse_second_over_first = nan(n,1);
g0_catastrophic = false(n,1);
n3_rescue = false(n,1);
mechanism_class = strings(n,1);
unresolved_reason = strings(n,1);

x_ref_m = cfg.stageB3.reference_x_m;

for i = 1:n
    yref = y_ref_m(i);
    Exact = sar_exact_reference_components(cfg,S.ranges_moving,x_ref_m,yref);
    Xc = Exact.components;
    xfull = Exact.full_signal;

    comp_energy = sum(abs(Xc).^2,2);
    [Esort,ord] = sort(comp_energy,'descend');
    pdom = ord(1);
    dominant_scatterer_idx(i) = pdom;
    dominant_energy_fraction(i) = Esort(1) / max(sum(comp_energy),eps);
    if numel(Esort) >= 2
        second_to_first_component_energy_ratio(i) = Esort(2)/max(Esort(1),eps);
    else
        second_to_first_component_energy_ratio(i) = 0;
    end

    xdom = Xc(pdom,:);
    try
        fdom = sar_fit_sampled_lfm(xdom);
    catch ME
        mechanism_class(i) = "U";
        unresolved_reason(i) = "dominant_fit_failed:" + string(ME.identifier);
        continue;
    end

    dominant_a(i) = fdom.a;
    dominant_beta_rad(i) = fdom.beta_rad;
    dominant_nu_fit_bins(i) = fdom.nu_bins;
    dominant_phase_fit_nrmse(i) = fdom.phase_fit_nrmse;
    dominant_phase_fit_r2(i) = fdom.phase_fit_r2;

    % Strong-only global reference at the physical dominant-component a.
    Sref = branch_g0_neighbor3_audit(xdom,fdom.a,fdom.nu_bins,cfg.stageB);
    validate_branch_schema(Sref,'strong-only');
    nu_ref = Sref.global_nu_bins;

    % Full natural line under the same dominant-component dechirp.
    F = branch_g0_neighbor3_audit(xfull,fdom.a,nu_ref,cfg.stageB);
    validate_branch_schema(F,'full-line');

    strong_reference_nu_bins(i) = nu_ref;
    mixture_global_nu_bins(i) = F.global_nu_bins;
    coarse_top1_bin(i) = F.coarse_top1_bin;
    g0_nu_bins(i) = F.G0.nu_hat_bins;
    n3_nu_bins(i) = F.N3.nu_hat_bins;
    g0_error_to_strong_bins(i) = F.g0_error_bins;
    n3_error_to_strong_bins(i) = F.n3_error_bins;
    mixture_global_error_to_strong_bins(i) = F.global_error_bins;
    g0_error_to_mixture_global_bins(i) = circular_bin_distance_local( ...
        F.G0.nu_hat_bins,F.global_nu_bins,cfg.Na);
    n3_error_to_mixture_global_bins(i) = circular_bin_distance_local( ...
        F.N3.nu_hat_bins,F.global_nu_bins,cfg.Na);
    g0_catastrophic(i) = F.g0_catastrophic;
    n3_rescue(i) = F.n3_rescue;

    if numel(F.coarse_top_scores_normalized) >= 2
        coarse_second_over_first(i) = F.coarse_top_scores_normalized(2);
    else
        coarse_second_over_first(i) = NaN;
    end

    [mechanism_class(i),unresolved_reason(i)] = classify_mechanism( ...
        F,nu_ref,cfg);
end

%% 4. Compact line table retained locally
T = table(line_id,image_row,y_ref_m,y_offset_m, ...
    line_energy_sel,line_energy_over_mean, ...
    dominant_scatterer_idx,dominant_energy_fraction, ...
    second_to_first_component_energy_ratio, ...
    dominant_a,dominant_beta_rad,dominant_nu_fit_bins, ...
    dominant_phase_fit_nrmse,dominant_phase_fit_r2, ...
    strong_reference_nu_bins,mixture_global_nu_bins,coarse_top1_bin, ...
    g0_nu_bins,n3_nu_bins, ...
    g0_error_to_strong_bins,n3_error_to_strong_bins, ...
    mixture_global_error_to_strong_bins, ...
    g0_error_to_mixture_global_bins,n3_error_to_mixture_global_bins, ...
    coarse_second_over_first,g0_catastrophic,n3_rescue, ...
    mechanism_class,unresolved_reason);

writetable(T,fullfile(cfg.results_dir,cfg.stageB3.csv_name));

%% 5. Mechanism counts and pre-registered verdict
nE = nnz(mechanism_class=="E");
nB = nnz(mechanism_class=="B");
nD = nnz(mechanism_class=="D");
nG = nnz(mechanism_class=="G");
nU = nnz(mechanism_class=="U");
nDrescue = nnz(mechanism_class=="D" & n3_rescue);
nDunrescued = nnz(mechanism_class=="D" & ~n3_rescue);

if nU > 0
    verdict = "STOP_UNRESOLVED_MECHANISM_CLASSIFICATION";
elseif nDrescue > 0
    verdict = "NATURAL_DISCRETE_FIRST_WITH_N3_RESCUE_PROCEED_STAGEC";
elseif nD > 0
    verdict = "DISCRETE_FIRST_PRESENT_BUT_NO_N3_RESCUE_STOP";
else
    verdict = "NO_NATURAL_DISCRETE_FIRST_IN_CANONICAL_SCENE_STOP_YAW_ONLY";
end

%% 6. Representative line: D+rescue if available, else maximum G0 error
idx_rep = find(mechanism_class=="D" & n3_rescue,1,'first');
if isempty(idx_rep)
    valid = isfinite(g0_error_to_strong_bins);
    if any(valid)
        idx_valid = find(valid);
        [~,jj] = max(g0_error_to_strong_bins(valid));
        idx_rep = idx_valid(jj);
    else
        idx_rep = 1;
    end
end

Rep = rebuild_representative(cfg,S,y_ref_m(idx_rep));

%% 7. Figures
make_stageB3_figures(cfg,S,line_energy,mean_line_energy,T,idx_rep,Rep);

%% 8. MAT and feedback bundle
save(fullfile(cfg.results_dir,cfg.stageB3.save_mat_name), ...
    'cfg','T','selected_rows','line_energy','mean_line_energy', ...
    'verdict','idx_rep','Rep','-v7.3');

write_feedback_bundle(cfg,T,mean_line_energy,verdict,idx_rep, ...
    nE,nB,nD,nG,nU,nDrescue,nDunrescued);

%% Console summary
fprintf('\n================ STAGE-B3 SUMMARY ================\n');
fprintf('Selected lines = %d / %d\n',height(T),numel(line_energy));
fprintf('Classes E/B/D/G/U = %d / %d / %d / %d / %d\n',nE,nB,nD,nG,nU);
fprintf('D-class Neighbor-3 rescue / unrescued = %d / %d\n',nDrescue,nDunrescued);
fprintf('Representative line: id=%d, y offset=%.3f m, class=%s\n', ...
    T.line_id(idx_rep),T.y_offset_m(idx_rep),T.mechanism_class(idx_rep));
fprintf('VERDICT: %s\n',verdict);
fprintf('Feedback: %s\n',fullfile(cfg.results_dir,cfg.stageB3.feedback_bundle_name));
fprintf('===================================================\n');

end

%% ========================================================================
function validate_stageA_contract(cfg,S)
required = {'cfg','ranges_moving','img_moving'};
for i=1:numel(required)
    if ~isfield(S,required{i})
        error('EXP01_STAGEB3:StageASchemaMismatch', ...
            'Stage-A MAT is missing field: %s',required{i});
    end
end
if S.cfg.Na ~= cfg.Na || abs(S.cfg.prf-cfg.prf)>1e-12 || ...
        abs(S.cfg.fc-cfg.fc)>1 || abs(S.cfg.bandwidth-cfg.bandwidth)>1
    error('EXP01_STAGEB3:StageAConfigDrift', ...
        'Current config no longer matches the accepted Stage-A MAT.');
end
if size(S.img_moving,1) ~= numel(cfg.image.y_axis_m)
    error('EXP01_STAGEB3:ImageAxisMismatch', ...
        'img_moving row count does not match cfg.image.y_axis_m.');
end
end

%% ========================================================================
function validate_branch_schema(A,label)
required = {'global_nu_bins','global_error_bins','coarse_top1_bin', ...
    'coarse_top_scores_normalized','G0','N3','g0_error_bins', ...
    'n3_error_bins','g0_catastrophic','n3_rescue','dechirped_signal'};
missing = required(~cellfun(@(f)isfield(A,f),required));
if ~isempty(missing)
    error('EXP01_STAGEB3:BranchSchemaMismatch', ...
        '%s branch audit missing fields: %s',label,strjoin(missing,', '));
end
if ~isfield(A.G0,'nu_hat_bins') || ~isfield(A.N3,'nu_hat_bins')
    error('EXP01_STAGEB3:BranchNestedSchemaMismatch', ...
        '%s G0/N3 result is missing nu_hat_bins.',label);
end
end

%% ========================================================================
function [cls,reason] = classify_mechanism(F,nu_strong_ref,cfg)
% Scientific taxonomy guard. Catastrophic magnitude alone does NOT define
% a branch failure.

cat_thr = cfg.stageB3.catastrophic_error_threshold_bins;
match_tol = cfg.stageB3.branch_match_tolerance_bins;
N = cfg.Na;
reason = "";

if F.g0_error_bins <= cat_thr
    cls = "E";
    return;
end

mix_shift = F.global_error_bins;
strong_branch = nearest_integer_periodic(nu_strong_ref,N);
mix_branch = nearest_integer_periodic(F.global_nu_bins,N);
coarse_branch = nearest_integer_periodic(F.coarse_top1_bin,N);

if mix_shift <= match_tol
    % Correct continuous winner remains matched to the strong reference.
    if coarse_branch ~= strong_branch
        cls = "D";
    else
        cls = "U";
        reason = "G0 catastrophic although mixture global and coarse branch remain matched";
    end
else
    % The continuous mixture optimum itself moved away from strong truth.
    if mix_branch == strong_branch
        cls = "B";
    else
        cls = "G";
    end
end
end

%% ========================================================================
function k = nearest_integer_periodic(nu,N)
k = round(nu);
lo = -floor(N/2);
hi = ceil(N/2)-1;
while k < lo, k = k + N; end
while k > hi, k = k - N; end
end

%% ========================================================================
function d = circular_bin_distance_local(a,b,N)
d = abs(mod((a-b)+N/2,N)-N/2);
end

%% ========================================================================
function Rep = rebuild_representative(cfg,S,yref)
Exact = sar_exact_reference_components(cfg,S.ranges_moving, ...
    cfg.stageB3.reference_x_m,yref);
comp_energy = sum(abs(Exact.components).^2,2);
[~,pdom] = max(comp_energy);
xdom = Exact.components(pdom,:);
xfull = Exact.full_signal;
fdom = sar_fit_sampled_lfm(xdom);
Sref = branch_g0_neighbor3_audit(xdom,fdom.a,fdom.nu_bins,cfg.stageB);
F = branch_g0_neighbor3_audit(xfull,fdom.a,Sref.global_nu_bins,cfg.stageB);
Rep.y_ref_m = yref;
Rep.dominant_scatterer_idx = pdom;
Rep.xdom = xdom;
Rep.xfull = xfull;
Rep.fit = fdom;
Rep.Sref = Sref;
Rep.F = F;
end

%% ========================================================================
function make_stageB3_figures(cfg,S,line_energy,meanE,T,idx_rep,Rep)
vis = cfg.stageB3.figure_visible;
if strcmpi(vis,'on'), v='on'; else, v='off'; end

yoff = cfg.image.y_axis_m(:)-cfg.ship_center_y;

% Figure 09: line selection + taxonomy / error geometry
f1 = figure('Name','EXP01 Stage-B3 Natural Line Taxonomy','Color','w','Visible',v);
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

nexttile;
plot(yoff,line_energy/max(meanE,eps),'-','LineWidth',1.1); hold on;
yline(1,'--','selection threshold = mean');
scatter(T.y_offset_m,T.line_energy_over_mean,30,'filled');
grid on;
xlabel('Ground-range offset (m)'); ylabel('line energy / mean');
title(sprintf('Canonical moving-BP target-line selection | selected %d/%d', ...
    height(T),numel(line_energy)));

nexttile;
plot(T.y_offset_m,T.g0_error_to_strong_bins,'o-','LineWidth',1.0); hold on;
plot(T.y_offset_m,T.mixture_global_error_to_strong_bins,'s-','LineWidth',1.0);
plot(T.y_offset_m,T.n3_error_to_strong_bins,'^-','LineWidth',1.0);
yline(cfg.stageB3.catastrophic_error_threshold_bins,'--','catastrophic threshold');
yline(cfg.stageB3.branch_match_tolerance_bins,':','branch-match tolerance');
for i=1:height(T)
    text(T.y_offset_m(i),max([T.g0_error_to_strong_bins(i), ...
        T.n3_error_to_strong_bins(i),T.mixture_global_error_to_strong_bins(i)])+0.01, ...
        char(T.mechanism_class(i)),'FontSize',8,'HorizontalAlignment','center');
end
grid on; xlabel('Ground-range offset (m)'); ylabel('error to dominant strong reference (bin)');
title('Natural mechanism taxonomy: E=easy, B=continuous bias, D=discrete-first, G=global-winner change');
legend('G0','mixture global','Neighbor-3','Location','best');

exportgraphics(f1,fullfile(cfg.results_dir,'09_stageB3_line_taxonomy.png'),'Resolution',180);

% Figure 10: representative landscape
F = Rep.F; Sref = Rep.Sref;
nu0 = Sref.global_nu_bins;
q = (nu0-cfg.stageB3.landscape_halfwidth_bins): ...
    cfg.stageB3.landscape_step_bins: ...
    (nu0+cfg.stageB3.landscape_halfwidth_bins);
Js = branch_tone_objective(Sref.dechirped_signal,q);
Jf = branch_tone_objective(F.dechirped_signal,q);
Js = Js/max(Js+eps);
Jf = Jf/max(Jf+eps);

f2 = figure('Name','EXP01 Stage-B3 Representative Landscape','Color','w','Visible',v);
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
nexttile;
plot(q,Js,'LineWidth',1.2); hold on;
plot(q,Jf,'--','LineWidth',1.2);
xline(nu0,':','dominant strong reference');
xline(F.global_nu_bins,'-.','mixture global');
xline(F.G0.nu_hat_bins,'--','G0');
xline(F.N3.nu_hat_bins,'-.','N3');
grid on; xlabel('\nu (DFT bins)'); ylabel('normalized objective');
title(sprintf('Representative line id=%d | class=%s | y offset=%.3f m', ...
    T.line_id(idx_rep),T.mechanism_class(idx_rep),T.y_offset_m(idx_rep)));
legend('dominant strong-only','full physical line','Location','best');

nexttile;
stem(F.coarse_bins,F.coarse_objective/max(F.coarse_objective),'filled','MarkerSize',3); hold on;
xline(F.coarse_top1_bin,'--','coarse Top-1');
xline(nu0,':','strong ref');
xline(F.global_nu_bins,'-.','mixture global');
xlim([nu0-cfg.stageB3.landscape_halfwidth_bins, ...
    nu0+cfg.stageB3.landscape_halfwidth_bins]);
ylim([0 1.05]); grid on;
xlabel('integer DFT bin'); ylabel('normalized coarse objective');
title(sprintf('G0 err=%.4f | mixture-global shift=%.4f | N3 err=%.4f | rescue=%d', ...
    F.g0_error_bins,F.global_error_bins,F.n3_error_bins,F.n3_rescue));

exportgraphics(f2,fullfile(cfg.results_dir,'10_stageB3_representative_landscape.png'),'Resolution',180);
end

%% ========================================================================
function write_feedback_bundle(cfg,T,meanE,verdict,idx_rep,nE,nB,nD,nG,nU,nDrescue,nDunrescued)
path = fullfile(cfg.results_dir,cfg.stageB3.feedback_bundle_name);
fid = fopen(path,'w');
if fid<0, error('EXP01_STAGEB3:FeedbackOpenFailed','Could not open %s',path); end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP01 / STAGE-B3 CANONICAL FULL TARGET-LINE NATURAL MECHANISM AUDIT\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'Scene retuning: NONE\n');
fprintf(fid,'DenseRisk embedding: NONE\n');
fprintf(fid,'Proposed scheduler: NOT RUN\n');
fprintf(fid,'Noise / clutter: OFF\n\n');

fprintf(fid,'[RESEARCH QUESTION]\n');
fprintf(fid,['Do naturally selected target range lines in the accepted canonical yawing-ship SAR scene contain ', ...
    'the discrete-first branch failure mechanism targeted by Neighbor-3?\n\n']);

fprintf(fid,'[TARGET-LINE SELECTION]\n');
fprintf(fid,'rule=%s\n',cfg.stageB3.line_selection_rule);
fprintf(fid,'n_image_range_lines=%d\n',numel(cfg.image.y_axis_m));
fprintf(fid,'n_selected_lines=%d\n',height(T));
fprintf(fid,'mean_line_energy=%.12g\n',meanE);
fprintf(fid,'reference_x_m=%.12g\n\n',cfg.stageB3.reference_x_m);

fprintf(fid,'[FROZEN TAXONOMY]\n');
fprintf(fid,'E=G0 not catastrophic relative to dominant strong truth\n');
fprintf(fid,'B=mixture continuous optimum displaced, but nearest-integer branch unchanged\n');
fprintf(fid,'D=mixture global optimum remains matched to strong truth, coarse Top-1 branch changes, G0 catastrophic\n');
fprintf(fid,'G=mixture continuous global optimum changes nearest-integer branch\n');
fprintf(fid,'U=unresolved guard; do not force scientific interpretation\n');
fprintf(fid,'branch_match_tolerance_bins=%.12g\n',cfg.stageB3.branch_match_tolerance_bins);
fprintf(fid,'catastrophic_error_threshold_bins=%.12g\n\n',cfg.stageB3.catastrophic_error_threshold_bins);

fprintf(fid,'[CLASS COUNTS]\n');
fprintf(fid,'E_easy=%d\n',nE);
fprintf(fid,'B_continuous_bias=%d\n',nB);
fprintf(fid,'D_discrete_first=%d\n',nD);
fprintf(fid,'G_global_winner_change=%d\n',nG);
fprintf(fid,'U_unresolved=%d\n',nU);
fprintf(fid,'D_with_N3_rescue=%d\n',nDrescue);
fprintf(fid,'D_without_N3_rescue=%d\n\n',nDunrescued);

fprintf(fid,'[REPRESENTATIVE LINE]\n');
print_line_row(fid,T(idx_rep,:));

% First report every D line (normally small), then a bounded set of the
% largest G0-error lines so the user does not need to upload the CSV.
fprintf(fid,'\n[D-CLASS LINES]\n');
idxD = find(T.mechanism_class=="D");
if isempty(idxD)
    fprintf(fid,'NONE\n');
else
    for j=1:numel(idxD)
        print_line_row(fid,T(idxD(j),:));
    end
end

fprintf(fid,'\n[TOP NON-EASY / HIGH-ERROR LINES]\n');
[~,ord] = sort(T.g0_error_to_strong_bins,'descend','MissingPlacement','last');
ord = ord(1:min(cfg.stageB3.max_feedback_rows,numel(ord)));
for j=1:numel(ord)
    print_line_row(fid,T(ord(j),:));
end

fprintf(fid,'\n[VERDICT]\n');
fprintf(fid,'stageB3_verdict=%s\n',verdict);

fprintf(fid,'\n[STOP / NEXT RULE]\n');
fprintf(fid,'1) If any U line exists: STOP and audit classification/interface only; do not run Proposed.\n');
fprintf(fid,'2) If at least one D line is rescued by Neighbor-3: proceed directly to Stage-C frozen Proposed image-level integration.\n');
fprintf(fid,'3) If D exists but none is rescued: STOP; do not widen Neighbor-3 or retune the scene.\n');
fprintf(fid,'4) If D does not occur: close the canonical yaw-only scene for the selective-N3 SAR claim; do not manufacture a hard case.\n');
fprintf(fid,'5) B/G lines are physically meaningful failure modes but are NOT evidence that the frozen Neighbor-3 branch-recovery claim applies.\n');

fprintf(fid,'\n[UPLOAD REQUEST]\n');
fprintf(fid,'Return only: EXP01_STAGEB3_FEEDBACK_BUNDLE.txt, 09_stageB3_line_taxonomy.png, 10_stageB3_representative_landscape.png. Keep CSV/MAT locally unless a specific anomaly requires them.\n');
end

%% ========================================================================
function print_line_row(fid,R)
fprintf(fid,[ ...
    'line_id=%d\trow=%d\ty_offset_m=%.6g\tclass=%s\tdomP=%d\t' ...
    'domEnergyFrac=%.6g\tsecond/first=%.6g\tphaseNRMSE=%.6g\t' ...
    'strongRef=%.6g\tmixGlobal=%.6g\tcoarseTop1=%.6g\t' ...
    'G0=%.6g\tN3=%.6g\tG0err=%.6g\tmixShift=%.6g\tN3err=%.6g\t' ...
    'N3rescue=%d\ttop2/top1=%.6g\treason=%s\n'], ...
    R.line_id,R.image_row,R.y_offset_m,char(R.mechanism_class), ...
    R.dominant_scatterer_idx,R.dominant_energy_fraction, ...
    R.second_to_first_component_energy_ratio,R.dominant_phase_fit_nrmse, ...
    R.strong_reference_nu_bins,R.mixture_global_nu_bins,R.coarse_top1_bin, ...
    R.g0_nu_bins,R.n3_nu_bins,R.g0_error_to_strong_bins, ...
    R.mixture_global_error_to_strong_bins,R.n3_error_to_strong_bins, ...
    R.n3_rescue,R.coarse_second_over_first,char(R.unresolved_reason));
end
