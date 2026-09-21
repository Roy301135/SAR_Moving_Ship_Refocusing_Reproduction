function cfg = config_exp02_fair_r2a(research_dir,repo_root)
%CONFIG_EXP02_FAIR_R2A
% Corrected frozen configuration for EXP02-FAIR-R2A:
% Branch Contribution to Image Defocus — Candidate B.
%
% IMPORTANT CORRECTION
% --------------------
% R1 defines the branch coordinate nu in the dechirped TONE objective:
%
%   z[m] = x[m] * exp(-j*pi*a*m^2)
%   J(nu)=|sum z[m] exp(-j*2*pi*nu*m/N)|^2
%
% Therefore R2A must reconstruct in that SAME branch-native coordinate.
% It must NOT map nu into the finite u-grid of frft_direct.m.
%
% R2A now reuses the validated EXP009/EXP010 practical mechanism:
%
%   recenter by nu
%   -> matched-LFM dechirp
%   -> FFT
%   -> frozen finite window around DC
%   -> inverse matched-LFM transform
%   -> undo recenter
%   -> sequential subtraction
%
% This removes the coordinate mismatch that caused the old FrFT closure to
% give TRUE/WRONG ratio ~= 1.

cfg = struct();

cfg.experiment_id = "EXP02_FAIR_R2A_BRANCH_CONTRIBUTION_TO_IMAGE_DEFOCUS";
cfg.experiment_name = "FAIR_CSAR_R2A_Branch_Contribution_Candidate_B";

cfg.data_root = fullfile(repo_root,'data','fair_csar','pilot_candidate_B');

cfg.r1b_workspace = fullfile( ...
    research_dir,'results','exp02_real_sar_branch_audit', ...
    'fair_csar','r1b_full_frozen_pool_occurrence', ...
    'EXP02_FAIR_R1B_workspace.mat');

cfg.results_dir = fullfile( ...
    research_dir,'results','exp02_real_sar_branch_audit', ...
    'fair_csar','r2a_branch_contribution_candidate_b');

%% Frozen practical removal operator
% EXP009/EXP010 froze the finite removal width at 3 bins.
cfg.clean.removal_window_bins = 3;

% Same component ordering in G0 and Global paths.
cfg.clean.order_rule = "descending_frac_energy";

%% R0/R1 p_beta -> sampled quadratic coefficient convention
cfg.tnorm_full_span = 8;

%% Reconstruction closure
cfg.closure.N = 310;
cfg.closure.p_beta = 0.78;
cfg.closure.nu_true = 4.37;
cfg.closure.nu_wrong_offset = 24.0;

% These are engineering self-test thresholds only.
cfg.closure.min_true_capture_fraction = 0.95;
cfg.closure.max_wrong_capture_fraction = 0.05;

%% Image metrics
cfg.metrics.azimuth_energy_fraction = 0.80;

%% Reporting
cfg.figure_resolution = 180;

end
