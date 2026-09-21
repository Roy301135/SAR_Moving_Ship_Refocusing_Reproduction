function run_exp01_stageB4_3d_swing_audit()
%RUN_EXP01_STAGEB4_3D_SWING_AUDIT
% EXP01 Stage-B4 — Literature-anchored full 3-D rigid-body swing audit.
%
% Research question:
%   When the accepted SAR system and sparse ship scene are driven by ONE
%   frozen literature-anchored roll+pitch+yaw rigid-body motion, do naturally
%   selected target range lines enter the discrete-first / Neighbor-3-
%   rescuable branch-vulnerable regime discovered in EXP009/010?
%
% Forbidden in this stage:
%   - motion-type / amplitude / period / phase sweeps;
%   - scene or scatterer retuning;
%   - DenseRisk inverse embedding;
%   - Proposed scheduler;
%   - noise / clutter;
%   - new reliability features or branch thresholds.

clc;

%% Resolve repository-local paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
research_root = fileparts(code_dir);
functions_dir = fullfile(research_root,'functions');
addpath(this_dir);
addpath(functions_dir);

cfg = config_exp01_stageB4(research_root);
if ~exist(cfg.results_dir,'dir'), mkdir(cfg.results_dir); end

fprintf('============================================================\n');
fprintf('EXP01 SAR Branch Translation - Stage B4\n');
fprintf('Literature-anchored full 3-D rigid-body swing audit\n');
fprintf('Scene retuning: NONE\n');
fprintf('Motion sweep: NONE\n');
fprintf('Proposed scheduler: NOT RUN\n');
fprintf('Noise / clutter: OFF\n');
fprintf('============================================================\n\n');

fprintf('Roll  amplitude / period = %.3f deg / %.3f s\n', ...
    cfg.stageB4.motion.amplitude_rad(1)*180/pi,cfg.stageB4.motion.period_s(1));
fprintf('Pitch amplitude / period = %.3f deg / %.3f s\n', ...
    cfg.stageB4.motion.amplitude_rad(2)*180/pi,cfg.stageB4.motion.period_s(2));
fprintf('Yaw   amplitude / period = %.3f deg / %.3f s\n', ...
    cfg.stageB4.motion.amplitude_rad(3)*180/pi,cfg.stageB4.motion.period_s(3));
fprintf('Initial phase (all axes) = %.6f rad\n\n',cfg.stageB4.motion.phase0_rad(1));

%% 1. Build static-center-pose and moving 3-D rigid-body tracks
fprintf('[1/6] Building 3-D rigid-body tracks...\n');
tracks_static = sar_build_ship_tracks_3d(cfg,'static');
tracks_moving = sar_build_ship_tracks_3d(cfg,'moving');
ranges_static = sar_compute_slant_ranges(cfg,tracks_static);
ranges_moving = sar_compute_slant_ranges(cfg,tracks_moving);

% Guard against silent truncation by the inherited range grid.
range_min = min(ranges_moving(:));
range_max = max(ranges_moving(:));
if range_min < min(cfg.range_axis_m) || range_max > max(cfg.range_axis_m)
    error('EXP01_STAGEB4:RangeGridCoverage', ...
        ['3-D motion leaves the inherited range grid. Moving range=[%.3f, %.3f] m, ', ...
         'grid=[%.3f, %.3f] m. Do not silently enlarge the grid after seeing branch results.'], ...
        range_min,range_max,min(cfg.range_axis_m),max(cfg.range_axis_m));
end

%% 2. Generate range-compressed data and stationary-reference BP images
fprintf('[2/6] Generating range-compressed static / 3-D moving echoes...\n');
echo_static = sar_generate_range_compressed_echo(cfg,ranges_static);
echo_moving = sar_generate_range_compressed_echo(cfg,ranges_moving);

fprintf('[3/6] Backprojecting static / 3-D moving scenes...\n');
img_static = sar_backprojection_static_reference(cfg,echo_static);
img_moving = sar_backprojection_static_reference(cfg,echo_moving);

%% 3. Physical local-quadratic audit for all scatterers (diagnostic only)
model_audit = sar_model_consistency_audit(cfg,ranges_static,ranges_moving);

