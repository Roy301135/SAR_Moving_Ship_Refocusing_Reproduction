# EXP02-R0C — Cross-Ship Processing-Object Reproducibility Gate

## Purpose

R0B showed that the first real ship chip has weak dominant single-LFM evidence and
that lowest-energy background controls can have larger maximized coherence because of
the look-elsewhere / extreme-value floor.

R0C does **not** modify the signal model. It asks whether that pattern is a one-chip
accident or a reproducible property of OpenSARShip focused SLC ship chips.

## Preselected ships

All are from Scene 1 and were selected from metadata only:

```text
x19112_y4564   already used 257x257 pilot
x48949_y5380   larger ship support
x64672_y2351   larger ship support
```

No ship was selected using LFM or branch outcomes.

## Before running

Extract these two additional original `Patch` files into:

```text
E:\OpenSARShip_raw\pilot\scene01\Patch\
```

The script locates them by coordinates, so the ship-type filename prefix may vary:

```text
*_x48949_y5380.tif
*_x64672_y2351.tif
```

No `Patch_Cal` files are required for these two ships.

## Frozen analysis

Exactly the R0B dominant-LFM diagnostic is reused:

- VV primary;
- target range lines: energy > mean;
- equal-count lowest-energy background control;
- beta grid: 401;
- nfft: 2048;
- beta range inside `opensarship_lfm_coherence_scan`: `[-1/N,+1/N]`.

No G0, Neighbor-3, Proposed, branch taxonomy, or outcome-based crop/window is used.

## Run

```matlab
run_exp02_r0c_cross_ship_interface_gate
```

## Return

Upload only:

```text
EXP02_R0C_FEEDBACK_BUNDLE.txt
05_cross_ship_lfm_coherence.png
06_cross_ship_chirp_gain.png
```

Keep CSV and MAT locally.
