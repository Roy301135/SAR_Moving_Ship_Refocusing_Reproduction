# EXP009 / PA5E-R1
## Numerical Tie-Tolerance Patch

This is a **small archival correction**, not a new broad experiment.

PA5E showed that `PlateauAware` and `LocalMax` were numerically identical,
even though the exact half-bin focused spectrum visually contains two
equal-height dominant bins.

The likely reason is floating-point representation: mathematically equal
samples can differ by a few machine-precision units.

PA5E-R1 tests that directly.

---

## 1. What changes

Four semantics are compared:

```text
LocalMax
ConnectedSupport
PlateauAwareExact
PlateauAwareTol
```

### LocalMax

PA5C/PA5D legacy rule.

### ConnectedSupport

All bins satisfying

```text
|Y| >= 0.7 max|Y|
```

are retained as threshold support.

### PlateauAwareExact

The PA5E rule using exact floating-point comparisons.

### PlateauAwareTol

A new numerical-equivalence rule.

The tolerance is

\[
\tau_{\rm tie}
=
100\,N\,\mathrm{eps}(\max |Y|).
\]

Therefore this is **not** a physically tuned peak-merging parameter.

It only says:

> samples that differ at floating-point numerical precision should be
> treated as equal for plateau topology.

---

## 2. Scope

Only:

- Paper1s / BeamDerived;
- on-grid \(\eta=0\);
- exact half-bin \(\eta=0.5\);
- true strong parameter;
- zero strong-order mismatch;
- windows \(l=[1,3,5,9,17]\);
- all existing physical velocity separations and LowV/HighV sides.

No noise.

No FrAc estimator.

No Monte Carlo phase sweep.

So this patch should be much faster than PA5E.

---

## 3. Main quantity

For each fixed removal mask:

\[
E_0^2
=
\frac{L_0^2}{r_A^2}
+
D_0^2.
\]

The minimum weak/strong ratio needed for `E0 <= 1` is

\[
r_{\min}
=
\frac{L_0}{\sqrt{1-D_0^2}}.
\]

PA5E-R1 asks whether a true numerical-tolerance-aware plateau rule changes
the half-bin \(r_{\min}\) conclusion.

---

## 4. Expected branches

### Branch A

If:

```text
PlateauAwareExact ≈ LocalMax
PlateauAwareTol   ≈ ConnectedSupport
```

then the prior PA5E coincidence was indeed a numerical tie-handling issue.

If the best PlateauAwareTol \(r_{\min}\) still remains clearly above zero:

> numerical tie handling mattered, but did not create the finite-window
> recoverability floor.

This is the expected clean closure.

### Branch B

If PlateauAwareTol drives the best half-bin \(r_{\min}\) close to zero:

> the previous floor was much more implementation-dependent than PA5E
> suggested.

Then PA5F should be reconsidered before proceeding.

### Branch C

If PlateauAwareTol does not approach ConnectedSupport:

> our plateau/support interpretations are genuinely different beyond
> numerical equality, and the semantics audit remains open.

---

## 5. Built-in self-tests

Before the physical experiment starts, the code runs two small semantic
self-tests.

### Exact plateau

```text
[0.1, 1, 1, 0.1]
```

Expected detected-bin counts:

```text
LocalMax           1
ConnectedSupport   2
PlateauAwareExact  2
PlateauAwareTol    2
```

### Near-tie plateau

The second dominant sample is perturbed only at machine-precision scale.

Expected:

```text
PlateauAwareTol -> 2 bins
```

If either condition fails, MATLAB stops immediately before the experiment.

---

## 6. Priority outputs

```text
pa5er1_tie_diagnostics.csv
pa5er1_floor_summary.csv
pa5er1_semantic_comparison.csv
pa5er1_decision_summary.csv
```

Figures:

```text
fig01_halfbin_tie_tolerance_masks.png
fig02_halfbin_L1_rmin_vs_semantics.png
fig03_halfbin_rmin_vs_window_beam.png
fig04_best_rmin_ongrid_vs_halfbin.png
```

---

## 7. Run

Place the files in:

```text
E:\SAR_Moving_Ship_Refocusing_Reproduction\papers\Xu2025_Adaptive_Fast_Refocusing\code\exp09_physical_validation
```

Run:

```matlab
results = exp09_pa5er1_tie_tolerance_patch;
```

Outputs:

```text
results\exp09_physical_validation\exp09_pa5er1_tie_tolerance_patch
```

After this patch is closed, the planned next research stage is:

```text
PA5F — Sub-Bin Recentered / Fence-Aware Strong Removal
```
