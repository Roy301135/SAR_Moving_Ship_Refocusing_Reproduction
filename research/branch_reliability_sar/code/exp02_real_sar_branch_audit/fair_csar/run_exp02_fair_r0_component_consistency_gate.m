%% run_exp02_fair_r0_component_consistency_gate.m
% EXP02-FAIR-R0-COMPONENT
% Final R0 Component-Consistency Gate for FAIR-CSAR Candidate B
%
% PURPOSE
% -------
% The previous corrected R0 + phase-sensitivity gate established:
%   1) Candidate B has target-specific fractional-domain structure.
%   2) p=1 is phase-blind and cannot by itself establish LFM structure.
%   3) Real target lines contain non-p=1 phase-sensitive structure beyond
%      amplitude-preserving phase-permutation surrogates.
%
% This FINAL R0 gate asks a stronger question:
%
%   Do the real target lines contain RECURRING, statistically guarded,
%   non-p=1 LOCAL FrAc peaks that behave like repeatable LFM components
%   across neighboring audited range columns?
%
% The experiment deliberately controls the within-line "look elsewhere"
% problem. A local peak is accepted only if it exceeds the 95th percentile
% of the MAXIMUM nondegenerate FrAc energy obtained from that line's own
% amplitude-preserving phase-permutation surrogates.
%
% Thus:
%   pointwise surrogate exceedance  -> previous phase gate
%   max-statistic significant peak  -> this component-consistency gate
%
% FROZEN BOUNDARIES
% -----------------
%   - Same FAIR-CSAR Candidate B
%   - Same corrected-R0 crop
%   - Same 12 frozen target lines
%   - Same p-grid
%   - Same phase-permutation null
%   - Same RNG seed and 32 surrogates/line
%   - Same |p-1| <= 0.06 phase-blind guard
%   - NO G0 / Neighbor-3 / Proposed
%   - NO second FAIR ship
%   - NO inverse focus / re-focus
%
% PRE-REGISTERED COMPONENT MATCHING
% ---------------------------------
%   cluster_tolerance = 0.04 order units = two frozen p-grid steps.
%
% Engineering gate for a recurrent component candidate:
%   support >= 50% of frozen target lines
%   AND
%   max consecutive audited-line run >= 4
%
% This is a reproducibility/continuity gate, not a statistical theorem and
% not a claim that the whole ship is exactly MC-LFM.
%
% OUTPUT REVIEW BUNDLE
% --------------------
% Upload only:
%   EXP02_FAIR_R0_COMPONENT_FEEDBACK.txt
%   01_fwer_significant_peak_map.png
%   02_recurrence_support.png
%   03_dominant_component_track.png
%
% Keep CSV/MAT locally.

clear; clc; close all;

%% 0. Resolve repository paths
this_file = mfilename('fullpath');
fair_code_dir = fileparts(this_file);
exp02_code_dir = fileparts(fair_code_dir);
code_dir = fileparts(exp02_code_dir);
research_dir = fileparts(code_dir);
research_parent = fileparts(research_dir);
repo_root = fileparts(research_parent);

addpath(genpath(fullfile(research_dir,'functions')));
addpath(genpath(fullfile(repo_root,'papers')));

cfg = config_exp02_fair_r0();

if exist('fair_csar_fractional_line_audit','file') ~= 2
    error('fair_csar_fractional_line_audit.m is not on the MATLAB path.');
end

%% 1. Frozen inputs / previous workspaces
data_root = fullfile(repo_root,'data','fair_csar','pilot_candidate_B');

mat_path = fullfile(data_root,'SLCMats',[cfg.stem '.mat']);

r0_dir = fullfile( ...
    research_dir,'results','exp02_real_sar_branch_audit', ...
    'fair_csar','r0_mclfm_compatibility');

phase_dir = fullfile( ...
    research_dir,'results','exp02_real_sar_branch_audit', ...
    'fair_csar','r0_phase_sensitivity_gate');

