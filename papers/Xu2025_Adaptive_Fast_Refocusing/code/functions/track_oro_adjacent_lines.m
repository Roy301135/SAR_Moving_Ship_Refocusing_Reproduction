function [p_est, eval_count, boundary_hit, init_order] = ...
    track_oro_adjacent_lines(X, p_full, search_step, delta, ...
                             n, kappa, max_lag, init_idx)
%TRACK_ORO_ADJACENT_LINES Adjacent-line ORO tracking for AFRA-style reuse.
%
% Inputs:
%   X           - N x Nline complex matrix; each column is one azimuth signal
%                 associated with one spatial/range cell.
%   p_full      - full candidate ORO grid used for initialization
%   search_step - local order-search step
%   delta       - half width of the local tracking window
%   n           - centered slow-time sample indices
%   kappa       - normalized chirp-slope scale
%   max_lag     - maximum integer delay for FrAc energy
%   init_idx    - index of the maximum-energy line used for initialization
%
% Outputs:
%   p_est        - estimated dominant ORO for every line
%   eval_count   - total number of candidate-order evaluations
%   boundary_hit - logical vector; true if the local maximum lies at a
%                  search-window boundary (useful as a failure warning)
%   init_order   - ORO estimated on the initialization line
%
% Mechanism:
%   1) Full-search the strongest line.
%   2) Use its estimated ORO as the center for the adjacent line.
%   3) Re-estimate that adjacent line inside [p_prev-delta, p_prev+delta].
%   4) Continue recursively to both sides.
%
% This isolates the adjacent-line prior described in Xu et al. (JSTARS 2025).
% It does not implement the paper's full three-stage multi-component CLEAN
% refocusing pipeline.

Nline = size(X, 2);

p_est = nan(1, Nline);
boundary_hit = false(1, Nline);
eval_count = 0;

full_low = p_full(1);
full_high = p_full(end);

%% 1. Full-search initialization line
E0 = compute_frac_energy_map(X(:, init_idx), p_full, n, kappa, max_lag);
[~, idx0] = max(E0(:,1));

p_est(init_idx) = p_full(idx0);
init_order = p_est(init_idx);
eval_count = eval_count + numel(p_full);

%% 2. Propagate to the right
for iline = (init_idx+1):Nline
    [p_local, hit_guard] = local_grid( ...
        p_est(iline-1), delta, search_step, full_low, full_high);

    E_local = compute_frac_energy_map( ...
        X(:, iline), p_local, n, kappa, max_lag);

    [~, imax] = max(E_local(:,1));
    p_est(iline) = p_local(imax);

    boundary_hit(iline) = hit_guard || (imax == 1) || (imax == numel(p_local));
    eval_count = eval_count + numel(p_local);
end

%% 3. Propagate to the left
for iline = (init_idx-1):-1:1
    [p_local, hit_guard] = local_grid( ...
        p_est(iline+1), delta, search_step, full_low, full_high);

    E_local = compute_frac_energy_map( ...
        X(:, iline), p_local, n, kappa, max_lag);

    [~, imax] = max(E_local(:,1));
    p_est(iline) = p_local(imax);

    boundary_hit(iline) = hit_guard || (imax == 1) || (imax == numel(p_local));
    eval_count = eval_count + numel(p_local);
end

end

function [p_local, clipped] = local_grid(center, delta, step, full_low, full_high)
%LOCAL_GRID Construct a local tracking grid on the same global step lattice.

low = center - delta;
high = center + delta;

clipped = (low < full_low) || (high > full_high);

low = max(low, full_low);
high = min(high, full_high);

% Snap to a fixed lattice to make evaluation counts reproducible.
low = ceil(low / step) * step;
high = floor(high / step) * step;

if high < low
    p_local = center;
else
    p_local = low : step : high;
end

end
