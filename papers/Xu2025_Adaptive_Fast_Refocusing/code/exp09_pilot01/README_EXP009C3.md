# EXP009-C3 / Pilot-01 — History-Aware Adaptive Computation

## 1. 为什么现在进入 C3

C2.2 给出了非常关键的诊断：

- `cheap_prominence` pooled Beneficial AUC 约为 0.749；
- `cheap_entropy` pooled Beneficial AUC 约为 0.743；
- 但 cell-centered / within-cell AUC 都迅速下降到约 0.52；
- 说明当前最强 practical observables 的主要作用，是识别一个**持续存在的 latent risk state**，而不是判断某一个独立 realization 的 fate。

同时，State Oracle 在 10% / 25% budget 下只能解释 Oracle selection advantage 的一部分，而不是全部。

因此下一步不再继续搜索新的 single-shot scalar feature，而是问：

> **如果 risk state 在相邻方位线之间具有持续性，能否利用 causal history，把 noisy 的 instantaneous state proxy 稳定下来，从而更合理地分配 fallback computation？**

---

# 2. C3 第一阶段的定位

本实验是：

> **sequence-level bootstrap proof-of-concept**

而不是最终物理 SAR 场景。

它不重新运行 FrAc / CLEAN，而是直接使用已经验证过的：

```text
C1 / C2.1 4500 trials
```

并构造带持续 latent state 的 synthetic sequence。

这样做的目的，是先单独验证：

\[
\boxed{
\text{History aggregation 是否真的能从 noisy one-shot observations 中恢复 state information？}
}
\]

如果这一步都不成立，就没有必要立刻构造更昂贵的连续二维 SAR 仿真。

---

# 3. 数据划分

每个 C1 cell 有 500 个 realization。

C3 使用严格 disjoint pool：

```text
odd trial_id  -> TRAIN pool
even trial_id -> TEST pool
```

所以：

- history hyperparameter tuning；
- score percentile calibration；
- test evaluation；

不会使用同一个 empirical realization。

---

# 4. State 定义

C2.2 已经得到 9 个 cell 的平均：

\[
u_c
=
P(B|c)-P(H|c).
\]

C3 用 TRAIN pool 重新估计：

\[
\hat u_c.
\]

再按：

\[
\hat u_c
\]

从低风险到高风险排序。

这里的“邻近 state”指的是：

> **utility-ranked latent difficulty state**

而不是声称这些 cell 在真实物理参数空间中一定连续相邻。

这点必须保留，避免过度解释。

---

# 5. Sequence 构造

## Smooth regime

状态大概率保持：

```text
p_stay = 0.90
```

剩余概率只移动到相邻 risk state。

因此形成：

```text
persistent / slowly varying latent difficulty
```

---

## Abrupt regime

在 Smooth dynamics 基础上增加：

```text
p_jump = 0.04
```

概率跳到 utility rank 相距至少：

```text
3 states
```

的位置。

用于验证：

> History smoothing 是否出现 tracking lag，以及简单 reset 能否缓解。

---

# 6. 每一个 sequence position 如何生成

给定当前 latent state / cell：

1. 从该 cell 对应 TRAIN 或 TEST empirical pool 中独立有放回抽取一个 realization；
2. 直接继承该 trial 的：
   - Cheap success；
   - Fallback success；
   - Beneficial / Harmful label；
   - prominence；
   - entropy。
3. 所以每个位置包含：

\[
\text{persistent state}
+
\text{realization-level randomness}.
\]

这正好对应 C2.2 想分解的问题。

---

# 7. Instantaneous risk：InstantPE

C3 不再堆 feature。

Primary one-shot score 只使用 C2.2 中最稳定的两个 state proxy：

```text
cheap prominence
cheap entropy
```

利用 TRAIN pool empirical CDF 转换成 percentile risk：

\[
r_p
=
1-F_p(\text{prominence})
\]

因为低 prominence 更危险；

\[
r_e
=
F_e(\text{entropy})
\]

因为高 entropy 更危险。

然后：

\[
\boxed{
r_k^{\rm inst}
=
\frac{r_p+r_e}{2}
}
\]

因此 score 始终位于：

\[
[0,1].
\]

没有模型训练，也没有 true state 参数输入。

---

# 8. History policy：EMA

定义：

\[
\boxed{
r_k^{\rm EMA}
=
\alpha r_k^{\rm inst}
+
(1-\alpha)r_{k-1}^{\rm EMA}
}
\]

