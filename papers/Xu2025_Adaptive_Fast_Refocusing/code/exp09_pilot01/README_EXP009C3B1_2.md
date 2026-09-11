# EXP009-C3-B1.2 — Mechanism-Informed Realization Observable Audit

## 1. 这一轮为什么必要

C3-B1.1 已经把问题压缩得非常清楚：

```text
physical state
    -> 稳定、可重复
```

但是：

```text
prominence + entropy
    -> 只有较弱的 within-state realization information
```

因此现在不应该继续增加 EMA、fusion heuristic 或复杂分类器。

真正要解决的问题是：

> **同一个 physical state 下，究竟还有哪些 signal-level observables 能解释“为什么这一发 fallback beneficial / harmful”？**

C3-B1.2 因此从：

```text
policy design
```

暂时退回：

```text
information discovery
```

这是刻意的。

---

# 2. 与 C3-B1 / C3-B1.1 的连续性

本实验保持：

```text
N = 512
q_ref = 1.44
mu_scale = 180
q_weak = 1.470

A_strong = 1
f_strong = 12.3
f_weak   = 30.3

phi_strong = 0.20
phi_weak   = -0.70

SNR = 3 dB

notch halfwidth = 1 bin

q search:
1.380 : 0.001 : 1.560

tau_q = 0.003
```

连续 azimuth trajectory、Smooth / Abrupt 参数变化、TRAIN / TEST 数量和随机 seed 也与 C3-B1 完全一致。

因此理论上：

```text
Cheap success
Fallback success
Beneficial
Harmful
```

应该与 C3-B1 原始 experiment 完全一致。

如果标准 C3-B1 result folder 存在，程序会自动检查 label mismatch rate。

理想情况：

```text
all mismatch rates = 0
```

---

# 3. 为什么需要重新运行 signal-level

C3-B1 原始 trial bank 只保存了：

```text
cheap prominence
cheap entropy
cheap q_hat
fallback q_hat
outcome labels
```

但 C3-B1.2 需要：

- 完整 q-search curve morphology；
- q_strong 附近 response；
- q_strong-dechirped residual spectrum；
- sub-aperture q-search consistency。

这些量无法从旧 CSV 反推。

因此本轮必须重新生成同一批 signal realizations。

---

# 4. Controlled boundary

与 C3-B1 一样：

\[
q_s(k)
\]

仍然是 oracle / known。

因此本轮只研究：

\[
\boxed{
\text{weak-stage realization observability}
}
\]

不混入 dominant-q tracking error。

如果这一轮找到真正有效的 realization observables，再进入：

```text
practical q_strong tracking
```

会更稳妥。

---

# 5. 最重要的评价量：Within-line AUC

固定某条 azimuth line \(k\)：

```text
A_w/A_s 固定
q_s-q_w 固定
state prior 固定
```

只让 AWGN realization 改变。

此时计算：

\[
AUC_k.
\]

然后用：

\[
N_{+,k}N_{-,k}
\]

做 pair-count weighting：

\[
\boxed{
AUC_{\rm within-line}
}
\]

因此：

> **任何稳定高于 0.5 的结果，都意味着真正的 realization-level information，而不是 state information。**

---

# 6. C3-B1.1 baseline

上一轮已经得到：

## Beneficial

Smooth：

\[
AUC_{\rm within}\approx0.537
\]

Abrupt：

\[
AUC_{\rm within}\approx0.523
\]

## Harmful

Smooth：

\[
AUC_{\rm within}\approx0.528
\]

Abrupt：

\[
AUC_{\rm within}\approx0.583
\]

所以 C3-B1.2 的目标不是证明：

```text
AUC > 0.5
```

这么宽松。

而是判断 richer mechanism observables 能否把：

```text
Beneficial within-line AUC
```

推到：

\[
\sim0.58
\]

甚至：

\[
>0.60.
\]

对 Harmful，如果能稳定：

