# SAR Moving Ship Refocusing Research Repository

> **Research repository for complex-motion ship SAR defocusing/refocusing, sequential MC-LFM processing, branch-reliability analysis, and SAR image-level physical validation.**
>
> 本仓库记录复杂运动舰船 SAR 非聚焦 / 重聚焦方向的论文复现、机制探索、原创方法研究以及后续 SAR 图像级物理验证过程。

---

## 1. Repository Overview

This repository was initially created to reproduce and understand representative methods for refocusing complex-motion ship targets in SAR imagery.

During the reproduction process, several limitations and failure modes gradually exposed a broader research problem:

```text
paper reproduction
        ↓
fast local ORO search
        ↓
tracking reliability
        ↓
weak-component recovery
        ↓
sequential-removal failure mechanism
        ↓
global branch competition
        ↓
rare catastrophic branch-selection failure
        ↓
internal reliability state
        ↓
selective branch recovery
        ↓
practical non-oracle validation
        ↓
SAR image-level physical interpretation
```

Therefore, this repository now contains both:

1. **paper reproduction / reproduction-derived extensions**, and
2. **original research developed from the limitations revealed during reproduction**.

These two categories are explicitly distinguished in the documentation.

---

## 2. Main Research Topics

The current repository covers the following topics:

- complex-motion ship SAR defocusing and refocusing;
- residual LFM / MC-LFM modeling;
- FrFT / FrAc based parameter estimation;
- optimal rotation order (ORO) estimation;
- local-search acceleration and adjacent-line prior sharing;
- weak-component recovery in sequential processing;
- finite-window and off-grid removal effects;
- strong-component leakage and weak-component damage;
- coherent residual perturbation;
- local estimation bias versus global branch switching;
- catastrophic branch-selection failure;
- reliability-aware selective Neighbor-3 recovery;
- practical non-oracle processing;
- noise robustness and validity boundaries;
- SAR image-level translation of search-level branch errors.

MATLAB is the primary experiment language.

---

## 3. Repository Structure

The repository is organized approximately as follows:

```text
SAR_Moving_Ship_Refocusing_Reproduction/
│
├── README.md
├── .gitignore
│
├── data/
│   ├── real_sar/
│   └── simulated/
│
├── docs/
│   ├── experiment_notes/
│   └── reading_notes/
│
├── papers/
│   │
│   ├── Wang2023_.../
│   │   ├── code/
│   │   ├── functions/
│   │   └── results/
│   │
│   └── Xu2025_Adaptive_Fast_Refocusing/
│       ├── README.md
│       ├── AGENTS.md
│       ├── code/
│       ├── results/
│       └── docs/
│           └── research_evolution/
│
└── research/
    └── branch_reliability_sar/
        ├── README.md
        ├── code/
        ├── functions/
        ├── docs/
        └── results/
            ├── raw/
            ├── summary/
            └── figures/
```

Historical experiment folder names are intentionally preserved whenever possible because MATLAB paths, experiment dependencies, and documentation may rely on them.

---

## 4. Paper Reproduction Lines

### 4.1 Wang 2023 Series

The Wang-related experiments establish the earlier numerical and physical basis for:

- residual LFM behavior;
- FrFT / FrAc concentration;
- optimal fractional-order estimation;
- ship-motion induced defocusing;
- fast versus fine parameter search;
- computational cost versus estimation accuracy.

These experiments provide important background for the later Xu 2025 and sequential-refocusing studies.

---

### 4.2 Xu 2025 Adaptive Fast Refocusing

The directory

```text
papers/Xu2025_Adaptive_Fast_Refocusing/
```

started from the reproduction and analysis of:

> *Adaptive Fast Refocusing for Ship Targets With Complex Motion in SAR Images*

Its research evolution can be summarized as:

```text
EXP01–EXP03
Core reproduction / numerical verification
        ↓
EXP04–EXP06
Tracking stress tests and reliability-oriented extensions
        ↓
EXP07–EXP08
Multi-component / weak-component exploration
        ↓
════════════════════════════════════
EXP009: ORIGINAL RESEARCH BEGINS
════════════════════════════════════
        ↓
EXP009
Failure mechanism + reliability discovery
        ↓
EXP010
Practical non-oracle closure + robustness
        ↓
EXP011
Theory validation / falsification
```

