# EXP009 / PA5G
## Continuous Sub-Bin Estimation and Evidence-Gated Recentering

PA5F produced two simultaneous results:

1. **mechanism validation succeeded**:
   exact recentering collapses the off-grid leakage floor and the
   finite-length Dirichlet model predicts \(L_0\) essentially exactly;

2. **the practical estimator became the bottleneck**:
   - the fixed 3-point log-power parabola has deterministic bias at
     intermediate offsets;
   - blind mixture-based recentering can generate false correction even
     when the true offset is zero.

PA5G addresses those two deterministic problems directly.

---

## 1. Research questions

### RQ1

Can a continuous model-derived estimator remove the PA5F interpolation
bias without estimator shopping?

### RQ2

After that deterministic bias is removed, how much sub-bin error is caused
only by coherent weak contamination?

### RQ3

Can a data-driven evidence gate suppress the on-grid false-correction
problem while retaining the large-off-grid recentering gain?

---

## 2. Continuous ML / LS estimator

After true strong dechirping,

\[
z[n]
=
A_s e^{j2\pi \nu n/N}
+
u[n],
\]

where \(u[n]\) is deterministic contamination from the weak component.

For a candidate \(\nu\), fit an unknown complex amplitude:

\[
\hat c(\nu)
=
\arg\min_c
\|z-c\,a(\nu)\|^2.
\]

This gives the concentrated objective

\[
J(\nu)
=
\left|
\sum_{n=0}^{N-1}
z[n]e^{-j2\pi\nu n/N}
\right|^2.
\]

The PA5G estimate is

\[
\boxed{
\hat\nu_{\rm ML}
=
\arg\max_\nu J(\nu)
}
\]

within a local interval around the dominant integer DFT bin.

A 33-point deterministic grid is used only to identify a local bracket.
The final estimate comes from `fminbnd`, so it is not grid-quantized.

The old PA5F log-parabolic estimator is retained only as an audit baseline.

---

## 3. Why the correction uses only the fractional component

The removal mask can already follow an integer-bin peak.

Therefore the method only needs to remove

\[
\hat\eta
=
\hat\nu-\operatorname{round}(\hat\nu).
\]

This maps the focused strong component to its nearest integer DFT bin
without imposing an unnecessary full-bin shift.

---

## 4. Evidence gate

Blind recentering is unsafe because a coherent weak component can shift
the apparent strong peak even when the true strong offset is zero.

PA5G therefore compares two nested models.

### H0 — integer-bin model

\[
\nu=\operatorname{round}(\hat\nu).
\]

Unknown parameters:

- real part of complex amplitude;
- imaginary part of complex amplitude.

So:

\[
k_0=2.
\]

### H1 — continuous-frequency model

\[
\nu=\hat\nu_{\rm ML}.
\]

This adds one real frequency parameter:

\[
k_1=3.
\]

For either model,

\[
\mathrm{BIC}
=
N\ln(\mathrm{RSS}/N)
+
k\ln N.
\]

Define:

\[
\Delta\mathrm{BIC}
=
\mathrm{BIC}_{H0}
-
\mathrm{BIC}_{H1}.
\]

Positive values favor a true continuous-frequency model.

However, BIC alone may still treat structured weak contamination as
evidence for a fractional shift.

So PA5G adds a second, internal-consistency requirement.

---

## 5. Split-aperture uncertainty

Using the same dechirped data, estimate frequency separately on the first
and second aperture halves:

\[
\hat\nu_L,\qquad\hat\nu_R.
\]

Define:

\[
U_{\rm split}
=
|\hat\nu_L-\hat\nu_R|.
\]

A true strong center-frequency offset is constant across the aperture,
whereas coherent contamination from a mismatched weak chirp can produce
different local apparent shifts.

The PA5G primary gate is therefore:

\[
\boxed{
\Delta\mathrm{BIC}>0
\quad\text{and}\quad
|\hat\eta|>U_{\rm split}
}
\]

This contains **no tuned physical threshold**.

The estimated shift simply has to exceed the data's own internal
split-aperture disagreement.

---

## 6. Groups

### G0 — Baseline

```text
eta_used = 0
```

### G1 — OracleRecenter

```text
eta_used = true eta
```

Mechanism upper bound.

### G2 — ContinuousStrongOnly

