function v = centered_order_to_velocity(p_centered, Vsar, lambda, R0, PRF, Na)
%CENTERED_ORDER_TO_VELOCITY Evaluate Eq. (22) from centered FrFT order.
%
% This function is mainly used for the numerical consistency check in
% exp01_eq22_ori_mapping.m.

p_signed = p_centered + 0.5;
alpha = p_signed * pi / 2;

v = zeros(size(alpha));

zero_idx = abs(alpha) < 1e-12;
nz = ~zero_idx;

cot_alpha = cos(alpha(nz)) ./ sin(alpha(nz));

den = lambda * R0 * (PRF^2 / Na) .* cot_alpha ...
      - 2 * Vsar^2;

radicand = 1 + 2 * Vsar^2 ./ den;

if any(radicand < -1e-10)
    warning('Negative radicand encountered in Eq. (22).');
end

radicand = max(radicand, 0);
v(nz) = Vsar .* (1 - sqrt(radicand));
v(zero_idx) = 0;

end
