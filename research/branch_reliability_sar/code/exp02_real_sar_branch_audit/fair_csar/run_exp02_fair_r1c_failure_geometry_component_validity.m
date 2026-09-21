%% run_exp02_fair_r1c_failure_geometry_component_validity.m
% EXP02-FAIR-R1C
% Failure Geometry & Component Validity Audit
%
% R1B observed:
%   SAFE=203
%   N3_COVERAGE_MISS=19
%   G0_FAIL_N3_RESCUE=0
%
% R1C does NOT retune N3. It asks:
%
%   A. Are those failure states part of recurrent real component families?
%   B. Where is the evaluation-only global branch's nearest integer seed?
%   C. What was that seed's coarse DFT rank and score relative to Top-1?
%   D. Is the seed even geometrically contained in frozen {k0-1,k0,k0+1}?
%
% Inputs are read only from the saved R1B workspace. No surrogate screening
% is repeated and no second target is introduced.
%
% Upload after run:
%   EXP02_FAIR_R1C_FEEDBACK.txt
%   01_failure_recurrence_overlay.png
%   02_failure_search_geometry.png
%   03_failure_recurrence_summary.png
%   04_selected_failure_landscapes.png

clear; clc; close all;

%% 0. Resolve project paths
this_file = mfilename('fullpath');
fair_code_dir = fileparts(this_file);
exp02_code_dir = fileparts(fair_code_dir);
code_dir = fileparts(exp02_code_dir);
research_dir = fileparts(code_dir);

addpath(fair_code_dir);
addpath(genpath(fullfile(research_dir,'functions')));

cfg = config_exp02_fair_r1c(research_dir);

if ~exist(cfg.results_dir,'dir')
    mkdir(cfg.results_dir);
end

if exist(cfg.r1b_workspace,'file') ~= 2
    error('EXP02_FAIR_R1C:MissingR1BWorkspace', ...
        'R1B workspace not found: %s',cfg.r1b_workspace);
end

%% 1. Load exact R1B state
W = load(cfg.r1b_workspace, ...
    'cfg','frozen_cols','p_grid', ...
    'line_peak_orders','line_peak_values','line_peak_excess', ...
    'StateLineIndex','StateRangeColumn','StatePbeta', ...
    'StateFracEnergy','StateExcessAboveMaxStat95', ...
    'Audit','T','n_states','n_safe','n_rescue','n_miss','n_persist');

required = { ...
    'frozen_cols','line_peak_orders','StateLineIndex','StateRangeColumn', ...
    'StatePbeta','Audit','T'};

for i = 1:numel(required)
    if ~isfield(W,required{i})
        error('EXP02_FAIR_R1C:WorkspaceSchema', ...
            'R1B workspace missing required field: %s',required{i});
    end
end

n_states = numel(W.StatePbeta);

if numel(W.Audit) ~= n_states
    error('EXP02_FAIR_R1C:AuditLengthMismatch', ...
        'Audit struct count and state count disagree.');
end

Taxonomy = string(W.T.Taxonomy);
failure_idx = find(Taxonomy ~= "SAFE");
n_fail = numel(failure_idx);

if n_fail < 1
    error('EXP02_FAIR_R1C:NoFailures', ...
        'R1C requires at least one non-SAFE R1B state.');
end

fprintf('============================================================\n');
fprintf('EXP02-FAIR-R1C FAILURE GEOMETRY & COMPONENT VALIDITY\n');
fprintf('R1B states           : %d\n',n_states);
fprintf('R1B non-SAFE states  : %d\n',n_fail);
fprintf('component tol        : %.3f order\n', ...
    cfg.component_match_tolerance_order);
fprintf('local range halfwidth: +/- %d columns\n', ...
    cfg.local_range_halfwidth_columns);
fprintf('N3 retuning          : NOT ALLOWED / NOT RUN\n');
fprintf('============================================================\n\n');

