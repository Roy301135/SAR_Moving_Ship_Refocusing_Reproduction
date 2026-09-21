function D = opensarship_read_cal_chip(path)
%OPENSARSHIP_READ_CAL_CHIP Read OpenSARShip radiometrically calibrated chip.
%
% ReadMe v1.0:
%   band 1 = calibrated VH NRCS
%   band 2 = calibrated VV NRCS

arguments
    path (1,:) char
end

if ~exist(path,'file')
    error('OpenSARShip:MissingCal','Calibrated chip not found: %s',path);
end

raw = imread(path);
if ndims(raw) ~= 3 || size(raw,3) ~= 2
    error('OpenSARShip:UnexpectedCalLayout', ...
        'Expected HxWx2 calibrated Patch, got size %s.',mat2str(size(raw)));
end
if ~isa(raw,'single')
    error('OpenSARShip:UnexpectedCalType', ...
        'Expected single-precision calibrated Patch, got %s.',class(raw));
end

D = struct();
D.path = path;
D.raw = raw;
D.VH = raw(:,:,1);
D.VV = raw(:,:,2);
D.height = size(raw,1);
D.width = size(raw,2);
end