r0_workspace = fullfile(r0_dir,'EXP02_FAIR_R0_workspace.mat');
phase_workspace = fullfile(phase_dir,'EXP02_FAIR_R0_PHASE_workspace.mat');

result_dir = fullfile( ...
    research_dir,'results','exp02_real_sar_branch_audit', ...
    'fair_csar','r0_component_consistency_gate');

if ~exist(result_dir,'dir')
    mkdir(result_dir);
end

required_files = {mat_path,r0_workspace,phase_workspace};
for i = 1:numel(required_files)
    if exist(required_files{i},'file') ~= 2
        error('Required input/workspace missing: %s',required_files{i});
    end
end

%% 2. Load exact frozen state
R = load(r0_workspace, ...
    'cfg','r1','r2','c1','c2','target_global','p_grid');

P = load(phase_workspace, ...
    'cfg','rng_seed','n_surrogates','phase_guard_halfwidth', ...
    'surrogate_upper_percentile','target_global','p_grid','real_curve');

if ~strcmp(R.cfg.stem,cfg.stem) || ~strcmp(P.cfg.stem,cfg.stem)
    error('Candidate stem mismatch between config and saved workspaces.');
end

target_global = R.target_global(:).';
p_grid = R.p_grid(:).';

if ~isequal(target_global,P.target_global(:).')
    error('Frozen target-line selection differs between R0 and phase workspace.');
end

if max(abs(p_grid-P.p_grid(:).')) > 1e-12
    error('p-grid differs between R0 and phase workspace.');
end

real_curve_saved = P.real_curve;

n_target = numel(target_global);
Np = numel(p_grid);

if size(real_curve_saved,1) ~= n_target || size(real_curve_saved,2) ~= Np
    error('Saved phase-gate real_curve has incompatible dimensions.');
end

%% 3. Pre-registered constants
rng_seed = P.rng_seed;
n_surrogates = P.n_surrogates;
phase_guard_halfwidth = P.phase_guard_halfwidth;

p_blind = 1.0;
surrogate_max_percentile = 95;

cluster_tolerance = 0.04;
min_support_lines = ceil(0.50*n_target);
min_consecutive_run = 4;

% Distinct peak families on one line must be separated by more than the
% same component-matching tolerance.
within_line_nms_tolerance = cluster_tolerance;

guard_mask = abs(p_grid-p_blind) > (phase_guard_halfwidth + 1e-12);

if ~any(guard_mask)
    error('Nondegenerate order mask is empty.');
end

%% 4. Load real complex SLC
[S,mat_info] = fair_csar_load_complex_mat(mat_path);
S = double(S);

fprintf('============================================================\n');
fprintf('EXP02-FAIR-R0 COMPONENT-CONSISTENCY GATE\n');
fprintf('Candidate               : %s\n',cfg.stem);
fprintf('Frozen target lines     : %d\n',n_target);
fprintf('Surrogates/line         : %d\n',n_surrogates);
fprintf('Surrogate max percentile: %.1f\n',surrogate_max_percentile);
fprintf('Cluster tolerance       : %.3f order\n',cluster_tolerance);
fprintf('Gate support            : >= %d/%d lines\n',min_support_lines,n_target);
fprintf('Gate consecutive run    : >= %d audited lines\n',min_consecutive_run);
fprintf('G0/N3/Proposed          : NOT RUN\n');
fprintf('============================================================\n\n');

%% 5. Recreate exact phase-permutation null and linewise max-stat thresholds
rng(rng_seed,'twister');

real_curve = zeros(n_target,Np);
line_maxstat_q95 = zeros(n_target,1);

% Per-line accepted peaks after:
%   local maximum
%   nondegenerate guard
%   max-statistic q95 threshold
sig_peak_orders = cell(n_target,1);
sig_peak_values = cell(n_target,1);
sig_peak_excess = cell(n_target,1);

max_abs_realcurve_diff_vs_saved = 0;

for k = 1:n_target
    col = target_global(k);
    x = S(R.r1:R.r2,col);

    a_real = fair_csar_fractional_line_audit( ...
        x,p_grid,cfg.frac_exclude_zero_lags);

    real_curve(k,:) = a_real.frac_energy;

    max_abs_realcurve_diff_vs_saved = max( ...
        max_abs_realcurve_diff_vs_saved, ...
        max(abs(real_curve(k,:) - real_curve_saved(k,:))));

    amp = abs(x(:).');
    ph = angle(x(:).');

    surrogate_max_nondeg = zeros(n_surrogates,1);

    for is = 1:n_surrogates
        perm = randperm(numel(ph));
        xs = amp .* exp(1j*ph(perm));

        a_s = fair_csar_fractional_line_audit( ...
            xs,p_grid,cfg.frac_exclude_zero_lags);

        s = a_s.frac_energy;
        surrogate_max_nondeg(is) = max(s(guard_mask));
    end

    line_maxstat_q95(k) = vector_percentile( ...
        surrogate_max_nondeg,surrogate_max_percentile);

    % Real local maxima. Endpoints are deliberately excluded because a
    % component peak should be locally resolved inside the frozen search.
    is_local = false(1,Np);

    for ip = 2:(Np-1)
        is_local(ip) = ...
            (real_curve(k,ip) > real_curve(k,ip-1)) && ...
            (real_curve(k,ip) >= real_curve(k,ip+1));
    end

    candidate_idx = find( ...
        is_local & ...
        guard_mask & ...
        (real_curve(k,:) > line_maxstat_q95(k)));

    % Within-line nonmaximum suppression so a broad peak does not count as
    % several component families.
    keep_idx = nms_peak_indices( ...
        candidate_idx,real_curve(k,:),p_grid,within_line_nms_tolerance);

    sig_peak_orders{k} = p_grid(keep_idx);
    sig_peak_values{k} = real_curve(k,keep_idx);
    sig_peak_excess{k} = real_curve(k,keep_idx) - line_maxstat_q95(k);

    fprintf('line %2d/%2d | col=%d | maxstat95=%.5g | significant peaks=%d', ...
        k,n_target,col,line_maxstat_q95(k),numel(keep_idx));

    if ~isempty(keep_idx)
        fprintf(' | p=%s',mat2str(p_grid(keep_idx),3));
    end
    fprintf('\n');
end

%% 6. Cross-line recurrence support on the frozen p-grid
support_count = zeros(1,Np);
max_consecutive_run = zeros(1,Np);
support_strength = zeros(1,Np);

for ip = 1:Np
    if ~guard_mask(ip)
        continue;
    end

    center = p_grid(ip);

    hit = false(1,n_target);
    strength = zeros(1,n_target);

    for k = 1:n_target
        pk = sig_peak_orders{k};
        ek = sig_peak_excess{k};

        if isempty(pk)
            continue;
        end

        in_cluster = abs(pk-center) <= cluster_tolerance + 1e-12;

        if any(in_cluster)
            hit(k) = true;
            strength(k) = max(ek(in_cluster));
        end
    end

    support_count(ip) = sum(hit);
    max_consecutive_run(ip) = longest_true_run(hit);
    support_strength(ip) = sum(strength);
end

%% 7. Dominant recurrent cluster
valid_idx = find(guard_mask);

% Lexicographic choice:
%   1) maximum line support
%   2) maximum consecutive audited-line run
%   3) maximum summed excess above linewise max-stat q95
score = [ ...
    support_count(valid_idx).', ...
    max_consecutive_run(valid_idx).', ...
    support_strength(valid_idx).' ];

[~,ord] = sortrows(score,[-1 -2 -3]);
dominant_idx = valid_idx(ord(1));
dominant_center = p_grid(dominant_idx);

dominant_support = support_count(dominant_idx);
dominant_run = max_consecutive_run(dominant_idx);
dominant_strength = support_strength(dominant_idx);

dominant_gate_pass = ...
    (dominant_support >= min_support_lines) && ...
    (dominant_run >= min_consecutive_run);

%% 8. Track one matched peak per line within dominant component cluster
matched_order = nan(n_target,1);
matched_energy = nan(n_target,1);
matched_excess = nan(n_target,1);
matched = false(n_target,1);

for k = 1:n_target
    pk = sig_peak_orders{k};
    vk = sig_peak_values{k};
    ek = sig_peak_excess{k};

    if isempty(pk)
        continue;
    end

    in_cluster = abs(pk-dominant_center) <= cluster_tolerance + 1e-12;
    idx = find(in_cluster);

    if isempty(idx)
        continue;
    end

    % If more than one accepted local peak falls inside the same fixed
    % component window, retain the stronger one.
    [~,ii] = max(vk(idx));
    jj = idx(ii);

    matched(k) = true;
    matched_order(k) = pk(jj);
    matched_energy(k) = vk(jj);
    matched_excess(k) = ek(jj);
end

matched_order_iqr = local_iqr(matched_order(matched));

adjacent_steps = [];

for k = 1:(n_target-1)
    if matched(k) && matched(k+1)
        adjacent_steps(end+1) = abs(matched_order(k+1)-matched_order(k)); %#ok<AGROW>
    end
end

if isempty(adjacent_steps)
    median_adjacent_step = NaN;
    max_adjacent_step = NaN;
else
    median_adjacent_step = median(adjacent_steps);
    max_adjacent_step = max(adjacent_steps);
end

%% 9. Multi-component descriptive metrics
n_sig_peaks_per_line = cellfun(@numel,sig_peak_orders);
lines_with_1plus = sum(n_sig_peaks_per_line >= 1);
lines_with_2plus = sum(n_sig_peaks_per_line >= 2);

% Extract top 3 recurrent cluster centers, separated so the same broad
% family is not reported multiple times.
top_cluster_center = nan(1,3);
top_cluster_support = zeros(1,3);
top_cluster_run = zeros(1,3);
top_cluster_strength = zeros(1,3);

available = guard_mask;

for ir = 1:3
    idx_pool = find(available);

    if isempty(idx_pool)
        break;
    end

    score_r = [ ...
        support_count(idx_pool).', ...
        max_consecutive_run(idx_pool).', ...
        support_strength(idx_pool).' ];

    [~,ord_r] = sortrows(score_r,[-1 -2 -3]);
    ii = idx_pool(ord_r(1));

    if support_count(ii) == 0
        break;
    end

    top_cluster_center(ir) = p_grid(ii);
    top_cluster_support(ir) = support_count(ii);
    top_cluster_run(ir) = max_consecutive_run(ii);
    top_cluster_strength(ir) = support_strength(ii);

    available(abs(p_grid-p_grid(ii)) <= 2*cluster_tolerance + 1e-12) = false;
end

%% 10. Figure 1: significant local peak map
fig1 = figure('Color','w','Name','FAIR R0 significant local peak map');

imagesc(p_grid,1:n_target,real_curve);
axis xy;
xlabel('FrAc order p');
ylabel('Frozen target audited line');
title('Real Eq.(31) energy with max-statistic significant local peaks');
colorbar;
hold on;

for k = 1:n_target
    pk = sig_peak_orders{k};

    if ~isempty(pk)
        plot(pk,k*ones(size(pk)),'wo', ...
            'MarkerSize',6,'LineWidth',1.2);
    end
end

xline(p_blind,'w--','p=1','LineWidth',1.0);
xline(p_blind-phase_guard_halfwidth,'w:','LineWidth',0.8);
xline(p_blind+phase_guard_halfwidth,'w:','LineWidth',0.8);

hold off;

exportgraphics(fig1, ...
    fullfile(result_dir,'01_fwer_significant_peak_map.png'), ...
    'Resolution',cfg.figure_resolution);

%% 11. Figure 2: recurrence support
fig2 = figure('Color','w','Name','FAIR R0 recurrence support');
tiledlayout(2,1,'Padding','compact','TileSpacing','compact');

nexttile;
plot(p_grid,support_count,'o-','LineWidth',1.1);
hold on;
yline(min_support_lines,'--',sprintf('support gate = %d',min_support_lines));
xline(dominant_center,':',sprintf('dominant %.2f',dominant_center), ...
    'LineWidth',1.0);
xline(p_blind,'--','p=1','LineWidth',0.8);
hold off;
xlabel('Component-cluster center order p');
ylabel('Supporting target lines');
title(sprintf('Local-peak recurrence | dominant support=%d/%d', ...
    dominant_support,n_target));
grid on;

nexttile;
plot(p_grid,max_consecutive_run,'o-','LineWidth',1.1);
hold on;
yline(min_consecutive_run,'--',sprintf('run gate = %d',min_consecutive_run));
xline(dominant_center,':',sprintf('dominant %.2f',dominant_center), ...
    'LineWidth',1.0);
xline(p_blind,'--','p=1','LineWidth',0.8);
hold off;
xlabel('Component-cluster center order p');
ylabel('Max consecutive audited-line run');
title(sprintf('Spatial recurrence | dominant max run=%d',dominant_run));
grid on;

exportgraphics(fig2, ...
    fullfile(result_dir,'02_recurrence_support.png'), ...
    'Resolution',cfg.figure_resolution);

%% 12. Figure 3: dominant component track
fig3 = figure('Color','w','Name','FAIR R0 dominant component track');

plot(target_global,matched_order,'o-','LineWidth',1.2);
hold on;

missing = ~matched;
if any(missing)
    plot(target_global(missing), ...
        dominant_center*ones(sum(missing),1), ...
        'x','MarkerSize',8,'LineWidth',1.2);
end

yline(dominant_center,'--', ...
    sprintf('cluster center %.2f',dominant_center), ...
    'LineWidth',0.9);

yline(dominant_center-cluster_tolerance,':','LineWidth',0.7);
yline(dominant_center+cluster_tolerance,':','LineWidth',0.7);

hold off;
xlabel('Range column');
ylabel('Matched significant local-peak order');
title(sprintf(['Dominant recurrent component | support=%d/%d | ' ...
    'run=%d | gate=%s'], ...
    dominant_support,n_target,dominant_run,passfail(dominant_gate_pass)));
grid on;

exportgraphics(fig3, ...
    fullfile(result_dir,'03_dominant_component_track.png'), ...
    'Resolution',cfg.figure_resolution);

%% 13. CSV outputs
AuditedLine = (1:n_target).';
RangeColumn = target_global(:);
MaxStatQ95 = line_maxstat_q95;
NumSignificantLocalPeaks = n_sig_peaks_per_line(:);
DominantClusterMatched = matched;
DominantMatchedOrder = matched_order;
DominantMatchedEnergy = matched_energy;
DominantMatchedExcess = matched_excess;

T = table( ...
    AuditedLine,RangeColumn,MaxStatQ95,NumSignificantLocalPeaks, ...
    DominantClusterMatched,DominantMatchedOrder, ...
    DominantMatchedEnergy,DominantMatchedExcess);

writetable(T, ...
    fullfile(result_dir,'EXP02_FAIR_R0_COMPONENT_line_metrics.csv'));

%% 14. Save workspace
save(fullfile(result_dir,'EXP02_FAIR_R0_COMPONENT_workspace.mat'), ...
    'cfg','target_global','p_grid','guard_mask', ...
    'rng_seed','n_surrogates','phase_guard_halfwidth', ...
    'surrogate_max_percentile','cluster_tolerance', ...
    'min_support_lines','min_consecutive_run', ...
    'real_curve','line_maxstat_q95', ...
    'sig_peak_orders','sig_peak_values','sig_peak_excess', ...
    'support_count','max_consecutive_run','support_strength', ...
    'dominant_center','dominant_support','dominant_run', ...
    'dominant_strength','dominant_gate_pass', ...
    'matched','matched_order','matched_energy','matched_excess', ...
    'matched_order_iqr','median_adjacent_step','max_adjacent_step', ...
    'n_sig_peaks_per_line','lines_with_1plus','lines_with_2plus', ...
    'top_cluster_center','top_cluster_support', ...
    'top_cluster_run','top_cluster_strength', ...
    'max_abs_realcurve_diff_vs_saved');

%% 15. Feedback bundle
txt_path = fullfile(result_dir,'EXP02_FAIR_R0_COMPONENT_FEEDBACK.txt');

fid = fopen(txt_path,'w');
if fid < 0
    error('Cannot write feedback bundle.');
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP02-FAIR-R0 COMPONENT-CONSISTENCY GATE\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'G0=NOT_RUN\n');
fprintf(fid,'Neighbor3=NOT_RUN\n');
fprintf(fid,'Proposed=NOT_RUN\n');
fprintf(fid,'Branch_taxonomy=NOT_RUN\n');
fprintf(fid,'Second_FAIR_ship=NOT_USED\n');
fprintf(fid,'Inverse_focus=NOT_RUN\n\n');

fprintf(fid,'[FROZEN INPUT / REPRODUCIBILITY]\n');
fprintf(fid,'stem=%s\n',cfg.stem);
fprintf(fid,'crop_rows=%d:%d\n',R.r1,R.r2);
fprintf(fid,'crop_columns=%d:%d\n',R.c1,R.c2);
fprintf(fid,'target_lines=%d\n',n_target);
fprintf(fid,'target_range_columns=%s\n',mat2str(target_global));
fprintf(fid,'rng_seed=%d\n',rng_seed);
fprintf(fid,'surrogates_per_line=%d\n',n_surrogates);
fprintf(fid,'max_abs_realcurve_diff_vs_saved_phase_gate=%.12g\n\n', ...
    max_abs_realcurve_diff_vs_saved);

fprintf(fid,'[PRE-REGISTERED GATE]\n');
fprintf(fid,'phase_blind_order=%.6f\n',p_blind);
fprintf(fid,'phase_guard_halfwidth=%.6f\n',phase_guard_halfwidth);
fprintf(fid,'surrogate_test=linewise_max_nondegenerate_energy\n');
fprintf(fid,'surrogate_max_percentile=%.1f\n',surrogate_max_percentile);
fprintf(fid,'local_peak_required=1\n');
fprintf(fid,'cluster_tolerance_order=%.6f\n',cluster_tolerance);
fprintf(fid,'minimum_support_lines=%d/%d\n',min_support_lines,n_target);
fprintf(fid,'minimum_consecutive_audited_line_run=%d\n\n',min_consecutive_run);

fprintf(fid,'[DOMINANT RECURRENT COMPONENT]\n');
fprintf(fid,'dominant_cluster_center=%.6f\n',dominant_center);
fprintf(fid,'support_lines=%d/%d\n',dominant_support,n_target);
fprintf(fid,'max_consecutive_run=%d\n',dominant_run);
fprintf(fid,'summed_excess_above_linewise_maxstat_q95=%.9g\n',dominant_strength);
fprintf(fid,'matched_order_IQR=%.9g\n',matched_order_iqr);
fprintf(fid,'median_adjacent_matched_order_step=%.9g\n',median_adjacent_step);
fprintf(fid,'max_adjacent_matched_order_step=%.9g\n',max_adjacent_step);
fprintf(fid,'engineering_component_consistency_gate=%s\n\n', ...
    passfail(dominant_gate_pass));

fprintf(fid,'[MULTI-PEAK DESCRIPTION]\n');
fprintf(fid,'lines_with_at_least_one_FWER_guarded_peak=%d/%d\n', ...
    lines_with_1plus,n_target);
fprintf(fid,'lines_with_at_least_two_FWER_guarded_peaks=%d/%d\n', ...
    lines_with_2plus,n_target);

for ir = 1:3
    if isnan(top_cluster_center(ir))
        continue;
    end

    fprintf(fid,['top_cluster_%d center=%.6f support=%d/%d ' ...
        'max_run=%d strength=%.9g\n'], ...
        ir,top_cluster_center(ir),top_cluster_support(ir),n_target, ...
        top_cluster_run(ir),top_cluster_strength(ir));
end

fprintf(fid,'\n[PER-LINE ACCEPTED PEAKS]\n');

for k = 1:n_target
    fprintf(fid,'line_%02d col=%d maxstat_q95=%.9g n_peaks=%d orders=%s\n', ...
        k,target_global(k),line_maxstat_q95(k), ...
        numel(sig_peak_orders{k}),mat2str(sig_peak_orders{k},3));
end

fprintf(fid,'\n[INTERPRETATION BOUNDARY]\n');
fprintf(fid,['Accepted peaks are non-p=1 local maxima that exceed the 95th ' ...
    'percentile of the maximum nondegenerate Eq.(31) energy from the same ' ...
    'line''s amplitude-preserving phase-permutation surrogates. This ' ...
    'controls the within-line order scan more strictly than the previous ' ...
    'pointwise phase gate.\n']);
fprintf(fid,['The engineering component-consistency gate supports a recurrent ' ...
    'LFM-component-compatible structure only if the dominant peak family ' ...
    'appears in at least half of the frozen target lines and in a run of ' ...
    'at least four consecutive audited lines.\n']);
fprintf(fid,['Even a PASS does not prove the entire real ship signal is exactly ' ...
    'MC-LFM. It establishes a sufficiently recurrent phase-coherent local ' ...
    'component to justify considering the next real branch-state audit.\n']);

fprintf(fid,'\n[UPLOAD REQUEST]\n');
fprintf(fid,'1) EXP02_FAIR_R0_COMPONENT_FEEDBACK.txt\n');
fprintf(fid,'2) 01_fwer_significant_peak_map.png\n');
fprintf(fid,'3) 02_recurrence_support.png\n');
fprintf(fid,'4) 03_dominant_component_track.png\n');

fprintf('\n============================================================\n');
fprintf('Component-consistency gate complete.\n');
fprintf('Dominant center : %.3f\n',dominant_center);
fprintf('Support         : %d/%d\n',dominant_support,n_target);
fprintf('Max run         : %d\n',dominant_run);
fprintf('Gate            : %s\n',passfail(dominant_gate_pass));
fprintf('Feedback        : %s\n',txt_path);
fprintf('============================================================\n');

%% Local helpers
function keep_idx = nms_peak_indices(candidate_idx,y,p_grid,tol)
% Retain strongest peak first, suppress candidates within +/- tol.

if isempty(candidate_idx)
    keep_idx = candidate_idx;
    return;
end

[~,ord] = sort(y(candidate_idx),'descend');
candidate_idx = candidate_idx(ord);

keep_idx = [];

for i = 1:numel(candidate_idx)
    ii = candidate_idx(i);

    if isempty(keep_idx) || ...
            all(abs(p_grid(ii)-p_grid(keep_idx)) > tol + 1e-12)
        keep_idx(end+1) = ii; %#ok<AGROW>
    end
end

% Return in increasing order for readability.
[~,ord2] = sort(p_grid(keep_idx));
keep_idx = keep_idx(ord2);

end

function r = longest_true_run(x)

x = logical(x(:).');

r = 0;
cur = 0;

for i = 1:numel(x)
    if x(i)
        cur = cur + 1;
        r = max(r,cur);
    else
        cur = 0;
    end
end

end

function q = local_iqr(x)

x = x(~isnan(x));
x = sort(x(:));

if isempty(x)
    q = NaN;
    return;
end

q = vector_percentile(x,75) - vector_percentile(x,25);

end

function v = vector_percentile(x,p)

x = sort(x(:));
n = numel(x);

if n == 0
    v = NaN;
    return;
end

if n == 1
    v = x(1);
    return;
end

pos = 1 + (n-1)*p/100;
lo = floor(pos);
hi = ceil(pos);

if lo == hi
    v = x(lo);
else
    w = pos-lo;
    v = (1-w)*x(lo) + w*x(hi);
end

end

function s = passfail(tf)

if tf
    s = 'PASS';
else
    s = 'FAIL';
end

end
