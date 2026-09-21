function A = branch_g0_neighbor3_audit(x, a_dechirp, nu_reference_bins, stage_cfg)
%BRANCH_G0_NEIGHBOR3_AUDIT
% Mechanism-only branch audit using frozen PA5I/EXP010 local semantics.
%
% Inputs:
%   x                  observed physical mixture (row vector)
%   a_dechirp          oracle strong chirp parameter for Stage-B only
%   nu_reference_bins  evaluation-only strong branch reference
%
% Outputs include coarse G0, refined G0, Neighbor-3, and a full-period
% continuous global reference. Proposed scheduler is intentionally absent.

x = x(:).';
N = numel(x);
m = 0:N-1;
z = x .* exp(-1j*pi*a_dechirp.*m.^2);

%% Coarse DFT Top-1
Y = fftshift(fft(z));
bins = -floor(N/2):(ceil(N/2)-1);
Jcoarse = abs(Y).^2;
[~,i0] = max(Jcoarse);
k0 = bins(i0);

%% G0 local refinement
G0 = branch_refine_from_seed(z,k0,stage_cfg);

%% Neighbor-3 local branch redundancy
seeds = k0 + (-stage_cfg.neighbor_radius:stage_cfg.neighbor_radius);
Ncand = numel(seeds);

if Ncand < 1
    error('branch_g0_neighbor3_audit:EmptyNeighborSet', ...
        'Neighbor candidate set is empty. Check stage_cfg.neighbor_radius.');
end

% IMPORTANT:
% Preallocate from a real returned prototype rather than repmat(struct(),...).
% MATLAB does not allow indexed assignment between structures with different
% field sets, so an empty field-less struct cannot safely receive the output
% of branch_refine_from_seed(). This prototype-based pattern should also be
% used for future arrays of result structs.
first_cand = branch_refine_from_seed(z,seeds(1),stage_cfg);
N3cand = repmat(first_cand,Ncand,1);
N3cand(1) = first_cand;

for i = 2:Ncand
    N3cand(i) = branch_refine_from_seed(z,seeds(i),stage_cfg);
end

[~,ibest] = max([N3cand.objective_at_hat]);
N3 = N3cand(ibest);

%% Evaluation-only full-period global continuous reference
% A full-period zero-padded FFT gives exact samples of the same tone
% objective on a 1/global_oversample bin grid. We then fminbnd only between
% the neighboring oversampled points around the best sample. This is much
% cheaper than a 1e-3-bin direct scan and does not assume where the branch
% should lie. This reference NEVER enters a method path.
os = stage_cfg.global_oversample;
L = N * os;
Yos = fftshift(fft(z,L));
if mod(L,2)==0
    k_os = -L/2:(L/2-1);
else
    k_os = -floor(L/2):floor(L/2);
end
qgrid = k_os .* (N/L);
Jgrid = abs(Yos).^2;
[~,ig] = max(Jgrid);
i1 = max(1,ig-1);
i2 = min(numel(qgrid),ig+1);
ref_lb = qgrid(i1);
ref_ub = qgrid(i2);
count = 0;
if ref_ub <= ref_lb
    nu_global = qgrid(ig);
    Jglobal = Jgrid(ig);
else
    opts = optimset('Display','off', ...
        'TolX',stage_cfg.global_tolx_bins, ...
        'MaxFunEvals',stage_cfg.global_max_fun_evals);
    [nu_global,fval] = fminbnd(@wrapped_global,ref_lb,ref_ub,opts);
    Jglobal = -fval;
end

%% Evaluation metrics
err_g0 = circular_bin_distance(G0.nu_hat_bins,nu_reference_bins,N);
err_n3 = circular_bin_distance(N3.nu_hat_bins,nu_reference_bins,N);
err_global = circular_bin_distance(nu_global,nu_reference_bins,N);

g0_cat = err_g0 > stage_cfg.catastrophic_error_threshold_bins;
n3_cat = err_n3 > stage_cfg.catastrophic_error_threshold_bins;
n3_rescue = g0_cat && ~n3_cat;

% Top coarse bins for compact feedback.
[Js,ord] = sort(Jcoarse,'descend');
ntop = min(5,numel(ord));
top_bins = bins(ord(1:ntop));
top_scores = Js(1:ntop) / max(Js(1),eps);

A.N = N;
A.dechirped_signal = z;
A.coarse_bins = bins;
A.coarse_objective = Jcoarse;
A.coarse_top1_bin = k0;
A.coarse_top_bins = top_bins;
A.coarse_top_scores_normalized = top_scores;
A.G0 = G0;
A.N3 = N3;
A.N3_candidates = N3cand;
A.global_nu_bins = nu_global;
A.global_objective = Jglobal;
A.reference_nu_bins = nu_reference_bins;
A.g0_error_bins = err_g0;
A.n3_error_bins = err_n3;
A.global_error_bins = err_global;
A.g0_catastrophic = g0_cat;
A.n3_catastrophic = n3_cat;
A.n3_rescue = n3_rescue;
A.n3_total_evals = sum([N3cand.n_objective_evals]);
A.global_grid_count = numel(qgrid);
A.global_oversample = os;
A.global_refine_evals = count;

    function y = wrapped_global(q)
        count = count + 1;
        y = -branch_tone_objective(z,q);
    end
end

function d = circular_bin_distance(a,b,N)
% Distance on the N-bin periodic frequency coordinate.
d = abs(mod((a-b)+N/2,N)-N/2);
end
