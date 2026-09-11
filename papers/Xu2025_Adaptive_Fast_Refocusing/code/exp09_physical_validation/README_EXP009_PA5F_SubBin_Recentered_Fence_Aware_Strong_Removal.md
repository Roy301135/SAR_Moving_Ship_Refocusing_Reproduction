# EXP009 / PA5F
## Sub-Bin Recentered / Fence-Aware Strong Removal

PA5E-R1 closed the deterministic implementation audit:

- half-bin numerical tie handling does matter;
- but a nonzero finite-window recoverability floor remains after the
  tie-safe correction.

PA5F is therefore the first **mechanism → method** step.

The goal is not to add another diagnostic patch. It is to ask:

> if off-grid focusing creates the strong-leakage floor, can we actively
> remove the fractional-bin offset before narrowband deletion?

---

## 1. Core mechanism

After the true strong chirp rate is removed, an off-grid focused strong
component is

\[
z[n]
=
e^{j2\pi\eta n/N}.
\]

If a sub-bin estimate \(\hat\eta\) is applied as

\[
x_r[n]
=
x[n]e^{-j2\pi\hat\eta n/N},
\]

then the residual focused offset is

\[
\epsilon
=
\eta-\hat\eta.
\]

The ideal oracle case is

\[
\hat\eta=\eta
\quad\Rightarrow\quad
\epsilon=0.
\]

The strong component then returns to an integer DFT bin.

---

## 2. Four groups

### G0 — Baseline

```text
true strong chirp rate
eta_hat = 0
```

This is the current Wang-style finite-window baseline.

### G1 — OracleRecenter

```text
true strong chirp rate
eta_hat = true eta
```

This is the mechanism upper bound.

If G1 cannot remove the off-grid floor, our PA5D–PA5E mechanism model is
wrong or incomplete.

### G2 — StrongOnlyEstimate

```text
true strong chirp rate
eta_hat estimated from strong-only focused spectrum
```

Estimator:

```text
3-point log-power parabolic interpolation
```

This isolates the intrinsic sub-bin estimator bias.

### G3 — PracticalEstimate

```text
true strong chirp rate
eta_hat estimated from strong + weak coherent mixture
```

The same estimator is used. No estimator shopping is allowed after seeing
the results.

This tests whether weak coherent contamination becomes the practical
bottleneck.

---

## 3. Why beta_s is still oracle

PA5F deliberately uses the **true strong chirp rate** in every group.

Therefore:

\[
\beta_s\text{ error}=0.
\]

This isolates the new question:

\[
\text{sub-bin recentering only}.
\]

FrAc strong-order estimation error will be reintroduced only after the
deterministic recentering mechanism is validated.

Noise is also OFF.

---

## 4. Fixed peak semantics

PA5E-R1 showed that `PlateauAwareTol` is the appropriate numerical
tie-safe peak-centered implementation for this bridge.

PA5F therefore fixes:

```text
Peak semantics = PlateauAwareTol
Gate = 0.7 max magnitude
```

Peak semantics are no longer an experimental factor.

---

## 5. Exact finite-length Dirichlet leakage model

For residual offset

\[
\epsilon=\eta-\hat\eta,
\]

the normalized N-point DFT energy at integer bin \(k\) is

\[
p_k(\epsilon)
=
\left|
\frac{
\sin[\pi(\epsilon-k)]
}{
N\sin[\pi(\epsilon-k)/N]
}
\right|^2.
\]

For the **actual binary removal mask** \(\mathcal M\),

\[
L_0^2
=
1-
\sum_{k\in\mathcal M}
p_k(\epsilon).
\]

PA5F compares:

```text
measured strong leakage L0
vs
Dirichlet-predicted L0
```

for every deterministic floor trial.

This turns the previous empirical fence-effect observation into a direct
finite-length spectral model.

---

## 6. Recoverability floor

The exact ownership identity remains

\[
E_0^2
=
\frac{L_0^2}{r_A^2}
+
D_0^2.
\]

Therefore

\[
r_{\min}
=
\frac{L_0}{\sqrt{1-D_0^2}}
\]

whenever \(D_0<1\).

If oracle recentering works as predicted:

\[
L_0^{\rm G1}\rightarrow0
\]

and hence

\[
r_{\min}^{\rm G1}\rightarrow0.
\]

This is the strongest deterministic test of the PA5D–PA5E mechanism.

---

## 7. Two complementary experiment tracks

### Track A — floor / mechanism track

Groups:

```text
G0
G1
G2
```

Mask selection uses the **strong-only** focused transform.

This produces clean:

