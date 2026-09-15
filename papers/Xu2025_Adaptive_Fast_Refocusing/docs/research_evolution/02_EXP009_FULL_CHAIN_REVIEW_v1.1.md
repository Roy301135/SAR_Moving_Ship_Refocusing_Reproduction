# EXP009 / Pilot-01 至 PA5J-B3-R2：实验工作全链路复盘与论文收敛审计

> 项目：复杂运动舰船 SAR 非聚焦 / 顺序重聚焦可靠性  
> 当前阶段：从 discovery phase 进入 paper-convergence phase  
> 复盘范围：`《非聚焦论文阅读2》`、`EXP009 / Pilot-01-Part1/2/3`、`实验理解助手`、当前 PA5J-B0→B3-R2 实验线，以及项目内相关 handoff / README / results summary  
> 更新时间：2026-09-12
> v1.1 小修：冻结 catastrophic-label 数值来源；将当前 operational semantics 明确为 batch / fixed-compute scheduler；区分 search-level engineering evidence 与尚未闭合的 SAR-level Claim 3；将机制链表述从“必然逐级因果链”收紧为“相互作用的失效层”。

---

## 0. 这份文档解决什么问题

这份复盘不是简单罗列“做过哪些实验”，而是回答四个更重要的问题：

1. **我们一开始为什么会做 EXP009？**
2. **EXP009 内部为什么会从 weak-component recovery 一路走到 branch reliability / adaptive computation？**
3. **哪些发现是真正改变研究方向的关键节点，哪些只是必要的验证与排错？**
4. **到 PA5J-B3-R2 为止，论文真正可以稳定下来的核心价值是什么，后续还缺什么，哪些实验应当停止继续扩展？**

为了避免把历史探索结果过度包装成最终结论，本文把证据分成四类：

- **[Mechanism]**：解释“为什么会失败”的机制性证据；
- **[Method]**：解释“如何利用该机制改善算法”的方法性证据；
- **[Audit]**：排除替代解释、代码漂移或比较不公平的审计性证据；
- **[Pending]**：当前仍未闭合、必须留到后续验证的部分。

> **证据使用原则**  
> 本文只写入当前对话记录、项目 handoff、README、summary 和正式结果中已经支持的内容。  
> 对于早期实验中未能从现有记录恢复出精确数值的部分，保留实验角色与方向性结论，不补造数值。

---

# 1. 一句话总览：EXP009 到底从哪里走到了哪里

如果把全部实验压缩成一条主线，可以写成：

```text
Xu 2025 / Wang 2023 复现
    ↓
快速局部 ORO tracking 虽省算力，但局部失效会传播
    ↓
EXP07/08：即使全局 entropy 看起来不错，也可能漏掉弱分量
    ↓
EXP009：弱分量到底从 sequential refocusing 的哪一步开始丢失？
    ↓
finite-window / off-grid / fence leakage
    ↓
strong subtraction mismatch
    ↓
coherent strong–weak perturbation
    ↓
local continuous bias
    ↓
global branch switching / rare catastrophic failure
    ↓
内部 reliability state 是否能提前看见这种失败？
    ↓
Refined-LR 抓 observable core
    ↓
Cost-0 指标在 residual pool 仍保留额外信息
    ↓
naive simultaneous fusion 会发生 rank dilution
    ↓
staged reliability allocation
    ↓
selective Neighbor-3
    ↓
真实 cost–reliability Pareto improvement
    ↓
dense comparator audit 后优势仍存在但显著收缩
    ↓
同一 staged policy 跨 Paper1s / BeamDerived 仍能保留正收益
    ↓
当前：POLICY FREEZE / paper convergence
```

真正发生变化的，不只是“我们找到了一个更好的 gate”，而是研究问题本身从：

> **如何更快地做 FrFT / FrAc 搜索？**

逐步转成了：

> **如何识别 rare catastrophic search failure，并把有限计算预算只花在真正危险的 trial 上？**

这就是当前小论文最核心的研究价值。

---

# 2. EXP009 之前：为什么 Xu 2025 复现最终会把我们带到 reliability 问题

EXP009 并不是凭空出现的。它来自 `《非聚焦论文阅读2》` 中对 Xu 2025 AFRA 的复现与扩展。

---

## 2.1 EXP01：先确认最基础的 LFM → FrFT/FrAc 聚焦链条

早期 EXP01 的任务很简单：

> 在最干净的单分量 residual LFM 上，验证理论 order、熵最优 order、峰值最优 order 是否一致。

已有记录中：

- theoretical order ≈ `1.557716`
- entropy estimate ≈ `1.558000`
- peak estimate ≈ `1.559000`
- wrong / optimal entropy ≈ `4.001108 / 1.809682`
- peak-energy concentration ≈ `0.028636 / 0.259186`

这一步的作用不是创新，而是建立可信的数值地基：

\[
\text{quadratic phase}
\rightarrow
\text{linear STFT ridge}
\rightarrow
\text{FrFT concentration}
\]

能够被我们自己的仿真链正确复现。

---

## 2.2 EXP04–EXP06：从“快搜索”转向“可靠的自适应搜索”

在 Xu 2025 的 fast local search 思路中，核心是：

- 最强方位线做较完整搜索；
- 邻近方位线复用上一条 ORO；
- 只在小 tracking window 内局部搜索。

### EXP04：平滑 ORO 场中的效率收益

**问题：**

> 如果真实 ORO 在方位线上平滑变化，小 tracking window 是否足够？

结果说明：

- fixed-small \(\Delta\) 很省 FrFT 调用；
- 在平滑场景下精度可维持；
- 但这只证明了“理想平滑情况下的效率”，并没有证明突变情况下稳健。

这一步第一次把：

\[
\text{Fast}
\leftrightarrow
\text{Fine}
\]

明确变成了：

\[
\text{quality–cost trade-off}
\]

而不是单纯“谁更准”。

---

### EXP05：固定 window 在突变 ORO 下为什么会坏

后续把 abrupt ORO jump、弱能量区域、噪声等困难因素加入。

关键发现：

> 当真实 ORO 离开固定 tracking window 时，FrAc 峰会逼近甚至命中搜索边界。

此后出现：

\[
\text{边界命中}
\rightarrow
\text{局部搜索滞后}
\rightarrow
\text{错误 prior 传给下一条方位线}
\rightarrow
\text{误差传播}
\]

这里最重要的新概念是：

> **boundary hit 可以作为在线不可靠性警报，但 boundary hit 本身不等于一定估错。**

这为后面 EXP009 的“internal reliability state”埋下了第一颗种子。

---

### EXP06：Boundary-aware Adaptive \(\Delta\)

进一步设计：

