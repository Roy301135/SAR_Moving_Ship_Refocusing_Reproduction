# Xu 2025 Adaptive Fast Refocusing — Reproduction, Extensions, and Original Research

> **Directory role:** This folder records the research line that started from reproducing Xu et al. (2025) and gradually evolved into an independent study of sequential MC-LFM refocusing reliability.
>
> **重要边界：EXP009 及之后的实验属于原创研究，不应被描述为 Xu 2025 原论文复现。**
>
> Historical code remains in this directory to preserve MATLAB path stability, experiment dependencies, and research provenance.

---

## 1. Scope of This Directory

This directory originally served to reproduce and understand the main processing ideas in:

**Xu et al. (2025)**  
*Adaptive Fast Refocusing for Ship Targets With Complex Motion in SAR Images*  
IEEE Journal of Selected Topics in Applied Earth Observations and Remote Sensing (JSTARS).

The initial focus included:

- complex-motion ship refocusing;
- residual LFM / MC-LFM modeling;
- FrFT / FrAc based parameter estimation;
- optimal rotation order (ORO) estimation;
- reduced search intervals;
- adjacent-azimuth-line prior sharing;
- computational efficiency of local search.

During the reproduction process, several failure modes and unresolved questions emerged. These gradually changed the research problem from:

```text
How can local FrFT / FrAc search be made faster?
```

into:

```text
When does the cheap search become unreliable,
how can that unreliability be detected internally,
and when should extra computation be allocated?
```

Therefore, this folder now contains three types of work:

1. **core reproduction / numerical verification**;
2. **reproduction-derived stress tests and exploratory extensions**;
3. **original research developed from the observed failure mechanisms**.

---

## 2. Research Evolution

The experiment line should be interpreted as:

```text
EXP01–EXP03
Core reproduction / numerical verification
        ↓
EXP04–EXP06
Adjacent-line tracking stress tests
and reliability-oriented extensions
        ↓
EXP07–EXP08
Multi-component / weak-component exploration
        ↓
══════════════════════════════════════════════
EXP009: ORIGINAL RESEARCH BEGINS
══════════════════════════════════════════════
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

### EXP01–EXP03 — Core Reproduction

Main purposes:

- verify the LFM → FrFT / FrAc concentration chain;
- reproduce ORO estimation;
- compare full search with reduced ORO intervals;
- establish a trustworthy MATLAB numerical baseline.

These experiments are primarily reproduction / verification.

---

### EXP04–EXP06 — Tracking Reliability Extensions

This stage starts from adjacent-line prior sharing.

Main observations:

- a small local search window can significantly reduce computation when the ORO field varies smoothly;
- abrupt ORO changes can push the true optimum outside the current local window;
- boundary hits can accompany tracking lag and error propagation;
- boundary information can therefore serve as an internal warning of search unreliability;
- adaptive window expansion / fallback provides an early proof of concept for selective computation.

This stage is best understood as:

> **reproduction-derived extension + mechanism exploration**

rather than direct reproduction.

---

### EXP07–EXP08 — Multi-Component and Weak-Component Exploration

The focus moves from dominant-component tracking toward component completeness.

Important observations include:

```text
good global focus
≠
complete weak-component recovery
```

and:

```text
one FrAc spectrum
→ multiple reliable component peaks
```

is not robust under difficult multi-component conditions.

These experiments directly motivate the later question:

> **Where does weak-component failure first enter the sequential refocusing chain?**

---

## 3. EXP009 — Original Research: Failure Mechanism and Reliability

EXP009 is the academic boundary between reproduction-derived exploration and original research.

The main research question evolves into:

> **Where does weak-component failure enter the sequential MC-LFM refocusing chain, and can the search process itself reveal when a branch decision is unreliable?**

The current failure-mechanism chain is summarized as:

```text
finite aperture / finite window
        ↓
off-grid miscentering
        ↓
strong residual leakage
+
weak-component damage
        ↓
recoverability limitation
        ↓
coherent residual perturbation
        ↓
search-objective deformation
        ↓
local continuous bias
        ↓
global branch competition
        ↓
