function cfg = config_exp02_r0c()
%CONFIG_EXP02_R0C
% EXP02-R0C — Cross-ship processing-object reproducibility gate.
%
% Purpose:
%   Test whether the R0B interface signature is specific to one ship chip
%   or repeats across three PRESELECTED ships from the SAME OpenSARShip scene.
%
% No branch algorithms are used.
% The R0B LFM scanner is reused without changing its scientific semantics.

cfg.experiment_id = "EXP02_R0C_CROSS_SHIP_INTERFACE_GATE";
cfg.experiment_name = "Cross_Ship_Processing_Object_Reproducibility_Gate";

this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
research_root = fileparts(fileparts(this_dir));

cfg.scene_dir = 'E:\OpenSARShip_raw\pilot\scene01';
cfg.patch_dir = fullfile(cfg.scene_dir,'Patch');
cfg.ship_xml = fullfile(cfg.scene_dir,'Ship.xml');

% PRESELECTED before any R0C outcome was observed.
% #1 = already used 257x257 science-pilot chip.
% #2/#3 = larger ships selected from metadata only (support size, motion,
%          AIS/SAR match), NOT from branch or LFM outcomes.
cfg.ship_xy = [ ...
    19112 4564; ...
    48949 5380; ...
    64672 2351];

cfg.primary_pol = "VV";
cfg.line_selection_rule = "energy_gt_mean";
cfg.background_control = "lowest_energy_equal_count";

% Frozen R0B scanner settings.
cfg.n_beta = 401;
cfg.nfft = 2048;

cfg.output_dir = fullfile(research_root,'results', ...
    'exp02_real_sar_branch_audit','r0c_cross_ship_interface_gate');

cfg.feedback_name = 'EXP02_R0C_FEEDBACK_BUNDLE.txt';
cfg.csv_name = 'exp02_r0c_cross_ship_metrics.csv';
cfg.mat_name = 'exp02_r0c_outputs.mat';
cfg.fig1_name = '05_cross_ship_lfm_coherence.png';
cfg.fig2_name = '06_cross_ship_chirp_gain.png';

end
