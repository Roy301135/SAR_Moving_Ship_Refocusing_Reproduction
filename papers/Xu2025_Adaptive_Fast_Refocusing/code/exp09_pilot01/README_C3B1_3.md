# EXP009-C3-B1.3 — State-Conditioned Harm-Aware Fallback

## 1. 这一轮在整条实验链里的位置

C3-B1.2 给出了一个非常明确的不对称结果：

```text
Beneficial fate
    -> fixed-state 下仍较难稳定预测

Harmful fate
    -> q-landscape morphology 中存在很强的 realization-level information
```

因此 C3-B1.3 不再继续寻找更多 observable，而是第一次把这个机制结果转成真正的 computation-allocation policy。

核心假设：

\[
\boxed{
\text{fallback utility}
=
\text{state opportunity}
-
\text{realization harm risk}
}
\]

这和此前的 direct fusion 不同。

---

# 2. C3-B1.2 给出的直接依据

上一轮最重要的 Harmful within-line 结果包括：

Smooth：

```text
local curvature          ~0.820
peak second/first ratio  ~0.751
peak margin              ~0.751
width50                  ~0.669
```

Abrupt：

```text
local curvature          ~0.841
peak second/first ratio  ~0.787
peak margin              ~0.787
width50                  ~0.668
```

而 MorphologyOnly group：

```text
Smooth within-H ~0.717
Abrupt within-H ~0.755
```

相反 Beneficial group-level within-line AUC 仍大致停留在：

```text
~0.52–0.55
```

因此这一轮重点不是：

```text
predict Beneficial directly
```

而是：

```text
state tells us where extra computation may be worthwhile
morphology tells us where fallback may be dangerous
```

---

# 3. 本轮不重新生成 signal

C3-B1.3 直接读取 C3-B1.2：

```text
train_rich_trials_smooth.csv
train_rich_trials_abrupt.csv
test_rich_trials_smooth.csv
test_rich_trials_abrupt.csv
```

默认位置：

```text
results/
└── exp09_pilot01/
    └── exp09c3b1_2_mechanism_observable_audit/
```

然后重新构建与 C3-B1 / B1.2 一致的 cross-fitted state prior。

---

# 4. 为什么采用 asymmetric policy

原来 direct fusion 的逻辑是：

\[
X
\rightarrow
P(Beneficial), P(Harmful)
\rightarrow
P_B-P_H.
\]

问题是：

```text
P_B 本身仍然难预测
```

因此一个统一模型容易被这个难问题拖累。

C3-B1.3 改成：

## Opportunity channel

\[
S = \text{physical-state prior}
\]

回答：

> 当前 state 整体上值不值得花额外 computation？

## Harm channel

\[
p_H
=
P(Harmful|\text{q morphology})
\]

回答：

> 当前这一发 realization 是否存在 fallback 反而损伤 Cheap 正确结果的风险？

然后再分配 budget。

---

# 5. Harm model

只用 C3-B1.2 已经证明最有信息的 q-landscape morphology：

```text
cheap_prominence
cheap_entropy

peak_second_ratio
peak_margin_norm
top2_q_separation

width50_q
local_curvature_norm
local_asymmetry
peak_robust_z
```

使用：

```text
ridge logistic
```

预测：

\[
p_H.
\]

没有引入 MLP / deep learning。

原因是这一轮只验证：

> **机制分解本身是否有算法价值。**

---

# 6. OOF 防止 policy tuning 泄漏

TRAIN 有 20 个 Monte-Carlo sequence。

本轮使用：

```text
5-fold sequence-level OOF
```

而且：

```text
Smooth sequence i
Abrupt sequence i
```

进入同一个 fold。

因此：

```text
lambda
hard-veto threshold
```

都只根据 out-of-fold TRAIN prediction 选择。

TEST 完全不参与超参数选择。

---

# 7. Policy 1 — StateOnly

\[
J_{\rm state}=z(S).
\]

这是上一轮非常重要的 practical baseline。

---

# 8. Policy 2 — HarmOnlyMorph

\[
J_{\rm harm}=-p_H.
\]

这个 policy 不看 opportunity，只问：

> 哪些 realization 看起来最安全？

它主要是 diagnostic baseline。

---

# 9. Policy 3 — StateMorphDirect

传统 direct fusion：

```text
state + morphology
    ->
two-head logistic
    ->
pB - pH
```