%% 4. Natural target-line selection from the 3-D moving BP SLC
line_energy = sum(abs(img_moving).^2,2);
mean_line_energy = mean(line_energy);
selected_rows = find(line_energy > mean_line_energy);
if isempty(selected_rows)
    error('EXP01_STAGEB4:NoSelectedLines', ...
        'Energy-above-mean selection returned zero target lines.');
end
fprintf('[4/6] Selected natural target lines: %d / %d\n', ...
    numel(selected_rows),numel(line_energy));

%% 5. Audit every selected line using the frozen Stage-B3 taxonomy
fprintf('[5/6] Auditing natural 3-D target-line branch geometry...\n');
T = audit_selected_lines(cfg,ranges_moving,line_energy,mean_line_energy,selected_rows);
writetable(T,fullfile(cfg.results_dir,cfg.stageB4.csv_name));

nE = nnz(T.mechanism_class=="E");
nB = nnz(T.mechanism_class=="B");
nD = nnz(T.mechanism_class=="D");
nG = nnz(T.mechanism_class=="G");
nU = nnz(T.mechanism_class=="U");
nDrescue = nnz(T.mechanism_class=="D" & T.n3_rescue);
nDunrescued = nnz(T.mechanism_class=="D" & ~T.n3_rescue);

if nU > 0
    verdict = "STOP_UNRESOLVED_3D_MECHANISM_CLASSIFICATION";
elseif nDrescue > 0
    verdict = "NATURAL_3D_DISCRETE_FIRST_WITH_N3_RESCUE_CANDIDATE_STAGEC";
elseif nD > 0
    verdict = "3D_DISCRETE_FIRST_PRESENT_BUT_NO_N3_RESCUE_STOP";
else
    verdict = "NO_NATURAL_DISCRETE_FIRST_IN_LITERATURE_ANCHORED_3D_CLOSE_SIMULATION";
end

% Representative line: D+rescue first, else maximum G0 error.
idx_rep = find(T.mechanism_class=="D" & T.n3_rescue,1,'first');
if isempty(idx_rep)
    valid = isfinite(T.g0_error_to_strong_bins);
    if any(valid)
        idxv = find(valid);
        [~,jj] = max(T.g0_error_to_strong_bins(valid));
        idx_rep = idxv(jj);
    else
        idx_rep = 1;
    end
end
Rep = rebuild_representative(cfg,ranges_moving,T.y_ref_m(idx_rep));

%% 6. Figures, MAT and compact feedback bundle
fprintf('[6/6] Writing figures / feedback bundle...\n');
make_figures(cfg,tracks_static,tracks_moving,img_static,img_moving, ...
    line_energy,mean_line_energy,T,idx_rep,Rep);

save(fullfile(cfg.results_dir,cfg.stageB4.save_mat_name), ...
    'cfg','tracks_static','tracks_moving','ranges_static','ranges_moving', ...
    'echo_static','echo_moving','img_static','img_moving','model_audit', ...
    'line_energy','mean_line_energy','selected_rows','T','verdict', ...
    'idx_rep','Rep','-v7.3');

write_feedback_bundle(cfg,tracks_moving,model_audit,T,mean_line_energy, ...
    verdict,idx_rep,nE,nB,nD,nG,nU,nDrescue,nDunrescued);

fprintf('\n================ STAGE-B4 SUMMARY ================\n');
fprintf('Selected lines = %d / %d\n',height(T),numel(line_energy));
fprintf('Classes E/B/D/G/U = %d / %d / %d / %d / %d\n',nE,nB,nD,nG,nU);
fprintf('D-class Neighbor-3 rescue / unrescued = %d / %d\n',nDrescue,nDunrescued);
fprintf('Representative line: id=%d, y offset=%.3f m, class=%s\n', ...
    T.line_id(idx_rep),T.y_offset_m(idx_rep),T.mechanism_class(idx_rep));
fprintf('VERDICT: %s\n',verdict);
fprintf('Feedback: %s\n',fullfile(cfg.results_dir,cfg.stageB4.feedback_bundle_name));
fprintf('===================================================\n');

end

%% ========================================================================
function T = audit_selected_lines(cfg,ranges_moving,line_energy,meanE,selected_rows)
n = numel(selected_rows);

