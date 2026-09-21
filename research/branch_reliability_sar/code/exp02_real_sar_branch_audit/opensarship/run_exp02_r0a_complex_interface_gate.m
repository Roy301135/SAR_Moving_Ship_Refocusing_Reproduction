function run_exp02_r0a_complex_interface_gate()
%RUN_EXP02_R0A_COMPLEX_INTERFACE_GATE
%
% EXP02-R0A — OpenSARShip complex-chip interface gate.
%
% Purpose:
%   1) validate OpenSARShip HxWx4 single SLC layout;
%   2) reconstruct complex VH/VV;
%   3) verify filename <-> Ship.xml association;
%   4) verify chip geometry and calibrated-power consistency;
%   5) freeze g(:,n)=S(:,n): row=azimuth, column=range.
%
% This stage intentionally DOES NOT run:
%   - MC-LFM parameter search
%   - G0 / Neighbor-3
%   - branch taxonomy
%   - Proposed scheduler

clc;

%% Paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
research_root = fileparts(code_dir);
func_dir = fullfile(research_root,'functions','opensarship');
addpath(this_dir);
addpath(func_dir);

cfg = config_exp02_r0();
if ~exist(cfg.output_dir,'dir'), mkdir(cfg.output_dir); end

slc_path = fullfile(cfg.scene_dir,cfg.patch_rel);
cal_path = fullfile(cfg.scene_dir,cfg.patch_cal_rel);
ship_xml = fullfile(cfg.scene_dir,cfg.ship_xml_rel);
scene_xml = fullfile(cfg.scene_dir,cfg.scene_xml_rel);

fprintf('============================================================\n');
fprintf('EXP02-R0A OpenSARShip Complex Interface Gate\n');
fprintf('============================================================\n');

%% Read data
S = opensarship_read_slc_chip(slc_path);
C = opensarship_read_cal_chip(cal_path);
ship = opensarship_find_ship_record(ship_xml,S.center_x,S.center_y);
scene = opensarship_read_scene_metadata(scene_xml);

assert(S.height==C.height && S.width==C.width, ...
    'SLC / calibrated chip dimensions disagree.');

%% Geometry guard from Ship.xml bounding box
ulx = ship.SAR.UpperLeft_x;
uly = ship.SAR.UpperLeft_y;
lrx = ship.SAR.LowerRight_x;
lry = ship.SAR.LowerRight_y;

expected_w = abs(ulx-lrx)+1;
expected_h = abs(uly-lry)+1;

if expected_h ~= S.height || expected_w ~= S.width
    error('EXP02_R0A:ChipGeometryMismatch', ...
        ['Chip size mismatch: TIFF=%dx%d, Ship.xml bounding box implies %dx%d. ' ...
         'Axis convention must be audited before proceeding.'], ...
         S.height,S.width,expected_h,expected_w);
end

%% Calibration sanity: only correlation, not equality
pow_vh = abs(double(S.VH)).^2;
pow_vv = abs(double(S.VV)).^2;
cal_vh = double(C.VH);
cal_vv = double(C.VV);

rho_vh = corr(pow_vh(:),cal_vh(:),'Rows','complete');
rho_vv = corr(pow_vv(:),cal_vv(:),'Rows','complete');

if rho_vh < cfg.min_cal_power_correlation || rho_vv < cfg.min_cal_power_correlation
    error('EXP02_R0A:CalibrationConsistency', ...
        'Power-vs-calibrated correlation is unexpectedly low: VH=%.6f VV=%.6f.', ...
        rho_vh,rho_vv);
end

%% Primary/secondary complex chips
if cfg.primary_pol=="VV"
    P = S.VV;
    Q = S.VH;
else
    P = S.VH;
    Q = S.VV;
end

%% Natural line-energy diagnostic
% Rows = azimuth, columns = range -> fixed-range line is P(:,n).
line_energy = sum(abs(double(P)).^2,1);
mean_line_energy = mean(line_energy);

switch cfg.line_selection_rule
    case "energy_gt_mean"
        selected = line_energy > mean_line_energy;
    otherwise
        error('Unknown line-selection rule.');
