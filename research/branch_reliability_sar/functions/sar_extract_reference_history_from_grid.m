function out = sar_extract_reference_history_from_grid(cfg, echo, x_ref_m, y_ref_m)
%SAR_EXTRACT_REFERENCE_HISTORY_FROM_GRID
% Extract one stationary-reference-compensated complex range-cell history
% from the stored range-compressed SAR data.
%
% For pulse m, sample the range-compressed data at the stationary reference
% slant range R_ref(m), then remove the common stationary carrier phase:
%
%   x_grid[m] = s_rc(R_ref(m),m) * exp(+j 4 pi R_ref(m)/lambda)
%
% This is a data-grid diagnostic in Stage-B. The exact forward evaluation is
% used as the primary mechanism signal to avoid interpolation artifacts.

eta = cfg.eta(:).';
platform_x = cfg.platform_velocity .* eta;
Rref = sqrt((platform_x - x_ref_m).^2 + y_ref_m.^2 + cfg.platform_height^2);

x = complex(zeros(1, numel(eta)));
Raxis = cfg.range_axis_m(:);

for m = 1:numel(eta)
    sample = interp1(Raxis, echo(:,m), Rref(m), cfg.bp.interp_method, 0);
    x(m) = sample .* exp(1j * 4*pi * Rref(m) / cfg.lambda);
end

out.signal = x;
out.Rref_m = Rref;
out.x_ref_m = x_ref_m;
out.y_ref_m = y_ref_m;

end
