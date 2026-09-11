function cfg = config_exp09a4()
%CONFIG_EXP09A4 Configuration for EXP009-A4: residual interference geometry.
%
% Main questions:
%   1) Why does the weak-q peak move toward the strong component?
%   2) Does the shift reverse sign when q_strong is mirrored around q_weak?
%   3) Can the shift be explained by the local derivative of the residual
%      interference term around q_weak?
%
% This is a mechanism experiment. It deliberately uses oracle quantities
% (true weak frequency and true q values) for diagnostic decomposition.

%% Reproducibility
cfg.seed = 20260908;
cfg.num_mc = 100;

%% Signal
cfg.N = 512;

cfg.q_ref = 1.44;
cfg.mu_scale = 180;

cfg.q_weak = 1.470;

cfg.A_strong = 1.0;
cfg.A_weak_ratio = 0.40;
cfg.A_weak = cfg.A_strong * cfg.A_weak_ratio;

cfg.f_strong = 12.3;
cfg.f_weak   = 30.3;

cfg.phi_strong = 0.20;
cfg.phi_weak   = -0.70;

%% Noise
cfg.snr_db = 3.0;  % referenced to the two-component noiseless mixture

%% CLEAN
cfg.notch_halfwidth_bins = 1;

%% Mirror test
cfg.mirror_separation = 0.050;
cfg.q_strong_lower = cfg.q_weak - cfg.mirror_separation;
cfg.q_strong_upper = cfg.q_weak + cfg.mirror_separation;

%% Separation sweep
% Keep this modest: it is not yet the full failure map.
cfg.separation_list = [0.020 0.030 0.040 0.050 0.060];

%% Operational q search
cfg.q_search_min = 1.340;
cfg.q_search_max = 1.600;
cfg.q_search_step = 0.001;

%% Fine geometry grid around q_weak
cfg.q_geom_halfwidth = 0.020;
cfg.q_geom_step = 0.0001;

%% First-order perturbation derivative
% Central difference uses +/- deriv_offset around q_weak.
cfg.deriv_offset = 0.0005;

%% Weak recovery criterion for Monte Carlo mirror test
cfg.tau_q = 0.003;
cfg.success_tol = 1e-12;

%% Figures
cfg.figure_visible = 'off';

%% Output
% Leave empty to automatically create:
% <paper_root>/results/exp09_pilot01/exp09a4_residual_geometry/
cfg.output_dir = '';

end
