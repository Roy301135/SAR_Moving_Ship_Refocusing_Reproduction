function out = fair_csar_fractional_line_audit(x, p_grid, zero_exclude)
%FAIR_CSAR_FRACTIONAL_LINE_AUDIT Paper-consistent FrAc-energy diagnostic.
%
% Xu et al. (2025), Eq. (26):
%   R_alpha(rho) = F^{-1}{ |X_{alpha+pi/2}(u)|^2 }
%
% Xu et al. (2025), Eq. (31):
%   E_rho(alpha) = integral |R_alpha(rho)|^2 d rho
%
% IMPORTANT CORRECTION
% --------------------
% The previous R0 implementation used the *maximum nonzero-lag fraction*
% of |R_alpha|^2. That is NOT Eq. (31) and is unsuitable for ORO
% estimation. In fact, at the correct LFM order, |X|^2 becomes highly
% concentrated and its inverse Fourier transform can have nearly uniform
% magnitude, so a max/total lag-concentration metric can suppress the
% desired order.
%
% This corrected implementation uses the TOTAL FrAc energy. To make values
% dimensionless and robust to small numerical gain variations in the direct
% FrFT, the reported score is
%
%   C_alpha = N * sum_rho |R_alpha(rho)|^2 / (sum_u |X|^2)^2
%
% By Parseval this equals
%
%   C_alpha = sum_u |X(u)|^4 / (sum_u |X(u)|^2)^2
%
% and therefore has the SAME maximizing order as Eq. (31) when the FrFT is
% unitary. It lies roughly in [1/N, 1], with larger values indicating
% stronger fractional-domain concentration.
%
% The third argument zero_exclude is retained ONLY for call compatibility
% with earlier R0 scripts. It is intentionally ignored in the corrected
% Eq. (31) implementation; zero lag must NOT be removed from total FrAc
% energy.
%
% No branch-reliability logic is implemented here.

if exist('frft_direct','file') ~= 2
    error(['frft_direct.m is not on the MATLAB path. Expected validated ' ...
           'implementation under papers/Wang2023_Fast_Accurate_FrFT/' ...
           'code/functions/.']);
end

% Retain signature compatibility but explicitly do not use it.
if nargin < 3
    zero_exclude = 0; %#ok<NASGU>
else
    zero_exclude = zero_exclude; %#ok<NASGU>
end

x = double(x(:).');
N = numel(x);

den = sqrt(sum(abs(x).^2));
if den <= eps
    error('Zero-energy azimuth line.');
end
x = x / den;

eta = (0:N-1) - (N-1)/2;
if max(abs(eta)) == 0
    t_norm = 0;
else
    t_norm = eta / max(abs(eta)) * 4;
end
u_norm = t_norm;

Np = numel(p_grid);

frft_conc = zeros(1,Np);
frac_energy = zeros(1,Np);
frft_entropy = zeros(1,Np);

for ip = 1:Np
    p = p_grid(ip);

    %% Direct FrFT concentration at p (diagnostic only)
    Xp = safe_frft_project(x,t_norm,p,u_norm);
    P = abs(Xp).^2;
    Psum = sum(P);

    frft_conc(ip) = max(P) / max(Psum,eps);

    prob = P / max(Psum,eps);
    prob = prob(prob > 0);
    frft_entropy(ip) = -sum(prob .* log(prob + eps));

    %% Paper-consistent FrAc energy
    % Eq. (26): alpha + pi/2 => order p + 1.
    p90 = p + 1;

    X90 = safe_frft_project(x,t_norm,p90,u_norm);
    P90 = abs(X90).^2;
    P90sum = sum(P90);

    R = ifft(P90);

    % Eq. (31) total energy, normalized to a dimensionless concentration.
    Eraw = sum(abs(R).^2);
    frac_energy(ip) = N * Eraw / max(P90sum.^2,eps);
end

[frft_peak,best_frft_idx] = max(frft_conc);
[frac_peak,best_frac_idx] = max(frac_energy);
[entropy_min,best_entropy_idx] = min(frft_entropy);

frac_med = median(frac_energy);
frft_med = median(frft_conc);

out = struct();

out.p_grid = p_grid;
out.frft_concentration = frft_conc;
out.frac_score = frac_energy;          % legacy field name retained
out.frac_energy = frac_energy;         % explicit corrected name
out.frft_entropy = frft_entropy;

out.best_frft_order = p_grid(best_frft_idx);
out.best_frac_order = p_grid(best_frac_idx);
out.best_entropy_order = p_grid(best_entropy_idx);

out.frft_peak = frft_peak;
out.frac_peak = frac_peak;
out.entropy_min = entropy_min;

out.frft_peak_to_median = frft_peak / max(frft_med,eps);
out.frac_peak_to_median = frac_peak / max(frac_med,eps);

out.frac_metric = "Eq31_total_energy_normalized";
out.zero_lag_exclusion_used = false;

end

function X = safe_frft_project(x,t_norm,p,u_norm)
%SAFE_FRFT_PROJECT Handle exact even-integer FrFT orders analytically.

q = mod(p,4);
tol = 1e-10;

if abs(q) < tol || abs(q-4) < tol
    X = x;
elseif abs(q-2) < tol
    X = fliplr(x);
else
    X = frft_direct(x,t_norm,p,u_norm);
end

X = X(:).';

end
