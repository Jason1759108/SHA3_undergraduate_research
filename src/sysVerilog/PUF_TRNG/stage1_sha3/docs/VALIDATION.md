# 第一階段驗證紀錄

## 2026-11-09 Reset 修正版

本次已修正來源與既有 Block Design，重新跑 synthesis / implementation / write_bitstream。上板步驟見 [修正版操作](FIXED_RELEASE_STEPS.md)。以下是本機實際完成的檢查；尚未在實驗室實板驗收。

| 檢查 | 結果與範圍 |
|---|---|
| 原始 01_RTL | 15 個凍結來源雜湊符合，未改動原始 SHA3 |
| Reset 原因重現 | 實際 reset IP 功能網表：aux=0 不能解除 reset；aux=1 可解除並可再次 reset |
| 舊錯誤 HWH 防護 | archived_reset_bug 真實舊 HWH 被 Python 離線檢查拒絕；Tcl reset guard 亦已驗證拒絕舊接線 |
| 核心一般回歸 | 本次重跑 18 cases PASS |
| parity/replay 回歸 | 本次重跑 153 cases PASS |
| AXI wrapper + 真實核心 | 本次重跑 34 個標準比較與 2 次恢復後比較 PASS；涵蓋 backpressure、錯誤封包、reset |
| 完整 BD 行為模擬 | 36 次 SHA3 比較 PASS；實際 vendor DMA/interconnect/reset、PS GP0 MMIO、VIP DDR 輸入、獨立 HP0 byte scoreboard |
| 系統恢復 | malformed header 後 abc PASS；兩通道 Halted 後 PL reset，再啟動及 abc PASS |
| PS HP0 輸出監看 | 檢查 RX 位址、burst、5 beats、WSTRB、WLAST、BRESP=OKAY、9 output words 與 guard |
| PYNQ v2.5 HWH parser | 執行官方原始 parser，辨識 25 MHz、DMA 0x40400000 與 sha3 階層；CMA 容量查詢使用 mock |
| PYNQ v2.5 DMA API | 執行官方原始 DMA/_DMAChannel，搭配 mock MMIO/記憶體；17 種訊息與故障/恢復分支 PASS |
| Python/notebook | driver 與所有 notebook code cells 符合 Python 3.6 語法；JSON 正常 |
| RTL 複本一致 | 15 個來源對照 IP repo、專案 ipshared 與模擬 ipshared，僅正規化 CR 換行後均相同 |
| Routed timing | 25 MHz，WNS +3.834 ns、WHS +0.022 ns；setup/hold failing endpoints 均為 0 |
| Clock constraints | no_clock、constant_clock、unconstrained_internal_endpoints、multiple_clock、loops 均為 0 |
| 使用資源 | 13,061 LUT、9,744 FF、2 BRAM tiles、0 DSP、1 BUFG |
| DRC | 0 Error / 0 Critical Warning；12 Warning、2 Advisory，詳見下方，不代表無任何警告 |

日誌：`build/reset_audit/step2.log`、`connection_check.log`；`build/simulation/`、`regression_normal/`、`regression_ft/`；完整 BD 的 `build/sha3_pynq/sha3_pynq.sim/sim_1/behav/xsim/simulate_driver.log`；摘要 `build/system_sim_result.json`、`build/pynq25_compat/host_checks_passed.json`；建置 `build/repair_build.log`；發布 `build/final_export.log`；報告 `build/reports/`。

### 明確保留的限制

- vendor PS VIP 已接受正確 HP0 地址、data、strobes 並回傳 OKAY，但其 `read_mem` backdoor 在初始測試仍讀到預填值。等待後仍未更新，具體模型原因未釐清。最後測試使用不驅動 DUT 的獨立 HP0 byte scoreboard 核對實際匯流排輸出；不宣稱 VIP DDR storage 回讀通過。初始檢查的 `debug.vcd` / `debug_driver.log` 留在同一 xsim 目錄供追溯。
- 系統模擬包含真實 RTL/vendor IP 與 PS transaction 模型，沒有執行 ARM Linux、PYNQ FPGA manager、實體 DDR 訓練、供電或網路。PYNQ 軟體檢查是 mock，不是板上 17 次測試。
- DRC 保留 PDCN-1569 3 項、REQP-1839 8 項、RTSTAT-10 1 項，另 REQP-181 2 項 Advisory，位置在 vendor FIFO/interconnect/BRAM；timing methodology 另列 LUTAR-1。未將這些規則降級或關閉。系統模擬與 routed timing 提供補充證據，但仍需實板驗收。
- PS board preset 的負 DQS skew 警告與其他未安裝裝置的 Board 49-26 警告保留。overlay 沿用板上開機時的 DDR 初始化；沒有修改實驗室 SD image 或 boot 設定。
- 原本 cross-lane force/release testbench 的 XSIM 不支援限制仍存在；本次 153 組 ft suite 另外通過，不能替代該 testbench 的執行紀錄。
- 實板成功條件為新 release 的 abc 與 34 次 hashlib 比對通過。不能承諾 100% 上板一定成功。

