# 論文 Person B 寫作分工

更新日期：2026-11-08。此為可選論文路線的固定 10 ns 版本。資料準備與工作站操作由使用者完成；你只負責指定英文段落、圖表及自己內容的修訂，不負責跑實驗或審查另一人的成果。

配套：[共同說明](./論文_共同Phase排程與分工.md)、[工作站完整流程](./工作站操作與資料說明.md)。本文 `PAPER/` 指「論文書寫資料」。正文放 `PAPER/personB工作空間/段落/section_n.n.docx` 或 `.md`；每節選一種格式。圖表來源／資料／輸出放同一個 `圖表/`，例如 `F2_source.svg`、`F2_data.csv`、`F2.png`。不再建立每項 T 任務的多層資料夾。

P1、P2 可各自開始，兩人不需同步；P3 使用已回收的四版 10 ns 結果，不等待掃頻；P4 依同一批結果整併，沒有互相驗收工作。圖表工作代號 F/R 與正式 Fig./Table 的對應見共同說明。

## P1 背景與方法初稿

依固定版本原始碼、參考論文與本次流程撰寫，可獨立往下做。

### 1.1 研究背景

**產出位置：** `PAPER/personB工作空間/段落/section_1.1.docx`（或 `.md`）。

- 第一段：介紹 SHA3-256 硬體的使用背景與結果正確性需求。
- 第二段：說明故障可能使 digest 錯誤，區分運算錯誤與演算法本身安全性。
- 第三段：說明容錯電路也消耗面積、能量與時序裕量，引出資源受限設計問題。
- 本節不新增圖；引用標準或原研究，不先報本組改善百分比。

### 1.2 從 ArchHC 出發的研究動機

**產出位置：** `PAPER/personB工作空間/段落/section_1.2.docx`（或 `.md`）。

- 第一段：說明 ArchHC 的整體 state Hamming 保護啟發了本專題。
- 第二段：說明本組每拍只處理部分 lanes，因此提出保護組織方式是否適配的疑問。
- 第三段：介紹 V1→V2→V3 的研究路線；V1 是自家序列化架構的對照，不是 ArchHC 重現。
- 本節不新增圖；不能把對方 FPGA LUT 與本組 ASIC 面積直接算勝負。

### 1.3 研究問題

**產出位置：** `PAPER/personB工作空間/段落/section_1.3.docx`（或 `.md`）。

- 第一段單獨提出主問題：同 SECDED＋replay 策略下，V1 整顆 state 與 V2 分 lane 的 10 ns 成本及已測故障行為有何差異。
- 第二段提出延伸問題：V3 改為 parity 偵測與 local replay 後，10 ns 成本及可偵測能力有何取捨；明言這不是等強度保護比較。
- 第三段界定固定 10 ns、指定暫態注入與可信來源；沒有掃頻，不宣稱最高頻率、所有故障或全系統防護。
- 本節不新增圖，不把預期 lane 勝出寫成前提。

### 2.1 SHA3-256 與 Keccak 結構

**產出位置：** `PAPER/personB工作空間/段落/section_2.1.docx`（或 `.md`）。

- 第一段：說明 rate/capacity、1600-bit state 與 24 rounds。
- 第二段：介紹 θ/ρ/π/χ/ι，只保留理解保護設計所需內容。
- 第三段：說明 lane、row、column 與序列化操作的關係。
- **要放 F1：Keccak 幾何圖。** 畫 5×5×64 結構，標 x/y/z、64-bit lane、五 lane row/column，保持與 RTL 索引一致。圖說解釋這些單位如何對應後面檢查／重算。

- 自行製作圖源，不直接複製論文圖片。

