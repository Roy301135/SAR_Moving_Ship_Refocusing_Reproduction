# EXP009-C2 / Pilot-01 — Benefit-Aware Computation Allocation

## 1. 为什么 C2 改变了 target

C1.1 已经把当前 Practical–Oracle gap 分解得非常清楚：

\[
\text{Allocation Loss}\approx 89.8\%
\]

\[
\text{Selector Loss}\approx 10.2\%.
\]

而在 matched-cost operating point 下：

```text
Beneficial allocation capture ≈ 49.6%
Benefit precision among triggers ≈ 49.4%
Selector rescue capture ≈ 97.9%
```

这意味着：

> 只要真正 rescuable 的 trial 被送进 fallback，后面的 branch selection 基本已经不是主要问题。

真正的瓶颈是：

\[
\boxed{
\text{有限 fallback budget 投给了错误的 residual states}
}
\]

因此 C2 不再预测：

```text
Cheap 是否会失败？
```

而直接预测：

```text
如果我多花一次 fallback 计算，这次计算到底值不值？
```

---

# 2. C2 不重新跑信号级 Monte Carlo

C2 直接读取 C1 已经生成的：

```text
c1_branch_trials.csv
```

所以：

- 不重新合成信号；
- 不重新运行 4500 次 Cheap/Fallback；
- 不改变 C1 的 experimental realization。

C2 是纯 policy / allocation experiment。

---

# 3. Fallback Value Label

定义 Cheap recovery outcome：

\[
S_C\in\{0,1\}
\]

和 Fallback recovery outcome：

\[
S_F\in\{0,1\}.
\]

---

## 3.1 Beneficial

\[
S_C=0,\quad S_F=1
\]

即：

```text
Cheap fail
Fallback success
```

额外计算带来：

\[
+1
\]

个 binary recovery gain。

这是最应该获得 fallback budget 的状态。

---

## 3.2 Harmful

\[
S_C=1,\quad S_F=0
\]

即：

```text
Cheap success
Fallback fail
```

如果盲目 fallback，会损失：

\[
-1.
\]

---

## 3.3 Neutral

其余：

```text
Cheap/Fallback 都成功
```

或：

```text
Cheap/Fallback 都失败
```

额外计算对 binary recovery 不产生收益。

---

# 4. Value of Computation

C2 使用两个非常简单的 LOCO logistic model：

\[
P_B(x)
=
P(\text{Beneficial}\mid x)
\]

和：

\[
P_H(x)
=
P(\text{Harmful}\mid x).
\]

定义：

\[
\boxed{
V(x)
=
P_B(x)
-
\lambda_H P_H(x)
}
\]

默认：

\[
\lambda_H=1.
\]

因为 binary recovery 中：

```text
Beneficial = +1
Harmful    = -1
Neutral    = 0
```

所以在固定 computation budget 下：

> \(V(x)\) 越大，越值得优先执行 fallback。

成本本身不塞进这个 score，因为 C2 是在：

```text
给定 fallback budget
```

的前提下比较 allocation efficiency。

---

# 5. Practical inputs

Primary C2 model **只使用 fallback 之前就能看到的 Cheap observables**：

```text
cheap_prominence
cheap_entropy
cheap_second_to_first
```

不使用：

```text
Gamma
Lambda
true q
weak_ratio
signed separation
SNR
fallback prominence
fallback q
fallback residual energy
```

这些量要么是 oracle diagnostic，要么只有 fallback 算完后才知道，不能作为 practical allocation input。

---

# 6. 为什么先只用 3 个 feature

B3/B4 已经证明：

> feature 越堆越多，并不自动带来跨 cell 泛化。

所以 C2 第一轮刻意只保留：

- peak prominence；
- curve entropy；
- second/first peak ratio。

先回答：

> **改变 learning target 本身，是否已经比原来的 failure-confidence threshold 更有效？**

如果答案是否定的，再考虑引入新的 strong-stage / sequential-history observables。

---

# 7. 两个 learned model

## Linear Value Model

输入：

\[
[prominence,\ entropy,\ second/first]
\]

分别估计：

\[
P_B,\quad P_H.
\]

---

## Quadratic Value Model

在相同三个实际 observable 上增加：

- square terms；
- pairwise interactions。

即：

\[
x_i^2,\qquad x_ix_j.
\]

目的不是堆复杂 AI，而是测试：

> 这些 observable 是否存在简单的非线性互补关系？

仍然只是透明的小模型。

---

# 8. Leave-One-Cell-Out

每次完整留下一个 parameter cell：

```text
8 cells -> fit P_B / P_H
1 cell  -> test
```

标准化、logistic fitting 和 budget threshold 全部只从 training cells 得到。

这避免：

```text
同一个 cell 的 500 trials
随机拆 train/test
```

带来的严重同分布泄漏。

---

# 9. Budget allocation

C2 的核心不再只是 ROC。

给定：

\[
10\%,\ 25\%,\ 50\%
\]

