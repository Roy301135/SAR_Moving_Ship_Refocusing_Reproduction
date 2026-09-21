%% run_exp02_fair_r0.m
% EXP02-FAIR-R0
% Source-Aligned MC-LFM / FrAc Compatibility Audit
%
% Frozen question:
%   In a dataset-labeled motion-defocused GF-3 SL complex target, do the
%   Wang-style ship azimuth lines exhibit target-specific fractional-domain
%   structure compatible with the Wang/Xu MC-LFM processing object?
%
% NOT RUN:
%   G0
%   Neighbor-3
%   Proposed
%   Branch taxonomy
%
% Stop rule:
%   If target lines do not show reproducibly stronger / more structured
%   fractional-domain behavior than deterministic adjacent-sea controls,
%   do NOT proceed to real branch-state audit.

clear; clc; close all;

%% 0. Resolve repository paths
this_file = mfilename('fullpath');
fair_code_dir = fileparts(this_file);
exp02_code_dir = fileparts(fair_code_dir);
code_dir = fileparts(exp02_code_dir);
research_dir = fileparts(code_dir);
research_parent = fileparts(research_dir);
repo_root = fileparts(research_parent);

functions_root = fullfile(research_dir,'functions');
addpath(genpath(functions_root));

% Reuse the already validated FrFT convention from the reproduction line.
papers_root = fullfile(repo_root,'papers');
if exist(papers_root,'dir')
    addpath(genpath(papers_root));
end

if exist('frft_direct','file') ~= 2
    error(['Validated frft_direct.m not found after adding <repo>/papers. ' ...
           'Expected under papers/Wang2023_Fast_Accurate_FrFT/code/functions/.']);
end

cfg = config_exp02_fair_r0();

data_root = fullfile(repo_root,'data','fair_csar','pilot_candidate_B');

mat_path = fullfile(data_root,'SLCMats',[cfg.stem '.mat']);
png_path = fullfile(data_root,'PNGImages',[cfg.stem '.png']);
xml_path = fullfile(data_root,'METAXmls',[cfg.stem '.xml']);

result_dir = fullfile( ...
    research_dir,'results','exp02_real_sar_branch_audit', ...
    'fair_csar','r0_mclfm_compatibility');

if ~exist(result_dir,'dir')
    mkdir(result_dir);
end

required = {mat_path,png_path,xml_path};
for i = 1:numel(required)
    if exist(required{i},'file') ~= 2
        error('Required input missing: %s',required{i});
    end
end

fprintf('============================================================\n');
fprintf('EXP02-FAIR-R0 | Source-Aligned MC-LFM / FrAc Audit\n');
fprintf('Candidate : %s\n',cfg.stem);
fprintf('Results   : %s\n',result_dir);
fprintf('G0/N3/Proposed/branch taxonomy: NOT RUN\n');
fprintf('============================================================\n\n');

%% 1. Load data and metadata
[S,mat_info] = fair_csar_load_complex_mat(mat_path);
meta = fair_csar_read_metadata_xml(xml_path);
orient = fair_csar_png_orientation_corr(S,png_path);

fprintf('MAT variable : %s\n',mat_info.variable_name);
fprintf('MAT size     : %d x %d | class=%s | complex=%d\n', ...
    size(S,1),size(S,2),mat_info.class_name,mat_info.is_complex);
fprintf('PNG raw corr : %.6f | best=%s (%.6f)\n\n', ...
    orient.raw_corr,orient.best_name,orient.best_corr);

if orient.raw_corr < cfg.min_png_corr
    error('RAW MAT/PNG correlation %.4f is below frozen integrity threshold %.2f.', ...
        orient.raw_corr,cfg.min_png_corr);
end

if orient.best_name ~= "raw"
    error('RAW orientation is not the best MAT/PNG orientation match (%s is best).', ...
        orient.best_name);
end

if size(S,1) ~= meta.patch_height || size(S,2) ~= meta.patch_width
    error('MAT size disagrees with XML patch size.');
end

if ~strcmp(meta.sub_category,'Motion_Defocusing_Ship')
    error('Frozen candidate is not labeled Motion_Defocusing_Ship in XML.');
end

%% 2. Frozen OBB + margin crop
x_min = floor(min(meta.x));
x_max = ceil(max(meta.x));
y_min = floor(min(meta.y));
y_max = ceil(max(meta.y));

