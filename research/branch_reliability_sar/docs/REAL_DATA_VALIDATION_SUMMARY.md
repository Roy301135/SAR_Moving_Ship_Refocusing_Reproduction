# Real-Data Validation Summary
## OpenSARShip → FAIR-CSAR Branch Reliability and Model-Gap Checkpoint

本文件总结从 OpenSARShip 到 FAIR-CSAR 的真实数据实验链，重点记录：

```text
为什么换数据集
哪些真实机制得到验证
哪些原始预期没有成立
当前 model-gap 指向哪里
```

---

# 1. OpenSARShip

## 1.1 目标

OpenSARShip 最初用于回答：

```text
公开真实复数 SAR ship chip
是否可以作为 branch mechanism 的真实验证入口？
```

## 1.2 R0A — Complex SLC Interface

验证：

```text
complex SLC interface PASS
```

冻结约定：

```text
MATLAB row    = azimuth
MATLAB column = range
g(:,n)        = one azimuth history at range column n
```

## 1.3 R0B / R0C — LFM Compatibility

在测试目标中：

- target single-LFM coherence 较弱；
- target/background separation 不足以支撑 source-aligned MC-LFM validation；
- cross-ship 复现得到相近结论。

## 1.4 决策

因此停止：

```text
继续在 OpenSARShip 中寻找 branch rescue
```

转向 FAIR-CSAR。

这一步是：

```text
dataset applicability decision
```

而不是为了获得正结果的事后调参。

---

# 2. FAIR-CSAR Candidate B

Candidate B：

```text
GF3_KAS_SL_028685_E139.7_N35.5_20220120_L1A_HH_L10000000001_00000_16050
```

标签：

```text
Motion_Defocusing_Ship
```

---

# 3. R0 — Real Component Validity

## 3.1 Positive Control

初版 fractional-autocorrelation scalar metric 未能恢复已知 synthetic LFM order。

因此该 diagnostic 被直接否决。

之后采用 corrected Xu Eq.(31)-consistent FrAc-energy objective。

修正后：

```text
known synthetic LFM order
=
recovered order
```

通过。

---

## 3.2 Phase Sensitivity

对真实 target line 做 amplitude-preserving phase permutation。

结果显示真实数据在 non-p=1 order 上存在显著超过 surrogate 的 phase-coherent structure。

---

## 3.3 Component Consistency

Candidate B 中存在跨相邻 range columns 的 recurrent LFM-compatible component family。

这支持：

```text
real phase-coherent LFM-compatible structure exists
```

但不能证明：

```text
whole ship signal is exact MC-LFM
```

---

# 4. R1 — Real Branch Occurrence

## 4.1 R1A

8 个最可信 recurrent component states：

```text
8 / 8 SAFE
0 N3 rescue
```

说明：

```text
visible defocus != automatic branch failure
```

---

## 4.2 R1B

全冻结 component pool：

```text
222 valid component states

SAFE                      203
G0_FAIL_N3_RESCUE           0
N3_COVERAGE_MISS            19
PERSISTENT_WITHIN_COVERAGE   0
```

即：

```text
19 / 222 = 8.56%
```

non-SAFE。

结论：

```text
real branch failure exists
```

---

## 4.3 R1C

19 个 failure 中：

```text
11 / 19
```

满足 recurrent credibility。

但：

```text
0 / 19
```

global basin 位于 frozen N3 coverage 中。

因此 real branch failure 主要表现为：

```text
remote-basin competition
```

而不是：

```text
local Neighbor-3-rescuable failure
```

---

# 5. Candidate C Independent Replication

Candidate C：

```text
GF3_KAS_SL_028368_E139.7_N35.5_20211229_L1A_HH_L10000000001_00000_04491
```

冻结 Candidate-B pipeline。

结果：

```text
69 valid states

SAFE               67
N3_COVERAGE_MISS    2
G0_FAIL_N3_RESCUE   0
```

两个 failure：

```text
0 / 2 recurrent credible
```

结论：

