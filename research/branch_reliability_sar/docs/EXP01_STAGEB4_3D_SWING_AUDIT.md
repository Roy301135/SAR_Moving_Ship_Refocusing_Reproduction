# EXP01 Stage-B4 — 3-D Rigid-Body Natural Branch Audit

## Research Question

Does a **single pre-registered, literature-anchored full 3-D ship swing** naturally map the SAR scene into the discrete-first branch-vulnerable region targeted by the frozen Neighbor-3 recovery operator?

## Served Evidence Gap

Stage-A/B established:

- motion -> physically generated SAR defocus;
- SAR complex history -> sampled MC-LFM representation.

Stage-B2 showed that a selected signal-space DenseRisk state could not be faithfully inverse-mapped into the yaw-only physical family.

Stage-B3 showed that all naturally selected lines in the accepted yaw-only canonical scene were easy with respect to the frozen branch taxonomy.

Stage-B4 therefore changes **only the physical motion family** from yaw-only to full rigid-body roll+pitch+yaw, using literature-anchored parameters. It does not search for a favorable motion state.

## Frozen Physical Motion

Wang 2023 simulation anchor:

| Axis | Double amplitude | Sinusoid amplitude used | Period |
| --- | ---: | ---: | ---: |
| Roll | 17.2 deg | 8.6 deg | 12.2 s |
| Pitch | 3.4 deg | 1.7 deg | 6.7 s |
| Yaw | 38 deg | 19 deg | 14.2 s |

Initial phase is fixed to `pi/2` for all axes, following the single initial-phase statement in the cited simulation setup.

The rotation matrix is the Xu 2025 Eq. (14) matrix, implemented exactly and self-audited for orthogonality and determinant +1.

## Frozen Signal/Branch Semantics

No change from Stage-B3:

- target lines: moving-BP line energy > mean line energy;
- dominant physical scatterer provides the strong reference;
- E / B / D / G / U mechanism taxonomy;
- branch match tolerance = 0.02 bin;
- catastrophic threshold = 0.10 bin;
- G0 and Neighbor-3 unchanged;
- Proposed not run.

## Falsifier / Stop Rule

1. Any unresolved U lines -> audit implementation/classification before scientific interpretation.
2. Natural D line + Neighbor-3 rescue -> this is evidence that the physically generated 3-D SAR state can enter the previously discovered branch-vulnerable region; inspect LFM fit and then proceed to Stage-C.
3. D without rescue -> stop; do not expand Neighbor-3.
4. No D -> close controlled rigid-body simulation for the selective-N3 branch claim. Do not add more simulated motion families merely to obtain a positive result.

## Physical-Realizability Interpretation (bounded scope)

A useful interpretation, not a new main research line, is:

- `H_branch`: signal-space branch-vulnerable hard-state region;
- `M_SAR`: states reachable through a specified SAR motion/geometry mapping;
- physically relevant branch hard states belong to `H_branch intersect M_SAR`.

Stage-B4 only checks whether one literature-anchored 3-D rigid-body realization naturally enters that intersection. It does **not** map the intersection, estimate its probability, or rank motion types.
