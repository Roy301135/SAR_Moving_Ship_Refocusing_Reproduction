function result = minimum_entropy_search( ...
    x, t, u, p_initial, h_coarse, h_fine, p_bounds)
%MINIMUM_ENTROPY_SEARCH
% Advance-and-retreat minimum-entropy FrFT order search.
%
% result = minimum_entropy_search( ...
%     x, t, u, p_initial, h_coarse, h_fine, p_bounds)
%
% Implements the mechanism described in Section 3.3 of Wang et al. (2023):
%
%   1. Start from an initial FrFT order.
%   2. Evaluate entropy at p and p+h.
%   3. Determine the entropy-decreasing direction.
%   4. Move in that direction until entropy increases.
%   5. Use the coarse minimum as the initial value of a fine search.
%
% Inputs
% -------------------------------------------------------------------------
% x          : signal
% t          : normalized input coordinate
% u          : normalized FrFT output coordinate
% p_initial  : initial FrFT order
% h_coarse   : coarse search step
% h_fine     : fine search step
% p_bounds   : [p_min p_max]
%
% Output fields
% -------------------------------------------------------------------------
% result.p_opt
% result.entropy_opt
% result.n_frft
% result.p_history
% result.entropy_history
% result.stage_history
% result.p_coarse
% result.entropy_coarse
%
% Note
% -------------------------------------------------------------------------
% Every actual call of frft_direct is counted.
% No caching is used, so n_frft reflects the literal implementation cost.

    arguments
        x
        t
        u
        p_initial (1,1) double
        h_coarse (1,1) double {mustBePositive}
        h_fine (1,1) double {mustBePositive}
        p_bounds (1,2) double
    end

    p_min = p_bounds(1);
    p_max = p_bounds(2);

    if p_min >= p_max
        error('Invalid p_bounds.');
    end

    p_initial = min(max(p_initial, p_min), p_max);

    p_history = [];
    entropy_history = [];
    stage_history = strings(0,1);

    n_frft = 0;

    %% Coarse stage
    coarse = run_directional_stage( ...
        p_initial, ...
        h_coarse, ...
        "coarse");

    %% Fine stage
    fine = run_directional_stage( ...
        coarse.p_opt, ...
        h_fine, ...
        "fine");

    result = struct();

    result.p_opt = fine.p_opt;
    result.entropy_opt = fine.entropy_opt;

    result.p_coarse = coarse.p_opt;
    result.entropy_coarse = coarse.entropy_opt;

    result.n_frft = n_frft;

    result.p_history = p_history;
    result.entropy_history = entropy_history;
    result.stage_history = stage_history;

    %% -------------------------------------------------------------
    function stage = run_directional_stage(p_start, h_abs, stage_name)

        p0 = min(max(p_start, p_min), p_max);

        E0 = evaluate_entropy(p0, stage_name);

        % First trial: positive direction.
        h = abs(h_abs);

        p1 = p0 + h;

        % If positive direction immediately exceeds the valid interval,
        % try the negative direction instead.
        if p1 > p_max
            h = -h;
            p1 = p0 + h;
        end

        % If neither direction is available, return p0.
        if p1 < p_min || p1 > p_max

            stage.p_opt = p0;
            stage.entropy_opt = E0;

            return;
        end

        E1 = evaluate_entropy(p1, stage_name);

        %% Determine downhill direction
        if E1 >= E0

            % Positive direction is uphill.
            % Reverse the direction and test the other side.
            h = -h;

            p1 = p0 + h;

            if p1 < p_min || p1 > p_max

                stage.p_opt = p0;
                stage.entropy_opt = E0;

                return;
            end

            E1 = evaluate_entropy(p1, stage_name);

            % If both sides are higher, p0 is already a local minimum
            % at the current search resolution.
            if E1 >= E0

                stage.p_opt = p0;
                stage.entropy_opt = E0;

                return;
            end
        end

        %% We now know that E1 < E0.
        % Continue in this downhill direction until entropy increases.

        p_current = p1;
        E_current = E1;

        while true

            p_next = p_current + h;

            if p_next < p_min || p_next > p_max
                break;
            end

            E_next = evaluate_entropy( ...
                p_next, ...
                stage_name);

            if E_next >= E_current
                break;
            end

            p_current = p_next;
            E_current = E_next;
        end

        stage.p_opt = p_current;
        stage.entropy_opt = E_current;
    end

    %% -------------------------------------------------------------
    function H = evaluate_entropy(p, stage_name)

        Xp = frft_direct(x, t, p, u);

        H = signal_entropy(Xp);

        n_frft = n_frft + 1;

        p_history(end+1,1) = p;
        entropy_history(end+1,1) = H;
        stage_history(end+1,1) = stage_name;
    end

end