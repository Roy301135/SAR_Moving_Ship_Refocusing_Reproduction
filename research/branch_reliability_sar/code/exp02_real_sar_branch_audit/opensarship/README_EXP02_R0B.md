# EXP02-R0B — Real Complex-Line Dominant LFM Compatibility Audit

R0A established that OpenSARShip original `Patch/*.tif` preserves usable complex
VH/VV SLC information and that:

```text
row    = azimuth
column = range
g(:,n) = fixed-range complex azimuth line
```

R0B asks whether real `g(:,n)` lines exhibit coherent support for the same local
discrete-LFM family used in the signal-level work.

This is **not a branch experiment**.

For each natural target line from R0A, and an equal-count lowest-energy background
control, the code scans:

\[
s[m;\beta,\nu]
=
e^{j\pi\beta m^2}
e^{j2\pi\nu m/N}.
\]

It reports dominant single-LFM projection coherence, tone-only coherence,
chirp gain, best `beta`, best `nu`, and beta-boundary hits.

No hard model-validity threshold is introduced.

Run:

```matlab
run_exp02_r0b_real_lfm_compatibility_audit
```

Upload only:

```text
EXP02_R0B_FEEDBACK_BUNDLE.txt
03_real_lfm_compatibility_overview.png
04_representative_beta_profiles.png
```

Keep CSV and MAT locally.
