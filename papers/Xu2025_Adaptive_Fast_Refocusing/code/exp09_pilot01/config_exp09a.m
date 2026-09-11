function cfg = config_exp09a()
%CONFIG_EXP09A Configuration for EXP009-A / Pilot-01 Oracle Ladder.
%
% This is a self-contained mechanism experiment. It deliberately removes
% spatial tracking and uses a normalized MC-LFM model plus a matched-chirp
% concentration search as a controlled FrFT/FrAc-like backend.
%
% The goal is NOT to claim an AFRA implementation. The goal is to isolate:
%   L0: intrinsic weak-component detectability
%   L1: strong-component q/ORO estimation error
%   L2: practical CLEAN/filtering penalty
%   L3: local-search behavior under a VALID prior
%
% After EXP009-A is verified, the search backend can be replaced by the
% project's existing FrAc/FrFT functions for EXP009-B/C.

%% Reproducibility
cfg.seed = 20260908;
cfg.num_mc = 100;

%% Signal length and normalized slow time
cfg.N = 512;

%% ORO-like parameterization
% q is an ORO-like normalized parameter. The actual quadratic-phase slope is
% mu(q) = mu_scale * (q - q_ref).
cfg.q_ref = 1.44;
cfg.mu_scale = 180;

cfg.q_strong = 1.420;
cfg.q_weak   = 1.470;

%% Component parameters
cfg.A_strong = 1.0;
cfg.A_weak_ratio = 0.40;
cfg.A_weak = cfg.A_strong * cfg.A_weak_ratio;

% Different center frequencies keep the controlled CLEAN notch from
% trivially deleting the whole weak component, while the two components
% still share the same slow-time record and differ in chirp slope.
cfg.f_strong = 12.3;
cfg.f_weak   = 30.3;

cfg.phi_strong = 0.20;
cfg.phi_weak   = -0.70;

%% Noise
% SNR is defined against the average power of the CLEAN two-component
% noiseless mixture.
cfg.snr_db = 3.0;

%% Full q search
cfg.q_min = 1.340;
cfg.q_max = 1.540;
cfg.q_step = 0.001;

%% Weak-component recovery criterion
% Correct recovery if |q_hat_weak - q_weak| <= tau_q.
cfg.tau_q = 0.003;

%% Practical CLEAN
% After dechirping at q_hat_strong, remove the strongest FFT bin and its
% immediate neighbors. halfwidth=1 removes 3 bins in total.
cfg.clean_notch_halfwidth_bins = 1;

%% L3 local-search control
% IMPORTANT:
% EXP009-A uses an intentionally VALID local prior. This isolates the effect
% of narrowing the search when the prior itself is not wrong.
%
% Search center = q_weak + local_prior_bias.
cfg.local_halfwidth = 0.015;
cfg.local_prior_bias = 0.000;

%% Reliability observables
% Exclude +/- guard bins around the best q when computing peak/second-peak
% ratio, otherwise adjacent grid samples make the ratio artificially ~1.
cfg.second_peak_guard_bins = 4;

%% Figures
cfg.figure_visible = 'off';

%% Output
% Leave empty to automatically create:
% <paper_root>/results/exp09_pilot01/exp09a_oracle_ladder/
cfg.output_dir = '';

end