### 修正內容

低有效 aux_reset_in 改接 constant_one，dcm_locked=1、mb_debug_sys_rst=0；build/export 與 Python 都檢查極性及接線。Python 在下載前檢查 bit/hwh 雜湊、時脈、reset、Stream、AXI 與 DMA 位址；啟動與恢復增設檢查點、有界輪詢及停止失敗保留緩衝區。發布時比對系統模擬 HWH/來源雜湊、PYNQ driver 測試雜湊及所有 IP 複本，避免只改來源卻匯出舊 IP。

### 已發布版本

- build_id：`sha3-reset-fixed-20261109T135050Z`（UTC 時間；本地為 2026-11-09 21:50:50）
- bit SHA-256：`12dcce5673dad7d3ad21f1f1f6f5a85b427d58d6d3464b74923fe57934f8da0e`
- hwh SHA-256：`56306f1b0dd324f7f4457f2a112f9c761c7dc976844f43c7dcd4ff7d604f27e1`
- 位置：`build/overlay`，五個檔案已透過最終離線檢查。

## 2026-11-08 歷史紀錄（含舊 reset 錯誤）

以下保留當時的結果與檔案雜湊，供追溯；不是目前可上板版本。


**2026-11-08 補充。** 下列已完成的 SHA-3、wrapper、時序與 DRC 結果仍是該次測試的紀錄，但該次未包含完整 Block Design 的 reset 功能驗證。之後查出低有效 `aux_reset_in` 接到常數 0，會永久重設 DMA 與 AXI interconnect。已用實際生成的 Reset IP 功能網表重現。現有 `build/overlay/` 硬體檔案須先修正並重建，詳見 [事故檢查](INCIDENT_RESET_AUDIT.md)。

驗證日期為 2026-11-08，工具為本機安裝的 Vivado / Vivado Simulator 2025.2，目標晶片 `xc7z020clg400-1`。

交付設定為 PS FCLK0 **25 MHz**，週期 40 ns。先前 50 MHz 嘗試在佈線途中出現壅塞，曾達 WNS=-1.321 ns，因此停止該次嘗試並改用較寬裕的 25 MHz。這個數字是該次的中途估計值。先前紀錄保存在 `build/attempt_50mhz/`。

## 已完成的功能驗證

| 項目 | 結果 | 日誌或證據 |
|---|---|---|
| 原始 RTL 基準 | 15 個原始來源的 SHA-256 均符合建立時的快照 | `baseline_manifest.json`，`python verify_baseline.py` |
| FPGA CE 核心的一般回歸 | 18 組 SHA3-256 cases 通過 | `build/regression_normal/simulation.log` |
| FPGA CE 核心的故障回歸 | 153 組 parity/replay cases 通過 | `build/regression_ft/simulation.log` |
| 真實核心 + AXI wrapper | 17 種訊息跑兩輪，digest 全部與 hashlib 一致，另通過錯誤恢復後的 abc | `build/simulation/simulation.log` |
| AXI 流量控制 | 輸入間隔、輸出 backpressure、TKEEP/TLAST、錯誤 header、提早 TLAST、錯誤封包 drain、重設後再送訊息均通過 | 同上 |
| Python 封包與 digest 解析 | 所有標準向量可還原原訊息，little-endian digest 解析一致 | 本機 Python 檢查 |
| Python DMA 恢復路徑 | 以 mock DMA 檢查正常傳輸、timeout 保留 buffer、重設後換新 DMA driver、重新傳輸與釋放 buffer | 本機 Python 檢查 |
| notebook | JSON 與所有 code cells 語法檢查通過 | `python/SHA3_Bringup.ipynb` |
| IP 打包與 Block Design | S_AXIS/M_AXIS、clock/reset 介面成功推斷，BD 建立、Validate Design、HDL wrapper 與 hwh 生成完成 | `build/create_project.log` |

一般與故障回歸直接使用複製的原本 testbench，FPGA 核心使用 CE 版本。AXI 測試的參考值由 Python `hashlib.sha3_256()` 產生，包含 0、1、3、4、7、31、32、64、135、136、137、271、272、273、1000、4096 bytes 及明確的 `abc` 訊息。

