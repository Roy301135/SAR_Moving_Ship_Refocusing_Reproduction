function run_exp01_stageB5_effective_geometry_audit()
%RUN_EXP01_STAGEB5_EFFECTIVE_GEOMETRY_AUDIT
%
% EXP01 Stage-B5
% Frozen 3-D Scene ERV / IPP Quasi-Stationarity Audit
%
% Research question:
%   In the already accepted Stage-B4 3-D rigid-body scene, how much does
%   radar-effective observation geometry vary during the ~1.4 s aperture?
%
% This script performs GEOMETRY RE-ANALYSIS ONLY. It does not:
%   - change any Stage-B4 motion parameter
%   - change aperture length
%   - change target-line selection
%   - run G0/N3 again
%   - run Proposed
%   - sweep any parameter
%
% Scientific interpretation is intentionally NOT thresholded automatically.
% The script reports descriptive ERV / LOS / IPP metrics together with the
% already frozen Stage-B4 quadratic-fit diagnostics.  Final interpretation
% is performed after reviewing the feedback bundle and figures.

clc;

%% Paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
research_root = fileparts(code_dir);
functions_dir = fullfile(research_root,'functions');
addpath(this_dir);
addpath(functions_dir);

cfg = config_exp01_stageB5(research_root);
if ~exist(cfg.results_dir,'dir')
    error('EXP01_STAGEB5:MissingResultsDir', ...
        'Results directory does not exist: %s',cfg.results_dir);
end

fprintf('============================================================\n');
fprintf('EXP01 Stage-B5 — Frozen 3-D ERV / IPP Audit\n');
fprintf('Re-analysis only | no retuning | no sweep | no Proposed\n');
fprintf('============================================================\n\n');

%% 1) Provenance: require accepted Stage-A + Stage-B4 text records
if ~exist(cfg.stageA_summary,'file')
    error('EXP01_STAGEB5:MissingStageA', ...
        'Missing Stage-A summary: %s',cfg.stageA_summary);
end
if ~exist(cfg.stageB4_feedback,'file')
    error('EXP01_STAGEB5:MissingStageB4', ...
        'Missing accepted Stage-B4 feedback: %s',cfg.stageB4_feedback);
end

stageA_text = fileread(cfg.stageA_summary);
stageB4_text = fileread(cfg.stageB4_feedback);

% Frozen system values come from the accepted Stage-A record.
prf = get_numeric_key(stageA_text,'PRF_Hz');
H = get_numeric_key(stageA_text,'platform_height_m');
V = get_numeric_key(stageA_text,'platform_velocity_mps');
Na = round(get_numeric_key(stageA_text,'Na'));
Tap_record = get_numeric_key(stageA_text,'synthetic_aperture_time_s');

% Verify the accepted Stage-B4 motion has not drifted.
assert_close(get_numeric_key(stageB4_text,'roll_x_amplitude_deg'), ...
    cfg.roll_amplitude_deg,cfg.provenance_abs_tol,'roll amplitude');
assert_close(get_numeric_key(stageB4_text,'roll_x_period_s'), ...
    cfg.roll_period_s,cfg.provenance_abs_tol,'roll period');
assert_close(get_numeric_key(stageB4_text,'roll_x_phase0_rad'), ...
    cfg.roll_phase0_rad,cfg.provenance_abs_tol,'roll phase');

assert_close(get_numeric_key(stageB4_text,'pitch_y_amplitude_deg'), ...
    cfg.pitch_amplitude_deg,cfg.provenance_abs_tol,'pitch amplitude');
assert_close(get_numeric_key(stageB4_text,'pitch_y_period_s'), ...
    cfg.pitch_period_s,cfg.provenance_abs_tol,'pitch period');
assert_close(get_numeric_key(stageB4_text,'pitch_y_phase0_rad'), ...
    cfg.pitch_phase0_rad,cfg.provenance_abs_tol,'pitch phase');

assert_close(get_numeric_key(stageB4_text,'yaw_z_amplitude_deg'), ...
    cfg.yaw_amplitude_deg,cfg.provenance_abs_tol,'yaw amplitude');
assert_close(get_numeric_key(stageB4_text,'yaw_z_period_s'), ...
    cfg.yaw_period_s,cfg.provenance_abs_tol,'yaw period');
assert_close(get_numeric_key(stageB4_text,'yaw_z_phase0_rad'), ...
    cfg.yaw_phase0_rad,cfg.provenance_abs_tol,'yaw phase');

