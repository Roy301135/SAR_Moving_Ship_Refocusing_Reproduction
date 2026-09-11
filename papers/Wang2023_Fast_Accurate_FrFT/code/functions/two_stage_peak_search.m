function result = two_stage_peak_search( ...
    x, t, u, h_coarse, h_fine, p_bounds)
%TWO_STAGE_PEAK_SEARCH
% Traditional FrFT two-stage traversal based on maximum peak.
%
% The implementation follows the computational structure discussed in
% Wang et al. (2023):
%
%   1. Traverse the whole FrFT-order interval using a coarse step.
%   2. Find the order whose FrFT has the largest peak.
%   3. Traverse a local interval of width approximately 2*h_coarse
%      using the fine step.
%
% With:
%
%   h_coarse = 0.1
%   h_fine   = 0.005
%
% and an order interval of length approximately 2, this requires about:
%
%   20 coarse evaluations
%   40 fine evaluations
%
% corresponding to the approximately 60 FrFT evaluations reported for the
% traditional search structure in the paper.
%
% Inputs
% -------------------------------------------------------------------------
% x
% t
% u
% h_coarse
% h_fine
% p_bounds
%
% Output fields
% -------------------------------------------------------------------------
% result.p_opt
% result.peak_opt
% result.n_frft
% result.p_coarse
% result.peak_coarse
% result.p_fine
% result.peak_fine

    p_min = p_bounds(1);
    p_max = p_bounds(2);

    %% 1. Coarse traversal
    %
    % Use cell centers rather than the singular p = 0 and p = 2
    % endpoints.

    p_coarse = ...
        (h_coarse/2) : h_coarse : (2-h_coarse/2);

    p_coarse = p_coarse( ...
        p_coarse >= p_min & ...
        p_coarse <= p_max);

    peak_coarse = zeros(size(p_coarse));

    n_frft = 0;

    for ii = 1:numel(p_coarse)

        Xp = frft_direct( ...
            x, t, p_coarse(ii), u);

        peak_coarse(ii) = ...
            max(abs(Xp).^2);

        n_frft = n_frft + 1;
    end

    [~, idx_coarse] = max(peak_coarse);

    p_coarse_opt = ...
        p_coarse(idx_coarse);

    %% 2. Fine traversal
    fine_left = ...
        max(p_min, p_coarse_opt - h_coarse);

    fine_right = ...
        min(p_max, p_coarse_opt + h_coarse);

    % Excluding the left endpoint gives approximately
    % 2*h_coarse/h_fine evaluations.
    p_fine = ...
        (fine_left + h_fine) : ...
        h_fine : ...
        fine_right;

    peak_fine = zeros(size(p_fine));

    for ii = 1:numel(p_fine)

        Xp = frft_direct( ...
            x, t, p_fine(ii), u);

        peak_fine(ii) = ...
            max(abs(Xp).^2);

        n_frft = n_frft + 1;
    end

    [peak_opt, idx_fine] = ...
        max(peak_fine);

    p_opt = ...
        p_fine(idx_fine);

    %% 3. Output
    result = struct();

    result.p_opt = p_opt;
    result.peak_opt = peak_opt;

    result.n_frft = n_frft;

    result.p_coarse = p_coarse;
    result.peak_coarse = peak_coarse;

    result.p_coarse_opt = p_coarse_opt;

    result.p_fine = p_fine;
    result.peak_fine = peak_fine;

end