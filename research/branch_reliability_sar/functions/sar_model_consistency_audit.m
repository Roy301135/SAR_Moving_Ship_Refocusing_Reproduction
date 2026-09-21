function audit = sar_model_consistency_audit(cfg, ranges_static, ranges_moving)
%SAR_MODEL_CONSISTENCY_AUDIT Audit local quadratic residual-phase validity.
%
% For each scatterer, form the exact motion-induced residual phase relative
% to the aperture-center-frozen static reference:
%   dphi(eta) = -4*pi/lambda * (R_moving - R_static)
% and fit a second-order polynomial in slow time.
%
% No automatic validity threshold is imposed in Stage A.

eta = cfg.eta(:);
Ns = size(ranges_static, 1);

idx = (1:Ns).';
fit_nrmse = nan(Ns,1);
r2 = nan(Ns,1);
max_abs_residual_rad = nan(Ns,1);
quad_coeff_rad_s2 = nan(Ns,1);
lin_coeff_rad_s = nan(Ns,1);
phase_span_rad = nan(Ns,1);

fit_phase = zeros(Ns, numel(eta));
true_phase = zeros(Ns, numel(eta));

for p = 1:Ns
    dR = ranges_moving(p,:).' - ranges_static(p,:).';
    phi = -4*pi/cfg.lambda .* dR;
    coeff = polyfit(eta, phi, 2);
    phi_fit = polyval(coeff, eta);
    residual = phi - phi_fit;

    centered = phi - mean(phi);
    denom = norm(centered);
    if denom > 1e-12
        fit_nrmse(p) = norm(residual) / denom;
        sst = sum(centered.^2);
        sse = sum(residual.^2);
        r2(p) = 1 - sse / sst;
    end

    max_abs_residual_rad(p) = max(abs(residual));
    quad_coeff_rad_s2(p) = coeff(1);
    lin_coeff_rad_s(p) = coeff(2);
    phase_span_rad(p) = max(phi) - min(phi);
    fit_phase(p,:) = phi_fit.';
    true_phase(p,:) = phi.';
end

labels = string(cfg.scatterers.labels(:));
role = repmat("context", Ns, 1);
role(cfg.scatterers.strong_idx) = "strong";
role(cfg.scatterers.weak_idx) = "weak";

T = table(idx, labels, role, fit_nrmse, r2, max_abs_residual_rad, ...
    phase_span_rad, quad_coeff_rad_s2, lin_coeff_rad_s, ...
    'VariableNames', {'scatterer_idx','label','role','quadratic_fit_nrmse', ...
    'quadratic_fit_r2','max_abs_fit_residual_rad','phase_span_rad', ...
    'quadratic_coeff_rad_per_s2','linear_coeff_rad_per_s'});

audit.table = T;
audit.true_phase = true_phase;
audit.fit_phase = fit_phase;
audit.eta = eta.';
audit.strong_idx = cfg.scatterers.strong_idx;
audit.weak_idx = cfg.scatterers.weak_idx;

end
