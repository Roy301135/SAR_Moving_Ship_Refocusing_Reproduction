# Xu 2025 Adaptive Fast Refocusing —— 复现、扩展与原创研究演化说明

> **本目录定位：**  
> 本目录最初用于复现 Xu 2025 关于复杂运动舰船 SAR 自适应快速重聚焦的工作，但随着实验推进，逐渐发展出一条独立研究线：
>
> **Xu 2025 复现 → 局部搜索可靠性问题 → 多分量弱目标恢复 → 顺序去除失效机制 → 分支竞争 → 可靠性感知选择性恢复 → practical non-oracle 闭环 → 理论验证。**
>
> **特别说明：EXP009 及之后的实验属于我们自己的原创研究，不应被理解为 Xu 2025 原论文复现实验。**

---

## 1. 为什么这个目录已经不只是“论文复现”

最开始，这个目录确实承担的是 Xu 2025 的论文复现任务。

原始研究问题主要围绕：

```text
复杂运动舰船
    ↓
残余 MC-LFM
    ↓
FrFT / FrAc
    ↓
ORO 参数估计
    ↓
局部搜索
    ↓
相邻方位线先验共享
    ↓
降低计算量
```

但随着复现深入，我们逐渐发现，真正值得研究的问题并不是单纯：

> “怎样进一步把 FrFT / FrAc 搜索做得更快？”

而是：

> **快速局部搜索什么时候会失效？失效之前能不能从搜索过程内部看到征兆？如果能够看到，是否可以只给高风险样本增加额外计算？**

这一转变并不是预先设计好的，而是从 EXP04–EXP08 的实验现象中逐渐暴露出来的。

因此，目前这个目录实际承担三个不同层级的任务：

| 层级 | 内容 |
|---|---|
| 论文复现 | 验证 Xu 2025 的核心机制与数值流程 |
| 研究型扩展 | 对原方法进行 stress test、多分量、弱分量等扩展 |
| 原创研究 | 从 EXP009 开始研究 failure mechanism、branch reliability、selective recovery 和理论边界 |

---

## 2. 参考论文与最初研究起点

本目录起点为：

**Xu et al., 2025**  
*Adaptive Fast Refocusing for Ship Targets With Complex Motion in SAR Images*  
IEEE JSTARS

该论文最初带给我们的核心研究对象包括：

```text
复杂运动舰船
→ 空变失焦
→ MC-LFM
→ ORO estimation
→ 缩小搜索区间
→ 相邻方位线共享先验
→ 降低 FrFT/FrAc 搜索代价
```

尤其值得关注的是 Xu 2025 中的一个重要思想：

> **相邻方位线之间存在参数连续性，因此可以利用上一条方位线结果缩小下一条方位线的搜索范围。**

我们的 EXP04–EXP06 最初就是从这里继续向前走。

---

## 3. EXP01–EXP03：核心复现阶段

这一阶段主要回答：

> 我们自己的 MATLAB 仿真链能否正确复现 Xu 2025 所依赖的最基本数学与数值机制？

主要包括：

```text
residual LFM
    ↓
FrFT / FrAc concentration
    ↓
理论最优 order
    ↓
数值搜索最优 order
```

以及：

```text
Full Search
vs.
Reduced ORO Interval
```

这部分工作的意义主要是建立**可信数值地基**，而不是创新。

例如已经验证：

- 理论 order 与数值最优 order 能够一致；
- 缩小 ORO 区间后，计算次数明显下降；
- 在正常条件下不会显著损失估计精度。

因此：

> **EXP01–EXP03 应被明确标记为 reproduction / numerical verification。**

---

## 4. EXP04–EXP06：从“快搜索”走向“可靠搜索”

这一阶段是第一次发生真正研究转向的地方。

Xu 2025 的基本假设是：

> 相邻方位线 ORO 变化平滑，因此上一条线可以作为下一条线的局部搜索 prior。

EXP04 证明：

```text
平滑 ORO 场
+
小 tracking window
→
计算量显著下降
+
精度基本保持
```

但是 EXP05 开始主动加入困难情况，例如：

```text
abrupt ORO jump
弱能量区域
噪声
```

这时发现：

