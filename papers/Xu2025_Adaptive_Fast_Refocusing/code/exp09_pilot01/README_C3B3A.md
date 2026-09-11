# EXP009-C3-B3A — Rescueability Failure-Mode Decomposition

## 1. 本轮问题

C3-B2 已经把 Beneficial 拆成：

```text
Beneficial = CheapFailure AND FallbackSuccess
```

并发现：

```text
CheapFailure:
    Smooth within-line AUC ≈ 0.610
    Abrupt within-line AUC ≈ 0.655

Rescueability:
    Smooth within-line AUC ≈ 0.519
    Abrupt within-line AUC ≈ 0.535
```

所以当前真正的瓶颈已经不再是：

```text
“能不能看出 Cheap 可能错了？”
```

而是：

```text
“Cheap 已经错了以后，为什么 fallback 有时能救、有时救不了？”
```

C3-B3A 因此不继续堆 classifier，而是做 **failure-mode decomposition**。

---

# 2. 一个重要的实验边界

当前 C3 控制链中：

```text
fallback
=
off-grid parametric strong refit
+
full weak-q search
```

而：

```text
FallbackSuccess
=
|q_hat_fallback - q_weak| <= tau_q
```

所以当前控制实验里**不存在**：

```text
q 已经选对
→ 后续 refocusing 仍然失败
```

这一额外阶段。

也就是说，C3-B3A 的问题必须更精确地写成：

> **为什么 fallback residual 的 q-concentration 全局最大值会离开真实 weak-q basin？**

这比泛泛地说“fallback 为什么失败”更准确。

---

# 3. Failure-mode taxonomy

只研究：

```text
CheapFailure trials
```

然后分成五类。

## Success

```text
fallback q winner
落在
|q-q_weak| <= tau_q
```

---

## NearShift

fallback 失败，但：

```text
global winner
只是在 q_weak 附近发生小偏移
```

默认：

```text
tau_q < |q_hat-q_weak| <= 0.010
```

意义：

> weak basin 基本还在，但峰位置有偏移。

如果这一类很多，后续可能优先考虑：

- local refinement；
- second-stage fine search；
- uncertainty-aware acceptance。

---

## PeakCompetition

真实 weak-q basin 内**仍存在 local peak**，但：

```text
另一个 peak
>
true weak peak
```

所以全局 top-1 选错。

意义：

> weak component 并没有消失，而是输掉了峰竞争。

如果这一类占主导，下一步更应该研究：

```text
multi-hypothesis candidate retention
local verification
top-K -> cheap verification
```

而不一定继续强化 CLEAN。

---

## BasinCollapse

在真实 weak-q basin 内：

```text
连 local maximum 都没有形成
```

意义：

> weak-q 结构本身已经被 residual geometry / noise / operator distortion 破坏。

如果这一类占主导，下一步应该研究：

```text
strong residual leakage
weak attenuation
coherent cross-term
noise perturbation
refit operator
```

而不是 selection strategy。

---

## BoundaryFalsePeak

global winner 落到 q 搜索区间边界附近。

意义：

> 搜索曲线被远端错误峰控制，需单独识别以避免把 boundary artifact 混进普通 peak competition。

---

# 4. 为什么要加入 residual exact decomposition

Fallback 的 parametric refit 从 noisy mixture 中估计一个 strong atom。

C3-B3A 固定这个**同一个 fitted atom**，然后分别把投影算子作用到：

```text
strong
weak
noise
```

得到：

\[
r = e_s + e_w + e_n
\]

其中：

- `e_s`：strong residual；
- `e_w`：weak component 经 refit operator 后的剩余；
- `e_n`：noise 经同一 operator 后的剩余。

代码同时计算 consistency：

```text
e_s + e_w + e_n
```

必须与直接对 mixture 做 refit 得到的 residual 一致。

这样我们就能定量区分：

```text
strong 没去干净
vs
weak 被 refit 误伤
vs
noise 扰动
vs
coherent cross-term
```

---

# 5. 核心机制指标

## Residual strong retention

\[
\eta_s
=
\frac{\|e_s\|^2}{\|s_s\|^2}
\]

越大：

> strong 去除越不充分。

---

## Weak retention

\[
\eta_w
=
\frac{\|e_w\|^2}{\|s_w\|^2}
\]

越小：

> fallback refit 对 weak component 误伤越重。

---

## Residual strong / weak ratio

\[
\Lambda_{s/w}
=
\frac{\|e_s\|^2}{\|e_w\|^2}
\]

这比单纯看 strong residual energy 更直接：

> fallback residual 中 strong contamination 相对于 weak 到底有多严重？

---

## Residual noise / weak ratio

\[
\Lambda_{n/w}
=
\frac{\|e_n\|^2}{\|e_w\|^2}
\]

---

## Strong–weak coherent cross-term

\[
C_{sw}
=
\frac{2\Re\langle e_w,e_s\rangle}
{\|e_w\|^2}
\]

这与我们 A4 里已经验证过的“coherent perturbation 改变 q-peak geometry”直接衔接。

---

## Noise–weak coherent cross-term

\[
C_{wn}
=
\frac{2\Re\langle e_w,e_n\rangle}
{\|e_w\|^2}
\]

它用来判断：

> 同一物理状态下不同 Monte Carlo realization 的 rescueability 差异，是否主要来自 coherent noise perturbation。