它的含义非常直观：

> 单条 residual curve 很 noisy，但相邻方位线共享一个持续的 difficulty state，因此不要每一条线都完全重新相信 noisy observation。

---

# 9. 为什么要有 EMAReset

History 会有一个天然问题：

> state 突变后，过去历史可能拖累当前判断。

这和 EXP05–06 tracking-window lag 的思想非常类似。

所以加入最简单的 innovation reset：

\[
I_k
=
|r_k^{\rm inst}-r_{k-1}^{\rm hist}|.
\]

如果：

\[
I_k>\tau_I,
\]

则：

\[
\boxed{
r_k^{\rm reset}=r_k^{\rm inst}
}
\]

否则继续 EMA。

也就是说：

```text
状态稳定
    -> 相信 history，降低 noisy fluctuation

状态疑似突变
    -> 暂时丢掉历史，快速重新跟踪
```

这仍然不是复杂算法。

---

# 10. 参数 tuning

C3 不手工挑最好看的参数。

使用 TRAIN synthetic sequences：

### EMA

扫描：

```text
alpha = 0.05 ... 1.0
```

在：

```text
25% fallback budget
```

下选择 TRAIN recovery 最好的 alpha。

---

### Reset

在选定 alpha 后，对 innovation threshold 使用 TRAIN innovation distribution 的：

```text
80%
85%
90%
95%
97.5%
```

quantile 扫描。

再选择 TRAIN 25% budget recovery 最好的 threshold。

TEST 完全不参与 tuning。

---

# 11. Policy

主要比较：

## InstantPE

单条线：

\[
r_k^{inst}
\]

---

## EMA

纯 history smoothing。

---

## EMAReset

history smoothing + abrupt-state reset。

---

## KnownStatePrior

诊断上界。

知道当前 trial 属于哪个 latent cell，并使用 TRAIN-pool：

\[
\hat u_c
\]

作为 risk score。

但它**不知道当前 realization 的 Beneficial label**。

因此它代表：

> 如果 state estimation 几乎完美，单靠 state-level information 能做到什么程度？

---

## TrialOracle

直接知道 individual Beneficial label。

仍然是真正的 trial-level upper bound。

---

## RandomExpected

matched-budget random allocation expectation。

---

# 12. 一个细节：StatePrior 的 tie-breaking

同一个 state 内所有 realization 的 score 相同。

为了保证预算分配时不会因为 threshold tie 一次触发整个 cell，代码给每个 sequence position 生成一个：

```text
allocation_tiebreak
```

这是完全独立于：

- feature；
- state outcome；
- Beneficial label；

的随机数。

只以 \(10^{-9}\) 级别用于 score tie-breaking。

所以 KnownStatePrior 在同一 state 内本质上仍然是：

> **随机选择 realization**

不会偷偷利用 instantaneous information。

---

# 13. C3 最重要的第一个指标

## State Observability

对 TEST sequences 计算：

\[
\rho
(
r_k,
u_{state(k)}
)
\]

即：

> score 与 latent state utility 的 Spearman correlation。

我们希望：

### Smooth

\[
\rho_{\rm EMA}
>
\rho_{\rm Instant}.
\]

如果成立：

> History 确实在提取 state，而不是简单平滑图形。

---

# 14. 第二个指标：Beneficial Capture

固定 fallback budget：

\[
b
\]

判断：

\[
\boxed{
\text{真正 Beneficial trials 中，有多少被 policy 送进 fallback？}
}
\]

这是从 C1.1 开始一直坚持的核心 allocation metric。

---

# 15. 第三个指标：Weak Recovery vs Cost

最终还是：

\[
\boxed{
\text{Weak Recovery -- Computation Pareto}
}
\]

分别对：

```text
Smooth
Abrupt
```

画完整曲线。

---

# 16. C3 最理想的结果

## Smooth regime

理想排序：

\[
\boxed{
KnownStatePrior
>
EMA
>
InstantPE
>
Random
}
\]

TrialOracle 仍最高。

如果 EMA 在 25% budget 下能够：

- Beneficial Capture 明显提高；
- Recovery 明显提高；

说明：

> **history-aware state estimation 有真实 value。**

---

# 17. Abrupt regime 的理想结果

理想情况：

\[
\boxed{
EMAReset
\gtrsim
EMA
}
\]

