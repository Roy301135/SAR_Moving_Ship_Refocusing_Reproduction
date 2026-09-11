function cfg = config_exp09c3b3b()
%CONFIG_EXP09C3B3B
% EXP009 / Pilot-01 / C3-B3B
% Near-Shift Mechanism and Local Peak Recovery
%
% C3-B3A established that, among fallback failures:
%   - Smooth: NearShift dominates;
%   - Abrupt: NearShift dominates;
%   - strong residual energy is already very small;
%   - weak retention is ~1;
%   - the true weak-q response is usually very close to the global peak.
%
% C3-B3B therefore asks:
%
%   1) Is the residual weak-q shift consistent with the A4/B1
%      first-order perturbation law?
%   2) Is the failure mainly a coarse-grid / threshold artifact?
%   3) Can purely local, observable curve geometry reduce the error?
%   4) Do Cheap-branch and fallback q errors share a perturbation source?
%
% IMPORTANT:
%   q_weak is used only for mechanism diagnostics and scoring.
%   The practical local estimators do NOT use q_weak.

%% Reproducibility
cfg.seed = 20260909;

%% Signal model: identical to C3-B3A
cfg.N = 512;

cfg.q_ref = 1.44;
cfg.mu_scale = 180;

cfg.q_weak = 1.470;

cfg.A_strong = 1.0;

cfg.f_strong = 12.3;
cfg.f_weak   = 30.3;

cfg.phi_strong = 0.20;
cfg.phi_weak   = -0.70;

%% SNR
cfg.snr_db = 3.0;

%% Cheap branch
cfg.notch_halfwidth_bins = 1;

%% Fallback branch
cfg.refit_nfft_factor = 8;

%% Operational q search: same coarse grid as C3-B3A
cfg.q_search_min = 1.380;
cfg.q_search_max = 1.560;
cfg.q_search_step = 0.001;

%% Half-step diagnostic grid
% Used ONLY on coarse fallback failures to ask:
%   "Would a denser q grid rescue the failure?"
cfg.q_half_step = 0.0005;

%% Success / NearShift
cfg.tau_q = 0.003;
cfg.success_tol = 1e-12;
cfg.near_shift_tol = 0.010;

%% Exact matched-response mechanism grid
% This grid is oracle-centered at q_weak and is diagnostic only.
% It is used to test the A4/B1 first-order perturbation law:
%
%   delta_q ~= - DeltaP'(q0) / P_w''(q0)
%
cfg.q_diag_halfwidth = 0.012;
cfg.q_diag_step = 0.0001;
cfg.max_firstorder_abs_shift = 0.020;

%% Practical local curve estimators
% These operate only on the observed COARSE fallback q curve.
cfg.logquad_halfbins = 2;     % 5-point log-quadratic fit
cfg.centroid_halfbins = 3;    % 7-bin local centroid
cfg.centroid_power = 2.0;

%% Continuous azimuth-state sequence: identical to C3-B3A
cfg.num_lines = 121;

cfg.weak_ratio_center = 0.34;
cfg.weak_ratio_sin1 = 0.10;
cfg.weak_ratio_sin2 = 0.035;
cfg.weak_ratio_min = 0.18;
cfg.weak_ratio_max = 0.52;

cfg.sep_center = -0.010;
cfg.sep_sin1 = 0.038;
cfg.sep_sin2 = 0.014;
cfg.sep_min = -0.060;
cfg.sep_max =  0.060;

cfg.jump_fraction = 0.45;
cfg.jump_weak_ratio_step = -0.14;
cfg.jump_sep_step = -0.035;

%% Monte Carlo
% Same as C3-B3A for direct comparability.
cfg.num_mc = 40;

%% Batch sizes
cfg.q_search_block_lines = 16;

%% First-order validation subsets
% We report:
%   All CheapFailure
%   FallbackFailure
%   NearShift
cfg.min_validation_samples = 20;

%% Figures
cfg.figure_visible = 'off';

%% Output
cfg.output_dir = '';

end
