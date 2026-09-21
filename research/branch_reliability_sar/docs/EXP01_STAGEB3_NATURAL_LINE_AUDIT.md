# EXP01 Stage-B3 — Canonical Full Target-Line Natural Mechanism Audit

## Research Question

In the accepted and completely untuned canonical yawing-ship SAR scene, do naturally selected ship target range lines contain the **discrete-first branch failure** mechanism targeted by the frozen Neighbor-3 recovery operator?

## Served Claim

This stage serves only the SAR-level mechanism bridge:

```text
physical SAR target line
    -> sampled MC-LFM geometry
    -> natural failure taxonomy
    -> is the selective-N3 target mechanism physically present?
```

It does not test the Proposed scheduler yet.

## Evidence Gap

Stage-A established:

```text
ship motion -> SAR defocus
```

Stage-B established:

```text
physical SAR history -> sampled MC-LFM representation
```

Stage-B2 falsified faithful realization of one frozen DenseRisk row inside the pre-registered yaw-only inverse-embedding family. Therefore the next necessary evidence is not another designed hard state, but whether the canonical physical scene naturally contains the branch mechanism at all.

## Controls

1. Stage-A scene is loaded unchanged.
2. No DenseRisk target is used.
3. Target range lines are selected only by moving-SLC line energy above its mean.
4. On each line, the dominant physical scatterer defines the evaluation-only strong reference.
5. G0 and Neighbor-3 use the already frozen local-search semantics.
6. No Proposed scheduler, noise, clutter, parameter sweep, or scene retuning is allowed.

## Mechanism Taxonomy

A large strong-reference error by itself is insufficient to call a branch failure.

### E — Easy / stable

G0 strong-reference error does not exceed the frozen catastrophic threshold.

### B — Continuous-bias

The full-mixture continuous global optimum moves significantly away from the dominant strong reference, but remains in the same nearest-integer branch. Neighbor-3 should not be expected to undo this displacement.

### D — Discrete-first branch failure

The full-mixture continuous global optimum remains within the frozen branch-match tolerance of the dominant strong reference, while the coarse Top-1 branch changes and G0 becomes catastrophic.

This is the mechanism directly served by Neighbor-3.

### G — Global-winner / branch change

The full-mixture continuous global optimum moves to a different nearest-integer branch relative to the dominant strong reference.

### U — Unresolved guard

If the geometry is internally inconsistent with the above taxonomy, stop rather than relabel it for convenience.

## Metrics

Per selected target line:

- line energy / mean line energy;
- dominant scatterer and dominant energy fraction;
- second/first component-energy ratio;
- dominant sampled-LFM fit NRMSE / R2;
- dominant strong global reference nu;
- full-mixture global continuous nu;
- coarse Top-1 branch;
- G0 nu and error to strong reference;
- Neighbor-3 nu and error to strong reference;
- mixture-global displacement from strong reference;
- coarse Top-2 / Top-1 score ratio;
- mechanism class;
- Neighbor-3 rescue flag.

## Falsifier / Stop Rule

1. Any unresolved `U` line -> stop and audit the interface/classifier only.
2. At least one natural `D` line with Neighbor-3 rescue -> Stage-C is authorized immediately.
3. Natural `D` exists but none is rescued -> stop; no Neighbor-5, no scene retuning.
4. No natural `D` line -> close the canonical yaw-only scene for the selective-N3 SAR claim. Do not manufacture a failure.

The stage is complete after this single canonical-scene audit. No second yaw configuration is added merely to obtain a preferred outcome.