- \(L_0\);
- \(D_0\);
- \(r_{\min}\);
- analytic Dirichlet validation.

It is the mechanism track.

### Track B — practical coherent-mixture track

Groups:

```text
G0
G1
G2
G3
```

Mask selection uses the actual

\[
x=s+w.
\]

It sweeps:

- both apertures;
- all fence offsets;
- all physical velocity separations;
- LowV / HighV;
- all weak/strong ratios;
- 16 relative phases;
- all five deletion windows.

It reports:

- waveform error;
- `E <= 1` trial fraction;
- weak-stage success;
- strong leakage;
- weak projection loss;
- eta-estimation error.

---

## 8. Sub-bin estimator

The estimator is fixed before the experiment:

\[
\hat\eta
=
k_0+\delta,
\]

where \(k_0\) is the dominant focused DFT bin and

\[
\delta
=
\frac12
\frac{L_- - L_+}
{L_- - 2L_0 + L_+},
\]

with

\[
L=\log |Y|^2.
\]

The interpolation correction is clipped to

\[
[-0.5,0.5].
\]

No alternative estimator is tried in PA5F.

If G2 is good and G3 is bad:

> weak contamination, rather than the recentering idea, is the bottleneck.

If G2 itself is poor:

> sub-bin estimation is the next mechanism problem.

---

## 9. Physical grid

Inherited unchanged:

- `fc = 3 GHz`
- `PRF = 188 Hz`
- `H = 3000 m`
- `La = 2 m`
- `V = 150 m/s`
- `R0/H = sqrt(2)`
- weak velocity `15 m/s`
- `Delta-v = [2.5,5,7.5,10,15,20] m/s`
- `A_w/A_s = [0.1,0.2,0.3,0.5,0.8]`
- 16 relative phases
- `eta = [0,0.125,0.25,0.375,0.5]`
- `l = [1,3,5,9,17]`
- Paper1s / BeamDerived
- no noise

---

## 10. Built-in startup tests

Before the physical experiment starts, PA5F checks:

### A — half-bin estimator

An ideal half-bin strong-only component must return

```text
eta_hat ≈ 0.5
```

### B — oracle recentering

After exact half-bin recentering, a one-bin removal mask must leave
essentially zero strong leakage.

### C — Dirichlet model

The analytic DFT-bin energy formula must match a direct FFT of an
off-grid tone to numerical precision.

If any of these fail, the physical sweep never starts.

---

## 11. Priority outputs

### Mechanism track

```text
pa5f_floor_trials.csv
pa5f_floor_summary.csv
pa5f_best_floor_summary.csv
pa5f_dirichlet_validation_summary.csv
```

### Practical track

```text
pa5f_practical_trials.csv
pa5f_practical_summary.csv
pa5f_best_practical_summary.csv
pa5f_subbin_estimator_summary.csv
```

### Integrity / decision

```text
pa5f_projection_identity_summary.csv
pa5f_improvement_summary.csv
pa5f_decision_summary.csv
```

---

## 12. Figures

```text
fig01_best_floor_vs_fence_offset.png
fig02_best_L0_vs_fence_offset.png
fig03_subbin_estimator_rmse.png
fig04_best_practical_error_vs_fence.png
fig05_feasible_fraction_vs_fence.png
fig06_dirichlet_model_validation.png
fig07_halfbin_floor_vs_window.png
fig08_practical_eta_error_vs_contrast.png
```

---

## 13. Decision branches

### Branch A — mechanism validated, practical method promising

If:

\[
r_{\min}^{G1}\approx0,
\]

the Dirichlet model passes, G2 estimates eta accurately, and G3 improves
the half-bin practical error:

> the deterministic fence-aware correction is validated.

Next stage:

```text
reintroduce strong-order estimation error + noise/clutter
```

### Branch B — oracle works, G2 works, G3 fails

Then:

> mixture-contaminated sub-bin estimation is the bottleneck.

The next experiment should study a robust eta estimator, not abandon
recentering.

### Branch C — oracle works, G2 fails

Then:

> finite-sample sub-bin estimation is the bottleneck.

### Branch D — oracle does not collapse the floor

Then the current mechanism model is incomplete and must be revisited
before adding any realism.

---

## 14. Run

Place the files in:

```text
E:\SAR_Moving_Ship_Refocusing_Reproduction\papers\Xu2025_Adaptive_Fast_Refocusing\code\exp09_physical_validation
```

Run:

```matlab
results = exp09_pa5f_subbin_recenter_removal;
```

Outputs:

```text
results\exp09_physical_validation\exp09_pa5f_subbin_recenter_removal
```
