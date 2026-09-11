function E = compute_frac_energy_map(X, p_search, n, kappa, max_lag)
%COMPUTE_FRAC_ENERGY_MAP Mechanism-level discrete fractional autocorrelation.
%
% Inputs:
%   X        - N x Nr complex signal matrix
%   p_search - candidate centered rotation orders
%   n        - centered slow-time sample indices (N x 1)
%   kappa    - normalized chirp-slope scaling
%   max_lag  - maximum integer delay
%
% Output:
%   E        - Np x Nr FrAc energy map
%
% This is a mechanism-level discrete implementation inspired by Eq. (25)
% of Xu et al. (JSTARS, 2025), designed to verify multi-ORO separability.
% It is not claimed to be the authors' exact unpublished discrete code.

[N, Nr] = size(X);
Np = numel(p_search);

E = zeros(Np, Nr);

for ip = 1:Np
    alpha = p_search(ip) * pi/2;
    q_scan = kappa * tan(alpha);

    acc = zeros(1, Nr);

    for d = 1:max_lag
        product = X((d+1):N, :) .* conj(X(1:(N-d), :));

        nn = n((d+1):N);
        phase = exp(-1j * 2*pi * q_scan * d .* nn / N);

        r = (phase.' * product) / (N-d);
        acc = acc + abs(r).^2;
    end

    E(ip, :) = acc;
end

end
