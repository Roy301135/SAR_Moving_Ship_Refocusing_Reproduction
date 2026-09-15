# EXP009–EXP010 最终“论点—证据—图表—局限”矩阵 v1.0

> 项目：复杂运动舰船 SAR 顺序重聚焦与可靠性感知恢复  
> 当前状态：**论文架构 / 证据冻结阶段（Paper Architecture / Evidence Freeze）**  
> 更新时间：2026-09-13  
> 用途：用于后续向导师/老师汇报、论文架构讨论、正文与补充材料划分，以及避免继续无边界扩展实验。

---

# 0. 论文最终定位

本篇不再组织成多个彼此平行的小创新，而收敛为两个核心研究点。

---

## 核心论点 1：失效机理（Failure Mechanism）

### 推荐中文表述

> **有限窗与非整数栅格（off-grid）效应，以及多分量之间的相干扰动，会共同改变顺序重聚焦过程中的搜索目标函数形态；在困难条件下，这种局部估计偏差会进一步演化为全局分支竞争，并最终导致少量灾难性分支选择错误。**

### 对应英文稿可用表述

> Finite-window/off-grid effects and coherent multi-component perturbations can distort the sequential-refocusing search landscape; under difficult regimes, this distortion can escalate from local estimation bias to global branch competition and rare catastrophic branch-selection failure.

### 不应过度表述为

> 所有失效都能够由一个统一、严格闭合、适用于所有工况的层级模型完整解释。

目前证据足以支持“**机制链条 + 关键因果瓶颈**”，但不支持所有工况下统一的闭式失效模型。

---

## 核心论点 2：可靠性感知的选择性恢复（Reliability-Aware Selective Recovery）

### 推荐中文表述

> **可利用计算代价较低的内部可靠性指标，分阶段选择性调用 Neighbor-3 分支恢复。Refined-LR 主要捕获可观测性较强的失效核心，剩余样本中的 FiveBin 指标则提供局部互补信息。冻结后的分阶段策略在 practical non-oracle 全链路中能够以明显低于 Always-N3 的计算代价降低灾难性分支错误，并在加性噪声压力测试和宽泛物理状态网格中保持净收益；但这种可靠性受到上游强分量参数估计精度的明确约束。**

### 对应英文稿可用表述

> Cheap internal reliability states can be used in a staged manner to allocate Neighbor-3 recovery selectively. Refined-LR captures the dominant observable failure core, while residual FiveBin information provides a localized complementary signal. The frozen staged policy yields genuine intermediate-cost reliability gains under practical non-oracle processing, and the gain persists under additive-noise stress and broad physical-state anchors, subject to an upstream strong-parameter accuracy boundary.

### 不应过度表述为

- Neighbor-3 在 practical chain 中无条件“绝对安全”；
- 分阶段策略在所有计算成本、所有 SNR、所有场景下都优于单阶段策略；
- FiveBin 是所有残余失效条件下的最佳可靠性指标；
- 当前 batch/rank scheduler 已经等价于部署阶段可直接使用的逐样本固定阈值；
- 当前工作已经完成海杂波、真实 SAR 场景和端到端图像级工程验证。

---

# 1. 最终“论点—证据”矩阵

## 1.1 核心论点 1：失效机理