```text
真实 ORO 离开局部搜索窗口
        ↓
FrAc 峰靠近搜索边界
        ↓
boundary hit
        ↓
局部估计滞后
        ↓
错误 prior 被传给下一条方位线
        ↓
error propagation
```

这时候出现了一个非常重要的新概念：

> **boundary hit 可以作为“不可靠搜索”的内部警报。**

但同时我们也明确：

> boundary hit 并不等于一定错误，它只是 reliability state。

随后 EXP06 使用：

```text
Δ = 0.01
→ 0.02
→ 0.04
→ 0.08
→ full-search fallback
```

形成了一个最早期的：

> **根据内部风险状态选择是否增加计算量**

的 proof-of-concept。

这实际上已经埋下了后来 PA5J / selective Neighbor-3 的核心思想。

因此 EXP04–EXP06 更准确的分类是：

> **Xu 2025 reproduction-derived extension / reliability-oriented exploration**

而不再是单纯复现。

---

## 5. EXP07–EXP08：研究问题进一步转向弱分量恢复

进入多分量场景以后，我们发现：

> “整体聚焦得不错”和“所有散射分量都恢复了”并不是一回事。

EXP07 的一个重要发现是：

```text
低 image entropy
≠
所有 weak component 都正确恢复
```

也就是说：

```text
good global focus
    ≠
component completeness
```

某些弱分量即使没有被恢复，整体 entropy 依然可能很好。

这说明如果仅使用：

```text
Image Entropy
```

这样的全局指标，有可能完全看不到弱散射成分已经丢失。

EXP08 进一步发现：

> 在复杂 multi-component 条件下，简单依靠“一张 FrAc spectrum 找多个峰”并不可靠。

于是问题从：

```text
dominant ORO tracking
```

逐渐转向：

```text
第二、第三个弱分量
到底能不能可靠恢复？
```

这就直接引出了 EXP009。

---

## 6. EXP009：原创研究正式开始

这是整个目录最重要的分界点。

从 EXP009 开始，研究问题已经不再来自 Xu 2025 原论文。

EXP009 最初真正问的是：

> **弱分量究竟从 sequential refocusing 的哪一步开始损失？**

后来进一步发展成：

> **顺序重聚焦内部的搜索过程，是否包含足够的信息，用来识别高风险 branch failure？**

因此目录里应该明确写：

```text
══════════════════════════════
EXP009: ORIGINAL RESEARCH
══════════════════════════════
```

并且说明：

> EXP009 以后虽然物理文件仍然放在  
> `papers/Xu2025_Adaptive_Fast_Refocusing/`  
> 下面，但这是为了保持 MATLAB 路径、历史依赖和科研 provenance。

也就是说：

> **文件夹位置 ≠ 学术归属。**

---

## 7. EXP009 的核心机制发现

EXP009 最终不是形成很多平行的小创新，而是逐渐收敛成一条连续失效机制链。

当前比较稳定的机制链是：

```text
有限孔径 / 有限窗
        ↓
off-grid miscentering
        ↓
strong residual leakage
+
weak-component damage
        ↓
weak-component recoverability floor
        ↓
coherent residual
        ↓
weak search objective deformation
        ↓
local continuous bias
        ↓
global branch competition
        ↓
rare catastrophic branch-selection error
```

---

## 8. Strong leakage 与 weak damage

这是目前 Claim 1 最扎实的理论部分之一。

我们把 sequential strong removal 抽象为一个有限窗投影算子。

去除强分量后，弱分量恢复误差由两部分组成：

```text
strong residual leakage
+
weak-component damage
```

在当前冻结的正交 projection model 下，可以得到：

\[
E^2
=
\left(rac{L_s}{r_A}ight)^2+D_w^2
\]

其中：

```text
Ls = strong residual leakage ratio
Dw = weak component damage ratio
rA = weak / strong amplitude or norm ratio
```

这个关系特别重要，因为它说明：

> **strong residual 本身即使不大，只要 weak component 很弱，其影响仍然会被 \(1/r_A\) 放大。**

因此：

```text
weak 越弱
→
对 strong residual 越敏感
```

这也是为什么 sequential weak recovery 会出现明显下限。

---

## 9. off-grid 与 recoverability floor