r1 = max(1,y_min - cfg.crop_margin_px);
r2 = min(size(S,1),y_max + cfg.crop_margin_px);
c1 = max(1,x_min - cfg.crop_margin_px);
c2 = min(size(S,2),x_max + cfg.crop_margin_px);

G = double(S(r1:r2,c1:c2));

% Wang-style range-column selection inside the ship crop.
line_energy = sum(abs(G).^2,1);
target_local_all = find(line_energy > mean(line_energy));

if isempty(target_local_all)
    error('No target line survives E(n) > mean(E) rule.');
end

target_global_all = c1 - 1 + target_local_all;

% Deterministic evenly spaced subsampling for compute control.
target_local = even_subsample(target_local_all,cfg.max_lines_per_group);
target_global = c1 - 1 + target_local;
n_target = numel(target_local);

%% 3. Deterministic adjacent-sea background controls
left_hi = max(0,c1 - cfg.bg_gap_px);
left_lo = max(1,left_hi - cfg.bg_band_width_px + 1);

right_lo = min(size(S,2)+1,c2 + cfg.bg_gap_px);
right_hi = min(size(S,2),right_lo + cfg.bg_band_width_px - 1);

bg_pool = [];
if left_lo <= left_hi
    bg_pool = [bg_pool, left_lo:left_hi]; %#ok<AGROW>
end
if right_lo <= right_hi
    bg_pool = [bg_pool, right_lo:right_hi]; %#ok<AGROW>
end

if numel(bg_pool) < n_target
    error('Not enough deterministic adjacent-sea control columns.');
end

bg_global = even_subsample(bg_pool,n_target);

fprintf('Crop rows    : %d:%d (%d samples)\n',r1,r2,r2-r1+1);
fprintf('Crop columns : %d:%d\n',c1,c2);
fprintf('Wang E>mean target columns: %d | audited=%d\n', ...
    numel(target_local_all),n_target);
fprintf('Background audited columns: %d\n\n',numel(bg_global));

%% 4. Fractional-domain audit
p_grid = cfg.p_grid;
Np = numel(p_grid);

target_frac_map = zeros(n_target,Np);
target_frft_map = zeros(n_target,Np);
target_entropy_map = zeros(n_target,Np);

bg_frac_map = zeros(n_target,Np);
bg_frft_map = zeros(n_target,Np);
bg_entropy_map = zeros(n_target,Np);

target_metrics = struct([]);
bg_metrics = struct([]);

for k = 1:n_target
    xt = S(r1:r2,target_global(k));
    xb = S(r1:r2,bg_global(k));

    at = fair_csar_fractional_line_audit( ...
        xt,p_grid,cfg.frac_exclude_zero_lags);
    ab = fair_csar_fractional_line_audit( ...
        xb,p_grid,cfg.frac_exclude_zero_lags);

    target_frac_map(k,:) = at.frac_score;
    target_frft_map(k,:) = at.frft_concentration;
    target_entropy_map(k,:) = at.frft_entropy;

    bg_frac_map(k,:) = ab.frac_score;
    bg_frft_map(k,:) = ab.frft_concentration;
    bg_entropy_map(k,:) = ab.frft_entropy;

    tm = compact_metrics(at,target_global(k),'target', ...
        sum(abs(double(xt)).^2));
    bm = compact_metrics(ab,bg_global(k),'background', ...
        sum(abs(double(xb)).^2));

    % Prototype-based struct preallocation. MATLAB cannot assign a
    % populated struct into repmat(struct(),...), because the field sets
    % differ. Freeze the actual schema from the first returned metrics
    % structure, then overwrite subsequent entries.
    if k == 1
        target_metrics = repmat(tm,1,n_target);
        bg_metrics = repmat(bm,1,n_target);
    else
        target_metrics(k) = tm;
        bg_metrics(k) = bm;
    end

    fprintf('line %2d/%2d complete\n',k,n_target);
end

T = struct2table([target_metrics,bg_metrics]);
writetable(T,fullfile(result_dir,'EXP02_FAIR_R0_line_metrics.csv'));

%% 5. Aggregate metrics
Tt = struct2table(target_metrics);
Tb = struct2table(bg_metrics);

