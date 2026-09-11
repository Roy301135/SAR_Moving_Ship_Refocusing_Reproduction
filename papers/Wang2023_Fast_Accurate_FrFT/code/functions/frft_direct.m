function X = frft_direct(x, t, p, u)
%FRFT_DIRECT Direct normalized continuous-kernel FrFT discretization.
%
%   X = frft_direct(x, t, p, u)
%
% Inputs
%   x : input signal, row or column vector
%   t : normalized input coordinate, same length as x
%   p : FrFT order, with rotation angle alpha = p*pi/2
%   u : normalized output coordinate
%
% Output
%   X : FrFT output sampled on u, returned as a column vector
%
% Kernel convention
%
%   K_alpha(t,u) = A_alpha *
%       exp(j*pi*((t^2+u^2)cot(alpha) - 2tu csc(alpha)))
%
%   A_alpha = sqrt(1 - j*cot(alpha))
%
% For an input chirp
%
%   x(t) = exp(j*pi*kappa*t^2),
%
% the quadratic phase is cancelled when
%
%   cot(alpha_opt) + kappa = 0.
%
% Important
%   This implementation is intentionally direct and transparent. Its
%   computational complexity is O(N^2) per transform. It is appropriate for
%   mechanism verification in EXP01-EXP03, but should later be replaced by
%   an FFT-based discrete FrFT for serious runtime benchmarking.
%
%   The routine numerically renormalizes the output energy to the input
%   energy. This makes peak/entropy comparisons across nearby orders more
%   stable under finite-grid discretization.

    if nargin < 4 || isempty(u)
        u = t;
    end

    x = x(:);
    t = t(:).';
    u = u(:);

    N = numel(x);

    if numel(t) ~= N
        error('Length of t must equal length of x.');
    end

    if N < 2
        error('Signal length must be at least 2.');
    end

    alpha = p*pi/2;

    if abs(sin(alpha)) < 1e-8
        error(['frft_direct is singular for p near an even integer ' ...
               '(sin(alpha) approximately zero).']);
    end

    dt = mean(diff(t));

    cot_alpha = cos(alpha) / sin(alpha);
    csc_alpha = 1 / sin(alpha);

    A_alpha = sqrt(1 - 1j*cot_alpha);

    % Matrix dimensions:
    %   u.^2        : Nu x 1
    %   t.^2        : 1 x Nt
    %   u * t       : Nu x Nt
    phase = pi * ( ...
        (u.^2 + t.^2) * cot_alpha ...
        - 2 * (u * t) * csc_alpha );

    K = A_alpha .* exp(1j * phase);

    X = K * x * dt;

    % Numerical energy normalization.
    Ein = sum(abs(x).^2);
    Eout = sum(abs(X).^2);

    if Eout > 0
        X = X * sqrt(Ein / Eout);
    end
end
