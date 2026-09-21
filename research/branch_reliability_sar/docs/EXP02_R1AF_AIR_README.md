# EXP02-FAIR-R1A — Real Branch-State Occurrence Audit

## Purpose

R1A asks one narrow question:

> On the real FAIR-CSAR Candidate-B component states already accepted by R0,
> does the frozen discrete-first G0 search naturally select a different
> continuous branch from the full-period continuous global winner, and can
> frozen Neighbor-3 recover it?

R1A is **not** a Proposed-method experiment.

## Frozen input

R1A reads, without re-selection:

- the corrected FAIR R0 workspace;
- the R0 component-consistency workspace;
- the exact dominant recurrent component lines marked `matched == true`;
- their saved `matched_order`.

For the accepted Candidate B this is expected to be **8 real component-line states**.
The script stops if that number changes.

## Search semantics

Inherited/frozen:

- local half-width: `0.75 bin`
- local bracket points: `33`
- Neighbor radius: `1`
- branch-match tolerance: `0.02 bin`
- catastrophic threshold: `0.10 bin`

Evaluation-only full-period global reference:

- zero-padded FFT oversample: `1024`
- continuous refinement around the sampled global maximum
- never enters G0 or N3 decisions

## R0-order to branch-domain mapping

For R0 component order `p_beta` and line length `N`:

```text
a_sample = tan(pi*p_beta/2) * (8/(N-1))^2
```

Then:

```text
z[m] = x[m] * exp(-j*pi*a_sample*m^2)
```

The centered-coordinate expansion leaves only a linear phase plus a constant after correct quadratic removal, which is exactly the tone coordinate audited by G0/N3.

## Taxonomy

- `SAFE`
- `G0_FAIL_N3_RESCUE`
- `N3_COVERAGE_MISS`
- `PERSISTENT_WITHIN_COVERAGE`

A separate severity flag marks `G0_error > 0.10 bin` as catastrophic.

## Scientific boundary

The full-period continuous winner is the global winner of the **same search objective**.
It is not physical ground truth for ship motion.

R1A is conditional on the R0-estimated component order and therefore does not claim access to hidden true beta.

No outcome from R1A may retune the frozen branch search.

## Run

From MATLAB:

```matlab
run_exp02_fair_r1a_real_branch_occurrence
```

## Result folder

```text
research/branch_reliability_sar/results/
  exp02_real_sar_branch_audit/
    fair_csar/
      r1a_real_branch_occurrence/
```

## Upload for review

Only upload:

1. `EXP02_FAIR_R1A_FEEDBACK.txt`
2. `01_frequency_and_error_audit.png`
3. `02_branch_taxonomy_map.png`
4. `03_selected_objective_landscapes.png`
5. `04_margin_vs_g0_error.png`

Keep CSV/MAT locally.
