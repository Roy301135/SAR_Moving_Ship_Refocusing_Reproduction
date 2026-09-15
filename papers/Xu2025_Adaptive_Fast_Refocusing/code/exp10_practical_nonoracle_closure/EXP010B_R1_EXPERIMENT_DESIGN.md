# EXP010-B-R1 — Neighbor-3 Recovery-Operator Ownership Audit

## Status

Targeted deterministic audit after EXP010-B formal closure.

This is **not** a new method experiment and does **not** reopen policy design.

## Trigger

EXP010-B established all of the following simultaneously:

- Oracle firewall passed;
- frozen Refined-LR / FiveBin risk directions did not reverse;
- Proposed achieved strict positive branch-reliability gain on both DenseRisk apertures;
- Proposed induced zero branch catastrophes;
- but `Always_Neighbor3` retained deterministic catastrophic branch failures in the fully practical chain.

Therefore the previous unconditional wording that Neighbor-3 is “branch safe” no longer transfers automatically from PA5I to the fully practical beta-estimation chain.

## Research Question

Why does Neighbor-3 lose branch safety after practical strong-beta estimation?

Three possible ownership classes are tested:

1. **Upstream beta-hat mismatch / landscape deformation**
   - practical beta-hat distorts the dechirped objective enough that the PA5I adjacency assumption no longer holds;
2. **Adjacency / candidate-coverage limitation**
   - even under true beta, the global continuous basin lies outside the union of the three local refinement intervals;
3. **Local-refinement / implementation transfer issue**
   - the global basin is covered, but the inherited local refinement still does not recover it.

## Controls

For every current `Always_Neighbor3` catastrophic failure from EXP010-B:

### A. Practical-beta replay

Reconstruct the trial and rerun:

`practical beta-hat -> Neighbor-3 -> practical-beta global reference`

This must reproduce the stored EXP010-B result within tolerance.

### B. True-beta mechanism control

Use simulator true strong beta only in the evaluation-control branch:

`true beta -> same Neighbor-3 -> true-beta global reference`

No truth enters Proposed.

### C. Candidate-coverage geometry

For both A and B, test whether the corresponding global reference lies inside at least one of the three inherited local-search intervals:

`seed in {k0-1,k0,k0+1}, local halfwidth = 0.75 bin`.

## Falsifiers / stop rules

- reconstruction mismatch -> stop: audit code transfer;
- true-beta failures persist **within candidate coverage** -> stop before noise and audit local-refinement semantics;
- true-beta failures persist only because global basin is outside N3 intervals -> report adjacency validity boundary;
- practical failures disappear under true beta -> report that Neighbor-3 branch safety is conditional on upstream beta-estimation accuracy.

## Forbidden actions

- no Neighbor-5;
- no new feature;
- no change of b1/b2;
- no risk-direction changes;
- no new removal width;
- no SNR sweep yet.

## Output philosophy

The main user-feedback artifact is:

`EXP010B_R1_FEEDBACK_BUNDLE.txt`

Raw CSV/MAT files remain locally for traceability.
