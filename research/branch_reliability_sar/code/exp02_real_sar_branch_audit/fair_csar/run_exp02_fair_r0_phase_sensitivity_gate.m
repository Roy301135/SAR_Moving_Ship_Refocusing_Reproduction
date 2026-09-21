%% run_exp02_fair_r0_phase_sensitivity_gate.m
% EXP02-FAIR-R0-PHASE
% Phase-Sensitivity Gate for FAIR-CSAR Candidate B
%
% Scientific question
% -------------------
% The corrected Eq.(31) R0 audit found a strong, highly stable target peak
% at p = 1. However, for the present normalized Eq.(31) metric, p = 1 is a
% special phase-blind point:
%
%   p = 1  ->  p+1 = 2 in Eq.(26)
%            -> second-order FrFT = parity/time reversal
%            -> normalized Eq.(31) energy depends only on |x[m]|
%
% Therefore this experiment tests whether the real target also contains
% NON-DEGENERATE phase-coherent fractional structure away from p = 1.
%
% Null construction
% -----------------
% For each frozen target azimuth line
%
%   x[m] = |x[m]| exp(j phi[m])
%
% construct amplitude-preserving phase-permutation surrogates
%
%   x_surr[m] = |x[m]| exp(j phi[perm(m)])
%
% The amplitude envelope and empirical phase histogram are preserved, while
% the azimuth-time phase ordering is destroyed.
%
% Frozen boundaries
% -----------------
%   - Same Candidate B
%   - Same OBB + 32 px crop
%   - Same Wang E(n)>mean(E) target selection
%   - Same deterministic even subsampling to 12 target lines
%   - No G0 / Neighbor-3 / Proposed
%   - No branch taxonomy
%   - No second FAIR-CSAR ship
%   - No inverse focusing / re-focusing
%
% Positive-control status
% -----------------------
% The current fair_csar_fractional_line_audit.m has already passed the
% synthetic LFM positive control under the corrected Xu Eq.(31) objective.
%
% Output review bundle
% --------------------
% Upload only:
%   EXP02_FAIR_R0_PHASE_FEEDBACK.txt
%   01_real_vs_phase_surrogate.png
%   02_phase_excess_heatmap.png
%   03_nondegenerate_support.png

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

%% 1. Frozen paths
data_root = fullfile(repo_root,'data','fair_csar','pilot_candidate_B');

mat_path = fullfile(data_root,'SLCMats',[cfg.stem '.mat']);

r0_dir = fullfile( ...
    research_dir,'results','exp02_real_sar_branch_audit', ...
    'fair_csar','r0_mclfm_compatibility');

r0_workspace = fullfile(r0_dir,'EXP02_FAIR_R0_workspace.mat');

result_dir = fullfile( ...
    research_dir,'results','exp02_real_sar_branch_audit', ...
    'fair_csar','r0_phase_sensitivity_gate');

if ~exist(result_dir,'dir')
    mkdir(result_dir);
end

if exist(mat_path,'file') ~= 2
    error('Frozen FAIR-CSAR MAT input not found: %s',mat_path);
end

if exist(r0_workspace,'file') ~= 2
    error(['Corrected R0 workspace not found: %s\n' ...
           'Run the corrected run_exp02_fair_r0.m first.'],r0_workspace);
end

%% 2. Load exact frozen R0 selection
W = load(r0_workspace, ...
    'cfg','r1','r2','c1','c2','target_global','bg_global','p_grid');

required_fields = { ...
    'cfg','r1','r2','c1','c2','target_global','bg_global','p_grid'};

for i = 1:numel(required_fields)
    if ~isfield(W,required_fields{i})
        error('R0 workspace missing required field: %s',required_fields{i});
    end
end

if ~strcmp(W.cfg.stem,cfg.stem)
    error('R0 workspace candidate stem does not match current frozen config.');
end

target_global = W.target_global(:).';
bg_global = W.bg_global(:).';
p_grid = W.p_grid(:).';

if numel(target_global) ~= 12
    warning('Expected 12 frozen target lines, found %d.',numel(target_global));
end

%% 3. Load complex SLC
[S,mat_info] = fair_csar_load_complex_mat(mat_path);
S = double(S);

%% 4. Frozen phase-surrogate settings
rng_seed = 20260917;
n_surrogates = 32;