rare catastrophic branch-selection failure
```

### 3.1 Strong Leakage and Weak Damage

Under the current orthogonal finite-window removal model, the weak-component recovery error is decomposed as

\[
E^2
=
\left(\frac{L_s}{r_A}\right)^2
+
D_w^2,
\]

where:

- \(L_s\): strong-component leakage ratio;
- \(D_w\): weak-component damage ratio;
- \(r_A\): weak-to-strong norm / amplitude ratio.

This relation explains why even moderate strong residual leakage can dominate when the desired weak component becomes sufficiently weak.

The result is **operator-level and assumption-bounded**. It should not be interpreted as a universal SAR detection limit.

---

### 3.2 Off-Grid Recoverability Limitation

Finite-window removal around an integer coarse seed can become miscentered when the true transform-domain center is off-grid.

This creates:

```text
strong leakage ↓ when window widens
but
weak damage ↑ when window widens
```

which forms a structural leakage–damage trade-off.

Oracle sub-bin recentering is used only as a causal control to test whether off-grid miscentering is a key bottleneck.

---

### 3.3 Coherent Residual Perturbation

Strong residual energy does not only raise a noise floor.

If the downstream search response is written as

\[
C(q)=C_w(q)+C_e(q),
\]

then

\[
|C(q)|^2
=
|C_w(q)|^2
+
|C_e(q)|^2
+
2\operatorname{Re}\{C_w(q)C_e^\ast(q)\}.
\]

The coherent cross term can reshape the weak-component search objective and alter peak geometry / branch ranking.

---

### 3.4 Local Bias vs. Global Branch Switching

Two failure modes must remain distinct:

```text
local continuous estimation bias
```

and

```text
global branch switching
```

A catastrophic branch error is not simply a larger local bias.  
The continuous local optimum and the discrete coarse winner are different mathematical objects.

This distinction is central to the current Claim 1.

---

## 4. Reliability-Aware Selective Recovery

Once rare catastrophic branch errors were identified, the next question became:

> **Can the cheap search detect when it is likely to fail, so that expensive recovery is invoked only when necessary?**

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

The purpose is not to make Neighbor-3 itself cheaper.

The purpose is to avoid running Neighbor-3 on every sample.

---

## 5. EXP010 — Practical Non-Oracle Closure

EXP010 tests whether the reliability-aware strategy survives when oracle information is removed.

Main purposes:

- use practical strong-component parameter estimation;
- apply a frozen staged policy;
- compare against G0 / cheap search and Always-N3;
- audit computational cost;
- test additive-noise robustness;
- identify the ownership of residual Neighbor-3 failures.

The current practical conclusion is:

> **Neighbor-3 is conditionally reliable, not unconditionally safe.**

Residual failures are strongly associated with upstream strong-component parameter-estimation error.

Therefore, Neighbor-3 should be interpreted as:

```text
local branch redundancy
subject to upstream parameter accuracy
```

rather than a universal rescue operator.

---

## 6. EXP011 — Theory Validation / Falsification

EXP011 is **not** a third independent method contribution.

Its role is to test, refine, or falsify the minimum theoretical bridges required by the existing claims.

The current theory focus is:

### Bridge 1

```text
coherent residual
        ↓
objective perturbation
        ↓
branch-margin erosion
        ↓
winner switching
```

A minimal branch-switching condition can be expressed through the correct-branch margin

\[
M_0
=
J_c^{(0)}-J_b^{(0)},
\]

with switching possible when

\[
\Delta J_b-\Delta J_c > M_0.
\]

### Bridge 2

```text
upstream parameter error
        ↓
search-coordinate displacement
        ↓
candidate / basin coverage erosion
        ↓
conditional Neighbor-3 failure
```

A local first-order mapping may be written as

\[
\delta_\nu
\approx
\frac{\partial \nu}{\partial \beta}\delta_\beta.
\]

If the effective Neighbor-3 coverage radius is \(R_{\rm cov}\) and the intrinsic offset is \(\rho\), a sufficient interpretation is of the form

\[
|\delta_\nu| < R_{\rm cov}-\rho.
\]

The goal is to provide a compact validity condition, not to build an unnecessarily broad probability theory.

---

## 7. Current Paper-Level Claims

The current work should converge to **two core contributions**.

### Claim 1 — Failure Mechanism

Finite-window / off-grid sequential removal creates strong-component leakage and weak-component damage. The resulting coherent residual perturbs the downstream search objective, and under difficult regimes this can lead from local estimation distortion to global branch competition and rare catastrophic branch-selection errors.

### Claim 2 — Reliability-Aware Selective Recovery

Cheap internal search states can be used to identify high-risk cases and selectively allocate Neighbor-3 recovery. This yields a reliability–computation trade-off between cheap G0 search and Always-N3, subject to an upstream parameter-accuracy validity boundary.

---

## 8. Claim Boundaries

The current evidence does **not** support the following stronger statements:

- all sequential-refocusing failures are described by one universal closed-form model;
- Neighbor-3 is unconditionally safe;
- Refined-LR or FiveBin is universally optimal;
- AWGN is equivalent to real sea clutter;
- the current batch / fixed-compute scheduler is already a deployment-ready per-sample threshold system;
- branch correctness is sufficient for full weak-component recovery;
- search-level reliability gain automatically proves SAR image-level structural gain.

These boundaries should remain explicit in future analysis and paper writing.

---

## 9. Directory Structure

```text
Xu2025_Adaptive_Fast_Refocusing/
├── README.md
├── AGENTS.md
│
├── code/
│   ├── exp01_...
│   ├── exp02_...
│   ├── ...
│   ├── exp09_pilot01/
│   ├── exp09_physical_validation/
│   ├── exp10_practical_nonoracle_closure/
│   ├── exp011_theory_validation/
│   └── functions/
│
├── results/
│   ├── exp01_...
│   ├── ...
│   ├── exp09_physical_validation/
│   ├── exp10_practical_nonoracle_closure/
│   └── exp011_theory_validation/
│
└── docs/
    └── research_evolution/
        ├── 01_XU2025_RESEARCH_EVOLUTION_CN.md
        ├── 02_EXP009_FULL_CHAIN_REVIEW_v1.1.md
        ├── 03_EXP009_EXP010_CLAIM_EVIDENCE_MATRIX_v1.0.md
        ├── 04_NOVELTY_ATTACK_AND_GAP_AUDIT_v1.0.md
        └── theory/
            └── 05_UNIFIED_THEORY_DRAFT_v0.2.pdf