或者完整：

\[
0\%-100\%
\]

fallback budget，

只给 score 最高的 residual states 执行 fallback。

实际 policy 采用：

\[
\boxed{
\text{trigger}
\Rightarrow
\text{directly use fallback}
}
\]

不再使用 C1 的 post-fallback prominence selector。

这是由 C1.1 直接支持的简化。

---

# 10. 对照 policy

C2 比较：

### Prominence

```text
低 prominence 优先 fallback
```

即 C1/C1.1 baseline。

### Entropy

```text
高 entropy 优先 fallback
```

### Linear Value

\[
P_B-P_H
\]

### Quadratic Value

带简单二阶关系的：

\[
P_B-P_H
\]

### Oracle

真正知道 Beneficial label 的理想 allocation。

### Random Expected

相同预算下随机分配 fallback 的期望表现。

---

# 11. C2 最核心的图

## Beneficial Capture vs Budget

\[
\boxed{
\text{在给定计算预算下，真正 rescuable trials 找到了多少？}
}
\]

这是 C1.1 已经证明的主瓶颈。

---

## Recovery Recall vs Budget

最终：

\[
\boxed{
\text{Weak Recovery--Computation Pareto}
}
\]

---

## Benefit Precision vs Budget

\[
\boxed{
\text{花出去的 fallback budget 有多少真的值得？}
}
\]

---

## Harmful Allocation vs Budget

判断：

> value model 是否在提高 rescue capture 的同时避免把 fallback 投给 Cheap 已经正确、但 Fallback 会失败的状态。

---

# 12. 一个非常重要的 Random baseline

随机触发比例为：

\[
b
\]

时，期望 Recall 是：

\[
R_{\rm random}(b)
=
R_C
+
b
\left(
P(B)-P(H)
\right).
\]

因此如果 learned policy 只比 Random 稍好：

> benefit target 没有 practical value。

如果明显优于 Random 和 Prominence：

> C2 才算真正成功。

---

# 13. C2 成功判据

## Strong GO

在 LOCO 下：

1. Value model 的 Beneficial Capture 明显高于 Prominence；
2. 同预算 Recall 明显提高；
3. Harmful trigger fraction 不明显恶化；
4. 25% 左右预算下向 Oracle 靠近明显；
5. Quadratic model 若优于 Linear，说明有简单非线性互补信息。

这时可以继续：

> 新增 strong-stage / sequential-history practical observables。

---

## Partial GO

Value model AUC 或 capture 有提升，但 budget-Pareto 提升很小。

说明：

> target 改对了，但现有 Cheap curve observables 信息仍然不足。

下一步应该增加**新的信息源**，而不是增加模型复杂度。

优先考虑：

- strong removed-energy fraction；
- strong fit residual；
- previous-stage confidence；
- stage number；
- sequential residual-energy history；
- previous q / amplitude stability。

---

## NO-GO

Linear / Quadratic Value 都不优于 Prominence。

说明：

> 仅靠当前 weak residual curve，无法更精确预测 fallback value。

那 C2 的下一版应直接采集 strong-stage observables。

仍然不应直接跳到深度学习。

---

# 14. AI 的判断标准

只有当：

```text
simple value target + multiple practical observables
```

已经显示明显互补性，但：

```text
linear / quadratic mapping
```

利用不充分时，

才值得尝试：

- small tree；
- shallow MLP；
- raw 1-D FrAc curve encoder。

否则不因为“AI 可能更强”而改变主线。

---

# 15. 输出

```text
benefit_feature_audit.csv
loco_score_diagnostics.csv
loco_value_scores.csv

budget_policy_curves.csv
reported_budget_points.csv
value_score_calibration.csv

cell_value_diagnostics.csv
summary.txt
exp09c2_results.mat
```

---

# 16. 主要图

```text
fig01_value_composition_by_cell.png
fig02_feature_value_auc.png
fig03_loco_score_auc.png
fig04_value_score_calibration.png
fig05_beneficial_capture_vs_budget.png
fig06_quality_cost_pareto.png
fig07_benefit_precision_vs_budget.png
fig08_harmful_allocation_vs_budget.png
fig09_policy_comparison_25pct.png
```

---

# 17. 推荐目录

```text
papers/
└── Xu2025_Adaptive_Fast_Refocusing/
    ├── code/
    │   └── exp09_pilot01/
    │       ├── exp09c2_benefit_aware_allocation.m
    │       └── config_exp09c2.m
    └── results/
        └── exp09_pilot01/
            └── exp09c2_benefit_aware_allocation/
```

---

# 18. 运行

```matlab
cd <...>/Xu2025_Adaptive_Fast_Refocusing/code/exp09_pilot01
results = exp09c2_benefit_aware_allocation;
```

C2 不重新做信号级 FrAc Monte Carlo，所以理论上会比 B/C1 信号实验快很多，主要耗时来自 LOCO logistic fitting。
