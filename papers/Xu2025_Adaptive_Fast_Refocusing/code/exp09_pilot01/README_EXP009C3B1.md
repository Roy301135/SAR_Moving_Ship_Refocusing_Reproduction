# EXP009-C3-B1 / Pilot-01 — Signal-Level Continuous Azimuth-State Validation

## 1. C3-B1 的位置

C3-A 已经完成了一个 bootstrap sequence proof-of-concept：

```text
persistent latent state
    -> history improves state observability
    -> EMA improves computation allocation
    -> abrupt state transition causes history lag
    -> innovation reset mitigates the lag
```

但 C3-A 的 state persistence 是人为通过 Markov dynamics 注入的。

因此 C3-B1 的任务不是继续调 EMA，而是回答更关键的问题：

> **如果相邻方位线真正由连续变化的 MC-LFM signal parameters 生成，前面的 history phenomenon 是否仍然存在？**

这一步把 C3 从：

```text
statistical sequence proof-of-concept
```

推进到：

```text
signal-level continuous-azimuth mechanism validation
```

---

# 2. C3-B1 的 controlled boundary

C3-B1 仍然保持：

\[
q_s(k)
\]

在每一条线都已知 / oracle。

原因不是认为实际算法中 q_strong 永远已知，而是继续保持 A/B/C1 的 weak-stage isolation：

```text
dominant strong q tracking
```

暂时不和：

```text
weak-stage adaptive computation
```

混在一起。

因此：

```text
C3-B1
    -> validate weak-stage history mechanism

C3-B2
    -> add practical q_strong estimation / tracking
```

---

# 3. Signal model

沿用 EXP009 B/C controlled chain：

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
```

LFM：

\[
s(t)
=
A
\exp\left[
j\left(
\pi\mu(q)t^2
+
2\pi f_0 t
+
\phi_0
\right)
\right]
\]

其中：

\[
\mu(q)
=
\mu_{\rm scale}(q-q_{\rm ref}).
\]

---

# 4. Continuous azimuth state

C3-B1 不再从离散 B2 cells 随机跳转。

定义：

\[
k=1,\ldots,121
\]

条连续 azimuth lines。

归一化位置：

\[
x_k\in[0,1].
\]

---

## 4.1 Weak / strong ratio

Smooth baseline：

\[
\frac{A_w(k)}{A_s}
=
0.34
+
0.10\sin(2\pi x_k-0.30)
+
0.035\sin(4\pi x_k+0.70).
\]

并限制：

\[
0.18
\le
A_w/A_s
\le
0.52.
\]

---

## 4.2 Relative q geometry

定义：

\[
\Delta q(k)
=
q_s(k)-q_w.
\]

Smooth baseline：

\[
\Delta q(k)
=
-0.010
+
0.038\sin(2\pi x_k+0.80)
+
0.014\sin(6\pi x_k-0.40).
\]

限制：

\[
-0.060
\le
\Delta q
\le
0.060.
\]

因此：

\[
q_s(k)
=
q_w+\Delta q(k).
\]

---

# 5. 为什么先只变化两个物理量

第一版只让：

```text
A_w / A_s
q_s - q_w
```

连续变化。

SNR 暂时固定。

这样做是为了保持因果链干净：

```text
physical line state
    -> strong residual / weak competition changes
    -> Cheap / fallback value changes
    -> history tracks resulting risk state