## 額外測試的模擬器限制

也嘗試過原本的 `TESTBED_CROSS_LANE.sv`。XSIM 在 elaboration 階段回報 `VRFC 10-3149`，原因是對 unpacked array 的 variable 元素使用 bit-select force/release。該測試留在 `sim/baseline/` 作為原始參考，這次的 XSIM 執行入口提供 axis、normal 與 ft 三組已通過的 suite。故障回歸的 153 組結果列在上表。

## 完整 FPGA 實作結果

25 MHz 版本已完成 synthesis、placement、routing、write_bitstream 及同名 bit/hwh 匯出。最後建置於本機時間 18:41 完成。

| 項目 | 結果 |
|---|---|
| Clock | `clk_fpga_0`，40.000 ns，25 MHz |
| WNS / TNS | +3.834 ns / 0.000 ns |
| WHS / THS | +0.022 ns / 0.000 ns |
| Pulse-width slack | +18.750 ns，0 failing endpoints |
| 未約束的內部 endpoints | 0 |
| 缺少 clock 的 register pins | 0 |
| Routing | 21,245 條可路由 nets 全數完成，0 routing errors |
| Bitstream DRC | 0 errors |
| LUT | 13,061 / 53,200，24.55% |
| Flip-flop | 9,744 / 106,400，9.16% |
| BRAM tiles / DSP | 2 / 0 |
| BUFG | 1 |

資源數字包含 SHA-3、DMA、AXI interconnect、reset 等整個 overlay。報告在 `build/reports/timing_summary.rpt`、`utilization.rpt`、`drc.rpt`、`clocks.rpt`。完整建置日誌為 `build/build_25mhz.log`。

上板所需的四個檔案都在 `build/overlay/`。Python driver 與 notebook 已核對與 `python/` 的交付版本相同，HWH 已核對 `/sha3/sha3_dma` 為 AXI DMA 7.1、FCLK0 為 25 MHz。

| 檔名 | SHA-256 |
|---|---|
| `sha3_pynq.bit` | `cf6626b4fabddaaebb5efe739b727098e61f8b94761b78f772cfe8c3f74adb0a` |
| `sha3_pynq.hwh` | `0038bcebb13a39f210be9d140ee2ef92f1970e4b2b2337a3dc22fd381fad4a68` |

這兩個 hash 對應本次生成的檔案。重新建置後應記錄新檔案的 hash。

## 建置時的工具訊息

- IP Packager 對 SystemVerilog top 顯示 `IP_Flow 19-5101`，本次 top 是平坦的 wire ports，兩個 AXI Stream 介面及 clock/reset 已成功推斷並通過 BD 驗證。
- 官方 PYNQ-Z2 board preset 含四組負的 DDR DQS-to-clock delay，Vivado 2025.2 在最初 BD 驗證時顯示 `PSU-1` 至 `PSU-4` critical warnings。這些值沿用附帶的官方 board preset。實板驗證需依實驗室現有板卡／PYNQ 環境確認。
- 初次建置腳本曾嘗試設定工具衍生的 reset polarity 與 GP0 frequency 參數，收到 read-only 警告。已從交付腳本移除這些設定。已確認 reset block 的 `C_EXT_RESET_HIGH=0`。交付的 FCLK0 設為 25 MHz。
- 2025.2 對 Constant IP 建議遷移至 inline HDL，該版本仍可生成本設計使用的 Constant IP。
- AXI interconnect 生成時出現 ID 寬度轉換相關訊息，對照實作的 DRC 與 timing report 檢查最終設計。
- 最終 DRC 保留 12 個 warnings 與 2 個 advisories。分類為 `PDCN-1569` 3 個、`REQP-1839` 8 個、`RTSTAT-10` 1 個、`REQP-181` 2 個，位置集中在 DMA 與 interconnect 的生成電路。詳見 `build/reports/drc.rpt`。
- Methodology 另外保留 4 個 `LUTAR-1` 非同步 reset 警告，列於 timing report。設計使用低有效 reset，錯誤封包處理也會重設核心。實板需驗證載入、連續訊息與恢復流程。

## 實板驗證

實驗室 PYNQ-Z2 上的執行由使用者在已登記時段進行。完成後保存板號、PYNQ 版本、bitstream SHA-256、abc 比對及 `SUCCESS 34 FPGA SHA3-256 comparisons` 輸出。功能模擬與 implementation 結果共同作為上板前的依據，實板結果另行記錄。
