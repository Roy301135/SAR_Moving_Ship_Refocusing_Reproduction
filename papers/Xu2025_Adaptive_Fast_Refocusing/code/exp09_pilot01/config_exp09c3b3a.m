function cfg = config_exp09c3b3a()
%CONFIG_EXP09C3B3A
% EXP009 / Pilot-01 / C3-B3A
% Rescueability Failure-Mode Decomposition
%
% Scientific question:
%   C3-B2 showed that CheapFailure has moderate within-state observability,
%   while Rescueability is close to random. C3-B3A therefore stops trying
%   to improve the classifier and asks:
%
%     When Cheap already failed, WHY does fallback rescue some trials
%     but fail on others?
%
% Controlled boundary:
%   - same two-component LFM model as C3-B1/C3-B1.2/C3-B2;
%   - q_strong remains known/oracle;
%   - fallback = off-grid parametric strong refit + full weak-q search;
%   - fallback success is defined only by q_hat error, as in C3-B1.
%
% Therefore C3-B3A decomposes failure at the fallback-q landscape level:
%
%   CheapFailure
%       -> Success
%       -> NearShift
%       -> PeakCompetition
%       -> BasinCollapse
%       -> BoundaryFalsePeak
%
% It also decomposes the refit residual into:
%   residual strong + residual weak + residual noise
% under the SAME fitted projection operator.

%% Reproducibility
cfg.seed = 20260909;

%% Signal model: preserve C3-B1 controlled chain
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

%% Cheap branch: fixed notch
cfg.notch_halfwidth_bins = 1;

%% Fallback branch: off-grid parametric strong refit
cfg.refit_nfft_factor = 8;

%% Weak-q search
cfg.q_search_min = 1.380;
cfg.q_search_max = 1.560;
cfg.q_search_step = 0.001;

cfg.tau_q = 0.003;
cfg.success_tol = 1e-12;

% A failed global winner that is only slightly outside the success basin
% is called NearShift. This is diagnostic, not a new success criterion.
cfg.near_shift_tol = 0.010;

% Search-boundary winner diagnostic.
cfg.boundary_margin_q = 0.003;

%% Continuous azimuth-state sequence: match C3-B1
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
% 40 x 121 trials per regime gives thousands of CheapFailure cases while
% remaining comparable to the prior C3-B1 TEST bank size.
cfg.num_mc = 40;

%% Batch search
cfg.q_search_block_lines = 16;

%% Failure-map binning
cfg.weak_ratio_edges = linspace( ...
    cfg.weak_ratio_min,cfg.weak_ratio_max,7);

cfg.sep_edges = linspace( ...
    cfg.sep_min,cfg.sep_max,9);

cfg.min_bin_trials = 10;

%% Representative curves
% For each class, select the trial closest to the class median in:
%   [true/global ratio, residual strong/weak ratio, q error].
cfg.max_representatives_per_class = 1;

%% Figures
cfg.figure_visible = 'off';

%% Output
cfg.output_dir = '';

end