这是最关键的公平对照之一。

因为如果 asymmetric decomposition 不如 direct fusion，

那么：

> decomposition 有解释价值，但还没有算法优势。

---

# 10. Policy 4 — StateAllDirect

复现 C3-B1.2 的强 direct-fusion baseline：

```text
state
+
all realization observables
```

然后：

\[
J=p_B-p_H.
\]

---

# 11. Policy 5 — OpportunityMinusHarm

本轮主方法候选：

\[
\boxed{
J_{\lambda}
=
z(S)
-
\lambda p_H
}
\]

其中：

\[
\lambda
\]

从：

```text
0 : 0.1 : 4
```

用 OOF TRAIN 在 25% budget 下选择。

它的物理含义非常直接：

```text
高 opportunity
+
低 harm risk
    ->
优先使用 fallback
```

---

# 12. Policy 6 — OpportunityHardVeto

更工程化、更容易解释：

```text
先按 state opportunity 排序
```

但若：

\[
p_H>h
\]

则把该 trial 大幅降级。

也就是：

\[
\boxed{
\text{opportunity gate}
+
\text{harm veto}
}
\]

阈值 \(h\) 也是 OOF TRAIN 选择。

---

# 13. Policy 7 — OracleHarmVeto

这个 policy 非 practical，而是非常关键的诊断上界。

使用真实：

```text
Harmful label
```

把所有真正 Harmful trial 从 StateOnly ranking 中降级。

它回答：

> **假如我们完美知道哪里 fallback 会伤害结果，仅靠 harm avoidance 能把 StateOnly 提升多少？**

这个量决定：

```text
harm-aware 路线本身到底有没有足够大的 ceiling
```

---

# 14. Policy 8 — TrialOracle

真正上界：

```text
Beneficial first
Neutral second
Harmful last
```

---

# 15. 为什么这一轮使用 exact matched budget

对于 budget：

\[
b
\]

直接从每个 TEST scene / regime 的 policy score 中选择 top-K：

\[
K=\mathrm{round}(bN).
\]

因此：

```text
StateOnly
DirectFusion
Harm-aware
Oracle
```

全部使用完全相同的 trigger 数量。

不存在：

> 某个策略因为实际 fallback 更少，所以看起来更好。

---

# 16. 最重要的比较

## A. Harm model 是否真的保留 B1.2 信息？

看：

```text
harm_model_audit.csv
```

尤其：

```text
within_line_harm_auc
```

合理预期仍应接近：

```text
Smooth ~0.7+
Abrupt ~0.7+
```

如果突然掉到 ~0.5，要先检查实现。

---

## B. OpportunityMinusHarm vs StateOnly

在：

```text
25% budget
```

比较：

```text
policy_recall
harmful_fraction_among_triggers
beneficial_capture
```

理想情况：

```text
Recovery ↑
Harmful allocation ↓
```

同时发生。

---

## C. Asymmetric vs Direct Fusion

比较：

```text
StateMorphDirect
StateAllDirect
OpportunityMinusHarm
OpportunityHardVeto
```

如果 asymmetric policy 优于 direct fusion：

> 说明“机会”和“风险”分开建模不仅有解释性，而且有算法收益。

---

## D. OracleHarmVeto 的 ceiling

定义：

\[
G_H
=
R_{\rm OracleHarmVeto}
-
R_{\rm StateOnly}.
\]

如果它明显大：

> harm avoidance 本身是一条高价值路线。

如果它很小：

> 即使 Harmful 能被完美预测，也不够；真正瓶颈仍是 Beneficial opportunity。

---

# 17. 两个非常重要的 gap fraction

## Perfect harm avoidance 能解释多少 TrialOracle gap？

\[
\boxed{
F_H
=
\frac{
R_{\rm OracleHarmVeto}-R_{\rm StateOnly}
}{
R_{\rm TrialOracle}-R_{\rm StateOnly}
}
}
\]

这个量告诉我们：

> 剩余 Oracle gap 里，有多少纯粹来自“避免 harmful fallback”就能解决。

---

## Practical policy 捕获了多少 OracleHarm gain？

\[
\boxed{
F_{\rm practical|H}
=
\frac{
R_{\rm practical}-R_{\rm StateOnly}
}{
R_{\rm OracleHarmVeto}-R_{\rm StateOnly}
}
}
\]