% Existing model-fit evidence from accepted B4.
scatterer_quad_median = get_numeric_key(stageB4_text,'median_quadratic_fit_nrmse');
scatterer_quad_max = get_numeric_key(stageB4_text,'max_quadratic_fit_nrmse');
line_quad_median = get_numeric_key(stageB4_text,'median_dominant_phase_fit_nrmse');
line_quad_max = get_numeric_key(stageB4_text,'max_dominant_phase_fit_nrmse');

fprintf('Provenance gate: PASS\n');
fprintf('  Na=%d PRF=%.9g Hz H=%.9g m V=%.9g m/s\n',Na,prf,H,V);
fprintf('  Frozen B4 motion matches accepted feedback bundle.\n\n');

%% 2) Reconstruct ONLY the frozen B4 kinematics
% Stage-A/B4 broadside anchor: slant range = sqrt(2)*H, hence the
% scene-centroid ground range equals H. No translation was introduced in B4.
dt = 1/prf;
eta = ((0:Na-1) - (Na-1)/2) / prf;
Tap = eta(end)-eta(1);
assert(abs(Tap-Tap_record) < 1e-10, ...
    'Stage-A aperture-time provenance mismatch.');

platform_pos = [V*eta; zeros(1,Na); H*ones(1,Na)];
ship_centroid = [cfg.scene_center_x_m*ones(1,Na); ...
                 H*ones(1,Na); ...
                 cfg.scene_center_z_m*ones(1,Na)];

roll = deg2rad(cfg.roll_amplitude_deg) * ...
    sin(2*pi*eta/cfg.roll_period_s + cfg.roll_phase0_rad);
pitch = deg2rad(cfg.pitch_amplitude_deg) * ...
    sin(2*pi*eta/cfg.pitch_period_s + cfg.pitch_phase0_rad);
yaw = deg2rad(cfg.yaw_amplitude_deg) * ...
    sin(2*pi*eta/cfg.yaw_period_s + cfg.yaw_phase0_rad);

R = zeros(3,3,Na);
for k=1:Na
    R(:,:,k) = Rx(roll(k)) * Ry(pitch(k)) * Rz(yaw(k));
end

%% 3) ERV / IPP audit
Audit = sar_effective_observation_geometry( ...
    eta,platform_pos,ship_centroid,R,cfg);
M = Audit.metrics;

%% 4) Figures — minimal outputs only
fig1 = figure('Color','w','Name','EXP01 Stage-B5 ERV magnitude');
plot(eta,Audit.erv_magnitude_radps,'LineWidth',1.6); hold on;
plot(eta,Audit.ship_angular_speed_radps,'--','LineWidth',1.0);
plot(eta,Audit.sar_los_angular_speed_radps,':','LineWidth',1.2);
xline(0,'k:');
grid on;
xlabel('Slow time \eta (s)');
ylabel('Angular rate (rad/s)');
title('Frozen B4 effective observation rates');
legend('||\omega_{eff}||','||\omega_{ship}||','||\omega_{SAR}||', ...
    'Location','best');
exportgraphics(fig1,fullfile(cfg.results_dir,cfg.fig1_name),'Resolution',180);

fig2 = figure('Color','w','Name','EXP01 Stage-B5 angular drift');
plot(eta,rad2deg(Audit.ipp_normal_drift_rad),'LineWidth',1.6); hold on;
plot(eta,rad2deg(Audit.los_drift_rad),'--','LineWidth',1.2);
plot(eta,rad2deg(Audit.cross_range_drift_rad),':','LineWidth',1.2);
xline(0,'k:');
grid on;
xlabel('Slow time \eta (s)');
ylabel('Angular drift from aperture center (deg)');
title('Frozen B4 radar-effective observation geometry drift');
legend('IPP normal / ERV direction','LOS','cross-range direction', ...
    'Location','best');
exportgraphics(fig2,fullfile(cfg.results_dir,cfg.fig2_name),'Resolution',180);

%% 5) Save MAT for local provenance
save(fullfile(cfg.results_dir,cfg.mat_name), ...
    'cfg','Audit','M','eta','roll','pitch','yaw', ...
    'platform_pos','ship_centroid','R', ...
    'scatterer_quad_median','scatterer_quad_max', ...
    'line_quad_median','line_quad_max');

%% 6) Feedback bundle
feedback_path = fullfile(cfg.results_dir,cfg.feedback_name);
fid = fopen(feedback_path,'w');
if fid < 0
    error('EXP01_STAGEB5:FeedbackOpenFailed', ...
        'Cannot open feedback bundle: %s',feedback_path);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP01 / STAGE-B5 FROZEN 3-D SCENE ERV / IPP QUASI-STATIONARITY AUDIT\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'Scene retuning: NONE\n');
fprintf(fid,'Motion sweep: NONE\n');
fprintf(fid,'Aperture change: NONE\n');
fprintf(fid,'Branch algorithms: NOT RERUN\n');
fprintf(fid,'Proposed scheduler: NOT RUN\n\n');

