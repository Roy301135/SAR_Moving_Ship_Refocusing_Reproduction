function [G_focus, g_left, info] = extract_one_lfm_component( ...
    g, t_norm, u_norm, p, win_half, peak_ratio)
%EXTRACT_ONE_LFM_COMPONENT One sequential FrFT/CLEAN extraction stage.
%
% Purpose:
%   Given ONE estimated refocusing order p, focus the current residual
%   signal, keep the strong narrow fractional-domain peak(s), subtract the
%   focused component, and return the residual to the input coordinate.
%
% Inputs
%   g          : current complex residual signal
%   t_norm     : normalized input coordinate
%   u_norm     : normalized FrFT output coordinate
%   p          : FrFT refocusing order
%   win_half   : half width of each extraction window [samples]
%   peak_ratio : local-peak threshold relative to current FrFT maximum
%
% Outputs
%   G_focus    : extracted focused component in the fractional domain
%   g_left     : residual returned to the input/time-domain coordinate
%   info       : diagnostic structure
%
% Notes:
%   - frft_direct.m must already be on the MATLAB path.
%   - This helper is intentionally single-stage so EXP08 can alternate:
%         FrAc ORO detection -> FrFT/CLEAN peel -> FrAc on residual.
%
% This is the key correction relative to the preliminary EXP08, which tried
% to recover three OROs from one unpeeled FrAc spectrum.

was_column = iscolumn(g);

g_work = g(:).';
t_norm = t_norm(:).';
u_norm = u_norm(:).';

N = numel(g_work);

Gp = frft_direct(g_work, t_norm, p, u_norm);
Gp = Gp(:).';

mag = abs(Gp);
max_mag = max(mag);

peak_idx = local_peak_indices(mag, peak_ratio * max_mag);

if isempty(peak_idx)
    [~,idx_global] = max(mag);
    peak_idx = idx_global;
end

mask = false(1,N);

for kk = 1:numel(peak_idx)
    lo = max(1, peak_idx(kk)-win_half);
    hi = min(N, peak_idx(kk)+win_half);
    mask(lo:hi) = true;
end

G_focus = zeros(1,N);
G_focus(mask) = Gp(mask);

G_left = Gp - G_focus;

g_left = frft_direct(G_left, u_norm, -p, t_norm);
g_left = g_left(:).';

info = struct();
info.n_peaks = numel(peak_idx);
info.peak_indices = peak_idx;
info.mask_fraction = mean(mask);
info.focus_peak = max(abs(G_focus));
info.residual_energy_ratio = ...
    sum(abs(g_left).^2) / max(sum(abs(g_work).^2),eps);

if was_column
    G_focus = G_focus.';
    g_left = g_left.';
end

end

function idx = local_peak_indices(y, threshold)

N = numel(y);

if N == 1
    if y(1) >= threshold
        idx = 1;
    else
        idx = [];
    end
    return;
end

is_peak = false(1,N);

is_peak(1) = y(1) >= y(2);
is_peak(N) = y(N) >= y(N-1);

for ii = 2:(N-1)
    is_peak(ii) = ...
        (y(ii) >= y(ii-1)) && ...
        (y(ii) >= y(ii+1));
end

idx = find(is_peak & (y >= threshold));

end
