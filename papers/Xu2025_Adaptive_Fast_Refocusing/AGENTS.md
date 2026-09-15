# Project Working Rules

This repository is a research-code project on SAR defocusing/refocusing for complex moving ships. MATLAB is the primary experiment language.

## 1. Research integrity

- Researchers decide the research question, experimental hypotheses, control groups, metrics, and protocol. Do not invent or silently change them.
- Never tune parameters merely to obtain an expected result. A negative result is a valid result.
- Before changing an existing experiment, read its corresponding README, DESIGN document, frozen protocol, and any relevant audit note first.
- Keep the following labels explicit in analysis and documentation:
  - `Confirmed by evidence`
  - `Working hypothesis`
  - `Planned-not-tested`
- If README, code, configuration, and results disagree, report the conflict explicitly. Do not select one version as truth without researcher direction.
- Oracle information may be used for causal attribution, upper-bound analysis, or counterfactual controls, but must not be presented as part of the practical algorithm.
- Do not promote an exploratory observation to a paper-level claim unless the supporting experiment and evidence have been frozen.

## 2. Change discipline

- Before modifying files, check Git status when Git metadata is available.
- Do not commit or push without explicit authorization.
- After modifications, report changed files and the intended effect.
- Do not delete historical experimental results merely for cleanup.
- Do not rename or move historical experiment directories only for naming consistency if MATLAB paths, configurations, or documentation depend on them.
- Do not modify MATLAB code, experimental parameters, or result files unless the request explicitly authorizes it.
- Prefer adding a new experiment or a clearly versioned patch over silently overwriting an established experiment.
- Preserve experiment provenance, including configuration, parameter sources, and decision gates.

## 3. Repository research boundary

The repository contains both paper reproduction and original research.

### 3.1 Paper reproduction / reproduction-derived extensions

Historical experiments under:

```text
papers/
```

may include:

- reproduction of published methods;
- reproduction-derived stress tests;
- exploratory extensions motivated by reproduced methods.

Their exact academic role must be documented in the corresponding README.

### 3.2 Original research under Xu2025 historical path

The directory:

```text
papers/Xu2025_Adaptive_Fast_Refocusing/
```

contains both reproduction-derived work and original research.

Important boundary:

```text
EXP01–EXP03
Core reproduction / numerical verification

EXP04–EXP06
Tracking and reliability-oriented extensions

EXP07–EXP08
Multi-component / weak-component exploration

EXP009 onward
Original research
```

EXP009 and later experiments remain in the Xu2025 directory for historical provenance and dependency stability. Their physical location must not be interpreted as academic origin.

### 3.3 New SAR-stage research

New SAR image-level physical-validation work must be developed under:

```text
research/branch_reliability_sar/
```

Do not continue the old historical sequence as `EXP012`.

The new workspace uses its own local experiment numbering, for example:

```text
exp01_sar_branch_error_mapping/
exp02_sar_branch_rescue/
```

## 4. Current paper-level research focus

The current work is converging toward two main research claims.

### Claim 1 — Failure Mechanism

Current evidence focuses on the chain:

```text
finite-window / off-grid effects
        ↓
strong residual leakage + weak-component damage
        ↓
recoverability limitation
        ↓
coherent residual perturbation
        ↓
search-objective deformation
        ↓
local bias / global branch competition
        ↓
rare catastrophic branch-selection failure
```

### Claim 2 — Reliability-Aware Selective Recovery

Current evidence focuses on:

```text
cheap search
        ↓
internal reliability state
        ↓
staged risk screening
        ↓
selective Neighbor-3 recovery
        ↓
reliability–computation trade-off
```

Neighbor-3 must be treated as conditionally reliable because its practical validity depends on upstream strong-component parameter-estimation accuracy.

## 5. Claim boundaries

Do not overstate the current evidence.

Do not claim that:

- all failures are described by one universal closed-form model;
- Neighbor-3 is unconditionally safe;
- Refined-LR or FiveBin is universally optimal;
- AWGN is equivalent to sea clutter;
- the current batch/fixed-compute scheduler is already a deployment-ready per-sample threshold system;
- branch correctness guarantees full weak-component recovery;
- search-level reliability gain automatically proves SAR image-level structural benefit.

## 6. Experiment-expansion rule

Do not add experiments merely because another experiment can be added.

A new experiment is justified when at least one of the following is true:

- a current claim has a clear evidence gap;
- a result conflicts with the current mechanism;
- an alternative explanation has not been excluded;
- a theory bridge requires direct validation;
- a practical validity boundary must be tested;
- SAR image-level translation requires a minimal physical test.

If none of these apply, prefer paper architecture, theory compression, or documentation over further expansion.

## 7. Documentation to read before extending the Xu2025 research line

Start with:

```text
papers/Xu2025_Adaptive_Fast_Refocusing/README.md
```

Then consult:

```text
papers/Xu2025_Adaptive_Fast_Refocusing/docs/research_evolution/
```

Recommended reading order:

```text
01_XU2025_RESEARCH_EVOLUTION_CN.md
02_EXP009_FULL_CHAIN_REVIEW_v1.1.md
03_EXP009_EXP010_CLAIM_EVIDENCE_MATRIX_v1.0.md
04_NOVELTY_ATTACK_AND_GAP_AUDIT_v1.0.md
theory/05_UNIFIED_THEORY_DRAFT_v0.2.pdf
```

Before modifying a specific experiment, also read that experiment's own README / DESIGN / protocol files.

## 8. New SAR research objective

The next stage should establish the physical translation:

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

The objective is not merely to produce a visually better SAR image.

The objective is to explain what a search-level branch error physically becomes in the SAR imaging chain, and what structures are restored by successful branch rescue.
