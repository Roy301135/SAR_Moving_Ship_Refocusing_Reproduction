# Real-Data Validation Figures

> Curated figure index for the real-SAR validation checkpoint.
>
> These figures are copied from the full local experiment outputs and are
> intended for Git-facing documentation, project review, and later paper /
> presentation preparation.
>
> They are **not** a replacement for the complete local `results/` tree.

---

## 1. Figure Set Overview

```text
01_opensarship_complex_interface.png
02_opensarship_cross_ship_lfm_coherence.png
03_fair_recurrent_component_track.png
04_fair_candidate_b_branch_occurrence.png
05_fair_candidate_b_failure_geometry.png
06_fair_candidate_c_replication.png
07_fair_r2a_branch_contribution.png
08_fair_gap01_real_vs_synthetic.png
```

Together they summarize the evidence chain:

```text
OpenSARShip interface
        ↓
OpenSARShip applicability boundary
        ↓
FAIR recurrent LFM-compatible structure
        ↓
Candidate-B real branch occurrence
        ↓
remote-basin failure geometry
        ↓
Candidate-C independent replication
        ↓
branch contribution to focused representation
        ↓
real-vs-synthetic model-gap diagnosis
```

---

# 2. Figure-by-Figure Index

## 01 — OpenSARShip Complex Interface

**File**

```text
01_opensarship_complex_interface.png
```

**Original source**

```text
results/exp02_real_sar_branch_audit/
opensarship/r0a_interface_gate/
01_complex_chip_sanity.png
```

**Experiment**

```text
OpenSARShip R0A — Complex SLC Interface Gate
```

**Purpose**

Verify that the selected public OpenSARShip sample can be read and handled as
a complex SAR chip with a consistent azimuth/range interpretation.

**Supports**

```text
complex-SLC data interface is usable
```

and establishes the frozen convention:

```text
row    = azimuth
column = range
g(:,n) = one azimuth history
```

**Does not support**

```text
exact MC-LFM validity
branch-failure occurrence
ship-motion truth
```

---

## 02 — OpenSARShip Cross-Ship LFM Coherence

**File**

```text
02_opensarship_cross_ship_lfm_coherence.png
```

**Original source**

```text
results/exp02_real_sar_branch_audit/
opensarship/r0c_cross_ship_interface_gate/
05_cross_ship_lfm_coherence.png
```

**Experiment**

```text
OpenSARShip R0C — Cross-Ship Interface / LFM Compatibility Gate
```

**Purpose**

Check whether the weak single-LFM compatibility observed in the pilot ship is
an isolated case or persists across additional ship targets.

**Supports**

The tested OpenSARShip targets do not provide sufficiently strong,
source-aligned single-LFM evidence for direct validation of the frozen
MC-LFM branch mechanism.

**Does not support**

```text
OpenSARShip is unusable for SAR research
real ships are non-LFM in general
no ship target can satisfy an LFM approximation
```

This figure motivates the dataset transition to FAIR-CSAR.

---

## 03 — FAIR Recurrent Component Track

**File**

```text
03_fair_recurrent_component_track.png
```

**Original source**

```text
results/exp02_real_sar_branch_audit/
fair_csar/r0_component_consistency_gate/
03_dominant_component_track.png
```

**Experiment**

```text
FAIR R0 — Component-Consistency Gate
```

**Purpose**

Show the recurrent LFM-compatible component family identified across
neighboring range columns in Candidate B.

**Supports**

```text
phase-sensitive recurrent LFM-compatible structure exists
```

in the real motion-defocused ship data.

**Does not support**

```text
the whole ship range-column is an exact MC-LFM signal
every detected component is physically independent
the estimated p_beta is physical motion truth
```

---

## 04 — FAIR Candidate-B Branch Occurrence

**File**

```text
04_fair_candidate_b_branch_occurrence.png
```

**Original source**

```text
results/exp02_real_sar_branch_audit/
fair_csar/r1b_full_frozen_pool_occurrence/
02_branch_occurrence_map.png
```

**Experiment**

```text
FAIR R1B — Full Frozen Pool Occurrence
```

**Frozen pool**

```text
62 Wang-selected ship lines
55 lines with valid components
222 accepted component states
```

**Main taxonomy**

```text
SAFE                      203
G0_FAIL_N3_RESCUE           0
N3_COVERAGE_MISS            19
PERSISTENT_WITHIN_COVERAGE   0
```

**Purpose**

Show where real branch failures occur within the frozen Candidate-B
component pool.

**Supports**

```text
real branch failure exists
```

and that the observed Candidate-B failures are not natural frozen-N3 rescue
cases.

**Does not support**

The observed fraction must not be interpreted as a physical population
prevalence for all ship scatterers or all motion-defocused SAR targets.

---

## 05 — FAIR Candidate-B Failure Geometry

**File**

```text
05_fair_candidate_b_failure_geometry.png
```

**Original source**

