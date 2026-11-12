# Person A 論文工作手冊

更新日期：2026-11-13。此手冊按[共同 Phase 與章節表](./論文_共同Phase排程與分工.md)分工；正文直接在共享 Overleaf 的 `sections/` 編輯，無本地 personA 工作區。A 只負責本手冊列出的段落、圖表與自己的引用，不安排檢查 B 的工作。V3 不進本文。

## P1：基準、實驗環境與單 block 指標

### 3.1 Common Baseline and Low-Power Datapath

**Overleaf 檔案：** `sections/03_01_baseline.tex`。

- 第一段：說明 1600-bit state、25 個 64-bit lanes、序列化 θ/ρ/π/χ/ι、round scheduler 與 state bank；每一組比較都沿用同一 C3 基底。
- 第二段：說明 C3 原有 per-lane gated clock／資料寫入控制與低功耗設計動機；確認實際採用的正式 RTL，不把開發過程中的 ICG 試驗當成本文設計。
- 第三段：指明 V0 無 FT，V1/V2 只改保護碼字及故障回應相關邏輯；若還有 RTL 差異，列入 R2，不將總成本差全歸於 ECC。
- **F2：共用 datapath 圖。** 畫 top I/O、padding/absorb、state bank、lane clock、round scheduler、output formatter；標 1600/64/1088/256-bit 寬度及有 clock gating 的位置。圖說明示它是 RTL 架構示意，不是合成 netlist。

### 4.1 Design Versions and Synthesis Conditions

**Overleaf 檔案：** `sections/04_01_versions.tex`。

- 第一段：精確定義 V0、V1、V2 的 top、00/01/02/03 入口與正式來源。V3 不列表。
- 第二段：列共同的 TSMC40、Design Compiler、10 ns、功耗報告來源；工具版本與 library 路徑只填正式保存且可核對的部分。
- 第三段：寫出 02 `OK` 的判定範圍與 03 的 `PASS_WITH_SDF_WARNING`，不稱 post-layout timing signoff。
- **R3：版本與設定表。** 欄位為版本、保護碼字、recovery、合成 top、period、製程、01/02/03 證據路徑；ArchHC 另在 2.3/R1，不混作本組 V1。

### 4.4 Single-Block Timing and P/T Definition

**Overleaf 檔案：** `sections/04_04_metrics.tex`。

- 第一段：固定 `rate_minus_1` 135-byte 正常訊息。其 1080 個**有效輸入 bits**加 padding 後只做一次 permutation；136-byte 訊息會再做一次，不是本指標的樣本。
- 第二段：單 block 時間由既有 `paper_cycle_monitor.sv` 的第一筆被接受輸入到第八個輸出字取樣，記 `N_single`。同時註明 PATTERN 的 `latency` 可能比 monitor 多一拍，**整篇只用 monitor 口徑**。
- 第三段：`throughput = 1080/(N_single × 10 ns)`；`estimated P/T = total_power_mw / throughput_gbps`（pJ/有效輸入 bit）。總功耗為整顆 SHA3 的 DC 估計，沒有 SAIF 或晶片實測。
- 第四段：引用 [三版主表](../工作站結果/單block正式週期/V012_single_block_10ns.csv) 及三個 `*_135byte_cycles.csv`。每版兩筆 135-byte 案例都為一次 permutation、258 cycles；說明它們與封存 10 ns 功耗數字的來源如何核對。正文和 R7 可直接填 **0.418604651 Gbps**；V0/V1/V2 的 P/T 分別填 **4.819889350／8.428835872／8.075392356 pJ/bit**。
- **F5：單 block 計時示意。** 畫輸入接受、padding、單次 Keccak、八個 32-bit 輸出、最後輸出取樣；在圖中分開 241-cycle core 觀察、整顆 `N_single` 與 PATTERN 額外一拍。
- **R5：指標定義表。** 欄位為名稱、來源欄位／檔案、公式、單位、起訖事件與限制。僅有一種正文 P/T；不要再把 240-cycle 或 4096-byte P/T 列作論文性能數字。

## P2：兩種 SECDED 的結構

### 3.2 Full-State SECDED (V1)

**Overleaf 檔案：** `sections/03_02_full_state.tex`。

- 第一段：把 25 lanes 打包為 1600 bits，說明 11 個 Hamming 檢查位與 1 個整體 parity bit，形成 (1612,1600) SECDED。
- 第二段：說明 syndrome＋整體 parity 的 OK／CORRECTED／UNCORR 判斷；一個碼字中單錯可直接修正，檢測到不可修正錯誤則保持寫回並進入 replay。
- 第三段：依正式 `keccak_lane_ecc.sv` 指明編碼、注入、解碼和寫回順序。存入 `ecc_q` 的校驗位目前**未被 decoder 讀回**，不能說本版已實證「儲存中的 state 暫存器位元翻轉」會被修正。
- **F3(a)：V1 路徑圖。** 畫 1600-bit pack、1612-bit codeword、注入點、decoder、single global status、寫回與 replay；清楚標 `ecc_q` 不是此 decoder 的輸入。

### 3.3 Lane-Level SECDED (V2)

