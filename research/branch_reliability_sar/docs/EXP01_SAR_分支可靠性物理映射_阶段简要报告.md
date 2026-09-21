# EXP01：SAR 分支可靠性物理映射阶段简要报告

## 1. 实验目的

EXP01 的目标不是继续扩展 EXP009–EXP011 已冻结的算法，而是回答一个新的验证问题：

> **此前在信号域 / 搜索域发现的 branch failure 与 reliability-aware recovery，是否能够自然映射到具有真实 SAR 成像物理意义的复杂运动舰船场景中？**

因此，本阶段重点考察以下链路：

\[
\text{舰船运动}
\rightarrow
\text{斜距与残余相位}
\rightarrow
\text{SAR失焦}
\rightarrow
\text{MC-LFM信号状态}
\rightarrow
\text{branch geometry}.
\]

其中 G0、Neighbor-3 只作为机制审计工具；冻结的 Proposed scheduler 在这一阶段始终未参与场景调节或结果筛选。

---

## 2. Stage-A：SAR 物理成像基础

首先建立了由离散舰船散射点、真实运动轨迹、斜距历程、距离压缩复回波及 stationary-reference BP 构成的 SAR 物理仿真链。

静止目标能够正常聚焦，而 yaw 运动目标自然产生明显的空间变化失焦。与此同时，指定 strong/weak 散射点的残余相位能够被二次相位模型高精度描述：

- Strong quadratic-fit NRMSE ≈ 0.00617；
- Weak quadratic-fit NRMSE ≈ 0.00441；
- 两者 \(R^2\) 均接近 1。

因此得到：

\[
\boxed{
\text{舰船运动}
\rightarrow
R_p(\eta)
\rightarrow
\Delta\phi_p(\eta)
\rightarrow
\text{空间变 SAR 失焦}
}
\]

并确认当前短孔径条件下使用 MC-LFM / quadratic residual phase 模型具有物理依据。

**结论：Stage-A PASS / CLOSED。**

---

## 3. Stage-B：SAR 物理信号到搜索域的接口验证

随后从真实 SAR forward model 中提取同一距离单元内的复数 aperture history，并映射到 EXP009/010 使用的 sampled MC-LFM 参数：

\[
(a,\beta,\nu).
\]

关键结果：

- 物理数据网格提取信号与 exact forward signal 的复相关系数约为 0.9991；
- 指定 P4/P7 pair 与完整信号的复相关系数约为 0.9940；
- Strong sampled-LFM phase-fit NRMSE ≈ 0.00138；
- Weak sampled-LFM phase-fit NRMSE ≈ 0.00106。

说明：

\[
\boxed{
\text{SAR physical history}
\rightarrow
\text{EXP009/010 signal/search domain}
}
\]

这一接口成立。

但 canonical P4/P7 状态下 G0 与 Neighbor-3 均稳定，没有出现 branch catastrophe。

由此得到第一个重要 SAR-level 认识：

\[
\boxed{
\text{明显 SAR 失焦}
\not\Rightarrow
\text{branch search 不可靠}
}
\]

**结论：Stage-B PASS / CLOSED。**

---

## 4. Stage-B2：Signal-space hard state 的物理可实现性检查

Stage-B2 从既有 EXP010-B 中预先选择了一个已经确认满足

\[
G0\ failure
\rightarrow
N3/Proposed\ rescue
\]

的 DenseRisk hard state，并尝试在 yaw-only SAR physical family 中进行逆向物理实现。

结果表明：

- fractional \(\nu\) 能较好对齐；
- physical \(\beta_s,\beta_w\) 与目标分别存在约 \(0.643W_\beta\) 和 \(0.745W_\beta\) 的偏差；
- physical-to-signal translation gate 未通过；
- 物理场景中的 G0 与 N3 均产生约 0.183 bin 误差；
- Neighbor-3 未发生 rescue。

进一步分析表明，这一物理状态主要表现为：

\[
\text{coherent mixture}
\rightarrow
\text{continuous optimum displacement},
\]

而不是此前理论中的：

\[
\text{correct continuous branch}
\rightarrow
\text{coarse-ranking inversion}.
\]

因此它并不是 selective Neighbor-3 所针对的同一种 failure mechanism。

**结论：指定 DenseRisk hard state 未能被 yaw-only SAR family 忠实实现；Stage-B2 按预注册 Stop Rule 关闭。**

---

## 5. Stage-B3：Yaw-only 自然 target-line 审计

为避免人为构造 hard case，随后直接对 canonical yaw scene 中自然选出的 SAR target range lines 进行统一机制分类。

按照 moving BP line energy > mean 的规则，从 81 个 range lines 中选出 25 条目标 line。最终分类为：

\[
E=25,\qquad
B=D=G=U=0.
\]

即：

- 全部属于 Easy / stable 状态；
- 没有 discrete-first branch failure；
- 没有 N3 rescue case。

最高 G0 error 约为 0.0354 bin。

因此 yaw-only 物理场景进一步支持：

\[
\boxed{
\text{复杂运动和明显失焦}
\neq
\text{branch-vulnerable state}.
}
\]

**结论：canonical yaw-only scene 中未观察到自然 D-class；该场景关闭。**

---

## 6. Stage-B4：文献锚定 3D 刚体摆动验证

最后将运动模型扩展为文献锚定的 roll + pitch + yaw 三维刚体摆动，但保持以下内容不变：

- SAR 系统参数；
- scatterer layout；
- target-line selection；
- taxonomy；
- G0 / Neighbor-3 定义；
- 不进行参数 sweep；
- 不进行 scene retuning；
- 不运行 Proposed scheduler。