%% 2. Preallocate failure diagnostics
FailureStateID = failure_idx(:);
FailureLineIndex = W.StateLineIndex(failure_idx);
FailureRangeColumn = W.StateRangeColumn(failure_idx);
FailurePbeta = W.StatePbeta(failure_idx);
FailureTaxonomy = Taxonomy(failure_idx);

G0ErrorBins = zeros(n_fail,1);
N3ErrorBins = zeros(n_fail,1);
CoarseMargin = zeros(n_fail,1);

GlobalNu = zeros(n_fail,1);
G0Nu = zeros(n_fail,1);
N3Nu = zeros(n_fail,1);

GlobalNearestIntegerSeed = zeros(n_fail,1);
GlobalSeedOffgridAbs = zeros(n_fail,1);
GlobalSeedCoarseRank = zeros(n_fail,1);
GlobalSeedCoarseScoreRatio = zeros(n_fail,1);
GlobalSeedObjectiveLossVsContinuous = zeros(n_fail,1);

G0ToGlobalSeedDistanceBins = zeros(n_fail,1);
GlobalSeedInsideFrozenN3IntegerSet = false(n_fail,1);
ActualN3CandidateCoverage = false(n_fail,1);
CoverageGeometryConsistency = false(n_fail,1);

GlobalComponentSupportAllLines = zeros(n_fail,1);
LocalComponentSupport = zeros(n_fail,1);
LocalConsecutiveRangeRun = zeros(n_fail,1);
LocalMatchedOrderIQR = nan(n_fail,1);
RecurrentComponentCredible = false(n_fail,1);

%% 3. Diagnose every R1B failure state
for jj = 1:n_fail
    sid = failure_idx(jj);
    A = W.Audit(sid);

    N = A.N;
    p0 = W.StatePbeta(sid);
    col0 = W.StateRangeColumn(sid);

    G0ErrorBins(jj) = A.g0_error_bins;
    N3ErrorBins(jj) = A.n3_error_bins;
    CoarseMargin(jj) = A.coarse_top1_top2_margin;

    GlobalNu(jj) = A.global_nu_bins;
    G0Nu(jj) = A.g0_nu_wrapped;
    N3Nu(jj) = A.n3_nu_wrapped;

    %% 3a. Global-basin nearest integer seed and coarse geometry
    gseed = nearest_integer_bin(A.global_nu_bins,N);
    GlobalNearestIntegerSeed(jj) = gseed;

    GlobalSeedOffgridAbs(jj) = circular_bin_distance( ...
        A.global_nu_bins,gseed,N);

    bins = A.coarse_bins(:);
    Jc = A.coarse_objective(:);

    ig = find(bins == gseed,1);

    if isempty(ig)
        error('EXP02_FAIR_R1C:GlobalSeedNotOnCoarseGrid', ...
            'Nearest global integer seed %d is not in coarse grid.',gseed);
    end

    [~,ord] = sort(Jc,'descend');
    rank_pos = find(ord==ig,1);

    GlobalSeedCoarseRank(jj) = rank_pos;
    GlobalSeedCoarseScoreRatio(jj) = Jc(ig)/max(Jc);

    Jseed_cont = branch_tone_objective(A.dechirped_signal,gseed);
    GlobalSeedObjectiveLossVsContinuous(jj) = ...
        (A.global_objective-Jseed_cont)/max(A.global_objective,eps);

    G0ToGlobalSeedDistanceBins(jj) = circular_bin_distance( ...
        A.coarse_top1_bin,gseed,N);

    n3_integer_seeds = wrap_integer_bins(A.N3_candidate_seeds,N);
    GlobalSeedInsideFrozenN3IntegerSet(jj) = any(n3_integer_seeds==gseed);

    ActualN3CandidateCoverage(jj) = A.n3_candidate_coverage;

    % If the nearest integer seed is inside N3, the true global continuous
    % maximum is at most 0.5 bin from that seed and lies inside the frozen
    % +/-0.75-bin local search support. A disagreement deserves engineering
    % review before scientific interpretation.
    CoverageGeometryConsistency(jj) = ...
        (GlobalSeedInsideFrozenN3IntegerSet(jj) == ...
         ActualN3CandidateCoverage(jj));

    %% 3b. Cross-line recurrence of the same accepted component family
    support = false(numel(W.frozen_cols),1);
    nearest_order = nan(numel(W.frozen_cols),1);

    for il = 1:numel(W.frozen_cols)
        pk = W.line_peak_orders{il};

        if isempty(pk)
            continue;
        end

        [dmin,ii] = min(abs(pk-p0));

        if dmin <= cfg.component_match_tolerance_order + 1e-12
            support(il) = true;
            nearest_order(il) = pk(ii);
        end
    end

    GlobalComponentSupportAllLines(jj) = sum(support);

    local_mask = ...
        abs(W.frozen_cols(:)-col0) <= cfg.local_range_halfwidth_columns;

    local_support_mask = support & local_mask;
    LocalComponentSupport(jj) = sum(local_support_mask);

    support_cols = W.frozen_cols(local_support_mask);
    LocalConsecutiveRangeRun(jj) = longest_consecutive_integer_run( ...
        support_cols);

    local_orders = nearest_order(local_support_mask);
    LocalMatchedOrderIQR(jj) = local_iqr(local_orders);

    RecurrentComponentCredible(jj) = ...
        (LocalComponentSupport(jj) >= cfg.min_local_support_lines) && ...
        (LocalConsecutiveRangeRun(jj) >= cfg.min_consecutive_range_run);

    fprintf(['failure %2d/%2d | state=%d col=%d p=%.2f | ' ...
        'err=%.3f | global seed=%d rank=%d dist=%g | ' ...
        'local support=%d run=%d recurrent=%d\n'], ...
        jj,n_fail,sid,col0,p0,G0ErrorBins(jj), ...
        gseed,GlobalSeedCoarseRank(jj),G0ToGlobalSeedDistanceBins(jj), ...
        LocalComponentSupport(jj),LocalConsecutiveRangeRun(jj), ...
        RecurrentComponentCredible(jj));
