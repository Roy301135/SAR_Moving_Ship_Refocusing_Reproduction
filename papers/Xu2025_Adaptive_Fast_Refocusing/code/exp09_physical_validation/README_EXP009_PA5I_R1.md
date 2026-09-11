# EXP009 / PA5I-R1
## PA4-Gamma Consistency, Dense-Fence Sweep, and Rare-Tail Audit

PA5I found a strong result:

- `G0 OriginalTop1`: rare catastrophic branch switching;
- `G1 Neighbor3`: zero catastrophic failures on the original 5-point eta grid;
- `G2 Top2Coarse`: most failures removed, but not all;
- `G3 Top3Coarse`: nearly all failures removed;
- `G4 GlobalReference`: diagnostic oracle-like reference.

However, three issues must be audited before moving to PA5J.

---

## R1-A — restore the PA4 resolution coordinate

PA4 defined:

\[
a_i=\frac{K_{\mathrm{res},i}}{\mathrm{PRF}^2},
\qquad
\beta_i=\arctan(a_i)
\]

and

\[
\Gamma
=
\frac{
|\beta_s-\beta_w|
}{
W_{\beta,3\mathrm{dB}}
}.
\]

PA4's measured intrinsic widths were:

```text
Paper1s:
W_beta,3dB = 1.70e-4 rad

BeamDerived:
W_beta,3dB = 8.60e-5 rad
```

Therefore PA5I-R1 does **not** re-estimate a new width in another coordinate.
It restores these upstream PA4 anchors directly.

Internal anchor checks include approximately:

```text
Paper1s, HighV, dv=5 m/s:
Gamma ~= 0.328

Paper1s, HighV, dv=20 m/s:
Gamma ~= 1.365

BeamDerived, HighV, dv=5 m/s:
Gamma ~= 0.648

BeamDerived, HighV, dv=20 m/s:
Gamma ~= 2.698
```

If these checks fail, the program stops.

---

## R1-B — dense eta on the actual PA5I risk manifold

Instead of inventing a new set of "difficult" parameters, PA5I-R1 reads:

```text
pa5i_trials.csv
```

and finds every unique physical/phase state for which:

```text
G0_OriginalTop1
```

actually produced a catastrophic branch failure.

The original failing eta value is removed from the state identity.

For each such risk state, PA5I-R1 then sweeps:

\[
\eta = 0:0.01:0.5.
\]

This directly asks:

> Does Neighbor-3 remain branch-safe between the five eta points used by PA5I?

The same four practical methods are retained:

```text
G0 OriginalTop1
G1 Neighbor3
G2 Top2Coarse
G3 Top3Coarse
```

plus:

```text
G4 GlobalReference
```

---

## Global-reference acceleration audit

A dense eta sweep can make the original `0.001-bin` global grid expensive.

Therefore R1 uses:

```text
0.01-bin global grid
+ continuous local refinement
```

for the full dense sweep.

Before running the dense audit, a deterministic subset is cross-checked
against the original:

```text
0.001-bin global grid
+ local refinement.
```

If the resulting continuous peak positions disagree by more than:

\[
10^{-5}\ \text{bin},
\]

the program stops.

Thus the faster reference cannot silently alter the branch-safety result.

---

## R1-C — rare-tail metrics

PA5I showed that p95 can completely hide a sub-1% catastrophic failure mode.

PA5I-R1 therefore reports:

\[
p95,\ p99,\ p99.5,\ p99.9,\ \max,
\]

plus:

\[
P_{\mathrm{catastrophic}}.
\]

The main reliability metric remains the explicit catastrophic branch-failure
rate.

---

# Inputs

The experiment expects the upstream file:

```text
results/
  exp09_physical_validation/
    exp09_pa5i_branchsafe_multicandidate_ml/
      pa5i_trials.csv
```

No manual copying of the CSV into the code directory is needed.

---

# Outputs

```text
pa5i_r1_trials_with_corrected_gamma.csv
pa5i_r1_corrected_gamma_states.csv
pa5i_r1_pa4_gamma_anchor_audit.csv
pa5i_r1_corrected_gamma_failure_phase.csv

pa5i_r1_rare_tail_original_grid.csv

pa5i_r1_dense_eta_risk_states.csv
pa5i_r1_global_reference_validation.csv
pa5i_r1_dense_eta_trials.csv
pa5i_r1_dense_eta_failure_profile.csv
pa5i_r1_rare_tail_dense_risk.csv
pa5i_r1_dense_cost_reliability.csv

pa5i_r1_decision_summary.csv
summary.txt
exp09_pa5i_r1_results.mat
```

Figures:

```text
fig01_restored_pa4_gamma.png
fig02_G0_corrected_gamma_phase.png
fig03_G1_corrected_gamma_phase.png
fig04_dense_eta_failure_profile.png
fig05_dense_eta_max_branch_error.png
fig06_rare_tail_original_grid.png
fig07_rare_tail_dense_risk.png
fig08_dense_cost_reliability.png
fig09_global_reference_crosscheck.png
```

---

# Decision rule

PA5I-R1 allows progression to PA5J only when:

1. PA4 Gamma anchor audit passes;
2. Neighbor-3 has zero catastrophic failures on the dense-risk sweep;
3. Neighbor-3's maximum branch error stays below the branch-match gate.

Then the decision becomes:

```text
PA5I_CONFIRMED_PROCEED_TO_PA5J_ADAPTIVE_CONFIDENCE_GATE
```

Otherwise PA5I remains open.

---

# Interpretation discipline

A zero failure rate in this experiment means:

> Neighbor-3 is branch-safe over the tested dense eta sweep of the
> empirically observed PA5I risk manifold.

It does **not** mean a proof for arbitrary velocity, phase, aperture,
contrast, noise, clutter, or untested parameter ranges.

---

# Run

Extract these files to:

```text
E:\SAR_Moving_Ship_Refocusing_Reproduction\
papers\Xu2025_Adaptive_Fast_Refocusing\
code\exp09_physical_validation
```

Run:

```matlab
results = exp09_pa5i_r1_gamma_denseeta_tail_audit;
```
