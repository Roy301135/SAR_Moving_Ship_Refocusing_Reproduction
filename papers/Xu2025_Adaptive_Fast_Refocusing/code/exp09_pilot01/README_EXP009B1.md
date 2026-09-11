# EXP009-B1 / Pilot-01 — Failure & Mechanism Map

## 1. Why B1 starts now

A1-A4 progressively established:

```text
weak failure exists
    ↓
dominant q estimation is not the main bottleneck
    ↓
practical CLEAN introduces a large late-stage penalty
    ↓
direct weak filtering is not the dominant cause
    ↓
filtered strong residual is the main controlled failure source
    ↓
the local q bias is dominated by a coherent cross-term
```

A4 further showed that the peak-shift sign is **not** determined simply by whether `q_strong` lies above or below `q_weak`.

Therefore B1 is not a blind performance sweep.

Its purpose is:

> **Test whether residual-induced coherent peak shifting forms a stable failure region across weak strength, signed q separation and SNR.**

---

## 2. Why signed separation is used

Originally the failure map was planned as:

```text
A_weak/A_strong × |q_weak-q_strong| × SNR
```

A4 showed that the coherent cross-term is phase-sensitive and can change sign non-monotonically.

Therefore B1 uses:

```text
q_strong - q_weak
```

rather than only its magnitude.

Default:

```text
[-0.06 -0.05 -0.04 -0.03 -0.02
  +0.02 +0.03 +0.04 +0.05 +0.06]
```

This avoids throwing away information that A4 already showed to be important.

---

## 3. Parameter grid

### Weak/strong amplitude ratio

```text
0.20 0.30 0.40 0.50 0.60
```

### Signed q separation

```text
-0.06 ... -0.02, +0.02 ... +0.06
```

### SNR

```text
0, 3, 6 dB
```

### Monte Carlo

```text
50 trials per map cell
```

This is a pilot map.

Do **not** immediately increase every cell to 500 Monte Carlo runs.

If a transition boundary is found, only those cells should later be refined with more realizations.

---

## 4. SNR definition

A key design choice:

```text
SNR is referenced to the strong-component power.
```

Therefore:

```text
noise variance = P_strong / 10^(SNR/10)
```

This means the noise variance does not change simply because the weak amplitude ratio changes.

The weak effective SNR naturally decreases as `A_weak/A_strong` becomes smaller, which is physically consistent with the weak-component problem.

---

## 5. Two Monte-Carlo branches

Every map cell compares paired noise realizations.

### Baseline

```text
s_weak + noise
```

This asks:

> Is the weak component intrinsically recoverable at this weak strength and SNR?

### Residual

```text
s_weak + filtered_strong_residual + noise
```

This asks:

> How much additional damage is created by the sequential CLEAN residual?

The key metric is therefore not only:

```text
Residual Recall
```

but also:

```text
Residual Penalty
=
Baseline Recall - Residual Recall
```

This prevents intrinsic low-SNR failure from being confused with CLEAN-induced failure.

---

## 6. Noiseless mechanism map

For every:

```text
(A_weak/A_strong, signed separation)
```

B1 also calculates:

- filtered-strong residual energy / weak energy;
- noiseless operational q bias;
- oracle matched-response q bias;
- first-order predicted q bias;
- `dP_e/dq`;
- `dP_cross/dq`;
- `dDeltaP/dq`;
- weak-peak curvature;
- first-order prediction error.

This allows the performance heatmap to be paired with a mechanism heatmap.

---

## 7. Main mathematical relation retained from A4

For:

```text
r = s_weak + e_strong
```

define:

```text
C(q) = <r,a_w(q)>
     = C_w(q) + C_e(q)
```

Then:

```text
P(q)
=
|C_w|^2
+
|C_e|^2
+
2 Re{C_w C_e*}
```

and:

```text
DeltaP = P_e + P_cross
```

For small perturbations:

```text
delta_q
≈
- DeltaP'(q_weak) / P_w''(q_weak)
```

A4 showed:

```text
|dP_cross/dq| >> |dP_e/dq|
```

in the studied case.

B1 tests whether this remains true over a wider region.

---

## 8. What would count as a strong B1 result

### Result A — Stable residual penalty region

There is a region where:

```text
baseline recall is high
```

