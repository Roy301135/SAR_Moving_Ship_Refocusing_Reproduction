# EXP009-A4 / Pilot-01 — Residual Interference Geometry

## 1. Why A4 matters

A3 established a clean mechanism chain:

```text
practical CLEAN
    -> filtered strong residual remains
    -> weak concentration landscape is perturbed
    -> weak-q estimate shifts
    -> weak-component recovery drops
```

A4 goes one mathematical level deeper:

> **Why does the peak move toward one side, and can that shift be approximated analytically?**

This is potentially important for the final paper because it converts an empirical failure mode into an interpretable local perturbation model.

---

## 2. Mirror-q test

Default:

```text
q_weak = 1.470
q_strong_lower = 1.420
q_strong_upper = 1.520
```

The two strong components are symmetric around q_weak.

If the filtered strong residual is pulling the weak-q estimate toward its own q region, the expected sign pattern is:

```text
q_strong < q_weak  -> negative weak-q bias
q_strong > q_weak  -> positive weak-q bias
```

A sign reversal is much stronger evidence than observing the same negative bias repeatedly.

---

## 3. Exact local matched-response decomposition

For explanation only, A4 introduces an **oracle diagnostic** weak-template response:

```text
C(q) = <r(t), a_w(q,t)>
```

where `a_w(q,t)` uses:

- candidate q;
- the true weak center frequency.

For:

```text
r = s_weak + e_strong
```

linearity gives:

```text
C(q) = C_w(q) + C_e(q)
```

Therefore:

```text
P(q) = |C(q)|^2
     = |C_w(q)|^2
     + |C_e(q)|^2
     + 2 Re{C_w(q) C_e*(q)}
```

Define:

```text
P_w     = |C_w|^2
P_e     = |C_e|^2
P_cross = 2 Re{C_w C_e*}
DeltaP  = P_e + P_cross
```

The important point is that the residual does not only contribute its own power `P_e`. Because the response is coherent, it also generates a **cross-term** with the weak component.

---

## 4. First-order peak-shift approximation

For the weak-only response, the maximum is at q_weak:

```text
P_w'(q_weak) ~= 0
```

After residual interference:

```text
P_total(q) = P_w(q) + DeltaP(q)
```

Let the new peak be:

```text
q_hat = q_weak + delta_q
```

For a sufficiently small perturbation:

```text
0 ~= P_total'(q_weak)
   + delta_q * P_w''(q_weak)
```

Since `P_w'(q_weak) ~= 0`:

```text
delta_q
~= - DeltaP'(q_weak) / P_w''(q_weak)
```

This is the central mathematical hypothesis tested by A4.

Because:

```text
P_w''(q_weak) < 0
```

the sign of the peak shift is controlled by the local slope:

```text
DeltaP'(q_weak)
```

If the residual interference raises the left side of the weak peak more strongly, `DeltaP'` becomes negative and the estimated q shifts left.

---

## 5. Why the cross-term may matter more than residual energy alone

A3 showed that reducing the total filtered-strong residual energy did not necessarily remove the persistent bias.

A4 separates:

```text
dP_e/dq
```

from:

```text
dP_cross/dq
```

at q_weak.

This allows a stronger question:

> Is peak pulling driven mainly by the residual's own local power, or by coherent interference between the weak component and the reshaped strong residual?

If:

```text
|dP_cross/dq| >> |dP_e/dq|
```

then the persistent bias is better explained as a **coherent interference geometry** problem rather than a simple residual-energy problem.

That would be a useful mathematical explanation for the final paper.

---

## 6. Experiment structure

### Part A — Noiseless mirror test

For lower and upper strong q:

- apply the same fixed CLEAN notch;
- obtain filtered strong residual;
- add it to the weak component;
- compare:
  - operational q bias;
  - oracle matched-response q bias;
  - first-order predicted bias;
  - derivative contributions.

### Part B — Small separation sweep

Use:

```text
|q_s - q_w| = 0.02, 0.03, 0.04, 0.05, 0.06
```

on both sides.

This is **not** the full failure map.

It only checks whether:

- bias sign follows relative q position;
- first-order prediction remains valid;
- derivative/cross-term geometry changes systematically with separation.

### Part C — Monte Carlo mirror validation

100 shared noise realizations.

Compare:

```text
Baseline = s_weak + noise
```

versus:

```text
s_weak + noise + filtered strong residual
```

for both lower and upper q_strong.

---

## 7. Strongest expected outcome

The most convincing result would be:

```text
Lower strong:
    operational bias < 0
    matched-response bias < 0
    predicted bias < 0

Upper strong:
    operational bias > 0
    matched-response bias > 0
    predicted bias > 0
```

and the Monte Carlo distributions should show the same sign reversal.

Even better, if:

```text
|dP_cross/dq| > |dP_e/dq|
```

over much of the separation sweep, the paper-level explanation becomes:

```text
filtered strong residual
    -> coherent cross-term with weak component
    -> asymmetric local perturbation of weak concentration curve
    -> first-order peak pulling
```

---

## 8. When the first-order approximation may fail

The approximation:

```text
delta_q ~= -DeltaP' / P_w''
```

assumes a relatively small perturbation.

It may become inaccurate when:

- strong residual is too large;
- q separation is very small;
- the total curve becomes multi-peaked;
- the peak moves several grid cells.

That is not a coding failure. It would define the boundary between:

```text
small-perturbation peak pulling
```

and:

```text
catastrophic peak replacement / mode switching
```

which may itself become useful in the later failure map.

---

## 9. Recommended placement

```text
papers/
└── Xu2025_Adaptive_Fast_Refocusing/
    ├── code/
    │   └── exp09_pilot01/
    │       ├── exp09a4_residual_geometry.m
    │       └── config_exp09a4.m
    └── results/
        └── exp09_pilot01/
            └── exp09a4_residual_geometry/
```

---

## 10. Run

```matlab
cd <...>/Xu2025_Adaptive_Fast_Refocusing/code/exp09_pilot01
results = exp09a4_residual_geometry;
```

---

## 11. Outputs

```text
mirror_noiseless_summary.csv
separation_sweep_summary.csv
mirror_mc_trials.csv
mirror_mc_summary.csv
summary.txt
exp09a4_results.mat

fig01_mirror_operational_curves.png
fig02_lower_decomposition.png
fig03_upper_decomposition.png
fig04_mirror_DeltaP.png
fig05_separation_vs_bias.png
fig06_derivative_contributions.png
fig07_residual_energy_vs_separation.png
fig08_mc_mirror_bias.png
fig09_mc_mirror_recovery.png
```

---

## 12. Paper-level caution

Even if the mathematical picture is supported, A4 is still based on the controlled synthetic MC-LFM model.

The safe wording at this stage is:

> "A first-order perturbation analysis suggests that the filtered residual can induce directional peak pulling through asymmetric coherent interference."

Only after the later parameter failure map and SAR validation should it be elevated to a broader claim.
