function run_exp01_sar_branch_translation()
%RUN_EXP01_SAR_BRANCH_TRANSLATION EXP01 Stage-A SAR physical-chain build.
%
% Current scope:
%   1) sparse ship scatterer scene;
%   2) yaw motion and exact range history;
%   3) ideal range-compressed complex SAR data;
%   4) stationary-reference backprojection;
%   5) static/moving image comparison;
%   6) local quadratic residual-phase audit.
%
% Explicitly NOT included yet:
%   - G0 / Proposed / Always-N3 / Oracle branch processing;
%   - noise / sea clutter / SNR sweeps;
%   - policy retuning;
%   - image-level claim testing.
%
% The purpose of this run is to verify the SAR physics foundation before
% attaching the already-frozen search/recovery chain.

clc;

%% Resolve repository-local paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
research_root = fileparts(code_dir);
functions_dir = fullfile(research_root, 'functions');
addpath(this_dir);
addpath(functions_dir);

cfg = config_exp01(research_root);
if ~exist(cfg.results_dir, 'dir')
    mkdir(cfg.results_dir);
end

fprintf('============================================================\n');
fprintf('EXP01 SAR Branch Translation - Stage A\n');
fprintf('SAR physical foundation only; branch policy is NOT run yet.\n');
fprintf('============================================================\n');
fprintf('fc       = %.3f GHz\n', cfg.fc/1e9);
fprintf('lambda   = %.4f m\n', cfg.lambda);
fprintf('B        = %.1f MHz\n', cfg.bandwidth/1e6);
fprintf('PRF      = %.1f Hz\n', cfg.prf);
fprintf('H        = %.1f m\n', cfg.platform_height);
fprintf('v_sar    = %.1f m/s\n', cfg.platform_velocity);
fprintf('Na       = %d\n', cfg.Na);
fprintf('Tap      = %.4f s\n', cfg.synthetic_aperture_time);
fprintf('rho_r    = %.4f m\n', cfg.range_resolution_m);
fprintf('Yaw amp  = %.2f deg\n', cfg.motion.yaw_amplitude_rad*180/pi);
fprintf('Yaw T    = %.2f s\n', cfg.motion.yaw_period_s);
fprintf('Results  = %s\n\n', cfg.results_dir);

%% 1. Build static and moving ship trajectories
tracks_static = sar_build_ship_tracks(cfg, 'static');
tracks_moving = sar_build_ship_tracks(cfg, 'moving');

ranges_static = sar_compute_slant_ranges(cfg, tracks_static);
ranges_moving = sar_compute_slant_ranges(cfg, tracks_moving);

%% 2. Generate ideal range-compressed complex data
fprintf('[1/4] Generating range-compressed static echo...\n');
echo_static = sar_generate_range_compressed_echo(cfg, ranges_static);

fprintf('[2/4] Generating range-compressed moving echo...\n');
echo_moving = sar_generate_range_compressed_echo(cfg, ranges_moving);

%% 3. Backprojection with the SAME stationary-reference imager
fprintf('[3/4] Backprojecting static scene...\n');
t_bp = tic;
img_static = sar_backprojection_static_reference(cfg, echo_static);
runtime_bp_static_s = toc(t_bp);

fprintf('[4/4] Backprojecting moving scene...\n');
t_bp = tic;
img_moving = sar_backprojection_static_reference(cfg, echo_moving);
runtime_bp_moving_s = toc(t_bp);

%% 4. Audit physical SAR -> local quadratic residual-phase consistency
audit = sar_model_consistency_audit(cfg, ranges_static, ranges_moving);

strong_row = audit.table(audit.table.scatterer_idx == cfg.scatterers.strong_idx, :);
weak_row = audit.table(audit.table.scatterer_idx == cfg.scatterers.weak_idx, :);

%% 5. Geometry consistency of designated same-range-line pair at eta=0
center_idx = (cfg.Na + 1)/2;
strong_idx = cfg.scatterers.strong_idx;
weak_idx = cfg.scatterers.weak_idx;
center_ground_range_delta_m = ...
    tracks_static.y(strong_idx, center_idx) - tracks_static.y(weak_idx, center_idx);
