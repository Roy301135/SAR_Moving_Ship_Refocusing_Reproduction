# Branch Reliability in SAR — Controlled and Real-Data Validation

> 本目录用于记录复杂运动舰船 SAR 非聚焦研究中，从搜索/信号级 branch reliability 机制向受控 SAR、公开真实复数 SLC、真实失焦舰船数据以及 model-gap 诊断的完整研究链。
>
> MATLAB 为主要实验语言。

---

## 1. 当前研究定位

本工作最初关注：

```text
G0 discrete-first branch failure
        ↓
Neighbor-3 local branch redundancy
        ↓
reliability-aware selective recovery
```

在 model-matched synthetic / controlled experiments 中，上述局部 branch-recovery 机制得到了验证。

进入真实 SAR 数据后，问题逐步收敛为：

> 为什么 synthetic 中成立的 local branch-recovery regime，在真实严重失焦舰船上并不占主导？真实数据中的剩余失焦更可能由什么 signal/model gap 产生？

当前研究链：

```text
signal/search-level mechanism
        ↓
controlled SAR physical translation
        ↓
OpenSARShip complex-SLC applicability audit
        ↓
FAIR-CSAR real component validation
        ↓
real branch occurrence / geometry
        ↓
Candidate-C independent replication
        ↓
R2A branch contribution audit
        ↓
GAP01 real-vs-synthetic gap audit
        ↓
literature-gated non-branch mechanism study
```

---

## 2. 与历史 Xu 2025 复现线的关系

历史复现与由复现衍生的原创实验仍保留在：

```text
papers/Xu2025_Adaptive_Fast_Refocusing/
```

其中 EXP009–EXP011 已经超出单纯论文复现，形成了独立的 failure-mechanism / reliability-aware recovery 研究。

本目录：

```text
research/branch_reliability_sar/
```

不继续历史编号，而作为新的 SAR 物理映射与真实数据验证 workspace。

---

## 3. 当前目录结构

```text
research/branch_reliability_sar/
├─ README.md
│
├─ code/
│  ├─ exp01_sar_branch_translation/
│  └─ exp02_real_sar_branch_audit/
│     ├─ opensarship/
│     └─ fair_csar/
│
├─ functions/
│  ├─ fair_csar/
│  └─ opensarship/
│
├─ docs/
│  ├─ EXPERIMENT_INDEX.md
│  ├─ CURRENT_RESEARCH_CHECKPOINT.md
│  ├─ REAL_DATA_VALIDATION_SUMMARY.md
│  └─ historical experiment documents...
│
└─ results/
   ├─ exp01_sar_branch_translation/
   └─ exp02_real_sar_branch_audit/
      ├─ opensarship/
      └─ fair_csar/
```

Git 仓库建议主要跟踪：

```text
code/
functions/
docs/
README.md
```

而大体积生成结果（MAT、完整 CSV、批量 PNG）默认保留本地。

---

## 4. EXP01 — Controlled SAR Physical Translation

代码目录：

```text
code/exp01_sar_branch_translation/
```

主要阶段：

```text
Stage A   controlled SAR geometry / static-reference BP
Stage B   residual LFM physical interface
Stage B2  synthetic hard-state physical embedding
Stage B3  natural target-line branch audit
Stage B4  3-D roll/pitch/yaw swing audit
Stage B5  ERV / IPP effective observation geometry audit
```

当前阶段性结论：

1. 受控 SAR 条件下，部分真实物理散射历史可以被 quadratic LFM 很好近似；
2. 将 synthetic hard branch state 直接嵌入受控 SAR 物理场景并不容易；
3. 即使引入 3-D 舰船摆动和显著 ERV / IPP 动态，也不会自动产生 synthetic 中的 local-N3 failure；
4. 因此：

```text
complex motion / visible defocus / dynamic observation geometry
```

并不充分推出：

```text
local branch risk
```

EXP01 对当前 branch 问题视为阶段性 CLOSED。

---

## 5. EXP02 — Real SAR Branch Audit

### 5.1 OpenSARShip

代码：

```text
code/exp02_real_sar_branch_audit/opensarship/
```

实验：

```text
R0A  complex-SLC interface gate
R0B  real single-LFM compatibility audit
R0C  cross-ship interface replication
```