end

%% 4. Integrity / aggregate diagnostics
n_recurrent = sum(RecurrentComponentCredible);
n_isolated_or_weak = n_fail-n_recurrent;

n_global_seed_inside_n3 = sum(GlobalSeedInsideFrozenN3IntegerSet);
n_geometry_inconsistent = sum(~CoverageGeometryConsistency);

median_global_seed_rank = median(GlobalSeedCoarseRank);
median_seed_distance = median(G0ToGlobalSeedDistanceBins);
median_seed_score_ratio = median(GlobalSeedCoarseScoreRatio);
median_offgrid = median(GlobalSeedOffgridAbs);

if n_geometry_inconsistent > 0
    stop_decision = "R1C_GEOMETRY_INCONSISTENCY__ENGINEERING_AUDIT_BEFORE_SCIENCE";
elseif n_recurrent >= ceil(0.5*n_fail) && n_global_seed_inside_n3 == 0
    stop_decision = ...
        "R1C_MAJORITY_CREDIBLE_REMOTE_BASIN_FAILURES__MOVE_SECOND_CANDIDATE_NO_RETUNE";
elseif n_recurrent < ceil(0.5*n_fail)
    stop_decision = ...
        "R1C_COMPONENT_RECURRENCE_WEAK__TREAT_R1B_FAILURE_PREVALENCE_CAUTION";
else
    stop_decision = ...
        "R1C_MIXED_FAILURE_GEOMETRY__REVIEW_BEFORE_SECOND_CANDIDATE";
end

