# 論文 Person A 寫作分工

更新日期：2026-11-08。此為可選論文路線的固定 10 ns 版本。資料準備與工作站操作由使用者完成；你只負責指定英文段落、圖表及自己內容的修訂，不負責跑實驗或審查另一人的成果。

配套：[共同說明](./論文_共同Phase排程與分工.md)、[工作站完整流程](./工作站操作與資料說明.md)。本文 `PAPER/` 指「論文書寫資料」。正文放 `PAPER/personA工作空間/段落/section_n.n.docx` 或 `.md`；每節選一種格式。圖表來源／資料／輸出放同一個 `圖表/`，例如 `F2_source.svg`、`F2_data.csv`、`F2.png`。不再建立每項 T 任務的多層資料夾。

P1、P2 可各自開始，兩人不需同步；P3 使用已回收的四版 10 ns 結果，不等待掃頻；P4 依同一批結果整併，沒有互相驗收工作。圖表工作代號 F/R 與正式 Fig./Table 的對應見共同說明。

## P1 背景與方法初稿

依固定版本原始碼、參考論文與本次流程撰寫，可獨立往下做。

### 3.1 C3 基準架構

**產出位置：** `PAPER/personA工作空間/段落/section_3.1.docx`（或 `.md`）。

- 第一段：介紹 SHA3-256 輸入、padding、absorb、state、round 與輸出。
- 第二段：說明每拍五個 lanes、θ 五拍與 χ 五拍、24 rounds；標明 240 是核心運算拍數。
- 第三段：說明 clock gating、資料保存與 I/O 握手；不把核心吞吐視為所有訊息的端到端吞吐。
- **要放 F2：共同核心與保護位置圖。** 畫 I/O→padding/absorb→state→θ→ρπ→χ/ι→output 的資料關係，另以四個分圖或色框標 V0/V1/V2/V3 的保護與 checkpoint 位置。標正常路徑、檢查路徑及控制方向。

- F2 由你獨立閱讀現有 RTL 完成，不依賴其他圖表完成。圖說列版本與省略的細節；保留可編輯圖源。

**本節圖表：F2。** 圖源、資料與成品都放 `PAPER/personA工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

### 5.1 版本與合成環境

**產出位置：** `PAPER/personA工作空間/段落/section_5.1.docx`（或 `.md`）。

- 第一段：列四個版本及來源，說明 V1 是本研究對照，不是 ArchHC 完整重現。
- 第二段：寫 library、PVT、工具、clock、I/O delay/load、uncertainty、compile 設定。
- 第三段：指明四版正式 overlay、工作站 `rtl_latest.json`、10 ns `sweep_summary.csv` 和來源核對檔。沒有保存的 library 版本細節、完整 log 或報告不得推定。
- **要放 R2b：環境與約束表。** 逐項列共用的 10 ns 週期、製程／工具、合成入口及有證據的設定；未知欄標「未保存／未確認」，不能填推測的預設值。

**本節圖表：R2b。** 圖源、資料與成品都放 `PAPER/personA工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

### 5.5 評估指標與計算方式

**產出位置：** `PAPER/personA工作空間/段落/section_5.5.docx`（或 `.md`）。

- 第一段：定義 CSV 的 `total_cell_area`、`total_power_mw`、`worst_slack_ns` 與 10 ns `status`。面積單位應核對原 library／報告後才標；沒有組合／循序分解或最短週期資料，不寫 Fmax。
- 第二段：full SHA3 使用 4096 bytes＝32768 有效訊息 bits；時間為第一筆輸入在 rising edge 被接受，到第八個輸出 word 被同步接收的 edge 間隔。主吞吐量為 `32768 / (C_e2e × T_ns)` Gbps。
- 第三段：`standalone_core_cycles=241` 是 RTL 單元測試的週期記錄；舊 `clock_cycles_per_block=240` 是公式假設。這次沒有獨立 core 合成，不能列 core 面積、core 功耗或 `P_core/T_core`。
- 第四段：主估計 P/T = `total_power_mw / full_sha3_throughput_gbps`；舊欄 `energy_per_bit_pj` = `total_power_mw / throughput_gbps`，其中 `throughput_gbps=1088/(240×10)`。兩者同用完整 SHA3 的 DC 功耗；後者是 core-normalized 口徑，不能稱為完整訊息實測能量。
- 第五段：功耗使用 DC 未回標訊號活動的估計值；沒有 SAIF、實測活動或故障恢復能量。四版同用 10 ns，不延伸至其他週期。
- **要放 R4（Table 5）：指標／來源／單位／公式／起訖事件表。** 分列 full SHA3 4096-byte 主指標、240-cycle 舊口徑、241-cycle RTL core 記錄及 03 狀態；明列沒有獨立 core PPA。

