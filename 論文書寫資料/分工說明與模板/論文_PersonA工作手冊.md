# 論文 Person A 寫作分工

更新日期：2026-10-27。資料準備與全部工作站操作由使用者一人完成。你只負責下面指定英文段落、圖表及自己內容的修訂，不負責跑實驗、整理他人的工作或審查另一人的成果。

配套：[共同說明](./論文_共同Phase排程與分工.md)、[工作站完整流程](./工作站操作與資料說明.md)。本文 `PAPER/` 指「論文書寫資料」。正文放 `PAPER/personA工作空間/段落/section_n.n.docx` 或 `.md`；每節選一種格式。圖表來源／資料／輸出放同一個 `圖表/`，例如 `F2_source.svg`、`F2_data.csv`、`F2.png`。不再建立每項 T 任務的多層資料夾。

P1、P2 可在使用者跑資料時完成，兩人不需同步；P3 只等待使用者交付完整的工作站結果，不等待另一位作者；P4 填入最後結果及整併，沒有互相驗收工作。圖表工作代號 F/R 與正式 Fig./Table 的對應見共同說明。

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
- 第三段：說明報告命名、資料來源與量測條件；尚未取得的欄位先留明確待補。
- **要放 R2b：環境與約束表。** 一列一版本／設定，註明共同項及不可直接比較項；不要把未知欄填成預設值。

**本節圖表：R2b。** 圖源、資料與成品都放 `PAPER/personA工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

### 5.5 評估指標與計算方式

**產出位置：** `PAPER/personA工作空間/段落/section_5.5.docx`（或 `.md`）。

- 第一段：定義 library cell area（確認 library 單位後才標 µm²）、組合／循序面積、slack、掃描範圍內最短 VALID period。不得把離散掃頻點稱精確 Fmax。
- 第二段：full SHA3 使用 4096 bytes＝32768 有效訊息 bits；時間為第一筆輸入在 rising edge 被接受，到第八個輸出 word 被同步接收的 edge 間隔。主吞吐量為 `32768 / (C_e2e × T_ns)` Gbps。
- 第三段：standalone core 的 `C_core` 由 1600-bit reference-vector TB 量出 start_process 接受至 process_done 觀察的週期；附屬吞吐量為 `1088 / (C_core × T_ns)` Gbps。1600 是 state 寬度，不能當 SHA3-256 有效吸收 bits。240 運算拍與含交握的量測週期分開寫。
- 第四段：full 主能耗指標用 `P_full / TP_full`；core 指標用 `P_core / TP_core`，mW/Gbps＝pJ/bit。另保留 `P_full / TP_core` 作舊法對照，明稱 full-power core-normalized estimate。
- 第五段：三種都是 vectorless power-normalized estimates；輸入共用 0.1 toggles/cycle、static probability 0.5，reset/injection 另列。未使用活動波形，不能宣稱實際訊息能量或故障恢復能量。
- **要放 R4（Table 5）：指標／範圍／單位／公式／起訖事件表。** full 與 core 各列功耗來源、cycles 來源、分母；列出舊法僅供補充。

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

使用 `工作站結果/` 的新 logs、CSV 與原始 reports。資料尚未完成時先寫段落結構，不填預期數字。

### 6.2 SECDED 粒度的 PPA 比較

**產出位置：** `PAPER/personA工作空間/段落/section_6.2.docx`（或 `.md`）。

- 第一段：比較 V1/V2 同操作點的面積、功率、能量與時序。
- 第二段：呈現掃描範圍內的可達性，分開比較共同頻率與各自最佳點。
- 第三段：說明優勢是否隨操作點改變，保留 lane 不占優的數據。
- **要放 F7：面積—clock period 曲線。** 橫軸 ns、縱軸使用 library cell area 單位（確認後才標 µm²）；V1/V2 為重點，可加 V0/V3 參考；timing failed 明確標示，不能當有效點連線。圖說標版本、PVT、合成方式及資料來源。

- 不以 10 ns 的小幅面積改善描述成所有操作點「大幅降低」。

**本節圖表：F7。** 圖源、資料與成品都放 `PAPER/personA工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