%% 5. Result table
Tfail = table( ...
    FailureStateID,FailureLineIndex,FailureRangeColumn,FailurePbeta, ...
    FailureTaxonomy,G0ErrorBins,N3ErrorBins,CoarseMargin, ...
    GlobalNu,G0Nu,N3Nu, ...
    GlobalNearestIntegerSeed,GlobalSeedOffgridAbs, ...
    GlobalSeedCoarseRank,GlobalSeedCoarseScoreRatio, ...
    GlobalSeedObjectiveLossVsContinuous, ...
    G0ToGlobalSeedDistanceBins, ...
    GlobalSeedInsideFrozenN3IntegerSet, ...
    ActualN3CandidateCoverage,CoverageGeometryConsistency, ...
    GlobalComponentSupportAllLines,LocalComponentSupport, ...
    LocalConsecutiveRangeRun,LocalMatchedOrderIQR, ...
    RecurrentComponentCredible);

writetable(Tfail, ...
    fullfile(cfg.results_dir,'EXP02_FAIR_R1C_failure_metrics.csv'));

%% 6. Figure 1: failure states over all accepted component states
fig1 = figure('Color','w','Name','R1C failure recurrence overlay');

scatter(W.StateRangeColumn,W.StatePbeta,24,[0.72 0.72 0.72],'filled');
hold on;

idx_rec = find(RecurrentComponentCredible);
idx_weak = find(~RecurrentComponentCredible);

if ~isempty(idx_rec)
    scatter(FailureRangeColumn(idx_rec),FailurePbeta(idx_rec), ...
        95,'o','LineWidth',1.6, ...
        'MarkerEdgeColor',[0.85 0.15 0.10], ...
        'DisplayName','recurrent failure');
end

if ~isempty(idx_weak)
    scatter(FailureRangeColumn(idx_weak),FailurePbeta(idx_weak), ...
        85,'x','LineWidth',1.6, ...
        'MarkerEdgeColor',[0.15 0.20 0.80], ...
        'DisplayName','weak/isolated failure');
end

hold off;
xlabel('Range column');
ylabel('Accepted nondegenerate FrAc order p_\beta');
title(sprintf('R1B accepted states with R1C failure recurrence | recurrent=%d/%d', ...
    n_recurrent,n_fail));
legend('all accepted states','recurrent failure','weak/isolated failure', ...
    'Location','best');
grid on;

exportgraphics(fig1, ...
    fullfile(cfg.results_dir,'01_failure_recurrence_overlay.png'), ...
    'Resolution',cfg.figure_resolution);

%% 7. Figure 2: search geometry
fig2 = figure('Color','w','Name','R1C failure search geometry');
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');

nexttile;
sz = 45 + 15*LocalComponentSupport;
scatter(G0ToGlobalSeedDistanceBins,GlobalSeedCoarseRank, ...
    sz,FailurePbeta,'filled');
xlabel('|k_0 - k_{global-seed}| circular distance (bins)');
ylabel('Global-basin nearest integer seed coarse rank');
title('Remote-basin geometry');
grid on;
cb = colorbar;
ylabel(cb,'p_\beta');

nexttile;
scatter(GlobalSeedOffgridAbs,GlobalSeedCoarseScoreRatio, ...
    sz,FailurePbeta,'filled');
xlabel('|nu_{global} - nearest integer| (bins)');
ylabel('J(global integer seed) / J(coarse Top-1)');
title('Off-grid loss and coarse under-ranking');
grid on;
cb = colorbar;
ylabel(cb,'p_\beta');

exportgraphics(fig2, ...
    fullfile(cfg.results_dir,'02_failure_search_geometry.png'), ...
    'Resolution',cfg.figure_resolution);

%% 8. Figure 3: recurrence summary
fig3 = figure('Color','w','Name','R1C failure recurrence summary');
tiledlayout(2,1,'Padding','compact','TileSpacing','compact');

nexttile;
bar(1:n_fail,LocalComponentSupport);
hold on;
yline(cfg.min_local_support_lines,'--','local support gate');
hold off;
xlabel('Failure state index within R1C');
ylabel('Matched ship lines in +/-3 columns');
title(sprintf('Local component recurrence | credible=%d/%d', ...
    n_recurrent,n_fail));
