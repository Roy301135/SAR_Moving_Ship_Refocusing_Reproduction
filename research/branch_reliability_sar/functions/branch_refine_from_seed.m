function out = branch_refine_from_seed(z, seed_bins, stage_cfg)
%BRANCH_REFINE_FROM_SEED Inherited PA5I/EXP010 local refinement semantics.
%
% 1) Search seed +/- 0.75 bin on 33 bracket samples.
% 2) Take the best bracket sample.
% 3) fminbnd only between its immediate neighboring bracket samples.

lb = seed_bins - stage_cfg.local_search_halfwidth_bins;
ub = seed_bins + stage_cfg.local_search_halfwidth_bins;
grid = linspace(lb,ub,stage_cfg.local_bracket_points);
J = branch_tone_objective(z,grid);

[~,ib] = max(J);
i1 = max(1,ib-1);
i2 = min(numel(grid),ib+1);
local_lb = grid(i1);
local_ub = grid(i2);

neval = numel(grid);
if local_ub <= local_lb
    nu_hat = grid(ib);
    Jhat = J(ib);
else
    count = 0;
    opts = optimset('Display','off', ...
        'TolX',stage_cfg.local_tolx_bins, ...
        'MaxFunEvals',stage_cfg.local_max_fun_evals);
    [nu_hat,fval] = fminbnd(@wrapped_obj,local_lb,local_ub,opts);
    Jhat = -fval;
    neval = neval + count;
end

out.seed_bins = seed_bins;
out.nu_hat_bins = nu_hat;
out.objective_at_hat = Jhat;
out.n_objective_evals = neval;
out.bracket_grid_bins = grid;
out.bracket_objective = J;

    function y = wrapped_obj(q)
        count = count + 1;
        y = -branch_tone_objective(z,q);
    end
end
