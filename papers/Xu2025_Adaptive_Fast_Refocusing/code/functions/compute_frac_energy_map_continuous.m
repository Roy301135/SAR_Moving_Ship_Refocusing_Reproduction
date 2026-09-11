function E = compute_frac_energy_map_continuous(X, q_search, t_norm, max_lag)
%COMPUTE_FRAC_ENERGY_MAP_CONTINUOUS
% FrAc-like energy map on the SAME normalized coordinate used by frft_direct.
%
% Purpose:
%   EXP08 needs one synthetic MC-LFM signal model that is simultaneously
%   compatible with:
%       (1) FrAc-style ORO search, and
%       (2) FrFT/CLEAN refocusing.
%
% Signal convention:
%   x(t) = exp(j*pi*a*t^2 + j*2*pi*b*t)
%
% For a uniform normalized coordinate t with spacing dt,
%
%   x(t_n) conj(x(t_{n-d}))
%       ~ exp(j*2*pi*a*(d*dt)*t_n)
%
% Therefore the FrAc energy peaks when
%
%   a = tan(alpha_q),    alpha_q = q*pi/2.
%
% The corresponding FrFT refocusing order is
%
%   p_refocus = q + 1,
%
% because -cot((q+1)*pi/2) = tan(q*pi/2).
%
% Inputs:
%   X        : N x Nline complex matrix
%   q_search : candidate FrAc tracking orders
%   t_norm   : 1 x N or N x 1 uniform normalized coordinate
%   max_lag  : maximum integer lag
%
% Output:
%   E        : Nq x Nline FrAc-like energy map
%
% This is a controlled mechanism-level implementation, not the authors'
% exact unpublished discrete FrAc code.

t = t_norm(:);
[N, Nline] = size(X);

if numel(t) ~= N
    error('Length of t_norm must match size(X,1).');
end

if N < 3
    error('Signal length must be at least 3.');
end

dt = mean(diff(t));

Nq = numel(q_search);
E = zeros(Nq, Nline);

for iq = 1:Nq

    alpha_q = q_search(iq) * pi/2;
    a_scan = tan(alpha_q);

    acc = zeros(1, Nline);

    for d = 1:max_lag

        product = X((d+1):N,:) .* conj(X(1:(N-d),:));

        t_now = t((d+1):N);

        phase = exp(-1j * 2*pi * a_scan * (d*dt) .* t_now);

        r = (phase.' * product) / (N-d);

        acc = acc + abs(r).^2;
    end

    E(iq,:) = acc;
end

end