**本節圖表：R4。** 圖源、資料與成品都放 `PAPER/personA工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

## P2 架構與驗證方法

依固定版本原始碼、參考論文與本次流程撰寫，可獨立往下做。

### 3.2 1600-bit SECDED 對照架構

**產出位置：** `PAPER/personA工作空間/段落/section_3.2.docx`（或 `.md`）。

- 第一段：說明 25 lanes 如何打包為 1600 bits，形成 (1612,1600) codeword。
- 第二段：說明 syndrome、直接修正、global status、active lanes 寫回與雙錯 replay。
- 第三段：說明真正受保護的編解碼區間、保存資訊與恢復限制，區分設計意圖與實際實作。
- **要放 F3：兩種 SECDED 編解碼圖。** F3(a) 為 1600-bit，F3(b) 為 lane；畫出資料寬度、校驗位元、encoder/decoder、注入區間與寫回。D checkpoint 另用小框標出，不能暗示它與 state 保護相同。

- 圖說明示兩圖比較的是保護組織方式，不以校驗位元數直接推論 area。

**本節圖表：F3。** 圖源、資料與成品都放 `PAPER/personA工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

### 3.3 Lane-level SECDED 架構

**產出位置：** `PAPER/personA工作空間/段落/section_3.3.docx`（或 `.md`）。

- 第一段：說明 25 組 (72,64)、lane_active 與 inactive lane 的處理。
- 第二段：說明單錯直接修正、雙錯由外部 replay 恢復；DE 不等於 Hamming 修雙錯。
- 第三段：說明跨 lane 各單錯與單個大碼雙錯的能力不同。
- **本節引用 F3(b)**，不重畫同一張圖；逐項對照其編解碼與寫回路徑。

**本節圖表：F3(b)（引用）。** 圖源、資料與成品都放 `PAPER/personA工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

### 3.4 共同設計與差異

**產出位置：** `PAPER/personA工作空間/段落/section_3.4.docx`（或 `.md`）。

- 第一段：列共同核心、排程與操作粒度。
- 第二段：列 ECC 粒度、D/checkpoint、快照與恢復控制的異同。
- 第三段：交代比較能回答與不能回答的問題。
- **要放 R2a：版本與模組差異表。** 欄為 V0/V1/V2/V3，列為資料路徑、保護、快照、恢復、正常拍數；每格有來源或不適用說明。

**本節圖表：R2a。** 圖源、資料與成品都放 `PAPER/personA工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

### 4.1 現行方案的設計目標

**產出位置：** `PAPER/personA工作空間/段落/section_4.1.docx`（或 `.md`）。

- 第一段：由既有 SECDED 的硬體成本提出改善需求。
- 第二段：定義降低常駐保護成本、保持正常核心拍數、對可偵測暫態故障局部恢復三個目標。
- 第三段：說明以重算時間交換直接修正電路，但不保證所有錯誤可偵測。
- 本節不新增圖，不以待量測結果當作已達成目標。

### 4.4 原子提交與控制接線

**產出位置：** `PAPER/personA工作空間/段落/section_4.4.docx`（或 `.md`）。

- 第一段：說明任一 active lane mismatch 阻止整欄／列提交。
- 第二段：說明 C checkpoint、χ frozen_state、資料保留及 scheduler 的角色。
- 第三段：說明 hold 不應形成檢查資料組合回授；fault 不等於整個 clock network 關閉。
- **要放 F5：控制與資料接線圖。** 畫 predictor→checker→fault→hold/replay、data_nxt/data_cur→writeback，以及 checkpoint 接受條件。用不同線型區分資料與控制。

- 圖由你依 RTL 完成；具體波形由 B 在 4.5 的 F6 處理，你不負責修改 F6。

**本節圖表：F5。** 圖源、資料與成品都放 `PAPER/personA工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

## P3 結果段落與圖表

使用 `工作站結果/2026-11-04_四版10ns/` 的 `rtl_latest.json`、單點 CSV 與摘要。沒有逐點掃頻、原始 reports、netlist 或逐案 log；圖表只使用能追到來源的數字。

### 6.2 SECDED 粒度的 PPA 比較

**產出位置：** `PAPER/personA工作空間/段落/section_6.2.docx`（或 `.md`）。

- 第一段：比較 V1/V2 同操作點的面積、功率、能量與時序。
- 第二段：用同一 10 ns 的絕對差及百分比，精確報 V2 相對 V1 的面積與功率／P/T；目前面積約低 1.9%，完整 SHA3 估計 P/T 約低 4.2%。
- 第三段：兩版 CSV 的 `worst_slack_ns` 都顯示 0.00，解釋這是報表欄位，不能用來推算 Fmax、其他週期的優勢或足夠時序裕量。
- **要放 F7：V1／V2 固定 10 ns 的面積與功率比較圖。** 用兩個小面板或分開座標，畫絕對值與明示的百分比；座標不是 clock period。圖說註明製程、10 ns、full SHA3、DC 估計功耗、兩版對照來源與面積單位核對狀態。

- 不以這個單點的小幅改善描述成所有操作點「大幅降低」。

**本節圖表：F7。** 圖源、資料與成品都放 `PAPER/personA工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

