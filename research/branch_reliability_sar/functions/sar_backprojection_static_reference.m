function image = sar_backprojection_static_reference(cfg, echo)
%SAR_BACKPROJECTION_STATIC_REFERENCE Stationary-scene BP image formation.
%
% The imager assumes every pixel is stationary. Moving-target mismatch is
% therefore allowed to emerge naturally from the data instead of being
% imposed as an image-domain blur.

xg = cfg.image.x_axis_m;
yg = cfg.image.y_axis_m;
[X, Y] = meshgrid(xg, yg);
image = complex(zeros(size(X)));

Raxis = cfg.range_axis_m(:);
eta = cfg.eta;
platform_x = cfg.platform_velocity .* eta;

for m = 1:numel(eta)
    Rref = sqrt((platform_x(m) - X).^2 + Y.^2 + cfg.platform_height^2);

    samples = interp1(Raxis, echo(:,m), Rref(:), ...
        cfg.bp.interp_method, 0);
    samples = reshape(samples, size(Rref));

    image = image + samples .* exp(1j * 4*pi .* Rref / cfg.lambda);
end

end
