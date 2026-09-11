# EXP009 / PA5D
## Window-Normalized and Fence-Effect Robustness of Strong Removal

PA5C established the Wang-style transform-domain removal mechanism:

\[
E^2 =
\left(\frac{L_s}{r_A}\right)^2 + D_w^2,
\]

with a clear strong-leakage / weak-projection-loss tradeoff.

PA5D does **not** add noise yet. It first closes three methodological
loopholes that could otherwise make the PA5C result look stronger than it
really is.

---

## 1. Research questions

### RQ1 — fixed bins vs fair bandwidth comparison

PA5C used the same bin counts

```text
l = [1,3,5,9,17]
```

for Paper1s and BeamDerived.

But the two apertures have different `N`, so the same `l` means different

\[
l/N
\]

and different transform-domain physical bandwidth

\[
\Delta f = l\,PRF/N.
\]

PA5D therefore compares:

- `FixedBins`: PA5C convention;
- `BandwidthMatched`: equal target `l/N`, referenced to Paper1s.

Since PRF is the same, equal `l/N` is also equal physical filter bandwidth.

This prevents us from falsely attributing a filter-bandwidth difference
to the aperture itself.

---

## 2. RQ2 — fence effect / off-grid focusing

PA5C used `b=0`, which focuses exactly onto the FFT grid.

PA5D introduces

```text
eta = [0, 0.125, 0.25, 0.375, 0.5] bins
```

through

\[
b=\eta/N.
\]

Both strong and weak receive the **same** `b`, so relative center-frequency
separation remains zero. Only off-grid focusing changes.

`eta=0.5` is the standard worst fence-effect position.

The main question is:

> does the leakage/loss tradeoff and balanced removal window remain stable
> when the focused component is not exactly on-grid?

---

## 3. RQ3 — non-clipped tolerance law

PA5C tolerance curves sometimes hit the artificial search limit 0.30.

PA5D replaces that with an adaptive search:

```text
initial |delta_beta|/W = 0.30
double as needed
cap = 2.00
grid step = 0.0025
```

The code searches until the connected `E<=1` region around zero actually
crosses the threshold.

If it still reaches the search cap, the result is marked as **censored**
instead of being falsely reported as an exact tolerance.

---

## 4. RQ4 — directional tolerance

For off-grid peaks, PA5D reports separately:

\[
\delta^-_{\max}
\]

and

\[
\delta^+_{\max}.
\]

It also reports

```text
tolerance_directional_asymmetry
```

so that any positive/negative mismatch asymmetry is measured rather than
silently averaged away.

This is useful in light of the earlier EXP009 discussion about apparently
directional peak shifts.

---

## 5. Window families

### FixedBins

```matlab
[1 3 5 9 17]
```

for both apertures.

### BandwidthMatched

Target fractions are:

```text
[1 3 5 9 17] / N_Paper1s
```

For each aperture these fractions are converted to the nearest positive
odd bin count.

Thus BeamDerived will generally use more bins than Paper1s for the same
normalized/physical bandwidth.

The exact values are written to:

```text
pa5d_window_specifications.csv
```

---

## 6. Error ownership remains exact

For every fixed binary removal mask:

\[
e=(I-Q)s-Qw.
\]

Under the unitary bridge:

\[
\|e\|^2
=
\|(I-Q)s\|^2+\|Qw\|^2.
\]

Therefore PA5D still records:

- strong leak ratio `L_s`;
- weak projection loss `D_w`;
- total predicted error;
- measured residual error;
- numerical identity error.

The projection identity must still pass at machine precision.

---

## 7. Balanced window

PA5C's `l=3` is **not** assumed optimal.

For every:

- aperture;
- window family;
- fractional-bin offset,

PA5D chooses a balanced candidate:

1. find the maximum weak-stage success rate;
2. keep windows with success at least 90% of that maximum;
3. among those, select minimum median residual error.

This gives a transparent operational compromise rather than a hand-picked
window.

---

## 8. Tolerance scaling law

For one representative physical geometry (`Delta-v=10 m/s`, HighV), PA5D
computes the connected-safe tolerance for:

\[
E=\|r-w\|/\|w\|\le1.
\]

For each:

- aperture;
- window family;
- window index;
- fractional-bin offset;
- weak/strong ratio,

the code returns:

- negative tolerance;
- positive tolerance;
- symmetric tolerance;
- directional asymmetry;
- censoring flags.

Then it fits, through the origin,

\[
\delta_{\rm tol}\approx\alpha r_A
\]

and reports `R^2`.

`alpha` is explicitly treated as an experiment-specific descriptor, not
a universal constant.

---

## 9. Physical grid

Inherited unchanged:

- `fc = 3 GHz`
- `PRF = 188 Hz`
- `H = 3000 m`
- `La = 2 m`
- `V = 150 m/s`
- `R0/H = sqrt(2)`
- `v_w = 15 m/s`
- `Delta-v = [2.5,5,7.5,10,15,20] m/s`
- `A_w/A_s = [0.1,0.2,0.3,0.5,0.8]`
- 16 relative phases
- Paper1s / BeamDerived
- no noise

---

## 10. Priority outputs

First inspect:

```text
pa5d_projection_identity_summary.csv
pa5d_window_specifications.csv
pa5d_window_family_comparison.csv
pa5d_balanced_window_by_offset.csv
pa5d_tolerance_summary.csv
pa5d_tolerance_scaling_summary.csv
pa5d_decision_summary.csv
```

Figures:

```text
fig01_balanced_error_vs_fence_offset.png
fig02_balanced_success_vs_fence_offset.png
fig03_halfbin_leakage_loss_vs_bandwidth.png
fig04_fixed_vs_bandwidth_matched.png
fig05_balanced_bandwidth_vs_fence_offset.png
fig06_tolerance_vs_contrast_and_offset.png
fig07_halfbin_directional_tolerance.png
fig08_tolerance_scaling_R2_map.png
```

---

## 11. Interpretation branches

### Branch A

If bandwidth normalization barely changes the conclusions and tolerance
scaling remains strong across fence offsets:

> the PA5B/PA5C mechanism is robust enough to move toward noise/clutter.

### Branch B

If the core tolerance scaling survives but fence offset changes the
balanced bandwidth or quantitative error substantially:

> the mechanism survives, but practical removal must be fence-aware.

### Branch C

If equal-bandwidth comparison reverses the aperture conclusion:

> part of PA5C's aperture advantage was a window-normalization artifact.

### Branch D

If the tolerance-vs-contrast scaling collapses off-grid:

> the simple PA5B local tolerance law is not operator-robust and must be
> replaced by a fence-aware model.

Every branch is scientifically useful.

---

## 12. Run

Place the files in:

```text
E:\SAR_Moving_Ship_Refocusing_Reproduction\papers\Xu2025_Adaptive_Fast_Refocusing\code\exp09_physical_validation
```

Run:

```matlab
results = exp09_pa5d_window_fence_robustness;
```

Outputs:

```text
results\exp09_physical_validation\exp09_pa5d_window_fence_robustness
```

Noise remains OFF in PA5D.