center_slant_range_delta_m = ...
    ranges_static(strong_idx, center_idx) - ranges_static(weak_idx, center_idx);

%% 6. Save tables / MAT / text summary
writetable(audit.table, fullfile(cfg.results_dir, 'model_consistency_audit.csv'));

if cfg.save_mat
    save(fullfile(cfg.results_dir, 'exp01_stageA_outputs.mat'), ...
        'cfg', 'tracks_static', 'tracks_moving', ...
        'ranges_static', 'ranges_moving', ...
        'echo_static', 'echo_moving', ...
        'img_static', 'img_moving', 'audit', ...
        'runtime_bp_static_s', 'runtime_bp_moving_s', '-v7.3');
end

summary_path = fullfile(cfg.results_dir, 'EXP01_STAGEA_SUMMARY.txt');
fid = fopen(summary_path, 'w');
cleanup_obj = onCleanup(@() fclose_if_open(fid)); %#ok<NASGU>

fprintf(fid, 'EXP01 SAR Branch Translation - Stage A Summary\n');
fprintf(fid, '============================================================\n');
fprintf(fid, 'Scope: SAR physical foundation only; no branch algorithm yet.\n\n');
fprintf(fid, 'SYSTEM\n');
fprintf(fid, 'fc_GHz=%.9g\n', cfg.fc/1e9);
fprintf(fid, 'lambda_m=%.12g\n', cfg.lambda);
fprintf(fid, 'bandwidth_MHz=%.9g\n', cfg.bandwidth/1e6);
fprintf(fid, 'PRF_Hz=%.9g\n', cfg.prf);
fprintf(fid, 'platform_height_m=%.9g\n', cfg.platform_height);
fprintf(fid, 'platform_velocity_mps=%.9g\n', cfg.platform_velocity);
fprintf(fid, 'Na=%d\n', cfg.Na);
fprintf(fid, 'synthetic_aperture_time_s=%.12g\n', cfg.synthetic_aperture_time);
fprintf(fid, 'range_resolution_m=%.12g\n\n', cfg.range_resolution_m);

fprintf(fid, 'MOTION\n');
fprintf(fid, 'motion_type=%s\n', cfg.motion.type);
fprintf(fid, 'yaw_amplitude_deg=%.12g\n', cfg.motion.yaw_amplitude_rad*180/pi);
fprintf(fid, 'yaw_period_s=%.12g\n', cfg.motion.yaw_period_s);
fprintf(fid, 'yaw_center_deg=%.12g\n\n', cfg.motion.theta_center_rad*180/pi);

fprintf(fid, 'DESIGNATED STRONG/WEAK PAIR\n');
fprintf(fid, 'strong_idx=%d\n', strong_idx);
fprintf(fid, 'weak_idx=%d\n', weak_idx);
fprintf(fid, 'amplitude_ratio_weak_over_strong=%.12g\n', ...
    cfg.scatterers.amplitude(weak_idx)/cfg.scatterers.amplitude(strong_idx));
fprintf(fid, 'center_ground_range_delta_m=%.12g\n', center_ground_range_delta_m);
fprintf(fid, 'center_slant_range_delta_m=%.12g\n\n', center_slant_range_delta_m);

fprintf(fid, 'MODEL CONSISTENCY AUDIT\n');
fprintf(fid, 'Strong quadratic_fit_nrmse=%.12g\n', strong_row.quadratic_fit_nrmse);
fprintf(fid, 'Strong quadratic_fit_r2=%.12g\n', strong_row.quadratic_fit_r2);
fprintf(fid, 'Strong max_abs_fit_residual_rad=%.12g\n', strong_row.max_abs_fit_residual_rad);
fprintf(fid, 'Strong phase_span_rad=%.12g\n', strong_row.phase_span_rad);
fprintf(fid, 'Weak quadratic_fit_nrmse=%.12g\n', weak_row.quadratic_fit_nrmse);
fprintf(fid, 'Weak quadratic_fit_r2=%.12g\n', weak_row.quadratic_fit_r2);
fprintf(fid, 'Weak max_abs_fit_residual_rad=%.12g\n', weak_row.max_abs_fit_residual_rad);
fprintf(fid, 'Weak phase_span_rad=%.12g\n\n', weak_row.phase_span_rad);