**本節圖表：F1。** 圖源、資料與成品都放 `PAPER/personB工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

### 2.2 SECDED 與 parity 原理

**產出位置：** `PAPER/personB工作空間/段落/section_2.2.docx`（或 `.md`）。

- 第一段：說明 Hamming syndrome 與 single-error correction。
- 第二段：說明額外 parity 與 double-error detection，推導 (72,64) 與 (1612,1600) 的校驗位元數。
- 第三段：說明單 parity 可偵測奇數翻轉、偶數可能抵銷；多個 lane 分開檢查與單個 signature 不同。
- 第四段：明確寫雙錯的恢復是 replay，不是 Hamming 直接修正。
- 本節不新增圖；架構編解碼圖由 A 在 3.2 放 F3。

### 2.3 Replay 與可信來源

**產出位置：** `PAPER/personB工作空間/段落/section_2.3.docx`（或 `.md`）。

- 第一段：區分 error detection、直接 correction、重算 recovery。
- 第二段：說明必須保留可信輸入／checkpoint，故障解除後重算才可能恢復。
- 第三段：說明持續被偵測的故障可能停滯，shared input 先壞則可能一致地算錯。
- 本節不新增圖；實際 replay 時序在你自己的 4.5 放 F6。

### 2.4 相關研究與定位

**產出位置：** `PAPER/personB工作空間/段落/section_2.4.docx`（或 `.md`）。

- 分別介紹 ArchHC/TMR、RERO、Luo 的 SHA-3 parity 偵錯，以及 Ewert 多維 parity。
- 每篇說明保護對象、偵測／修正／恢復能力與平台，不以不同製程、FPGA/ASIC 的數字直接排序。
- 最後一段指出本研究重點：共同序列化基準與固定 10 ns 條件下，V1／V2 的 SECDED 粒度比較為主，V3 為不同策略的延伸取捨。ArchHC 的 FPGA 數字只作背景，不與本研究 ASIC 數字直接排名。
- **要放 R1：文獻比較表。** 欄含來源、保護區域、方法、恢復能力、平台、可比較／不可比較項；引文連到原文。沒有取得全文的細節留待查證。

**本節圖表：R1。** 圖源、資料與成品都放 `PAPER/personB工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

## P2 架構與驗證方法

依固定版本原始碼、參考論文與本次流程撰寫，可獨立往下做。

### 4.2 θ 的獨立 parity 預測

**產出位置：** `PAPER/personB工作空間/段落/section_4.2.docx`（或 `.md`）。

- 第一段：定義 P(V) 與輸入 lane parity。
- 第二段：推導 C parity、D parity、θ 輸出 parity，說明旋轉不改變全 lane parity。
- 第三段：說明 col0 的 C 檢查與 checkpoint 接受；後續欄使用什麼保存資訊。
- **要放 F4：預測與主資料路徑來源圖。** F4(a) 為 θ，標 in_state、C/cP、D、predicted parity、actual parity，以及共享輸入邊界。

- F4 整張由你製作；χ/ι 分圖要求見下一節。圖中不能把「兩種 RTL expression」畫成已證明的物理故障獨立。

**本節圖表：F4(a)。** 圖源、資料與成品都放 `PAPER/personB工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

### 4.3 χ／ι 的獨立 parity 預測

**產出位置：** `PAPER/personB工作空間/段落/section_4.3.docx`（或 `.md`）。

- 第一段：從 χ 公式推導 parity，展示完整輸入 AND 乘積項。
- 第二段：解釋為什麼只有五個輸入 lane parity 不足以預測 χ。
- 第三段：說明 row0 的 RC parity 與 round index 共同錯誤限制。
- **使用 F4(b)：χ／ι 分圖。** 畫 row_in、主要 χ 運算、獨立預測乘積項與 RC 輸入；在本節引用該分圖，不再產生不同編號的重複圖。

- 對應單元測試說明公式如何驗證，但不將隨機 state 檢查稱為完整硬體 fault coverage。

**本節圖表：F4(b)。** 圖源、資料與成品都放 `PAPER/personB工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

### 4.5 Replay 與恢復時序

**產出位置：** `PAPER/personB工作空間/段落/section_4.5.docx`（或 `.md`）。

- 第一段：說明成功時提交並前進，失配時 hold 與保留資料。
- 第二段：說明下一拍 replay 仍重新檢查，重試失敗不可直接放行。
- 第三段：說明第一欄、第一列、最後操作、連續故障的邊界行為。
- **要放 F6：完整時序圖，由你直接完成。** 分圖呈現正常操作、SECDED 單錯直接修正、可偵測錯誤 replay、V3 連續故障。列 clk、round/index、active、fault、hold、replay、writeback、done，標每次實際提交。

