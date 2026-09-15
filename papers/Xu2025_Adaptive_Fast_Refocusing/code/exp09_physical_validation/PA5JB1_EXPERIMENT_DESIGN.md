# EXP009 / PA5J-B1 — Frozen Experiment Design

## Research Question

Can internal G0 search-state diagnostics selectively invoke Neighbor-3, reducing final catastrophic branch failures while retaining most of the computational advantage of G0?

The experiment moves beyond PA5J-B0:

```text
warning ability
    ↓
actual Neighbor-3 recovery
    ↓
final failure probability
    ↓
objective-evaluation cost
    ↓
cost–reliability Pareto
```

## Baselines

- **G0 — OriginalTop1**: no fallback.
- **Always Neighbor-3**: reliability / cost reference.

## Selective policies

- **G2 FiveBin**: `fivebin_peak_fraction`, low = risky.
- **G3 Entropy**: `local_entropy5`, high = risky.
- **G4 Cost0_MaxRank**: max of within-group risk percentiles of FiveBin and Entropy.
- **G5 RefinedLR**: `refined_lr_asymmetry`, high = risky, +2 objective evaluations per trial.
- **G6 All3_MaxRank**: max of all three within-group risk percentiles, +2 objective evaluations per trial.

No learned fusion weights are introduced.

## Primary groups

Analyze separately:

- Original / Paper1s
- Original / BeamDerived
- DenseRisk / Paper1s
- DenseRisk / BeamDerived

## Budget sweep

\[
b\in\{0,0.005,0.01,0.02,0.05,0.1,0.2,0.3,0.5,0.75,1\}.
\]

Selection is tie-inclusive, so actual fallback fraction may exceed nominal budget.

## Final failure definition

A triggered trial uses the **stored Neighbor-3 result**.

An untriggered trial uses the **stored G0 result**.

This allows explicit separation of:

- rescue;
- unresolved failure;
- induced failure.

## Cost model

Because the decision is made after G0:

\[
C_i^{adaptive}
=
C_{G0,i}
+
C_{diag}
+
I_i(C_{N3,i}-C_{G0,i}).
\]

For Cost-0 policies:

\[
C_{diag}=0.
\]

For RefinedLR / All3:

\[
C_{diag}=2.
\]

## Primary endpoint

\[
\boxed{
P_F^{final}
\quad\text{vs}\quad
E[N_{\mathrm{objective\ evals}}]
}
\]

## Secondary endpoints

- actual fallback fraction;
- rescued G0 failures;
- induced failures;
- persistent failures after fallback;
- q95 / q99 / q99.9 branch error;
- max branch error;
- Wilson interval.

## Expected branches

### A — Refined-LR creates a new Pareto front
The simplest adaptive gate is already sufficient.

### B — All-three fusion strictly improves Refined-LR
B0 complementarity translates into actual algorithmic gain.

### C — Cost-0 fusion is competitive
A cheap reliability gate may be preferable despite weaker single-indicator AUC.

### D — Adaptive policies hit a reliability floor
Supports the B0 low-cost local-observability-ceiling candidate and motivates explicit branch exploration.

### E — Neighbor-3 itself has non-negligible failure / induced failure
The bottleneck shifts from gating to the recovery operator.

The MATLAB exporter does not decide among these branches automatically.
