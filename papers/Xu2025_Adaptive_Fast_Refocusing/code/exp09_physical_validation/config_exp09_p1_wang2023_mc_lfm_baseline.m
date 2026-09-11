function cfg = config_exp09_p1_wang2023_mc_lfm_baseline()
%CONFIG_EXP09_P1_WANG2023_MC_LFM_BASELINE
% EXP009 / Physical Validation Track / P1
%
% Wang 2023 five-component MC-LFM physical baseline.
%
% Paper-reported quantities are separated from controlled numerical
% quantities. Do NOT relabel the latter as Wang-paper parameters.

%% Constants
cfg.c = 3.0e8;

%% Wang 2023 Table 1 — paper-reported SAR system parameters
cfg.fc_hz = 3.0e9;
cfg.prf_hz = 188;
cfg.bandwidth_hz = 150e6;
cfg.platform_height_m = 3000;
cfg.antenna_length_m = 2;
cfg.platform_velocity_mps = 150;
cfg.pulse_width_s = 1.5e-6;

%% Wang 2023 Table 2 — paper-reported azimuth velocities
cfg.target_velocity_mps = [5, 10, 15, 20, 25];

%% Geometry uncertainty
% Wang Table 1 does NOT report incidence angle or the exact closest slant
% range R0 for this five-point MC-LFM experiment.
%
% Therefore P1 does not silently invent one R0. It performs a controlled
% sensitivity sweep:
%
%       R0 = platform_height * slant_range_factor
%
% These factors are numerical sensitivity settings, NOT Wang parameters.
cfg.slant_range_factor = [1.0, sqrt(2), 2.0];
cfg.representative_slant_range_factor = sqrt(2);

%% Azimuth sample-count uncertainty
% Wang Table 1/2 does not give the exact azimuth-line length used in the
% one-line MC-LFM experiment.
%
% These are controlled numerical settings, not paper-reported values.
cfg.azimuth_samples = [256, 512, 1024];
cfg.representative_azimuth_samples = 512;

%% MC-LFM controlled parameters
% Wang Eq. (13) allows component-specific center frequencies b_i, but the
% five-point experiment does not report exact b_i or component amplitudes.
% P1 isolates chirp-rate/ORO separability:
cfg.component_amplitudes = ones(1,5);
cfg.component_center_frequency_hz = zeros(1,5);

% Unknown initial phases are handled by a reproducible phase Monte Carlo.
cfg.num_phase_mc = 200;
cfg.phase_seed = 20230910;

%% Matched-chirp diagnostic
% P1 uses a chirp-rate matched-response bank as a convention-light proxy
% for the FrFT energy-concentration principle. Wang states that FrFT at
% the ORO re-matches the LFM component.
cfg.k_grid_oversample = 160;         % points per minimum true separation
cfg.k_grid_margin_separations = 2.0; % search margin on both sides

%% Numerical gate settings
% These are diagnostic criteria, not literature parameters.
cfg.peak_match_tolerance_fraction = 0.35;
cfg.min_sep_over_3db_width_gate = 1.0;
cfg.phase_mc_all5_rate_gate = 0.80;

%% Figure/output
cfg.figure_visible = 'off';
cfg.output_dir = '';

end