\[
>0.62
\]

则非常支持：

> **harm-aware fallback gating**

---

# 7. Observable Family A — q-curve morphology

当前 prominence / entropy 只把整条 weak-search curve 压成两个 scalar。

C3-B1.2 额外保留：

## 7.1 Competing peak ratio

先排除 dominant peak 周围：

```text
±3 q-grid bins
```

再寻找真正的第二 competing peak。

定义：

\[
r_{21}
=
\frac{P_2}{P_1}.
\]

同时：

\[
m_{12}
=
\frac{P_1-P_2}{P_1}.
\]

---

## 7.2 Top-2 q separation

\[
\Delta q_{12}
=
|q_1-q_2|.
\]

它区分：

```text
同一主瓣内部小抖动
```

和：

```text
真正远距离 competing mode
```

---

## 7.3 Half-maximum q width

从 dominant peak 左右连续搜索：

\[
M(q)\ge0.5M_{\max}.
\]

得到：

\[
W_{50}.
\]

宽 peak 往往意味着：

```text
weak-q estimate 更不稳定
```

---

## 7.4 Local curvature

\[
\kappa
=
\frac{
2M_i-M_{i-1}-M_{i+1}
}{
M_i
}.
\]

它直接描述 peak sharpness。

---

## 7.5 Local asymmetry

比较 peak 左右局部能量：

\[
A_{\rm LR}
=
\frac{|E_L-E_R|}{E_L+E_R}.
\]

它可能反映 coherent residual 对 weak peak 的单侧拉动。

---

## 7.6 Robust peak z-score

\[
Z_{\rm peak}
=
\frac{
P_1-\operatorname{median}(M)
}{
1.4826\,MAD(M)
}.
\]

相比 prominence，它对整体 curve floor 与长尾结构更敏感。

---

# 8. Observable Family B — strong residual / weak competition

A3/A4/B 已经告诉我们：

> strong residual 的影响不是单纯 residual energy，而和 coherent interference geometry 有关。

因此这里直接利用已知 / tracked：

\[
q_s
\]

作为 reference。

---

## 8.1 Response at q_strong

\[
R_s
=
\frac{
M(q_s)
}{
M_{\max}
}.
\]

如果 weak search curve 在 strong q 附近仍然保持较强 response，

说明：

```text
strong residual competition
```

仍然明显。

---

## 8.2 q_strong neighborhood fraction

对：

```text
q_s ± 3 grid bins
```

计算：

\[
E_{q_s}
=
\frac{
\sum_{\mathcal N(q_s)}M(q)
}{
\sum_q M(q)
}.
\]

---

## 8.3 Dominant peak to q_strong distance

\[
|q_{\rm peak}-q_s|.
\]

---

# 9. q_strong-dechirped residual spectrum

对 Cheap residual：

\[
x_c
\]

使用：

\[
q_s
\]

dechirp：

\[
z_s(t)
=
x_c(t)
e^{-j\pi\mu(q_s)t^2}.
\]

然后 FFT。

记录：

```text
strong_spec_peak_fraction
strong_spec_local_fraction
strong_spec_entropy
```

注意：

> `strong_spec_peak_fraction` 不是声称最大 spectral mode 一定是真实 strong residual。

它只是：

> 在 strong-q dechirped domain 中 residual 的 concentration observable。

它的优势是 practical：

```text
不需要知道 q_weak
```

---

# 10. Observable Family C — Sub-aperture stability

把完整 aperture 分成：

```text
4 contiguous sub-apertures
```

每个 sub-aperture 独立 weak-q search：

\[
\hat q_1,\ldots,\hat q_4.
\]

记录：

## 10.1 q std

\[
\frac{\operatorname{std}(\hat q_m)}{\tau_q}
\]

---

## 10.2 q range

\[
\frac{
\max\hat q_m-\min\hat q_m
}{
\tau_q
}
\]