| 子结论 | 核心实验 | 关键结果 / 直接证据 | 证据等级 | 在正文中的作用 | 主要局限 |
|---|---|---|---|---|---|
| 在 Wang / Xu 对应的物理尺度下，有限合成孔径确实会限制多分量分辨和顺序恢复 | P0 / P1 / P1B / P1C | 归一化模型中发现的问题可以迁移到实际论文参数尺度；跨孔径和几何条件并非始终稳定 | B | 物理尺度锚定 | 不是对所有真实海况的统计描述 |
| 有限窗去除存在“强分量残留”与“弱分量损伤”的结构性权衡 | PA5 / PA5B / PA5C | 窗口变宽可降低强分量泄漏 \(L_s\)，但会增加弱分量损伤 \(D_w\) | A/B | 机制主证据 | 针对当前冻结的去除算子族 |
| 弱分量可恢复误差可分解为 \(E^2=(L_s/r_A)^2+D_w^2\) | PA5C / PA5D | 强分量残留项被 \(1/r_A\) 放大，因此弱分量越弱，对残留越敏感 | A | **核心解析结果** | 主要针对无噪声算子级分析 |
| 有限窗 / off-grid 泄漏会形成弱强比可恢复下限 | PA5D | 推导得到 \(r_{\min}=L_0/\sqrt{1-D_0^2}\) | A | **核心解析结果** | 不是含噪真实 SAR 的最终物理下限 |
| half-bin / off-grid 下限并非峰值定义或数值 tie 造成 | PA5E / PA5E-R1 | 改变峰值语义与 tie tolerance 后，下限仍然存在 | A | 反事实排除 | 建议放补充材料 |
| 亚栅格重定位（sub-bin recenter）是 off-grid 下限的关键因果瓶颈 | PA5F | Oracle recenter 几乎消除强分量泄漏及 recoverability floor | A | **强因果反事实证据** | Oracle 仅用于机制归因 |
| 单强分量下的大部分偏差来自离散插值，而多分量偏差不只是插值问题 | PA5F / PA5G | 连续 ML 后 strong-only bias 接近 0，但 mixture bias 仍保留 | A | 区分数值偏差与物理相干扰动 | 仍受有限观测窗影响 |
| 低 / 中 contrast 下的 mixture bias 具有一阶扰动结构 | PA5H | \(\delta_{\rm mix}\approx-rH'(0)/J_s''(0)\)，在低 / 中 contrast 下吻合较好 | A/B | 局部偏差机制解释 | 不应外推到高 contrast |
| 高 contrast 条件下会出现全局分支切换，而不仅是局部偏差继续增大 | PA5H-R1 | local-continuous 与 global-search 结果出现分离 | A/B | **局部偏差 → 全局分支失效的分界** | 不等于统一闭式 branch 模型 |
| 灾难性分支错误与连续参数局部偏差是两类不同失效模式 | PA5H-R1 / PA5I | 局部 refinement 仍可能平滑，但 global winner 已发生切换 | A | **Claim 1 的终点** | catastrophic threshold 使用冻结定义 |
| practical chain 中 residual N3 failure 的主要 ownership 是上游 \(\hat\beta_s\) 失配 | EXP010-B-R1 | 当前 86 个 N3 residual failures 在 true-\(\beta\) control 下 86/86 消失；true-\(\beta\) candidate coverage miss=0 | A | **实际链路有效性边界归因** | true \(\beta\) 仅为 evaluation control |
| 加性噪声会放大上游 \(\beta\) 估计误差尾部，并进一步恶化分支可靠性 | EXP010-C DenseRisk + OriginalGrid | 低 SNR 下 strong-\(\beta\) error 的 p99 明显增大，同时 branch failure 上升 | B | 噪声鲁棒性中的机制承接 | 当前只验证 complex AWGN，不等同于海杂波 |

### Claim 1 压缩后的逻辑链

```text
有限孔径 / 有限窗
        ↓
off-grid 强分量残留 + 弱分量损伤
        ↓
弱分量可恢复下限
        ↓
Oracle recenter 定位关键因果瓶颈
        ↓
连续 refinement 消除 strong-only 插值偏差
        ↓
多分量相干作用仍保留系统性局部偏差
        ↓
高 contrast 下出现全局分支竞争 / winner switching
        ↓
少量灾难性分支选择错误
        ↓
practical β 估计误差决定 N3 residual failure
        ↓
噪声进一步放大 β-error tail，并暴露可靠性边界
```

---

## 1.2 核心论点 2：可靠性感知的选择性恢复

| 子结论 | 核心实验 | 关键结果 / 直接证据 | 证据等级 | 在正文中的作用 | 主要局限 |
|---|---|---|---|---|---|
| Neighbor-3 相比 G0 更可靠，但若对全部样本运行，计算成本明显更高 | PA5I / I-R1 | deterministic precursor 中 N3 显著减少灾难性错误，但 objective evaluations 大幅增加 | B | 方法动机 | 早期“零失效”建立在正确 strong chirp-rate 条件下 |
| cheap-search 内部存在可用于风险判断的可靠性状态 | PA5J-A | Refined-LR、FiveBin、Entropy 均有一定 directional AUC，Refined-LR 最强 | B | 风险 gate 可行性 | AUC 表示排序能力，不是部署阈值 |
| Refined-LR 主要捕获可观测性较高的失效核心 | B0 / B1 | 低 / 中预算下 capture / precision 最强 | B | Stage 1 设计依据 | 并非所有 regime 都最优 |
| Refined-LR 未触发的 residual pool 中，FiveBin 仍保留额外信息 | B2 | residual-pool AUC：Paper1s 约 0.76–0.82；BeamDerived 约 0.63–0.72 | A/B | Stage 2 设计依据 | 贡献属于局部互补 |
| 直接把多个指标做同时 max-rank fusion 会在低预算下产生 rank dilution | B2 | budget-matched trigger-set 对照否定“指标越多直接融合越好” | A | staged architecture 的必要性 | 不等于所有 fusion 方式都无效 |
| staged allocation 的收益并非单阶段预算网格太稀造成 | B3-R1 | 枚举约 49,173 个 deterministic single-stage endpoints 后，仍保留局部 Pareto 改善 | A | **公平性审计** | 改善主要集中于 intermediate-compute 区域 |
| 同一组 policy 参数可跨 Paper1s / BeamDerived 保持正收益 | B3-R2 | 216 个共享参数配置中存在 strict-both / robust-front，最终冻结 \(b_1=0.20,b_2=0.10\) | A/B | **跨孔径共享策略证据** | 属于 in-grid robustness，不是 held-out generalization |
| practical non-oracle chain 中 Proposed 仍可显著降低 branch failure，并在 DenseRisk 中改善弱分量恢复 | EXP010-B | DenseRisk / Paper1s：branch fail .1364→.0312，weak feasible .5900→.6818；BeamDerived：.1716→.0833，weak .4412→.5000 | B | **practical 主结果** | Always-N3 仍保留 residual failure floor |
| noiseless practical chain 中 Proposed 没有制造新的 branch catastrophe | EXP010-B | 四组 validation 中 Proposed induced branch catastrophe = 0 | B | 安全性证据 | severe noise 下可出现极少量 induced harm |
| practical N3 residual floor 来源于上游 \(\beta\) 失配，而非 N3 邻接候选覆盖不足 | EXP010-B-R1 | 86/86 failures 在 true-\(\beta\) 后消失；beta-error 对 N3 failure 的 AUC 为 0.834–0.998 | A | **局限归因** | 因此 N3 只能描述为“条件可靠” |
| 冻结 policy 在 AWGN stress 下仍保持显著 branch gain | EXP010-C DenseRisk | Paper1s 从 -5 到 20 dB 均明显低于 G0；BeamDerived 从 -10 到 20 dB 也保持净收益 | B | **噪声鲁棒性主结果** | Paper1s / -10 dB 的 Stage2 接近随机水平 |
| 对完整 staged interpretation 而言，跨孔径的保守噪声有效下限为 \(-5\) dB | EXP010-C DenseRisk | Paper1s 在 -10 dB Stage2 AUC≈0.496，criterion fail；-5 dB 及以上通过；BeamDerived 到 -10 dB 仍通过 | B | **validity boundary** | 不等于低于 -5 dB 方法完全失效 |
| 宽泛 OriginalGrid 上没有观察到系统性 noise-induced harm | EXP010-C OriginalGrid anchor | 两 aperture 在 -10 / 0 / 10 / 20 dB 全部 validity pass；所有 anchor 上 Proposed branch fail < G0 | B | **宽泛物理状态 sanity check** | OriginalGrid 仍不等同于真实海况分布 |
| scheduler 在不知道 SNR 的情况下，会自然把更多计算量分配给 noisy / risky 样本 | EXP010-C | 低 SNR 时 fallback fraction 更高，高 SNR 时更低；代码明确禁止 per-SNR reranking | B/C | 工程解释亮点 | 当前仍是 batch fixed-compute scheduler |
| 在信息较充分的 SNR 条件下，Proposed 可接近 Always-N3 的可靠性，但计算成本显著更低 | EXP010-C | OriginalGrid 10 / 20 dB 多处 Proposed branch failure≈Always-N3；normalized branch cost 约 0.18–0.19 vs 1 | B | Pareto 结果 | 不应外推到所有 SNR / 所有 stress case |
| 分支正确只是弱分量恢复的必要条件，而非充分条件 | EXP010-B / C | 多处 branch rescue 并未立即转化为 weak feasible；较高 SNR 下 weak gain 才更明显 | B | 讨论与局限 | finite-window operator floor 与 residual geometry 仍存在 |

### Claim 2 压缩后的逻辑链

```text
Neighbor-3：更可靠，但计算量高
        ↓
cheap-search 内部存在可观测风险状态
        ↓
Refined-LR 捕获主要失效核心
        ↓
residual FiveBin 提供局部互补
        ↓
分阶段分配 Neighbor-3
        ↓
穷举单阶段 fairness audit
        ↓
共享 policy 跨孔径冻结
        ↓
practical non-oracle 全链路闭合
        ↓
R1 明确 N3 受上游 β 精度约束
        ↓
冻结 policy 通过 AWGN robustness
        ↓
OriginalGrid 证明宽泛物理状态下无系统性崩塌
```

---

# 2. 建议进入正文的核心数值

## 2.1 无噪声 practical closure：EXP010-B

### DenseRisk / Paper1s

- G0 branch failure：**0.13636**
- Proposed branch failure：**0.03119**
- Always-N3 branch failure：**0.02406**
- Proposed normalized branch cost：**0.277**
- G0 weak feasible：**0.59002**
- Proposed weak feasible：**0.68182**
- 配对 branch rescue / harm：**118 / 0**
- 配对 weak rescue / harm：**109 / 6**

### DenseRisk / BeamDerived

- G0 branch failure：**0.17157**
- Proposed branch failure：**0.08333**
- Always-N3 branch failure：**0.06373**
- Proposed normalized branch cost：**0.283**
- G0 weak feasible：**0.44118**
- Proposed weak feasible：**0.50000**
- 配对 branch rescue / harm：**36 / 0**
- 配对 weak rescue / harm：**24 / 0**

### OriginalGrid

- Paper1s branch failure：**0.01063 → 0.00563**
- BeamDerived branch failure：**0.00354 → 0.00125**
- normalized branch cost：约 **0.283–0.285**
- weak feasible 仅小幅提升，主要作为 broad-safety / non-inferiority 证据。

---

## 2.2 Neighbor-3 ownership audit：EXP010-B-R1

- 当前 N3 residual failures：**86**
- true-\(\beta\) 后被消除：**86**
- true-\(\beta\) 下仍 persistent：**0**
- true-\(\beta\) candidate coverage miss：**0**
- true-\(\beta\) 已覆盖但仍失败：**0**
- true-\(\beta\) control induced failures：**0**

beta-error 对 N3 failure 的 directional AUC：

- Original / Paper1s：**0.9976**
- Original / BeamDerived：**0.9949**
- DenseRisk / Paper1s：**0.9425**
- DenseRisk / BeamDerived：**0.8338**

因此最安全的结论是：

> practical chain 中 residual Neighbor-3 failure 的主要来源是上游 strong-\(\beta\) 估计失配，而不是 Neighbor-3 邻接候选覆盖本身。

---

## 2.3 DenseRisk 加性噪声鲁棒性：EXP010-C

### Paper1s

| Strong-SNR | G0 branch fail | Proposed | Always-N3 | Proposed cost | weak feasible 净增益 |
|---:|---:|---:|---:|---:|---:|
| -10 dB | .3553 | .2817 | .2703 | .367 | 0 |
| -5 dB | .2211 | .0945 | .0761 | .345 | 0 |
| 0 dB | .1705 | .0431 | .0336 | .283 | 0 |
| 5 dB | .1471 | .0298 | .0245 | .244 | +.0482 |
| 10 dB | .1450 | .0284 | .0233 | .235 | +.0721 |
| 15 dB | .1405 | .0305 | .0234 | .231 | +.0715 |
| 20 dB | .1381 | .0307 | .0232 | .230 | +.0899 |

解释边界：

- 完整 staged reliability interpretation 的保守跨孔径下限：**-5 dB**
- Paper1s 在 -10 dB 时 Stage2 AUC≈**0.496**
- 该点应解释为“残余诊断信息接近随机水平”，而不是“整个 Proposed 完全失效”。

### BeamDerived

- Proposed 在 -10→20 dB 全程保持正 branch gain；
- strict criterion 到 **-10 dB** 仍通过；
- downstream weak gain 出现得更晚，说明 weak recovery 仍受到去除算子和 residual geometry 的限制。

---

## 2.4 OriginalGrid 噪声锚点

四个 anchor：

\[
-10,\ 0,\ 10,\ 20\ {\rm dB}
\]

两个 aperture 均通过 validity check。

### Paper1s branch failure

- -10 dB：**.14663 → .14092**
- 0 dB：**.01425 → .00875**
- 10 dB：**.01067 → .00563**
- 20 dB：**.01029 → .00558**

### BeamDerived branch failure

- -10 dB：**.05175 → .04871**
- 0 dB：**.00538 → .00304**
- 10 dB：**.00358 → .00138**
- 20 dB：**.00342 → .00121**

宽泛物理状态下的安全结论：

> severe noise 下收益会缩小，但没有观察到系统性 broad-regime collapse；在中高 SNR 条件下，Proposed 可用约 18%–23% 的 normalized branch cost 接近 Always-N3 的 branch reliability。

---

# 3. 图表冻结建议：正文建议保留 7 张主图

## 图 1：问题与失效机制总览

### 目的

用一张图说明论文研究对象与核心困难：

```text
MC-LFM 方位线
→ 强分量参数估计
→ recenter / 有限窗去除
→ residual
→ 弱分量搜索
```

在链路旁标出三类主要失效源：

1. finite-window / off-grid leakage；
2. 多分量相干扰动；
3. global branch competition / catastrophic selection。

### 来源

自绘机制图，不需要新增实验。

---

## 图 2：有限窗 / off-grid 的 weak recoverability 机制

建议 3 个 panel：

- (a) removal width 与 \(L_s\)、\(D_w\) 的权衡；
- (b) 解析式
  \[
  E^2=(L_s/r_A)^2+D_w^2
  \]
  与实验结果对比；
- (c) \(r_{\min}\) recoverability floor + oracle recenter 反事实。

### 来源

PA5C / PA5D / PA5F。

### 作用

Claim 1 最核心的 operator-level mechanism figure。

---

## 图 3：从局部估计偏差到全局分支失效

建议 3 个 panel：

- (a) strong-only continuous refinement 后 bias 接近 0；
- (b) mixture local bias 与一阶扰动预测；
- (c) high-contrast 下 local refinement 与 global winner 分离。

### 来源

PA5G / PA5H / PA5H-R1。

### 作用

明确：

\[
\text{局部连续偏差}
\neq
\text{全局灾难性分支错误}
\]

---

## 图 4：可靠性指标与 staged policy

建议 3 个 panel：

- (a) Refined-LR / FiveBin 的风险排序能力；
- (b) Refined-LR 过滤后的 residual pool 中 FiveBin 的互补性；
- (c) frozen staged policy 流程图。

### 来源

PA5J-A / B2 + policy freeze。

### 注意

Entropy 等次级可靠性指标可移至补充材料，避免正文过密。

---

## 图 5：Deterministic cost–reliability Pareto closure

建议：

- (a) 穷举 single-stage frontier vs staged points（B3-R1）；
- (b) Paper1s / BeamDerived shared-policy audit（B3-R2）；
- 标出最终冻结点：
  \[
  b_1=0.20,\qquad b_2=0.10.
  \]

### 作用

Claim 2 的公平性与共享策略证据。

---

## 图 6：Practical non-oracle closure 与 failure ownership

建议 4 个 panel：

- (a) OriginalGrid：G0 / Proposed / Always-N3 的 branch failure 与 cost；
- (b) DenseRisk：同上；
- (c) DenseRisk weak feasible：G0 → Proposed；
- (d) R1 ownership：86 个 residual N3 failures 在 true-\(\beta\) control 下变为 0，并配 beta-error failure/success 对比。

### 来源

EXP010-B + EXP010-B-R1。

### 作用

证明方法从 isolated mechanism 成功迁移到 practical chain，同时明确其适用边界。

---

## 图 7：加性噪声下的 validity boundary

建议 4 个 panel：

- (a) DenseRisk / Paper1s：branch failure vs SNR；
- (b) DenseRisk / BeamDerived：branch failure vs SNR；
- (c) strong-\(\beta\) error 的 p99 vs SNR；
- (d) fallback fraction / normalized cost vs SNR。

图中可标出：

- Paper1s staged validity floor：**-5 dB**
- OriginalGrid 四个 SNR anchors 全部通过。

### 关键解释

policy 不知道真实 SNR，但低 SNR 情况会自然触发更多 recovery budget，体现：

> **内部可靠性状态驱动的自适应计算资源分配**

而不是：

> **根据已知 SNR 人为调节预算。**

---

# 4. 建议进入正文的表格

## Table I — Signal / Geometry / Processing Parameters

包含：

- Wang / Xu 物理参数；
- Paper1s / BeamDerived；
- strong / weak ratio；
- \(\eta\)；
- removal width；
- N3 search semantics；
- catastrophic threshold；
- \(b_1,b_2\)；
- AWGN SNR 定义。

---

## Table II — Practical Noiseless Main Results

仅保留：

- OriginalGrid / DenseRisk；
- Paper1s / BeamDerived；
- G0 / Proposed / Always-N3；
- branch fail；
- normalized cost；
- weak feasible；
- paired rescue / harm。

Oracle exact / oracle notch 建议放 Supplement。

---

## Table III — Noise Robustness Summary

建议列：

- SNR；
- G0 / Proposed / N3 branch fail；
- Proposed cost；
- strong-\(\beta\) p99 error；
- weak feasible gain；
- validity pass/fail。

正文优先 DenseRisk；
OriginalGrid anchor 可作为表尾简化行或 Supplement。

---

# 5. 正文 / 补充材料划分建议

## 正文必须保留

1. PA5C–F：finite-window / off-grid recoverability mechanism；
2. PA5G–H-R1：local bias → branch competition；
3. PA5J-A / B2：reliability state + complementarity；
4. B3-R1 / B3-R2：公平性与共享 policy；
5. EXP010-B：practical closure；
6. EXP010-B-R1：upstream-\(\beta\) ownership；
7. EXP010-C DenseRisk：noise validity boundary；
8. OriginalGrid noise anchor：只保留压缩结论。

## 补充材料优先

- PA5E / E-R1 的 peak semantics / tie audit；
- 早期 normalized Pilot-A3/A4；
- 完整 indicator ranking；
- B0 / B1 大量预算 sweep；
- B3-R1 的全部 49,173 comparator endpoints；
- B3-R2 全部 216 shared configurations；
- oracle exact / oracle notch 完整统计；
- OriginalGrid 四个 SNR 的完整长表；
- seed ledger / Wilson CI 细节；
- smoke implementation；
- implementation self-tests。

---

# 6. 不再新增的实验

从本矩阵冻结后，第一篇论文默认**不再新增**：

- 新 reliability feature；
- Neighbor-5 / Neighbor-K 扩展；
- 新 fusion architecture；
- learned gate；
- SNR-adaptive threshold；
- aperture-specific policy；
- 更多 SNR 点；
- 更多 MC；
- colored Gaussian noise；
- K-distribution / compound-Gaussian sea clutter；
- SCR sweep；
- 新的 deterministic stress family。

除非后续写作过程中发现：

> 某个“核心论点”缺少必要证据，而不是“图还不够漂亮”。

否则不重新打开实验设计。

---

# 7. 当前仍未完成，但不属于本篇核心 Claim 的内容

## SAR-Level Translation / Engineering Validation

目前仍不能正式宣称：

\[
\text{branch reliability gain}
\rightarrow
\text{真实 SAR 图像级重聚焦增益}
\]

已经完成。

尚未系统验证：

- weak structure preservation；
- image entropy / sharpness；
- ghost / false structure；
- motion-parameter accuracy；
- end-to-end image-level computation advantage；
- public / real SAR scene applicability；
- local sea clutter / SCR 下的表现。

因此建议把这些内容定位为：

> **后续 SAR-level validation / 下一阶段工作**

而不是继续塞进当前 EXP009–EXP010 论文主线。

---

# 8. 当前论文推荐结构

```text
1. Introduction
   ├─ 复杂运动舰船 SAR sequential refocusing 背景
   ├─ multi-component + finite-window removal 的潜在问题
   ├─ 现有方法主要关注“如何重聚焦”，较少研究 failure reliability
   └─ 本文两项贡献

2. Signal Model and Failure Mechanism
   ├─ MC-LFM model
   ├─ finite-window / off-grid removal
   ├─ leakage–damage decomposition
   ├─ recoverability floor
   └─ coherent mixture perturbation and branch competition

3. Reliability-Aware Selective Recovery
   ├─ cheap G0
   ├─ Refined-LR reliability state
   ├─ residual FiveBin complementarity
   ├─ staged allocation
   └─ Neighbor-3 conditional recovery

4. Experimental Protocol
   ├─ Wang/Xu physical anchoring
   ├─ Paper1s / BeamDerived
   ├─ OriginalGrid / DenseRisk
   ├─ practical non-oracle chain
   ├─ frozen metrics / thresholds
   └─ AWGN protocol

5. Results
   5.1 Failure-mechanism validation
   5.2 Reliability-state and Pareto validation
   5.3 Practical non-oracle closure
   5.4 Upstream-β ownership audit
   5.5 Additive-noise validity boundary

6. Discussion
   ├─ branch correctness ≠ weak recovery sufficiency
   ├─ Neighbor-3 conditional validity
   ├─ batch scheduler vs deployable threshold
   ├─ AWGN ≠ sea clutter
   └─ SAR-level translation remains future work

7. Conclusion
```

---

# 9. 最终收敛判断

当前论文已经可以压缩为：

\[
\boxed{
\text{两个核心研究点}
+
\text{一条完整机制链}
+
\text{一个 practical reliability method}
+
\text{明确的 validity boundary}
}
\]

而不再是：

> “做了很多实验，然后从中挑若干结果写论文。”

当前阶段正式进入：

\[
\boxed{
\text{Paper Architecture Freeze}
\rightarrow
\text{Figure / Table Selection}
\rightarrow
\text{Manuscript Drafting}
}
\]

