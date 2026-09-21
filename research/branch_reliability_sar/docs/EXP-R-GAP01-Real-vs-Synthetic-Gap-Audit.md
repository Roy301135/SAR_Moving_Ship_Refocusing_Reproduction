# EXP-R-GAP01-Real-vs-Synthetic-Gap-Audit

## Why GAP01 exists

Before FAIR-CSAR, synthetic / controlled branch-reliability experiments produced positive local-recovery results. On real FAIR-CSAR Candidate B/C, most accepted states are SAFE, observed failures are mainly remote-basin misses, no natural frozen-N3 rescue was found, and R2A showed only limited overall branch headroom.

GAP01 distinguishes three explanations:

1. implementation / parameter-range incompatibility;
2. upstream `p_beta` estimation mismatch;
3. broader real-data signal-model gap: multi-component mixing, higher-order/nonlinear phase, clutter, range-cell mixing, spatial variation, etc.

This is a diagnostic audit only. It proposes no new recovery method.

## A. Parameter-support exact clones

For every R1B accepted real state, synthesize

```text
x[m] = exp(j*pi*a*m^2 + j*2*pi*nu*m/N)
a    = tan(pi*p_beta/2) * (8/(N-1))^2
```

using that real state's frozen `p_beta` and evaluation-only global `nu`, then run the same frozen real-data branch audit.

If all clones close correctly, the R1 implementation is compatible with the actual parameter support encountered in Candidate B.

## B. Real single-quadratic-LFM adequacy

For each real state, compute squared normalized projection onto the frozen quadratic-LFM atom:

```text
C = |h^H x|^2 / (||h||^2 ||x||^2)
```

Then allow only `p_beta +/- 0.04`. For each candidate `p_beta`, optimize `nu` over the full period.

Interpretation:

- large local-p gain: upstream `p_beta` mismatch is plausible;
- low absolute coherence plus small local-p gain: a broader model/multi-component/higher-order gap is more plausible.

Important: a real range-column signal can contain multiple components, so low coherence is not unique proof of high-order phase.

## C. Paired J(p_beta,nu) landscapes

Four representative states:

1. largest real G0 failure;
2. most ambiguous failure by coarse margin;
3. most ambiguous SAFE state;
4. representative SAFE state.

For each, plot the real objective and an exact synthetic clone side by side.

## Frozen branch semantics

```text
local halfwidth = 0.75 bin
local bracket points = 33
Neighbor radius = 1
branch match = 0.02 bin
catastrophic = 0.10 bin
global reference oversample = 1024
```

No N3/Top-K/search-window retuning is allowed.

## Run

```matlab
run_exp02_fair_gap01_real_vs_synthetic
```

## Output folder

```text
research/branch_reliability_sar/results/
  exp02_real_sar_branch_audit/
    fair_csar/
      gap01_real_vs_synthetic/
```

## Upload

1. `EXP02_FAIR_GAP01_FEEDBACK.txt`
2. `01_synthetic_clone_parameter_support.png`
3. `02_real_single_lfm_adequacy.png`
4. `03_joint_landscape_representatives.png`
5. `04_gap_summary.png`

Keep CSV/MAT locally.
