function cfg = config_exp02_r0()
%CONFIG_EXP02_R0
% EXP02-R0A — OpenSARShip complex-chip reader / interface gate.
%
% This stage does NOT run G0, Neighbor-3, Proposed, or any branch taxonomy.
% It only verifies that the selected OpenSARShip SLC chip can be read as a
% physically meaningful complex focused SAR chip and mapped to g(:,n).

cfg.experiment_id = "EXP02_R0A_OPENSARSHIP_COMPLEX_INTERFACE";
cfg.experiment_name = "OpenSARShip_Complex_Chip_Interface_Gate";

%% Local data
cfg.scene_dir = 'E:\OpenSARShip_raw\pilot\scene01';
cfg.patch_rel = fullfile('Patch','Cargo_x19112_y4564.tif');
cfg.patch_cal_rel = fullfile('Patch_Cal','Cargo_x19112_y4564.tif');
cfg.ship_xml_rel = 'Ship.xml';
cfg.scene_xml_rel = 'Metedata.xml';

%% Primary / secondary polarization
cfg.primary_pol = "VV";
cfg.secondary_pol = "VH";

%% Natural line selection for diagnostic only
% Same non-branch-outcome rule used in the controlled SAR audit:
% fixed-range complex azimuth lines whose total energy exceeds the mean.
cfg.line_selection_rule = "energy_gt_mean";

%% Numerical guards
cfg.require_single = true;
cfg.require_nbands_slc = 4;
cfg.require_nbands_cal = 2;
cfg.min_nonzero_variance = 1e-8;
cfg.min_cal_power_correlation = 0.98;

%% Output
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
research_root = fileparts(fileparts(this_dir));

cfg.output_dir = fullfile(research_root,'results','exp02_real_sar_branch_audit','r0a_interface_gate');
cfg.feedback_name = 'EXP02_R0A_FEEDBACK_BUNDLE.txt';
cfg.mat_name = 'exp02_r0a_outputs.mat';
cfg.fig_complex_name = '01_complex_chip_sanity.png';
cfg.fig_energy_name = '02_target_line_energy.png';

end