\[
\Delta:
0.01\rightarrow0.02\rightarrow0.04\rightarrow0.08
\rightarrow\text{full-search fallback}
\]

只有当局部 FrAc 峰逼近搜索边界时才扩窗。

结果说明：

- 在大 jump 下能接近 Wide / Full 搜索的 ORO 精度；
- 平滑区域仍保持接近 FixedSmall 的低成本；
- 但这仍然只是 **mechanism-level proof-of-concept**，不能直接宣称已经得到通用可靠性理论。

### 这一阶段真正的研究启发

EXP04–06 把问题从：

> “怎样把 FrFT 做快？”

改写成：

> “怎样根据内部不可靠性把额外计算预算只分配给困难样本？”

后来 PA5J 的 reliability-gated Neighbor-3，本质上就是这个思想在更深层 global branch failure 上的延续。

---

## 2.3 EXP07：全局 focus metric 好，不等于分量完整

EXP07 开始从 dominant ORO tracking 往 multi-component recovery 推进。

主要发现：

1. ORO mismatch 会降低 FrFT concentration；
2. mismatch 会抬高 residual MC-LFM energy；
3. 如果遗漏 weak ORO：
   - weak component 会留在 residual；
   - residual energy 上升；
   - residual 与 weak component correlation 上升。

最关键的发现是：

> **低 image entropy 可以和“漏掉弱分量”同时存在。**

也就是说：

\[
\text{good global focus}
\not\Rightarrow
\text{component completeness}
\]

这是后来 EXP009 研究 weak recoverability 的直接动机。

---

## 2.4 EXP08：二维 ship-like MC-LFM 中“一谱多峰”并不可靠

EXP08 进一步构造：

- strong / mid / weak 三分量；
- spatially varying ORO；
- abrupt jump；
- weak-energy region；
- noise。

结果：

> `One FrAc spectrum → three peaks` 的想法在复杂条件下并不稳定。

而 sequential search / CLEAN 对 weak recovery 更有帮助。

这一步让瓶颈从：

> dominant ORO tracking

正式转向：

> **第二、第三个弱 ORO 是否能被可靠恢复。**

---

# 3. EXP009 最初的研究问题：弱分量究竟从哪里开始坏

EXP009 / Pilot-01 的最初问题可以压缩成：

> **Where does weak-component failure first enter the sequential MC-LFM refocusing chain?**

最初并没有一上来就做 reliability gate。

反而先建立了一个 **oracle ladder**，用来逐层拆解 sequential strong-removal → weak-recovery 的失效来源。

---

# 4. EXP009 初期：Normalized Discovery / Oracle Ladder

这一条历史支线非常重要，因为它定义了后面 Physical Validation 要回答的问题。

---

## 4.1 L0–L3 Oracle Ladder

初始控制案例中曾固定：

- \(N=512\)
- SNR = 3 dB
- \(q_s=1.420\)
- \(q_w=1.470\)
- \(A_w/A_s=0.40\)
- full grid step = 0.001
- success tolerance = 0.003
- local half-width = 0.015

四层含义：

### L0 — Exact strong subtraction

用真值精确删除 strong，再 full-search weak。

这是“最理想上界”。

### L1 — Strong-\(q\) error only

只引入 strong 参数估计误差，其余尽量 oracle。

回答：

> 仅仅 strong 参数轻微误差是否足够让 weak recovery 崩溃？

### L2 — Practical CLEAN + full weak search

执行：

```text
dechirp
→ FFT
→ local notch
→ IFFT
→ rechirp
→ full weak search
```

开始真正让 practical operator 进入链路。

### L3 — Practical CLEAN + valid local prior

和 L2 使用相同 residual，只限制 weak 的搜索范围。

用于区分：

\[
\text{residual/operator problem}
\]

和：

\[
\text{search-range problem}
\]

历史记录中，L3 candidate evaluations 约比 L2 低 42%，说明合理 local prior 可以省成本，但无法替代对 residual mechanism 的理解。

---

## 4.2 A3 / A4：strong residual 会“拉” weak peak

随后实验开始发现：

> weak peak 的偏移并不只是 random noise，也不只是“strong 没删干净导致底噪升高”。

关键是 **coherent residual**。

对于：

\[
C(q)=C_w(q)+C_e(q)
\]

功率：

\[
P(q)=|C(q)|^2
=
|C_w|^2+|C_e|^2
+
2\operatorname{Re}\{C_wC_e^*\}
\]

最后一项是 coherent cross term。

在 weak 真值附近，峰值的一阶偏移可写成：

