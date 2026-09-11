function cfg = config_exp09a2()
%CONFIG_EXP09A2 Configuration for EXP009-A2: CLEAN mechanism dissection.
%
% Goal:
%   Isolate whether practical CLEAN itself reshapes/damages the weak
%   component, and how the effect changes with CLEAN notch width.
%
% Scientific scope:
%   This remains a controlled mechanism experiment. It uses the same
%   self-contained matched-chirp concentration backend as EXP009-A.
%   It is not a claim of exact Xu 2025 AFRA reproduction.

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
% Numerical tolerance avoids floating-point classification artifacts at
% exactly the recovery boundary.
cfg.success_tol = 1e-12;

%% Default CLEAN width for C0/C1/C2 comparison
cfg.default_notch_halfwidth_bins = 1;

%% Width sweep
cfg.notch_halfwidth_list = [0 1 2 3 5];

%% Reliability helper
cfg.second_peak_guard_bins = 4;

%% Figures
cfg.figure_visible = 'off';

%% Output
% Leave empty to automatically create:
% <paper_root>/results/exp09_pilot01/exp09a2_clean_mechanism/
cfg.output_dir = '';

end