### 6.3 從 SECDED 到 parity 的策略成本

**產出位置：** `PAPER/personA工作空間/段落/section_6.3.docx`（或 `.md`）。

- 第一段：比較 V2/V3 的成本與正常拍數。
- 第二段：指出 predictor、checker、checkpoint 等同時改變，改善不能全部歸於 parity 或 lane 粒度。
- 第三段：列直接修正與 replay 的能力取捨，引用現有 PATTERN 與 suite-level PASS；沒有保存的逐案故障數值不補寫。
- **要放 F8：四版固定 10 ns 的完整 SHA3 估計 P/T 比較圖。** 四根 bar 取自 `full_sha3_estimated_p_over_t_pj_per_bit`，以 V1／V2 為視覺重點，V0／V3 供策略脈絡；可在圖註列舊 240-cycle 欄，但不能混成同一測量口徑。圖說標 4096 bytes、7668 cycles、DC 估計功耗與 10 ns。不畫 core PPA 或未量測的故障恢復能量。

- F8 由你完成；數值使用四版各自的單點 `sweep_summary.csv`。

**本節圖表：F8。** 圖源、資料與成品都放 `PAPER/personA工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

### 6.4 最終方案對起始對照組

**產出位置：** `PAPER/personA工作空間/段落/section_6.4.docx`（或 `.md`）。

- 第一段：以 V1→V3 呈現整體方案結果。
- 第二段：列相對 V0 的成本，以及 V2 作為中間方案的位置。
- 第三段：說明這不是單變因實驗，保護範圍不同，不能稱完全等價替代。
- **要放 R6：四版共同 10 ns 主表。** 列 01、02、03 狀態、面積、總功耗、slack、7668-cycle full SHA3 吞吐與估計 P/T；可加 V2 對 V1、V3 對 V1 的改善欄，但每個百分比都標明基準。03 狀態原文保留 `PASS_WITH_SDF_WARNING`。不建立不存在的 core 合成 panel。

**本節圖表：R6。** 圖源、資料與成品都放 `PAPER/personA工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

### 6.5 保護能力與硬體成本解讀

**產出位置：** `PAPER/personA工作空間/段落/section_6.5.docx`（或 `.md`）。

- 第一段：將 F7／F8 的 10 ns 成本與 V1／V2／V3 的實際保護機制並列，區分編碼粒度差異與整體策略差異。
- 第二段：用 RTL／PATTERN 描述「單碼字單錯」、「跨 lane 各單錯」、「parity 偵測並 replay」等已測案例；不把不同測項加總為同一覆蓋率。
- 第三段：坦言沒有保留組合／循序面積分解、關鍵路徑與獨立 checker 成本，無法把總成本差直接歸因於某個模組；`slack=0.00` 不能證明關鍵路徑類型。
- **要放 F9：10 ns 成本與保護能力定位圖。** 橫軸使用四版相對 V0 的總面積（或絕對面積），各版本旁以文字列其保護／恢復類型與已測 fault 類別；縱軸只用類別，不用沒有定義母體的「fault coverage %」。圖說明示 V3 與 SECDED 不能作等強度比較。

**本節圖表：F9。** 圖源、資料與成品都放 `PAPER/personA工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

## P4 結論與整併

結論僅使用四版固定 10 ns 精簡結果及已驗證的 RTL 測項；沒有掃頻、post-layout 或原始模組成本分解。

### 7.1 結論

**產出位置：** `PAPER/personA工作空間/段落/section_7.1.docx`（或 `.md`）。

- 第一段：依 V1/V2 同 10 ns 結果回答粒度問題，寫出改善幅度小且侷限於本設定。
- 第二段：依 V2/V3 結果回答策略問題，包含成本改善與能力代價。
- 第三段：依 `rtl_latest.json` 中已通過的 suite 與 V3 的已知盲點限定適用範圍；不擴稱任意錯誤都可恢復。
- 不新增圖；引用 R6、R5，並註明 03 的 SDF 警告與未量測頻率。

### 7.2 未來工作

**產出位置：** `PAPER/personA工作空間/段落/section_7.2.docx`（或 `.md`）。

- 分段列 state 儲存保護、其他 parity 粒度、更多故障模型或實體驗證。
- 說明各方向要解決什麼限制，明確屬未完成工作。
- 不新增圖，不把沒有做 state parity 描述成現有結論已被證明。

### 附錄 A 與交付

**產出位置：** `PAPER/personA工作空間/段落/section_appendix_A.docx`（或 `.md`）。

- 放版本、固定 10 ns 的 full SHA3 合成入口、CSV 欄位、公式、精簡結果路徑與來源核對界線，以及可編輯 F2/F3/F5/F7/F8/F9、R2a/R2b/R4/R6。列出 standalone core 只做 RTL 向量測試，沒有 core PPA。
- 各小節獨立檔案或明確標號，供全文整併；製程庫不納入公開附件。
- 老師／AI 對你負責部分的修訂由你處理，不檢查 B 的文章或圖表。
