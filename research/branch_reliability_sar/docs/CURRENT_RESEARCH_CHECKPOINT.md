# Current Research Checkpoint
## 复杂运动舰船 SAR 非聚焦 —— Branch Reliability 线阶段归档

> 本文档用于新实验对话或后续研究阶段快速接续。
>
> 当前节点：Controlled SAR + OpenSARShip + FAIR-CSAR branch occurrence + R2A + GAP01 已完成。

---

## 1. 当前最重要的研究判断

原始研究假设：

```text
真实严重失焦舰船中可能频繁出现 discrete-first local branch failure
        ↓
Neighbor-3 可以低成本恢复
        ↓
reliability-aware compute allocation
```

现在需要修正为：

```text
local Neighbor-3 mechanism
在 model-matched synthetic regime 中成立

但

真实严重失焦舰船中的 observed branch failures
主要表现为 remote-basin competition
```

同时：

```text
大部分 accepted real states 是 SAFE
```

且：

```text
G0 -> Global branch substitution
只产生有限且指标不一致的整体聚焦收益
```

因此 branch failure：

```text
真实存在
+
具有局部空间因果性
```

但当前证据不支持：

```text
branch failure 是 severe ship defocus 的主要来源
```

---

## 2. 已经完成的闭环

```text
Synthetic branch mechanism
        ↓
Controlled SAR translation
        ↓
OpenSARShip applicability audit
        ↓
FAIR R0 model/component gate
        ↓
R1 real occurrence
        ↓
R1C failure geometry
        ↓
Candidate C independent replication
        ↓
R2A image-level contribution
        ↓
GAP01 real-vs-synthetic diagnosis
```

---

## 3. GAP01 后的优先假设排序

### H1 — Implementation / parameter-range mismatch

当前优先级：

```text
LOW
```

原因：

```text
222 / 222
```

Candidate-B real-state parameter-support exact clones 均由 G0 / N3 正确恢复。

---

### H2 — Small upstream p_beta mismatch

当前优先级：

```text
MEDIUM-LOW as dominant explanation
```

原因：

```text
p_beta +/- 0.04
```

局部 relaxation 只带来很小 median coherence gain。

但 boundary-hit 非零，因此不能完全排除更大尺度的 FM-rate mismatch。

---

### H3 — Broader real-data model / mixture gap

当前优先级：

```text
HIGH
```

候选来源：

```text
higher-order / nonlinear phase
multi-component mixture
sequential-removal residual
spatially variant defocus
range-cell / scatterer mixing
clutter / sidelobe contamination
```

当前尚不能唯一归因。

---

## 4. 下一阶段工作原则

下一阶段不要直接继续写新算法。

应先把最新文献调研用于：

```text
Mechanism-oriented Literature Gate
```

逐项回答：

1. 哪些 candidate mechanisms 已有成熟解决方案？
2. 哪些机制与 FAIR-CSAR 中观察到的：
   - low single-LFM coherence；
   - broad/multi-ridge J(p_beta,nu)；
   - remote basin competition；
   - severe visual defocus but mostly SAFE states；
   相一致？
3. 哪个机制仍有：
   ```text
   real-data evidence
   +
   scientific gap
   +
   controllable experiment
   ```
4. 哪个机制最适合作为下一篇小论文或 Paper B 的主问题？

---

## 5. Branch 线 Stop Rule

除非新的文献或新机制明确要求，否则不要继续：

```text
N5 / N7
Top-K rescue
larger local search windows
new branch reliability thresholds
new branch feature engineering
```

当前 branch 线的价值已经从：

```text
“方法必须在真实数据中成功”
```

转变为：

```text
mechanism validation
+
applicability boundary
+
negative real-data evidence
+
model-gap discovery
```

---

## 6. 工程状态

有效 FAIR R2A helper：

```text
functions/fair_csar/refocus_mclfm_branch_native_clean.m
```

Deprecated：

```text
functions/fair_csar/refocus_mc_lfm_clean_branch_locked.m
```

原因：

```text
错误地将 R1 dechirped-tone nu
映射到 finite direct-FrFT u grid
```

后续不要继续调用。

---

## 7. 新对话建议读取顺序

为了快速接续，先读：

```text
1. README.md
2. docs/CURRENT_RESEARCH_CHECKPOINT.md
3. docs/REAL_DATA_VALIDATION_SUMMARY.md
4. docs/EXPERIMENT_INDEX.md
```

如果新研究问题涉及具体实验，再按需读取：

```text
EXP-R-GAP01-Real-vs-Synthetic-Gap-Audit.md
EXP-R-R2A-Branch-Contribution-to-Image-Defocus.md
EXP-R-R1C-Failure-Geometry-Component-Validity.md
```

以及对应代码 / feedback。