For the detailed experiment map and reproduction/original-research boundary, see:

```text
papers/Xu2025_Adaptive_Fast_Refocusing/README.md
```

---

## 5. Reproduction vs. Original Research Boundary

A central repository rule is:

> **Physical directory location does not imply academic origin.**

EXP009 and later experiments remain physically under:

```text
papers/Xu2025_Adaptive_Fast_Refocusing/
```

because they evolved directly from the Xu 2025 reproduction chain and already contain established:

- MATLAB relative paths;
- function dependencies;
- result paths;
- configuration references;
- parameter-provenance records;
- experiment documentation.

Moving them only for directory aesthetics would introduce unnecessary engineering risk.

However, academically:

```text
EXP009 onward
=
original research
```

These experiments must not be described as reproductions of Xu et al. (2025).

Historical code is therefore preserved in place, while new SAR-stage research is developed in a separate `research/` workspace.

---

## 6. Current Paper-Level Research Claims

The current research is intentionally converging toward **two core contributions** rather than accumulating many parallel innovations.

### Claim 1 — Failure Mechanism

The current evidence supports the following bounded mechanism:

```text
finite aperture / finite window
        ↓
off-grid miscentering
        ↓
strong residual leakage
+
weak-component damage
        ↓
weak-component recoverability floor
        ↓
coherent residual perturbation
        ↓
search-objective deformation
        ↓
local estimation bias
        ↓
global branch competition
        ↓
rare catastrophic branch-selection error
```

Under the current orthogonal finite-window removal model, the normalized weak-component recovery error can be written as

\[
E^2
=
\left(\frac{L_s}{r_A}\right)^2
+
D_w^2,
\]

where:

- \(L_s\) denotes strong-component leakage;
- \(D_w\) denotes weak-component damage;
- \(r_A\) denotes the weak-to-strong norm/amplitude ratio.

This result explains why relatively small strong residual leakage can become dominant when the desired component is weak.

The mechanism is intentionally restricted to the tested operator, geometry, and modeling assumptions. It is not claimed as a universal closed-form SAR failure law.

---

### Claim 2 — Reliability-Aware Selective Recovery

The cheap branch-search process contains internal reliability information that can be used to identify high-risk cases.

The current staged interpretation is:

```text
cheap search
        ↓
internal reliability state
        ↓
Stage 1: Refined-LR
        ↓
residual pool
        ↓
Stage 2: FiveBin
        ↓
selective Neighbor-3 recovery
```

The purpose is to allocate additional branch recovery only to samples that are likely to need it.

This provides a reliability–computation trade-off between:

```text
G0 / cheap search
```

and:

```text
Always-N3
```

rather than executing the expensive recovery for every sample.

Neighbor-3 is treated as **conditionally reliable**, because its practical validity depends on upstream strong-component parameter-estimation accuracy.

---

## 7. Claim Boundaries

The current work does **not** claim that:

- all sequential-refocusing failures can be explained by one universal closed-form model;
- Neighbor-3 is unconditionally safe;
- Refined-LR or FiveBin is a universally optimal reliability indicator;
- additive white Gaussian noise is equivalent to real sea clutter;
- the current batch / fixed-compute scheduler is already a deployment-ready per-sample threshold system;
- branch correctness automatically guarantees full weak-component recovery;
- search-level reliability improvement automatically proves SAR image-level structural improvement.

These boundaries should remain explicit in future analysis, documentation, and paper writing.

---

## 8. Research-Evolution Documentation

The detailed research history is stored under:

```text
papers/Xu2025_Adaptive_Fast_Refocusing/docs/research_evolution/
```

Recommended reading order:

