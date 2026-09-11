# EXP009-C1 / Pilot-01 — Oracle-to-Practical Adaptive Budget Test

## 1. C1 的核心问题

A/B 系列已经完成了：

```text
weak failure
    -> strong residual contamination
    -> coherent cross-term peak pulling
    -> stable failure region
    -> oracle risk Gamma
    -> practical observability boundary
```

B3/B4 最终告诉我们：

> reliability 不需要完美预测“这一次一定失败”，更现实的目标是：把额外计算优先分配给高风险 residual state。

因此 C1 第一次正式验证：

\[
\boxed{
\text{reliability}
\rightarrow
\text{extra computation}
\rightarrow
\text{Weak Recall--Cost gain}
}
\]

---

## 2. 为什么 C1 不再继续做 confidence classifier

B3：

```text
catastrophic observability 很强
perturbative observability 中等
```

B4：

```text
sub-aperture q stability 没有解决 perturbative single-shot prediction
```

因此不再继续寻找“万能 failure classifier”。

C1 改成 policy 视角：

```text
低风险 -> 不花额外预算
高风险 -> 启动更贵的 fallback
```

---

# 3. Cheap branch

Cheap branch 完全复用 B1-B4 的 weak-stage residual：

\[
r_{\rm cheap}
=
s_w + e_s + n
\]

其中：

\[
e_s
\]

是 fixed-notch CLEAN 后留下的 filtered strong residual。

然后进行一次完整 q search。

所以 C1 首先会再次检查：

```text
Cheap recall == B2 residual recall
```

如果复现误差不是数值精度级，就不要分析后续 policy。

---

# 4. Extra-computation fallback

C1 没有使用“更宽 q search”作为 fallback。

原因是 A/B 系列的问题已经不是 search interval 太窄，而是：

\[
\boxed{
\text{filtered coherent strong residual contaminates weak search}
}
\]

因此 fallback 直接攻击这个机制。

---

## 4.1 Parametric strong-component refit

从原始 mixture：

\[
x=s_s+s_w+n
\]

出发。

假设：

\[
q_s
\]

已经由前一级 dominant-component stage 得到。

这和 A/B 系列一直采用的 weak-stage isolation 一致。

---

## 4.2 Off-grid carrier estimation

在已知 / previous-stage：

\[
q_s
\]

的条件下 dechirp strong component：

```text
mixture
 -> dechirp(q_s)
 -> zero-padded FFT
 -> off-grid carrier peak interpolation
```

默认：

```text
NFFT = 8N
```

---

## 4.3 LS strong reconstruction

得到 off-grid carrier 后构造 strong atom：

\[
a_s(t)
\]

并估计：

\[
\hat\alpha_s
=
\frac{a_s^H x}{a_s^H a_s}.
\]

然后：

\[
r_{\rm refit}
=
x-\hat\alpha_s a_s.
\]

最后再进行一次 weak q search。

---

# 5. 为什么这个 fallback 合理

原来的 fixed-notch CLEAN 在 dechirped FFT 中直接去掉若干 bins。

当 strong tone 是 off-grid 时：

```text
spectral leakage
```

不能被有限 notch 完全消除。

A3/A4 正是发现：

```text
filtered strong residual
```

通过 coherent cross-term 推动 weak peak。

C1 的 parametric refit 用连续频率 strong model 做 LS subtraction，因此理论上有机会：

```text
减少 strong residual
同时避免更宽 notch 对 weak component 的额外破坏
```

但这仍然只是待验证的 candidate fallback，不提前宣称有效。

---

# 6. 四类 policy

## 6.1 Cheap

```text
永远不 fallback
```

成本最低。

---

## 6.2 Always Extra

所有 trial 都执行 parametric refit。

代码会报告两种诊断：

### Blind replace

总是使用 fallback 输出。

### Select by prominence

cheap 和 fallback 都算完后：

```text
哪一个 residual concentration prominence 更高
就选择哪一个 q estimate
```

后者更接近 practical branch selection。

---

## 6.3 Oracle Adaptive

Oracle 只用于性能上界。

它知道：

```text
cheap 是否失败
fallback 是否成功
```

因此只在：

```text
cheap fail AND fallback success
```

时触发 extra computation。

这是：

> 达到 `cheap OR fallback` union quality 所需的最小理论 trigger rate。

Oracle 不是 practical method。

---

## 6.4 Practical Adaptive

主 gate 使用 B3/B4 最稳定的 observable：

```text
prominence
```

规则：

```text
cheap prominence 低
    -> trigger refit fallback
```

fallback 计算后再使用：

```text
higher prominence branch
```

做 practical selection。

代码同时扫描 entropy gate 作为对照。

---

# 7. 为什么 C1 不直接固定一个 prominence threshold

固定阈值容易变成：

```text
0.61 为什么？
0.58 为什么？
```

因此 C1 第一阶段先画完整：

\[
\text{Recall--Fallback Rate}
\]

和：

\[
\text{Recall--Normalized q-search budget}
\]

曲线。

目的是判断：

> practical gate 是否存在真正的 Pareto gain。

---

# 8. Cost 定义

所有 policy 都从 mandatory cheap stage 开始。

Cheap：

\[
C_q=1.
\]

如果某 trial fallback：

\[
C_q=2.
\]

因此平均：

\[
\boxed{
C_q
=
1+\text{fallback rate}
}
\]

同时输出：

```text
q_candidate_evals_per_trial
strong_refit_calls_per_trial
```

其中：

\[
N_q
\]

是每次 q search 的 candidate 数。

注意：