尤其在 jump 后局部 tracking error 上：

\[
E_{\rm reset}
<
E_{\rm EMA}.
\]

这将形成一个非常自然的：

```text
persistent state -> history helps
abrupt change    -> history can lag
innovation reset -> recover
```

机制链。

---

# 18. 对结果不要预设过高

根据 C2.2：

- State knowledge 只能解释 Oracle opportunity 的一部分；
- 因此 EMA 不应该被期待直接逼近 Trial Oracle。

更合理的成功是：

> 在 matched budget 下，相对于 InstantPE 得到稳定、重复、跨 Smooth/Abrupt 有解释的中等提升。

例如：

```text
Beneficial Capture +5~10 percentage points
```

或者 recovery 获得稳定的几个百分点增益，

就已经是值得继续 signal-level C3-B 的 proof-of-concept。

---

# 19. C3 的 GO / NO-GO

## Strong GO

如果：

### Smooth

```text
EMA > InstantPE
```

明显成立；

### Abrupt

```text
EMAReset >= EMA
```

并降低 jump lag；

同时：

```text
History policy
```

向 KnownStatePrior 靠近。

那么下一步进入：

> **C3-B：连续物理参数 / signal-level azimuth sequence**

把：

- weak ratio；
- q separation；
- SNR / SCR；

真正设成空间连续变化。

---

## Partial GO

EMA 的 state correlation 明显提高，但 final recovery gain 很小。

说明：

> state tracking 有效，但 state information 本身不足以显著改善 individual fallback allocation。

这时 future policy 应考虑：

\[
\boxed{
state prior + realization refinement
}
\]

hierarchical architecture。

---

## NO-GO

如果：

```text
best alpha ≈ 1
EMA ≈ InstantPE
```

甚至 history 更差，

则说明：

> 在当前 empirical sequence model 中，state persistence 本身不足以提供新的 practical advantage。

那 history 路线要降级。

---

# 20. 当前实验边界必须强调

C3 第一版通过：

> **在 empirical trial bank 上人为引入 persistent Markov state**

来测试 history hypothesis。

因此即使结果非常好，也只能称：

```text
sequence-level statistical proof-of-concept
```

不能直接写成：

> “真实相邻 SAR 方位线一定具有这种 Markov risk dynamics。”

下一步必须回到 signal-level continuous state sequence 验证。

---

# 21. 输出

```text
state_estimation_diagnostics.csv

history_budget_curves.csv
reported_budget_points.csv

history_tuning_summary.csv
alpha_sweep.csv
reset_sweep.csv

abrupt_jump_diagnostics.csv

representative_smooth_sequence.csv
representative_abrupt_sequence.csv

summary.txt
exp09c3_results.mat
```

---

# 22. 主要图

```text
fig01_state_observability.png

fig02_representative_smooth_tracking.png
fig03_representative_abrupt_tracking.png

fig04_smooth_capture_vs_budget.png
fig05_smooth_quality_cost.png

fig06_abrupt_capture_vs_budget.png
fig07_abrupt_quality_cost.png

fig08_policy_comparison_25pct.png
fig09_jump_tracking_error.png

fig10_alpha_tuning.png
fig11_reset_tuning.png
```

---

# 23. 推荐目录

```text
papers/
└── Xu2025_Adaptive_Fast_Refocusing/
    ├── code/
    │   └── exp09_pilot01/
    │       ├── exp09c3_history_aware_adaptive_computation.m
    │       └── config_exp09c3.m
    └── results/
        └── exp09_pilot01/
            └── exp09c3_history_aware_adaptive_computation/
```

---

# 24. 运行

```matlab
cd <...>/Xu2025_Adaptive_Fast_Refocusing/code/exp09_pilot01

results = exp09c3_history_aware_adaptive_computation;
```

本轮不重新执行 FrAc / CLEAN，因此计算量应远低于 C1/C2.1。

---

# 25. 最优先返回的结果

运行结束后，优先查看：

```text
summary.txt
state_estimation_diagnostics.csv
reported_budget_points.csv
abrupt_jump_diagnostics.csv
```

以及：

```text
fig01_state_observability.png
fig02_representative_smooth_tracking.png
fig03_representative_abrupt_tracking.png
fig05_smooth_quality_cost.png
fig07_abrupt_quality_cost.png
fig08_policy_comparison_25pct.png
fig09_jump_tracking_error.png
```
