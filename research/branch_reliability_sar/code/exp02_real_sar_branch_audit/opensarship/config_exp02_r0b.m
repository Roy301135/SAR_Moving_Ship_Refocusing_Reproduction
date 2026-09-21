function cfg = config_exp02_r0b()
%CONFIG_EXP02_R0B
% EXP02-R0B — Real complex-line dominant LFM compatibility audit.
%
% No G0 / Neighbor-3 / Proposed / branch taxonomy is used here.
% This stage asks only whether natural fixed-range azimuth lines from the
% real OpenSARShip complex SLC exhibit coherent support for the same local
% discrete-LFM family used by the signal-level work.

cfg.experiment_id = "EXP02_R0B_REAL_LFM_COMPATIBILITY";
cfg.experiment_name = "Real_Complex_Line_Dominant_LFM_Compatibility";

this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
research_root = fileparts(fileparts(this_dir));

cfg.r0a_mat = fullfile(research_root,'results', ...
    'exp02_real_sar_branch_audit','r0a_interface_gate','exp02_r0a_outputs.mat');

cfg.output_dir = fullfile(research_root,'results', ...
    'exp02_real_sar_branch_audit','r0b_lfm_compatibility');

cfg.n_beta = 401;
cfg.nfft = 2048;
cfg.background_control = "lowest_energy_equal_count";
cfg.representatives = "strongest_median_weakest_selected_energy";

cfg.feedback_name = 'EXP02_R0B_FEEDBACK_BUNDLE.txt';
cfg.csv_name = 'exp02_r0b_line_metrics.csv';
cfg.mat_name = 'exp02_r0b_outputs.mat';
cfg.fig1_name = '03_real_lfm_compatibility_overview.png';
cfg.fig2_name = '04_representative_beta_profiles.png';
end