- 根據 PATTERN、RTL 與 suite-level PASS 畫示意時序；圖說明稱 schematic timing diagram，不能當成已保存的逐案波形；把 240 核心拍與 TB 交握計數分開。圖說列版本、案例與故障位置，不需 A 再定稿。

**本節圖表：F6。** 圖源、資料與成品都放 `PAPER/personB工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

### 4.6 保護範圍與限制

**產出位置：** `PAPER/personB工作空間/段落/section_4.6.docx`（或 `.md`）。

- 第一段：列 V3 保護的運算輸出、C 檢查與重算前提。
- 第二段：列偶數翻轉、shared input、state/frozen/control/checker 等未涵蓋或可信部分。
- 第三段：區分持續被偵測故障停住與未偵測故障可能輸出錯誤。
- 本節不新增圖。不要寫「任何錯誤都 replay 修復」或等價於 SECDED。

### 5.2 功能驗證方法

**產出位置：** `PAPER/personB工作空間/段落/section_5.2.docx`（或 `.md`）。

- 第一段：一般訊息、padding 邊界、多區塊、golden digest 來源。
- 第二段：說明 reset、handshake、訊息接受與輸出完成的觀察事件。
- 第三段：依四份 `rtl_latest.json` 列各版 `normal`、`ft`、`cross_lane`、單元與 `core` suite 的 PASS 狀態；正常 TB、容錯 TB、單元與 standalone core RTL 向量測試目的分開。沒有保存逐案 log，不把 suite PASS 寫成逐案量測值。
- 本節不新增圖，案例盤點併入下一節 R3，不需等 A 的版本表。

### 5.3 故障模型與注入方法

**產出位置：** `PAPER/personB工作空間/段落/section_5.3.docx`（或 `.md`）。

- 第一段：定義位置、注入階段、bit 數、持續時間及可信來源。
- 第二段：說明 raw-data bit 與 codeword bit 的映射；相同數值 mask 不一定是相同故障。
- 第三段：定義成功恢復、漏偵測、錯誤 digest、有限時間內未完成等結果。
- **要放 R3：故障／案例矩陣。** 一列一類案例，欄含版本、注入位置、mask 意義、持續拍、PATTERN 中的預期與保存的 suite-level PASS 證據。案例數只有能從本次 PATTERN 明確計數時才列；標明跨 lane、完整核心與單元測試不同。

**本節圖表：R3。** 圖源、資料與成品都放 `PAPER/personB工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

### 5.4 合成與閘級驗證範圍

**產出位置：** `PAPER/personB工作空間/段落/section_5.4.docx`（或 `.md`）。

- 第一段：說明四版僅有整個 `sha3_ultra_low_power_top` 的 10 ns 合成成本；standalone core 只做 RTL 向量測試，沒有獨立 core 面積、功耗或負載比較。
- 第二段：依正式 `syn.tcl`、`run_sweep.sh` 與 10 ns CSV 說明相同的合成入口、製程設定及 `status=OK`；未保存的逐模組面積、check_design 報告或 netlist，不能稱已證明 mapped 保護電路完整保留。
- 第三段：03 以對應 netlist／SDF 跑正常功能 PATTERN；四版 CSV 都是 `PASS_WITH_SDF_WARNING`、`gate_03_timing_violation=NO`。寫出 SDF 有未匹配警告，這不是無警告 timing signoff；03 也沒有做合成後故障注入。
- 第四段：證據層級為 01 RTL 故障／功能測試、02 合成估計與 03 正常功能。未做 mapped fault injection、post-layout、SAIF 或實體晶片驗證，不把 RTL 故障通過擴稱為實體故障覆蓋。
- 不新增圖；環境引用 R2b，功能結果引用 R5。

## P3 結果段落與圖表

使用 `工作站結果/2026-11-04_四版10ns/` 的四份 `rtl_latest.json` 與四份 10 ns CSV。逐案 log 與原始合成報告未保存；不要由通過總結反推每案的延遲或 fault coverage 百分比。

### 6.1 功能與故障驗證結果

**產出位置：** `PAPER/personB工作空間/段落/section_6.1.docx`（或 `.md`）。