target_frac_median = median(Tt.frac_peak);
bg_frac_median = median(Tb.frac_peak);
frac_TB_ratio = target_frac_median / max(bg_frac_median,eps);

target_frac_prom_median = median(Tt.frac_peak_to_median);
bg_frac_prom_median = median(Tb.frac_peak_to_median);
frac_prom_TB_ratio = target_frac_prom_median / max(bg_frac_prom_median,eps);

target_frft_median = median(Tt.frft_peak);
bg_frft_median = median(Tb.frft_peak);
frft_TB_ratio = target_frft_median / max(bg_frft_median,eps);

target_p_iqr = local_iqr(Tt.best_frac_order);
bg_p_iqr = local_iqr(Tb.best_frac_order);

[~,ordt] = sort(Tt.range_column);
target_p_sorted = Tt.best_frac_order(ordt);
target_step_median = median(abs(diff(target_p_sorted)));

[~,ordb] = sort(Tb.range_column);
bg_p_sorted = Tb.best_frac_order(ordb);
bg_step_median = median(abs(diff(bg_p_sorted)));

%% 6. Figure 1: frozen candidate / audited columns
I = log1p(abs(double(S)));

fig1 = figure('Color','w','Name','FAIR R0 candidate');
imagesc(I);
axis image;
colormap gray;
hold on;
rectangle('Position',[c1 r1 c2-c1+1 r2-r1+1], ...
    'EdgeColor',[1 0 0],'LineWidth',1.2);
for k = 1:numel(target_global)
    xline(target_global(k),'LineWidth',0.7);
end
for k = 1:numel(bg_global)
    xline(bg_global(k),'--','LineWidth',0.5);
end
hold off;
xlabel('Range column');
ylabel('Azimuth row');
title('Frozen Candidate B: crop + audited target/background lines');
exportgraphics(fig1,fullfile(result_dir,'01_candidate_roi_and_lines.png'), ...
    'Resolution',cfg.figure_resolution);

%% 7. Figure 2: Eq.(31) FrAc energy maps
fig2 = figure('Color','w','Name','FAIR R0 Eq31 FrAc maps');
tiledlayout(2,1,'Padding','compact','TileSpacing','compact');

nexttile;
imagesc(p_grid,1:n_target,target_frac_map);
axis xy;
xlabel('FrFT order p');
ylabel('Target audited line');
title('Target: normalized Eq.(31) total FrAc energy');
colorbar;

nexttile;
imagesc(p_grid,1:n_target,bg_frac_map);
axis xy;
xlabel('FrFT order p');
ylabel('Background audited line');
title('Adjacent-sea control: same normalized Eq.(31) FrAc energy');
colorbar;

exportgraphics(fig2,fullfile(result_dir,'02_frac_score_maps.png'), ...
    'Resolution',cfg.figure_resolution);

%% 8. Figure 3: best FrAc order across range
fig3 = figure('Color','w','Name','FAIR R0 best order');
plot(Tt.range_column,Tt.best_frac_order,'o-','LineWidth',1.1);
hold on;
plot(Tb.range_column,Tb.best_frac_order,'x--','LineWidth',1.0);
hold off;
xlabel('Range column');
ylabel('Best FrAc order p');
title('Best fractional order: target vs deterministic sea control');
legend('target','background','Location','best');
grid on;
exportgraphics(fig3,fullfile(result_dir,'03_best_order_vs_range.png'), ...
    'Resolution',cfg.figure_resolution);

%% 9. Figure 4: target/background summary
fig4 = figure('Color','w','Name','FAIR R0 summary');
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');

nexttile;
plot(ones(height(Tt),1),Tt.frac_peak,'o');
hold on;
plot(2*ones(height(Tb),1),Tb.frac_peak,'x');
hold off;
xlim([0.5 2.5]);
xticks([1 2]);
xticklabels({'target','background'});
ylabel('Peak normalized Eq.(31) FrAc energy');
title(sprintf('Median T/B = %.3f',frac_TB_ratio));
grid on;

nexttile;
plot(ones(height(Tt),1),Tt.frac_peak_to_median,'o');
hold on;
plot(2*ones(height(Tb),1),Tb.frac_peak_to_median,'x');
hold off;
xlim([0.5 2.5]);
xticks([1 2]);
xticklabels({'target','background'});
ylabel('Eq.(31) FrAc peak / median(order)');
title(sprintf('Prominence median T/B = %.3f',frac_prom_TB_ratio));
grid on;

