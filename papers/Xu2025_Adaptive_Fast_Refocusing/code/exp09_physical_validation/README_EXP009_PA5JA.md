# EXP009 / PA5J-A
## Internal Unreliability Indicator Discovery

PA5I and PA5I-R1 established a clean mechanism:

```text
fractional-bin fence effect
        ↓
coarse-winner instability
        ↓
rare catastrophic branch switching
        ↓
Neighbor-3 local candidate protection
        ↓
0 catastrophic failures on the tested dense-risk manifold
```

The next question is no longer:

> Can Neighbor-3 repair the failure?

PA5I-R1 already says yes on the tested regime.

The PA5J question is:

> Can the algorithm know when it actually needs Neighbor-3?

PA5J-A is the **discovery stage** only.

It does **not** tune a final threshold.
It does **not** train a classifier.
It does **not** use global-reference quantities as candidate features.

---

# 1. Research Question

Can the original `G0_OriginalTop1` estimator detect its own impending branch failure from quantities it already has internally?

A useful indicator should satisfy all of the following:

1. discriminate G0 success vs catastrophic branch failure on the original PA5I grid;
2. preserve the same risk direction on the PA5I-R1 dense-risk stress set;
3. work across both `Paper1s` and `BeamDerived`;
4. not require the global reference;
5. preferably cost little or nothing beyond G0.

---

# 2. Data roles

Two datasets are kept separate.

## 2.1 Original PA5I grid

```text
exp09_pa5i_branchsafe_multicandidate_ml/
    pa5i_trials.csv
```

This preserves the **real base rate** of the branch failure.

From PA5I-R1:

```text
G0 catastrophic rate ≈ 0.5729%
```

This dataset is essential because a gate that looks good only on a hand-selected risk set may be useless in normal operation.

## 2.2 PA5I-R1 dense risk set

```text
exp09_pa5i_r1_gamma_denseeta_tail_audit/
    pa5i_r1_dense_eta_trials.csv
```

This is a deliberate stress test on states that actually generated G0 failure.

From PA5I-R1:

```text
G0 conditional catastrophic rate ≈ 35.23%
```

This is **not** treated as the system-wide failure probability.

---

# 3. Candidate indicators

The indicators are grouped by extra computational cost.

## Cost class 0 — coarse FFT only

These are available before any additional refinement.

```text
neighbor_ratio
neighbor_margin
lr_asymmetry
threebin_central_fraction
fivebin_peak_fraction
local_entropy5
coarse_second_ratio
coarse_second_gap
second_localmax_ratio
remote_competitor_ratio
plateau_count90
plateau_count95
```

The most mechanism-motivated family is the local-neighbor family.

For example:

\[
R_{\mathrm{nbr}}
=
\frac{
\max(|Y[k_0-1]|,|Y[k_0+1]|)
}{
|Y[k_0]|
}.
\]

If the winning coarse bin is barely larger than a neighbor,

\[
R_{\mathrm{nbr}}\rightarrow1,
\]

the discrete winner may be fragile to fence-effect geometry.

---

## Cost class 1 — already available after G0

No extra objective evaluation is required.

```text
refine_abs_displacement
refine_boundary_fraction
refinement_gain_rel
```

Example:

\[
D_{\mathrm{ref}}
=
|\hat\nu-k_0|.
\]

A large coarse-to-refined displacement may indicate that the coarse winner was not a stable representation of the continuous peak.

---

## Cost class 2 — two extra objective evaluations

```text
refined_curvature_norm
refined_lr_asymmetry
```

At the G0 refined point, evaluate:

\[
J(\hat\nu-h),\quad
J(\hat\nu+h),
\]

with:

```text
h = 0.05 bin
```

This gives a cheap local curvature / asymmetry diagnostic without running Neighbor-3.

---

# 4. Variables that are NOT candidate gate inputs

The following variables may appear in diagnostic tables, but are explicitly excluded from gate-feature discovery:

```text
Gamma_PA4
A_w/A_s
true eta
global-reference branch error
catastrophic label
```

Why?

Because PA5J is trying to find an **internally observable** reliability signal.

These variables are allowed only for:

- labeling;
- stratification;
- physical interpretation.

---

# 5. Reconstruction audit

PA5J-A regenerates every G0 input signal from the upstream physical parameters and reruns the G0 estimator.

Before any indicator result is accepted, the reconstructed G0 estimate must agree with the stored upstream PA5I result within:

\[
10^{-6}\ \text{bin}.
\]

If this fails, the program stops.

This prevents code drift from being mistaken for a reliability mechanism.

---

# 6. Evaluation metrics

Because the original catastrophic rate is below 1%, accuracy is intentionally not used.