- remote failure 可以在独立真实目标出现；
- Candidate B 的 recurrent failure population 未强复现；
- 两个 frozen candidates 中都没有 natural frozen-N3 rescue。

---

# 6. R2A — Branch Contribution

R2A 在相同 accepted component model 下比较：

```text
G0 branch
vs
evaluation-only Global branch
```

结果：

```text
branch-induced changes
几乎完全位于 R1 failure columns
```

说明 R1 branch taxonomy 与 image-level branch substitution effect 一致。

但整体指标：

```text
entropy             小幅变差
azimuth W80          小幅改善
peak concentration   小幅变差
```

因此：

```text
branch failure
=
real + spatially causal
```

但：

```text
remaining branch headroom
=
limited / mixed
```

当前证据不支持将 severe ship defocus 主要归因于 branch selection。

---

# 7. GAP01 — Real-vs-Synthetic Gap

## 7.1 Parameter-Support Closure

Candidate B 的全部：

```text
222
```

个真实 `(p_beta, global_nu)` states 被生成 exact quadratic-LFM clones。

结果：

```text
G0 truth match       222 / 222
N3 truth match       222 / 222

max G0 error         ~9.87e-7 bin
max N3 error         ~9.03e-7 bin
max Global error     ~7.17e-9 bin
```

因此基本排除：

```text
implementation only works for artificial synthetic parameter ranges
```

---

## 7.2 Small Local p_beta Relaxation

真实 line：

```text
median frozen atom coherence        ~0.02994
median relaxed atom coherence       ~0.03587
median local-p gain                 ~0.00360
p90 local-p gain                    ~0.01156
gain >= 0.02                        ~2.25%
```

因此：

```text
small p_beta estimation bias
```

不足以解释 real-vs-synthetic gap。

但 boundary-hit 非零，因此不完全排除更大的 FM-rate mismatch。

---

## 7.3 Joint Objective Geometry

Exact synthetic clones：

```text
clean + structured + localized
```

Real FAIR states：

```text
multiple ridges
remote competing basins
broad / speckled objective geometry
```

因此当前最有力的新认识是：

```text
same parameter support
+
same branch implementation
```

并不能让真实信号表现成 synthetic clone。

真正变化的是：

```text
signal/model regime
```

---

# 8. 已验证内容

```text
1. model-matched local branch failure / recovery mechanism 成立；

2. real FAIR data 中存在 LFM-compatible phase-coherent structure；

3. real branch failure 存在；

4. Candidate-B failures 主要是 remote-basin coverage miss；

5. branch substitution 影响正确的 failure locations；

6. R1 implementation 对全部 observed real-state parameter support
   在 exact clones 上闭环。
```

---

# 9. 与原预期不符

```text
1. 未观察到 natural local N3 rescue；

2. severe defocus != frequent branch failure；

3. Candidate-B recurrent failures 未在 Candidate C 强复现；

4. Global branch substitution 没有显著统一改善整体聚焦；

5. small p_beta correction 无法解释 synthetic-real gap。
```

---

# 10. 当前最可能的 Research Gap

目前不能唯一断言：

```text
higher-order phase
```

就是答案。

因为 real range-column 的低 single-LFM coherence 也可能来自：

```text
multi-component mixture
spatial variation
range-cell mixing
clutter / sidelobe contamination
sequential-removal residual
```

因此下一步应该是：

```text
Literature Gate
        ↓
mechanism-specific diagnostic
```

而不是直接扩张 branch method。

---

# 11. 当前阶段结论

最稳妥的当前表述：

```text
The local branch-recovery mechanism is valid in its model-matched regime.

Real motion-defocused FAIR-CSAR data do contain branch failures, but the
observed failures are predominantly remote-basin events outside the frozen
Neighbor-3 coverage.

Moreover, the real data exhibit a substantially more complex objective
geometry than exact quadratic-LFM clones over the same parameter support.

The remaining severe defocus is therefore more plausibly associated with a
broader real-data signal/model/mixing gap than with simple local branch
selection alone.
```