结论：

- complex SLC 接口成立；
- 但 tested targets 上的单 LFM 证据不足以直接支撑 source-aligned MC-LFM branch validation；
- 因此停止继续在 OpenSARShip 上寻找 branch rescue，并切换到 FAIR-CSAR。

OpenSARShip 的价值是：

```text
data/interface applicability audit
```

而不是：

```text
最终 branch-mechanism validation dataset
```

---

## 6. FAIR-CSAR 实验链

### R0 — Model / Component Validity

主要脚本：

```text
run_exp02_fair_r0_positive_control.m
run_exp02_fair_r0.m
run_exp02_fair_r0_phase_sensitivity_gate.m
run_exp02_fair_r0_component_consistency_gate.m
```

关键过程：

1. 初版 fractional-autocorrelation scalar diagnostic 未通过 synthetic positive control；
2. 改为 Xu Eq.(31)-consistent FrAc-energy objective；
3. corrected diagnostic 可以精确恢复已知 synthetic LFM order；
4. real Candidate B 存在 phase-sensitive、non-p=1、跨 range-cell recurrent 的 LFM-compatible structure。

边界：

```text
LFM-compatible recurrent structure
!=
whole real range-column is exact MC-LFM
```

---

### R1A — Dominant Recurrent Component Audit

```text
8 / 8 SAFE
0 natural Neighbor-3 rescue
```

说明：

```text
visible defocus != branch failure
```

---

### R1B — Full Frozen Candidate-B Pool

```text
62 Wang-selected ship lines
55 lines with >=1 valid component
222 valid component states

SAFE                      203
G0_FAIL_N3_RESCUE           0
N3_COVERAGE_MISS            19
PERSISTENT_WITHIN_COVERAGE   0
```

因此：

```text
19 / 222 = 8.56%
```

accepted states 为 non-SAFE。

真实 branch failure 得到验证。

---

### R1C — Failure Geometry / Component Validity

在 19 个 non-SAFE states 中：

```text
11 / 19
```

满足 frozen local recurrence credibility rule。

但：

```text
0 / 19
```

的 global basin 位于 frozen Neighbor-3 coverage 内。

真实 failure geometry 更接近：

```text
remote, near-equal basin competition
```

而不是：

```text
local k0-1 / k0 / k0+1 competition
```

---

### R1D — Candidate C Independent Replication

冻结 Candidate-B pipeline，不调参。

结果：

```text
45 Wang-selected ship lines
22 lines with valid components
69 valid component states

SAFE               67
N3_COVERAGE_MISS    2
G0_FAIL_N3_RESCUE   0
```

两个 failure 均未满足 recurrent credibility gate。

因此 Candidate C：

- 弱复现了 real remote branch failure 可以发生；
- 未复现 Candidate B 中较明显的 recurrent remote failure population；
- 仍未出现 natural frozen-N3 rescue。

---

## 7. R2A — Branch Contribution Audit

主脚本：

```text
run_exp02_fair_r2a_branch_contribution_candidate_b.m
```

当前有效 helper：

```text
functions/fair_csar/refocus_mclfm_branch_native_clean.m
```

处理链：

```text
recenter by nu
-> matched-LFM dechirp
-> FFT
-> frozen finite extraction
-> inverse transform
-> undo recenter
-> sequential subtraction / accumulation
```

R2A 比较：

```text
Frozen G0 branch
vs
evaluation-only Global branch
```

其余 component set、p_beta、顺序、operator 均冻结。

结果：

- branch substitution 的变化几乎完全局限于 R1 failure columns；
- 但整体 entropy / W80 / concentration 只出现小幅且不一致变化；
- 因此 branch failure 是真实且具有空间因果性的，但在当前 accepted component model 下，剩余 branch headroom 有限。

---

## 8. GAP01 — Real-vs-Synthetic Gap Audit

主脚本：

```text
run_exp02_fair_gap01_real_vs_synthetic.m
```

### A. Real-state parameter-support exact clones

Candidate B 全部：

```text
222
```

个 accepted real-state `(p_beta, global_nu)` 被逐个合成为 exact quadratic-LFM clone。

结果：

