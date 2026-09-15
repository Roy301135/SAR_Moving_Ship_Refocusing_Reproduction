# EXP010-B — Noiseless Practical Non-Oracle Formal Closure

## 1. Research Question

在 EXP010-A smoke 已通过 implementation / oracle-firewall 检查后，完整 practical non-oracle sequential chain 能否在**正式物理网格**与**冻结的 DenseRisk stress set**上维持：

1. practical strong-parameter estimation 的可接受稳定性；
2. frozen Refined-LR → FiveBin staged policy 的原风险方向；
3. selective Neighbor-3 对 catastrophic branch failure 的真实 paired rescue；
4. branch reliability gain 向 downstream weak recovery 的可解释传递；
5. 不依赖 truth / oracle quantity 的完整运行闭环。

## 2. Served Claims

- **Claim 1 — Mechanism / practical-chain closure**：量化 finite-window operator floor 与 practical estimation gap。
- **Claim 2 — Method / frozen-policy closure**：验证冻结 policy 在完整 non-oracle chain 中仍产生 intermediate-cost reliability gain。

本实验不服务 Claim 3，不加入 SAR-level image translation。

## 3. Evidence Gap

EXP010-A 仅为 432-trial smoke，Paper1s 未命中 branch catastrophe，BeamDerived 仅命中 1 个。因此它只能证明“链能跑通”，不能作为正式 Claim evidence。

EXP010-B 必须扩大到：

- `OriginalGrid`：完整 PA5 物理网格；
- `DenseRisk`：PA5I-R1 已冻结风险状态 × `eta = 0:0.01:0.5`。

DenseRisk 的 truth metadata 只用于**构造验证样本**，不能进入 Proposed decision path。

## 4. Frozen Method

```text
G0 practical search
→ Stage 1: Refined-LR, b1=0.20, high-risk first
→ Stage 2: FiveBin, b2=0.10 on Stage-1-untriggered pool, low raw value = risky
→ selective Neighbor-3
→ practical recenter
→ PlateauAwareTol 0.70
→ frozen 3-bin notch
→ inverse transform
→ undo recenter
→ residual
→ full fixed-domain practical weak-beta search
```

不得修改：feature family、risk direction、b1/b2、Neighbor-3 candidate count、3-bin removal width。

## 5. Mandatory Comparators

1. `G0_OriginalTop1`
2. `Proposed_Frozen_Staged`
3. `Always_Neighbor3`
4. `ORACLE_ExactSubtraction` — evaluation/control only
5. `ORACLE_TrueBetaEta_Notch3` — evaluation/control only

## 6. Validation Sets

### OriginalGrid

- Delta-v = `[2.5, 5, 7.5, 10, 15, 20] m/s`
- side = `LowV / HighV`
- Aw/As = `[0.1, 0.2, 0.3, 0.5, 0.8]`
- relative phase = 16 uniform values
- eta = `[0, 0.125, 0.25, 0.375, 0.5]`
- two apertures: `Paper1s`, `BeamDerived`

共 4800 trials / aperture。

### DenseRisk

读取冻结的：

```text
results\exp09_physical_validation\
exp09_pa5i_r1_gamma_denseeta_tail_audit\
pa5i_r1_dense_eta_risk_states.csv
```

并保持：

```text
eta = 0:0.01:0.5
```

不得重新挖 risk state。

## 7. Falsifiers

以下任一结果会直接削弱 / 修改当前 Claim 2：

- Oracle firewall failure；
- Refined-LR 或 residual FiveBin 在有足够正负样本时 directional AUC < 0.5；
- Neighbor-3 出现 persistent systematic branch failure；
- Proposed 相对 G0 在 DenseRisk 两 aperture 均不能取得严格正 branch-failure gain；
- Proposed 出现明显 induced branch catastrophe。

出现这些结果时：**报告 falsification / limitation，不在本实验内调 policy。**

## 8. Primary Outputs

- `method_summary.csv`
- `paired_outcome_summary.csv`
- `stage_allocation_summary.csv`
- `risk_direction_audit.csv`
- `operator_gap_summary.csv`
- `upstream_estimation_summary.csv`
- `oracle_firewall_audit.csv`
- `formal_verdict.csv`
- raw batch/evaluation CSVs
- figures

以及用户回传优先文件：

```text
EXP010B_FEEDBACK_BUNDLE.txt
```

该 TXT 汇总全部需要反馈给网页端的核心数值与 verdict。通常只需上传它 + 关键图。

## 9. Stop Rule

如果 EXP010-B formal noiseless closure 通过：

> **停止继续扩展 deterministic/noiseless 实验。**

下一步进入：

```text
SNR / noise-definition literature audit
→ noise protocol freeze
```

如果 EXP010-B 失败，则只审计失败 ownership；不得为得到漂亮结果新增 feature、换 Stage-2 signal 或重调 budget。