---

# 6. q-landscape anatomy

每个 CheapFailure trial 都保存：

```text
global_score
true_basin_score

true_to_global_ratio

true_basin_localmax
true_peak_rank

competitor_q
competitor_distance

curve_entropy
global_prominence
true_curvature_norm
num_local_peaks
```

其中最重要的是：

## true_to_global_ratio

\[
R_q
=
\frac{
\max_{|q-q_w|\le\tau_q} C(q)
}{
\max_q C(q)
}
\]

若：

```text
R_q ≈ 1
```

但 q_hat 仍然失败：

> 更像 NearShift / close competition。

若：

```text
R_q << 1
```

> true weak basin 已经明显失去竞争力。

---

## true_peak_rank

如果真实 weak basin 中有 local peak，就看它在所有 local peaks 中排第几：

```text
rank = 2
→ 一个 competitor 压过它

rank >= 3
→ 多峰竞争严重

no true local peak
→ BasinCollapse
```

---

# 7. 本轮不做什么

C3-B3A **不做**：

- MLP；
- Random Forest；
- Deep Learning；
- 新 computation policy；
- 新 adaptive fallback。

因为现在还没有回答：

> Rescueability failure 的主要物理类型到底是什么。

先把 failure mode 拆清楚，再决定算法。

---

# 8. 合理预期

## Case A — PeakCompetition 占主导

这是非常有价值的结果。

说明：

```text
true weak component 仍然存在
只是 top-1 selection 失败
```

下一步建议：

> **C3-B3B：Top-K / multi-hypothesis low-cost verification**

---

## Case B — BasinCollapse 占主导

说明：

```text
fallback strong refit 后
true weak basin 本身就被破坏
```

下一步建议：

> **C3-B3B：Residual Geometry / Refit-Operator Rescueability**

重点研究：

- strong leakage；
- weak attenuation；
- coherent cross-term；
- operator width / model mismatch。

---

## Case C — NearShift 占主导

说明：

> fallback 方法大方向是对的，只是 q peak 产生系统性局部偏移。

下一步可以试：

- coarse-to-fine；
- local interpolation；
- soft top-K；
- confidence radius。

---

## Case D — residual geometry 很强，但 physical state 很弱

这是一个很重要的结果：

> Rescueability 是由“本次 realization 的 residual geometry”生成的，而不是只由宏观 physical state 决定。

这时才真正有理由研究：

```text
low-cost residual probe
learned rescueability estimator
轻量 AI / ML
```

因为我们已经知道模型该学的是什么。

---

## Case E — residual geometry 也接近 0.5

这意味着：

> 当前受控 SNR 下的 rescue fate 很可能高度受随机 noise realization 支配。

此时不应强行上更复杂模型。

应该先研究：

- SNR dependence；
- longer aperture；
- multi-look evidence；
- neighborhood aggregation；
- 是否需要改变 fallback 本身。

---

# 9. 文件

```text
exp09c3b3a_rescueability_failure_mode_decomposition.m
config_exp09c3b3a.m
README_C3B3A.md
```

---

# 10. 建议目录

```text
papers/
└── Xu2025_Adaptive_Fast_Refocusing/
    ├── code/
    │   └── exp09_pilot01/
    │       ├── exp09c3b3a_rescueability_failure_mode_decomposition.m
    │       └── config_exp09c3b3a.m
    └── results/
        └── exp09_pilot01/
            └── exp09c3b3a_rescueability_failure_mode_decomposition/
```

---

# 11. 运行

```matlab
cd <...>/Xu2025_Adaptive_Fast_Refocusing/code/exp09_pilot01

results = exp09c3b3a_rescueability_failure_mode_decomposition;
```

这一轮是 standalone signal-level diagnostic，不依赖 C3-B2 CSV。

---

# 12. 重点输出

```text
failure_mode_summary.csv
rescueability_mechanism_audit.csv
residual_anatomy_by_failure_mode.csv
true_basin_peak_rank_summary.csv

state_failure_map_smooth.csv
state_failure_map_abrupt.csv

line_rescueability_smooth.csv
line_rescueability_abrupt.csv

decision_summary.csv
summary.txt
```

---

# 13. 最重要图片

优先看：

```text
fig01_failure_mode_composition.png

fig04_mechanism_auc_audit.png

fig05_true_peak_rank_anatomy.png

fig06_smooth_representative_curves.png
fig07_abrupt_representative_curves.png

fig08_smooth_residual_geometry_plane.png
fig09_abrupt_residual_geometry_plane.png
```

再看：

```text
fig02_smooth_state_rescue_map.png
fig03_abrupt_state_rescue_map.png

fig10_smooth_line_rescueability.png
fig11_abrupt_line_rescueability.png
```

---

# 14. 这一轮真正要得到的一句话

C3-B2 已经告诉我们：

> **我们能部分知道 Cheap 错了，但不知道 fallback 能不能救。**

C3-B3A 要进一步回答：

\[
\boxed{
\text{Fallback 救不了，到底是}
\;
\text{“weak peak 还在但输了竞争”，}
\;
\text{还是“weak peak 本身已经塌了”？}
}
\]

这个答案会直接决定下一轮是研究：

```text
candidate selection
```

还是：

```text
residual / operator redesign
```

这就是 C3-B3A 的唯一主任务。
