function [p_est, eval_count, boundary_hit, delta_used, fallback_full] = ...
    track_oro_adaptive_window(X, p_full, search_step, delta_levels, ...
                              n, kappa, max_lag, init_idx)
%TRACK_ORO_ADAPTIVE_WINDOW Boundary-aware adaptive ORO tracking.
%
% This is an exploratory extension motivated by the failure mode observed
% in EXP05. It is NOT claimed to be part of Xu et al. (JSTARS, 2025).
%
% Mechanism:
%   1) Full-search the strongest initialization line.
%   2) For each adjacent line, begin with the smallest local window.
%   3) If the local FrAc maximum lies at a search boundary, enlarge Delta
%      and re-evaluate the CURRENT line.
%   4) If all local Delta levels still end at a boundary, fall back to a
%      full search for that line.
%
% Inputs:
%   X             - N x Nline complex signal matrix
%   p_full        - full candidate ORO grid
%   search_step   - ORO grid step
%   delta_levels  - ascending local half-width candidates, e.g.
%                   [0.01 0.02 0.04 0.08]
%   n             - centered slow-time indices
%   kappa         - normalized chirp-slope scale
%   max_lag       - maximum integer delay for FrAc
%   init_idx      - strongest-line initialization index
%
% Outputs:
%   p_est         - estimated ORO for every line
%   eval_count    - total candidate-order evaluations
%   boundary_hit  - whether any local search hit a boundary on that line
%   delta_used    - final local half width used for each line
%                   NaN on initialization/fallback-full lines
%   fallback_full - true when the line required a full-search fallback

Nline = size(X,2);

p_est = nan(1,Nline);
boundary_hit = false(1,Nline);
delta_used = nan(1,Nline);
fallback_full = false(1,Nline);

eval_count = 0;

full_low = p_full(1);
full_high = p_full(end);

%% 1. Strongest-line full-search initialization
E0 = compute_frac_energy_map(X(:,init_idx), p_full, n, kappa, max_lag);
[~,idx0] = max(E0(:,1));

p_est(init_idx) = p_full(idx0);
eval_count = eval_count + numel(p_full);

%% 2. Propagate right
for iline = (init_idx+1):Nline
    [p_est(iline), add_eval, hit_any, used_delta, did_fallback] = ...
        estimate_one_line(X(:,iline), p_est(iline-1), ...
                          p_full, search_step, delta_levels, ...
                          n, kappa, max_lag, full_low, full_high);

    eval_count = eval_count + add_eval;
    boundary_hit(iline) = hit_any;
    delta_used(iline) = used_delta;
    fallback_full(iline) = did_fallback;
end

%% 3. Propagate left
for iline = (init_idx-1):-1:1
    [p_est(iline), add_eval, hit_any, used_delta, did_fallback] = ...
        estimate_one_line(X(:,iline), p_est(iline+1), ...
                          p_full, search_step, delta_levels, ...
                          n, kappa, max_lag, full_low, full_high);

    eval_count = eval_count + add_eval;
    boundary_hit(iline) = hit_any;
    delta_used(iline) = used_delta;
    fallback_full(iline) = did_fallback;
end

end

function [p_hat, eval_count, hit_any, used_delta, did_fallback] = ...
    estimate_one_line(xline_sig, center, p_full, search_step, ...
                      delta_levels, n, kappa, max_lag, ...
                      full_low, full_high)

eval_count = 0;
hit_any = false;
used_delta = NaN;
did_fallback = false;

for id = 1:numel(delta_levels)

    delta = delta_levels(id);

    p_local = local_grid(center, delta, search_step, full_low, full_high);

    E_local = compute_frac_energy_map( ...
        xline_sig, p_local, n, kappa, max_lag);

    eval_count = eval_count + numel(p_local);

    [~,imax] = max(E_local(:,1));
    p_candidate = p_local(imax);

    is_boundary = (imax == 1) || (imax == numel(p_local));

    if ~is_boundary
        p_hat = p_candidate;
        used_delta = delta;
        return;
    end

    hit_any = true;
end

% If the peak stays at the local-search boundary even at the widest local
% window, reinitialize this line with a full search.
E_full = compute_frac_energy_map( ...
    xline_sig, p_full, n, kappa, max_lag);

eval_count = eval_count + numel(p_full);

[~,imax] = max(E_full(:,1));
p_hat = p_full(imax);

did_fallback = true;
used_delta = NaN;

end

function p_local = local_grid(center, delta, step, full_low, full_high)

low = max(center-delta, full_low);
high = min(center+delta, full_high);

low = ceil(low/step)*step;
high = floor(high/step)*step;

if high < low
    p_local = center;
else
    p_local = low:step:high;
end

end