```

如果第一版同时加入：

```text
SNR
SCR
q_strong tracking error
third component
2-D clutter
```

即使 history 有效，也很难知道主要由哪个变量产生。

---

# 6. Smooth 与 Abrupt 两个 regime

## Smooth

只使用上述连续参数曲线。

---

## Abrupt

从同一 smooth baseline 出发，在约：

```text
45% sequence position
```

加入：

\[
\Delta(A_w/A_s)=-0.14
\]

以及：

\[
\Delta(\Delta q)=-0.035.
\]

然后继续限制在合法参数范围中。

这个 jump 的目的不是声称真实舰船一定发生这一固定跳变量，而是：

> 在 signal level 制造一个明确的物理状态突变，用于验证 history-lag / reset mechanism。

---

# 7. 每一条 line 真正重新生成 signal

对每条 azimuth line：

\[
s_s(k,t)
\]

和：

\[
s_w(k,t)
\]

根据当前：

```text
A_w/A_s(k)
q_s(k)-q_w
```

重新生成。

每个 Monte-Carlo sequence 还重新生成独立 AWGN。

所以 C3-B1 中的：

```text
Cheap success
Fallback success
Beneficial
Harmful
```

都来自当前 signal chain。

不再来自 imposed Markov label。

---

# 8. Cheap branch

为了严格延续 C1/C2.1 controlled weak-stage experiment，Cheap branch 仍使用：

```text
strong-only fixed-notch residual
```

即：

\[
e_s(k)
=
\mathcal C_{\rm notch}\{s_s(k)\}.
\]

随后：

\[
x_{\rm cheap}(k)
=
s_w(k)
+
e_s(k)
+
n(k).
\]

再执行完整 weak q search。

注意：

> 这里不是对 mixture 直接做实际 notch 后再分析。

这是为了继续隔离：

\[
\boxed{
\text{filtered strong residual 对 weak search 的影响}
}
\]

并和 C1/C2.1 保持同一 experimental definition。

---

# 9. Fallback branch

从原始：

\[
x_{\rm mix}
=
s_s+s_w+n
\]

出发。

已知：

\[
q_s(k)
\]

后：

```text
dechirp(q_s)
    -> zero-padded FFT
    -> off-grid strong-frequency interpolation
    -> LS strong amplitude reconstruction
    -> subtract strong atom
    -> full weak q search