```text
G0 truth match       222 / 222
N3 truth match       222 / 222
max G0 error         ~9.87e-7 bin
max N3 error         ~9.03e-7 bin
max Global error     ~7.17e-9 bin
```

因此：

```text
synthetic -> real gap
```

不能由：

```text
R1 code only works for artificial parameter ranges
```

来解释。

---

### B. Real single-quadratic-LFM adequacy

结果：

```text
median frozen atom coherence        ~0.02994
median locally relaxed coherence    ~0.03587
median local-p gain                 ~0.00360
p90 local-p gain                    ~0.01156
gain >= 0.02                        ~2.25%
```

仅做：

```text
p_beta +/- 0.04
```

的小范围修正，不能解释 real-vs-synthetic gap。

但由于 local-p scan 仍有非零 boundary-hit rate，因此不能完全排除更大的 upstream FM-rate mismatch。

---

### C. Joint (p_beta, nu) Landscape

Exact synthetic clones：

```text
clean / structured / localized objective geometry
```

Representative real states：

```text
multiple ridges
remote competing basins
broad / speckled objective structure
```

当前最合理的判断是：

```text
implementation / parameter-range mismatch
不是主因
```

而：

```text
broader real-data signal/model/mixing gap
```

优先级上升。

---

## 9. 当前已经验证的内容

```text
1. model-matched local discrete-first branch failure 机制成立；

2. 正确 basin 位于 Neighbor-3 coverage 内时，
   local branch redundancy 可以有效恢复；

3. controlled SAR 中 residual quadratic-LFM approximation 在一定条件下成立；

4. FAIR-CSAR 中存在 phase-sensitive recurrent LFM-compatible structure；

5. Candidate B 中真实 branch failure 确实存在；

6. Candidate B 中 observed failures 主要属于 remote-basin coverage misses；

7. R1 failure locations 与 R2A branch-substitution changes 空间一致；

8. R1 implementation 在 Candidate-B 实际 (p_beta,nu) 参数范围上，
   对 exact synthetic clones 完全闭环。
```

---

## 10. 与原预期不一致的内容

```text
1. 两个 frozen FAIR targets 中都没有发现 natural G0-fail/N3-rescue；

2. severe visible defocus 并不意味着高 branch-failure prevalence；

3. Candidate B 的 recurrent remote failures 未在 Candidate C 强复现；

4. Global branch substitution 没有带来明显、一致的整体聚焦改善；

5. 小范围 p_beta correction 不能解释 real-vs-synthetic gap。
```

---

## 11. 当前 Research Boundary

当前 branch / Neighbor-3 线已经完成：

```text
mechanism verification
+
controlled SAR applicability audit
+
real occurrence audit
+
failure-geometry boundary
+
independent replication
+
image-level contribution audit
+
real-vs-synthetic gap audit
```

因此现阶段不应为了获得预期结果而继续事后扩张：

```text
N5 / N7
larger local window
Top-K rescue
new branch thresholds
new reliability feature
```

下一阶段应先经过新的 literature gate，再决定重点诊断：

```text
higher-order / nonlinear phase
multi-component coupling
sequential-removal residual
spatially variant defocus
range-cell / scatterer mixing
larger upstream FM-rate mismatch
```

---

## 12. 代码注意事项

当前有效 R2A helper：

```text
refocus_mclfm_branch_native_clean.m
```

旧文件：

```text
refocus_mc_lfm_clean_branch_locked.m
```

曾尝试将 R1 的 dechirped-tone `nu` 映射到 `frft_direct` 的有限 `u` grid，
该接口后来被证明不正确。

因此该文件应视为：

```text
DEPRECATED / DO NOT USE
```

建议后续 Git checkpoint 中不再公开跟踪此 helper。

---

## 13. 文档导航

建议首先阅读：

```text
docs/CURRENT_RESEARCH_CHECKPOINT.md
docs/EXPERIMENT_INDEX.md
docs/REAL_DATA_VALIDATION_SUMMARY.md
```

其中：

```text
CURRENT_RESEARCH_CHECKPOINT.md
    当前研究状态 + 下一阶段入口

EXPERIMENT_INDEX.md
    代码 / 文档 / 结果目录索引

REAL_DATA_VALIDATION_SUMMARY.md
    OpenSARShip → FAIR-CSAR 的完整真实数据证据链
```