fprintf(fid, 'RUNTIME\n');
fprintf(fid, 'BP_static_s=%.12g\n', runtime_bp_static_s);
fprintf(fid, 'BP_moving_s=%.12g\n\n', runtime_bp_moving_s);

fprintf(fid, 'STAGE-A REVIEW RULE\n');
fprintf(fid, ['Do NOT attach Proposed yet. First inspect: (1) static BP focusing, ', ...
    '(2) naturally generated moving-target defocus, (3) exact-vs-quadratic ', ...
    'phase fit for the designated strong/weak pair. No automatic model-fit ', ...
    'threshold is frozen in Stage A.\n']);

fclose(fid);
fid = -1;

%% 7. Figures
% Figure 1: scene geometry at aperture center
fig1 = figure('Name','EXP01 Scene Geometry','Color','w');
hold on;
body = cfg.scatterers.body_xy_m;
scatter(body(:,1), body(:,2), 70, cfg.scatterers.amplitude, 'filled');
for p = 1:size(body,1)
    text(body(p,1)+0.8, body(p,2)+0.4, sprintf('%d',p), 'FontSize', 9);
end
plot(body(strong_idx,1), body(strong_idx,2), 'ks', 'MarkerSize', 12, 'LineWidth', 1.5);
plot(body(weak_idx,1), body(weak_idx,2), 'ko', 'MarkerSize', 12, 'LineWidth', 1.5);
xlabel('Ship-body x_b (m)'); ylabel('Ship-body y_b (m)');
title(sprintf('Sparse ship skeleton | strong P%d, weak P%d | A_w/A_s=%.2f', ...
    strong_idx, weak_idx, cfg.scatterers.amplitude(weak_idx)/cfg.scatterers.amplitude(strong_idx)));
axis equal; grid on; colorbar;
if cfg.save_png
    exportgraphics(fig1, fullfile(cfg.results_dir, '01_scene_geometry.png'), 'Resolution', 180);
end

% Figure 2: range-compressed echo magnitude
fig2 = figure('Name','EXP01 Range-Compressed Echo','Color','w');
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
nexttile;
imagesc(cfg.eta, cfg.range_offset_m, sar_db(echo_static, -45)); axis xy;
xlabel('Slow time \eta (s)'); ylabel('Slant-range offset (m)');
title('Static: range-compressed magnitude (dB)'); colorbar; caxis([-45 0]);
nexttile;
imagesc(cfg.eta, cfg.range_offset_m, sar_db(echo_moving, -45)); axis xy;
xlabel('Slow time \eta (s)'); ylabel('Slant-range offset (m)');
title('Yawing: range-compressed magnitude (dB)'); colorbar; caxis([-45 0]);
if cfg.save_png
    exportgraphics(fig2, fullfile(cfg.results_dir, '02_range_compressed_echo.png'), 'Resolution', 180);
end

% Figure 3: BP images. Use a common absolute normalization so intensity
% differences are not hidden by separate per-panel normalization.
common_peak = max([abs(img_static(:)); abs(img_moving(:))]);
static_db = 20*log10(max(abs(img_static)/common_peak, 10^(-cfg.display.dynamic_range_db/20)));
moving_db = 20*log10(max(abs(img_moving)/common_peak, 10^(-cfg.display.dynamic_range_db/20)));