```

使用：

\[
N_{\rm FFT}=8N.
\]

LS：

\[
\hat\alpha_s
=
\frac{a_s^H x}{a_s^H a_s},
\]

然后：

\[
r_{\rm refit}
=
x-\hat\alpha_sa_s.
\]

---

# 10. Recovery label

和 C1 一致：

\[
|\hat q_w-q_w|
\le
0.003
\]

判定 weak recovery success。

定义：

### Beneficial

```text
Cheap fails
AND
Fallback succeeds
```

### Harmful

```text
Cheap succeeds
AND
Fallback fails
```

---

# 11. TRAIN / TEST

这里不再用 trial-bank split，而是直接生成完全独立的 signal Monte Carlo ensembles：

```text
20 TRAIN complete sequences / regime
40 TEST  complete sequences / regime
```

每个 complete sequence 都包含：

```text
121 azimuth lines
```

并使用独立 AWGN。

所以 TRAIN 和 TEST 没有共享 noise realization。

---

# 12. 第一个必须先过的检查：Physical State Reproducibility

C3-B1 首先不做 history。

对每个真实 line \(k\)，在 TRAIN ensemble 上估计：

\[
P_B(k)
=
P(\text{Beneficial}|k)
\]

\[
P_H(k)
=
P(\text{Harmful}|k)
\]

并定义：

\[
\boxed{
u(k)
=
P_B(k)-P_H(k).
}
\]

这个：

\[
u(k)
\]

就是 signal chain 自己产生的：

> **line-level fallback utility state**。

用 7-line moving average 降低有限 Monte-Carlo 抖动。

然后独立在 TEST ensemble 重新计算同样的 utility curve。

必须先检查：

\[
\rho
(
u_{\rm train}(k),
u_{\rm test}(k)
).
\]

---

## 为什么这一项比 history 本身更重要

如果：

\[
u_{\rm train}(k)
\]

和：

\[
u_{\rm test}(k)
\]

根本不一致，

那么就说明：

> 当前 continuous physical trajectory 并没有形成稳定可重复的 risk state。

此时：

```text
EMA > Instant
```

即使偶然出现也没有可靠解释。

代码会在：

\[
\rho<0.5
\]

时主动 warning。

比较理想的是：

\[
\rho>0.7.
\]

---

# 13. PhysicalStatePrior

C3-B1 的 state oracle 不再知道 C3-A 人工 Markov state。

它使用：

\[
u_{\rm train}(k)
\]

作为每个 line 的 risk prior。

TEST 时：

> 只知道“第 k 条线在 TRAIN ensemble 中平均有多值得 fallback”，不知道当前 TEST realization 的 fate。

所以它是：

\[
\boxed{
\text{signal-generated state-level diagnostic upper bound}
}
\]

而不是 practical method。

---

# 14. InstantPE

仍然只使用：

```text
Cheap prominence
Cheap entropy
```

并且 empirical CDF 仅使用：

```text
Smooth TRAIN
```

做 calibration。

这样 Abrupt TEST 不会获得自己的专属 calibration。

风险：

\[
r_p
=
1-F_p(\text{prominence})
\]

\[
r_e
=
F_e(\text{entropy})
\]

\[
\boxed{
r_{\rm inst}
=
\frac{r_p+r_e}{2}.
}
\]

---

# 15. EMA

\[
r_k^{EMA}
=
\alpha r_k^{inst}
+
(1-\alpha)r_{k-1}^{EMA}.
\]

\(\alpha\) 只使用：

```text
Smooth TRAIN
```

在 25% fallback budget 下扫描选择。

如果：

\[
\alpha\approx1,
\]

说明 signal-level continuous state 下 history 并没有实际价值。

如果明显：

\[
\alpha<1,
\]

并且 TEST 上继续提高 state observability / allocation：

> C3-A history hypothesis 才真正被 signal-level 支持。

---

# 16. EMAReset

固定 best alpha 后，

仅使用：

```text
Abrupt TRAIN
```

扫描 innovation threshold。

\[
I_k
=
|r_k^{inst}-r_{k-1}^{hist}|.
\]

如果：

\[
I_k>\tau_I
\]

则当前 history state reset 到 instantaneous score。

Threshold 候选：

```text
80%
85%
90%
95%
97.5%
99%
```

的 TRAIN innovation quantiles。

先按：

```text
25% budget TRAIN recovery
```

选最优。

若出现完全相同的 recovery，再选：

```text
post-jump tracking error 更小
```

者。

---

# 17. State observability

C3-B1 同时报告：

## Trial-level

\[
\rho(
r_{k,m},
u_{\rm train}(k)
)
\]

其中 \(m\) 是 TEST Monte-Carlo realization。

---

## Line-mean level

先算：

\[
\bar r(k)
=
\frac1M
\sum_m r_{k,m},
\]

再：

\[
\rho(
\bar r(k),
u_{\rm train}(k)
).
\]

这一项尤其重要。

如果：

\[
\rho_{\rm EMA,line}
>
\rho_{\rm Instant,line},
\]

说明 history 对 signal-generated risk trajectory 的恢复更稳定。

---

# 18. Budget policy

比较：

```text
InstantPE
EMA
EMAReset
PhysicalStatePrior
TrialOracle
RandomExpected
```

指标仍然统一为：

```text
actual fallback rate
weak recovery rate
beneficial capture
benefit precision
harmful fraction
normalized q-search budget
```

其中：

\[
\text{Normalized q-search budget}
=
1+\text{fallback rate}.
\]

和 C1/C2/C3-A 保持同一个 cost convention。

额外 parametric-refit FFT 的实际 runtime 单独输出，不假装它完全等于 q-search cost。

---

# 19. Abrupt jump diagnostics

在 physical jump 后前 5 条线中计算：

\[
|r_k-u(k)|.
\]

比较：

```text
InstantPE
EMA
EMAReset
```

目标机制：

```text
Smooth:
    EMA filters noisy state observations

Abrupt jump:
    EMA carries stale history
    -> transition lag

EMAReset:
    large innovation triggers reset
    -> post-jump error decreases