```text
eta_used = continuous ML estimate from strong-only data
```

Not practical. It isolates continuous-estimator bias.

### G3 — ContinuousMixtureAlways

```text
eta_used = continuous ML estimate from strong+weak mixture
always recenter
```

This shows what happens after interpolation bias is removed but blind
correction is retained.

### G4 — EvidenceGatedMixture

```text
continuous mixture estimate
+
BIC evidence
+
split-aperture consistency
```

This is the deterministic practical candidate.

---

## 7. Fixed variables

Unchanged from PA5F:

- `fc = 3 GHz`
- `PRF = 188 Hz`
- `H = 3000 m`
- `La = 2 m`
- `V = 150 m/s`
- `R0/H = sqrt(2)`
- weak velocity = `15 m/s`
- `Delta-v = [2.5,5,7.5,10,15,20] m/s`
- `A_w/A_s = [0.1,0.2,0.3,0.5,0.8]`
- 16 relative phases
- `eta = [0,0.125,0.25,0.375,0.5]`
- removal windows `l = [1,3,5,9,17]`
- Paper1s / BeamDerived
- `PlateauAwareTol`
- `0.7` transform-domain peak gate
- true strong chirp rate
- no noise
- no clutter

---

## 8. Startup tests

Before the long physical sweep, PA5G checks:

1. the continuous estimator recovers every target strong-only
   \(\eta\) to the prescribed numerical solver accuracy;

2. the evidence gate stays OFF for an exact on-grid single tone;

3. the evidence gate turns ON for an exact quarter-bin single tone.

If any test fails, the physical experiment does not start.

---

## 9. Priority outputs

### Estimator audit

```text
pa5g_strongonly_estimator_trials.csv
pa5g_strongonly_estimator_summary.csv
```

### Deterministic floor

```text
pa5g_floor_trials.csv
pa5g_floor_summary.csv
pa5g_best_floor_summary.csv
```

### Gate audit

```text
pa5g_gate_trials.csv
pa5g_gate_summary.csv
pa5g_gate_by_contrast.csv
```

### Practical removal

```text
pa5g_practical_trials.csv
pa5g_practical_summary.csv
pa5g_best_practical_summary.csv
pa5g_projection_identity_summary.csv
pa5g_improvement_summary.csv
pa5g_decision_summary.csv
```

---

## 10. Figures

```text
fig01_strongonly_estimator_rmse.png
fig02_mixture_continuous_rmse.png
fig03_gate_trigger_vs_eta.png
fig04_gate_selectivity_vs_contrast.png
fig05_best_practical_error_vs_eta.png
fig06_feasible_fraction_vs_eta.png
fig07_ongrid_false_correction_audit.png
fig08_shift_vs_split_disagreement.png
```

---

## 11. Expected result branches

### Branch A — continuous estimator and gate both work

Expected pattern:

\[
\mathrm{RMSE}_{G2}\rightarrow0,
\]

on-grid gate triggers are much lower than BIC-only triggers, and

\[
E_{G4}(\eta=0)
<
E_{G3}(\eta=0),
\]

while

\[
E_{G4}(\eta=0.5)
<
E_{G0}(\eta=0.5).
\]

Then:

> continuous sub-bin estimation + evidence-gated recentering becomes a
> legitimate deterministic method candidate.

Only after this branch should noise, clutter, and strong-order estimation
error be reintroduced.

### Branch B — continuous estimator works, gate still false-triggers

Then:

> interpolation bias is solved, but model selection under coherent
> contamination remains the bottleneck.

The next stage should model the mixture-induced estimator perturbation.

### Branch C — gate is too conservative

If on-grid false correction is suppressed but off-grid benefit disappears:

> the split-consistency rule is rejecting too many true fence offsets.

### Branch D — continuous strong-only estimator itself fails

Then the local continuous single-tone model or numerical implementation
must be revisited before any practical conclusions.

---

## 12. Run

Place all files in:

```text
E:\SAR_Moving_Ship_Refocusing_Reproduction\papers\Xu2025_Adaptive_Fast_Refocusing\code\exp09_physical_validation
```

Run:

```matlab
results = exp09_pa5g_continuous_subbin_gating;
```

Outputs:

```text
results\exp09_physical_validation\exp09_pa5g_continuous_subbin_gating
```