**Overleaf 檔案：** `sections/03_03_lane.tex`。

- 第一段：25 個 64-bit lanes 分別有 7 個 Hamming 位與 1 個整體 parity 位，形成 25 個 (72,64) SECDED 碼字；總校驗位 200，不能聲稱 V2 的 parity bits 比 V1 少。
- 第二段：每 lane 單錯直接修正；同一 lane 的可檢出雙錯走 replay。兩個不同 lane 各一個單錯在原理上可各自修正；V1 會視為同一大碼字的兩錯。嚴格區分 RTL 原理與 PATTERN 實測案例。
- 第三段：列與 V1 共同的 top、replay 與 D checkpoint，說明 lane enable 與重編碼校驗位的作用；同樣限定為目前驗證的寫入路徑故障模型。
- **F3(b)：V2 路徑圖。** 和 F3(a) 用相同畫法、同一注入點，顯示 25 條 lane encoder/decoder、各 lane status、uncorr mask 和選擇性寫回。
- **R2：兩版結構對照表。** 列碼字數與長度、校驗位總數、判斷粒度、單錯、同 lane 雙錯、跨 lane 雙單錯、replay、實際已驗證邊界；數字與原理分欄。

## P3：固定 10 ns 結果

### 5.2 Area, Power, and Timing at 10 ns

**Overleaf 檔案：** `sections/05_02_area_power.tex`。

- 第一段：從正式 10 ns CSV 取 V0/V1/V2 `total_cell_area`、`total_power_mw`、`worst_slack_ns`；面積單位須核對 library 報告，不能自行補 `µm²`。
- 第二段：V1→V2 用 V1 作百分比分母；現有結果顯示合成面積約低 1.9%、總功耗約低 4.2%。另用 V0 說明兩版相對無保護基準的總增量。
- 第三段：V1/V2 的 10 ns slack CSV 均顯示 0.00；不由此推導 Fmax 或其他 period 的性能。
- **F7：面積與總功耗圖。** 分成兩面板，三根 bar 為 V0/V1/V2，附精確來源、10 ns、DC 估計與面積單位核對狀態；不畫 V3 或掃頻曲線。

### 5.3 Single-Block Throughput and P/T

**Overleaf 檔案：** `sections/05_03_energy.tex`。

- 第一段：報三版正式 `N_single=258`；兩個 135-byte 正常案例、三個版本都相同。只表明**本次無故障輸入**的週期一致，不推廣到故障重跑延遲。
- 第二段：按 4.4/R5 的 **1080-bit、單 block** 公式算三版 throughput 與 P/T，正文不使用舊 CSV 的 `energy_per_bit_pj` 或 4096-byte `full_sha3_estimated_p_over_t_pj_per_bit`。
- 第三段：解釋 P/T 是 DC 估計功耗除以 RTL 正常輸入吞吐，不是實測 energy，也不是故障發生時的能量。V2 相對 V1 的 10 ns P/T 低約 **4.19%**；三版 `N_single` 一樣，這個差幅來自估計總功耗。
- **F8：單 block P/T 比較圖。** 三版 V0/V1/V2，圖說列 135 bytes、各版 `N_single`、10 ns、功耗口徑及 pJ/有效輸入 bit。
- **R7：同條件主表。** 以 `V012_single_block_10ns.csv` 為來源，欄為 01、02、03 狀態、面積、總功耗、slack、`N_single`、單 block throughput 與 P/T；保留 03 的 SDF 警告註記。不要轉抄舊 CSV 的 240-cycle／4096-byte P/T。

### 5.4 Granularity Tradeoffs and Limitations

**Overleaf 檔案：** `sections/05_04_tradeoffs.tex`。

- 第一段：將碼字粒度、校驗位總數、合成面積與單 block P/T 並列；面積差不能直接解釋為 checker 單元差，因為沒有逐模組面積報告。
- 第二段：用 R2/R4/R6 交代單錯、雙錯、跨 lane 錯誤的不同反應，不把部分 PATTERN 通過說成任意 fault 100% coverage。
- 第三段：明列無已儲存 state 位翻轉驗證、無 mapped fault injection、無 post-layout、無 PVT 掃描及功耗活動波形。

## P4：結論與附錄

### 6.1 Conclusions

**Overleaf 檔案：** `sections/06_01_conclusions.tex`。回答 1.3 的粒度問題；量化結論只用已完成的 10 ns 與單 block 指標，不延伸到 ArchHC FPGA 數字。指出 V1/V2 成本差幅與證據邊界。

### 6.2 Future Work

**Overleaf 檔案：** `sections/06_02_future.tex`。可列 state 儲存錯誤的實際檢查路徑、mapped fault injection、活動波形功耗與跨 PVT／頻率測試；明寫這些尚未做，不把它們當既有貢獻。

### Appendix A: Versions, Sources, and Calculation Details

**Overleaf 檔案：** `sections/app_a_sources.tex`。放 V0/V1/V2 原始碼版本、正式 10 ns CSV、三份 `*_135byte_cycles.csv`、一份三版合併主表、公式與來源指紋核對說明；不納入 V3、netlist 或製程庫。寫作不需再安排重測指令。