- 第一段：列四版 `rtl_latest.json` 的 `status=PASS` 與各測試 suite 名稱；正常功能、FT、cross-lane、單元與 core 逐類分開。
- 第二段：依 PATTERN／RTL 列單錯、雙錯、跨 lane 的預期機制及 suite-level PASS，區分直接修正與 replay；沒有逐案 log 時不填逐案觀測值。
- 第三段：列 V3 parity 的偶數位元可能漏偵測、可信來源限制與已設計的預期盲點案例；不把「測試通過」等同所有故障已恢復。
- **要放 R5：故障結果表。** 欄位含測試 suite、版本、PATTERN 中的故障類別與預期回應、保存的 PASS 證據、證據層級及已知限制。逐案 digest、額外拍與未完成狀態若無本輪 log 證據，填「本次精簡結果未保存」，不得補估。03 gate 只列正常功能通過，不能算進 RTL 故障覆蓋。

- 不用少量刻意案例直接聲稱普遍 100% 覆蓋率；要報比例就列明母體。

**本節圖表：R5。** 圖源、資料與成品都放 `PAPER/personB工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

### 6.6 恢復延遲、適用情境與限制

**產出位置：** `PAPER/personB工作空間/段落/section_6.6.docx`（或 `.md`）。

- 第一段：區分正常操作、單次故障及持續故障在 RTL 中的控制流程；現有精簡結果沒有逐案額外拍，不做數值延遲排名。
- 第二段：說明可信輸入保留、可接受重算的情境，以及直接修正仍有價值的情境。
- 第三段：列未涵蓋位置、可信來源、RTL／03 正常功能證據層級；10 ns 成本數值引用 A 的 R6，不另算故障能量。
- **要放 F10：恢復條件與延遲來源示意圖。** 以 normal／detect／hold／replay／commit 分支顯示單次與持續故障如何增加等待拍；圖中只標 RTL 可驗證的事件順序，不填未保存的逐案額外 cycles，也不畫連續故障數值曲線。圖說寫明是 schematic，不是本次逐案量測。

- **要放 R7：適用條件與限制表。** 列可信來源、可處理／不可保證的錯誤、恢復代價、使用條件。

- 能量討論引用 6.3/F8 的無故障 10 ns 估計 P/T，不把它解釋為故障恢復能量。

**本節圖表：F10、R7。** 圖源、資料與成品都放 `PAPER/personB工作空間/圖表/`，檔名前綴使用本節工作代號；在圖說／表註記錄來源 CSV 或 log 的相對路徑。

## P4 結論與整併

使用四版固定 10 ns 精簡結果；沒有掃頻、逐案 log 或 post-layout 報告。

### 1.4 研究貢獻

**產出位置：** `PAPER/personB工作空間/段落/section_1.4.docx`（或 `.md`）。

- 第一段：描述共同基準下兩種 SECDED 粒度比較。
- 第二段：描述現行代數預測、原子提交與局部 replay 的實作／驗證。
- 第三段：依固定 10 ns 數據寫明 V2 對 V1 的小幅成本下降，以及 V3 不同保護能力下的成本取捨；不能推論所有頻率或最大頻率。
- 不新增圖；四版 10 ns 結果已在資料夾，寫作前核對 CSV 與來源說明，不能把研究動機當成已完成貢獻。

### 摘要

**產出位置：** `PAPER/personB工作空間/段落/section_abstract.docx`（或 `.md`）。

- 依「問題→方法→結果→限制」寫成短而完整的摘要。
- 使用四版 10 ns 數字，區分 DC 估算與 RTL 週期記錄、240-cycle 舊口徑與 7668-cycle 端到端訊息；明示 03 有 SDF 警告。
- 不新增圖，不加入正文沒有證據的普遍領先或首次提出主張。

### 附錄 B 與全文整併

**產出位置：** `PAPER/personB工作空間/段落/section_appendix_B.docx`（或 `.md`）。

- 交付 PATTERN 中可確認的案例類別、位置映射、golden／seed 定義、suite-level PASS 與 10 ns CSV 來源、重現步驟及 F1/F4/F6/F10、R1/R3/R5/R7 圖表來源。未保存的逐案 log 不寫成已附原始證據。
- 依小節編號將兩人已交文字拼接，將圖表置於指定段落；只做檔案／排版整併，不審查或重寫 A 的內容。
- 老師／AI 負責文稿與圖表的審查；你處理自己負責部分收到的修訂。