如果这个值已经很高：

> 当前 morphology-based harm model 已经接近 harm-aware ceiling。

如果很低：

> 说明 Harmful 虽可观察，但 risk model / policy 仍需改进。

---

# 18. 这一轮的核心成功判据

## Strong GO

如果：

```text
OpportunityMinusHarm
or
OpportunityHardVeto
```

在 matched budget 下：

```text
Recovery > StateOnly
Harmful fraction << StateOnly
```

并且尤其在 Abrupt 中稳定，

那么可以形成第一版方法骨架：

\[
\boxed{
\text{State-Conditioned Harm-Aware Adaptive Refocusing}
}
\]

---

## Partial GO

如果：

```text
Harmful allocation 显著下降
```

但 recovery 几乎不变，

说明：

> harm veto 有效，但 benefit opportunity 仍是主要瓶颈。

这仍然是有价值的机制结论。

---

## Ceiling GO / Practical NO-GO

如果：

```text
OracleHarmVeto 明显提升
```

但 practical harm-aware policy 不提升，

则问题变成：

> 如何进一步提高 harm-risk estimation / calibration？

此时才值得考虑：

```text
nonlinear model
small MLP
1-D q-curve model
```

---

## Route NO-GO

如果：

```text
OracleHarmVeto 本身都几乎不优于 StateOnly
```

则说明：

> Harmful observability 虽然漂亮，但对最终 computation allocation 的 ceiling 很低。

那就不能把它硬包装成主方法。

---

# 19. 预期结果

根据 C3-B1.2，我更期待的是：

### Smooth

已有 StateOnly 很强，因此：

```text
harm-aware gain 可能较小
```

但 Harmful allocation 应下降。

### Abrupt

C3-B1.2 中 morphology 的 Harmful within-line AUC 非常强，

而 StateAll 在 25% budget 已经明显优于 StateOnly。

因此更值得期待：

```text
OpportunityMinusHarm / HardVeto
    ->
更明显的 recovery gain
+
更明显的 harmful suppression
```

但这只是实验预期，不提前当成结论。

---

# 20. 推荐目录

```text
papers/
└── Xu2025_Adaptive_Fast_Refocusing/
    ├── code/
    │   └── exp09_pilot01/
    │       ├── exp09c3b1_3_harm_aware_fallback.m
    │       └── config_exp09c3b1_3.m
    └── results/
        └── exp09_pilot01/
            └── exp09c3b1_3_harm_aware_fallback/
```

---

# 21. 运行

```matlab
cd <...>/Xu2025_Adaptive_Fast_Refocusing/code/exp09_pilot01

results = exp09c3b1_3_harm_aware_fallback;
```

本轮不重新生成 signal，因此计算量会比 C3-B1.2 小很多。

主要耗时只是：

```text
5-fold OOF logistic fitting
policy sweep
plotting
```

---

# 22. 关键输出

```text
selected_hyperparameters.csv

harm_model_audit.csv
harm_risk_calibration.csv

lambda_sweep_oof.csv
veto_sweep_oof.csv

harm_aware_policy_curves.csv
reported_budget_points.csv
primary_25pct_policy_comparison.csv

oracle_harm_decomposition.csv
delta_vs_stateonly.csv

decision_summary.csv
summary.txt
```

---

# 23. 最重要的图

```text
fig01_lambda_tuning.png
fig02_veto_tuning.png

fig03_policy_recovery_25pct.png
fig04_harmful_allocation_25pct.png

fig05_smooth_quality_cost.png
fig06_abrupt_quality_cost.png

fig07_oracle_harm_decomposition.png
fig08_abrupt_delta_vs_state.png

fig09_smooth_opportunity_risk_plane.png
fig10_abrupt_opportunity_risk_plane.png

fig11_harm_risk_calibration.png
fig12_harm_model_auc.png
```

---

# 24. 这轮真正想回答的一句话

C3-B1.2 已经告诉我们：

> “哪里 fallback 会有风险”比“哪里 fallback 一定有收益”更容易观察。

C3-B1.3 要正式验证：

\[
\boxed{
\text{能否把这种风险可观测性真正转化成更好的 computation allocation？}
}
\]

如果答案是 yes，

那么 EXP009 就第一次从：

```text
failure mechanism
```

跨到了：

```text
mechanism-informed adaptive method
```