but:

```text
residual recall is clearly lower
```

This proves that weak failure is not merely intrinsic low-SNR difficulty.

### Result B — Cross-term mechanism remains dominant

Over the same region:

```text
|dP_cross/dq| >> |dP_e/dq|
```

and first-order predicted bias tracks matched-response bias.

Then A4's mechanism is not a single-point curiosity.

### Result C — Residual energy alone is insufficient

Cells with similar:

```text
E_residual / E_weak
```

show different bias signs or different recovery penalties.

This would reinforce:

```text
interference geometry > energy alone
```

### Result D — Perturbative-to-catastrophic transition

Some cells show:

```text
small q bias + first-order agreement
```

while harder cells show:

```text
large error / catastrophic peak switching
```

and first-order approximation becomes inaccurate.

This would naturally define two failure regimes for the paper.

---

## 9. Important outputs

```text
mechanism_map_noiseless.csv
performance_map_mc.csv
mc_trial_level.csv
baseline_summary.csv
summary.txt
exp09b1_results.mat
```

### Key figures

```text
fig01_recovery_heatmap.png
fig02_penalty_heatmap.png
fig03_bias_heatmap.png
fig04_catastrophic_heatmap.png
fig05_predicted_bias_heatmap.png
fig06_cross_slope_heatmap.png
fig07_prediction_vs_matched.png
fig08_residual_energy_heatmap.png
fig09_penalty_vs_weak_ratio.png
fig10_theory_vs_mc_bias.png
```

---

## 10. Most important figures conceptually

### `fig02_penalty_heatmap`

This is probably the most important performance figure.

It shows where:

```text
weak component would have been recoverable
```

but:

```text
CLEAN residual makes it fail
```

### `fig06_cross_slope_heatmap`

This is the mechanism counterpart.

If its structure corresponds to the q-bias/failure map, the paper gains a much stronger explanatory story.

### `fig07_prediction_vs_matched`

Tests whether:

```text
delta_q ≈ -DeltaP'/P_w''
```

continues to explain the local peak shift over a parameter region.

### `fig10_theory_vs_mc_bias`

Connects the noiseless mathematical mechanism to actual noisy Monte-Carlo behavior.

---

## 11. Expected qualitative behavior

Do not require exact numbers.

Reasonable expectations from A1-A4 are:

1. Larger weak ratio -> baseline recovery improves.
2. Lower SNR -> baseline recovery worsens.
3. Residual penalty is **not necessarily monotonic** with q separation.
4. Bias sign may oscillate with signed separation because the coherent cross-term is phase-sensitive.
5. Residual-energy/weak-energy ratio should depend strongly on weak ratio, but only weakly on q separation for this controlled fixed-notch model.
6. First-order prediction should work best in modest-bias cells and degrade when peak replacement becomes catastrophic.
7. `dP_cross/dq` should remain much larger than `dP_e/dq` in at least part of the residual-induced failure region.

---

## 12. Runtime philosophy

The default map uses only 50 Monte-Carlo trials per cell.

This is intentional.

B1 is still a pilot mechanism map.

If a stable boundary emerges, later refinement should use:

```text
100–500 MC
```

only around selected transition cells.

Do not spend computation uniformly on obviously easy or obviously impossible cells.

This already follows the broader research principle:

> **allocate computation where uncertainty is high.**

---

## 13. Recommended placement

```text
papers/
└── Xu2025_Adaptive_Fast_Refocusing/
    ├── code/
    │   └── exp09_pilot01/
    │       ├── exp09b1_failure_mechanism_map.m
    │       └── config_exp09b1.m
    └── results/
        └── exp09_pilot01/
            └── exp09b1_failure_mechanism_map/
```

---

## 14. Run

```matlab
cd <...>/Xu2025_Adaptive_Fast_Refocusing/code/exp09_pilot01
results = exp09b1_failure_mechanism_map;
```

---

## 15. Paper-level caution

B1 is still based on the controlled synthetic two-component MC-LFM model.

Even a beautiful map only establishes:

> stable mechanism-level evidence.

The later paper still needs:

- more realistic multi-component / spatially varying signals;
- public SAR data if feasible;
- real group SAR data;
- a simple method improvement;
- quality-cost evaluation.
