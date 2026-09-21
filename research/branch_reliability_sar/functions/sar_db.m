function out_db = sar_db(x, floor_db)
%SAR_DB Magnitude in dB normalized to the maximum of x.
if nargin < 2
    floor_db = -40;
end
mag = abs(x);
peak = max(mag(:));
if peak <= 0
    out_db = floor_db * ones(size(mag));
    return;
end
out_db = 20*log10(max(mag / peak, 10^(floor_db/20)));
end
