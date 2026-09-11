function [S, f, t_center] = simple_stft(x, dt, win_len, hop, nfft)
%SIMPLE_STFT Toolbox-free short-time Fourier transform.
%
%   [S, f, t_center] = simple_stft(x, dt, win_len, hop, nfft)
%
% Inputs
%   x       : input signal
%   dt      : sample spacing
%   win_len : window length in samples
%   hop     : hop size in samples
%   nfft    : FFT length
%
% Outputs
%   S        : complex STFT matrix [frequency x frame]
%   f        : frequency axis
%   t_center : center time of each frame
%
% Uses a Hann window implemented explicitly, so no Signal Processing Toolbox
% is required.

    x = x(:).';
    N = numel(x);

    if win_len > N
        error('win_len cannot exceed signal length.');
    end

    if nfft < win_len
        error('nfft must be >= win_len.');
    end

    if hop < 1
        error('hop must be >= 1.');
    end

    win = 0.5 - 0.5*cos(2*pi*(0:win_len-1)/(win_len-1));

    starts = 1:hop:(N-win_len+1);
    n_frames = numel(starts);

    S = zeros(nfft, n_frames);

    for ii = 1:n_frames
        idx = starts(ii):(starts(ii)+win_len-1);

        frame = x(idx) .* win;
        spectrum = fftshift(fft(frame, nfft));

        S(:, ii) = spectrum(:);
    end

    fs = 1/dt;
    f = ((0:nfft-1) - floor(nfft/2)) * (fs/nfft);

    sample_center = starts - 1 + (win_len-1)/2;
    t_center = (sample_center - (N-1)/2) * dt;
end