grid on;

nexttile;
bar(1:n_fail,LocalConsecutiveRangeRun);
hold on;
yline(cfg.min_consecutive_range_run,'--','consecutive-run gate');
hold off;
xlabel('Failure state index within R1C');
ylabel('Longest consecutive range-column run');
title('Spatial continuity of matched component family');
grid on;

exportgraphics(fig3, ...
    fullfile(cfg.results_dir,'03_failure_recurrence_summary.png'), ...
    'Resolution',cfg.figure_resolution);

%% 9. Figure 4: selected failure landscapes with coarse samples
% Select diverse cases:
%   largest G0 error
%   smallest coarse margin
%   worst global-seed coarse rank
%   strongest local recurrence
candidate_show = [];

[~,ii] = max(G0ErrorBins);
candidate_show(end+1) = ii; %#ok<AGROW>

[~,ii] = min(CoarseMargin);
candidate_show(end+1) = ii; %#ok<AGROW>

[~,ii] = max(GlobalSeedCoarseRank);
candidate_show(end+1) = ii; %#ok<AGROW>

[~,ii] = max(LocalComponentSupport);
candidate_show(end+1) = ii; %#ok<AGROW>

candidate_show = unique(candidate_show,'stable');

if numel(candidate_show) < cfg.max_landscape_examples
    [~,ord] = sort(G0ErrorBins,'descend');
    for ii = ord(:).'
        if ~ismember(ii,candidate_show)
            candidate_show(end+1) = ii; %#ok<AGROW>
        end
        if numel(candidate_show) >= cfg.max_landscape_examples
            break;
        end
    end
end

candidate_show = candidate_show(1:min(cfg.max_landscape_examples,numel(candidate_show)));
n_show = numel(candidate_show);

fig4 = figure('Color','w','Name','R1C selected failure landscapes');
tiledlayout(n_show,1,'Padding','compact','TileSpacing','compact');

for iplt = 1:n_show
    jj = candidate_show(iplt);
    sid = failure_idx(jj);
    A = W.Audit(sid);

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

    % Coarse integer samples represented near the same unwrapped reference.
    coarse_q = zeros(size(A.coarse_bins));
    for ic = 1:numel(A.coarse_bins)
        coarse_q(ic) = nearest_periodic_rep(A.coarse_bins(ic),ref,A.N);
    end

    in_view = coarse_q >= qmin & coarse_q <= qmax;
    coarse_J = A.coarse_objective/max(A.coarse_objective);

    nexttile;
    plot(q,J,'LineWidth',1.0);
    hold on;
    stem(coarse_q(in_view),coarse_J(in_view), ...
        'Marker','none','LineStyle',':','LineWidth',0.6);
    xline(ref,':','global');
    xline(g0p,'--','G0');
    xline(nearest_periodic_rep( ...
        GlobalNearestIntegerSeed(jj),ref,A.N), ...
        '-.','global seed');
    hold off;

    xlabel('\nu (DFT bins; unwrapped around global)');
    ylabel('Normalized objective');
    title(sprintf(['state=%d col=%d p=%.2f | err=%.2f | seed rank=%d | ' ...
        'local support=%d run=%d'], ...
        sid,FailureRangeColumn(jj),FailurePbeta(jj), ...
        G0ErrorBins(jj),GlobalSeedCoarseRank(jj), ...
        LocalComponentSupport(jj),LocalConsecutiveRangeRun(jj)));
    grid on;
end

exportgraphics(fig4, ...
    fullfile(cfg.results_dir,'04_selected_failure_landscapes.png'), ...
    'Resolution',cfg.figure_resolution);

%% 10. Save workspace
save(fullfile(cfg.results_dir,'EXP02_FAIR_R1C_workspace.mat'), ...
    'cfg','W','failure_idx','Tfail', ...
    'n_fail','n_recurrent','n_isolated_or_weak', ...
    'n_global_seed_inside_n3','n_geometry_inconsistent', ...
    'median_global_seed_rank','median_seed_distance', ...
    'median_seed_score_ratio','median_offgrid','stop_decision');

