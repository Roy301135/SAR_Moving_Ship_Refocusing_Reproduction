function [S, info] = fair_csar_load_complex_mat(mat_path)
%FAIR_CSAR_LOAD_COMPLEX_MAT Load the dominant 2-D complex numeric matrix.
%
% FAIR-CSAR SLCMats are expected to store one Float32 complex matrix, but
% this reader avoids hard-coding the variable name.

vars = whos('-file',mat_path);

best_idx = [];
best_n = -inf;

for i = 1:numel(vars)
    if numel(vars(i).size) ~= 2
        continue;
    end
    if ~ismember(vars(i).class,{'single','double'})
        continue;
    end
    n = prod(vars(i).size);
    if n > best_n
        best_n = n;
        best_idx = i;
    end
end

if isempty(best_idx)
    error('No 2-D single/double numeric matrix found in MAT file.');
end

name = vars(best_idx).name;
tmp = load(mat_path,name);
S = tmp.(name);

if ~isnumeric(S) || ndims(S) ~= 2
    error('Loaded variable is not a 2-D numeric matrix.');
end

info = struct();
info.variable_name = name;
info.class_name = class(S);
info.size = size(S);
info.is_complex = ~isreal(S);
info.n_nan = sum(isnan(S(:)));
info.n_inf = sum(isinf(S(:)));
info.zero_fraction = mean(S(:) == 0);

if ~info.is_complex
    warning('FAIR-CSAR MAT matrix is real-valued; expected complex SLC.');
end
if info.n_nan > 0 || info.n_inf > 0
    error('MAT contains NaN/Inf values.');
end

end
