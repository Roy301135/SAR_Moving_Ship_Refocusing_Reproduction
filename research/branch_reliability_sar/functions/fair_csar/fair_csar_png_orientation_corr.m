function out = fair_csar_png_orientation_corr(S, png_path)
%FAIR_CSAR_PNG_ORIENTATION_CORR Check complex magnitude vs PNG orientation.
%
% Returns normalized linear correlation for eight dihedral transforms.
% Scientific code expects RAW orientation to be the best match for the
% frozen Candidate B.

I = double(imread(png_path));
if ndims(I) == 3
    I = mean(I,3);
end

A = log1p(abs(double(S)));

if ~isequal(size(A),size(I))
    error('MAT/PNG size mismatch: MAT=%dx%d PNG=%dx%d.', ...
        size(A,1),size(A,2),size(I,1),size(I,2));
end

names = ["raw","transpose","flipud","fliplr", ...
         "rot180","transpose_flipud","transpose_fliplr","rot90"];

imgs = cell(1,8);
imgs{1} = A;
imgs{2} = A.';
imgs{3} = flipud(A);
imgs{4} = fliplr(A);
imgs{5} = rot90(A,2);
imgs{6} = flipud(A.');
imgs{7} = fliplr(A.');
imgs{8} = rot90(A,1);

c = nan(1,8);
for k = 1:8
    if isequal(size(imgs{k}),size(I))
        c(k) = local_corr(imgs{k},I);
    end
end

[best_corr,best_idx] = max(c);

out = struct();
out.names = names;
out.corr = c;
out.best_name = names(best_idx);
out.best_corr = best_corr;
out.raw_corr = c(1);

end

function c = local_corr(a,b)
a = a(:);
b = b(:);
a = a - mean(a);
b = b - mean(b);
den = sqrt(sum(a.^2)*sum(b.^2));
if den <= eps
    c = 0;
else
    c = sum(a.*b)/den;
end
end
