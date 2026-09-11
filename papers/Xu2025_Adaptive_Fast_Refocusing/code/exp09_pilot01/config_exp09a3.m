function cfg = config_exp09a3()
%CONFIG_EXP09A3 Configuration for EXP009-A3: peak-shift mechanism test.
%
% Main question:
%   Is the persistent weak-q bias caused by:
%     (1) direct distortion of the weak component by the CLEAN notch, or
%     (2) the filtered strong residual left after CLEAN?
%
% This is a controlled mechanism experiment using the same self-contained
% matched-chirp concentration backend as EXP009-A/A2.

%% Reproducibility
cfg.seed = 20260908;
cfg.num_mc = 100;

%% Signal
cfg.N = 512;

cfg.q_ref = 1.44;
cfg.mu_scale = 180;

cfg.q_strong = 1.420;
cfg.q_weak   = 1.470;

cfg.A_strong = 1.0;
cfg.A_weak_ratio = 0.40;
cfg.A_weak = cfg.A_strong * cfg.A_weak_ratio;

cfg.f_strong = 12.3;
cfg.f_weak   = 30.3;

cfg.phi_strong = 0.20;
cfg.phi_weak   = -0.70;

%% Noise
cfg.snr_db = 3.0;   % referenced to the two-component noiseless mixture

%% q search
cfg.q_min = 1.340;
cfg.q_max = 1.540;
cfg.q_step = 0.001;

%% Weak recovery criterion
cfg.tau_q = 0.003;
cfg.success_tol = 1e-12;

%% CLEAN / notch
cfg.default_notch_halfwidth_bins = 1;
cfg.notch_halfwidth_list = [0 1 2 3 5];

%% Shape analysis around q_weak
cfg.shape_halfwidth = 0.020;

%% Figure settings
cfg.figure_visible = 'off';

%% Output
% Leave empty to automatically create:
% <paper_root>/results/exp09_pilot01/exp09a3_peak_shift/
cfg.output_dir = '';

end
