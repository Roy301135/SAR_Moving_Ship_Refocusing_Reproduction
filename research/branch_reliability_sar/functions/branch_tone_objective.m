function J = branch_tone_objective(z, nu_bins)
%BRANCH_TONE_OBJECTIVE Frozen tone-search objective after dechirping.
%
% J(nu) = | sum_m z[m] exp(-j 2pi nu m/N) |^2,
% m = 0,...,N-1.
%
% nu_bins may be scalar or vector.

z = z(:).';
N = numel(z);
m = 0:N-1;
q = nu_bins(:);
J = zeros(size(q));

% Chunking avoids a large temporary exponential matrix for dense scans.
chunk = 512;
for i0 = 1:chunk:numel(q)
    ii = i0:min(i0+chunk-1,numel(q));
    E = exp(-1j * 2*pi/N .* (q(ii) * m));
    v = E * z.';
    J(ii) = abs(v).^2;
end

J = reshape(J, size(nu_bins));

end