exportgraphics(fig4,fullfile(result_dir,'04_target_background_summary.png'), ...
    'Resolution',cfg.figure_resolution);

%% 10. Save MAT
save(fullfile(result_dir,'EXP02_FAIR_R0_workspace.mat'), ...
    'cfg','meta','mat_info','orient', ...
    'r1','r2','c1','c2', ...
    'target_local_all','target_global_all', ...
    'target_global','bg_global', ...
    'p_grid','target_frac_map','bg_frac_map', ...
    'target_frft_map','bg_frft_map', ...
    'target_entropy_map','bg_entropy_map', ...
    'Tt','Tb', ...
    'target_frac_median','bg_frac_median','frac_TB_ratio', ...
    'target_frac_prom_median','bg_frac_prom_median','frac_prom_TB_ratio', ...
    'target_frft_median','bg_frft_median','frft_TB_ratio', ...
    'target_p_iqr','bg_p_iqr', ...
    'target_step_median','bg_step_median');

%% 11. Feedback bundle
txt_path = fullfile(result_dir,'EXP02_FAIR_R0_FEEDBACK_BUNDLE.txt');
fid = fopen(txt_path,'w');
if fid < 0
    error('Cannot write feedback bundle.');
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP02-FAIR-R0 / SOURCE-ALIGNED MC-LFM / FrAc COMPATIBILITY AUDIT\n');
fprintf(fid,'================================================================\n');
fprintf(fid,'G0: NOT RUN\n');
fprintf(fid,'Neighbor-3: NOT RUN\n');
fprintf(fid,'Proposed: NOT RUN\n');
fprintf(fid,'Branch taxonomy: NOT RUN\n');
fprintf(fid,'automatic_gate_label=NOT_ASSIGNED\n\n');

fprintf(fid,'[FROZEN INPUT]\n');
fprintf(fid,'stem=%s\n',cfg.stem);
fprintf(fid,'dataset_label=%s\n',meta.sub_category);
fprintf(fid,'imaging_mode=%s\n',meta.imaging_mode);
fprintf(fid,'nominal_resolution_m=%.6f\n',meta.nominal_resolution);
fprintf(fid,'polarization=%s\n',meta.polarization_mode);
fprintf(fid,'velocity_mps=%.9f\n',meta.velocity_mps);
fprintf(fid,'center_frequency_hz=%.9f\n',meta.radar_center_frequency_hz);
fprintf(fid,'prf_hz=%.9f\n',meta.prf_hz);
fprintf(fid,'incidence_angle_deg=%.9f\n\n',meta.incidence_angle_deg);

fprintf(fid,'[COMPLEX INTERFACE]\n');
fprintf(fid,'mat_variable=%s\n',mat_info.variable_name);
fprintf(fid,'mat_class=%s\n',mat_info.class_name);
fprintf(fid,'mat_size=%dx%d\n',size(S,1),size(S,2));
fprintf(fid,'is_complex=%d\n',mat_info.is_complex);
fprintf(fid,'nan_count=%d\n',mat_info.n_nan);
fprintf(fid,'inf_count=%d\n',mat_info.n_inf);
fprintf(fid,'zero_fraction=%.12g\n',mat_info.zero_fraction);
fprintf(fid,'png_raw_corr=%.9f\n',orient.raw_corr);
fprintf(fid,'best_orientation=%s\n',orient.best_name);
fprintf(fid,'best_orientation_corr=%.9f\n\n',orient.best_corr);

fprintf(fid,'[FROZEN CROP / LINE SELECTION]\n');
fprintf(fid,'crop_rows=%d:%d\n',r1,r2);
fprintf(fid,'crop_columns=%d:%d\n',c1,c2);
fprintf(fid,'crop_margin_px=%d\n',cfg.crop_margin_px);
fprintf(fid,'target_rule=E(n)>mean(E) inside frozen crop\n');
fprintf(fid,'target_lines_before_compute_subsample=%d\n',numel(target_global_all));
fprintf(fid,'target_lines_audited=%d\n',numel(target_global));
fprintf(fid,'background_lines_audited=%d\n',numel(bg_global));
fprintf(fid,'background_rule=deterministic adjacent-sea sidebands\n\n');

