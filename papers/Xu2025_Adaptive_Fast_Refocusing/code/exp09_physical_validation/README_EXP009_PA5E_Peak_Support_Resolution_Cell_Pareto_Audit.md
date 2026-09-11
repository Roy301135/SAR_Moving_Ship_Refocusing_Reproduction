# EXP009 / PA5E
## Peak-Support / Resolution-Cell / Pareto Audit

PA5D exposed a major off-grid effect, but it also exposed two possible
confounders:

1. the exact discrete meaning of Wang's `FindPeak(|g| > 0.7 max)` step;
2. the arbitrary operating-point choice introduced by our previous
   "90% balanced success" rule.

PA5E closes those issues **before adding noise**.

---

## 1. Research questions

### RQ1 — Is the half-bin failure a peak-semantics artifact?

PA5C/PA5D used a conventional local-max rule with a directional tie rule:

```text
strictly greater than the left neighbor
greater than or equal to the right neighbor
```

At an exact half-bin focused peak, two adjacent DFT bins can be nearly
equal. That convention can retain only one member.

PA5E therefore audits three discrete interpretations.

### `LocalMax`

Legacy PA5C/PA5D behavior.

### `ConnectedSupport`

Every transform-domain sample satisfying

```text
|Y| >= 0.7 * max(|Y|)
```

is treated as detected support.

The requested `l`-bin window acts as a dilation around this support.

This is the most literal "thresholded support" interpretation.

### `PlateauAware`

A symmetric local-max rule:

```text
>= left
>= right
and > at least one neighbor
```

Therefore a two-bin equal maximum retains both members.

The `l`-bin narrowband window is placed around every retained maximum.

**Important:** Wang 2023 does not disambiguate these discrete tie/support
semantics in the published algorithm text. PA5E treats them as an
implementation-sensitivity audit. It does not claim that any one of them
is the authors' private-code implementation.

---

## 2. RQ2 — What is the natural window coordinate?

PA5D compared fixed bins and equal physical bandwidth by actually changing
the operator window.

PA5E uses a cleaner test.

The **same actual operators**

```text
l = [1,3,5,9,17] bins
```

are expressed in three coordinates:

\[
l,
\]

\[
l/N,
\]

and

\[
\frac{l}{W_{\rm focus,3dB}},
\]

where \(W_{\rm focus,3dB}\) is the oversampled 3-dB power width of a
single correctly focused LFM component, measured in original DFT-bin
units.

Because

\[
B_{\rm win}=l\frac{PRF}{N}
\]

and

\[
B_{\rm focus}=W_{\rm focus,3dB}\frac{PRF}{N},
\]

the third coordinate is also

\[
\frac{B_{\rm win}}{B_{\rm focus}}.
\]

PA5E interpolates the Paper1s and BeamDerived curves in each coordinate
and computes normalized cross-aperture RMSE.

This directly asks:

> which coordinate best collapses the operator behavior?

without changing the operator itself.

---

## 3. RQ3 — Remove the arbitrary balanced-window rule

PA5D selected a "balanced" window by:

1. retaining windows with success at least 90% of the best success;
2. choosing the minimum-error one.

That was useful diagnostically but it is still an arbitrary scalarization.

PA5E removes it.

Every operating point is represented by at least:

- weak-stage success rate;
- fraction of trials with `E <= 1`;
- median waveform error;
- 90th-percentile waveform error;
- strong leakage;
- weak projection loss.

PA5E computes nondominated Pareto points for:

```text
maximize weak-stage success
minimize median waveform error
```

both:

- within each peak semantics;
- globally across all semantics and window lengths.

No 90% success threshold is used in the Pareto definition.

---

## 4. RQ4 — Exact zero-mismatch recoverability floor

For a fixed true-parameter removal mask:

\[
E_0^2
=
\frac{L_0^2}{r_A^2}
+
D_0^2.
\]

Here:

- \(L_0\) is strong leakage at zero strong-order mismatch;
- \(D_0\) is weak projection loss at zero mismatch;
- \(r_A=A_w/A_s\).

For \(D_0<1\), `E0 <= 1` requires

\[
r_A
\ge
r_{\min}
=
\frac{L_0}{\sqrt{1-D_0^2}}.
\]

PA5E computes \(r_{\min}\) over:

- both apertures;
- every fence offset;
- all tested physical velocity separations / sides;
- every peak semantics;
- every window length.

This is the main test of whether the PA5D half-bin floor survives a
tie-safe implementation.

---

## 5. Focused resolution-cell calibration

For each aperture and fence offset, PA5E generates an oversampled focused
spectrum with

```text
oversampling = 128
```

and measures its 3-dB **power** width in original N-point DFT-bin units.

