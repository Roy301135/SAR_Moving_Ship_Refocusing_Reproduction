function cfg = config_exp02_fair_r0()
%CONFIG_EXP02_FAIR_R0 Frozen configuration for FAIR-CSAR R0.
%
% EXP02-FAIR-R0
% Source-Aligned MC-LFM / FrAc Compatibility Audit
%
% Scientific boundary:
%   - ONE pre-registered FAIR-CSAR candidate only.
%   - No G0 / Neighbor-3 / Proposed.
%   - No branch taxonomy.
%   - No parameter tuning from observed outcomes.
%   - This stage asks only whether a real, dataset-labeled motion-defocused
%     GF-3 SL target exhibits target-specific fractional-domain structure
%     compatible with the Wang/Xu MC-LFM processing object.
%
% Required data location:
%   <repo>/data/fair_csar/pilot_candidate_B/
%       SLCMats/<stem>.mat
%       PNGImages/<stem>.png
%       METAXmls/<stem>.xml
%
% The validated project FrFT implementation is reused from:
%   papers/Wang2023_Fast_Accurate_FrFT/code/functions/frft_direct.m

cfg = struct();

%% Frozen candidate
cfg.stem = [ ...
    'GF3_KAS_SL_028685_E139.7_N35.5_20220120_' ...
    'L1A_HH_L10000000001_00000_16050'];

%% Crop / line selection
cfg.crop_margin_px = 32;

% Wang-style target-line selection inside the frozen ship crop:
%   E(n) > mean_n E(n)
cfg.target_energy_rule = 'above_mean';

% Limit only for computational cost; selected lines are evenly subsampled
% in range-column order, not selected by fractional-domain outcome.
cfg.max_lines_per_group = 12;

% Deterministic adjacent-sea background controls.
cfg.bg_gap_px = 64;
cfg.bg_band_width_px = 128;

%% Fractional-domain audit
% Preserve the validated project FrFT convention used in the Wang/Xu
% reproduction line. This is deliberately broad and is NOT an ORI-tuned
% search.
cfg.p_grid = 0.10 : 0.02 : 1.90;

% FrAc score excludes zero lag. A small exclusion around zero lag avoids
% letting trivial total-energy autocorrelation dominate the diagnostic.
cfg.frac_exclude_zero_lags = 2;

%% Guard thresholds (engineering integrity only, not a science PASS rule)
cfg.min_png_corr = 0.85;

%% Plot/export
cfg.figure_resolution = 180;

end