fprintf(fid,'[FRACTIONAL-DOMAIN RESULTS]\n');
fprintf(fid,'frac_metric=Eq31_total_energy_normalized\n');
fprintf(fid,'zero_lag_exclusion_used=0\n');
fprintf(fid,'p_grid_min=%.6f\n',min(p_grid));
fprintf(fid,'p_grid_max=%.6f\n',max(p_grid));
fprintf(fid,'p_grid_step=%.6f\n',p_grid(2)-p_grid(1));
fprintf(fid,'target_frac_peak_median=%.9g\n',target_frac_median);
fprintf(fid,'background_frac_peak_median=%.9g\n',bg_frac_median);
fprintf(fid,'target_to_background_frac_peak_ratio=%.9g\n',frac_TB_ratio);
fprintf(fid,'target_frac_prominence_median=%.9g\n',target_frac_prom_median);
fprintf(fid,'background_frac_prominence_median=%.9g\n',bg_frac_prom_median);
fprintf(fid,'target_to_background_frac_prominence_ratio=%.9g\n',frac_prom_TB_ratio);
fprintf(fid,'target_frft_peak_median=%.9g\n',target_frft_median);
fprintf(fid,'background_frft_peak_median=%.9g\n',bg_frft_median);
fprintf(fid,'target_to_background_frft_peak_ratio=%.9g\n',frft_TB_ratio);
fprintf(fid,'target_best_frac_order_IQR=%.9g\n',target_p_iqr);
fprintf(fid,'background_best_frac_order_IQR=%.9g\n',bg_p_iqr);
fprintf(fid,'target_adjacent_best_order_step_median=%.9g\n',target_step_median);
fprintf(fid,'background_adjacent_best_order_step_median=%.9g\n\n',bg_step_median);

fprintf(fid,'[INTERPRETATION BOUNDARY]\n');
fprintf(fid,['This R0 uses the corrected Xu Eq.(31) total FrAc-energy objective. ' ...
    'A Motion_Defocusing_Ship label does not by itself establish a ' ...
    'Wang/Xu-type 3-D-swing MC-LFM generating regime.\n']);
fprintf(fid,['Evidence supporting compatibility would require target-specific ' ...
    'fractional-domain structure that is stronger and/or more spatially ' ...
    'organized than the deterministic adjacent-sea controls.\n']);
fprintf(fid,['If that separation is not present, stop before any real-data branch ' ...
    'audit. Do not tune G0/N3/Proposed parameters on this sample.\n\n']);

fprintf(fid,'[UPLOAD REQUEST]\n');
fprintf(fid,'Return only:\n');
fprintf(fid,'1) EXP02_FAIR_R0_FEEDBACK_BUNDLE.txt\n');
fprintf(fid,'2) 02_frac_score_maps.png\n');
fprintf(fid,'3) 03_best_order_vs_range.png\n');
fprintf(fid,'4) 04_target_background_summary.png\n');

fprintf('\n============================================================\n');
fprintf('EXP02-FAIR-R0 complete.\n');
fprintf('Feedback bundle: %s\n',txt_path);
fprintf('============================================================\n');

%% Local helpers
function idx = even_subsample(pool,max_n)
pool = pool(:).';
if numel(pool) <= max_n
    idx = pool;
    return;
end
q = round(linspace(1,numel(pool),max_n));
q = unique(max(1,min(numel(pool),q)),'stable');
idx = pool(q);
end

function r = compact_metrics(a,col,group_name,energy)
r = struct();
r.group = string(group_name);
r.range_column = col;
r.line_energy = energy;
r.best_frac_order = a.best_frac_order;
r.frac_peak = a.frac_peak;
r.frac_peak_to_median = a.frac_peak_to_median;
r.best_frft_order = a.best_frft_order;
r.frft_peak = a.frft_peak;
r.frft_peak_to_median = a.frft_peak_to_median;
r.best_entropy_order = a.best_entropy_order;
r.entropy_min = a.entropy_min;
end

function q = local_iqr(x)
x = sort(x(:));
if isempty(x)
    q = NaN;
    return;
end
q25 = local_percentile(x,25);
q75 = local_percentile(x,75);
q = q75-q25;
end

function v = local_percentile(x,p)
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