line_id = (1:n).';
image_row = selected_rows(:);
y_ref_m = cfg.image.y_axis_m(selected_rows).';
y_offset_m = y_ref_m - cfg.ship_center_y;
line_energy_sel = line_energy(selected_rows);
line_energy_over_mean = line_energy_sel ./ max(meanE,eps);

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

x_ref_m = cfg.stageB4.reference_x_m;

for i = 1:n
    yref = y_ref_m(i);
    Exact = sar_exact_reference_components(cfg,ranges_moving,x_ref_m,yref);
    Xc = Exact.components;
    xfull = Exact.full_signal;

    comp_energy = sum(abs(Xc).^2,2);
    [Esort,ord] = sort(comp_energy,'descend');
    pdom = ord(1);
    dominant_scatterer_idx(i) = pdom;
    dominant_energy_fraction(i) = Esort(1)/max(sum(comp_energy),eps);
    if numel(Esort)>=2
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

    try
        Sref = branch_g0_neighbor3_audit(xdom,fdom.a,fdom.nu_bins,cfg.stageB);
        validate_branch_schema(Sref,'strong-only');
        nu_ref = Sref.global_nu_bins;

        F = branch_g0_neighbor3_audit(xfull,fdom.a,nu_ref,cfg.stageB);
        validate_branch_schema(F,'full-line');
    catch ME
        mechanism_class(i) = "U";
        unresolved_reason(i) = "branch_audit_failed:" + string(ME.identifier);
        continue;
    end

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

    if numel(F.coarse_top_scores_normalized)>=2
        coarse_second_over_first(i) = F.coarse_top_scores_normalized(2);
    end

    [mechanism_class(i),unresolved_reason(i)] = classify_mechanism(F,nu_ref,cfg);
end

T = table(line_id,image_row,y_ref_m,y_offset_m, ...
    line_energy_sel,line_energy_over_mean, ...
    dominant_scatterer_idx,dominant_energy_fraction, ...
    second_to_first_component_energy_ratio, ...
    dominant_a,dominant_beta_rad,dominant_nu_fit_bins, ...
    dominant_phase_fit_nrmse,dominant_phase_fit_r2, ...
    strong_reference_nu_bins,mixture_global_nu_bins,coarse_top1_bin, ...
    g0_nu_bins,n3_nu_bins,g0_error_to_strong_bins,n3_error_to_strong_bins, ...
    mixture_global_error_to_strong_bins,g0_error_to_mixture_global_bins, ...
    n3_error_to_mixture_global_bins,coarse_second_over_first, ...
    g0_catastrophic,n3_rescue,mechanism_class,unresolved_reason);
end

%% ========================================================================
function validate_branch_schema(A,label)
required = {'global_nu_bins','global_error_bins','coarse_top1_bin', ...
    'coarse_top_scores_normalized','coarse_bins','coarse_objective', ...
    'G0','N3','g0_error_bins','n3_error_bins','g0_catastrophic', ...
    'n3_rescue','dechirped_signal'};
missing = required(~cellfun(@(f)isfield(A,f),required));
if ~isempty(missing)
    error('EXP01_STAGEB4:BranchSchemaMismatch', ...
        '%s branch audit missing fields: %s',label,strjoin(missing,', '));
end
if ~isfield(A.G0,'nu_hat_bins') || ~isfield(A.N3,'nu_hat_bins')
    error('EXP01_STAGEB4:BranchNestedSchemaMismatch', ...
        '%s G0/N3 result is missing nu_hat_bins.',label);
end
end

%% ========================================================================
function [cls,reason] = classify_mechanism(F,nu_strong_ref,cfg)
% Same frozen scientific taxonomy as Stage-B3. Catastrophic magnitude alone
% does NOT define a branch failure.
cat_thr = cfg.stageB4.catastrophic_error_threshold_bins;
match_tol = cfg.stageB4.branch_match_tolerance_bins;
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
    if coarse_branch ~= strong_branch
        cls = "D";
    else
        cls = "U";
        reason = "G0 catastrophic although mixture global and coarse branch remain matched";
    end
else
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
function Rep = rebuild_representative(cfg,ranges_moving,yref)
Exact = sar_exact_reference_components(cfg,ranges_moving, ...
    cfg.stageB4.reference_x_m,yref);
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
function make_figures(cfg,tracks_static,tracks_moving,img_static,img_moving, ...
    line_energy,meanE,T,idx_rep,Rep)
