function A = branch_real_g0_neighbor3_audit(x,a_dechirp,stage_cfg)
%BRANCH_REAL_G0_NEIGHBOR3_AUDIT
% Real-data branch occurrence audit under frozen PA5I/EXP010 semantics.
%
% Unlike the controlled-SAR branch_g0_neighbor3_audit(), this function does
% NOT receive an oracle nu_reference. Instead, it constructs an
% EVALUATION-ONLY full-period continuous global winner of the SAME
% dechirped tone objective and uses it as the search-objective reference.
%
% Method paths:
%   G0: integer DFT Top-1 -> frozen local continuous refinement
%   N3: Top-1 seed and its +/-1 neighbors -> same local refinement -> best J
%
% Evaluation path only:
%   full-period oversampled FFT -> local continuous refinement of global max
%
% Taxonomy:
%   SAFE
%     G0 matches global reference within branch_match_tolerance_bins.
%   G0_FAIL_N3_RESCUE
%     G0 misses, N3 matches.
%   N3_COVERAGE_MISS
%     G0 misses and none of the three refined N3 candidates match reference.
%   PERSISTENT_WITHIN_COVERAGE
%     G0 misses, at least one N3 candidate matches reference, but selected
%     N3 still misses.
%
% No Proposed scheduler is present.

x = double(x(:).');
N = numel(x);
m = 0:N-1;

if N < 8
    error('branch_real_g0_neighbor3_audit:TooShort', ...
        'Input line is too short for branch audit.');
end

z = x .* exp(-1j*pi*a_dechirp.*m.^2);

%% 1. Coarse integer DFT Top-1
Y = fftshift(fft(z));
bins = -floor(N/2):(ceil(N/2)-1);
Jcoarse = abs(Y).^2;

[Js,ord] = sort(Jcoarse,'descend');
i0 = ord(1);
k0 = bins(i0);

if numel(Js) >= 2
    coarse_margin = (Js(1)-Js(2)) / max(Js(1),eps);
else
    coarse_margin = NaN;
end

ntop = min(5,numel(ord));
top_bins = bins(ord(1:ntop));
top_scores = Js(1:ntop) / max(Js(1),eps);

%% 2. G0 local refinement
G0 = branch_refine_from_seed(z,k0,stage_cfg);

%% 3. Neighbor-3 local branch redundancy
seeds = k0 + (-stage_cfg.neighbor_radius:stage_cfg.neighbor_radius);
Ncand = numel(seeds);

if Ncand < 1
    error('branch_real_g0_neighbor3_audit:EmptyNeighborSet', ...
        'Neighbor candidate set is empty.');
end

first_cand = branch_refine_from_seed(z,seeds(1),stage_cfg);
N3cand = repmat(first_cand,Ncand,1);
N3cand(1) = first_cand;

for i = 2:Ncand
    N3cand(i) = branch_refine_from_seed(z,seeds(i),stage_cfg);
end

[~,ibest] = max([N3cand.objective_at_hat]);
N3 = N3cand(ibest);

%% 4. Evaluation-only full-period continuous global reference
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
q0 = qgrid(ig);

% Refine in a one-grid-step neighborhood around q0. The tone objective is
% N-periodic, so allowing the bracket to cross the canonical +/-N/2 edge is
% valid. Wrap only the reported estimate afterward.
dq = N/L;
ref_lb = q0-dq;
ref_ub = q0+dq;

count = 0;
opts = optimset( ...
    'Display','off', ...
    'TolX',stage_cfg.global_tolx_bins, ...
    'MaxFunEvals',stage_cfg.global_max_fun_evals);

[nu_global_raw,fval] = fminbnd(@wrapped_global,ref_lb,ref_ub,opts);
Jglobal = -fval;
nu_global = wrap_bin(nu_global_raw,N);

%% 5. Evaluation metrics
g0_nu = wrap_bin(G0.nu_hat_bins,N);
n3_nu = wrap_bin(N3.nu_hat_bins,N);

err_g0 = circular_bin_distance(g0_nu,nu_global,N);
err_n3 = circular_bin_distance(n3_nu,nu_global,N);

cand_nu = arrayfun(@(s) wrap_bin(s.nu_hat_bins,N),N3cand);
cand_dist = arrayfun(@(q) circular_bin_distance(q,nu_global,N),cand_nu);

tol = stage_cfg.branch_match_tolerance_bins;

g0_match = err_g0 <= tol;
n3_match = err_n3 <= tol;
candidate_coverage = any(cand_dist <= tol);

if g0_match
    taxonomy = "SAFE";
elseif n3_match
    taxonomy = "G0_FAIL_N3_RESCUE";
elseif ~candidate_coverage
    taxonomy = "N3_COVERAGE_MISS";
else
    taxonomy = "PERSISTENT_WITHIN_COVERAGE";
end

g0_catastrophic = err_g0 > stage_cfg.catastrophic_error_threshold_bins;
n3_catastrophic = err_n3 > stage_cfg.catastrophic_error_threshold_bins;

g0_objective_loss = (Jglobal-G0.objective_at_hat) / max(Jglobal,eps);
n3_objective_loss = (Jglobal-N3.objective_at_hat) / max(Jglobal,eps);

%% 6. Output
A = struct();

A.N = N;
A.a_dechirp = a_dechirp;
A.dechirped_signal = z;

A.coarse_bins = bins;
A.coarse_objective = Jcoarse;
A.coarse_top1_bin = k0;
A.coarse_top_bins = top_bins;
A.coarse_top_scores_normalized = top_scores;
A.coarse_top1_top2_margin = coarse_margin;

A.G0 = G0;
A.N3 = N3;
A.N3_candidates = N3cand;
A.N3_candidate_seeds = seeds;
A.N3_candidate_nu_wrapped = cand_nu;
A.N3_candidate_distance_to_global = cand_dist;

A.global_nu_bins = nu_global;
A.global_objective = Jglobal;
A.global_grid_count = numel(qgrid);
A.global_oversample = os;
A.global_refine_evals = count;

A.g0_nu_wrapped = g0_nu;
A.n3_nu_wrapped = n3_nu;
A.g0_error_bins = err_g0;
A.n3_error_bins = err_n3;

A.g0_matches_global = g0_match;
A.n3_matches_global = n3_match;
A.n3_candidate_coverage = candidate_coverage;

A.g0_catastrophic = g0_catastrophic;
A.n3_catastrophic = n3_catastrophic;
A.taxonomy = taxonomy;

A.g0_objective_loss_vs_global = g0_objective_loss;
A.n3_objective_loss_vs_global = n3_objective_loss;
A.n3_total_evals = sum([N3cand.n_objective_evals]);

    function y = wrapped_global(q)
        count = count + 1;
        y = -branch_tone_objective(z,q);
    end
end

function d = circular_bin_distance(a,b,N)
d = abs(mod((a-b)+N/2,N)-N/2);
end

function q = wrap_bin(q,N)
q = mod(q+N/2,N)-N/2;
end
