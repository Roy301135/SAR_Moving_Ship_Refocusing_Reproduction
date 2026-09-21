function D = opensarship_read_slc_chip(path)
%OPENSARSHIP_READ_SLC_CHIP Read an OpenSARShip original SLC ship chip.
%
% OpenSARShip ReadMe v1.0 specifies for SLC Patch:
%   band 1 = real(VH)
%   band 2 = imag(VH)
%   band 3 = real(VV)
%   band 4 = imag(VV)
%
% Axis convention from OpenSARShip:
%   x = range, y = azimuth
% Hence MATLAB row dimension is azimuth and column dimension is range.

arguments
    path (1,:) char
end

if ~exist(path,'file')
    error('OpenSARShip:MissingSLC','SLC chip not found: %s',path);
end

info = imfinfo(path);
raw = imread(path);

if ndims(raw) ~= 3 || size(raw,3) ~= 4
    error('OpenSARShip:UnexpectedSLCLayout', ...
        'Expected HxWx4 original SLC Patch, got size %s.',mat2str(size(raw)));
end

if ~isa(raw,'single')
    error('OpenSARShip:UnexpectedSLCType', ...
        'Expected single-precision original SLC Patch, got %s.',class(raw));
end

D = struct();
D.path = path;
D.raw = raw;
D.VH = complex(raw(:,:,1),raw(:,:,2));
D.VV = complex(raw(:,:,3),raw(:,:,4));
D.height = size(raw,1);
D.width = size(raw,2);
D.axis = struct('azimuth_dim',1,'range_dim',2, ...
    'row_semantics',"azimuth_y",'column_semantics',"range_x");
D.tiff_info = info;

% Parse filename center coordinate.
[~,name,ext] = fileparts(path);
tok = regexp([name ext],'_x(\d+)_y(\d+)\.tif$','tokens','once');
if isempty(tok)
    error('OpenSARShip:FilenameSchema', ...
        'Cannot parse center x/y from filename: %s',[name ext]);
end
D.center_x = str2double(tok{1});
D.center_y = str2double(tok{2});

% Basic information-preservation guards.
vr = [var(double(raw(:,:,1)),0,'all'), var(double(raw(:,:,2)),0,'all'), ...
      var(double(raw(:,:,3)),0,'all'), var(double(raw(:,:,4)),0,'all')];
D.band_variances = vr;
if any(~isfinite(vr)) || any(vr <= 0)
    error('OpenSARShip:DegenerateComplexBands', ...
        'At least one real/imag band has zero or invalid variance.');
end

end
