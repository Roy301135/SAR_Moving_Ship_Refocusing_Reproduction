function cfg = config_exp09_pa5i_branchsafe_ml()
%CONFIG_EXP09_PA5I_BRANCHSAFE_ML
% EXP009 / PA5I
%
% Branch-Safe Multi-Candidate Continuous ML
%
% Purpose
% -------
% PA5H-R1 confirmed:
%   1) exact signal translation invariance is numerically valid;
%   2) high-contrast collapse outliers are caused by local-estimator
%      branch switching / local-not-global failures;
%   3) the failure is sparse but catastrophic;
%   4) the failure is not primarily caused by near-degenerate top peaks.
%
% PA5I asks:
%
%   Can a very small number of additional local refinements eliminate
%   fence-effect-induced coarse-to-fine branch switching, while preserving
%   much lower computational cost than a global/wide continuous search?
%
% No new removal operator is introduced here.
% No gate threshold is tuned here.
%
% Groups
% ------
% G0  OriginalTop1:
%       strongest integer DFT bin -> one local continuous refinement.
%
% G1  Neighbor3:
%       refine {k0-1,k0,k0+1}; choose largest continuous objective.
%
% G2  Top2Coarse:
%       refine the top-2 integer coarse candidates; choose largest.
%
% G3  Top3Coarse:
%       refine the top-3 integer coarse candidates; choose largest.
%
% G4  GlobalReference:
%       broad dense-grid + local refinement around global grid maximum.
%       This is a diagnostic reference, not a practical method.
%
% Main metrics
% ------------
%   - branch recovery rate vs G4;
%   - catastrophic branch-failure rate;
%   - estimation error to G4;
%   - objective loss to G4;
%   - number of local refinements;
%   - approximate objective-evaluation cost;
%   - failure phase diagram over contrast x resolution coordinate.

%% Constants
cfg.c = 3.0e8;

%% Wang-2023 / physical-anchor parameters
cfg.fc_hz = 3.0e9;
cfg.prf_hz = 188;
cfg.bandwidth_hz = 150e6;
cfg.platform_height_m = 3000;
cfg.antenna_length_m = 2;
cfg.platform_velocity_mps = 150;
cfg.pulse_width_s = 1.5e-6;

cfg.slant_range_factor = sqrt(2);
cfg.paper_aperture_time_s = 1.0;
cfg.beamwidth_scale = 1.0;

%% Two-component physical grid
cfg.weak_velocity_mps = 15;
cfg.delta_velocity_mps = [2.5, 5, 7.5, 10, 15, 20];

cfg.A_strong = 1.0;
cfg.weak_to_strong_ratio = [0.10, 0.20, 0.30, 0.50, 0.80];

cfg.num_relative_phases = 16;
cfg.relative_phase_rad = ...
    (0:cfg.num_relative_phases-1) * ...
    (2*pi/cfg.num_relative_phases);

cfg.fractional_bin_offsets = [0, 0.125, 0.25, 0.375, 0.5];

%% Local continuous refinement
cfg.local_search_halfwidth_bins = 0.75;
cfg.local_bracket_points = 33;
cfg.local_tolx_bins = 1e-11;
cfg.local_max_fun_evals = 200;

%% Coarse candidate definitions
cfg.neighbor_radius = 1;
cfg.topk_list = [1, 2, 3];

% When selecting top-K coarse bins, use local maxima first to avoid
% spending all candidates on adjacent samples from one broad lobe.
% If there are too few local maxima, fill with remaining largest bins.
cfg.coarse_candidate_use_localmax = true;

%% Global reference
cfg.global_search_halfwidth_bins = 1.5;
cfg.global_grid_step_bins = 1e-3;
cfg.global_tolx_bins = 1e-12;
cfg.global_max_fun_evals = 300;

%% Branch matching and catastrophic failure
cfg.branch_match_tolerance_bins = 0.02;

% A branch failure is catastrophic if the estimate differs from the
% global-reference branch by more than this wrapped bin distance.
% This is diagnostic, not a method threshold.
cfg.catastrophic_error_threshold_bins = 0.10;

%% Objective-loss metric
cfg.objective_loss_floor = 1e-15;

%% Resolution coordinate
% Use PA4-style Gamma = |Delta beta| / W_beta,3dB.
% We estimate W_beta,3dB numerically from a strong-only matched response.
cfg.beta_width_dense_points = 4001;
cfg.beta_width_halfspan_bins = 2.0;

%% Output / numerics
cfg.figure_visible = 'off';
cfg.output_dir = '';
cfg.selftest_translation_gate = 1e-12;

end
