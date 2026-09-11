function cfg = config_exp09_pa5er1_tie_tolerance_patch()
%CONFIG_EXP09_PA5ER1_TIE_TOLERANCE_PATCH
% EXP009 / PA5E-R1
%
% Numerical Tie-Tolerance Patch
%
% Purpose:
%   Close one residual implementation question from PA5E:
%   the old "PlateauAware" rule still used exact floating-point
%   comparisons, so a mathematically equal half-bin twin peak could be
%   represented numerically by two nearly-equal samples and fail to be
%   treated as a plateau.
%
% This patch is intentionally small:
%   - no FrAc strong-order estimation;
%   - no noise;
%   - true strong parameter;
%   - only on-grid and half-bin cases;
%   - only zero-mismatch recoverability-floor analysis.
%
% It compares:
%   1) LocalMax          : PA5C/PA5D legacy rule
%   2) ConnectedSupport : threshold-support interpretation
%   3) PlateauAwareExact: PA5E exact-comparison rule
%   4) PlateauAwareTol  : numerical-tolerance-aware plateau rule
%
% The tolerance is tied to floating-point precision:
%
%   tie_tol = tie_eps_multiplier * N * eps(max(abs(Y)))
%
% so it is a numerical-equivalence tolerance, not a tunable physical
% peak-merging threshold.

%% Constants
cfg.c = 3.0e8;

%% Wang-2023 paper-grounded SAR parameters
cfg.fc_hz = 3.0e9;
cfg.prf_hz = 188;
cfg.bandwidth_hz = 150e6;
cfg.platform_height_m = 3000;
cfg.antenna_length_m = 2;
cfg.platform_velocity_mps = 150;
cfg.pulse_width_s = 1.5e-6;

%% Representative geometry inherited from PA5E
cfg.slant_range_factor = sqrt(2);

%% Apertures
cfg.paper_aperture_time_s = 1.0;
cfg.beamwidth_scale = 1.0;

%% Two-component physical grid
cfg.weak_velocity_mps = 15;
cfg.delta_velocity_mps = [2.5, 5, 7.5, 10, 15, 20];

cfg.A_strong = 1.0;

%% Only the two cases needed for the patch
cfg.fractional_bin_offsets = [0, 0.5];

%% Removal windows
cfg.filter_window_length_bins = [1, 3, 5, 9, 17];

%% Peak semantics
cfg.peak_semantics = ...
    ["LocalMax", ...
     "ConnectedSupport", ...
     "PlateauAwareExact", ...
     "PlateauAwareTol"];

%% Wang Algorithm-2 gate
cfg.frac_domain_peak_gate = 0.70;

%% Numerical tie tolerance
% Principled scaling with machine precision and transform length.
cfg.tie_eps_multiplier = 100;

%% Recoverability floor
cfg.small_norm_floor = 1e-12;

%% Diagnostic decision gates only
cfg.semantic_match_rel_tol = 1e-6;
cfg.persistent_floor_rmin_gate = 0.05;

%% Representative figure case
cfg.figure_aperture = 'BeamDerived';
cfg.figure_delta_velocity_mps = 10;
cfg.figure_side = 'HighV';
cfg.figure_eta = 0.5;
cfg.figure_window_bins = 1;

%% Output
cfg.figure_visible = 'off';
cfg.output_dir = '';

end
