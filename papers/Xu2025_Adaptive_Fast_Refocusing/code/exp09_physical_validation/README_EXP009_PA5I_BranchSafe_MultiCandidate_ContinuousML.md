# EXP009 / PA5I
## Branch-Safe Multi-Candidate Continuous ML

PA5H-R1 established a new deterministic failure mechanism:

\[
\boxed{
\text{fractional-bin fence effect}
\rightarrow
\text{coarse DFT winner changes}
\rightarrow
\text{local refinement enters wrong basin}
}
\]

The continuous objective itself remains translation-equivariant.

Therefore PA5I does **not** redesign the physical model. It asks whether a
small multi-candidate search can remove this sparse catastrophic failure at
low computational cost.

---

# 1. Research Question

Can a small number of additional local continuous refinements eliminate
the branch-switch failures of the original coarse-to-fine estimator while
remaining much cheaper than global search?

---

# 2. Groups

## G0 — OriginalTop1

Original PA5G / PA5H estimator:

```text
largest integer DFT bin
        ->
one local continuous refinement
```

This is the baseline.

## G1 — Neighbor3

Starting from the strongest coarse bin \(k_0\):

\[
\{k_0-1,k_0,k_0+1\}
\]

are all refined locally.

The refined candidate with the largest continuous objective is retained.

## G2 — Top2Coarse

Find the two strongest **coarse local maxima** and refine both.

If fewer than two coarse local maxima exist, fill with the next-largest
coarse bin.

## G3 — Top3Coarse

Same as G2 but with three coarse candidates.

## G4 — GlobalReference

Dense global diagnostic search over:

\[
[-1.5,\;1.5]\ {\rm bins}
\]

followed by local refinement around the global grid maximum.

This is **not** a proposed practical estimator.

It is the oracle-like branch reference.

---

# 3. Why G1 and G2 are both necessary

They test two different hypotheses.

### Neighbor3 hypothesis

The correct continuous basin is physically close to the coarse winner, but
the fence effect moves the winning integer sample by one bin.

### Top-K hypothesis

The correct basin may not be adjacent in integer-bin index but is still one
of the strongest coarse local maxima.

If G1 works better, local neighborhood structure is enough.

If G2 works better, peak ranking is more important than adjacency.

---

# 4. Physical parameter grid

Full PA5 physical grid is restored:

```text
Aw/As = [0.1, 0.2, 0.3, 0.5, 0.8]

Delta-v =
[2.5, 5, 7.5, 10, 15, 20] m/s

relative phase:
16 uniform values

eta =
[0, 0.125, 0.25, 0.375, 0.5]

aperture:
Paper1s
BeamDerived
```

This is important because PA5I must demonstrate not only that the known
high-contrast failures are repaired, but also that originally stable
low-contrast cases are not degraded.

---

# 5. Primary metrics

## Branch recovery

Relative to G4:

\[
|\hat\nu_G-\hat\nu_{G4}|
\leq
0.02\ {\rm bin}.
\]

## Catastrophic branch failure

Diagnostic definition:

\[
|\hat\nu_G-\hat\nu_{G4}|
>
0.10\ {\rm bin}.
\]

This threshold is not part of the estimator.

## Objective loss

\[
L_J
=
\frac{
J_{G4}-J_G
}{
J_{G4}
}.
\]

## Computational cost

Record:

- number of local refinements;
- total approximate objective evaluations.

---

# 6. Resolution coordinate

PA5I also restores a PA4-style resolution coordinate:

\[
\Gamma
=
\frac{
|\Delta\beta|
}{
W_{\beta,3{\rm dB}}
}.
\]

This lets us map where branch switching occurs in a physically meaningful
contrast-resolution plane.

The important output is therefore not just one average failure rate but a
phase diagram:

\[
(A_w/A_s,\Gamma)
\rightarrow
P_{\rm fail}.
\]

---

# 7. Main expected outcomes

## Branch A — Top-2 or Neighbor-3 eliminates failures

Best case:

\[
P_{\rm catastrophic}\approx0
\]

with only \(2\sim3\) local refinements.

Then the method result becomes:

\[
\boxed{
\text{a tiny multi-candidate refinement set removes a sparse catastrophic
coarse-to-fine failure mode}
}
\]

This is the cleanest outcome.

## Branch B — Top-3 needed

Still useful, but the search-cost story is weaker.

## Branch C — even Top-3 still fails

Then local multi-candidate refinement is insufficient and the failure is
more global than PA5H-R1 suggested.

In that case we should design an adaptive expansion or confidence-guided
fallback rather than blindly increasing K.

---

# 8. Outputs

```text
pa5i_resolution_coordinate.csv
pa5i_trials.csv
pa5i_method_summary.csv
pa5i_by_contrast.csv
pa5i_by_gamma.csv
pa5i_by_eta.csv
pa5i_failure_phase_diagram.csv
pa5i_catastrophic_tail.csv
pa5i_cost_recovery_pareto.csv
pa5i_decision_summary.csv
summary.txt
exp09_pa5i_results.mat
```

Figures:

```text
fig01_branch_recovery_vs_cost.png
fig02_failure_vs_contrast.png
fig03_failure_vs_eta.png
fig04_G0_failure_phase_diagram.png
fig05_G2_failure_phase_diagram.png
fig06_G1_failure_phase_diagram.png
fig07_tail_error_vs_gamma.png
fig08_cost_reliability_pareto.png
fig09_aperture_robustness.png
```

---

# 9. Important interpretation discipline

PA5I does not:

- tune the PA5G evidence gate;
- choose a removal-window length;
- re-fit the first-order bias law;
- add noise or clutter;
- claim G4 as a practical algorithm.

PA5I only answers:

> how much extra local search is required to make the continuous estimator
> branch-safe?

---

# 10. Run

Place the extracted files in:

```text
E:\SAR_Moving_Ship_Refocusing_Reproduction\
papers\Xu2025_Adaptive_Fast_Refocusing\
code\exp09_physical_validation
```

Run:

```matlab
results = exp09_pa5i_branchsafe_multicandidate_ml;
```

Outputs will be written to:

```text
results\exp09_physical_validation\
exp09_pa5i_branchsafe_multicandidate_ml
```