end

selected_idx = find(selected);

%% Complex-information diagnostics
diag = struct();
diag.primary_pol = cfg.primary_pol;
diag.secondary_pol = cfg.secondary_pol;
diag.slc_height = S.height;
diag.slc_width = S.width;
diag.n_selected_lines = numel(selected_idx);
diag.selected_fraction = mean(selected);
diag.mean_line_energy = mean_line_energy;
diag.primary_real_var = var(real(double(P(:))));
diag.primary_imag_var = var(imag(double(P(:))));
diag.secondary_real_var = var(real(double(Q(:))));
diag.secondary_imag_var = var(imag(double(Q(:))));
diag.cal_power_corr_vh = rho_vh;
diag.cal_power_corr_vv = rho_vv;

%% Figures
fig1 = figure('Color','w','Name','EXP02-R0A complex chip sanity');
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');

nexttile;
imagesc(20*log10(abs(S.VV)+eps)); axis image; colorbar;
title('VV magnitude (dB)'); xlabel('range x'); ylabel('azimuth y');

nexttile;
imagesc(angle(S.VV)); axis image; colorbar;
title('VV phase (rad)'); xlabel('range x'); ylabel('azimuth y');

nexttile;
imagesc(20*log10(abs(S.VH)+eps)); axis image; colorbar;
title('VH magnitude (dB)'); xlabel('range x'); ylabel('azimuth y');

nexttile;
imagesc(angle(S.VH)); axis image; colorbar;
title('VH phase (rad)'); xlabel('range x'); ylabel('azimuth y');

exportgraphics(fig1,fullfile(cfg.output_dir,cfg.fig_complex_name),'Resolution',180);

fig2 = figure('Color','w','Name','EXP02-R0A target-line energy');
x = 1:S.width;
plot(x,line_energy/mean_line_energy,'LineWidth',1.3); hold on;
yline(1,'k--','mean');
scatter(selected_idx,line_energy(selected_idx)/mean_line_energy,24,'filled');
grid on;
xlabel('Range-column index n');
ylabel('line energy / mean');
title(sprintf('%s natural fixed-range azimuth-line selection | %d/%d', ...
    cfg.primary_pol,numel(selected_idx),S.width));
exportgraphics(fig2,fullfile(cfg.output_dir,cfg.fig_energy_name),'Resolution',180);

%% Save local MAT
save(fullfile(cfg.output_dir,cfg.mat_name), ...
    'cfg','S','C','ship','scene','diag','line_energy','selected','selected_idx');

%% Feedback bundle
fb = fullfile(cfg.output_dir,cfg.feedback_name);
fid = fopen(fb,'w');
if fid<0, error('Cannot open feedback bundle.'); end
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP02-R0A / OPENSARSHIP COMPLEX-CHIP INTERFACE GATE\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'Branch algorithms: NOT RUN\n');
fprintf(fid,'Proposed scheduler: NOT RUN\n');
fprintf(fid,'Science interpretation: DATA / INTERFACE ONLY\n\n');

fprintf(fid,'[DATA]\n');
fprintf(fid,'scene_dir=%s\n',cfg.scene_dir);
fprintf(fid,'chip=%s\n',cfg.patch_rel);
fprintf(fid,'chip_center_x=%d\n',S.center_x);
fprintf(fid,'chip_center_y=%d\n',S.center_y);
fprintf(fid,'slc_size=%dx%dx4\n',S.height,S.width);
fprintf(fid,'slc_class=%s\n',class(S.raw));
fprintf(fid,'axis_row=azimuth_y\n');
fprintf(fid,'axis_column=range_x\n');
fprintf(fid,'processing_object=g(:,n)=S(:,n)\n\n');

fprintf(fid,'[BAND SCHEMA]\n');
fprintf(fid,'band1=real(VH)\n');
fprintf(fid,'band2=imag(VH)\n');
fprintf(fid,'band3=real(VV)\n');
fprintf(fid,'band4=imag(VV)\n');
fprintf(fid,'primary_pol=%s\n',cfg.primary_pol);
fprintf(fid,'secondary_pol=%s\n\n',cfg.secondary_pol);

