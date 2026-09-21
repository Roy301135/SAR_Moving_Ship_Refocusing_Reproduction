# EXP02-R0A — OpenSARShip Complex-Chip Interface Gate

## Scope

This stage validates the real complex-data interface only.

It does **not** run:

- MC-LFM search;
- G0;
- Neighbor-3;
- branch taxonomy;
- Proposed scheduler.

The selected science-pilot chip is:

```text
Patch/Cargo_x19112_y4564.tif
```

with its corresponding:

```text
Patch_Cal/Cargo_x19112_y4564.tif
```

## OpenSARShip SLC schema

According to the dataset ReadMe:

```text
band 1 = Re(VH)
band 2 = Im(VH)
band 3 = Re(VV)
band 4 = Im(VV)
```

and dataset coordinates are:

```text
x = range
y = azimuth
```

Therefore:

```text
MATLAB row    = azimuth
MATLAB column = range
g(:,n)        = fixed-range complex azimuth line
```

## Expected local data layout

```text
E:\OpenSARShip_raw\pilot\scene01\
├── Metedata.xml
├── Ship.xml
├── ReadMe.pdf
├── Patch\
│   └── Cargo_x19112_y4564.tif
└── Patch_Cal\
    └── Cargo_x19112_y4564.tif
```

## Run

```matlab
run_exp02_r0a_complex_interface_gate
```

## Return for review

Upload only:

```text
EXP02_R0A_FEEDBACK_BUNDLE.txt
01_complex_chip_sanity.png
02_target_line_energy.png
```

Keep the MAT file locally unless an anomaly occurs.

## Important motion-ground-truth limitation

OpenSARShip provides real complex SLC observations plus AIS/navigation metadata.
It does not provide synchronized ground-truth roll, pitch, yaw, heave, sway, or surge
time series for each vessel. Any 3-D ship-motion effects present in the SLC are latent
physical effects in the observed phase/scattering process, not labeled truth.
