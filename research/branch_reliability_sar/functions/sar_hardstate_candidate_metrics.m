function C = sar_hardstate_candidate_metrics(cfg, p)
%SAR_HARDSTATE_CANDIDATE_METRICS Map one physical yaw-pair candidate to
% sampled-LFM parameters. No branch objective is evaluated here.
%
% p fields:
%   x_strong_center_m, x_weak_center_m, common_y_offset_m,
%   yaw_amplitude_rad, yaw_period_s, yaw_phase0_rad.

eta = cfg.eta(:).';
N = numel(eta);

A = p.yaw_amplitude_rad;
T = p.yaw_period_s;
phi0 = p.yaw_phase0_rad;
theta0 = A * sin(phi0);

% P4/P7 are constrained to the same aperture-center ground-range line.
center_rel = [ ...
    p.x_strong_center_m, p.common_y_offset_m; ...
    p.x_weak_center_m,   p.common_y_offset_m];

R0 = [cos(theta0), -sin(theta0); sin(theta0), cos(theta0)];
body_xy = (R0.' * center_rel.').';

omega = 2*pi / T;
theta = A .* sin(omega .* eta + phi0);

x = zeros(2,N);
y = zeros(2,N);
for k = 1:N
    ct = cos(theta(k));
    st = sin(theta(k));
    x(:,k) = cfg.ship_center_x + ct.*body_xy(:,1) - st.*body_xy(:,2);
    y(:,k) = cfg.ship_center_y + st.*body_xy(:,1) + ct.*body_xy(:,2);
end

platform_x = cfg.platform_velocity .* eta;
ranges = zeros(2,N);
for k = 1:N
    dx = platform_x(k) - x(:,k);
    dy = -y(:,k);
    dz = cfg.platform_height;
    ranges(:,k) = sqrt(dx.^2 + dy.^2 + dz.^2);
end

x_ref_m = cfg.ship_center_x;
y_ref_m = cfg.ship_center_y + p.common_y_offset_m;
Rref = sqrt((platform_x-x_ref_m).^2 + y_ref_m.^2 + cfg.platform_height^2);

X = complex(zeros(2,N));
for q = 1:2
    dR = Rref - ranges(q,:);
    u = (2*cfg.bandwidth/cfg.c).*dR;
    h = sincpi_local(u);
    X(q,:) = h .* exp(-1j*4*pi.*(ranges(q,:)-Rref)/cfg.lambda);
end

fit_s = sar_fit_sampled_lfm(X(1,:));
fit_w = sar_fit_sampled_lfm(X(2,:));

C = struct();
C.p = p;
C.body_xy_m = body_xy;
C.center_rel_xy_m = center_rel;
C.theta_center_rad = theta0;
C.reference_x_m = x_ref_m;
C.reference_y_m = y_ref_m;
C.unit_components = X;
C.fit_s = fit_s;
C.fit_w = fit_w;
C.pair_center_separation_m = abs(p.x_weak_center_m-p.x_strong_center_m);
C.strong_minmax = fit_s.min_to_max_amplitude_ratio;
C.weak_minmax = fit_w.min_to_max_amplitude_ratio;
C.N = N;

end

function y = sincpi_local(x)
y = ones(size(x));
idx = abs(x) > 1e-12;
y(idx) = sin(pi*x(idx))./(pi*x(idx));
end