Outputs:

```text
pa5e_focus_resolution_cell_calibration.csv
```

The purpose is not to assume in advance that "one bin" is the natural
resolution cell. It is to measure the intrinsic focused width and test
the resulting coordinate empirically.

---

## 6. Physical grid

Inherited unchanged from PA5D:

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
- Paper1s and BeamDerived
- fence offsets `[0,0.125,0.25,0.375,0.5]`
- no noise

The strong and weak components share the same center-frequency offset

\[
b=\eta/N,
\]

so only the off-grid focusing condition changes.

---

## 7. Primary outputs

### Numerical identity

```text
pa5e_projection_identity_summary.csv
```

The fixed-mask identity must remain at numerical precision.

### Peak semantics

```text
pa5e_peak_semantics_summary.csv
```

This directly compares LocalMax, ConnectedSupport and PlateauAware.

### Operating points

```text
pa5e_operating_point_summary.csv
```

### Pareto

```text
pa5e_pareto_all_points.csv
pa5e_pareto_front.csv
pa5e_pareto_semantics_summary.csv
```

### Recoverability floor

```text
pa5e_recoverability_floor_trials.csv
pa5e_recoverability_floor_summary.csv
```

### Coordinate collapse

```text
pa5e_coordinate_collapse_detail.csv
pa5e_coordinate_collapse_summary.csv
```

### Decision

```text
pa5e_decision_summary.csv
```

---

## 8. Figures

```text
fig01_halfbin_peak_semantics_masks.png
fig02_halfbin_rmin_vs_peak_semantics.png
fig03_halfbin_pareto_front_beam.png
fig04_minimum_error_vs_fence_semantics.png
fig05_maximum_success_vs_fence_semantics.png
fig06_coordinate_collapse_strong_leak.png
fig07_halfbin_leakage_loss_operating_points.png
fig08_halfbin_rmin_map_beam.png
```

---

## 9. Result branches

### Branch A — mainly a peak-semantics artifact

If ConnectedSupport / PlateauAware reduce the half-bin \(r_{\min}\) close
to zero while LocalMax remains large:

> the dramatic PA5D half-bin floor was dominated by discrete peak-tie
> handling.

This would be a correction, not a failure.

### Branch B — semantics matters, but a floor survives

If tie-safe methods reduce \(r_{\min}\) substantially but it remains
clearly nonzero:

> the PA5D effect contains both an implementation-semantic component and a
> genuine finite-window fence-effect floor.

This is probably the most interesting mixed case.

### Branch C — floor persists across semantics

If all three semantics give comparable nonzero \(r_{\min}\):

> the recoverability floor is operator-level and not primarily caused by
> the old local-max tie rule.

### Coordinate result

If `l/W_focus` gives the smallest Paper/Beam normalized RMSE:

> resolution-cell normalization is the better operator coordinate.

If raw `l` wins:

> window width measured in transform resolution cells/bins is more natural
> than equal-Hz bandwidth for this removal operator.

If `l/N` wins:

> normalized/physical bandwidth remains the better scale.

No coordinate is assumed correct in advance.

---

## 10. Run

Place the files in:

```text
E:\SAR_Moving_Ship_Refocusing_Reproduction\papers\Xu2025_Adaptive_Fast_Refocusing\code\exp09_physical_validation
```

Run:

```matlab
results = exp09_pa5e_peak_support_pareto_audit;
```

Outputs:

```text
results\exp09_physical_validation\exp09_pa5e_peak_support_pareto_audit
```

Noise remains OFF in PA5E.

---

## v2 patch

Fixed a missing configuration-definition bug in the original PA5E package.

Added:

```matlab
cfg.gamma_unresolved_max = 0.50;
cfg.gamma_partial_max = 1.50;
```

These thresholds are inherited from PA4–PA5D and are required by
`gamma_regime()`.

The main script now also performs a complete startup check of every
`cfg.<field>` referenced by the code. If a future configuration field is
missing, MATLAB will fail immediately with one consolidated
`MissingConfigField` message instead of stopping later inside a nested
helper function.


---

## v3 patch

Fixed the Fig.3 legend construction error:

```text
vertcat: arrays being concatenated have inconsistent dimensions
```

Cause:

- `cellstr(sems)` was a 3×1 cell array;
- `{'Global Pareto front','E=1'}` was a 1×2 cell array;
- vertical concatenation therefore failed.

The figure code now:

1. explicitly stores all plot handles in `gobjects`;
2. constructs every legend label as a column cell;
3. calls `legend(handles, labels, ...)`.

This also removes dependence on MATLAB's implicit graphics-child ordering.

The v2 startup configuration-completeness audit is retained.