\[
\delta_q
\approx
-\frac{\Delta P'(q_w)}{P_w''(q_w)}
\]

通过把 strong 放到 weak 左右镜像位置，weak shift 的符号也会发生对应反转。

### 这里第一次明确：

\[
\text{strong residual}
\neq
\text{只抬高 noise floor}
\]

它会直接改变 weak 的局部目标函数几何。

---

## 4.3 C3-B3B.1：为什么早期已经碰过 noise，但后来没有继续扫 SNR

历史 normalized Pilot 里曾把 SNR 固定在 3 dB，准备做：

- weak/noise reshaping；
- strong residual coherent geometry；
- operator reshaping；
- residual/noise perturbation 的 interaction ownership。

当时明确规定：

> 在 ownership decomposition 没做清楚以前，不应急着扫 SNR、加 history/sub-aperture、改 CLEAN width 或引入 learned model。

这条原则和我们现在的论文收敛策略是一致的。

后来 Physical Validation 线为了先把确定性的物理机制闭合，选择暂时不把 noise 作为主变量。

因此：

- 早期“固定 3 dB 的 normalized discovery”；
- 当前“无噪声 Physical Validation”；

不是互相冲突，而是两个不同层级的问题。

---

# 5. 为什么后来必须新建 Physical Validation Track

随着 Pilot-01 深入，一个问题越来越明显：

> 如果继续完全依赖 normalized \(q\)-space proxy，我们可以看到现象，却很难证明它确实对应 Wang/Xu 舰船重聚焦中的真实物理尺度。

因此项目正式采用“两轨道”：

### Track A — 历史 normalized discovery

用于：

- 快速机制发现；
- oracle decomposition；
- failure taxonomy；
- 局部数学规律。

### Track B — `exp09_physical_validation`

用于：

- 回到 Wang / Xu 参数；
- 用物理 chirp-rate / finite-aperture 支撑；
- 做 paper-ready validation。

从此以后，Track B 成为当前论文主验证线。

---

# 6. Physical Validation 前半段：先证明“问题真的存在于物理尺度”

---

## 6.1 P0 — Xu velocity → ORO calibration

目的：

> 先确认 Xu 文中 velocity / ORO / aperture 参数之间能否建立一致的数值尺度。

复现得到约：

\[
[-0.415,-0.457,-0.500,-0.534,-0.583]
\]

同时：

- \(N_a\approx1211.80\)
- best integer \(N_a=1233\)
- median ORO error ≈ 0.00670

最终状态：

> `PASS_WITH_PUBLICATION_INCONSISTENCY`

也就是说：

- 主关系可以复现；
- 但公开论文内部部分参数存在无法完全闭合的不一致。

### 价值

这一步非常重要，因为它阻止了我们把“论文参数不一致”误判成自己代码错误。

---

## 6.2 P1 — Wang physical baseline

固定 Wang 2023 相关参数：

- \(f_c=3\) GHz
- PRF = 188 Hz
- \(B=150\) MHz
- \(H=3\) km
- platform speed = 150 m/s
- antenna length = 2 m
- \(v_a=\{5,10,15,20,25\}\) m/s

进一步在：

- \(R_0/H\in\{1,\sqrt2,2\}\)
- \(N_a\in\{256,512,1024\}\)
- 200 phase trials

上检查 residual chirp 的可分辨性。

代表性条件 \(R_0/H=\sqrt2,N=512\) 下：

\[
K_{\rm SAR}\approx106.066\ {\rm Hz/s}
\]

目标对应的 residual chirp rates 约为：

\[
[51.24,49.38,47.47,45.50,43.47]\ {\rm Hz/s}
\]

代表性场景下 all-five phase-MC detection 可达到 1，但所有 scenario 合并 pass fraction 只有约 0.556。

### 结论

不能简单说：

> “五个分量在物理上天然都能稳定分开。”

而必须承认：

\[
\text{可分辨性取决于 aperture / geometry / finite support}
\]

---

## 6.3 P1B / P1C — 仅靠更理想的间隔并不能解决 finite-aperture 问题

P1B 继续检查：

> 当 aperture 有限时，五分量是否还能稳定同时分辨？

结果是否定的。

P1C 又检查：

> 增大中心频率间隔是否能补救？

结果仍然不能根本解决。

### 这两步的作用

它们迫使研究从：

> “峰离得不够远”

转向：

> **finite aperture 下的 response overlap / leakage / coherent interaction**

这才真正进入 PA4–PA5。

---

# 7. PA4：从“是否可分”进入“为什么 weak peak 会偏”

PA4 把复杂五分量问题压缩成可解释的两分量问题，并构造：

- unresolved；
- partial；
- resolved；

等不同 regime。

同时通过 strong 在 weak 左右镜像放置，观察 weak peak 的 signed displacement。

核心数学结构仍然是：

\[
P=|C_w+C_e|^2
\]

而不是：

\[
|C_w|^2+|C_e|^2
\]

因此 cross term 决定了：

- shift 有方向；
- shift 依赖 relative phase / geometry；
- 不是简单的“energy contamination”。

这是 Claim 1 中“coherent mixture perturbation”的直接基础。

---

# 8. PA5 主链：strong removal 为什么会形成 weak recoverability floor

PA5 是整个 EXP009 机制线的核心。

---

## 8.1 PA5 / PA5B / PA5C：strong leakage 与 weak damage 是两个独立量

在 sequential removal 中，引入：

- \(L_s\)：strong residual leakage；
- \(D_w\)：weak waveform damage / loss；
- \(r_A=A_w/A_s\)：weak-to-strong amplitude ratio。

最终得到非常重要的误差恒等式：

\[
\boxed{
E^2
=
\left(\frac{L_s}{r_A}\right)^2
+
D_w^2
}
\]

这说明：

1. strong leakage 会被 \(1/r_A\) 放大；
2. weak 越弱，对 strong residual 越敏感；
3. 即便 weak 本身几乎没有被 notch 损伤，只要 strong residual 没压下去，recoverability 仍会失败；
4. 反过来，过宽的 removal window 虽能压 strong，却会提高 \(D_w\)。

### 于是 sequential strong removal 变成一个真实的 trade-off：

\[
\text{strong suppression}
\leftrightarrow
\text{weak preservation}
\]

而不是“窗口越宽越好”。

---

## 8.2 PA5D：recoverability floor 的解析化

进一步把误差关系变成 floor 条件。

如果 off-grid / finite-window 下 strong leakage 存在不可消除下界：

\[
L_0>0
\]

同时 weak damage 为 \(D_0\)，则 recoverability 要求会诱导：

\[
\boxed{
r_{\min}
=
\frac{L_0}{\sqrt{1-D_0^2}}
}
\]

这意味着：

> weak component 并不是只要 SNR 足够就一定能恢复；在固定 operator / finite window 下，可能存在由 leakage floor 决定的 amplitude-ratio floor。

这是整个 Claim 1 中最有价值的解析结果之一。

---

## 8.3 PA5E：换 peak semantics 也消不掉 half-bin floor

随后检查：

> recoverability floor 会不会只是我们 peak definition / stage detection 的数值语义造成的？

结果显示：

- peak semantics 会改变固定窗口下的具体数值；
- 但无法消除 finite-window / off-grid floor；
- half-bin 附近甚至会出现 best achievable \(E>1\)。

同时分离出：

- \(L_s\) 更多受 discrete support / resolution-cell geometry 控制；
- \(D_w\) 更多受 removal width \(l/N\) 控制。

### 负结果的价值

这排除了：

> “只是 peak picking 定义有问题”

这一替代解释。

---

## 8.4 PA5E-R1：排除 numerical tie artifact

又进一步做 numerical tie-tolerance patch。

目的：

> half-bin floor 会不会只是 floating-point tie / equal-peak 决策不稳定？

结果并未推翻 floor。

因此下一步很自然地问：

> 如果能把 strong 真正 recenter 到 sub-bin 位置，floor 会不会消失？

---

# 9. PA5F：Oracle recenter 是一个决定性的机制实验

PA5F 比较：

- G0 baseline；
- G1 oracle recenter；
- G2 strong-only estimated recenter；
- G3 practical mixture estimate。

结果：

### Oracle recenter

几乎消除：

- recoverability floor；
- strong leakage。

这说明：

\[
\boxed{
\text{half-bin floor 的主要来源确实是 sub-bin miscentering + finite-length leakage}
}
\]

而不是不可解释的 CLEAN 失败。

### Strong-only estimated recenter

显著改善，但仍有 estimator / interpolation bias。

### Practical mixture estimate

误差更大，而且随 weak/strong ratio 增大。

于是问题从：

> “off-grid 怎么办？”

推进到：

> **在 mixture 中 strong 的 sub-bin offset 为什么会被 weak 偏置？**

---

# 10. PA5G：插值 bias 和 mixture-induced bias 被正式拆开

PA5G 使用 continuous ML / LS refinement。

关键结果：

### Strong-only

continuous ML 几乎把 bias 降到 0。

因此：

> 之前 strong-only 的大部分误差确实主要来自插值器，而不是物理不可识别。

### Mixture

即使用 continuous ML，仍存在约：

\[
0.07\sim0.10\ {\rm bin}
\]

级别 bias。

所以：

\[
\boxed{
\text{mixture-induced bias 是真实的}
}
\]

而不是插值误差伪装出来的。

### Evidence gating

BIC + split consistency 相比 always-mixture 更安全，但仍不是 oracle。

这一步开始把：

\[
\text{estimator correction}
\]

和：

\[
\text{是否值得 correction 的 reliability evidence}
\]

连接起来。

---

# 11. PA5H：mixture bias 得到一阶数学模型

PA5H 建立：

\[
\boxed{
\delta_{\rm mix}
\approx
-r
\frac{H'(0)}{J_s''(0)}
}
\]

其中：

\[
r=A_w/A_s
\]

代表 weak-to-strong amplitude ratio。

在低/中 contrast 下：

\[
|\delta_{\rm mix}|
\propto r
\]

并且随 relative phase 呈平滑、近似周期变化。

已有结果：

- \(r=0.1,0.2,0.3\) 时，一阶模型 \(R^2\) 接近 1；
- \(r=0.8\) 时明显变差。

一开始看起来像：

> 高 contrast 下一阶模型 collapse。

但 PA5H-R1 证明事情更复杂。

---

# 12. PA5H-R1：必须区分 local continuous bias 与 global branch switching

高 contrast 下的不连续 / collapse 现象中混入：

- branch switching；
- tie selection；
- global winner change。

因此不能把所有异常都解释成：

> “一阶 perturbation law 在大 \(r\) 下失效”。

真正需要区分：

### Local continuous bias

同一 branch 内，峰位置连续偏移。

### Global branch switching

另一个局部峰成为全局赢家。

这是一个极关键的概念转折：

\[
\boxed{
\text{局部 estimator bias}
\neq
\text{global branch-selection catastrophe}
}
\]

从这里开始，研究自然进入 PA5I。

---

# 13. PA5I / PA5I-R1：从 mechanism 进入 rare-event reliability

PA5I 比较：

- `G0_OriginalTop1`
- `G1_Neighbor3`
- `G2_Top2Coarse`
- `G3_Top3Coarse`
- `G4_GlobalReference`

核心问题：

> G0 的 rare catastrophic branch switch，能不能通过稍微增加 branch candidates 被救回来？

结果非常干净：

### Original

G0：

\[
55\ \text{catastrophic failures}
\]

Neighbor-3：

\[
0
\]

### Dense-risk

G0：

\[
539
\]

Neighbor-3：

\[
0
\]

而且没有：

\[
\text{G0 success}\rightarrow\text{N3 failure}
\]

的 induced catastrophe。

### 但代价很高

平均 objective evaluations 大约从：

\[
\sim43\text{–}44
\]

上升到：

\[
\sim147\text{–}151
\]

量级。

因此得到第一个非常明确的工程问题：

\[
\boxed{
\text{Neighbor-3 很可靠，但 Always-N3 太贵}
}
\]

于是下一问变成：

> 能不能只在“可能失败”的 trial 上调用 N3？

---

# 14. PA5J-A：寻找 cheap internal unreliability indicator

PA5J-A 明确规定：

> 不能把 truth physics 或 global reference 用作 gate。

禁止：

- true \(\eta\)
- global branch error
- true branch
- Gamma / contrast 等只用于 post-hoc 的 truth-state

进入在线 gate。

最终比较出三个关键 observable：

### Refined-LR asymmetry

- Cost-2
- strongest single indicator
- AUC ≈ 0.965（Original）
- AUC ≈ 0.862（Dense-risk）

### FiveBin peak fraction

- Cost-0
- AUC ≈ 0.937 / 0.792

### Local entropy5

- Cost-0
- AUC ≈ 0.919 / 0.788

### 重要负结果

单指标无法在很低 fallback rate 下覆盖全部 catastrophic failures。

于是产生两个 failure types 的直觉：

- **Type A**：local geometry 已经明显不稳定；
- **Type B**：global branch 已错，但 local optimum 看起来仍然“合理”。

这直接推动 PA5J-B。

---

# 15. PA5J-B0：Complementarity Audit

B0 不直接构造最终 gate，而先回答：

> 三个指标到底是冗余，还是互补？

并采用：

- 11 个 threshold-free budgets；
- group-wise ranking；
- tie-inclusive selection；
- pairwise conditional rescue；
- budget-matched union；
- three-way common miss；
- Wilson CI。

这是整个后半段工程严谨性提升的关键节点。

---

## 15.1 Refined-LR 抓住一个 highly observable failure core

DenseRisk 中：

### Paper1s

Refined-LR top 20%：

\[
\text{capture}\approx61.6\%
\]

且：

\[
\text{precision}=100\%
\]

### BeamDerived

top 20%：

\[
\text{capture}\approx47.1\%
\]

同样：

\[
\text{precision}=100\%
\]

说明确实存在：

\[
\boxed{\text{highly observable failure core}}
\]

---

## 15.2 低预算下，简单 union 的“互补收益”很多是假象

在小 budget：

- pairwise OR 的 nominal capture 会提高；
- 但 actual trigger fraction 同时也增大。

一旦做 budget-matched fairness comparison，很多低预算 fusion 反而不如直接把预算给 Refined-LR。

这一步排除了一个非常危险的假结论：

> “多指标 union 看起来抓得更多，所以一定更互补。”

---

## 15.3 中高预算下，Cost-0 才开始真正补盲

代表性例子：

- Dense / BeamDerived：Refined + FiveBin 在中预算出现正 matched gain；
- Dense / Paper1s：Refined + Entropy 在更深风险区出现明显正 gain。

因此互补性不是“有没有”，而是：

\[
\boxed{\text{strongly budget-regime dependent}}
\]

---

## 15.4 Common miss 揭示 local observability ceiling

即使三个 indicator union，在 DenseRisk 中仍需要较高 trigger fraction 才能覆盖绝大多数 catastrophe。

这说明：

> 仅靠当前 local search-state diagnostics，很难在极低 fallback budget 下完全分离所有 global branch failures。

因此得到：

\[
\boxed{\text{low-cost local observability ceiling candidate}}
\]

注意这里一直保留 **candidate**，因为高 budget 下仍能最终抓到。

---

# 16. PA5J-B1：把 warning ability 转成真实 cost–reliability

B1 的关键变化是：

> 不再把“被触发的 failure”自动当成“被救回”。

而是读取真实 N3 outcome：

\[
F_i^{\rm final}
=
\begin{cases}
F_i^{N3}, & \text{triggered}\\
F_i^{G0}, & \text{otherwise}
\end{cases}
\]

同时正式计入 objective-evaluation cost。

### 主要对照

- G0
- Always-N3
- FiveBin selective N3
- Entropy selective N3
- Cost0-MaxRank
- Refined-LR selective N3
- All3-MaxRank

### 关键结果

1. **Refined-LR 在 low-to-mid budget 最强**；
2. 但随着 budget 增大，Refined-LR 出现 plateau；
3. Cost-0 在 residual/high-budget 区域重新变得有价值；
4. naive All3-MaxRank 并不总是优于 Refined-LR。

于是：

\[
\boxed{
\text{feature complementarity}
\not\Rightarrow
\text{naive symmetric fusion optimal}
}
\]

---

# 17. PA5J-B2：为什么 naive fusion 会失败

B2 专门研究：

> G5 抓走 observable core 后，Cost-0 在 residual pool 中还剩多少信息？

结果很强。

---

## 17.1 Refined-LR residual tail 确实存在

例如 DenseRisk：

### Paper1s

随着 G5 budget 从 0.1 → 0.5，仍有显著 residual failures。

### BeamDerived

0.2 → 0.3 附近甚至出现明显 plateau。

这确认：

\[
\text{Refined-LR}
\]

并非 information-complete。

---

## 17.2 Cost-0 在 residual pool 中仍然有信息

Paper1s 中 FiveBin residual-pool AUC 仍大约在：

\[
0.76\sim0.82
\]

BeamDerived 也约：

\[
0.63\sim0.72
\]

说明：

\[
\boxed{
\text{Cost-0 diagnostics retain information not exhausted by Refined-LR}
}
\]

---

## 17.3 G6 的低预算劣势来自 rank displacement

Paper1s 低 budget：

- G5 已抓住的一批 failure 被 G6 挤出去；
- G6 新补回的 failure 数量更少。

到更高 budget 时，关系才开始反转。

这说明：

> Cost-0 并不是“没用”，而是它在低预算阶段不应与 LR core 平权争抢 scarce fallback budget。

从而得到 staged policy 的核心设计思想：

\[
\boxed{
\text{Refined-LR first}
\rightarrow
\text{Cost-0 residual reranking}
}
\]

---

## 17.4 Physical anatomy：residual tail 不是简单 half-bin 重现

G5 residual failures：

- 强烈集中在少数 coherent relative-phase states；
- 但 \(\eta\) 仍横跨较宽范围；
- Gamma / resolution regime 有调制作用；
- contrast 高是进入风险 manifold 的条件之一，但不是 residual 额外机制的充分解释。

因此：

\[
\boxed{
\text{residual tail is phase-structured but not eta-only}
}
\]

这进一步支持：

\[
\text{coherent geometry}
+
\text{global branch ambiguity}
\]

而不是简单重新归因于 fence effect。

---

# 18. PA5J-B3：Staged Reliability Gate

B3 正式实现：

```text
Stage 1:
Refined-LR
    ↓
保护 observable failure core

Stage 2:
只在 Stage-1 未触发池中
用 FiveBin / Entropy / Cost0-MaxRank 重排
    ↓
Neighbor-3
```

并进行二维：

\[
(b_1,b_2)
\]

sweep。

第一轮结果显示大量 staged points 比原 B1 sampled envelope 更好。

但这里马上触发了一个非常重要的自我质疑：

> B3 的二维网格比 B1 原来的 11 个 budget 密得多，这会不会人为夸大 staged advantage？

这直接引出 B3-R1。

---

# 19. PA5J-B3-R1：Dense Single-Stage Comparator Audit

这是整个后期最重要的“反漂亮结果审计”之一。

对 B1 五个 single-stage policy：

- FiveBin
- Entropy
- Cost0-MaxRank
- Refined-LR
- All3-MaxRank

不再使用 11 个预算点，而是：

> **枚举每一个 distinct score cutoff 所对应的 deterministic tie-inclusive endpoint。**

最终一共得到约：

\[
49,173
\]

个 dense B1 endpoints。

---

## 19.1 结果：之前的 B3 gain 确实被粗 grid 放大

例如：

- Dense / Paper1s：旧 positive points 69 → dense audit 后 14；
- Dense / BeamDerived：92 → 11。

说明：

\[
\boxed{
\text{coarse B1 sampling significantly inflated apparent staged gain}
}
\]

这是必须诚实保留的结果。

---

## 19.2 但 staged gain 没有消失

最强 surviving examples：

### Dense / Paper1s

Entropy：

\[
b_1=0.30,\quad b_2=0.20
\]

\[
P_F^{B3}\approx0.0374
\]

同成本 dense-B1：

\[
P_F^{B1}\approx0.0544
\]

gain：

\[
\approx0.0169
\]

### Dense / BeamDerived

FiveBin：

\[
b_1=0.20,\quad b_2=0.10
\]

gain：

\[
\approx0.0196
\]

因此结论从：

> staged “大幅优于” single-stage

被收敛成：

\[
\boxed{
\text{staged allocation yields genuine but localized intermediate-cost Pareto gains}
}
\]

这是当前最可信的方法表述。

---

# 20. PA5J-B3-R2：Shared-Policy Cross-Aperture Robustness

R1 后还有一个潜在过拟合问题：

> Paper1s 和 BeamDerived 会不会需要不同的 signal / \(b_1\) / \(b_2\) 才能各自得到 gain？

R2 强制同一：

\[
(\text{Stage2 signal},b_1,b_2)
\]

同时用于两个 aperture。

---

## 20.1 Primary metric

定义：

\[
g_P
=
\text{Paper1s dense-B1-audited gain}
\]

\[
g_B
=
\text{BeamDerived dense-B1-audited gain}
\]

\[
\boxed{
g_{\rm robust}
=
\min(g_P,g_B)
}
\]

只有：

\[
g_{\rm robust}>0
\]

才算同一 policy 真正跨 aperture strict-better。

---

## 20.2 结果

216 个 shared configurations 中：

- strict-both：8
- noninferior-both：43
- robust-front configurations：4

最强 shared configuration：

\[
\boxed{
\text{FiveBin},\quad
b_1=0.20,\quad
b_2=0.10
}
\]

其：

\[
g_P\approx0.01248
\]

\[
g_B\approx0.01961
\]

分别相当于较同成本 dense-B1 comparator 少：

- Paper1s：14 个 catastrophic failures；
- BeamDerived：8 个 catastrophic failures。

worst normalized cost：

\[
\approx0.296
\]

---

## 20.3 跨 aperture gain 不是完全偶然

216 个配置的 gain 相关性：

\[
\rho_s\approx0.68
\]

各 Stage-2 signal 也大致保持正相关。

说明：

> 帮助 Paper1s 的配置，整体上也更倾向帮助 BeamDerived。

但相关性没有高到接近 1，说明 aperture dependency 仍存在。

---

## 20.4 回到 Original grid：安全，但没有额外 strict gain

DenseRisk strict-both 的 8 个配置：

- 回到 Original 后全部两边 non-inferior；
- 但没有一个在 Original 两 aperture 上同时 strict-better。

这非常重要。

它表明当前方法更适合定位为：

\[
\boxed{\text{hard-case robustness improvement}}
\]

而不是：

\[
\text{average-case universal superiority}
\]

---

# 21. 从初期到后期：真正的研究逻辑发生了什么变化

可以把整个 EXP009 分成三个阶段。

---

# 21.1 初期：Discovery

## 问题

> weak 为什么恢复不好？

## 核心思路

- oracle ladder；
- strong residual ownership；
- coherent peak pulling；
- local failure taxonomy。

## 主要发现

- strong residual 不只是抬底噪；
- coherent cross term 会改变 weak objective landscape；
- practical operator 可以产生 systematic bias；
- global entropy 不足以衡量 component completeness。

### 初期价值

建立了：

\[
\boxed{\text{failure is structured, not random}}
\]

---

# 21.2 中期：Physical mechanism → reliability transition

## 问题

> 这些现象能否在 Wang/Xu 物理尺度上成立？
>
> catastrophic failure 到底是 local bias 还是 global branch event？

## 主线

```text
P0/P1
→ finite-aperture physical anchor
→ PA4/PA5
→ leakage / recoverability floor
→ PA5F
→ recenter
→ PA5G/H
→ mixture bias
→ H-R1
→ branch switching
→ PA5I
```

## 核心发现

1. finite-window/off-grid leakage 是真实 physical bottleneck；
2. strong removal 存在 weak-ratio-dependent recoverability floor；
3. oracle recenter 可以几乎消除该 floor；
4. continuous ML 消除 interpolation bias 后，mixture bias 仍然存在；
5. low/medium contrast mixture bias 可被一阶模型解释；
6. 高 contrast 异常中混入 global branch switch；
7. Neighbor-3 能可靠恢复 rare catastrophic G0 failures。

### 中期价值

把问题从：

\[
\text{local estimation accuracy}
\]

提升成：

\[
\boxed{\text{rare-event branch reliability}}
\]

---

# 21.3 后期：Method construction + paper convergence

## 问题

> 能不能只在危险 trial 上花 Neighbor-3 的计算？

## 主线

```text
J-A
internal risk indicators
    ↓
B0
complementarity / common miss
    ↓
B1
real selective-N3 Pareto
    ↓
B2
residual information + rank dilution
    ↓
B3
staged gate
    ↓
R1
exhaustive single-stage fairness audit
    ↓
R2
shared-policy cross-aperture robustness
```

## 核心发现

- internal reliability state 是可观测的；
- Refined-LR 抓 observable core；
- Cost-0 在 residual pool 中仍有独立信息；
- naive fusion 会在 scarce-budget 下稀释最重要的 LR failures；
- staged allocation 有真实 method value；
- 但 advantage 在 exhaustive comparator 后明显收缩；
- surviving gain 主要位于 intermediate-compute regime；
- 同一 staged configuration 可以跨 aperture 保留正 gain；
- representative Original 上方法是安全 / noninferior，但没有强 strict gain。

### 后期价值

从“找漂亮指标”收敛成：

\[
\boxed{
\text{mechanism-guided staged reliability allocation}
}
\]

---

# 22. 当前已经可以稳定下来的三个核心价值点

---

## 22.1 核心价值 1：Mechanism

当前最稳妥的机制表述不是“某一个单独效应”，也不是“所有 catastrophe 都严格沿同一条必然链逐级发生”，而是若干 **相互作用的失效层（interacting failure layers）**：

\[
\boxed{
\begin{array}{c}
\text{finite-window / off-grid leakage}\\
\text{strong-removal mismatch / weak damage}\\
\text{coherent multi-component perturbation}\\
\text{local search-landscape distortion}\\
\text{global branch competition}
\end{array}
\ \Longrightarrow\ 
\text{rare catastrophic failure under difficult regimes}
}
\]

其中需要特别保持克制：

- local continuous bias 和 global branch switching 必须区分；
- phase / Gamma anatomy 是支持性证据，不应写成完整因果定律；
- high contrast 是风险条件，不等于 residual-tail 的唯一原因。

---

## 22.2 核心价值 2：Method

当前方法贡献可以收敛为：

\[
\boxed{
\text{Refined-LR-first staged reliability allocation}
\rightarrow
\text{residual Cost-0 reranking}
\rightarrow
\text{selective Neighbor-3}
}
\]

最重要的不是“FiveBin 最好”或“Entropy 最好”。

因为：

- 不同 aperture / cost regime 的最佳 Cost-0 signal 会变化；
- 三种 Cost-0 signal 都进入过有效 frontier。

真正稳定的是：

> **sequential allocation architecture**。

---

## 22.3 当前工程证据：Search-Level Engineering Trade-off（已成立，不等同于 Claim 3）

工程价值不应该写成：

> “Proposed 永远比 single-stage 更好。”

而应该写成：

> **在 intermediate compute regime，Proposed 可以以显著低于 Always-N3 的平均计算成本，降低 rare catastrophic branch failures；该收益在 exhaustive deterministic single-stage comparator 和 cross-aperture shared-policy audit 后仍然存在。**

同时：

- low-cost regime：Refined-LR single gate 可能已经很好；
- intermediate regime：staging 最有价值；
- high-cost regime：broad single-stage coverage 会追上；
- representative grid：主要体现 non-inferiority / safety；
- dense-risk：主要体现 robustness gain。

这是一条非常可信、可防守的 **search / parameter-level engineering evidence**。

但它不自动等价于 SAR 图像级工程收益。真正的 Claim 3 仍必须在 Claim 1 / Claim 2 冻结后，通过 SAR-level experiment 单独验证。

---

# 23. 哪些实验是论文正文核心，哪些适合附录

---

## 23.1 建议进入正文主线

### Mechanism section

- P0 / P1：物理尺度锚定（简洁）
- PA5D / PA5E：recoverability floor
- PA5F：oracle recenter
- PA5G / PA5H / H-R1：插值 bias、mixture bias、branch switching

### Reliability / Method section

- PA5I / I-R1：G0 vs Neighbor-3
- PA5J-A：internal indicators
- B0：observable core / complementarity
- B2：residual information + rank dilution
- B3：staged policy architecture
- B3-R1：exhaustive comparator
- B3-R2：shared-policy robustness

---

## 23.2 适合正文压缩、附录展开

- P1B / P1C
- PA5B / PA5C
- PA5E-R1
- B0 全部 pairwise / common-miss tables
- B1 全部 policy family 曲线
- Original-grid rare-event完整细表
- early normalized oracle ladder
- C3-B3B.1 ownership decomposition

---

## 23.3 不建议继续扩成新的主实验树

目前默认不新增：

- 新 reliability features；
- 新 staged fusion；
- 新 PA5K / PA5L；
- 更密的 \(b_1,b_2\) 网格；
- aperture-specific hand-tuned policy；
- learned gate。

除非后续 closure experiment **直接证伪当前 Claim**。

---

# 24. 当前收益是否已经呈下降趋势？

答案是：

\[
\boxed{\text{是，而且这是论文应该收敛的信号}}
\]

看信息增量：

| 阶段 | 新信息增量 |
|---|---|
| PA5F | 很大：off-grid floor 机制被 oracle recenter 验证 |
| PA5G/H | 很大：插值 bias 与 mixture bias 分开，并有一阶模型 |
| PA5H-R1 | 很大：local bias 与 global branch switch 分开 |
| PA5I/J-A | 很大：从 mechanism 进入 reliability |
| B0/B1/B2 | 很大：observable core、residual info、真实 Pareto |
| B3 | 中等偏大：staged architecture |
| B3-R1 | 非常重要，但主要是“验真” |
| B3-R2 | 重要 robustness evidence，但新机制信息有限 |
| 再继续微调 budget | 很可能低价值 |

因此当前实验线已经从：

\[
\text{discover new phenomenon}
\]

转向：

\[
\text{rule out alternative explanations}
\]

再往后如果仍围绕 gate 本身继续扫，很容易进入：

\[
\text{result polishing}
\]

而不是：

\[
\text{claim completion}
\]

---

# 25. 当前论文 Claim 建议

---

## Claim 1 — Mechanism Claim

> Finite-window/off-grid effects and coherent multi-component perturbations can distort the sequential-refocusing search landscape; under difficult regimes, this distortion can escalate from local estimation bias to global branch competition and rare catastrophic branch-selection failure.

不要过度写成“所有 failure 都由同一个 closed-form model 完整解释”。

---

## Claim 2 — Method Claim

> Cheap internal reliability states can be used in a staged manner to allocate branch-safe Neighbor-3 recovery selectively. Refined-LR first captures a highly observable failure core, while residual Cost-0 diagnostics recover complementary risk information. The resulting staged policy yields localized but genuine intermediate-cost Pareto improvements that survive exhaustive deterministic single-stage comparison and a shared-policy cross-aperture audit.

这是目前证据最完整的核心贡献。

---

## Claim 3 — SAR-Level Translation / Engineering Validation Target（Pending）

目前还不能写成“已成立 Claim”。

真正后续需要验证：

\[
\text{branch reliability gain}
\rightarrow
\text{weak recovery gain}
\rightarrow
\text{SAR refocusing quality gain}
\]

以及：

\[
\text{end-to-end compute benefit}
\]

是否闭环。

---

# 25.1 v1.1 评价语义与 operational semantics 冻结补丁

### Catastrophic label

当前 PA5J 主线继续严格继承 PA5I / PA5J-A 的标签体系：

- catastrophic threshold 数值：`0.10 bin`；
- branch-match tolerance：`0.02 bin`（context / branch matching，不与 catastrophic threshold 混用）；
- threshold 数值不得在后续 closure 中重新选择；
- `>` / `>=`、periodic wrapping / branch-error 具体实现语义必须从 PA5I 原始实现 **逐字继承**，不得在 v1.1 文档层自行重定义。

### 当前 operational semantics

当前 Claim 1 / Claim 2 closure 默认采用：

> **Option A — Batch / fixed-compute scheduler**

即对一个实际可共同处理的自然 batch（如同一 target / 同一处理批次中的 azimuth lines 或 processing units）按 frozen reliability score 排序，在固定计算预算下分配 Neighbor-3。

禁止为了得到 top-20% / top-10% 而按 true SNR、true \(\Gamma\)、true \(\eta\)、truth contrast、aperture truth label 等仿真元数据拆组后重新排序。

若未来要声明 per-trial online gate，则另行进入 Option B calibration，不影响当前 closure。

---

# 26. 当前建议正式冻结的 Proposed Policy

经过 R2，最合理的 primary shared candidate 是：

\[
\boxed{
\text{Stage 1: Refined-LR},\quad b_1=0.20
}
\]

\[
\boxed{
\text{Stage 2: FiveBin},\quad b_2=0.10
}
\]

理由不是“它在一个图上最好看”，而是：

- 同一配置跨 Paper1s / BeamDerived strict positive；
- worst-aperture gain 最大；
- worst normalized cost ≈ 0.296；
- 相对 dense-B1 comparator：
  - Paper1s 少约 14 个 catastrophic failures；
  - BeamDerived 少约 8 个；
- 回到 Original 两 aperture 均 non-inferior。

应同时保留 robust front 上其他点作为 sensitivity / ablation，而不是 noise 之后再重新挑。

---

# 27. 后续实验路线：从“探索”切换到“关闭 Claim”

当前不建议继续 B4 / 新 feature。

建议路线冻结为：

```text
PA5J-B3/B3-R1/B3-R2 closure
    ↓
POLICY FROZEN
    ↓
Mechanism Evidence Matrix
+ Oracle Ledger
    ↓
Noiseless Practical Non-Oracle Integration Smoke Test
    ↓
SNR / Noise Literature & Definition Audit
    ↓
PENDING-DEFINITION: injected/reference SNR + strong-effective SNR + weak-effective SNR
    ↓
NOISE PROTOCOL FROZEN
    ↓
Frozen-Policy Noise Robustness
    ↓
Noisy Practical Non-Oracle Sequential Closure
    ↓
CLAIM 1 & CLAIM 2 FROZEN
    ↓
SAR-Level Experimental Design
    ↓
Simulated SAR
→ Public real SAR
→ group real data if available
```

---

# 28. 后续每个新实验的准入规则

从现在开始，每个实验必须回答：

1. **它服务于哪个 Claim？**
2. **它排除哪个尚未解决的替代解释？**
3. **什么结果会削弱或修改当前 Claim？**
4. **如果不做，论文是否存在实质性证据缺口？**

如果第 4 个问题答案是：

> “不做也能成立，只是图可能没那么漂亮。”

默认：

\[
\boxed{\text{STOP}}
\]

---

# 29. 当前项目真正应该避免的三种回退

### 回退 1：继续 feature mining

例如：

> 再找第 4、第 5 个 reliability indicator。

目前没有必要。

---

### 回退 2：继续 budget polishing

例如：

\[
b_1=0.18,\quad b_2=0.08
\]

是否更漂亮。

R2 已经说明 robust-positive region 存在，但并不宽。

继续精调很容易变成 test-grid optimization。

---

### 回退 3：noise 一来就重新改 policy

后续 noise experiment 的角色必须是：

\[
\boxed{\text{robustness validation}}
\]

而不是：

\[
\text{new discovery / feature redesign}
\]

如果 frozen policy 在低 SNR 下退化，应报告适用区间，而不是每个 SNR 重新选 signal 或阈值。

---

# 30. 最终复盘：EXP009 现在真正完成了什么

从科研训练角度看，EXP009 最大的价值不是“做出了一条漂亮曲线”，而是完整走过了一个研究问题逐层收敛的过程：

### 第一步：发现异常

> weak component 会被遗漏，global focus metric 不足以解释信息完整性。

### 第二步：拆机制

> residual 不只是噪声，而有 coherent geometry。

### 第三步：做解析化

> strong leakage / weak damage 有可解释的 error decomposition 和 floor。

### 第四步：找真正主因

> oracle recenter 证明 off-grid miscentering / finite-window leakage 是关键 bottleneck。

### 第五步：区分估计 bias 与 branch catastrophe

> continuous local bias 和 global branch switching 不是同一个问题。

### 第六步：把 mechanism 变成 reliability problem

> G0 失败是 rare but catastrophic，N3 能救但太贵。

### 第七步：找内部可观测状态

> Refined-LR + Cost-0 指标能看到不同风险层级。

### 第八步：避免 naive fusion

> complementarity 不代表 symmetric fusion 最优。

### 第九步：构造 staged policy

> Refined-LR first，Cost-0 residual reranking。

### 第十步：主动攻击自己的漂亮结果

> exhaustive dense comparator 证明原始 gain 被放大，但并未消失。

### 第十一步：检查跨 aperture

> shared staged policy 仍存在真实正收益。

### 第十二步：主动停止继续扩树

> 因为现在缺的已经不是“另一个指标”，而是 noise / non-oracle integration / SAR-level closure。

---

# 31. 当前阶段结论

截至 PA5J-B3-R2，EXP009 已经具备：

- **一条物理机制链；**
- **一条数学解释链；**
- **一个 rare-event reliability formulation；**
- **一个内部 reliability-state discovery；**
- **一个 staged adaptive-computation method；**
- **exhaustive comparator fairness audit；**
- **cross-aperture shared-policy robustness evidence；**
- **清晰的后续 Claim-closing 路线。**

因此当前最重要的战略变化应当是：

\[
\boxed{
\text{从“继续发现更多东西”}
\rightarrow
\text{“证明现有东西已经足够成为一篇完整论文”}
}
\]

这也是为什么现在暂停新增 PA5 feature / gate 实验，是正确的。

---

# 32. 建议下一步先做的“非实验工作”

在正式进入新的 MATLAB 实验之前，我建议先完成三件文档工作：

## A. `EXP009_MECHANISM_EVIDENCE_MATRIX.md`

列：

| Claim 子句 | 对应实验 | 直接证据 | 反事实 / control | 证据等级 | 是否仍缺 |
|---|---|---|---|---|---|

这会决定哪些 Claim 真正可以写进摘要和结论。

---

## B. `EXP009_POLICY_FREEZE.md`

冻结：

- architecture；
- primary shared configuration；
- sensitivity configurations；
- cost definition；
- fallback semantics；
- truth variables 禁用规则；
- noise 后不得重新调 policy 的规则。

---

## C. `EXP009_ORACLE_LEDGER.md`

明确每个 practical-chain quantity：

| Quantity | 实际方法来源 | 是否可在线获得 | 真值是否仅用于评估 |
|---|---|---|---|

确保后面的 practical chain 不会偷偷把：

- true \(\eta\)
- true branch
- Gamma
- GlobalReference

重新引入 decision path。

---

## 33. 一个可以长期保留的项目判断

目前最合理的小论文定位，不是：

> “提出一个普适的新型 SAR 重聚焦大算法。”

而更像：

> **围绕 sequential ship refocusing 中 rare catastrophic branch failure，建立从物理失效机制、内部可靠性状态到选择性 branch-safe recovery 的一条完整方法链，并证明这种 mechanism-guided reliability-aware computation 在困难 regime 下能带来真实而可审计的 quality–cost improvement。**

这个尺度和当前证据最匹配，也更符合研一第一篇“小而尖”的目标。

---

## 附录 A：当前主线实验索引

```text
Xu / Wang reproduction
EXP01
EXP04–06
EXP07
EXP08

EXP009 normalized discovery
L0–L3 oracle ladder
A3 / A4
C3-B3B.1 等 ownership / NearShift 机制探索

EXP009 physical validation
P0
P1
P1B
P1C
PA4
PA5
PA5B
PA5C
PA5D
PA5E
PA5E-R1
PA5F
PA5G
PA5H
PA5H-R1
PA5I
PA5I-R1
PA5J-A
PA5J-B0
PA5J-B1
PA5J-B2
PA5J-B3
PA5J-B3-R1
PA5J-B3-R2
```

---

## 附录 B：当前最核心的数学关系

### 1. Coherent mixture power

\[
P(q)
=
|C_w+C_e|^2
=
|C_w|^2+|C_e|^2
+
2\operatorname{Re}\{C_wC_e^*\}
\]

### 2. Weak peak first-order shift

\[
\delta_q
\approx
-\frac{\Delta P'(q_w)}{P_w''(q_w)}
\]

### 3. Strong-removal / weak-recovery error decomposition

\[
\boxed{
E^2
=
\left(\frac{L_s}{r_A}\right)^2
+
D_w^2
}
\]

### 4. Recoverability floor

\[
\boxed{
r_{\min}
=
\frac{L_0}{\sqrt{1-D_0^2}}
}
\]

### 5. Mixture-induced sub-bin bias

\[
\boxed{
\delta_{\rm mix}
\approx
-r
\frac{H'(0)}{J_s''(0)}
}
\]

### 6. Shared-policy robust gain

\[
\boxed{
g_{\rm robust}
=
\min(g_{\rm Paper1s},g_{\rm BeamDerived})
}
\]

---

## 附录 C：证据边界

当前仍不能直接宣称：

1. 当前 staged policy 已经对所有 aperture / SNR / SAR 数据普适；
2. R2 是 independent held-out generalization；
3. phase / Gamma anatomy 已建立完整因果关系；
4. DenseRisk failure prevalence 等价于真实场景 failure prevalence；
5. Original grid 上 Proposed 显著优于所有 single-stage 方法；
6. signal/search-level branch reliability gain 已经自动转化为 SAR image-level gain。

这些正是后续 paper-closing validation 要解决或明确限定的部分。
