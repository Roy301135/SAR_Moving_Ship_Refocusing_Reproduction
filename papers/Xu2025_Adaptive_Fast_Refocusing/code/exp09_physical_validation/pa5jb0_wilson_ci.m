function [p,lo,hi] = pa5jb0_wilson_ci(k,n,z)
%PA5JB0_WILSON_CI Wilson interval; undefined denominators return NaN.
if n==0, p=NaN; lo=NaN; hi=NaN; return; end
p = k/n; d = 1+z^2/n; c = (p+z^2/(2*n))/d;
h = z/d*sqrt(p*(1-p)/n+z^2/(4*n^2));
lo = max(0,c-h); hi = min(1,c+h);
end
