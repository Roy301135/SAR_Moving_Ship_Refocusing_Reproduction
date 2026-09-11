function cfg = config_exp09c1()
%CONFIG_EXP09C1 Configuration for EXP009-C1.
%
% Oracle-to-Practical Adaptive Budget Test
%
% Scientific purpose:
%   Test whether a practical residual-confidence observable can allocate
%   extra computation only to difficult weak-component stages and obtain a
%   useful Weak-Recovery / Cost trade-off.
%
% C1 is still a mechanism/policy pilot. It is not yet the final paper method.

%% Reproducibility -- preserve B2/B3/B4 MC realization
cfg.seed = 20260909;

%% Input
% Leave empty for automatic discovery.
cfg.b2_result_dir = '';

%% Signal model -- must match B1-B4
cfg.N = 512;

cfg.q_ref = 1.44;
cfg.mu_scale = 180;
cfg.q_weak = 1.470;

cfg.A_strong = 1.0;

cfg.f_strong = 12.3;
cfg.f_weak = 30.3;

cfg.phi_strong = 0.20;
cfg.phi_weak = -0.70;

%% Cheap branch: original B1-B4 fixed-notch CLEAN
cfg.notch_halfwidth_bins = 1;

%% q search
cfg.q_search_min = 1.380;
cfg.q_search_max = 1.560;
cfg.q_search_step = 0.001;

%% Recovery
cfg.tau_q = 0.003;
cfg.success_tol = 1e-12;
cfg.catastrophic_error_q = 0.010;

%% Monte Carlo
cfg.num_mc = 500;

%% Extra-computation fallback:
% Off-grid strong-component parametric refit.
%
% q_strong is assumed available from the previous dominant-component stage.
% This is consistent with A/B-series isolation of weak-stage failure.
%
% The strong carrier/frequency is re-estimated using a zero-padded FFT,
% then the strong component is least-squares subtracted before a second
% weak-q search.
cfg.refit_nfft_factor = 8;

%% Practical gate observables
cfg.second_peak_guard_bins = 4;

% Primary C1 gate:
%   low prominence -> trigger extra computation
cfg.primary_gate = 'prominence';

%% Threshold sweeps for Pareto curves
cfg.num_thresholds = 61;

%% Budget-controlled LOCO practical policies
% These are requested average fallback fractions, not learned failure
% thresholds. This keeps the policy interpretation close to computation
% budgeting rather than deterministic classification.
cfg.target_fallback_rates = [0.10 0.25 0.50];

%% After fallback is computed, practical branch selection
% 'prominence' means accept whichever branch has higher observable
% prominence. This avoids blindly overwriting a good cheap estimate.
cfg.branch_selector = 'prominence';

%% Figures
cfg.figure_visible = 'off';

%% Output
cfg.output_dir = '';

end