3D 摆动后，quadratic / MC-LFM 模型仍保持良好：

- scatterer-level quadratic-fit NRMSE 中位数约 0.00619；
- 最大约 0.0168；
- 自然选出的 25 条 target line 中无模型异常。

最终分类结果：

\[
E=24,\qquad
G=1,\qquad
D=0.
\]

其中唯一 G-class line：

\[
\nu_{\rm strong,ref}\approx -4.6436,
\]

\[
\nu_{\rm mix,global}\approx -4.3337,
\]

二者相差约：

\[
0.3099\ \text{bin}.
\]

同时：

\[
\nu_{\rm G0}
=
\nu_{\rm N3}
=
\nu_{\rm mix,global}.
\]

因此这属于：

\[
\boxed{
\text{continuous global-winner change}
}
\]

而不是：

\[
\boxed{
\text{discrete-first branch failure}.
}
\]

Neighbor-3 无法恢复符合当前理论预期，并不表示 N3 实现失败。

**结论：完整 3D rigid-body simulation 中仍未观察到自然 N3-rescuable D-class。按照预注册规则，controlled rigid-body simulation 到此关闭。**

---

## 7. 当前形成的核心认识：Signal-space Hard State 与 SAR Physical State

目前可以将 signal-space hard state 与 SAR physical state 区分为两个空间。

定义信号域状态：

\[
\mathbf h=
(\beta_s,\beta_w,\nu_s,\nu_w,r_A,\Delta\phi,\ldots),
\]

以及 SAR 物理状态：

\[
\boldsymbol\theta=
(\text{motion},
\text{scatterer geometry},
\text{SAR geometry},
\text{aperture},\ldots).
\]

二者通过 SAR forward mapping：

\[
\mathbf h=F(\boldsymbol\theta)
\]

联系。

因此真正具有 SAR 工程意义的 branch-vulnerable 状态应属于：

\[
\boxed{
\mathcal H_{\rm phys}
=
\mathcal H_{\rm branch}
\cap
\mathcal M_{\rm SAR}.
}
\]

也就是说：

> **信号域 hard state 并不天然等价于 SAR 物理可实现状态；其实际意义取决于目标运动、散射几何和 SAR 成像条件所诱导的 physical manifold 是否进入 branch-vulnerable region。**

这一认识目前应作为：

- Claim 边界；
- 结果解释；
- Discussion / Limitation；
- 后续研究启发；

而不应扩展为新的主研究方向。

---

## 8. 对当前论文 Claim 的影响

### Claim 1：Failure Mechanism

仍然成立，但应明确属于：

\[
\boxed{\text{conditional mechanism claim}}
\]

而不是“真实 SAR 中某种 failure 的发生概率”结论。

因此此前 stress grid 中的 failure fraction 不能解释为实际舰船 SAR failure probability。

### Claim 2：Reliability-aware Selective Recovery

仍然成立，其准确含义应是：

> 当 processing unit 已进入 branch-vulnerable regime 时，选择性 Neighbor-3 能以低于 Always-N3 的计算代价提高 branch reliability。

不能扩展为“复杂运动舰船普遍需要 selective-N3”。

### SAR-level Translation

目前已经验证：

\[
\text{SAR physics}
\rightarrow
\text{MC-LFM representation}
\]

成立，但尚未得到自然：

\[
D
\rightarrow
N3\ rescue
\rightarrow
\text{weak structure recovery}
\rightarrow
\text{image gain}.
\]

因此该部分当前应标记为：

\[
\boxed{\text{尚未闭合，而非被否定。}}
\]

---

## 9. 当前阶段总结

EXP01 的 controlled simulation 已完成其主要任务：

\[
\text{物理 SAR 成像链建立}
\quad\checkmark
\]

\[
\text{SAR}\rightarrow\text{MC-LFM 接口建立}
\quad\checkmark
\]

\[
\text{yaw-only natural branch audit}
\quad\checkmark
\]

\[
\text{3D swing natural branch audit}
\quad\checkmark
\]

\[
\text{人为继续制造 hard case}
\quad\boxed{\text{停止}}
\]

因此后续实验不应继续增加新的模拟运动类型，而应升级验证真实性层级。

---

## 10. 下一阶段建议

下一阶段优先进入：

\[
\boxed{
\text{公开 / 真实 complex SAR ship data}
}
\]

首先不强求直接证明 Proposed 的 image-level gain，而是先回答：

> **真实复杂运动舰船 SLC 中是否自然存在与当前 branch-vulnerable geometry 相符的 processing units？**

推荐的最小验证链为：

\[
\text{real SAR target-line pool}
\rightarrow
\text{MC-LFM / branch geometry audit}
\rightarrow
\text{是否存在 D-like state}
\]

若真实数据中出现有物理意义的 branch-vulnerable processing units，再继续：

\[
\text{Frozen Proposed}
\rightarrow
\text{weak structure recovery}
\rightarrow
\text{SAR image-level gain}.
\]

若真实数据中仍未出现，则应重新评估 selective-N3 的实际发生频率与应用范围，而不是继续通过仿真制造正结果。





==EXP001 已经包含了基本的 3D rigid-body + SAR LOS slant-range physics，但仍采用了较理想的短 CPI、固定散射中心和确定性刚体运动模型。它证明了“3D 复杂运动 + 明显失焦”本身不足以自然产生 discrete-first branch failure。更真实的有效观测几何、时变散射以及非平稳长时运动是否会把 physical manifold 推入 D-class，目前仍是开放问题。==