```text
01_XU2025_RESEARCH_EVOLUTION_CN.md

02_EXP009_FULL_CHAIN_REVIEW_v1.1.md

03_EXP009_EXP010_CLAIM_EVIDENCE_MATRIX_v1.0.md

04_NOVELTY_ATTACK_AND_GAP_AUDIT_v1.0.md

theory/
└── 05_UNIFIED_THEORY_DRAFT_v0.2.pdf
```

Their roles are:

| Document | Purpose |
|---|---|
| `01_XU2025_RESEARCH_EVOLUTION_CN.md` | High-level Chinese research map and repository organization |
| `02_EXP009_FULL_CHAIN_REVIEW_v1.1.md` | Complete research lineage and experiment-history provenance |
| `03_EXP009_EXP010_CLAIM_EVIDENCE_MATRIX_v1.0.md` | Frozen Claim–Evidence–Figure–Limitation matrix |
| `04_NOVELTY_ATTACK_AND_GAP_AUDIT_v1.0.md` | Reviewer-style novelty attack, claim boundaries, and remaining gaps |
| `05_UNIFIED_THEORY_DRAFT_v0.2.pdf` | Unified theory mother draft for later paper compression |

These documents intentionally serve different purposes and should not be merged into one oversized summary.

---

## 9. New SAR Image-Level Research Workspace

New work after the EXP009–EXP011 checkpoint is developed under:

```text
research/branch_reliability_sar/
```

The new workspace does **not** continue the historical numbering as `EXP012`.

Instead, it starts a new local experiment sequence, for example:

```text
exp01_sar_branch_error_mapping/
exp02_sar_branch_rescue/
...
```

The main question is:

> **What does a search-level branch error physically become in the SAR imaging chain, and what scattering structures are restored when that branch is successfully rescued?**

The intended physical translation is:

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
weak-scatterer loss
 / ghost
 / sidelobe structure
        ↓
branch rescue
        ↓
image-level structure recovery
```

The goal is not merely to show that one SAR image looks visually better.

The goal is to connect:

```text
search-level mechanism
```

to:

```text
SAR image-level physical consequence
```

using controlled experiments.

---

## 10. Experiment Management Principles

The repository follows several research-management principles.

### 10.1 Mechanism before expansion

A new experiment should be added only when:

- a current claim has an unresolved evidence gap;
- a result conflicts with the current mechanism;
- an alternative explanation remains unexcluded;
- a theory bridge requires direct validation;
- SAR image-level translation requires a minimal physical test.

Experiments should not be added merely to increase experiment count.

### 10.2 Negative results are valid

Parameters must not be tuned merely to obtain the expected result.

A negative or contradictory result should be treated as evidence requiring interpretation.

### 10.3 Separate discovery from evidence freeze

Exploratory observations can generate hypotheses, but they do not automatically become paper-level claims.

### 10.4 Oracle controls are diagnostic only

Oracle information may be used to identify causal ownership or upper bounds.

It must not be presented as part of the practical algorithm.

### 10.5 Preserve research provenance

Historical experiment folders, code, and documentation should not be renamed or moved solely for cosmetic consistency.

---

## 11. Git and Large-File Policy

Git is used to preserve the reproducible research history.

The repository should primarily track:

- MATLAB source code;
- configuration files;
- experiment-design documents;
- frozen protocols;
- parameter provenance;
- compact result summaries;
- theory notes;
- audit documents;
- README files.

Large generated artifacts are generally kept locally, including:

```text
*.mat
large trial CSV files
raw Monte Carlo outputs
generated intermediate figures
```

The repository is therefore intended as:

> **a reproducible research record**

rather than:

> **a raw experiment-data backup**.

---

## 12. Current Status

```text
Wang-paper reproduction                         DONE
Xu 2025 core reproduction                       DONE
Tracking / local-search extensions              DONE
Multi-component / weak-recovery exploration     DONE
EXP009 failure-mechanism research               DONE / EVIDENCE FROZEN
EXP010 practical non-oracle closure             DONE / EVIDENCE FROZEN
EXP011 theory validation                        ACTIVE / CONVERGING
SAR image-level physical translation            NEXT
```

The next development stage should proceed under:

```text
research/branch_reliability_sar/
```
