function echo = sar_generate_range_compressed_echo(cfg, ranges)
%SAR_GENERATE_RANGE_COMPRESSED_ECHO Ideal range-compressed complex SAR data.
%
% Model for scatterer p at pulse m:
%   s(R,m) = a_p * sinc(2B/c * (R-R_p(m)))
%            * exp(-j*4*pi*R_p(m)/lambda)
%
% MATLAB's sinc is not required; a local sin(pi*x)/(pi*x) implementation
% is used to avoid toolbox dependence.

Raxis = cfg.range_axis_m(:);
Ns = size(ranges, 1);
Na = size(ranges, 2);
Nr = numel(Raxis);

echo = complex(zeros(Nr, Na));

for m = 1:Na
    col = complex(zeros(Nr, 1));
    for p = 1:Ns
        Rp = ranges(p,m);
        u = (2 * cfg.bandwidth / cfg.c) .* (Raxis - Rp);
        h_r = sincpi_local(u);
        carrier_phase = exp(-1j * 4*pi * Rp / cfg.lambda);
        col = col + cfg.scatterers.complex_coeff(p) .* h_r .* carrier_phase;
    end
    echo(:,m) = col;
end

end

function y = sincpi_local(x)
y = ones(size(x));
idx = abs(x) > 1e-12;
y(idx) = sin(pi*x(idx)) ./ (pi*x(idx));
end
