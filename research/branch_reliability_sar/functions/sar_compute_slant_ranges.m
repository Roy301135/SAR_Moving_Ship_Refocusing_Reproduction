function ranges = sar_compute_slant_ranges(cfg, tracks)
%SAR_COMPUTE_SLANT_RANGES True platform-to-scatterer slant ranges.
%
% Output ranges is [Nscatterer x Na].

eta = cfg.eta;
platform_x = cfg.platform_velocity .* eta;
platform_y = 0;
platform_z = cfg.platform_height;

Ns = size(tracks.x, 1);
Na = numel(eta);
ranges = zeros(Ns, Na);

for m = 1:Na
    dx = platform_x(m) - tracks.x(:,m);
    dy = platform_y - tracks.y(:,m);
    dz = platform_z - tracks.z(:,m);
    ranges(:,m) = sqrt(dx.^2 + dy.^2 + dz.^2);
end

end