```text
results/exp02_real_sar_branch_audit/
fair_csar/r1c_failure_geometry_component_validity/
02_failure_search_geometry.png
```

**Experiment**

```text
FAIR R1C — Failure Geometry / Component Validity
```

**Purpose**

Determine whether the R1B failures are local Neighbor-3 misses or remote
objective-basin competitions.

**Key result**

```text
19 non-SAFE states
11 / 19 recurrent credible
0 / 19 global basin inside frozen N3 coverage
```

**Supports**

The real failure geometry is better described as:

```text
remote, near-equal basin competition
```

rather than:

```text
local k0-1 / k0 / k0+1 branch competition
```

**Does not support**

This figure does not identify the physical cause of the remote competing
basins.

---

## 06 — FAIR Candidate-C Independent Replication

**File**

```text
06_fair_candidate_c_replication.png
```

**Original source**

```text
results/exp02_real_sar_branch_audit/
fair_csar/r1d_candidate_c_independent_replication/
04_candidate_c_failure_geometry.png
```

**Experiment**

```text
FAIR R1D — Candidate-C Independent Frozen Replication
```

**Result**

```text
69 accepted states

SAFE               67
N3_COVERAGE_MISS    2
G0_FAIL_N3_RESCUE   0
```

**Purpose**

Test whether the Candidate-B branch-failure behavior transfers under the same
frozen pipeline to an independent motion-defocused ship.

**Supports**

```text
remote branch failure can occur on an independent real target
```

**Also shows**

Candidate B's recurrent failure population does not strongly replicate in
Candidate C.

**Does not support**

```text
remote failure is universally rare
Candidate B is abnormal
Candidate C is fully model-matched
```

---

## 07 — FAIR R2A Branch Contribution

**File**

```text
07_fair_r2a_branch_contribution.png
```

**Original source**

```text
results/exp02_real_sar_branch_audit/
fair_csar/r2a_branch_contribution_candidate_b/
03_g0_vs_global_difference.png
```

**Experiment**

```text
FAIR R2A — Branch Contribution to Image Defocus
```

**Comparison**

```text
Frozen G0 branch
vs
evaluation-only Global branch
```

while holding fixed:

```text
component set
p_beta
component order
reconstruction operator
finite extraction width
```

**Purpose**

Test whether replacing only the branch coordinate changes the focused
representation at the R1 failure locations.

**Supports**

Branch-substitution changes are strongly localized to the identified failure
range columns.

Therefore:

```text
R1 branch taxonomy
```

and

```text
R2A reconstruction response
```

are spatially consistent.

**Does not support**

The evaluation-only Global branch is not physical motion truth, and this
figure does not establish the total recoverable physical SAR-image defocus.

---

## 08 — FAIR GAP01 Real-vs-Synthetic Landscape

**File**

```text
08_fair_gap01_real_vs_synthetic.png
```

**Original source**

```text
results/exp02_real_sar_branch_audit/
fair_csar/gap01_real_vs_synthetic/
03_joint_landscape_representatives.png
```

**Experiment**

```text
FAIR GAP01 — Real-vs-Synthetic Gap Audit
```

**Purpose**

Compare the joint:

```text
J(p_beta, nu)
```

geometry of representative real states with exact quadratic-LFM clones using
the same real-state parameter support.

**Observation**

Exact clones show:

```text
clean
structured
localized
```

objective geometry.

Real states show:

```text
multiple ridges
remote competing basins
broad / speckled objective structure
```

**Supports**

The main synthetic-to-real discrepancy is not explained by the branch code
failing over the observed real `(p_beta,nu)` support.

It points instead toward a broader:

```text
signal / model / mixture gap
```

**Does not support**

This figure alone cannot distinguish uniquely among:

```text
higher-order phase
multi-component coupling
range-cell mixing
spatial variation
clutter / sidelobe contamination
larger upstream FM-rate mismatch
```

---

# 3. Current Evidence Boundary

The curated figure set supports the following bounded chain:

```text
1. Public complex-SLC handling is valid.

2. OpenSARShip does not provide sufficiently strong source-aligned evidence
   for direct MC-LFM branch validation in the tested targets.

3. FAIR Candidate B contains recurrent phase-sensitive LFM-compatible
   structure.

4. Real branch failures occur.

5. The observed Candidate-B failures are predominantly remote-basin events
   outside frozen Neighbor-3 coverage.

6. Candidate C weakly replicates remote branch failure but not Candidate-B's
   recurrent failure population.

7. Branch substitution changes the expected failure locations, but the global
   focusing headroom is small / mixed.

8. Exact quadratic-LFM clones over the same observed parameter support remain
   well behaved, whereas real states exhibit much more complex objective
   geometry.
```

The figure set therefore supports a transition from:

```text
branch-recovery expansion
```

toward:

```text
literature-gated diagnosis of the remaining real-data model gap
```

without claiming that any single non-branch mechanism has already been
identified.