fprintf(fid,'[RESEARCH QUESTION]\n');
fprintf(fid,['Within the accepted Stage-B4 ~1.4 s aperture, how much do the ' ...
    'review-defined ERV and IPP vary?\n\n']);

fprintf(fid,'[COORDINATE / DEFINITION CONVENTION]\n');
fprintf(fid,'world_x=azimuth/flight\n');
fprintf(fid,'world_y=ground-range\n');
fprintf(fid,'world_z=up\n');
fprintf(fid,'u_LOS=radar_to_ship_centroid\n');
fprintf(fid,'rotation_convention=%s\n',cfg.rotation_convention);
fprintf(fid,'omega_ship=vee(skew(Rdot*R^T)) in world frame\n');
fprintf(fid,'omega_SAR=u_LOS x du_LOS/dt\n');
fprintf(fid,'omega_eff=(omega_SAR+omega_ship) x u_LOS\n');
fprintf(fid,'u_CR=normalize(omega_eff x u_LOS)\n');
fprintf(fid,'n_IPP=normalize(u_LOS x u_CR)\n');
fprintf(fid,['note=n_IPP and normalized omega_eff are mathematically identical ' ...
    'under these definitions; equality is used as a numerical self-check.\n\n']);

fprintf(fid,'[SCENE]\n');
fprintf(fid,'Na=%d\n',Na);
fprintf(fid,'PRF_Hz=%.15g\n',prf);
fprintf(fid,'aperture_time_s=%.15g\n',Tap);
fprintf(fid,'platform_height_m=%.15g\n',H);
fprintf(fid,'platform_velocity_mps=%.15g\n',V);
fprintf(fid,'scene_center_ground_range_m=%.15g\n',H);
fprintf(fid,'roll_amplitude_deg=%.15g\n',cfg.roll_amplitude_deg);
fprintf(fid,'roll_period_s=%.15g\n',cfg.roll_period_s);
fprintf(fid,'roll_phase0_rad=%.15g\n',cfg.roll_phase0_rad);
fprintf(fid,'pitch_amplitude_deg=%.15g\n',cfg.pitch_amplitude_deg);
fprintf(fid,'pitch_period_s=%.15g\n',cfg.pitch_period_s);
fprintf(fid,'pitch_phase0_rad=%.15g\n',cfg.pitch_phase0_rad);
fprintf(fid,'yaw_amplitude_deg=%.15g\n',cfg.yaw_amplitude_deg);
fprintf(fid,'yaw_period_s=%.15g\n',cfg.yaw_period_s);
fprintf(fid,'yaw_phase0_rad=%.15g\n\n',cfg.yaw_phase0_rad);

fprintf(fid,'[ERV]\n');
fprintf(fid,'mean_magnitude_radps=%.15g\n',M.erv_mean_radps);
fprintf(fid,'min_magnitude_radps=%.15g\n',M.erv_min_radps);
fprintf(fid,'max_magnitude_radps=%.15g\n',M.erv_max_radps);
fprintf(fid,'center_magnitude_radps=%.15g\n',M.erv_center_radps);
fprintf(fid,'magnitude_CV=%.15g\n',M.erv_cv);
fprintf(fid,'max_relative_deviation_from_center=%.15g\n', ...
    M.erv_max_relative_deviation_from_center);
fprintf(fid,'max_direction_drift_deg=%.15g\n',M.erv_direction_max_drift_deg);
fprintf(fid,'rms_direction_drift_deg=%.15g\n\n',M.erv_direction_rms_drift_deg);

fprintf(fid,'[ANGULAR-RATE COMPONENTS]\n');
fprintf(fid,'mean_ship_angular_speed_radps=%.15g\n',M.mean_ship_angular_speed_radps);
fprintf(fid,'max_ship_angular_speed_radps=%.15g\n',M.max_ship_angular_speed_radps);
fprintf(fid,'mean_SAR_LOS_angular_speed_radps=%.15g\n', ...
    M.mean_sar_los_angular_speed_radps);
fprintf(fid,'max_SAR_LOS_angular_speed_radps=%.15g\n', ...
    M.max_sar_los_angular_speed_radps);
fprintf(fid,'mean_ship_to_SAR_speed_ratio=%.15g\n\n', ...
    M.mean_ship_to_sar_angular_speed_ratio);

fprintf(fid,'[LOS]\n');
fprintf(fid,'max_angular_drift_deg=%.15g\n',M.los_max_drift_deg);
fprintf(fid,'rms_angular_drift_deg=%.15g\n\n',M.los_rms_drift_deg);

