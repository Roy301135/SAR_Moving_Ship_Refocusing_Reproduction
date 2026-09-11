function [g_refocus, g_left, info] = refocus_mc_lfm_clean( ...
    g, t_norm, u_norm, p_set, win_half, peak_ratio)
%REFOCUS_MC_LFM_CLEAN Xu-2025-style sequential MC-LFM refocusing.
%
% Source mechanism:
%   Xu et al., JSTARS 2025, Sec. IV-C "Azimuth Refocus"
%
%   1) FrFT the current residual signal at ORO p_i.
%   2) Detect strong peaks in the fractional domain.
%   3) Extract the focused component with narrow windows.
%   4) Subtract the focused component.
%   5) Inverse-FrFT the residual.
%   6) Continue sequentially for ALL OROs supplied in p_set.
%
% IMPORTANT:
%   The previous preliminary EXP07 implementation also used the 0.7
%   inter-component STOP rule from Wang et al. (Remote Sensing, 2023).
%   Xu 2025 does not specify that stop rule in its azimuth-refocus section;
%   it states that all LFM components can be refocused sequentially and
%   accumulated. Therefore this revised helper deliberately processes every
%   ORO in p_set and does NOT stop early based on component amplitude.
%
% Inputs
%   g           : complex MC-LFM azimuth-line signal
%   t_norm      : normalized input coordinate
%   u_norm      : normalized fractional coordinate
%   p_set       : ORO set to process, in sequential order
%   win_half    : half-width of each narrow extraction window [samples]
%   peak_ratio  : local peak threshold relative to the current FrFT maximum
%
% Outputs
%   g_refocus   : accumulated focused fractional-domain components
%   g_left      : final residual returned to the input/time-domain coordinate
%   info        : diagnostic structure
%
% Notes
%   - The exact discrete bandpass-window width is not reported by Xu 2025;
%     win_half remains an explicit controlled experiment parameter.
%   - peak_ratio=0.7 is retained only as a controlled peak-selection rule
%     inherited from the predecessor Wang implementation. It is NOT used as
%     an inter-component stopping criterion.
%   - frft_direct.m must already be on the MATLAB path.

was_column = iscolumn(g);

g_work = g(:).';
t_norm = t_norm(:).';
u_norm = u_norm(:).';

N = numel(g_work);
Q = numel(p_set);

g_refocus = zeros(1, N);
g_left = g_work;

peak_values = nan(1, Q);
n_peaks = zeros(1, Q);
mask_fraction = zeros(1, Q);
residual_energy_ratio_after_stage = nan(1, Q);

for ii = 1:Q

    p_i = p_set(ii);

    % Transform the CURRENT residual at the current ORO.
    Gp = frft_direct(g_left, t_norm, p_i, u_norm);
    Gp = Gp(:).';

    mag = abs(Gp);
    max_mag = max(mag);

    % Detect local maxima above a fraction of the current maximum.
    peak_idx = local_peak_indices(mag, peak_ratio * max_mag);

    if isempty(peak_idx)
        [~, idx_global] = max(mag);
        peak_idx = idx_global;
    end

    % Narrow-band extraction around all accepted peaks.
    mask = false(1, N);

    for kk = 1:numel(peak_idx)
        lo = max(1, peak_idx(kk) - win_half);
        hi = min(N, peak_idx(kk) + win_half);
        mask(lo:hi) = true;
    end

    G_focus_i = zeros(1, N);
    G_focus_i(mask) = Gp(mask);

    % Xu-2025-style accumulation of sequentially refocused components.
    g_refocus = g_refocus + G_focus_i;

    % Subtract in the fractional domain.
    G_left = Gp - G_focus_i;

    % Return the residual to the input/time-domain coordinate before the
    % next component is processed.
    g_left = frft_direct(G_left, u_norm, -p_i, t_norm);
    g_left = g_left(:).';

    peak_values(ii) = max(abs(G_focus_i));
    n_peaks(ii) = numel(peak_idx);
    mask_fraction(ii) = mean(mask);

    residual_energy_ratio_after_stage(ii) = ...
        sum(abs(g_left).^2) / max(sum(abs(g_work).^2), eps);
end

info = struct();
info.n_order_requested = Q;
info.n_order_used = Q;
info.peak_values = peak_values;
info.n_peaks = n_peaks;
info.mask_fraction = mask_fraction;
info.residual_energy_ratio_after_stage = residual_energy_ratio_after_stage;
info.residual_energy_ratio = ...
    sum(abs(g_left).^2) / max(sum(abs(g_work).^2), eps);

if was_column
    g_refocus = g_refocus.';
    g_left = g_left.';
end

end

function idx = local_peak_indices(y, threshold)
% Toolbox-free 1-D local maxima above threshold.

N = numel(y);

if N == 1
    if y(1) >= threshold
        idx = 1;
    else
        idx = [];
    end
    return;
end

is_peak = false(1, N);

is_peak(1) = (y(1) >= y(2));
is_peak(N) = (y(N) >= y(N-1));

for ii = 2:(N-1)
    is_peak(ii) = (y(ii) >= y(ii-1)) && (y(ii) >= y(ii+1));
end

idx = find(is_peak & (y >= threshold));

end
