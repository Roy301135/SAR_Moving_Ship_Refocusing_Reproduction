# EXP009-C1.1 — Policy Loss Decomposition

## 1. 目的

C1 已经证明：

- fallback 本身很强；
- Oracle adaptive 空间很大；
- Practical prominence gate 已经产生真实 Quality–Cost gain；
- 但 Practical 与 Oracle 之间仍然有明显差距。

C1.1 不再重新跑信号级 Monte Carlo，而直接读取：

```text
EXP009-C1/
└── c1_branch_trials.csv
```

把 Practical–Oracle gap 分解成：

\[
\boxed{
\text{Allocation Loss}
+
\text{Branch-Selection Loss}
}
\]

---

## 2. 为什么要做这个分解

当前 practical policy 有两个步骤：

```text
1. cheap prominence 低
   -> trigger fallback

2. fallback 运行以后
   -> 若 fallback prominence 更高
      才采用 fallback branch
```

所以 Practical 比 Oracle 差，可能有两个完全不同的原因。

### Allocation error

真正能够被 fallback 救回来的 trial：

```text
cheap fail
fallback success
```

根本没有被 trigger。

---

### Branch-selection error

trial 已经被 trigger，而且 fallback 实际能救回来，但：

```text
fallback prominence <= cheap prominence
```

导致当前 selector 仍然保留 cheap branch。

这两类误差对应完全不同的后续研究方向。

---

## 3. Beneficial / Harmful fallback

定义：

### Beneficial

\[
\neg S_C \land S_F
\]

即：

```text
cheap failure
fallback success
```

---

### Harmful

\[
S_C \land \neg S_F
\]

即：

```text
cheap success
fallback failure
```

---

## 4. 同一个 Practical Trigger 下比较三个 Selector

保持：

```text
cheap prominence <= threshold
```

这一 trigger set 完全不变。

然后比较：

### Selector A — Always fallback

只要 trigger：

```text
直接采用 fallback
```

---

### Selector B — Prominence selector

当前 C1 规则：

```text
fallback prominence > cheap prominence
    -> fallback
else
    -> cheap
```

---

### Selector C — Oracle selector

只用于诊断：

```text
trigger 后，哪个 branch 正确就选哪个
```

它给出了：

> **在当前 practical trigger set 不变的情况下，理论上最多能达到什么 Recall。**

所以它是 allocation ceiling。

---

## 5. Gap decomposition

定义：

\[
R_O
=
\text{Oracle union recall}
\]

\[
R_T
=
\text{Practical trigger + Oracle selector}
\]

\[
R_P
=
\text{当前 Practical trigger + prominence selector}
\]

则：

\[
R_O-R_P
=
(R_O-R_T)
+
(R_T-R_P).
\]

其中：

\[
\boxed{
R_O-R_T
=
\text{Allocation Loss}
}
\]

表示：

> rescuable trials 没有被 practical trigger 覆盖。

而：

\[
\boxed{
R_T-R_P
=
\text{Selector Loss}
}
\]

表示：

> trigger 已经覆盖到了，但 prominence selector 没有正确使用 fallback。

---

## 6. 最值得关注的量

### Beneficial allocation capture

\[
\frac{
\#(\text{beneficial AND triggered})
}{
\#(\text{beneficial})
}
\]

回答：

> 全部真正值得 fallback 的 trial，Practical gate 找到了多少？

---

### Benefit precision among triggers

\[
\frac{
\#(\text{beneficial AND triggered})
}{
\#(\text{triggered})
}
\]

回答：

> 实际花出去的 fallback budget 里，有多少真的花在“可救回”样本上？

---

### Selector rescue capture

只考虑：

```text
beneficial AND triggered
```

再看：

> prominence selector 最终有多少次真的采用了 fallback？

---

## 7. 一个尤其重要的比较

C1 已经出现：

```text
Fallback-only recall
>
Always-extra + prominence selector recall
```

因此 C1.1 会直接测试：

```text
Practical trigger -> always fallback
```

是否优于：

```text
Practical trigger -> prominence selector
```

如果：

\[
R_{\rm always}
>
R_{\rm prominence}
\]

那么说明：

> prominence 适合做 trigger risk signal，
> 但不适合做 post-fallback branch selector。

此时后续方法应简化成：

```text
trigger -> fallback
```

而不是再做第二次 branch confidence 比较。

---

## 8. 不需要重新跑 C1

只需要保留 C1 的：

```text
c1_branch_trials.csv
policy_curve_prominence.csv
```

默认目录：

```text
results/
└── exp09_pilot01/
    └── exp09c1_adaptive_budget/
```

如果目录不同，在：

```matlab
config_exp09c1_1.m
```

中设置：

```matlab
cfg.c1_result_dir = '你的 C1 结果目录';
```

---

## 9. 运行

```matlab
cd <...>/Xu2025_Adaptive_Fast_Refocusing/code/exp09_pilot01
results = exp09c1_1_policy_loss_decomposition;
```

---

## 10. 输出

```text
matched_policy_summary.csv
loss_summary.csv
policy_loss_decomposition_curve.csv
summary.txt
exp09c1_1_results.mat
```

---

## 11. 主要图

```text
fig01_same_trigger_selector_comparison.png
fig02_gap_decomposition.png
fig03_selector_recall_vs_budget.png
fig04_allocation_quality_vs_budget.png
fig05_selector_quality.png
fig06_matched_targeting_diagnostics.png
```

---

## 12. 后续判断

### Case A — Allocation loss 占主导

说明：

```text
fallback 很好
selector 也还行
但 gate 没找到真正 rescuable trial
```

后续 C2 应直接研究：

\[
\boxed{
P(\text{fallback beneficial}\mid \text{observable state})
}
\]

也就是 Benefit-aware Computation Allocation。

---

### Case B — Selector loss 占主导

说明：

```text
gate 已经找到困难 trial
但 post-fallback branch selection 逻辑错误
```

后续优先修 selector。

---

### Case C — Always-fallback 明显优于 prominence selector

说明最简单的 practical rule 可能就是：

```text
low-confidence trigger
    -> run fallback
    -> directly accept fallback
```

这反而更简洁，也更适合小论文方法设计。