fig3 = figure('Name','EXP01 Static vs Moving BP','Color','w');
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
nexttile;
imagesc(cfg.image.x_axis_m, cfg.image.y_axis_m-cfg.ship_center_y, static_db); axis xy equal tight;
xlabel('Azimuth x (m)'); ylabel('Ground-range offset (m)');
title('Static reference BP'); colorbar; caxis([-cfg.display.dynamic_range_db 0]);
hold on;
scatter(tracks_static.x(:,center_idx), tracks_static.y(:,center_idx)-cfg.ship_center_y, ...
    25, 'w', 'o', 'LineWidth', 0.8);
nexttile;
imagesc(cfg.image.x_axis_m, cfg.image.y_axis_m-cfg.ship_center_y, moving_db); axis xy equal tight;
xlabel('Azimuth x (m)'); ylabel('Ground-range offset (m)');
title('Yawing target under stationary-reference BP'); colorbar; caxis([-cfg.display.dynamic_range_db 0]);
hold on;
scatter(tracks_static.x(:,center_idx), tracks_static.y(:,center_idx)-cfg.ship_center_y, ...
    25, 'w', 'o', 'LineWidth', 0.8);
if cfg.save_png
    exportgraphics(fig3, fullfile(cfg.results_dir, '03_static_vs_moving_bp.png'), 'Resolution', 180);
end

% Figure 4: exact motion-induced residual phase vs quadratic fit for strong/weak
fig4 = figure('Name','EXP01 Model Consistency','Color','w');
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
nexttile;
plot(cfg.eta, audit.true_phase(strong_idx,:), 'LineWidth', 1.2); hold on;
plot(cfg.eta, audit.fit_phase(strong_idx,:), '--', 'LineWidth', 1.2);
grid on; xlabel('Slow time \eta (s)'); ylabel('\Delta\phi (rad)');
title(sprintf('Strong P%d: quadratic NRMSE=%.4g, R^2=%.6f', ...
    strong_idx, strong_row.quadratic_fit_nrmse, strong_row.quadratic_fit_r2));
legend('Exact from range history','Quadratic fit','Location','best');
nexttile;
plot(cfg.eta, audit.true_phase(weak_idx,:), 'LineWidth', 1.2); hold on;
plot(cfg.eta, audit.fit_phase(weak_idx,:), '--', 'LineWidth', 1.2);
grid on; xlabel('Slow time \eta (s)'); ylabel('\Delta\phi (rad)');
title(sprintf('Weak P%d: quadratic NRMSE=%.4g, R^2=%.6f', ...
    weak_idx, weak_row.quadratic_fit_nrmse, weak_row.quadratic_fit_r2));
legend('Exact from range history','Quadratic fit','Location','best');
if cfg.save_png
    exportgraphics(fig4, fullfile(cfg.results_dir, '04_model_consistency.png'), 'Resolution', 180);
end

%% 8. Console summary
fprintf('\n================ STAGE-A SUMMARY ================\n');
fprintf('Strong/weak center ground-range mismatch = %.6g m\n', center_ground_range_delta_m);
fprintf('Strong/weak center slant-range mismatch  = %.6g m\n', center_slant_range_delta_m);
fprintf('Strong phase quadratic NRMSE / R2 = %.6g / %.9f\n', ...
    strong_row.quadratic_fit_nrmse, strong_row.quadratic_fit_r2);
fprintf('Weak   phase quadratic NRMSE / R2 = %.6g / %.9f\n', ...
    weak_row.quadratic_fit_nrmse, weak_row.quadratic_fit_r2);
fprintf('BP runtime static/moving = %.3f / %.3f s\n', ...
    runtime_bp_static_s, runtime_bp_moving_s);
fprintf('Saved to: %s\n', cfg.results_dir);
fprintf('\nNEXT DECISION GATE:\n');
fprintf(['Return 03_static_vs_moving_bp.png, 04_model_consistency.png, and ', ...
    'EXP01_STAGEA_SUMMARY.txt for audit.\n']);
fprintf('Do not integrate Proposed before this SAR-physics audit passes.\n');
fprintf('=================================================\n');

end

function fclose_if_open(fid)
if isnumeric(fid) && isscalar(fid) && fid > 0
    try
        fclose(fid);
    catch
    end
end
end