```

Historical experiment folder names are intentionally preserved to avoid breaking:

- MATLAB relative paths;
- function dependencies;
- result paths;
- configuration references;
- experiment documentation;
- parameter provenance.

---

## 10. Research-Evolution Documentation

The detailed research history is stored under:

```text
docs/research_evolution/
```

Recommended reading order:

```text
01_XU2025_RESEARCH_EVOLUTION_CN.md
        ↓
02_EXP009_FULL_CHAIN_REVIEW_v1.1.md
        ↓
03_EXP009_EXP010_CLAIM_EVIDENCE_MATRIX_v1.0.md
        ↓
04_NOVELTY_ATTACK_AND_GAP_AUDIT_v1.0.md
        ↓
theory/05_UNIFIED_THEORY_DRAFT_v0.2.pdf
```

Their roles are:

| Document | Role |
|---|---|
| `01_XU2025_RESEARCH_EVOLUTION_CN.md` | High-level Chinese research map and repository organization |
| `02_EXP009_FULL_CHAIN_REVIEW_v1.1.md` | Full experiment-history provenance and research evolution |
| `03_EXP009_EXP010_CLAIM_EVIDENCE_MATRIX_v1.0.md` | Frozen Claim–Evidence–Figure–Limitation architecture |
| `04_NOVELTY_ATTACK_AND_GAP_AUDIT_v1.0.md` | Reviewer-style novelty attack and remaining-gap audit |
| `05_UNIFIED_THEORY_DRAFT_v0.2.pdf` | Theory mother draft for later paper compression |

These documents should remain separate because they serve different research-management purposes.

---

## 11. Large-File and Git Policy

This directory should primarily track:

- MATLAB source code;
- experiment configurations;
- experiment-design documents;
- frozen protocols;
- parameter provenance;
- compact textual summaries;
- theory notes;
- audit notes;
- README files.

Large generated artifacts are normally kept locally, including:

```text
*.mat
large trial CSV files
raw Monte Carlo outputs
generated intermediate figures
```

The purpose of Git is to preserve:

> **reproducible research history**

rather than:

> **raw experiment-data backup**.

---

## 12. Transition to New SAR Image-Level Research

The EXP009–EXP011 line is approaching a natural checkpoint.

New SAR image-level physical-validation work should **not** continue as `EXP012` in this folder.

It should proceed under:

```text
research/branch_reliability_sar/
```

with a new local numbering sequence such as:

```text
exp01_sar_branch_error_mapping/
exp02_sar_branch_rescue/
...
```

The main next-stage question is:

> **What does a search-level branch error physically become in the SAR imaging chain, and what scattering structures are restored when that branch is successfully rescued?**

The intended translation is:

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

This new stage is intended to provide the missing SAR image-level physical closure of the existing search/signal-level claims, not to create a new parallel algorithmic contribution.

---

## 13. Current Status

```text
EXP01–EXP03    Core reproduction                       DONE
EXP04–EXP06    Tracking / reliability extensions       DONE
EXP07–EXP08    Multi-component exploration             DONE
EXP009         Failure-mechanism research              DONE / EVIDENCE FROZEN
EXP010         Practical non-oracle closure            DONE / EVIDENCE FROZEN
EXP011         Theory validation                       ACTIVE / CONVERGING
Next           SAR image-level physical translation    → research/branch_reliability_sar/
```
