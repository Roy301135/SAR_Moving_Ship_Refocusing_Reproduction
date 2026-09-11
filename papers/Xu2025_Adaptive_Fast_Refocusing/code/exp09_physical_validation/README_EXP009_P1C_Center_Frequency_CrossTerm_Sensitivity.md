# EXP009 / Physical Validation Track / P1C
## Center-Frequency / Cross-Term Sensitivity Audit

### 1. 定位

P1C 是进入 PA4 之前的 **最后一个 Wang 2023 reproduction audit**。

无论结果支持还是不支持原先机制，P1C 做完后都不再通过调节 Wang 未公开参数来“追 Fig. 8”。

科研目标不是强行保住旧结论，而是确定：

> 哪些现象在有出处、可解释的物理/数值条件下仍然成立。

---

## 2. 为什么检查 b_i

Wang 2023 Eq. (13) 明确将每个 MC-LFM component 写成：

`l_i[m] = exp{j2pi(0.5*a_i*m^2 + b_i*m)}`

其中：

- `a_i` = modulation frequency / chirp-rate parameter
- `b_i` = center frequency

P0/P1/P1B 已经通过 Wang/Xu 参数把 `a_i` 锚定到真实 azimuth velocity。

但 Wang 五点实验并没有公开 exact `b_i`。

P1B 为隔离 chirp-rate effect 统一采用 `b_i=0`，因此不同分量的 cross-term geometry 可能比 Wang 实际仿真更强地重叠。

P1C 专门测试这一点。

---

## 3. 不自行编造 b_i：用 Fourier-bin spacing

P1C 定义：

`Delta b = gamma / N`

`b_i = [-2,-1,0,1,2] * Delta b`

其中：

`gamma = [0, 0.5, 1, 2, 4]`

含义：

- `gamma=0`：复现 P1B 的 `b_i=0`
- `gamma=1`：相邻 component center frequency 相差 1 个 DFT bin
- `gamma=2`：相邻相差 2 bins
- `gamma=4`：相邻相差 4 bins

这仍然是 controlled sensitivity，不是 Wang paper parameter。

---

## 4. 固定的物理条件

P1C 不再扫 geometry：

`R0/H = sqrt(2)`

固定继承 P1/P1B 代表场景。

只保留两个 aperture：

- `Paper1s`
- `BeamDerived`

物理 chirp rates `a_i` 完全固定，不随 `gamma` 改变。

不加：

- noise
- CLEAN
- adaptive search
- learned model

---

## 5. 比 P1B 多做一个关键分解：ideal auto vs coherent total

P1C 不只看 total FrAc 有没有五峰。

它显式计算：

### Ideal incoherent auto envelope

把每个 component 的 self-FrAc energy 独立求和：

`E_auto_ideal = sum_i sum_k |R_ii(beta,k)|^2`

它排除了 inter-component coherent interference。

因此：

> 如果 ideal auto 自己都不能形成 5 个可分峰，那么根本瓶颈是 aperture / intrinsic response width，而不是 cross-term。

### Coherent auto

`R_auto = sum_i R_ii`

### Total response

`R_total`

### Cross response

`R_cross = R_total - R_auto`

然后：

`E_cross = sum_k |R_cross|^2`

并输出：

- global cross/auto ratio
- true-beta 附近 cross/auto ratio
- auto-cross interaction / auto ratio

---

## 6. 三类最有价值的结果

### Branch A — Resolution-limited

如果：

`ideal incoherent auto` 都不能稳定出现 5 peaks

那么：

> P1B 的失败首先是 aperture / response-width resolution limit。

此时不应该继续用 b_i 强行救五峰。

PA4 应使用：

`Gamma = Delta beta / W_3dB`

作为明确的 controlled physical separation。

---

### Branch B — b_i / cross-term explains the gap

如果：

- ideal auto 能分 5 peak
- gamma=0 coherent total 不能
- gamma 增大后 total five-peak rate 明显上升
- cross/auto contamination 同时下降

那么：

> Wang 未公开的 b_i / cross-term geometry 是解释 Fig. 8 reproduction gap 的可信缺失因素。

PA4 可以把 b_i 作为 controlled nuisance parameter。

---

### Branch C — Phase-sensitive coherent interference persists

如果：

- ideal auto 可分
- phase-averaged total 可能出现 5 peaks
- single-realization MC rate 仍低

那么：

> phase-sensitive cross-term interference 是主要瓶颈。

这会直接与 EXP009 之前的 coherent perturbation 研究主线发生联系。

---

## 7. 输出文件

优先上传：

- `summary.txt`
- `p1c_decision_summary.csv`
- `p1c_sweep_summary.csv`
- `representative_component_parameters.csv`
- `fig01_detection_rate_vs_gamma.png`
- `fig02_cross_to_auto_vs_gamma.png`
- `fig03_paper1s_gamma0_decomposition.png`
- `fig04_paper1s_gammaMax_decomposition.png`
- `fig05_beam_gamma0_decomposition.png`
- `fig06_beam_gammaMax_decomposition.png`
- `fig07_ideal_auto_vs_total.png`

---

## 8. 运行

代码目录：

`E:\SAR_Moving_Ship_Refocusing_Reproduction\papers\Xu2025_Adaptive_Fast_Refocusing\code\exp09_physical_validation`

运行：

```matlab
results = exp09_p1c_center_frequency_crossterm_sensitivity;
```

结果：

`results\exp09_physical_validation\exp09_p1c_center_frequency_crossterm_sensitivity`

---

## 9. P1C 后的固定路线

无论 P1C 是哪一个 branch：

`P0 -> P1 -> P1B -> P1C -> PA4`

不再增加 `P1D/P1E` 去调 Wang 未公开参数。

如果原先机制在 physical validation 中失效：

> 正式记录其适用边界，停止维护旧结论，继续寻找在真实/文献锚定条件下出现的新机制。

这本身就是科研结果。
