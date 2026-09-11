# EXP009 / PA5B — LS Projection Error Decomposition

PA5B is a **mandatory correction/audit step** before adding noise.

## Critical implementation issue found while formalizing PA5

For MATLAB row vectors and

```matlab
x ~= c*h
```

the correct complex least-squares coefficient is

```matlab
c = (x*h')/(h*h');
```

because MATLAB `'` is the conjugate transpose.

PA5 used

```matlab
c_legacy = (h*x')/(h*h');
```

which is generally the complex conjugate of the required coefficient.

Therefore PA5 G2/G3 quantitative rescue and residual-error values must be
treated as **provisional** until PA5B is run.

PA5B does not hide this issue. It explicitly replays both the legacy and
corrected formulas.

## PA5B goals

1. Corrected PA5 replay.
2. Legacy-vs-correct quantitative audit.
3. Exact projection-error identity validation.
4. Strong-subtraction accuracy tolerance map.

## Exact error decomposition

With corrected LS projection,

\[
r = (I-P_h)(s+w)
\]

and

\[
e=r-w=(I-P_h)s-P_hw.
\]

The two terms are orthogonal, hence

\[
\|e\|^2
=
\|(I-P_h)s\|^2+\|P_hw\|^2.
\]

Define

\[
\rho_{sh}=\frac{|\langle s,h\rangle|}{\|s\|\|h\|},
\qquad
\rho_{wh}=\frac{|\langle w,h\rangle|}{\|w\|\|h\|},
\]

and \(r_A=A_w/A_s\). Then

\[
\frac{\|e\|^2}{\|w\|^2}
=
\frac{1-\rho_{sh}^2}{r_A^2}
+
\rho_{wh}^2.
\]

The first term is **strong mismatch leakage amplified relative to weak**.
The second is **weak projection loss**.

## Tolerance map

PA5B imposes

\[
\delta_\beta=
\frac{\hat\beta_s-\beta_s}{W_\beta}
\]

over `[-0.30,0.30]` and computes how small \(|\delta_\beta|\) must be for

- `||r-w||/||w|| <= 0.5`
- `||r-w||/||w|| <= 1.0`

for every tested geometry and weak/strong ratio.

## First file to inspect

After running, inspect:

`pa5b_identity_validation_summary.csv`

The exact identity must satisfy:

`max_identity_abs_error <= 1e-10`

If this fails, stop interpretation and debug.

Then inspect:

`pa5b_legacy_vs_correct_audit.csv`

to determine how much PA5 must be revised.

## Run

Place the files in:

`E:\SAR_Moving_Ship_Refocusing_Reproduction\papers\Xu2025_Adaptive_Fast_Refocusing\code\exp09_physical_validation`

Run:

```matlab
results = exp09_pa5b_projection_error_decomposition;
```

Outputs go to:

`results\exp09_physical_validation\exp09_pa5b_projection_error_decomposition`

No noise is introduced in PA5B.
