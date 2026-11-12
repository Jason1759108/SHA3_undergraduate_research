# V0／V1／V2 單 block 正式結果

來源：工作站 `project_run/single_block_10ns/` 的 2026-11-13 回收小檔案。`V012_single_block_10ns.csv` 為寫論文及製作 R7、F8 的**唯一三版主表**。三個 `*_135byte_cycles.csv` 各保存兩筆 135-byte 正常測例的原始週期列；三個 `*_01.log` 保存完整 01 RTL suite 的通過提示。每版的兩筆測例均為一次 permutation、`e2e_cycles=258`、`core_cycles_total=241`，且完整 01 suite 顯示 `[SUCCESS]`。

主表中的面積、static/dynamic/total power、slack、02/03 狀態與 SDF 警告數取自 [2026-11-04 已封存的 10 ns 結果](../2026-11-04_四版10ns/)；本次只重跑 01 RTL，未重跑 02/03。補測腳本在執行前核對了與 10 ns 記錄相同的 RTL、TB、monitor、filelist 及 runner 來源指紋；下載包中的 `reference_sources.json` 與本地生成時的版本相同。本資料夾不保存補測腳本、netlist、SDF 或工具暫存目錄。

## 論文數字

| 版本 | 135-byte 週期 | 10 ns 單 block 吞吐 (Gbps) | 整顆 SHA3 總功耗 (mW) | 估計 P/T (pJ/有效輸入 bit) | cell area（原報告數值） | 01／02／03 |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| V0 基準 | 258 | 0.418604651 | 2.0176281 | 4.819889350 | 47995.187680 | PASS／OK／PASS_WITH_SDF_WARNING |
| V1 1600-bit SECDED | 258 | 0.418604651 | 3.5283499 | 8.428835872 | 93673.840758 | PASS／OK／PASS_WITH_SDF_WARNING |
| V2 lane-level SECDED | 258 | 0.418604651 | 3.3803968 | 8.075392356 | 91894.367726 | PASS／OK／PASS_WITH_SDF_WARNING |

`T = 135 × 8 / (258 × 10 ns) = 0.418604651 Gbps`。每版 `P/T = 10 ns 整顆 SHA3 的 total_power_mw / T_Gbps`。V2 相對 V1 的 P/T 低約 **4.19%**，因為本次兩版週期相同，這個百分比也等於總功耗的差幅。功耗是 02 Design Compiler 估計值，**不是**晶片實測能量或活動波形功耗。03 的 `PASS_WITH_SDF_WARNING` 表示正常功能 PATTERN 通過，仍有 SDF 警告；不可寫成完全無警告的 timing signoff。兩版 10 ns slack 報告顯示 0.00，不能由此推得更短週期仍能通過。

`core_cycles_total=241` 是單次 Keccak core 的另列觀察，不加入論文主 P/T 的分母，也不能取代端到端 `e2e_cycles=258`。舊 240-cycle 與 4096-byte P/T 留在 10 ns 原始 CSV 供來源核對，正文只引用本表的單 block 欄。