如果强分量真实 transform-domain center 位于：

```text
integer bin 之间
```

而 removal window 仍以：

```text
integer coarse bin
```

为中心，就会出现：

```text
miscentering
```

从而导致：

```text
部分 strong energy 留在 window 外
→ strong leakage
```

如果扩大 window：

```text
strong leakage ↓
```

但是同时：

```text
weak damage ↑
```

于是形成结构性的：

```text
leakage–damage trade-off
```

进一步得到：

\[
r_{\min}
=
rac{L_0}
{\sqrt{1-D_0^2}}
\]

这一结果不能写成：

> “真实 SAR 中普适的检测极限”

而只能表述为：

> **在当前有限窗 removal operator、当前无噪声 operator-level 模型和当前恢复误差定义下的 weak-to-strong recoverability floor。**

这个限定非常重要。

---

## 10. strong residual 不只是“抬高噪声底”

这是我们后来机制分析中的关键认识。

对于 weak search objective，可以写成：

\[
C(q)=C_w(q)+C_e(q)
\]

于是：

\[
|C(q)|^2
=
|C_w|^2
+
|C_e|^2
+
2\operatorname{Re}
\{C_w C_e^st\}
\]

这里最后一项是：

```text
coherent cross term
```

因此 strong residual 的作用并不是：

```text
strong residual
→
单纯 noise floor ↑
```

而是：

```text
strong residual
+
weak signal
        ↓
coherent interference
        ↓
objective geometry 改变
        ↓
peak shift / ranking change
```

也就是说：

> **residual 会主动重塑 weak component 的搜索目标函数。**

这也是后面 branch competition 的基础。

---

## 11. local bias 和 branch catastrophe 必须分开

这是 EXP009 后期非常重要的研究认识。

早期容易形成一个过度简单的逻辑：

```text
local bias 越来越大
→
最终发生 catastrophe
```

但实验后来说明，这并不严谨。

实际上存在两类不同对象：

```text
连续域 local refinement
```

和：

```text
离散 coarse branch ranking
```

所以可能出现：

```text
continuous optimum 仍然比较稳定
```

但是：

```text
integer coarse branch winner 已经发生切换
```

因此必须区分：

### Failure Mode A

```text
local continuous estimation bias
```

### Failure Mode B

```text
global branch switching
```

后者才是真正的：

```text
catastrophic branch-selection error
```

---

## 12. Reliability State：失败之前能不能提前看到？

既然 catastrophic branch error 并不是完全随机出现，那么下一步自然变成：

> **cheap search 自己有没有信息可以告诉我们“这次搜索可能不可靠”？**

PA5J 系列开始研究内部 reliability feature。

最终发现：

```text
Refined-LR
```

在主要 failure core 上表现最好。

但是：

```text
Refined-LR 未触发的 residual pool
```

里面仍然存在剩余失败。

这时发现：

```text
FiveBin
```

仍保留一部分额外风险信息。

因此最终并没有选择：

```text
把所有指标一次性 fusion
```

因为这样容易出现：

```text
rank dilution
```

而是形成：

```text
Stage 1
Refined-LR
        ↓
抓主要 observable failure core

Stage 2
Residual FiveBin
        ↓
补充 residual failure
```

这构成了后面的：

> **staged reliability allocation**

---

## 13. Neighbor-3：为什么要选择性调用，而不是永远运行

Neighbor-3 的思想是：

```text
Cheap branch
+
邻近三个 candidate branches
```

从而降低 coarse branch error。

它的优势是：

```text
branch reliability ↑
```

但问题是：

```text
计算量 ↑
```

所以问题并不是：

> “Neighbor-3 好不好？”

而是：

> **哪些样本真的值得运行 Neighbor-3？**

最终形成：

```text
low risk
→
cheap search only

high risk
→
Neighbor-3 recovery
```

这就是我们当前第二个核心创新：

> **Reliability-Aware Selective Recovery**

---

## 14. EXP010：从机制 proof-of-concept 到 practical non-oracle

EXP010 的核心任务是：

> 把 EXP009 中带有 oracle / mechanism-analysis 色彩的发现，放进真正 practical 的处理链。

它重点验证：