%% 11. Feedback bundle
txt_path = fullfile(cfg.results_dir,'EXP02_FAIR_R1C_FEEDBACK.txt');
fid = fopen(txt_path,'w');

if fid < 0
    error('EXP02_FAIR_R1C:FeedbackOpenFailed', ...
        'Cannot write feedback bundle.');
end

cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP02-FAIR-R1C FAILURE GEOMETRY & COMPONENT VALIDITY AUDIT\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'Branch_parameters_retuned=0\n');
fprintf(fid,'New_surrogate_screening_run=0\n');
fprintf(fid,'Second_FAIR_ship_used=0\n');
fprintf(fid,'Image_refocusing_run=0\n\n');

fprintf(fid,'[FROZEN R1B INPUT]\n');
fprintf(fid,'total_R1B_states=%d\n',n_states);
fprintf(fid,'R1B_nonSAFE_states=%d\n',n_fail);
fprintf(fid,'component_match_tolerance_order=%.6f\n', ...
    cfg.component_match_tolerance_order);
fprintf(fid,'local_range_halfwidth_columns=%d\n', ...
    cfg.local_range_halfwidth_columns);
fprintf(fid,'min_local_support_lines=%d\n',cfg.min_local_support_lines);
fprintf(fid,'min_consecutive_range_run=%d\n\n', ...
    cfg.min_consecutive_range_run);

fprintf(fid,'[COMPONENT VALIDITY / RECURRENCE]\n');
fprintf(fid,'recurrent_credible_failures=%d/%d\n',n_recurrent,n_fail);
fprintf(fid,'weak_or_isolated_failures=%d/%d\n', ...
    n_isolated_or_weak,n_fail);
fprintf(fid,'median_local_support=%.9g\n',median(LocalComponentSupport));
fprintf(fid,'median_local_consecutive_run=%.9g\n', ...
    median(LocalConsecutiveRangeRun));
fprintf(fid,'median_global_component_support=%.9g\n\n', ...
    median(GlobalComponentSupportAllLines));

fprintf(fid,'[SEARCH GEOMETRY]\n');
fprintf(fid,'global_seed_inside_frozen_N3_integer_set=%d/%d\n', ...
    n_global_seed_inside_n3,n_fail);
fprintf(fid,'coverage_geometry_inconsistencies=%d/%d\n', ...
    n_geometry_inconsistent,n_fail);
fprintf(fid,'median_G0_to_global_integer_seed_distance_bins=%.9g\n', ...
    median_seed_distance);
fprintf(fid,'median_global_integer_seed_coarse_rank=%.9g\n', ...
    median_global_seed_rank);
fprintf(fid,'median_global_integer_seed_score_ratio=%.9g\n', ...
    median_seed_score_ratio);
fprintf(fid,'median_global_offgrid_distance_bins=%.9g\n\n', ...
    median_offgrid);

fprintf(fid,'[PER-FAILURE STATE]\n');
fprintf(fid,['R1B_state\tline\tcol\tp_beta\tG0_err\tmargin\tglobal_seed\t' ...
    'offgrid\tseed_rank\tseed_score_ratio\tG0_seed_distance\t' ...
    'seed_in_N3\tactual_N3_coverage\tgeometry_consistent\t' ...
    'global_support\tlocal_support\tlocal_run\tlocal_order_IQR\t' ...
    'recurrent\n']);