> 当前主 cost metric 尚未把 zero-padded FFT 与 q-evaluation 强行换算成同一个标量。

这是刻意的，因为任意人为设一个“FFT 等于多少 q candidate”会引入不必要假设。

后续如果 C1 成功，再用 runtime / FLOPs 做更正式的 quality-cost evaluation。

---

# 9. Oracle-matched cost

为了避免任意选阈值，C1 会找一个：

```text
Practical prominence threshold
```

使它的 fallback rate 尽可能接近：

```text
Oracle minimal useful trigger rate
```

然后比较：

\[
R_{\rm practical}
\]

与：

\[
R_{\rm oracle}.
\]

定义：

\[
\boxed{
\text{Oracle gain capture}
=
\frac{
R_{\rm practical}-R_{\rm cheap}
}{
R_{\rm oracle}-R_{\rm cheap}
}
}
\]

这是 C1 最关键的指标之一。

---

# 10. LOCO budget-controlled policy

为了避免 threshold sweep 只是在当前 9 cells 上“看图调参”，C1 还做：

```text
Leave-One-Cell-Out
```

但这次不是训练 classifier。

而是给定一个用户预算：

```text
10% fallback
25% fallback
50% fallback
```

每次：

```text
其他 8 cells
    -> 只根据 prominence 分布确定相应 quantile threshold

held-out cell
    -> 使用这个 threshold
```

因此它验证的是：

> 一个“预算控制式 gate”能否跨未见 parameter cell 泛化。

---

# 11. 最关键的 success criteria

C1 不要求 practical policy 达到 Oracle。

真正希望看到：

### 1. Fallback 本身有价值

\[
R_{\rm fallback}
>
R_{\rm cheap}
\]

或者至少：

\[
R_{\rm oracle\ union}
\gg
R_{\rm cheap}.
\]

如果 Oracle union 都几乎没提升：

> 说明这个 fallback 不值得继续。

---

### 2. Oracle adaptive 有明显空间

希望：

\[
R_{\rm oracle}-R_{\rm cheap}
\]

不是几个千分点。

---

### 3. Practical Pareto gain

希望 practical curve 中存在：

\[
R_{\rm practical}>R_{\rm cheap}
\]

同时：

\[
\text{fallback rate}\ll1.
\]

---

### 4. Practical captures nontrivial Oracle gain

例如：

```text
只花 20%-30% fallback budget
拿到 Oracle gain 的大部分
```

这种结果最有方法价值。

---

### 5. 不出现严重 harm

如果 fallback / branch selector 经常：

```text
cheap success -> policy failure
```

则当前 fallback 或 branch selection 不够安全。

---

# 12. 可能出现的三类结果

## Case A — Strong GO

```text
Oracle gain 大
Practical gain 明显
Practical cost << Always extra
```

那么 C1 直接证明：

\[
\boxed{
\text{Reliability-aware adaptive computation is viable}
}
\]

下一步进入 C2 扩大参数空间 / 优化 policy。

---

## Case B — Oracle 好，但 Practical 不好

说明：

```text
extra computation 是有效的
但当前 prominence gate 还不够好
```

这时应该优化 gate / history / region-level policy，而不是否掉 adaptive computation。

---

## Case C — Oracle 都不好

说明：

```text
parametric refit fallback 本身没有足够 rescue power
```

那就应该换 fallback mechanism，而不是继续调 confidence threshold。

---

# 13. 主要输出

```text
c1_branch_trials.csv
b2_reproduction_check.csv
cell_branch_diagnostics.csv

policy_curve_prominence.csv
policy_curve_entropy.csv
policy_summary.csv

loco_budget_policies.csv
loco_thresholds_budget_010.csv
loco_thresholds_budget_025.csv
loco_thresholds_budget_050.csv

summary.txt
exp09c1_results.mat
```

---

# 14. 主要图

```text
fig01_branch_potential_by_cell.png
fig02_fallback_rescue_harm.png
fig03_prominence_quality_cost.png
fig04_gate_comparison.png
fig05_loco_budget_pareto.png
fig06_policy_recovery_summary.png
fig07_prominence_vs_fallback_benefit.png
fig08_matched_cost_by_cell.png
```

---

# 15. 推荐目录

```text
papers/
└── Xu2025_Adaptive_Fast_Refocusing/
    ├── code/
    │   └── exp09_pilot01/
    │       ├── exp09c1_adaptive_budget.m
    │       └── config_exp09c1.m
    └── results/
        └── exp09_pilot01/
            └── exp09c1_adaptive_budget/
```

---

# 16. 运行

```matlab
cd <...>/Xu2025_Adaptive_Fast_Refocusing/code/exp09_pilot01
results = exp09c1_adaptive_budget;
```

---

# 17. 运行建议

C1 每个 trial 同时计算：

```text
Cheap branch
Parametric-refit fallback branch
```

因此比 B3 更重，但比 B4 的 4 个 sub-aperture search 更轻。

正式建议直接：

```matlab
cfg.num_mc = 500;
```

如果第一次只验证代码路径：

```matlab
cfg.num_mc = 50;
```

跑通后再恢复 500。

正式结论只使用完整 MC。

---

# 18. 一个重要实验边界

当前 fallback 使用 previous-stage / oracle-known：

\[
q_s
\]

来隔离 weak-stage computation policy。

这是有意设计，不应写成完整 practical algorithm 已经解决 dominant q estimation。

如果 C1 成功，后续 C2/C3 再逐步加入：

```text
estimated q_strong error
multi-component stage propagation
realistic sequential estimation
```

这样可以避免一次把多个 failure source 混在一起。