---

## 10.3 consensus fraction

统计：

\[
|\hat q_m-\hat q_{\rm full}|
\le\tau_q
\]

的 sub-aperture 比例。

---

## 10.4 prominence CV

\[
CV_p
=
\frac{
std(p_m)
}{
mean(p_m)
}.
\]

这组量直接回答：

> 当前 weak-search evidence 在 aperture 内是不是稳定。

---

# 11. Single-feature audit

每个 feature 分别报告：

```text
pooled Beneficial AUC
within-line Beneficial AUC

pooled Harmful AUC
within-line Harmful AUC
```

方向：

```text
feature 越大越危险
or
feature 越小越危险
```

只由 TRAIN AUC 决定。

TEST 不参与方向选择。

这是为了避免：

> 在 TEST 上偷偷把 AUC 翻到 >0.5。

---

# 12. Observable-group audit

所有 group 使用完全相同的：

```text
two-headed ridge logistic
```

结构：

\[
p_B=P(Beneficial|X)
\]

\[
p_H=P(Harmful|X)
\]

\[
V=p_B-p_H.
\]

固定：

```text
ridge lambda = 0.10
```

不做复杂 hyperparameter tuning。

---

# 13. Group definitions

## StateOnly

```text
state prior
```

---

## BaselinePE

```text
prominence
entropy
```

---

## StateBaseline

```text
state + prominence + entropy
```

---

## MorphologyOnly

```text
BaselinePE
+
second/first peak
peak margin
top-2 q separation
width50
curvature
asymmetry
robust z
```

---

## StrongCompetitionOnly

```text
BaselinePE
+
q_s response
q_s neighborhood fraction
peak-to-q_s distance
strong-q spectrum peak fraction
strong-q spectrum local fraction
strong-q spectrum entropy
```

---

## SubapertureOnly

```text
BaselinePE
+
sub-ap q std
sub-ap q range
sub-ap consensus
sub-ap prominence CV
```

---

## AllObservable

所有 realization features。

---

每一类同时有：

```text
State + feature group
```

版本。

最重要的是：

```text
StateAll
```

---

# 14. 为什么这轮 Beneficial / Harmful 分开

C3-B1.1 已经发现：

Abrupt：

\[
AUC^{within}_{H}
\approx0.583
\]

明显高于：

\[
AUC^{within}_{B}
\approx0.523.
\]

这提示 adaptive fallback 可能是 asymmetric decision：

```text
benefit opportunity
+
harm avoidance
```

而不是一个简单的：

```text
fallback / no fallback
```

binary classifier。

因此 C3-B1.2 对 B / H 全部分开审计。

---

# 15. 关键输出

## Single features

```text
single_feature_audit.csv
```

首先看：

```text
within_line_auc_beneficial
within_line_auc_harmful
```

---

## Group models

```text
group_information_audit.csv
```

---

## State-conditioned behavior

```text
state_bin_group_audit.csv
```

判断：

> 某组 observable 是否只在某些 state 区间有效。

---

## Policy

```text
mechanism_observable_budget_curves.csv
reported_budget_points.csv
```

---

## Oracle gap

```text
oracle_gap_capture.csv
```

---

## Final compact judgment

```text
decision_summary.csv
summary.txt
```

---

# 16. 主要图

```text
fig01_top_single_withinB.png
fig02_top_single_withinH.png

fig03_group_withinB.png
fig04_group_withinH.png

fig05_smooth_quality_cost.png
fig06_abrupt_quality_cost.png

fig07_policy_comparison_25pct.png
fig08_oracle_gap_capture_25pct.png

fig09_smooth_state_bin_B.png
fig10_abrupt_state_bin_B.png

fig11_smooth_state_bin_H.png
fig12_abrupt_state_bin_H.png

fig13_smooth_peak_competition_plane.png
fig14_abrupt_subaperture_plane.png
```

---

