%% run_exp02_fair_r1d_candidate_c_replication.m
% EXP02-FAIR-R1D
% Candidate C Independent Replication
%
% Frozen pipeline:
%   1) complex interface / orientation sanity
%   2) official OBB + 32px margin crop
%   3) Wang E(n)>mean(E) ship-line pool
%   4) corrected Eq.(31) + phase-permutation linewise max-stat component gate
%   5) G0 / N3 / eval-only continuous global reference
%   6) R1C-style failure geometry + local recurrence
%
% IMPORTANT:
%   - no parameters are tuned from Candidate-C results
%   - no Candidate-B workspace is used to pick Candidate-C lines/components
%   - Proposed / Refined-LR / FiveBin are NOT run
%   - inverse focusing is NOT run
%
% Upload:
%   EXP02_FAIR_R1D_FEEDBACK.txt
%   01_candidate_c_interface_crop.png
%   02_candidate_c_component_states.png
%   03_candidate_c_branch_occurrence.png
%   04_candidate_c_failure_geometry.png
%   05_candidate_c_selected_failure_landscapes.png

clear; clc; close all;

%% 0. Project paths
this_file = mfilename('fullpath');
fair_code_dir = fileparts(this_file);
exp02_code_dir = fileparts(fair_code_dir);
code_dir = fileparts(exp02_code_dir);
research_dir = fileparts(code_dir);
research_parent = fileparts(research_dir);
repo_root = fileparts(research_parent);

addpath(fair_code_dir);
addpath(genpath(fullfile(research_dir,'functions')));
addpath(genpath(fullfile(repo_root,'papers')));

cfg = config_exp02_fair_r1d_candidate_c(research_dir,repo_root);

if ~exist(cfg.results_dir,'dir')
    mkdir(cfg.results_dir);
end

%% 1. Contract checks
required_files = {cfg.mat_path,cfg.png_path,cfg.xml_path};

for i = 1:numel(required_files)
    if exist(required_files{i},'file') ~= 2
        error('EXP02_FAIR_R1D:MissingInput', ...
            'Required Candidate-C input missing: %s',required_files{i});
    end
end

required_fns = { ...
    'fair_csar_load_complex_mat', ...
    'fair_csar_read_metadata_xml', ...
    'fair_csar_png_orientation_corr', ...
    'fair_csar_fractional_line_audit', ...
    'branch_real_g0_neighbor3_audit', ...
    'branch_refine_from_seed', ...
    'branch_tone_objective'};

for i = 1:numel(required_fns)
    if exist(required_fns{i},'file') ~= 2
        error('EXP02_FAIR_R1D:MissingFunction', ...
            'Required function not found: %s',required_fns{i});
    end
end

%% 2. Load Candidate C and run interface sanity
[S,mat_info] = fair_csar_load_complex_mat(cfg.mat_path);
meta = fair_csar_read_metadata_xml(cfg.xml_path);
orient = fair_csar_png_orientation_corr(S,cfg.png_path);

S = double(S);

fprintf('============================================================\n');
fprintf('EXP02-FAIR-R1D CANDIDATE-C INDEPENDENT REPLICATION\n');
fprintf('Stem          : %s\n',cfg.stem);
fprintf('MAT size      : %d x %d\n',size(S,1),size(S,2));
fprintf('Complex       : %d\n',mat_info.is_complex);
fprintf('PNG raw corr  : %.6f | best=%s (%.6f)\n', ...
    orient.raw_corr,orient.best_name,orient.best_corr);
fprintf('Sub-category  : %s\n',meta.sub_category);
fprintf('============================================================\n\n');

if ~mat_info.is_complex
    error('EXP02_FAIR_R1D:NotComplex','Candidate C MAT is not complex.');
end

if orient.raw_corr < cfg.min_png_corr
    error('EXP02_FAIR_R1D:LowPNGCorrelation', ...
        'RAW MAT/PNG correlation %.4f < %.2f.', ...
        orient.raw_corr,cfg.min_png_corr);
end