### 6.3 從 SECDED 到 parity 的策略成本

**產出位置：** `PAPER/personA工作空間/段落/section_6.3.docx`（或 `.md`）。

- 第一段：比較 V2/V3 的成本與正常拍數。
- 第二段：指出 predictor、checker、checkpoint 等同時改變，改善不能全部歸於 parity 或 lane 粒度。
- 第三段：先列直接修正與 replay 的能力取捨，取得新結果後加入實際故障結果引用。
- **要放 F8：估計 energy/bit—period 圖。** (a) full SHA3 為主圖，(b) standalone core 為附圖；各用相同範圍的功耗／吞吐。圖說標 vectorless、訊息長度、週期量法與 PVT。不畫尚未量測的故障恢復能量。

- F8 由你完成；兩個分圖都使用使用者交付的 sweep.csv。

**本節圖表：F8。** 圖源、資料與成品都放 `PAPER/personA工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

### 6.4 最終方案對起始對照組

**產出位置：** `PAPER/personA工作空間/段落/section_6.4.docx`（或 `.md`）。

- 第一段：以 V1→V3 呈現整體方案結果。
- 第二段：列相對 V0 的成本，以及 V2 作為中間方案的位置。
- 第三段：說明這不是單變因實驗，保護範圍不同，不能稱完全等價替代。
- **要放 R6：共同有效頻率主表（優先 10 ns）。** 四版本列絕對值；改善欄各自標基準，百分比用相同定義；full/core 分成兩個 panel；所有版本須同 PVT、同 period 且 VALID，標明 vectorless 性質。

**本節圖表：R6。** 圖源、資料與成品都放 `PAPER/personA工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

### 6.5 硬體成本與關鍵路徑來源

**產出位置：** `PAPER/personA工作空間/段落/section_6.5.docx`（或 `.md`）。

- 第一段：用組合／循序及模組成本描述差異。
- 第二段：列代表 critical path 的起終點、主要運算與延遲，解釋是否支持碼寬假說。
- 第三段：說明共用／無法歸屬邏輯及合成最佳化影響。
- **要放 F9：面積組成與路徑圖。** F9(a) 用一致分類堆疊面積，總量與 report 對應；F9(b) 畫代表路徑並標原始報告位置。無法可靠拆分部分直接標示，不能硬湊。

- 原因分析以路徑證據為準，不只因 1600 大於 64 就斷言深度或延遲。

**本節圖表：F9。** 圖源、資料與成品都放 `PAPER/personA工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

## P4 結論與整併

使用 `工作站結果/` 的新 logs、CSV 與原始 reports。資料尚未完成時先寫段落結構，不填預期數字。

### 7.1 結論

**產出位置：** `PAPER/personA工作空間/段落/section_7.1.docx`（或 `.md`）。

- 第一段：依 V1/V2 結果回答粒度問題，指出操作條件。
- 第二段：依 V2/V3 結果回答策略問題，包含成本改善與能力代價。
- 第三段：依使用者提供的最終故障結果限定適用範圍，不新增未做實驗。
- 不新增圖；引用 R6、R5。若使用者的最終結果尚未到，先完成前兩段，其餘留來源待補。

### 7.2 未來工作

**產出位置：** `PAPER/personA工作空間/段落/section_7.2.docx`（或 `.md`）。

- 分段列 state 儲存保護、其他 parity 粒度、更多故障模型或實體驗證。
- 說明各方向要解決什麼限制，明確屬未完成工作。
- 不新增圖，不把沒有做 state parity 描述成現有結論已被證明。

### 附錄 A 與交付

**產出位置：** `PAPER/personA工作空間/段落/section_appendix_A.docx`（或 `.md`）。

- 放版本、full/core 邊界、完整掃頻、合成命令與設定、原始資料索引、可編輯 F2/F3/F5/F7/F8/F9、R2a/R2b/R4/R6。
- 各小節獨立檔案或明確標號，供全文整併；製程庫不納入公開附件。
- 老師／AI 對你負責部分的修訂由你處理，不檢查 B 的文章或圖表。