```text
oracle information removed
        ↓
frozen policy
        ↓
practical strong-parameter estimation
        ↓
selective N3
        ↓
是否仍然有收益？
```

目前一个核心 practical 结果是：

### DenseRisk / Paper1s

```text
G0 branch failure:
0.13636

Proposed:
0.03119

Always-N3:
0.02406

Proposed normalized branch cost:
0.277
```

也就是说：

```text
Proposed
≈
获得 Always-N3 的大部分 reliability gain
```

但计算成本明显低于全量 Always-N3。

同时 weak feasible：

```text
0.59002
→
0.68182
```

说明 reliability gain 在困难场景下能够进一步转化为弱分量恢复收益。

---

## 15. Neighbor-3 不是绝对安全

EXP010-B-R1 很重要，因为它否定了一个可能的过度 claim：

> Neighbor-3 并不是无条件可靠。

当前 residual N3 failure 的主要来源是：

```text
upstream strong β estimation error
```

在现有 control experiment 中：

```text
86 个 residual N3 failures
```

在 true-\(eta\) control 下：

```text
86 / 86 消失
```

而 candidate coverage miss：

```text
= 0
```

因此目前更严谨的结论是：

> **Neighbor-3 的可靠性取决于上游 strong-component parameter estimation accuracy。**

这就是：

```text
conditional validity
```

而不是：

```text
unconditional safety
```

---

## 16. Noise experiment 的正确定位

EXP010-C 加入了：

```text
complex AWGN
```

其目的不是证明：

> “方法已经适用于真实海杂波”

而是做：

```text
robustness stress test
```

我们目前可以支持的是：

```text
SNR ↓
    ↓
strong β error tail ↑
    ↓
branch reliability ↓
```

而且 frozen policy 在多组 SNR 下仍保持净收益。

但是必须明确：

```text
AWGN
≠
sea clutter
```

所以未来真实 SAR 图像验证仍然需要补。

---

## 17. EXP011：不是第三个创新，而是理论闭环

EXP011 的定位一定要写清楚：

> **Theory Validation / Falsification**

而不是：

> New Method

它主要补两个理论桥梁。

### 17.1 理论桥 1：local bias → global branch switching

```text
coherent residual
        ↓
objective perturbation
        ↓
branch-margin erosion
        ↓
winner switching
```

可以写成：

\[
M_0
=
J_c^{(0)}-J_b^{(0)}
\]

如果 residual perturbation 后：

\[
\Delta J_b-\Delta J_c>M_0
\]

则 competing branch 可以反超 correct branch。

这就是当前：

```text
local bias
→
global branch switching
```

的最小理论解释。

### 17.2 理论桥 2：upstream β error → N3 conditional validity

第二条是：

```text
upstream β error
        ↓
search coordinate displacement
        ↓
correct optimum 离开 N3 coverage
        ↓
Neighbor-3 failure
```

近似有：

\[
\delta_
u
pprox
rac{\partial
u}{\partialeta}
\delta_eta
\]

如果 Neighbor-3 coverage 半径为 \(R_{cov}\)，则可以尝试形成：

\[
|\delta_
u|
<
R_{cov}-ho
\]

进一步：

\[
|\delta_eta|
<
rac{R_{cov}-ho}
{|\partial
u/\partialeta|}
\]

这可以给 Neighbor-3 一个：

> **sufficient validity condition**

而不是泛泛说：

> β 估计不准时效果会变差。

---

## 18. 当前论文最终只保留两个核心创新点

当前工作不缺创新点数量。

最终应该收敛成两个核心 Claim。

### Claim 1：Failure Mechanism

可以概括为：

> 在复杂运动舰船 MC-LFM 顺序重聚焦中，有限窗和 off-grid 会导致 strong residual leakage 与 weak-component damage 的结构性权衡，并形成 weak-component recoverability floor。残余 strong component 会通过相干作用改变后续搜索目标函数，在困难条件下进一步导致 global branch competition 和 rare catastrophic branch-selection error。

这是：

```text
为什么会失败？
```

### Claim 2：Reliability-Aware Selective Recovery

可以概括为：