For every candidate feature:

## ROC AUC

Threshold-free ranking quality.

The risk direction is determined only on the original grid.

That same direction is then applied unchanged to the dense-risk set.

This is important: independently flipping the dense-risk direction would hide a non-transferable indicator.

## Average precision

For rare failures, PR behavior is more informative.

The code also reports:

\[
\frac{\mathrm{AP}}{\text{failure prevalence}}
\]

as precision enrichment over a random trigger.

## Fixed trigger-fraction capture

Without choosing a gate threshold, PA5J-A asks:

> If only the top 1%, 2%, 5%, 10%, 20%, ... most suspicious trials were allowed to trigger Neighbor-3, what fraction of catastrophic failures would they contain?

This produces the first empirical answer to the cost-saving question.

## Diagnostic minimum trigger fraction

For each indicator the code also reports the minimum ranked fraction needed to contain:

```text
95% of failures
100% of failures
```

This is an oracle diagnostic only.
It is not the PA5J-B threshold.

---

# 7. Pre-registered discovery screen

For screening only:

```text
min(AUC_original, AUC_dense-risk) >= 0.75
```

and the risk direction must be consistent.

This does **not** become the final adaptive-gate threshold.

Its purpose is only to decide whether a robust univariate internal observable exists.

---

# 8. Expected result branches

## Branch A — strong cheap indicator

If a cost-class-0 feature shows high and transferable discrimination:

```text
proceed to PA5J-B
```

with that coarse feature as the primary gate candidate.

This is the most desirable outcome.

## Branch B — only post-G0 indicator works

If cost class 1 works but coarse-only features do not:

```text
G0 must complete once,
then reliability is judged before accepting it.
```

Still useful, because Neighbor-3 is only run conditionally.

## Branch C — only +2-evaluation indicator works

A local-curvature/asymmetry probe may still be far cheaper than Neighbor-3.

Proceed to PA5J-B with an explicit cost tradeoff.

## Branch D — no robust univariate indicator

Do **not** force a threshold.

The next step would be:

```text
multivariate indicator model
or
new mechanism-derived observable
```

before any adaptive gate is claimed.

---

# 9. Output files

```text
pa5ja_indicator_trials_original.csv
pa5ja_indicator_trials_dense_risk.csv
pa5ja_reconstruction_audit.csv

pa5ja_indicator_summary.csv
pa5ja_failure_capture_curves.csv
pa5ja_aperture_robustness.csv
pa5ja_context_failure_summary.csv
pa5ja_indicator_shortlist.csv
pa5ja_decision_summary.csv

summary.txt
exp09_pa5ja_results.mat
```

Figures:

```text
fig01_indicator_auc_transfer.png
fig02_indicator_ap_enrichment.png
fig03_top_indicator_original_distribution.png
fig04_top_indicator_dense_distribution.png
fig05_original_capture_curves.png
fig06_dense_capture_curves.png
fig07_top_indicator_aperture_robustness.png
fig08_context_failure_vs_contrast.png
fig09_indicator_cost_robustness.png
```

---

# 10. Run

Place the package under:

```text
E:\SAR_Moving_Ship_Refocusing_Reproduction\
papers\Xu2025_Adaptive_Fast_Refocusing\
code\exp09_physical_validation
```

Run:

```matlab
results = exp09_pa5ja_indicator_discovery;
```

---

# 11. Interpretation discipline

A high AUC does not itself prove that a feature is a good production gate.

PA5J-A is only allowed to say:

> this internal observable contains predictive information about the rare branch-switch failure and transfers to the dense-risk stress set.

Threshold selection, cost-aware operating points, false-trigger penalties, and final adaptive logic belong to **PA5J-B**, not this experiment.


---

# Patch note — PA5I-R1 normalized dense schema

The first PA5J-A version assumed that `pa5i_r1_dense_eta_trials.csv`
contained `strong_chirp_rate_discrete` and
`weak_chirp_rate_discrete`.

That assumption was wrong.

PA5I-R1 deliberately uses a normalized two-table layout:

```text
pa5i_r1_dense_eta_trials.csv
    repeated eta/method/result rows

pa5i_r1_dense_eta_risk_states.csv
    one physical-parameter row per risk_state_id
```

The patched PA5J-A now:

1. validates each source file against its actual storage schema;
2. reads `pa5i_r1_dense_eta_risk_states.csv`;
3. restores the two chirp-rate columns by `risk_state_id`;
4. cross-checks duplicated `Gamma_PA4`;
5. refuses silent overwrite if two files disagree;
6. runs a second **consumer schema contract** immediately before indicator extraction.

This two-layer schema check is intended to prevent the same class of error in later experiments.
