function R = opensarship_lfm_coherence_scan(x,n_beta,nfft)
%OPENSARSHIP_LFM_COHERENCE_SCAN
% Broad diagnostic scan over the discrete-LFM family:
% s[m] = exp(j*pi*beta*m^2) exp(j*2*pi*nu*m/N)

x = double(x(:));
N = numel(x);
if N < 8, error('OpenSARShip:R0BTooShort','Azimuth line is too short.'); end
if nfft < N, error('OpenSARShip:R0BNFFT','nfft must be >= N.'); end

m = (-floor(N/2):ceil(N/2)-1).';
beta_grid = linspace(-1/N,1/N,n_beta);

energy = sum(abs(x).^2);
if ~(isfinite(energy) && energy > 0)
    error('OpenSARShip:R0BZeroEnergy','Line has invalid or zero energy.');
end

profile = zeros(1,n_beta);
best_nu_each = zeros(1,n_beta);

for ib = 1:n_beta
    beta = beta_grid(ib);
    xd = x .* exp(-1j*pi*beta*(m.^2));
    X = fftshift(fft(xd,nfft));
    p = abs(X).^2;
    [pk,idx] = max(p);
    profile(ib) = pk/(N*energy);
    k = idx - (floor(nfft/2)+1);
    best_nu_each(ib) = k * N / nfft;
end

[best_coh,ibest] = max(profile);
[~,izero] = min(abs(beta_grid));

R = struct();
R.N = N;
R.beta_grid = beta_grid;
R.beta_profile = profile;
R.best_nu_each = best_nu_each;
R.best_coherence = best_coh;
R.best_beta = beta_grid(ibest);
R.best_nu_bins = best_nu_each(ibest);
R.tone_coherence = profile(izero);
R.chirp_gain_db = 10*log10(max(R.best_coherence,eps)/max(R.tone_coherence,eps));
R.beta_boundary_hit = (ibest==1 || ibest==n_beta);
R.best_beta_index = ibest;
end