> Cheap search 内部存在能够反映 branch failure 风险的 reliability state。通过 Refined-LR 与 residual FiveBin 的 staged risk allocation，可以只对高风险样本调用 Neighbor-3，从而在明显低于 Always-N3 的计算代价下提高 branch reliability；同时 Neighbor-3 的最终有效性受到上游 strong-component 参数估计精度约束。

这是：

```text
知道为什么会失败以后，
如何只给真正危险的样本增加计算？
```

---

## 19. 当前明确不能过度宣称的内容

README 中应保留清晰的 Claim Boundary。

目前不能说：

```text
所有 sequential refocusing failure
都能被一个统一闭式模型解释
```

不能说：

```text
Neighbor-3 永远安全
```

不能说：

```text
Refined-LR / FiveBin
是普适最优 failure predictor
```

不能说：

```text
AWGN 实验已经代表真实海杂波
```

不能说：

```text
当前 batch fixed-compute scheduler
已经等于部署阶段逐样本 online threshold
```

更不能说：

```text
search-level gain
已经自动证明 SAR image-level gain
```

---

## 20. 为什么 EXP009–EXP011 继续留在 Xu2025 文件夹里

从学术性质上：

```text
EXP009–EXP011
=
Original Research
```

但从工程和 provenance 上：

```text
仍然保留在
papers/Xu2025_Adaptive_Fast_Refocusing/
```

原因是它们与此前实验存在大量依赖，例如：

```text
MATLAB relative paths
configs
functions
results paths
README references
parameter provenance
feedback bundles
```

现在为了“目录看起来更漂亮”去搬动，会产生大量不必要的工程风险。

因此采取：

> **历史代码不迁移，新研究从现在开始切换目录。**

---

## 21. 后续新的 SAR 工作区

从 EXP011 之后，不再继续：

```text
EXP012
```

而是建立：

```text
research/
└── branch_reliability_sar/
```

新目录只承担：

> **SAR image-level physical validation**

建议结构：

```text
research/
└── branch_reliability_sar/
    ├── README.md
    ├── code/
    │   ├── exp01_sar_...
    │   ├── exp02_sar_...
    │   └── ...
    ├── functions/
    ├── results/
    │   ├── raw/
    │   ├── summary/
    │   └── figures/
    └── docs/
```

这里的：

```text
EXP01
```

是**新研究阶段内部编号**。

不是旧 EXP001，也不是 EXP012。

---

## 22. SAR 阶段真正要验证什么

下一阶段不是：

> “Proposed 聚焦图看起来是不是更漂亮？”

而是建立完整的物理链：

```text
branch error
        ↓
parameter mismatch
        ↓
phase mismatch
        ↓
SAR focusing mismatch
        ↓
scattering-energy redistribution
        ↓
weak scatterer loss
 / ghost
 / sidelobe structure
        ↓
branch rescue
        ↓
这些结构恢复了什么？
```

下一阶段的核心研究问题是：

> **signal-level branch error 在 SAR 成像链中究竟变成了什么，以及 successful branch rescue 恢复了哪些散射结构。**

因此优先做：

```text
minimal SAR image-level translation
```

而不是继续增加：

```text
新 gate
N5 / N7
更多 budget
更多 AWGN
更多平行方法
```

---

## 23. 后续 SAR 图像实验应该重点看什么

下一阶段主要回答：

```text
branch reliability gain
        ↓
是否真的转化为
SAR image-level structural benefit?
```

重点指标应控制在少量具有物理意义的指标上，例如：

```text
image entropy
image contrast
strong-scatterer azimuth profile
IRW
PSLR
weak-structure preservation
ghost / false structure
```

最值得展示的 case 是：

```text
G0 catastrophe
→ Proposed rescue

G0 success
→ Proposed unchanged

difficult local-clutter case

Proposed residual failure case
```

这样才能真正形成：

```text
search-level paired rescue
        ↓
image-level consequence
```

---

## 24. `docs/research_evolution/` 的作用

已有总结材料不应该全部揉成一个 README。

建议建立：

```text
docs/
└── research_evolution/
```

内部保存：

