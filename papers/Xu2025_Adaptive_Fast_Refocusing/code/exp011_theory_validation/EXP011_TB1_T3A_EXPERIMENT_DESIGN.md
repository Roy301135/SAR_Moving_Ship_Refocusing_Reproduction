# EXP011 — Theory Validation Series

## EXP011-A / TB1-T3A: Retrospective Objective-Geometry Audit

### 1. Series role

`EXP011` is reserved for **theory validation only**.

It is intentionally separated from `EXP010`, which closed the practical non-oracle and noise-robustness evidence chain.

Recommended placement:

```text
E:\SAR_Moving_Ship_Refocusing_Reproduction\
papers\Xu2025_Adaptive_Fast_Refocusing\
├─ code\
│  └─ exp011_theory_validation\
│     ├─ config_exp011_tb1_t3a_geometry_audit.m
│     └─ exp011_tb1_t3a_geometry_audit.m
└─ results\
   └─ exp011_theory_validation\
      └─ exp011a_tb1_t3a_geometry_audit\
         ├─ smoke\
         └─ formal\
```

### 2. Scientific rule

> **Theory is frozen before looking at the EXP011 output. EXP011 may falsify, delimit, or support the theory, but it may not fit the theory.**

Hard prohibition:

```text
THIS AUDIT DOES NOT FIT THEORY TO DATA.
NO THEORY PARAMETER MAY BE ESTIMATED FROM FAILURE LABELS.
```

No new physics sweep is introduced. No new contrast, phase, eta, aperture, SNR, Monte-Carlo trial, recovery operator, or reliability feature is added.

The experiment only replays frozen PA5I-R1 physical risk states and reconstructs objective geometry that was not saved upstream.

### 3. TB1 model audited

After true strong-chirp dechirping,

\[
z[m]=z_0[m]+r z_p[m].
\]

For continuous frequency coordinate \(\nu\),

\[
J(\nu;r)
=
J_0(\nu)+rJ_1(\nu)+r^2J_2(\nu),
\]

where

\[
J_1(\nu)
=
2\Re\{C_0(\nu)C_p^*(\nu)\},
\qquad
J_2(\nu)=|C_p(\nu)|^2.
\]

For correct branch \(c\) and a fixed competitor \(b\),

\[
M_{cb}=V_c-V_b.
\]

With branch-accessible coarse values

\[
C_j=V_j-L_j,
\]

the effective coarse margin is

\[
\boxed{
\widetilde M_{cb}
=
C_c-C_b
=
M_{cb}-(L_c-L_b)
}.
\]

The audit distinguishes continuous branch switching, discrete/coarse branch inversion, and operational catastrophic error. These are not treated as synonyms.

### 4. Primary non-fitted questions

#### H1 — Sign consistency

In regular, non-tie, resolved-branch cases, \(\widetilde M_{cb}\) should have the same sign as the replayed coarse branch advantage against the same competitor. This is a logic audit, not a fitted probability model.

#### H2 — Discrete-first regime existence

Does the frozen PA5I-R1 background contain cases satisfying

\[
M_{cb}>0,
\qquad
\widetilde M_{cb}<0?
\]

Such cases support the mechanism that the continuous objective still favors the physical/correct branch while discrete coarse sampling has already inverted branch ranking.

If no such cases are found, the theory is **not automatically rejected**. The frozen PA5I-R1 background may simply be dominated by continuous global branch competition.

#### H3 — Mismatch ownership

Any mismatch is assigned before interpretation:

- `TYPE_I_POTENTIAL_FALSIFICATION`
- `TYPE_III_COARSE_TIE_NONSMOOTH`
- `TYPE_III_TOPOLOGY_OR_BRANCH_DEFINITION`
- `TYPE_III_BRANCH_ASSIGNMENT_UNRESOLVED`
- `TYPE_III_MARGIN_NEAR_ZERO`
- `CONSISTENT_WITH_TB1`

No mismatch may trigger coefficient fitting.

### 5. Four-regime taxonomy

| Regime | Continuous branch | Coarse branch | Interpretation |
|---|---|---|---|
| R0 | correct | correct | stable |
| R1 | correct | wrong | discrete-first failure |
| R2 | switched | wrong | continuous switch + coarse failure |
| R3 | switched | baseline coarse branch | continuous switch occurs before coarse follows |

R1 is especially informative, but R2 dominance is scientifically acceptable.

### 6. Why true-beta / true-chirp control is mandatory

TB1 is a deterministic search-geometry theory. Practical strong-beta mismatch was already isolated later in the chain and belongs to Theory Bridge 2.

Therefore EXP011-A freezes:

```text
true strong chirp dechirp
noise off
no practical beta estimation
```

### 7. Frozen inherited semantics

- local refinement halfwidth = `0.75 bin`
- local bracket samples = `33`
- Neighbor-3 seeds = `{k0-1,k0,k0+1}`
- global reference domain = `[-1.5,+1.5] bin`
- global grid = `1e-3 bin`
- branch-match tolerance = `0.02 bin`
- catastrophic threshold = `0.10 bin`
- DenseRisk eta = `0:0.01:0.5`

### 8. Outputs

```text
exp011a_tb1_t3a_trials.csv
exp011a_tb1_t3a_regime_summary.csv
exp011a_tb1_t3a_mismatch_taxonomy.csv
exp011a_tb1_t3a_verdict.csv
exp011a_tb1_t3a_selftest.csv
EXP011_TB1_T3A_FEEDBACK_BUNDLE.txt
exp011a_tb1_t3a_results.mat
figures/
```

### 9. Stop rule after EXP011-A

Do not immediately add new sweeps. First interpret whether PA5I-R1 is discrete-first supported, continuous-switch dominated, mixed, or genuinely inconsistent with the frozen TB1 assumptions.

Only after this interpretation should EXP011-B be opened. The intended EXP011-B is a theory-controlled continuation audit in perturbation strength \(r\) for selected **pre-existing frozen states**, used to test piecewise coarse-margin evolution and critical-boundary ordering without fitting.