% Exact p=1 is analytically phase-blind for the current Eq.(31) metric.
p_blind = 1.0;

% Guard around p=1 for the "non-degenerate" summary.
% This is fixed BEFORE inspecting surrogate results.
phase_guard_halfwidth = 0.06;

% Empirical surrogate envelope.
surrogate_upper_percentile = 95;

rng(rng_seed,'twister');

n_target = numel(target_global);
Np = numel(p_grid);

real_curve = zeros(n_target,Np);
surr_median = zeros(n_target,Np);
surr_q05 = zeros(n_target,Np);
surr_q95 = zeros(n_target,Np);

phase_excess_median = zeros(n_target,Np);
phase_excess_q95 = zeros(n_target,Np);

p1_max_relative_difference = zeros(n_target,1);

best_guard_order = nan(n_target,1);
best_guard_excess_q95 = nan(n_target,1);
best_guard_ratio_to_median = nan(n_target,1);
guard_positive = false(n_target,1);

fprintf('============================================================\n');
fprintf('EXP02-FAIR-R0 PHASE-SENSITIVITY GATE\n');
fprintf('Candidate        : %s\n',cfg.stem);
fprintf('Frozen target lines: %d\n',n_target);
fprintf('Surrogates/line : %d\n',n_surrogates);
fprintf('RNG seed        : %d\n',rng_seed);
fprintf('p=1 guard       : |p-1| <= %.2f excluded from nondegenerate summary\n', ...
    phase_guard_halfwidth);
fprintf('G0/N3/Proposed  : NOT RUN\n');
fprintf('============================================================\n\n');

%% 5. Target-line phase-surrogate audit
[~,i_p1] = min(abs(p_grid-p_blind));

guard_mask = abs(p_grid-p_blind) > (phase_guard_halfwidth + 1e-12);

if ~any(guard_mask)
    error('Non-degenerate order mask is empty.');
end

