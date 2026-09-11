function H = signal_entropy(x)
%SIGNAL_ENTROPY Shannon entropy of normalized signal energy.
%
%   H = signal_entropy(x)
%
% The definition follows the focusing metric used in the paper:
%
%   p_i = |x_i|^2 / sum_k |x_k|^2
%   H   = -sum_i p_i log(p_i)
%
% A more concentrated signal has lower entropy.

    power_x = abs(x(:)).^2;
    total_energy = sum(power_x);

    if total_energy <= 0
        H = NaN;
        return;
    end

    p = power_x / total_energy;

    % Avoid log(0).
    p = p(p > 0);

    H = -sum(p .* log(p));
end
