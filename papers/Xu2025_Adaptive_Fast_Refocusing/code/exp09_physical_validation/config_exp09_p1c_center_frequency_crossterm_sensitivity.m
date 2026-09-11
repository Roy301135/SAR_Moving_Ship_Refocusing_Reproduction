function cfg = config_exp09_p1c_center_frequency_crossterm_sensitivity()
%CONFIG_EXP09_P1C_CENTER_FREQUENCY_CROSSTERM_SENSITIVITY
% EXP009 / Physical Validation Track / P1C
%
% Center-Frequency / Cross-Term Sensitivity Audit
%
% P1C is the FINAL Wang-2023 reproduction audit before PA4.
%
% It tests whether the unresolved five-peak FrAc result in P1B is mainly
% caused by the unreported component center frequencies b_i and the
% resulting phase-sensitive cross-term geometry.
%
% No noise. No CLEAN. Physical chirp rates are fixed by Wang/Xu parameters.

%% Constants
cfg.c = 3.0e8;

%% Wang 2023 Table 1 — paper-reported
cfg.fc_hz = 3.0e9;
cfg.prf_hz = 188;
cfg.bandwidth_hz = 150e6;
cfg.platform_height_m = 3000;
cfg.antenna_length_m = 2;
cfg.platform_velocity_mps = 150;
cfg.pulse_width_s = 1.5e-6;

%% Wang 2023 Table 2 — paper-reported
cfg.target_velocity_mps = [5, 10, 15, 20, 25];

%% Representative geometry inherited from P1/P1B
% Exact R0 for Wang's five-point experiment is not reported.
% P1C does not resweep geometry; it fixes the representative sensitivity
% point used previously.
cfg.slant_range_factor = sqrt(2);

%% Two physically interpretable aperture scales
cfg.paper_aperture_time_s = 1.0;
cfg.beamwidth_scale = 1.0;

%% Component amplitudes
% Not reported for the five-point experiment; fixed equal to isolate the
% b_i/cross-term question.
cfg.component_amplitudes = ones(1,5);

%% Center-frequency separation sweep
% Wang Eq. (13) contains b_i, but exact b_i values are not reported.
%
% Define adjacent center-frequency spacing in DFT-bin units:
%
%       Delta b = gamma / N  cycles/sample
%
% and:
%
%       b_i = [-2,-1,0,1,2] * Delta b
%
% Thus gamma=1 means adjacent components differ by one Fourier bin.
cfg.gamma_bins = [0, 0.5, 1, 2, 4];
cfg.center_frequency_index = [-2,-1,0,1,2];

%% Unknown initial phases
cfg.num_phase_mc = 40;
cfg.phase_seed = 20230912;

%% FrAc statistic
cfg.max_lag_fraction = 0.40;
cfg.frac_fft_oversample = 32;
cfg.beta_grid_oversample = 100;
cfg.beta_grid_margin_separations = 3.0;

%% Peak matching
cfg.peak_match_tolerance_fraction = 0.40;
cfg.min_peak_prominence_fraction = 0.02;

%% Gate
% Diagnostic only, not literature numbers.
cfg.phase_mc_all5_rate_gate = 0.80;
cfg.cross_suppression_fraction_gate = 0.50;

%% Figure/output
cfg.figure_visible = 'off';
cfg.output_dir = '';

end