fprintf(fid,'[COMPLEX INFORMATION]\n');
fprintf(fid,'primary_real_variance=%.15g\n',diag.primary_real_var);
fprintf(fid,'primary_imag_variance=%.15g\n',diag.primary_imag_var);
fprintf(fid,'secondary_real_variance=%.15g\n',diag.secondary_real_var);
fprintf(fid,'secondary_imag_variance=%.15g\n\n',diag.secondary_imag_var);

fprintf(fid,'[SHIP.XML MATCH]\n');
fprintf(fid,'center_x=%g\n',ship.SAR.Center_x);
fprintf(fid,'center_y=%g\n',ship.SAR.Center_y);
fprintf(fid,'manual_length_m=%g\n',ship.SAR.Manual_Length);
fprintf(fid,'incidence_deg=%g\n',ship.SAR.Incidence);
if isfield(ship.AIS,'Sog'), fprintf(fid,'AIS_Sog_raw=%g\n',ship.AIS.Sog); end
if isfield(ship.AIS,'Rot'), fprintf(fid,'AIS_Rot_raw=%g\n',ship.AIS.Rot); end
if isfield(ship.AIS,'Length'), fprintf(fid,'AIS_length_m=%g\n',ship.AIS.Length); end
if isfield(ship.Match,'Length_error_rate')
    fprintf(fid,'length_error_rate=%g\n',ship.Match.Length_error_rate);
end
fprintf(fid,'bbox_width_px=%d\n',expected_w);
fprintf(fid,'bbox_height_px=%d\n\n',expected_h);

fprintf(fid,'[SCENE METADATA]\n');
print_field(fid,scene,'PRODUCT_TYPE');
print_field(fid,scene,'MISSION');
print_field(fid,scene,'ACQUISITION_MODE');
print_field(fid,scene,'range_spacing');
print_field(fid,scene,'azimuth_spacing');
print_field(fid,scene,'pulse_repetition_frequency');
print_field(fid,scene,'radar_frequency');
print_field(fid,scene,'line_time_interval');
fprintf(fid,'has_doppler_centroid_coefficients=%d\n\n', ...
    scene.has_doppler_centroid_coefficients);

fprintf(fid,'[CALIBRATION SANITY]\n');
fprintf(fid,'corr_absVH2_vs_calVH=%.15g\n',rho_vh);
fprintf(fid,'corr_absVV2_vs_calVV=%.15g\n\n',rho_vv);

fprintf(fid,'[NATURAL LINE SELECTION — DIAGNOSTIC ONLY]\n');
fprintf(fid,'rule=%s\n',cfg.line_selection_rule);
fprintf(fid,'n_range_columns=%d\n',S.width);
fprintf(fid,'n_selected=%d\n',numel(selected_idx));
fprintf(fid,'selected_fraction=%.15g\n',mean(selected));
fprintf(fid,'selected_indices=');
fprintf(fid,'%d ',selected_idx);
fprintf(fid,'\n\n');

fprintf(fid,'[INTERFACE VERDICT]\n');
fprintf(fid,'status=PASS_IF_SCRIPT_COMPLETES\n');
fprintf(fid,['meaning=OpenSARShip original SLC chip preserves usable complex VH/VV, ' ...
    'filename-to-Ship.xml association is consistent, and g(:,n) is well-defined.\n']);
fprintf(fid,['next=EXP02-R0B real complex-line local signal-model validity audit; ' ...
    'do not infer 3-D ship-motion ground truth from AIS metadata.\n']);

fprintf('\nEXP02-R0A completed.\n');
fprintf('Feedback: %s\n',fb);

end

function print_field(fid,s,name)
if ~isfield(s,name), return; end
v=s.(name);
if isnumeric(v)
    fprintf(fid,'%s=%.15g\n',name,v);
else
    fprintf(fid,'%s=%s\n',name,string(v));
end
end
