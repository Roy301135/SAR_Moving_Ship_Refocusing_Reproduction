# EXP01 Stage-B — SAR-to-Branch Interface Audit

Prerequisite: Stage-A has been run and accepted, and the following file exists:

```text
results/exp01_sar_branch_translation/exp01_stageA_outputs.mat
```

Run from MATLAB:

```matlab
run_exp01_stageB_interface_audit
```

Stage-B does not rerun or retune the physical scene. It loads the accepted Stage-A MAT and constructs the physical-to-sampled-LFM interface used for branch-geometry audit.

Expected new outputs:

```text
results/exp01_sar_branch_translation/
├── stageB_component_mapping.csv
├── stageB_branch_audit.csv
├── exp01_stageB_outputs.mat
├── EXP01_STAGEB_FEEDBACK_BUNDLE.txt
├── 05_stageB_physical_interface.png
└── 06_stageB_branch_landscape.png
```

For ChatGPT review, upload only the TXT and the two PNG figures. Keep CSV/MAT locally unless requested.