if orient.best_name ~= "raw"
    error('EXP02_FAIR_R1D:OrientationMismatch', ...
        'RAW orientation is not best; best=%s.',orient.best_name);
end

if size(S,1) ~= meta.patch_height || size(S,2) ~= meta.patch_width
    error('EXP02_FAIR_R1D:XMLSizeMismatch', ...
        'MAT dimensions disagree with XML patch size.');
end

if ~strcmp(meta.sub_category,'Motion_Defocusing_Ship')
    error('EXP02_FAIR_R1D:WrongSubcategory', ...
        'Candidate C XML sub-category is %s, not Motion_Defocusing_Ship.', ...
        meta.sub_category);
end

%% 3. Frozen crop from official polygon + margin
x_min = floor(min(meta.x));
x_max = ceil(max(meta.x));
y_min = floor(min(meta.y));
y_max = ceil(max(meta.y));

r1 = max(1,y_min-cfg.crop_margin_px);
r2 = min(size(S,1),y_max+cfg.crop_margin_px);
c1 = max(1,x_min-cfg.crop_margin_px);
c2 = min(size(S,2),x_max+cfg.crop_margin_px);

G = S(r1:r2,c1:c2);

%% 4. Wang-style full ship-line pool
line_energy = sum(abs(G).^2,1);
target_local_all = find(line_energy > mean(line_energy));
target_global_all = c1-1+target_local_all;

n_lines = numel(target_global_all);

if n_lines < 1
    error('EXP02_FAIR_R1D:NoShipLines', ...
        'No Candidate-C crop columns survive E(n)>mean(E).');
end

fprintf('Crop rows     : %d:%d (%d samples)\n',r1,r2,r2-r1+1);
fprintf('Crop columns  : %d:%d\n',c1,c2);
fprintf('Wang ship pool: %d lines\n\n',n_lines);

%% 5. Branch-interface self-test
run_interface_self_test(cfg);

%% 6. Frozen component screen over Candidate C pool
p_grid = cfg.p_grid(:).';
Np = numel(p_grid);

guard_mask = abs(p_grid-cfg.phase_blind_order) > ...
    (cfg.phase_guard_halfwidth+1e-12);

rng(cfg.phase_rng_seed,'twister');

line_threshold = nan(n_lines,1);
line_n_components = zeros(n_lines,1);
line_peak_orders = cell(n_lines,1);
line_peak_values = cell(n_lines,1);
line_peak_excess = cell(n_lines,1);

StateLineIndex = [];
StateRangeColumn = [];
StatePbeta = [];
StateFracEnergy = [];
StateExcessAboveMaxStat95 = [];

