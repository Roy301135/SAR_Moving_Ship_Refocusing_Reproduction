# Branch Reliability in SAR — Image-Level Physical Validation

> **Workspace role:** New-stage SAR image-level research derived from the EXP009–EXP011 signal/search-level mechanism study.
>
> This workspace starts a new experiment sequence. Historical EXP009–EXP011 code remains under `papers/Xu2025_Adaptive_Fast_Refocusing/` and is not moved here.

---

## 1. Research Objective

The central question of this workspace is:

> **What does a search-level branch error physically become in the SAR imaging chain, and what scattering structures are restored when that branch is successfully rescued?**

The intended physical chain is:

```text
branch error
        ↓
parameter mismatch
        ↓
phase mismatch
        ↓
SAR focusing mismatch
        ↓
scattering-energy redistribution
        ↓
weak-scatterer loss / ghost / sidelobe structure
        ↓
branch rescue
        ↓
image-level structure recovery
```

The goal is therefore not limited to comparing final image quality.

The research must connect:

```text
search-level mechanism
```

to:

```text
SAR image-level physical consequence
```

---

## 2. Relation to the Historical Xu2025 Research Line

The historical research line is preserved under:

```text
papers/Xu2025_Adaptive_Fast_Refocusing/
```

Its current paper-level findings are summarized as:

### Claim 1 — Failure Mechanism

Finite-window / off-grid sequential removal can create strong-component leakage and weak-component damage. The resulting coherent residual can reshape the downstream search objective and, under difficult regimes, contribute to global branch competition and rare catastrophic branch-selection errors.

### Claim 2 — Reliability-Aware Selective Recovery

Internal search states can be used to allocate Neighbor-3 recovery selectively to high-risk cases, improving reliability at lower cost than Always-N3, subject to an upstream parameter-estimation validity boundary.

The present workspace is not intended to create a third independent algorithmic contribution.

Its purpose is to provide the missing SAR-level physical translation of the existing claims.

---

## 3. Research Boundary

This workspace should remain narrow.

The immediate target is:

```text
search-level paired branch error / rescue
        ↓
controlled SAR imaging consequence
```

The following are not current priorities unless later evidence requires them:

- new reliability features;
- N5 / N7 branch neighborhoods;
- additional broad AWGN sweeps;
- deep-learning detection / recognition;
- large multi-satellite benchmarks;
- new image-domain refocusing algorithms;
- broad sea-clutter statistical modeling.

---

## 4. Experiment Numbering

This workspace starts a new local experiment sequence.

Do **not** continue the historical sequence as:

```text
EXP012
```

Use names such as:

```text
exp01_sar_branch_error_mapping/
exp02_sar_branch_rescue/
exp03_...
```

The numbering is local to this workspace.

---

## 5. First Research Question

The first experiment should establish the smallest causal bridge between search-level branch error and SAR image-level consequence.

A minimal initial question is:

> **For the same controlled scattering scene and the same underlying SAR data, how does a deliberately wrong branch change focusing, scattering-energy distribution, weak-scatterer visibility, and ghost/sidelobe structure relative to the correct branch?**

The initial comparison should prioritize:

```text
Correct / oracle branch
Wrong branch
Rescued branch
```

while holding the scene, signal realization, geometry, and imaging chain fixed.

---

## 6. Candidate Image-Level Observables

Only a small set of physically interpretable metrics should be used at first.

Candidate metrics include:

- image entropy;
- image contrast;
- azimuth impulse-response width / IRW;
- PSLR / ISLR when meaningful;
- local scattering-energy concentration;
- weak-scatterer peak retention;
- weak-structure preservation;
- ghost / false-structure energy;
- local azimuth-profile deformation.

Do not expand the metric set unless the first experiment reveals a specific evidence gap.

---

## 7. Preferred Case Types

The most informative cases are:

```text
1. G0 catastrophe
   → Proposed rescue

2. G0 success
   → Proposed unchanged

3. Difficult local-clutter or weak-scatterer case

4. Proposed residual failure case
   if such a case exists
```

The purpose is to create a paired causal interpretation rather than a collection of visually attractive examples.

---

## 8. Data Priority

Preferred data hierarchy:

```text
1. Group / project real complex SAR ship data
2. Public real complex SAR / ship-chip data
3. Paper-consistent or high-fidelity SAR simulation
```

Simulation can be used to establish controlled causal relationships, but it should not be treated as a complete substitute for real SAR validation.

---

## 9. Directory Structure

```text
branch_reliability_sar/
├── README.md
├── code/
├── functions/
├── docs/
└── results/
    ├── raw/
    ├── summary/
    └── figures/
```

Recommended roles:

```text
code/
    experiment scripts

functions/
    reusable SAR imaging / metric / utility functions

docs/
    experiment design, frozen protocols, interpretation notes

results/raw/
    large generated outputs; normally not tracked by Git

results/summary/
    compact tables and paper-ready summaries

results/figures/
    selected compact figures intended for interpretation or paper use
```

---

## 10. Experiment Design Discipline

Each experiment should define before execution:

- Research Question;
- hypothesis / competing explanations;
- control groups;
- fixed variables;
- changed variables;
- output metrics;
- expected result branches;
- falsification conditions;
- result-file policy.

A new experiment should be added only when:

- a current claim has an evidence gap;
- the observed result contradicts the current mechanism;
- an alternative explanation remains unresolved;
- the SAR image-level physical chain requires one additional controlled test.

Do not expand the experiment tree merely to accumulate results.

---

## 11. Current Status

```text
Historical search/signal mechanism study      CHECKPOINTED
EXP009–EXP010 evidence architecture           FROZEN
EXP011 theory validation                      CONVERGING
SAR image-level physical translation          STARTING
```

The next concrete task is to define and run the first minimal SAR branch-error mapping experiment.