vis = cfg.stageB4.figure_visible;
if strcmpi(vis,'on'), v='on'; else, v='off'; end

% Figure 11: frozen 3-D motion, moving image, line selection, taxonomy.
f1 = figure('Name','EXP01 Stage-B4 3D Scene and Taxonomy','Color','w','Visible',v);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

nexttile;
plot(cfg.eta,tracks_moving.theta_x*180/pi,'LineWidth',1.1); hold on;
plot(cfg.eta,tracks_moving.theta_y*180/pi,'LineWidth',1.1);
plot(cfg.eta,tracks_moving.theta_z*180/pi,'LineWidth',1.1);
grid on; xlabel('Slow time \eta (s)'); ylabel('Angle (deg)');
title('Frozen literature-anchored 3-D swing');
legend('roll','pitch','yaw','Location','best');

nexttile;
common_peak = max([abs(img_static(:)); abs(img_moving(:))]);
moving_db = 20*log10(max(abs(img_moving)/max(common_peak,eps), ...
    10^(-cfg.display.dynamic_range_db/20)));
imagesc(cfg.image.x_axis_m,cfg.image.y_axis_m-cfg.ship_center_y,moving_db);
axis xy equal tight; caxis([-cfg.display.dynamic_range_db 0]); colorbar;
hold on;
cidx = (cfg.Na+1)/2;
scatter(tracks_static.x(:,cidx),tracks_static.y(:,cidx)-cfg.ship_center_y, ...
    22,'w','o','LineWidth',0.8);
xlabel('Azimuth x (m)'); ylabel('Ground-range offset (m)');
title('3-D moving target under stationary-reference BP');

nexttile;
yoff = cfg.image.y_axis_m(:)-cfg.ship_center_y;
plot(yoff,line_energy/max(meanE,eps),'-','LineWidth',1.1); hold on;
yline(1,'--','selection threshold = mean');
scatter(T.y_offset_m,T.line_energy_over_mean,28,'filled');
grid on; xlabel('Ground-range offset (m)'); ylabel('line energy / mean');
title(sprintf('Natural target-line selection | selected %d/%d', ...
    height(T),numel(line_energy)));

nexttile;
plot(T.y_offset_m,T.g0_error_to_strong_bins,'o-','LineWidth',1.0); hold on;
plot(T.y_offset_m,T.mixture_global_error_to_strong_bins,'s-','LineWidth',1.0);
plot(T.y_offset_m,T.n3_error_to_strong_bins,'^-','LineWidth',1.0);
yline(cfg.stageB4.catastrophic_error_threshold_bins,'--','catastrophic threshold');
yline(cfg.stageB4.branch_match_tolerance_bins,':','branch-match tolerance');
for i=1:height(T)
    vals = [T.g0_error_to_strong_bins(i),T.n3_error_to_strong_bins(i), ...
        T.mixture_global_error_to_strong_bins(i)];
    yy = max(vals(isfinite(vals)));
    if isempty(yy), yy = 0; end
    text(T.y_offset_m(i),yy+0.01,char(T.mechanism_class(i)), ...
        'FontSize',8,'HorizontalAlignment','center');
end
grid on; xlabel('Ground-range offset (m)');
ylabel('error to dominant strong reference (bin)');
title('3-D natural mechanism taxonomy');
legend('G0','mixture global','Neighbor-3','Location','best');

exportgraphics(f1,fullfile(cfg.results_dir,'11_stageB4_3d_scene_and_taxonomy.png'),'Resolution',180);

% Figure 12: representative branch landscape.
F = Rep.F; Sref = Rep.Sref;
nu0 = Sref.global_nu_bins;
q = (nu0-cfg.stageB4.landscape_halfwidth_bins): ...
    cfg.stageB4.landscape_step_bins: ...
    (nu0+cfg.stageB4.landscape_halfwidth_bins);
Js = branch_tone_objective(Sref.dechirped_signal,q);
Jf = branch_tone_objective(F.dechirped_signal,q);
Js = Js/max(max(Js),eps);
Jf = Jf/max(max(Jf),eps);

