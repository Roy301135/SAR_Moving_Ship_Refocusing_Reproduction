# EXP-R-R2A-Branch-Contribution-to-Image-Defocus

## Critical correction

The first R2A implementation attempted to map the R1 branch coordinate
`nu` into the finite `u_norm` grid used by `frft_direct.m`.

That was the wrong interface.

R1 defines `nu` after dechirping as a **tone frequency in DFT-bin units**:

```text
z[m] = x[m] * exp(-j*pi*a*m^2)
J(nu)=|sum z[m] exp(-j*2*pi*nu*m/N)|^2
```

For some valid `(p_beta, nu)` pairs, converting this uncentered-sample tone
coordinate into the finite direct-FrFT `u` grid pushes the implied FrFT peak
to or beyond the edge of `u_norm`. The previous synthetic true/wrong closure
therefore collapsed both branches to the same boundary behavior and returned
a ratio near 1.

Changing the closure metric could not fix that coordinate mismatch.

## Correct R2A operator

The corrected experiment stays in the exact coordinate used by R1 and by the
validated EXP009/EXP010 practical removal chain:

```text
recenter by nu
-> dechirp by a
-> FFT
-> frozen finite window around DC
-> inverse FFT
-> rechirp
-> undo recenter
-> sequential subtraction
```

with:

```text
a = tan(pi*p_beta/2) * (8/(N-1))^2
```

This is the same mathematical mechanism used in EXP009/EXP010:

```text
practical_recenter_notch_remove
matched_lfm_transform
inverse_matched_lfm_transform
```

The frozen practical removal width is:

```text
3 bins
```

No R1 branch parameter is retuned.

## New helper

```text
research/branch_reliability_sar/functions/fair_csar/
  refocus_mclfm_branch_native_clean.m
```

The helper also returns a common matched-LFM focused profile. Each extracted
component is returned to its original `nu` location on the common FFT-bin
axis before accumulation.

## One-variable comparison

Both G0 and Global paths use the same:

- Candidate B;
- R1B accepted component states;
- `p_beta`;
- component order;
- 3-bin finite extraction width;
- sequential removal / accumulation operator.

Only:

```text
nu_G0 -> nu_Global
```

changes.

`nu_Global` remains an evaluation reference, not physical motion truth.

## Closure

Synthetic known LFM:

```text
x[m] = exp(j*pi*a*m^2 + j*2*pi*nu_true*m/N)
```

Correct branch must capture at least 95% of signal energy in the branch-
centered 3-bin matched-LFM window.

A deliberately wrong branch offset by 24 bins must capture no more than 5%.

If either fails, real Candidate-B processing stops.

## Metrics

Primary metrics compare ONLY the two outputs in the same matched-LFM focused
coordinate:

- entropy;
- azimuth 80%-energy width;
- peak concentration.

The original SLC is displayed only as context because its row coordinate is
not identical to the matched-LFM output coordinate.

## Run

```matlab
run_exp02_fair_r2a_branch_contribution_candidate_b
```

## Upload

1. `EXP02_FAIR_R2A_FEEDBACK.txt`
2. `01_reconstruction_closure.png`
3. `02_original_g0_global.png`
4. `03_g0_vs_global_difference.png`
5. `04_metric_comparison.png`
6. `05_failure_column_profile.png`