```

---

# 20. C3-B1 的成功判据

## Gate 1 — Stable signal-generated state

优先级最高。

希望：

\[
\rho(u_{\rm train},u_{\rm test})
\gtrsim0.7.
\]

至少不应接近随机。

---

## Gate 2 — Smooth history advantage

希望：

\[
\rho_{\rm EMA}
>
\rho_{\rm Instant}
\]

且 25% budget：

```text
EMA Beneficial Capture > InstantPE
EMA Recovery > InstantPE
```

不要求巨大提升。

稳定几个百分点已经具有机制意义。

---

## Gate 3 — Physical state ceiling

希望：

```text
PhysicalStatePrior > InstantPE
```

说明 signal-generated state 确实含有 adaptive-computation opportunity。

---

## Gate 4 — Abrupt lag

希望 jump 后：

```text
EMA error > InstantPE error
```

证明 history 存在 stale-state lag。

---

## Gate 5 — Reset mitigation

希望：

```text
EMAReset post-jump error < EMA
```

并且 global recovery 不明显下降。

Reset 不必立刻全局超过 EMA。

只要：

> 局部 transition mechanism 被恢复，

就可以继续研究。

---

# 21. 三种可能结果

## Strong PASS

```text
state reproducible
EMA > Instant in Smooth TEST
EMA lag appears after physical jump
Reset reduces jump lag
```

那么：

\[
\boxed{
\text{C3-A bootstrap phenomenon survives signal-level validation.}
}
\]

下一步进入：

> **C3-B2：Practical dominant-q tracking + history-aware weak-stage allocation**

---

## Partial PASS

state 很稳定，

history correlation 提高，

但 final recovery gain 很小。

说明：

> history 很会估计 state，但 state-level information 本身还不足以完成 trial allocation。

后续考虑：

\[
\text{state prior}
+
\text{instantaneous realization refinement}.
\]

---

## NO-GO

如果：

```text
train/test utility curve 不可重复
```

则首先修改：

```text
physical trajectory
MC sample size
SNR / weak-ratio operating region
```

而不是继续调 EMA。

如果 state 可重复但：

```text
best alpha ≈ 1
EMA <= Instant
```

则 C3 history 主线应降级。

---

# 22. 输出

主要 CSV：

```text
trajectory_smooth.csv
trajectory_abrupt.csv

train_trials_smooth.csv
train_trials_abrupt.csv
test_trials_smooth.csv
test_trials_abrupt.csv

signal_level_state_summary.csv
state_observability_diagnostics.csv

alpha_sweep.csv
reset_sweep.csv

signal_level_budget_curves.csv
reported_budget_points.csv

jump_tracking_diagnostics.csv
runtime_summary.csv

representative_smooth_sequence.csv
representative_abrupt_sequence.csv

summary.txt
exp09c3b1_results.mat
```

---

# 23. 主要图

```text
fig01_state_reproducibility.png
fig02_smooth_physical_trajectory.png

fig03_representative_smooth_tracking.png
fig04_representative_abrupt_tracking.png
fig05_state_observability.png

fig06_smooth_quality_cost.png
fig07_abrupt_quality_cost.png
fig08_policy_comparison_25pct.png

fig09_jump_tracking_error.png

fig10_alpha_tuning.png
fig11_reset_tuning.png

fig12_train_test_utility_profiles.png
fig13_smooth_ensemble_mean_tracking.png
fig14_abrupt_ensemble_mean_tracking.png
```

---

# 24. 推荐目录

```text
papers/
└── Xu2025_Adaptive_Fast_Refocusing/
    ├── code/
    │   └── exp09_pilot01/
    │       ├── exp09c3b1_signal_level_continuous_state.m
    │       └── config_exp09c3b1.m
    └── results/
        └── exp09_pilot01/
            └── exp09c3b1_signal_level_continuous_state/
```

---

# 25. 运行

```matlab
cd <...>/Xu2025_Adaptive_Fast_Refocusing/code/exp09_pilot01

results = exp09c3b1_signal_level_continuous_state;
```

---

# 26. 计算量

与 C3-A 不同，C3-B1 重新执行真实 signal-level：

```text
Cheap q search
+
8N parametric refit
+
Fallback q search
```

默认总量：

```text
121 lines
x
(20+40) MC
x
2 regimes
```

也就是：

```text
14520 signal-level line trials
```

每个 trial 还包含两个 q searches。

因此本轮明显比 C3-A 慢。

代码已使用：

```text
16 lines / batch
```

做 q-grid search，降低 MATLAB 循环开销。

---

# 27. MATLAB 维度安全规范

前面 A4 / C2.1 曾出现 row/column orientation 导致：

```text
matrix multiplication dimension mismatch
implicit expansion -> vector/matrix instead of scalar
```

C3-B1 针对这个问题统一做了以下处理：

```matlab
x = x(:);
t = t(:).';
q = q(:);
```

并在批量运算中显式构造：

```text
D3 : Q x N x 1
X3 : 1 x N x B
```

再使用：

```matlab
bsxfun
```

完成广播。

Parametric refit 也严格使用：

```text
L x 1 parameter vector
L x N signal matrix
```

并检查输出尺寸。

也就是说，本轮不会依赖模糊的 row/column implicit expansion 行为。