for jj = 1:n_fail
    fprintf(fid,['%d\t%d\t%d\t%.6f\t%.9g\t%.9g\t%d\t%.9g\t%d\t' ...
        '%.9g\t%.9g\t%d\t%d\t%d\t%d\t%d\t%d\t%.9g\t%d\n'], ...
        FailureStateID(jj),FailureLineIndex(jj),FailureRangeColumn(jj), ...
        FailurePbeta(jj),G0ErrorBins(jj),CoarseMargin(jj), ...
        GlobalNearestIntegerSeed(jj),GlobalSeedOffgridAbs(jj), ...
        GlobalSeedCoarseRank(jj),GlobalSeedCoarseScoreRatio(jj), ...
        G0ToGlobalSeedDistanceBins(jj), ...
        GlobalSeedInsideFrozenN3IntegerSet(jj), ...
        ActualN3CandidateCoverage(jj),CoverageGeometryConsistency(jj), ...
        GlobalComponentSupportAllLines(jj),LocalComponentSupport(jj), ...
        LocalConsecutiveRangeRun(jj),LocalMatchedOrderIQR(jj), ...
        RecurrentComponentCredible(jj));
end

fprintf(fid,'\n[STOP DECISION]\n');
fprintf(fid,'stop_decision=%s\n\n',stop_decision);

fprintf(fid,'[INTERPRETATION BOUNDARY]\n');
fprintf(fid,['A recurrent flag means the accepted FrAc component order reappears ' ...
    'on nearby frozen ship lines under the same 0.04-order matching rule. ' ...
    'It strengthens component validity but does not prove a unique physical ' ...
    'scatterer identity.\n']);
fprintf(fid,['The nearest-integer global seed and its coarse rank diagnose why ' ...
    'the local N3 seed set did or did not geometrically cover the continuous ' ...
    'global basin. These quantities are descriptive only and do not define ' ...
    'a new branch-recovery method.\n']);
fprintf(fid,['If failures are recurrent and their global integer seeds are far ' ...
    'outside the frozen N3 seed set, conclude that Candidate B contains ' ...
    'credible real remote-basin branch failures outside the local N3 ' ...
    'coverage regime. Do not enlarge N3 in this experiment.\n']);

fprintf(fid,'\n[UPLOAD REQUEST]\n');
fprintf(fid,'1) EXP02_FAIR_R1C_FEEDBACK.txt\n');
fprintf(fid,'2) 01_failure_recurrence_overlay.png\n');
fprintf(fid,'3) 02_failure_search_geometry.png\n');
fprintf(fid,'4) 03_failure_recurrence_summary.png\n');
fprintf(fid,'5) 04_selected_failure_landscapes.png\n');

fprintf('\n============================================================\n');
fprintf('R1C complete.\n');
fprintf('Credible recurrent failures: %d/%d\n',n_recurrent,n_fail);
fprintf('Global integer seed inside N3: %d/%d\n', ...
    n_global_seed_inside_n3,n_fail);
fprintf('Geometry inconsistencies: %d/%d\n', ...
    n_geometry_inconsistent,n_fail);
fprintf('Stop decision: %s\n',stop_decision);
fprintf('Feedback: %s\n',txt_path);
fprintf('============================================================\n');

%% ========================================================================
function g = nearest_integer_bin(nu,N)

g = round(nu);
g = mod(g+N/2,N)-N/2;

% For even N, canonical integer bins are [-N/2, ..., N/2-1].
if mod(N,2)==0 && g >= N/2
    g = g-N;
end

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
q = ref + delta;

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
    if cols(i)-cols(i-1) == 1
        cur = cur+1;
        r = max(r,cur);
    else
        cur = 1;
    end
end

end

%% ========================================================================
function q = local_iqr(x)

x = x(~isnan(x));
x = sort(x(:));

if isempty(x)
    q = NaN;
    return;
end

q = vector_percentile(x,75)-vector_percentile(x,25);

end

%% ========================================================================
function v = vector_percentile(x,p)

x = sort(x(:));
n = numel(x);

if n == 0
    v = NaN;
elseif n == 1
    v = x(1);
else
    pos = 1+(n-1)*p/100;
    lo = floor(pos);
    hi = ceil(pos);

    if lo == hi
        v = x(lo);
    else
        w = pos-lo;
        v = (1-w)*x(lo)+w*x(hi);
    end
end

end