f2 = figure('Name','EXP01 Stage-B4 Representative Landscape','Color','w','Visible',v);
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
nexttile;
plot(q,Js,'LineWidth',1.2); hold on;
plot(q,Jf,'--','LineWidth',1.2);
xline(nu0,':','dominant strong reference');
xline(F.global_nu_bins,'-.','mixture global');
xline(F.G0.nu_hat_bins,'--','G0');
xline(F.N3.nu_hat_bins,'-.','N3');
grid on; xlabel('\nu (DFT bins)'); ylabel('normalized objective');
title(sprintf('Representative 3-D line id=%d | class=%s | y offset=%.3f m', ...
    T.line_id(idx_rep),T.mechanism_class(idx_rep),T.y_offset_m(idx_rep)));
legend('dominant strong-only','full physical line','Location','best');

nexttile;
stem(F.coarse_bins,F.coarse_objective/max(max(F.coarse_objective),eps), ...
    'filled','MarkerSize',3); hold on;
xline(F.coarse_top1_bin,'--','coarse Top-1');
xline(nu0,':','strong ref');
xline(F.global_nu_bins,'-.','mixture global');
xlim([nu0-cfg.stageB4.landscape_halfwidth_bins, ...
    nu0+cfg.stageB4.landscape_halfwidth_bins]);
ylim([0 1.05]); grid on;
xlabel('integer DFT bin'); ylabel('normalized coarse objective');
title(sprintf('G0 err=%.4f | mixture-global shift=%.4f | N3 err=%.4f | rescue=%d', ...
    F.g0_error_bins,F.global_error_bins,F.n3_error_bins,F.n3_rescue));

exportgraphics(f2,fullfile(cfg.results_dir,'12_stageB4_representative_landscape.png'),'Resolution',180);
end

%% ========================================================================
function write_feedback_bundle(cfg,tracks_moving,model_audit,T,meanE,verdict, ...
    idx_rep,nE,nB,nD,nG,nU,nDrescue,nDunrescued)
path = fullfile(cfg.results_dir,cfg.stageB4.feedback_bundle_name);
fid = fopen(path,'w');
if fid<0
    error('EXP01_STAGEB4:FeedbackOpenFailed','Could not open %s',path);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP01 / STAGE-B4 LITERATURE-ANCHORED FULL 3-D SWING NATURAL BRANCH AUDIT\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'Scene retuning: NONE\n');
fprintf(fid,'Motion sweep: NONE\n');
fprintf(fid,'DenseRisk embedding: NONE\n');
fprintf(fid,'Proposed scheduler: NOT RUN\n');
fprintf(fid,'Noise / clutter: OFF\n\n');

fprintf(fid,'[RESEARCH QUESTION]\n');
fprintf(fid,['Can one frozen literature-anchored roll+pitch+yaw rigid-body SAR scene ', ...
    'naturally enter the discrete-first / Neighbor-3-rescuable branch-vulnerable regime?\n\n']);

fprintf(fid,'[FROZEN 3-D MOTION]\n');
fprintf(fid,'rotation_convention=%s\n',cfg.stageB4.motion.rotation_convention);
for k=1:3
    fprintf(fid,'%s_amplitude_deg=%.12g\n',cfg.stageB4.motion.axes{k}, ...
        cfg.stageB4.motion.amplitude_rad(k)*180/pi);
    fprintf(fid,'%s_period_s=%.12g\n',cfg.stageB4.motion.axes{k}, ...
        cfg.stageB4.motion.period_s(k));
    fprintf(fid,'%s_phase0_rad=%.12g\n',cfg.stageB4.motion.axes{k}, ...
        cfg.stageB4.motion.phase0_rad(k));
end
fprintf(fid,'rotation_max_orthogonality_error=%.12g\n', ...
    tracks_moving.max_rotation_orthogonality_error);
fprintf(fid,'rotation_max_determinant_error=%.12g\n\n', ...
    tracks_moving.max_rotation_determinant_error);

fprintf(fid,'[SCATTERER-LEVEL QUADRATIC PHASE DIAGNOSTIC]\n');
qa = model_audit.table.quadratic_fit_nrmse;
fprintf(fid,'median_quadratic_fit_nrmse=%.12g\n',median(qa,'omitnan'));
fprintf(fid,'max_quadratic_fit_nrmse=%.12g\n',max(qa,[],'omitnan'));
fprintf(fid,'review_threshold_nrmse=%.12g (reporting guard only; not an algorithm parameter)\n\n', ...
    cfg.stageB4.lfm_review_nrmse);