for k = 1:n_target
    col = target_global(k);
    x = S(W.r1:W.r2,col);

    % Real signal.
    a_real = fair_csar_fractional_line_audit( ...
        x,p_grid,cfg.frac_exclude_zero_lags);

    real_curve(k,:) = a_real.frac_energy;

    amp = abs(x(:).');
    ph = angle(x(:).');

    surr_curves = zeros(n_surrogates,Np);

    for is = 1:n_surrogates
        perm = randperm(numel(ph));

        % Preserve amplitude sample-by-sample and preserve the empirical
        % phase histogram, while destroying azimuth-time phase ordering.
        xs = amp .* exp(1j*ph(perm));

        a_s = fair_csar_fractional_line_audit( ...
            xs,p_grid,cfg.frac_exclude_zero_lags);

        surr_curves(is,:) = a_s.frac_energy;
    end

    surr_median(k,:) = column_percentile(surr_curves,50);
    surr_q05(k,:) = column_percentile(surr_curves,5);
    surr_q95(k,:) = column_percentile(surr_curves,surrogate_upper_percentile);

    phase_excess_median(k,:) = real_curve(k,:) - surr_median(k,:);
    phase_excess_q95(k,:) = real_curve(k,:) - surr_q95(k,:);

    % At p=1 the metric should be invariant to phase permutation.
    denom_p1 = max(abs(real_curve(k,i_p1)),eps);
    p1_max_relative_difference(k) = ...
        max(abs(surr_curves(:,i_p1) - real_curve(k,i_p1))) / denom_p1;

    % Non-degenerate line-level summary.
    idx_guard = find(guard_mask);

    [best_excess,ii] = max(phase_excess_q95(k,idx_guard));
    jj = idx_guard(ii);

    best_guard_order(k) = p_grid(jj);
    best_guard_excess_q95(k) = best_excess;
    best_guard_ratio_to_median(k) = ...
        real_curve(k,jj) / max(surr_median(k,jj),eps);

    guard_positive(k) = best_excess > 0;

    fprintf('target line %2d/%2d | col=%d | p1 rel.diff=%.3e | ', ...
        k,n_target,col,p1_max_relative_difference(k));
    fprintf('best nondeg p=%.2f | excess95=%+.4g | positive=%d\n', ...
        best_guard_order(k),best_guard_excess_q95(k),guard_positive(k));
end

%% 6. Aggregate support across frozen target lines
support_matrix = (real_curve > surr_q95) & repmat(guard_mask,n_target,1);
support_count = sum(support_matrix,1);
support_count(~guard_mask) = 0;

[max_support_lines,i_support] = max(support_count);
max_support_order = p_grid(i_support);

n_lines_any_positive = sum(guard_positive);

positive_orders = best_guard_order(guard_positive);
if isempty(positive_orders)
    positive_order_iqr = NaN;
else
    positive_order_iqr = local_iqr(positive_orders);
end

median_p1_rel_diff = median(p1_max_relative_difference);
max_p1_rel_diff = max(p1_max_relative_difference);

real_median_curve = median(real_curve,1);
surr_median_curve = median(surr_median,1);
surr_q05_curve = median(surr_q05,1);
surr_q95_curve = median(surr_q95,1);

median_excess_curve = median(phase_excess_median,1);
median_excess_q95_curve = median(phase_excess_q95,1);

%% 7. Optional original background reference
% No phase surrogates are generated for background; this is only the same
% deterministic control already used in corrected R0.
n_bg = numel(bg_global);
bg_real_curve = zeros(n_bg,Np);

for k = 1:n_bg
    xb = S(W.r1:W.r2,bg_global(k));
    ab = fair_csar_fractional_line_audit( ...
        xb,p_grid,cfg.frac_exclude_zero_lags);
    bg_real_curve(k,:) = ab.frac_energy;
end

bg_median_curve = median(bg_real_curve,1);

%% 8. Figure 1: aggregate real vs surrogate
fig1 = figure('Color','w','Name','FAIR R0 phase sensitivity aggregate');

fill([p_grid fliplr(p_grid)], ...
     [surr_q05_curve fliplr(surr_q95_curve)], ...
     [0.90 0.90 0.90], ...
     'EdgeColor','none', ...
     'DisplayName','phase-permuted 5-95% envelope');
hold on;

plot(p_grid,surr_median_curve,'--','LineWidth',1.1, ...
    'DisplayName','phase-permuted median');
plot(p_grid,real_median_curve,'LineWidth',1.4, ...
    'DisplayName','real target median');
plot(p_grid,bg_median_curve,':','LineWidth',1.1, ...
    'DisplayName','real sea median');

xline(p_blind,'-.','p=1 phase-blind','LineWidth',1.0);

yl = ylim;
patch([p_blind-phase_guard_halfwidth, p_blind+phase_guard_halfwidth, ...
       p_blind+phase_guard_halfwidth, p_blind-phase_guard_halfwidth], ...
      [yl(1),yl(1),yl(2),yl(2)], ...
      [0.95 0.95 0.95], ...
      'FaceAlpha',0.25,'EdgeColor','none', ...
      'HandleVisibility','off');
uistack(findobj(gca,'Type','line'),'top');

hold off;
xlabel('FrAc order p');
ylabel('Normalized Eq.(31) FrAc energy');
title('Real target vs amplitude-preserving phase-permutation null');
legend('Location','best');
grid on;

exportgraphics(fig1, ...
    fullfile(result_dir,'01_real_vs_phase_surrogate.png'), ...
    'Resolution',cfg.figure_resolution);

%% 9. Figure 2: real minus 95th-percentile surrogate
fig2 = figure('Color','w','Name','FAIR R0 phase excess heatmap');

imagesc(p_grid,1:n_target,phase_excess_q95);
axis xy;
xlabel('FrAc order p');
ylabel('Frozen target audited line');
title('Phase-sensitive excess: real - phase-surrogate 95th percentile');
colorbar;
hold on;
xline(p_blind,'w--','p=1','LineWidth',1.0);
hold off;

exportgraphics(fig2, ...
    fullfile(result_dir,'02_phase_excess_heatmap.png'), ...
    'Resolution',cfg.figure_resolution);

%% 10. Figure 3: cross-line support + spatial order
fig3 = figure('Color','w','Name','FAIR R0 nondegenerate support');
tiledlayout(2,1,'Padding','compact','TileSpacing','compact');

nexttile;
plot(p_grid,support_count,'o-','LineWidth',1.1);
xline(p_blind,'--','p=1','LineWidth',0.9);
xline(p_blind-phase_guard_halfwidth,':','LineWidth',0.8);
xline(p_blind+phase_guard_halfwidth,':','LineWidth',0.8);
xlabel('FrAc order p');
ylabel('# target lines > own surrogate 95%');
title(sprintf('Nondegenerate phase-sensitive support | max=%d/%d at p=%.2f', ...
    max_support_lines,n_target,max_support_order));
grid on;

nexttile;
plot(target_global,best_guard_order,'o-','LineWidth',1.1);
hold on;
bad = ~guard_positive;
if any(bad)
    plot(target_global(bad),best_guard_order(bad),'x','MarkerSize',8, ...
        'LineWidth',1.2);
end
hold off;
xlabel('Range column');
ylabel('Best nondegenerate order');
title(sprintf('Per-line best real-minus-surrogate95 order | positive lines=%d/%d', ...
    n_lines_any_positive,n_target));
grid on;

exportgraphics(fig3, ...
    fullfile(result_dir,'03_nondegenerate_support.png'), ...
    'Resolution',cfg.figure_resolution);

%% 11. CSV
T = table( ...
    (1:n_target).', ...
    target_global(:), ...
    p1_max_relative_difference, ...
    best_guard_order, ...
    best_guard_excess_q95, ...
    best_guard_ratio_to_median, ...
    guard_positive, ...
    'VariableNames',{ ...
    'AuditedLine','RangeColumn','P1MaxRelativeDifference', ...
    'BestNondegenerateOrder','BestExcessAboveSurrogate95', ...
    'RealToSurrogateMedianRatioAtBestOrder','HasPositiveNondegenerateExcess'});

writetable(T,fullfile(result_dir,'EXP02_FAIR_R0_PHASE_line_metrics.csv'));

%% 12. Save workspace
save(fullfile(result_dir,'EXP02_FAIR_R0_PHASE_workspace.mat'), ...
    'cfg','rng_seed','n_surrogates', ...
    'phase_guard_halfwidth','surrogate_upper_percentile', ...
    'target_global','bg_global','p_grid', ...
    'real_curve','surr_median','surr_q05','surr_q95', ...
    'phase_excess_median','phase_excess_q95', ...
    'p1_max_relative_difference', ...
    'best_guard_order','best_guard_excess_q95', ...
    'best_guard_ratio_to_median','guard_positive', ...
    'support_count','max_support_lines','max_support_order', ...
    'n_lines_any_positive','positive_order_iqr', ...
    'real_median_curve','surr_median_curve', ...
    'surr_q05_curve','surr_q95_curve', ...
    'bg_real_curve','bg_median_curve');

%% 13. Feedback bundle
txt_path = fullfile(result_dir,'EXP02_FAIR_R0_PHASE_FEEDBACK.txt');

fid = fopen(txt_path,'w');
if fid < 0
    error('Cannot write feedback bundle.');
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP02-FAIR-R0 PHASE-SENSITIVITY GATE\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'G0=NOT_RUN\n');
fprintf(fid,'Neighbor3=NOT_RUN\n');
fprintf(fid,'Proposed=NOT_RUN\n');
fprintf(fid,'Branch_taxonomy=NOT_RUN\n');
fprintf(fid,'Second_FAIR_ship=NOT_USED\n');
fprintf(fid,'Inverse_focus=NOT_RUN\n\n');

fprintf(fid,'[FROZEN INPUT / SELECTION]\n');
fprintf(fid,'stem=%s\n',cfg.stem);
fprintf(fid,'crop_rows=%d:%d\n',W.r1,W.r2);
fprintf(fid,'crop_columns=%d:%d\n',W.c1,W.c2);
fprintf(fid,'target_lines_audited=%d\n',n_target);
fprintf(fid,'target_range_columns=%s\n',mat2str(target_global));
fprintf(fid,'background_lines_audited=%d\n',n_bg);
fprintf(fid,'selection_reused_from_corrected_R0=1\n\n');

fprintf(fid,'[SURROGATE NULL]\n');
fprintf(fid,'surrogate_type=amplitude_preserving_phase_permutation\n');
fprintf(fid,'rng_seed=%d\n',rng_seed);
fprintf(fid,'surrogates_per_target_line=%d\n',n_surrogates);
fprintf(fid,'p_grid_min=%.6f\n',min(p_grid));
fprintf(fid,'p_grid_max=%.6f\n',max(p_grid));
fprintf(fid,'p_grid_step=%.6f\n',p_grid(2)-p_grid(1));
fprintf(fid,'phase_blind_order=%.6f\n',p_blind);
fprintf(fid,'nondegenerate_guard_halfwidth=%.6f\n',phase_guard_halfwidth);
fprintf(fid,'surrogate_upper_percentile=%.1f\n\n',surrogate_upper_percentile);

fprintf(fid,'[P=1 SANITY CHECK]\n');
fprintf(fid,'median_max_relative_difference_real_vs_surrogates=%.12g\n', ...
    median_p1_rel_diff);
fprintf(fid,'max_relative_difference_real_vs_surrogates=%.12g\n', ...
    max_p1_rel_diff);
fprintf(fid,['Expected behavior: approximately zero because the normalized ' ...
    'Eq.(31) metric at p=1 is amplitude-only.\n\n']);

fprintf(fid,'[NONDEGENERATE PHASE-SENSITIVE RESULTS]\n');
fprintf(fid,'lines_with_any_real_above_own_surrogate95=%d/%d\n', ...
    n_lines_any_positive,n_target);
fprintf(fid,'max_cross_line_support=%d/%d\n', ...
    max_support_lines,n_target);
fprintf(fid,'order_of_max_cross_line_support=%.6f\n',max_support_order);
fprintf(fid,'positive_line_best_order_IQR=%.9g\n\n',positive_order_iqr);

fprintf(fid,'[PER-LINE SUMMARY]\n');
for k = 1:n_target
    fprintf(fid,['line_%02d col=%d p1_rel_diff=%.3e ' ...
        'best_nondeg_p=%.6f excess_over_q95=%+.9g ' ...
        'real_to_surr_median_ratio=%.9g positive=%d\n'], ...
        k,target_global(k),p1_max_relative_difference(k), ...
        best_guard_order(k),best_guard_excess_q95(k), ...
        best_guard_ratio_to_median(k),guard_positive(k));
end

fprintf(fid,'\n[INTERPRETATION BOUNDARY]\n');
fprintf(fid,['The p=1 peak alone is not evidence of LFM/MC-LFM phase structure, ' ...
    'because under the present Eq.(31) normalization it is phase-blind.\n']);
fprintf(fid,['Evidence for phase-sensitive compatibility requires repeatable ' ...
    'non-p=1 orders where the real target exceeds its own amplitude-preserving ' ...
    'phase-permutation surrogate envelope across neighboring target lines.\n']);
fprintf(fid,['If such nondegenerate support is absent, do not proceed to branch ' ...
    'audit on Candidate B. The next decision is then between a second ' ...
    'pre-registered FAIR candidate and an inverse-focus/static-refocus ' ...
    'closure experiment.\n']);

fprintf(fid,'\n[UPLOAD REQUEST]\n');
fprintf(fid,'1) EXP02_FAIR_R0_PHASE_FEEDBACK.txt\n');
fprintf(fid,'2) 01_real_vs_phase_surrogate.png\n');
fprintf(fid,'3) 02_phase_excess_heatmap.png\n');
fprintf(fid,'4) 03_nondegenerate_support.png\n');

fprintf('\n============================================================\n');
fprintf('Phase-sensitivity gate complete.\n');
fprintf('Feedback: %s\n',txt_path);
fprintf('============================================================\n');

%% Local helpers
function q = column_percentile(X,p)
% Percentile down rows, independently for each column, no toolbox needed.

X = sort(X,1);
n = size(X,1);

if n == 1
    q = X;
    return;
end

pos = 1 + (n-1)*p/100;
lo = floor(pos);
hi = ceil(pos);

if lo == hi
    q = X(lo,:);
else
    w = pos-lo;
    q = (1-w)*X(lo,:) + w*X(hi,:);
end

end

function q = local_iqr(x)

x = sort(x(:));

if isempty(x)
    q = NaN;
    return;
end

q25 = vector_percentile(x,25);
q75 = vector_percentile(x,75);
q = q75-q25;

end

function v = vector_percentile(x,p)

n = numel(x);

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
