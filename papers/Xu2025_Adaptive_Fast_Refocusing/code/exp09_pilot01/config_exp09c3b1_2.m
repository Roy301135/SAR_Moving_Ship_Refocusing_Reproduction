function cfg = config_exp09c3b1_2()
%CONFIG_EXP09C3B1_2
% EXP009-C3-B1.2
% Mechanism-Informed Realization Observable Audit
%
% Purpose:
%   C3-B1.1 showed that physical state is highly reproducible, but
%   prominence/entropy contain only weak within-state realization
%   information. C3-B1.2 therefore returns to signal-level mechanism
%   observables and asks which practical observable families actually
%   separate Beneficial / Harmful realizations at fixed physical state.
%
% Controlled boundary:
%   - q_strong remains oracle/known, matching C3-B1.
%   - signal trajectory, SNR, Cheap branch, fallback branch, seeds and
%     recovery threshold match C3-B1.
%   - no deep model is introduced; identical ridge-logistic heads are used
%     to audit information content rather than model capacity.

%% Reproducibility
cfg.seed = 20260909;

%% Signal model -- identical to C3-B1
cfg.N = 512;

cfg.q_ref = 1.44;
cfg.mu_scale = 180;

cfg.q_weak = 1.470;

cfg.A_strong = 1.0;

cfg.f_strong = 12.3;
cfg.f_weak   = 30.3;

cfg.phi_strong = 0.20;
cfg.phi_weak   = -0.70;

cfg.snr_db = 3.0;

%% Cheap strong-removal chain
cfg.notch_halfwidth_bins = 1;

%% Parametric-refit fallback -- identical to C3-B1
cfg.refit_nfft_factor = 8;

%% Weak-q search
cfg.q_search_min = 1.380;
cfg.q_search_max = 1.560;
cfg.q_search_step = 0.001;

cfg.tau_q = 0.003;
cfg.success_tol = 1e-12;

cfg.q_search_block_lines = 16;

%% Continuous azimuth-state trajectory -- identical to C3-B1
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

%% Monte-Carlo ensembles -- identical to C3-B1
cfg.num_train_mc = 20;
cfg.num_test_mc  = 40;

%% State prior
cfg.state_utility_smooth_window = 7;

%% Rich q-curve morphology
% Second peak excludes a neighborhood around the main peak so that
% immediate grid samples from the same lobe are not misread as a
% competing mode.
cfg.second_peak_exclusion_bins = 3;

% Local morphology windows in q-grid bins.
cfg.curve_local_halfwidth_bins = 5;
cfg.strong_q_neighborhood_bins = 3;

%% Sub-aperture stability
cfg.num_subapertures = 4;

%% Strong-residual spectral diagnostics
% q_strong-dechirped Cheap residual FFT.
cfg.strong_spectrum_nfft_factor = 2;
cfg.strong_spectral_local_halfwidth_bins = 6;

%% Feature groups
% BaselinePE reproduces the C3-B1.1 instantaneous baseline.
cfg.feature_groups = { ...
    'StateOnly', ...
    'BaselinePE', ...
    'StateBaseline', ...
    'MorphologyOnly', ...
    'StateMorphology', ...
    'StrongCompetitionOnly', ...
    'StateStrongCompetition', ...
    'SubapertureOnly', ...
    'StateSubaperture', ...
    'AllObservable', ...
    'StateAll'};

%% Predictive model
% Two identical ridge-logistic heads:
%   pB = P(Beneficial|X)
%   pH = P(Harmful|X)
% Allocation value:
%   V = pB - pH
cfg.ridge_lambda = 0.10;
cfg.irls_max_iter = 100;
cfg.irls_tol = 1e-8;
cfg.prob_clip = 1e-6;

%% Budget evaluation
cfg.budget_grid = (0:0.05:1).';
cfg.report_budgets = [0.10 0.25 0.50];
cfg.primary_budget = 0.25;

%% State-bin diagnostics
cfg.num_state_bins = 5;

%% Diagnostic notices (not hard pass/fail claims)
% Previous C3-B1.1 within-line Beneficial AUC baseline was approximately:
%   Smooth 0.537, Abrupt 0.523.
% Harmful baseline:
%   Smooth 0.528, Abrupt 0.583.
cfg.notice_within_beneficial = 0.58;
cfg.notice_within_harmful = 0.62;

%% Optional continuity check against existing C3-B1 results
% If the standard C3-B1 raw banks exist, compare success labels generated
% here with the original experiment. This is only a validation guard.
cfg.verify_against_c3b1 = true;
cfg.c3b1_result_dir = '';

%% Figures
cfg.figure_visible = 'off';

%% Output
cfg.output_dir = '';

end