```text
EXP009_FULL_CHAIN_REVIEW_v1.1.md
EXP009_EXP010_CLAIM_EVIDENCE_MATRIX_v1.0.md
NOVELTY_ATTACK_AND_GAP_AUDIT_v1.0.md

theory/
└── UNIFIED_THEORY_DRAFT_v0.2.*
```

它们分别承担不同作用：

| 文档 | 作用 |
|---|---|
| `EXP009_FULL_CHAIN_REVIEW_v1.1.md` | 解释“为什么研究会走到今天”，保存研究演化与 provenance |
| `EXP009_EXP010_CLAIM_EVIDENCE_MATRIX_v1.0.md` | 说明“每个 Claim 由哪些实验支撑”，用于 evidence freeze |
| `NOVELTY_ATTACK_AND_GAP_AUDIT_v1.0.md` | 说明“哪些创新能守、哪些话不能说”，用于 novelty 与 reviewer attack |
| `UNIFIED_THEORY_DRAFT_v0.2.*` | 理论母稿，为最终论文数学部分服务 |

README 只做：

```text
研究地图 + 导航
```

而不是复制这些长文档。

---

## 25. Git 中应该保存什么

Git 最重要的作用不是备份所有实验输出，而是保存：

```text
代码
配置
实验设计
parameter provenance
summary
理论推导
README
研究决策历史
```

大型：

```text
.mat
large CSV
raw Monte Carlo trials
generated figures
```

继续保留本地即可。

因此 Git 保存的是：

> **reproducible research history**

而不是：

> hard-drive backup。

---

## 26. 未来论文真正收敛时怎么办

等第一篇论文结构完全稳定以后，可以另外建立：

```text
publication/
└── reliability_aware_ship_refocusing/
```

这时候再从：

```text
EXP009
EXP010
EXP011
SAR-EXP01...
```

中抽取真正需要的部分。

最后形成：

```text
publication/
├── README.md
├── src/
├── configs/
├── experiments/
└── figures/
```

届时再统一：

```text
函数接口
文件命名
路径
配置
结果格式
```

会比现在直接迁移历史代码合理得多。

换句话说：

```text
Research Repository
保存“我们怎么发现这个问题”

Publication Package
保存“别人怎么复现最终方法”
```

这两个本来就应该是不同层级。

---

## 27. 当前整个 Xu2025 研究线的状态

现在可以把状态明确写成：

```text
Xu 2025 核心复现
DONE

Tracking / local-search extension
DONE

Multi-component / weak recovery exploration
DONE

EXP009 failure mechanism
DONE / EVIDENCE FROZEN

EXP010 practical non-oracle closure
DONE / EVIDENCE FROZEN

EXP011 theory validation
ACTIVE / CONVERGING

SAR image-level physical translation
NEXT
```

而且到这个位置，已经形成一条比较清楚的研究主线：

```text
Xu 2025
局部快速搜索
        ↓
搜索什么时候不可靠？
        ↓
弱分量什么时候开始丢？
        ↓
有限窗 / off-grid
        ↓
strong leakage + weak damage
        ↓
coherent residual
        ↓
objective deformation
        ↓
branch competition
        ↓
rare catastrophic failure
        ↓
internal reliability state
        ↓
selective Neighbor-3
        ↓
practical non-oracle
        ↓
conditional validity
        ↓
SAR image-level physical consequence
```

这条链能够比“复现 Xu 2025 后继续做了很多实验”更准确地描述当前项目的真实演化。

---

## 28. 当前推荐的仓库整理动作

当前不再继续扩写 README，而是完成两个小的仓库整理闭环：

### 28.1 建立研究演化文档目录

```text
papers/
└── Xu2025_Adaptive_Fast_Refocusing/
    └── docs/
        └── research_evolution/
```

把现有研究总结、claim-evidence matrix、novelty audit 和理论母稿正式归位。

### 28.2 建立新 SAR 研究工作区

```text
research/
└── branch_reliability_sar/
```

历史 EXP009–EXP011 不迁移。

从这个目录开始，所有新的 SAR image-level physical validation 使用新的阶段内部实验编号。

完成以后，可进行一次独立 Git checkpoint，例如：

```text
docs: document research evolution and establish SAR research workspace
```

从该 checkpoint 开始：

> **Xu2025 研究史冻结，新 SAR 研究阶段正式开始。**