fprintf(fid,'[IPP]\n');
fprintf(fid,'max_normal_drift_deg=%.15g\n',M.ipp_normal_max_drift_deg);
fprintf(fid,'rms_normal_drift_deg=%.15g\n',M.ipp_normal_rms_drift_deg);
fprintf(fid,'max_cross_range_direction_drift_deg=%.15g\n', ...
    M.cross_range_max_drift_deg);
fprintf(fid,'rms_cross_range_direction_drift_deg=%.15g\n\n', ...
    M.cross_range_rms_drift_deg);

fprintf(fid,'[EXISTING STAGE-B4 MODEL FIT]\n');
fprintf(fid,'scatterer_quadratic_NRMSE_median=%.15g\n',scatterer_quad_median);
fprintf(fid,'scatterer_quadratic_NRMSE_max=%.15g\n',scatterer_quad_max);
fprintf(fid,'selected_line_dominant_NRMSE_median=%.15g\n',line_quad_median);
fprintf(fid,'selected_line_dominant_NRMSE_max=%.15g\n\n',line_quad_max);

fprintf(fid,'[IMPLEMENTATION SELF-CHECKS]\n');
fprintf(fid,'max_rotation_orthogonality_error=%.15g\n', ...
    M.max_rotation_orthogonality_error);
fprintf(fid,'max_rotation_determinant_error=%.15g\n', ...
    M.max_rotation_determinant_error);
fprintf(fid,'max_LOS_kinematic_reconstruction_error=%.15g\n', ...
    M.max_los_kinematic_reconstruction_error);
fprintf(fid,'max_IPP_ERV_identity_error_deg=%.15g\n\n', ...
    M.max_ipp_erv_direction_identity_error_deg);

fprintf(fid,'[INTERPRETATION]\n');
fprintf(fid,'automatic_quasi_stationary_label=NOT_ASSIGNED\n');
fprintf(fid,['reason=No frozen literature-backed angular threshold was defined; ' ...
    'interpret ERV/IPP drift jointly with the already accepted quadratic-fit evidence.\n']);
fprintf(fid,['Outcome_A_candidate=small ERV/IPP drift + good quadratic fit -> ' ...
    'quasi-stationary explanation supported.\n']);
fprintf(fid,['Outcome_B_candidate=material ERV/IPP drift + good quadratic fit + ' ...
    'B4 D=0 -> branch vulnerability is not a necessary consequence of ' ...
    'dynamic observation geometry.\n']);
fprintf(fid,['Outcome_C_candidate=coordinate/self-check anomaly -> implementation ' ...
    'audit only; no scientific sweep.\n\n']);

fprintf(fid,'[DECISION RULE]\n');
fprintf(fid,['After human audit, controlled simulation is frozen for either ' ...
    'Outcome A or Outcome B.\n']);
fprintf(fid,['Only implementation/coordinate inconsistencies authorize code-level ' ...
    'repair; they do not authorize motion/scene sweeps.\n\n']);

fprintf(fid,'[UPLOAD REQUEST]\n');
fprintf(fid,['Return only: %s, %s, %s. Keep MAT locally unless an anomaly ' ...
    'requires it.\n'],cfg.feedback_name,cfg.fig1_name,cfg.fig2_name);

fprintf('\nStage-B5 completed.\n');
fprintf('Feedback: %s\n',feedback_path);
fprintf('Figures : %s ; %s\n',cfg.fig1_name,cfg.fig2_name);
fprintf('No automatic quasi-stationarity verdict was assigned.\n');

end

%% ========================================================================
function v = get_numeric_key(txt,key)
pat = ['(?m)^\s*' regexptranslate('escape',key) '\s*=\s*' ...
       '([-+0-9.eE]+)'];
tok = regexp(txt,pat,'tokens','once');
if isempty(tok)
    error('EXP01_STAGEB5:MissingKey', ...
        'Required provenance key "%s" was not found.',key);
end
v = str2double(tok{1});
if ~isfinite(v)
    error('EXP01_STAGEB5:InvalidKey', ...
        'Key "%s" is not finite.',key);
end
end

function assert_close(a,b,tol,label)
if abs(a-b) > tol
    error('EXP01_STAGEB5:ProvenanceDrift', ...
        '%s drifted: recorded=%.15g expected=%.15g.',label,a,b);
end
end

function R=Rx(a)
c=cos(a); s=sin(a);
R=[1 0 0; 0 c -s; 0 s c];
end

function R=Ry(a)
c=cos(a); s=sin(a);
R=[c 0 s; 0 1 0; -s 0 c];
end

function R=Rz(a)
c=cos(a); s=sin(a);
R=[c -s 0; s c 0; 0 0 1];
end
