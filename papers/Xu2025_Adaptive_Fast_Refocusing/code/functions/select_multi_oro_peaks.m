function [q_sel, peak_energy, peak_idx] = ...
    select_multi_oro_peaks(E_col, q_grid, n_keep, min_sep)
%SELECT_MULTI_ORO_PEAKS Select strongest separated local maxima.
%
% Inputs:
%   E_col   : FrAc energy vector for one line
%   q_grid  : corresponding order grid
%   n_keep  : maximum number of ORO peaks to keep
%   min_sep : minimum separation in order units between selected peaks
%
% Outputs:
%   q_sel       : selected OROs, sorted by descending FrAc energy
%   peak_energy : corresponding peak energies
%   peak_idx    : indices in q_grid
%
% Notes:
%   - No hard relative-amplitude threshold is imposed here. This is
%     intentional for EXP08: if a true weak component leaves the ORI,
%     the algorithm may select a wrong residual/noise peak instead, and
%     component recall will explicitly reveal the failure.
%   - Local maxima are detected toolbox-free.

E_col = E_col(:);
q_grid = q_grid(:);

if numel(E_col) ~= numel(q_grid)
    error('E_col and q_grid must have the same length.');
end

N = numel(E_col);

if N == 1
    q_sel = q_grid;
    peak_energy = E_col;
    peak_idx = 1;
    return;
end

is_peak = false(N,1);

is_peak(1) = E_col(1) >= E_col(2);
is_peak(N) = E_col(N) >= E_col(N-1);

for ii = 2:(N-1)
    is_peak(ii) = ...
        (E_col(ii) >= E_col(ii-1)) && ...
        (E_col(ii) >= E_col(ii+1));
end

cand_idx = find(is_peak);

% Always include the global maximum.
[~, idx_global] = max(E_col);
if ~ismember(idx_global, cand_idx)
    cand_idx(end+1,1) = idx_global;
end

[~, ord] = sort(E_col(cand_idx), 'descend');
cand_idx = cand_idx(ord);

selected = [];

for kk = 1:numel(cand_idx)

    idx = cand_idx(kk);
    q = q_grid(idx);

    if isempty(selected)
        selected = idx;
    else
        q_existing = q_grid(selected);

        if all(abs(q - q_existing) >= min_sep)
            selected(end+1,1) = idx; %#ok<AGROW>
        end
    end

    if numel(selected) >= n_keep
        break;
    end
end

% If too few local maxima survive, fill with strongest remaining samples
% that also satisfy the minimum separation.
if numel(selected) < n_keep

    [~, all_ord] = sort(E_col, 'descend');

    for kk = 1:numel(all_ord)

        idx = all_ord(kk);

        if ismember(idx, selected)
            continue;
        end

        q = q_grid(idx);

        if isempty(selected) || ...
                all(abs(q - q_grid(selected)) >= min_sep)

            selected(end+1,1) = idx; %#ok<AGROW>
        end

        if numel(selected) >= n_keep
            break;
        end
    end
end

peak_idx = selected(:);
q_sel = q_grid(peak_idx);
peak_energy = E_col(peak_idx);

% Keep strongest-first order for sequential CLEAN.
[peak_energy, ord2] = sort(peak_energy, 'descend');
peak_idx = peak_idx(ord2);
q_sel = q_sel(ord2);

q_sel = q_sel(:).';
peak_energy = peak_energy(:).';
peak_idx = peak_idx(:).';

end