fprintf(fid,'[TARGET-LINE SELECTION]\n');
fprintf(fid,'rule=%s\n',cfg.stageB4.line_selection_rule);
fprintf(fid,'n_image_range_lines=%d\n',numel(cfg.image.y_axis_m));
fprintf(fid,'n_selected_lines=%d\n',height(T));
fprintf(fid,'mean_line_energy=%.12g\n',meanE);
fprintf(fid,'reference_x_m=%.12g\n\n',cfg.stageB4.reference_x_m);

fprintf(fid,'[FROZEN TAXONOMY]\n');
fprintf(fid,'E=G0 not catastrophic relative to dominant strong truth\n');
fprintf(fid,'B=mixture continuous optimum displaced, but nearest-integer branch unchanged\n');
fprintf(fid,'D=mixture global optimum remains matched to strong truth, coarse Top-1 branch changes, G0 catastrophic\n');
fprintf(fid,'G=mixture continuous global optimum changes nearest-integer branch\n');
fprintf(fid,'U=unresolved guard; do not force scientific interpretation\n');
fprintf(fid,'branch_match_tolerance_bins=%.12g\n',cfg.stageB4.branch_match_tolerance_bins);
fprintf(fid,'catastrophic_error_threshold_bins=%.12g\n\n',cfg.stageB4.catastrophic_error_threshold_bins);

fprintf(fid,'[CLASS COUNTS]\n');
fprintf(fid,'E_easy=%d\n',nE);
fprintf(fid,'B_continuous_bias=%d\n',nB);
fprintf(fid,'D_discrete_first=%d\n',nD);
fprintf(fid,'G_global_winner_change=%d\n',nG);
fprintf(fid,'U_unresolved=%d\n',nU);
fprintf(fid,'D_with_N3_rescue=%d\n',nDrescue);
fprintf(fid,'D_without_N3_rescue=%d\n\n',nDunrescued);

fprintf(fid,'[SELECTED-LINE LFM DIAGNOSTIC]\n');
qline = T.dominant_phase_fit_nrmse;
fprintf(fid,'median_dominant_phase_fit_nrmse=%.12g\n',median(qline,'omitnan'));
fprintf(fid,'max_dominant_phase_fit_nrmse=%.12g\n',max(qline,[],'omitnan'));
fprintf(fid,'n_lines_above_review_threshold=%d\n\n', ...
    nnz(qline > cfg.stageB4.lfm_review_nrmse));

fprintf(fid,'[REPRESENTATIVE LINE]\n');
print_line_row(fid,T(idx_rep,:));

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
ord = ord(1:min(cfg.stageB4.max_feedback_rows,numel(ord)));
for j=1:numel(ord)
    print_line_row(fid,T(ord(j),:));
end

fprintf(fid,'\n[VERDICT]\n');
fprintf(fid,'stageB4_verdict=%s\n',verdict);

fprintf(fid,'\n[STOP / NEXT RULE]\n');
fprintf(fid,'1) No motion/scene retuning is allowed after this run.\n');
fprintf(fid,'2) If any U line exists: audit classification/interface only; do not run Proposed.\n');
fprintf(fid,'3) If at least one physically interpretable D line is rescued by Neighbor-3: discuss physical realizability briefly, then proceed to Stage-C frozen Proposed image-level integration.\n');
fprintf(fid,'4) If D exists but none is rescued: stop; do not widen Neighbor-3.\n');
fprintf(fid,'5) If D does not occur: close controlled rigid-body simulation for the selective-N3 branch claim and do not add more simulated motion families merely to manufacture failure.\n');
fprintf(fid,'6) The hard-state physical-realizability view may be retained as interpretation/future work, not expanded into a new main research line here.\n');

fprintf(fid,'\n[UPLOAD REQUEST]\n');
fprintf(fid,['Return only: EXP01_STAGEB4_FEEDBACK_BUNDLE.txt, ', ...
    '11_stageB4_3d_scene_and_taxonomy.png, ', ...
    '12_stageB4_representative_landscape.png. Keep CSV/MAT locally unless a specific anomaly requires them.\n']);
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
