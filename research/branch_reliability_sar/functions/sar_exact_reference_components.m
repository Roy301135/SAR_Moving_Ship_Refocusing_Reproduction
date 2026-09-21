function out = sar_exact_reference_components(cfg, ranges_moving, x_ref_m, y_ref_m)
%SAR_EXACT_REFERENCE_COMPONENTS
% Exact ideal range-compressed forward-model evaluation along one canonical
% stationary reference range history.
%
% For component p:
%   x_p[m] = c_p sinc(2B/c * (Rref[m]-Rp[m]))
%            * exp(-j 4pi (Rp[m]-Rref[m])/lambda)
%
% Thus every component is expressed in the same residual sampled domain
% used by the EXP009/010 LFM implementation.

eta = cfg.eta(:).';
platform_x = cfg.platform_velocity .* eta;
Rref = sqrt((platform_x - x_ref_m).^2 + y_ref_m.^2 + cfg.platform_height^2);

Ns = size(ranges_moving,1);
N = size(ranges_moving,2);
X = complex(zeros(Ns,N));

for p = 1:Ns
    dR = Rref - ranges_moving(p,:);
    u = (2 * cfg.bandwidth / cfg.c) .* dR;
    h = sincpi_local(u);
    X(p,:) = cfg.scatterers.complex_coeff(p) .* h .* ...
        exp(-1j * 4*pi .* (ranges_moving(p,:) - Rref) / cfg.lambda);
end

out.components = X;
out.full_signal = sum(X,1);
out.Rref_m = Rref;
out.x_ref_m = x_ref_m;
out.y_ref_m = y_ref_m;

end

function y = sincpi_local(x)
y = ones(size(x));
idx = abs(x) > 1e-12;
y(idx) = sin(pi*x(idx)) ./ (pi*x(idx));
end
