# TB1 Theory Freeze v1.0 — Before EXP011-A

## Non-fitting declaration

The following theory is frozen **before** inspecting EXP011-A outputs. No coefficient may be estimated from failure labels.

## Unified deterministic signal model

After true dominant-component chirp-rate compensation,

\[
z[m]=z_0[m]+\varepsilon z_p[m].
\]

For the PA5H/PA5I family,

\[
\varepsilon=r=A_w/A_s.
\]

Define

\[
C_0(\nu)=\sum_m z_0[m]e^{-j2\pi\nu m/N},
\]

\[
C_p(\nu)=\sum_m z_p[m]e^{-j2\pi\nu m/N}.
\]

Then

\[
J(\nu;\varepsilon)
=
|C_0+\varepsilon C_p|^2
=
J_0(\nu)+\varepsilon J_1(\nu)+\varepsilon^2J_2(\nu),
\]

with

\[
J_0=|C_0|^2,
\qquad
J_1=2\Re\{C_0C_p^*\},
\qquad
J_2=|C_p|^2.
\]

This decomposition is algebraic and is not an empirical model.

## Local branch displacement

For a nondegenerate local maximum \(\nu_j^{(0)}\),

\[
\delta\nu_j
\approx
-\varepsilon
\frac{J_1'(\nu_j^{(0)})}
{J_0''(\nu_j^{(0)})}.
\]

This is a small-perturbation approximation only.

## Continuous branch margin

For correct branch \(c\) and competitor \(b\),

\[
M_{cb}=V_c-V_b.
\]

## Coarse branch representation

Let \(C_j\) denote the best integer-lattice score available to branch \(j\) through the frozen local-refinement semantics. Define

\[
L_j=V_j-C_j.
\]

Then

\[
\boxed{
\widetilde M_{cb}
=
C_c-C_b
=
M_{cb}-(L_c-L_b)
}.
\]

Thus it is theoretically possible to have

\[
M_{cb}>0
\]

but

\[
\widetilde M_{cb}<0.
\]

This is the discrete-first regime.

## Piecewise fixed-representative law

Within a region where the relevant coarse representatives remain unchanged,

\[
\widetilde M_{cb}(\varepsilon)
=
\widetilde M_{cb}^{(0)}
-\varepsilon G_{1,cb}
-\varepsilon^2G_{2,cb}.
\]

The half-bin / coarse-tie boundary is explicitly non-smooth and is not forced into one fixed-representative polynomial.

## Falsification boundary

A mismatch is theory-relevant only when:

- the exact objective decomposition passes;
- the branch map is resolved;
- no coarse tie is present;
- no topology ambiguity is present;
- the same frozen objective/search semantics are used;
- no practical-beta error or noise has been introduced.

All other mismatches are reported as assumption-boundary cases rather than fitted away.