# 17. 三种最关键结果

## Strong GO — 找到了新的 realization information

如果例如：

```text
Morphology / StrongCompetition / Subaperture
```

其中一组稳定满足：

\[
AUC^{within}_B\gtrsim0.58
\]

并且明显高于 BaselinePE：

那么：

> 新 observable family 真正解释了同一 state 下的 trial fate。

如果：

\[
State+Group
\]

进一步提高 25% budget recovery / Oracle-gap capture，

这组 feature 就值得进入方法设计。

---

## Harm-aware GO

如果 Beneficial 仍只有：

\[
\sim0.54
\]

但 Harmful 能达到：

\[
>0.62,
\]

则说明：

> 当前 observable 更适合“避免错误 fallback”，而不是直接预测“fallback 一定能救”。

此时下一步应做：

```text
opportunity gate
    +
harm veto
```

双通道策略。

---

## NO-GO — richer observable 仍无信息

如果所有 group：

\[
AUC^{within}_B
\approx0.52\sim0.54
\]

而 Harmful 也不提升，

则可以比较明确地判断：

> 当前 q-curve scalar morphology / sub-ap stability 仍不足以解释 TrialOracle gap。

这时下一步应该进一步进入：

```text
complex residual waveform representation
```

甚至才考虑：

```text
small learned representation
```

而不是继续手工融合现有 scalar。

---

# 18. 关于 AI 的位置

C3-B1.2 仍然不直接上 AI。

只有出现以下情况之一时，AI 才真正“有任务”：

### 情况 1

多组 observable 都有独立信息，但线性组合无法充分融合。

### 情况 2

state-bin 结果显示非常明显的 nonlinear state dependence。

### 情况 3

单个 scalar 不够，但完整 residual curve / sub-aperture representation 明显具有结构。

此时再做：

```text
small MLP
1-D CNN on q-curve
lightweight state-conditioned gating
```

会比直接上大模型更有研究逻辑。

---

# 19. 推荐目录

```text
papers/
└── Xu2025_Adaptive_Fast_Refocusing/
    ├── code/
    │   └── exp09_pilot01/
    │       ├── exp09c3b1_2_mechanism_observable_audit.m
    │       └── config_exp09c3b1_2.m
    └── results/
        └── exp09_pilot01/
            └── exp09c3b1_2_mechanism_observable_audit/
```

---

# 20. 运行

```matlab
cd <...>/Xu2025_Adaptive_Fast_Refocusing/code/exp09_pilot01

results = exp09c3b1_2_mechanism_observable_audit;
```

---

# 21. 计算量

这一轮需要重新运行真实 signal-level chain，而且增加了：

```text
4 x sub-aperture q-search
q_strong-dechirped spectral FFT
rich q-curve morphology extraction
```

所以预计比 C3-B1 更慢。

但：

```text
4 sub-apertures
```

总样本长度仍约等于一个 full aperture，因此主要额外代价大约是：

```text
~1 additional full-q-search equivalent
+
small diagnostics
```

而不是简单变成 4 倍。

---

# 22. 运行后优先发给我的内容

最优先：

```text
summary.txt
decision_summary.csv
single_feature_audit.csv
group_information_audit.csv
reported_budget_points.csv
oracle_gap_capture.csv
```

图片优先：

```text
fig01_top_single_withinB.png
fig02_top_single_withinH.png

fig03_group_withinB.png
fig04_group_withinH.png

fig07_policy_comparison_25pct.png
fig08_oracle_gap_capture_25pct.png

fig09_smooth_state_bin_B.png
fig10_abrupt_state_bin_B.png

fig11_smooth_state_bin_H.png
fig12_abrupt_state_bin_H.png
```

这轮最重要的不是“最终 recovery 又涨了多少”，而是：

\[
\boxed{
\text{到底哪一种 signal evidence 真正在固定 physical state 后仍然有信息？}
}
\]