for il = 1:n_lines
    col = target_global_all(il);
    x = S(r1:r2,col);

    ar = fair_csar_fractional_line_audit(x,p_grid,0);
    real_curve = ar.frac_energy;

    amp = abs(x(:).');
    ph = angle(x(:).');

    surrogate_max = zeros(cfg.n_surrogates,1);

    for is = 1:cfg.n_surrogates
        xs = amp .* exp(1j*ph(randperm(numel(ph))));

        as = fair_csar_fractional_line_audit(xs,p_grid,0);
        surrogate_max(is) = max(as.frac_energy(guard_mask));
    end

    q95 = vector_percentile(surrogate_max,cfg.surrogate_max_percentile);
    line_threshold(il) = q95;

    is_local = false(1,Np);

    for ip = 2:Np-1
        is_local(ip) = ...
            (real_curve(ip)>real_curve(ip-1)) && ...
            (real_curve(ip)>=real_curve(ip+1));
    end

    cand = find(is_local & guard_mask & (real_curve>q95));

    keep = nms_peak_indices( ...
        cand,real_curve,p_grid,cfg.within_line_nms_tolerance);

    line_n_components(il) = numel(keep);
    line_peak_orders{il} = p_grid(keep);
    line_peak_values{il} = real_curve(keep);
    line_peak_excess{il} = real_curve(keep)-q95;

    for jj = 1:numel(keep)
        ip = keep(jj);

        StateLineIndex(end+1,1) = il; %#ok<AGROW>
        StateRangeColumn(end+1,1) = col; %#ok<AGROW>
        StatePbeta(end+1,1) = p_grid(ip); %#ok<AGROW>
        StateFracEnergy(end+1,1) = real_curve(ip); %#ok<AGROW>
        StateExcessAboveMaxStat95(end+1,1) = real_curve(ip)-q95; %#ok<AGROW>
    end

    fprintf('component %3d/%3d | col=%d | n=%d | p=%s\n', ...
        il,n_lines,col,numel(keep),mat2str(p_grid(keep),3));
end

n_states = numel(StatePbeta);
n_lines_with_state = sum(line_n_components>0);

fprintf('\nAccepted Candidate-C component states: %d on %d/%d ship lines\n\n', ...
    n_states,n_lines_with_state,n_lines);

if n_states < 1
    error('EXP02_FAIR_R1D:NoValidComponents', ...
        'Candidate C produced no valid component states under frozen gate.');
end

%% 7. Branch occurrence audit
Audit = struct([]);

for is = 1:n_states
    col = StateRangeColumn(is);
    p_beta = StatePbeta(is);

    x = S(r1:r2,col);
    N = numel(x);

    a = pbeta_to_sampled_a(p_beta,N,cfg);

    A = branch_real_g0_neighbor3_audit(x,a,cfg.stage);

    A.state_id = is;
    A.source_pool_line_index = StateLineIndex(is);
    A.range_column = col;
    A.p_beta = p_beta;
    A.frac_energy = StateFracEnergy(is);
    A.frac_excess_above_maxstat95 = StateExcessAboveMaxStat95(is);

    if is == 1
        Audit = repmat(A,n_states,1);
    else
        Audit(is) = A;
    end

    fprintf('branch %3d/%3d | col=%d p=%.2f | G0=%.4g N3=%.4g | %s\n', ...
        is,n_states,col,p_beta,A.g0_error_bins,A.n3_error_bins,char(A.taxonomy));
end

%% 8. Compact state arrays
TaxonomyCell = arrayfun(@(s) char(s.taxonomy),Audit,'UniformOutput',false);
Taxonomy = reshape(string(TaxonomyCell),[],1);

G0ErrorBins = reshape(arrayfun(@(s) s.g0_error_bins,Audit),[],1);
N3ErrorBins = reshape(arrayfun(@(s) s.n3_error_bins,Audit),[],1);
CoarseMargin = reshape(arrayfun(@(s) s.coarse_top1_top2_margin,Audit),[],1);

is_safe = Taxonomy=="SAFE";
is_rescue = Taxonomy=="G0_FAIL_N3_RESCUE";
is_miss = Taxonomy=="N3_COVERAGE_MISS";
is_persist = Taxonomy=="PERSISTENT_WITHIN_COVERAGE";

n_safe = sum(is_safe);
n_rescue = sum(is_rescue);
n_miss = sum(is_miss);
n_persist = sum(is_persist);
n_fail = n_states-n_safe;

failure_idx = find(~is_safe);

%% 9. R1C-style failure credibility + search geometry
n_failure = numel(failure_idx);

FailureRecurrent = false(n_failure,1);
FailureLocalSupport = zeros(n_failure,1);
FailureLocalRun = zeros(n_failure,1);

GlobalSeedInsideN3 = false(n_failure,1);
CoverageGeometryConsistency = true(n_failure,1);

G0ToGlobalSeedDistance = zeros(n_failure,1);
GlobalSeedRank = zeros(n_failure,1);
GlobalSeedScoreRatio = zeros(n_failure,1);
GlobalOffgrid = zeros(n_failure,1);

for jj = 1:n_failure
    sid = failure_idx(jj);
    A = Audit(sid);

    p0 = StatePbeta(sid);
    col0 = StateRangeColumn(sid);
    N = A.N;

    %% recurrence
    support = false(n_lines,1);

    for il = 1:n_lines
        pk = line_peak_orders{il};

        if isempty(pk)
            continue;
        end

        support(il) = any(abs(pk-p0) <= ...
            cfg.component_match_tolerance_order+1e-12);
    end

    local = support & ...
        (abs(target_global_all(:)-col0) <= cfg.local_range_halfwidth_columns);

    FailureLocalSupport(jj) = sum(local);
    FailureLocalRun(jj) = longest_consecutive_integer_run( ...
        target_global_all(local));

    FailureRecurrent(jj) = ...
        FailureLocalSupport(jj) >= cfg.min_local_support_lines && ...
        FailureLocalRun(jj) >= cfg.min_consecutive_range_run;

    %% search geometry
    gseed = nearest_integer_bin(A.global_nu_bins,N);

    GlobalOffgrid(jj) = circular_bin_distance(A.global_nu_bins,gseed,N);
    G0ToGlobalSeedDistance(jj) = circular_bin_distance( ...
        A.coarse_top1_bin,gseed,N);

    bins = A.coarse_bins(:);
    Jc = A.coarse_objective(:);
    ig = find(bins==gseed,1);

    if isempty(ig)
        error('EXP02_FAIR_R1D:GlobalSeedNotOnGrid', ...
            'Global nearest integer seed not on coarse grid.');
    end

    [~,ord] = sort(Jc,'descend');
    GlobalSeedRank(jj) = find(ord==ig,1);
    GlobalSeedScoreRatio(jj) = Jc(ig)/max(Jc);

    n3_seeds = wrap_integer_bins(A.N3_candidate_seeds,N);
    GlobalSeedInsideN3(jj) = any(n3_seeds==gseed);

    CoverageGeometryConsistency(jj) = ...
        (GlobalSeedInsideN3(jj) == A.n3_candidate_coverage);
end

n_recurrent_failure = sum(FailureRecurrent);
n_remote_miss = sum((Taxonomy(failure_idx)=="N3_COVERAGE_MISS") & ~GlobalSeedInsideN3);
n_geometry_inconsistent = sum(~CoverageGeometryConsistency);

%% 10. Stop decision
if n_geometry_inconsistent > 0
    stop_decision = "R1D_GEOMETRY_INCONSISTENCY__AUDIT_IMPLEMENTATION";
elseif n_rescue > 0
    stop_decision = "R1D_LOCAL_N3_RESCUE_OBSERVED__INDEPENDENT_REPLICATION_POSITIVE";
elseif n_failure > 0 && n_recurrent_failure >= ceil(0.5*n_failure)
    stop_decision = "R1D_RECURRENT_FAILURES_WITHOUT_LOCAL_RESCUE__COMPARE_B_AND_C";
elseif n_failure > 0
    stop_decision = "R1D_FAILURES_OBSERVED_BUT_RECURRENCE_WEAK__CAUTIOUS_COMPARISON";
else
    stop_decision = "R1D_ALL_VALID_STATES_SAFE__CANDIDATE_C_NO_NATURAL_FAILURE";
end

%% 11. Figure 1: interface/crop
I = log1p(abs(S));

fig1 = figure('Color','w','Name','Candidate C interface/crop');
imagesc(I);
axis image;
colormap gray;
hold on;

rectangle('Position',[c1 r1 c2-c1+1 r2-r1+1], ...
    'EdgeColor',[1 0 0],'LineWidth',1.2);

for k = 1:numel(target_global_all)
    xline(target_global_all(k),'LineWidth',0.35);
end

hold off;
xlabel('Range column');
ylabel('Azimuth row');
title(sprintf('Candidate C | crop + Wang ship lines (%d)',n_lines));

exportgraphics(fig1, ...
    fullfile(cfg.results_dir,'01_candidate_c_interface_crop.png'), ...
    'Resolution',cfg.figure_resolution);

%% 12. Figure 2: accepted component states
fig2 = figure('Color','w','Name','Candidate C component states');

scatter(StateRangeColumn,StatePbeta, ...
    35+350*normalize01(StateExcessAboveMaxStat95), ...
    StateFracEnergy,'filled');

xlabel('Range column');
ylabel('Accepted nondegenerate FrAc order p_\beta');
title(sprintf('Candidate C frozen component gate | %d states on %d/%d lines', ...
    n_states,n_lines_with_state,n_lines));
grid on;
colorbar;

exportgraphics(fig2, ...
    fullfile(cfg.results_dir,'02_candidate_c_component_states.png'), ...
    'Resolution',cfg.figure_resolution);

%% 13. Figure 3: branch occurrence
fig3 = figure('Color','w','Name','Candidate C branch occurrence');

tax_order = [ ...
    "SAFE", ...
    "G0_FAIL_N3_RESCUE", ...
    "N3_COVERAGE_MISS", ...
    "PERSISTENT_WITHIN_COVERAGE"];

tax_y = zeros(n_states,1);

for k = 1:n_states
    tax_y(k) = find(tax_order==Taxonomy(k),1);
end

scatter(StateRangeColumn,tax_y,45,StatePbeta,'filled');
yticks(1:4);
yticklabels(tax_order);
ylim([0.5 4.5]);
xlabel('Range column');
ylabel('Branch-state taxonomy');
title(sprintf('Candidate C | S=%d R=%d M=%d P=%d', ...
    n_safe,n_rescue,n_miss,n_persist));
grid on;
cb = colorbar;
ylabel(cb,'p_\beta');

exportgraphics(fig3, ...
    fullfile(cfg.results_dir,'03_candidate_c_branch_occurrence.png'), ...
    'Resolution',cfg.figure_resolution);

%% 14. Figure 4: failure geometry
fig4 = figure('Color','w','Name','Candidate C failure geometry');
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');

nexttile;

if n_failure > 0
    scatter(G0ToGlobalSeedDistance,GlobalSeedRank, ...
        55+12*FailureLocalSupport,StatePbeta(failure_idx),'filled');
    xlabel('|k_0-k_{global-seed}| (bins)');
    ylabel('Global seed coarse rank');
    title(sprintf('Failure geometry | recurrent=%d/%d', ...
        n_recurrent_failure,n_failure));
    grid on;
    colorbar;
else
    axis off;
    text(0.5,0.5,'No non-SAFE states','HorizontalAlignment','center');
end

nexttile;

if n_failure > 0
    scatter(GlobalOffgrid,GlobalSeedScoreRatio, ...
        55+12*FailureLocalSupport,StatePbeta(failure_idx),'filled');
    xlabel('|nu_{global}-nearest integer| (bins)');
    ylabel('J(global seed)/J(coarse Top-1)');
    title(sprintf('Remote misses=%d | geometry inconsistencies=%d', ...
        n_remote_miss,n_geometry_inconsistent));
    grid on;
    colorbar;
else
    axis off;
    text(0.5,0.5,'No failure geometry to audit', ...
        'HorizontalAlignment','center');
end

exportgraphics(fig4, ...
    fullfile(cfg.results_dir,'04_candidate_c_failure_geometry.png'), ...
    'Resolution',cfg.figure_resolution);

%% 15. Figure 5: selected failure landscapes
fig5 = figure('Color','w','Name','Candidate C selected failure landscapes');

if n_failure > 0
    [~,ord_show] = sort(G0ErrorBins(failure_idx),'descend');
    show_local = ord_show(1:min(cfg.max_failure_landscapes,numel(ord_show)));
    show_state = failure_idx(show_local);

    tiledlayout(numel(show_state),1,'Padding','compact','TileSpacing','compact');

    for ii = 1:numel(show_state)
        sid = show_state(ii);
        A = Audit(sid);

        ref = A.global_nu_bins;
        g0p = nearest_periodic_rep(A.g0_nu_wrapped,ref,A.N);
        n3p = nearest_periodic_rep(A.n3_nu_wrapped,ref,A.N);

        qmin = min([ref,g0p,n3p])-2;
        qmax = max([ref,g0p,n3p])+2;
        q = linspace(qmin,qmax,4001);

        J = zeros(size(q));
        for iq = 1:numel(q)
            J(iq) = branch_tone_objective(A.dechirped_signal,q(iq));
        end
        J = J/max(J);

        nexttile;
        plot(q,J,'LineWidth',1.0);
        hold on;
        xline(ref,':','global');
        xline(g0p,'--','G0');
        xline(n3p,'-.','N3');
        hold off;

        xlabel('\nu (DFT bins; unwrapped around global)');
        ylabel('Normalized J');
        title(sprintf('state=%d col=%d p=%.2f | %s | err=%.2f', ...
            sid,StateRangeColumn(sid),StatePbeta(sid), ...
            Taxonomy(sid),G0ErrorBins(sid)));
        grid on;
    end
else
    axis off;
    text(0.5,0.5,'No failure landscapes: all states SAFE', ...
        'HorizontalAlignment','center');
end

exportgraphics(fig5, ...
    fullfile(cfg.results_dir,'05_candidate_c_selected_failure_landscapes.png'), ...
    'Resolution',cfg.figure_resolution);

%% 16. Save workspace
save(fullfile(cfg.results_dir,'EXP02_FAIR_R1D_workspace.mat'), ...
    'cfg','meta','mat_info','orient', ...
    'r1','r2','c1','c2','target_global_all','p_grid', ...
    'line_threshold','line_n_components','line_peak_orders', ...
    'line_peak_values','line_peak_excess', ...
    'StateLineIndex','StateRangeColumn','StatePbeta', ...
    'StateFracEnergy','StateExcessAboveMaxStat95', ...
    'Audit','Taxonomy', ...
    'n_lines','n_lines_with_state','n_states', ...
    'n_safe','n_rescue','n_miss','n_persist','n_fail', ...
    'failure_idx','FailureRecurrent','FailureLocalSupport','FailureLocalRun', ...
    'GlobalSeedInsideN3','CoverageGeometryConsistency', ...
    'G0ToGlobalSeedDistance','GlobalSeedRank', ...
    'GlobalSeedScoreRatio','GlobalOffgrid', ...
    'n_recurrent_failure','n_remote_miss', ...
    'n_geometry_inconsistent','stop_decision');

%% 17. Feedback bundle
txt_path = fullfile(cfg.results_dir,'EXP02_FAIR_R1D_FEEDBACK.txt');
fid = fopen(txt_path,'w');

if fid < 0
    error('EXP02_FAIR_R1D:FeedbackOpenFailed', ...
        'Cannot write feedback bundle.');
end

cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP02-FAIR-R1D CANDIDATE-C INDEPENDENT REPLICATION\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'Proposed=NOT_RUN\n');
fprintf(fid,'Branch_parameters_retuned=0\n');
fprintf(fid,'Inverse_focus=NOT_RUN\n\n');

fprintf(fid,'[INTERFACE]\n');
fprintf(fid,'stem=%s\n',cfg.stem);
fprintf(fid,'mat_size=%dx%d\n',size(S,1),size(S,2));
fprintf(fid,'is_complex=%d\n',mat_info.is_complex);
fprintf(fid,'png_raw_corr=%.9f\n',orient.raw_corr);
fprintf(fid,'best_orientation=%s\n',orient.best_name);
fprintf(fid,'best_orientation_corr=%.9f\n',orient.best_corr);
fprintf(fid,'sub_category=%s\n\n',meta.sub_category);

fprintf(fid,'[FROZEN CROP / SHIP POOL]\n');
fprintf(fid,'crop_rows=%d:%d\n',r1,r2);
fprintf(fid,'crop_columns=%d:%d\n',c1,c2);
fprintf(fid,'Wang_ship_lines=%d\n',n_lines);
fprintf(fid,'ship_lines_with_valid_components=%d/%d\n', ...
    n_lines_with_state,n_lines);
fprintf(fid,'valid_component_states=%d\n\n',n_states);

fprintf(fid,'[BRANCH OCCURRENCE]\n');
fprintf(fid,'SAFE=%d/%d\n',n_safe,n_states);
fprintf(fid,'G0_FAIL_N3_RESCUE=%d/%d\n',n_rescue,n_states);
fprintf(fid,'N3_COVERAGE_MISS=%d/%d\n',n_miss,n_states);
fprintf(fid,'PERSISTENT_WITHIN_COVERAGE=%d/%d\n',n_persist,n_states);
fprintf(fid,'G0_fail_total=%d/%d\n\n',n_fail,n_states);

fprintf(fid,'[FAILURE GEOMETRY / RECURRENCE]\n');
fprintf(fid,'recurrent_credible_failures=%d/%d\n', ...
    n_recurrent_failure,n_failure);
fprintf(fid,'remote_N3_coverage_misses=%d/%d\n', ...
    n_remote_miss,n_failure);
fprintf(fid,'coverage_geometry_inconsistencies=%d/%d\n', ...
    n_geometry_inconsistent,n_failure);

if n_failure > 0
    fprintf(fid,'median_G0_to_global_seed_distance=%.9g\n', ...
        median(G0ToGlobalSeedDistance));
    fprintf(fid,'median_global_seed_rank=%.9g\n',median(GlobalSeedRank));
    fprintf(fid,'median_global_seed_score_ratio=%.9g\n', ...
        median(GlobalSeedScoreRatio));
    fprintf(fid,'median_global_offgrid=%.9g\n',median(GlobalOffgrid));
end

fprintf(fid,'\n[FAILURE DETAILS]\n');

if n_failure == 0
    fprintf(fid,'NONE\n');
else
    fprintf(fid,['state\tline\tcol\tp_beta\ttaxonomy\tG0_err\tN3_err\t' ...
        'local_support\tlocal_run\trecurrent\tglobal_seed_dist\t' ...
        'seed_rank\tseed_score_ratio\tseed_in_N3\tgeometry_consistent\n']);

    for jj = 1:n_failure
        sid = failure_idx(jj);
        A = Audit(sid);

        fprintf(fid,['%d\t%d\t%d\t%.6f\t%s\t%.9g\t%.9g\t%d\t%d\t%d\t' ...
            '%.9g\t%d\t%.9g\t%d\t%d\n'], ...
            sid,StateLineIndex(sid),StateRangeColumn(sid),StatePbeta(sid), ...
            Taxonomy(sid),A.g0_error_bins,A.n3_error_bins, ...
            FailureLocalSupport(jj),FailureLocalRun(jj),FailureRecurrent(jj), ...
            G0ToGlobalSeedDistance(jj),GlobalSeedRank(jj), ...
            GlobalSeedScoreRatio(jj),GlobalSeedInsideN3(jj), ...
            CoverageGeometryConsistency(jj));
    end
end

fprintf(fid,'\n[STOP DECISION]\n');
fprintf(fid,'stop_decision=%s\n\n',stop_decision);

fprintf(fid,'[INTERPRETATION BOUNDARY]\n');
fprintf(fid,['Candidate C is an independent replication target using the same ' ...
    'pipeline and thresholds frozen on Candidate B. No Candidate-C result ' ...
    'is allowed to retune the branch or component-screen parameters.\n']);
fprintf(fid,['A SAFE state only means G0 reaches the same continuous global ' ...
    'branch under the accepted component dechirp. It does not imply the ' ...
    'SAR image is focused or that branch error dominates image defocus.\n']);
fprintf(fid,['If Candidate C reproduces recurrent remote-basin failures, compare ' ...
    'their geometry with Candidate B before any algorithm redesign. If a ' ...
    'natural G0-fail/N3-rescue event appears, record it without changing ' ...
    'the frozen Neighbor-3 definition.\n']);

fprintf(fid,'\n[UPLOAD REQUEST]\n');
fprintf(fid,'1) EXP02_FAIR_R1D_FEEDBACK.txt\n');
fprintf(fid,'2) 01_candidate_c_interface_crop.png\n');
fprintf(fid,'3) 02_candidate_c_component_states.png\n');
fprintf(fid,'4) 03_candidate_c_branch_occurrence.png\n');
fprintf(fid,'5) 04_candidate_c_failure_geometry.png\n');
fprintf(fid,'6) 05_candidate_c_selected_failure_landscapes.png\n');

fprintf('\n============================================================\n');
fprintf('Candidate C independent replication complete.\n');
fprintf('Valid states=%d | SAFE=%d RESCUE=%d MISS=%d PERSIST=%d\n', ...
    n_states,n_safe,n_rescue,n_miss,n_persist);
fprintf('Recurrent failures=%d/%d\n',n_recurrent_failure,n_failure);
fprintf('Stop decision: %s\n',stop_decision);
fprintf('Feedback: %s\n',txt_path);
fprintf('============================================================\n');

%% ========================================================================
function a = pbeta_to_sampled_a(p_beta,N,cfg)
scale = cfg.tnorm_full_span/(N-1);
a = tan(pi*p_beta/2)*scale^2;
end

%% ========================================================================
function run_interface_self_test(cfg)
N = 310;
m = 0:N-1;
p = 0.78;
nu = 4.37;

a = pbeta_to_sampled_a(p,N,cfg);
x = exp(1j*pi*a*m.^2 + 1j*2*pi*nu*m/N);

A = branch_real_g0_neighbor3_audit(x,a,cfg.stage);

if circular_bin_distance(A.global_nu_bins,nu,N)>1e-6 || ...
        circular_bin_distance(A.g0_nu_wrapped,nu,N)> ...
            cfg.stage.branch_match_tolerance_bins || ...
        circular_bin_distance(A.n3_nu_wrapped,nu,N)> ...
            cfg.stage.branch_match_tolerance_bins
    error('EXP02_FAIR_R1D:InterfaceSelfTestFailed', ...
        'Candidate-C branch interface self-test failed.');
end

fprintf('Branch interface self-test PASS.\n\n');
end

%% ========================================================================
function keep = nms_peak_indices(candidate_idx,y,p_grid,tol)
if isempty(candidate_idx)
    keep = candidate_idx;
    return;
end

[~,ord] = sort(y(candidate_idx),'descend');
candidate_idx = candidate_idx(ord);

keep = [];

for i = 1:numel(candidate_idx)
    ii = candidate_idx(i);

    if isempty(keep) || all(abs(p_grid(ii)-p_grid(keep)) > tol+1e-12)
        keep(end+1) = ii; %#ok<AGROW>
    end
end

[~,ord2] = sort(p_grid(keep));
keep = keep(ord2);
end

%% ========================================================================
function v = vector_percentile(x,p)
x = sort(x(:));
n = numel(x);

if n==1
    v = x(1);
    return;
end

pos = 1+(n-1)*p/100;
lo = floor(pos);
hi = ceil(pos);

if lo==hi
    v = x(lo);
else
    w = pos-lo;
    v = (1-w)*x(lo)+w*x(hi);
end
end

%% ========================================================================
function y = normalize01(x)
x = x(:);
xmin = min(x);
xmax = max(x);

if xmax<=xmin
    y = ones(size(x))*0.5;
else
    y = (x-xmin)/(xmax-xmin);
end
end

%% ========================================================================
function g = nearest_integer_bin(nu,N)
g = round(nu);
g = mod(g+N/2,N)-N/2;
g = round(g);
end

%% ========================================================================
function b = wrap_integer_bins(b,N)
b = round(b(:).');
b = mod(b+N/2,N)-N/2;
b = round(b);
end

%% ========================================================================
function d = circular_bin_distance(a,b,N)
d = abs(mod((a-b)+N/2,N)-N/2);
end

%% ========================================================================
function q = nearest_periodic_rep(q,ref,N)
delta = mod((q-ref)+N/2,N)-N/2;
q = ref+delta;
end

%% ========================================================================
function r = longest_consecutive_integer_run(cols)
cols = unique(sort(cols(:).'));

if isempty(cols)
    r = 0;
    return;
end

r = 1;
cur = 1;

for i = 2:numel(cols)
    if cols(i)-cols(i-1)==1
        cur = cur+1;
        r = max(r,cur);
    else
        cur = 1;
    end
end
end
