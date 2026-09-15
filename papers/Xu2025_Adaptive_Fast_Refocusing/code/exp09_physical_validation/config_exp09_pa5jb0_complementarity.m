function cfg = config_exp09_pa5jb0_complementarity()
%CONFIG_EXP09_PA5JB0_FAILURE_CONDITIONAL_INDICATOR_COMPLEMENTARITY
% Frozen PA5J-B0 engineering configuration. No scientific values are tuned.
cfg.pa5ja_folder_name = 'exp09_pa5ja_indicator_discovery';
cfg.original_trials_name = 'pa5ja_indicator_trials_original.csv';
cfg.dense_trials_name = 'pa5ja_indicator_trials_dense_risk.csv';
cfg.output_folder_name = 'exp09_pa5jb0_failure_conditional_indicator_complementarity';
cfg.output_dir = '';
cfg.figure_visible = 'off';
cfg.indicators = ["refined_lr_asymmetry","fivebin_peak_fraction","local_entropy5"];
cfg.risk_directions = ["high","low","high"];
cfg.budgets = [0,0.005,0.01,0.02,0.05,0.10,0.20,0.30,0.50,0.75,1];
cfg.wilson_z = 1.959963984540054;
cfg.expected_sources = ["original_grid","dense_risk"];
cfg.expected_apertures = ["Paper1s","BeamDerived"];
cfg.identity_fields = ["source","aperture_mode","azimuth_samples", ...
    "delta_velocity_mps","strong_velocity_side","strong_velocity_mps", ...
    "weak_to_strong_ratio","relative_phase_rad","true_eta_bins"];
end
