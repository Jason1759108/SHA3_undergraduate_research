# Person B 論文工作手冊

更新日期：2026-11-13。依[共同 Phase 與章節表](./論文_共同Phase排程與分工.md)分工。英文正文直接寫入共享 Overleaf 的指定 `sections/` 檔；本地沒有 personB 工作區。B 只負責自己的段落、圖表、摘要與引用，不安排驗收 A 的工作。本文只比較 V0/V1/V2。

## P1：動機、原理與相關研究

### 1.1 Research Background

**Overleaf 檔案：** `sections/01_01_background.tex`。

- 第一段：說明 SHA3-256 的安全用途及硬體單 bit 錯誤可能污染最終 digest；不要把硬體容錯描述成抵禦所有密碼攻擊。
- 第二段：說明成本受架構、序列化程度與保護粒度影響，因此要在同一個 C3 基底上比較。
- 第三段：引出 ASIC 成本、固定 10 ns 與可觀察的 01/02/03 證據；不先寫結果或誇大 fault coverage。

### 1.2 Motivation from ArchHC

**Overleaf 檔案：** `sections/01_02_motivation.tex`。

- 第一段：據 ArchHC 原文說明五個步驟之間各以 1600-bit Hamming 保護中間暫存器，單錯直接修正；ArchHC 不是 SECDED，也沒有本組 replay。ArchTMR_HC 是該論文另一個方案，不可混寫。
- 第二段：ArchHC FPGA 架構的 1611-bit 碼字與本組 V1 1612-bit SECDED、共用 C3 狀態 bank 的差異；其 LUT/FF/Mbps 不與本組 ASIC area/mW 直接排名。
- 第三段：說明本研究真正要回答的是「同樣 SECDED＋replay 條件下，全 state 與 lane 編碼粒度會怎樣影響本組硬體成本」。

### 1.3 Research Questions and Contributions

**Overleaf 檔案：** `sections/01_03_questions.tex`。

- 第一段：主問題為 V1 與 V2 在相同 top、製程、10 ns、正常單 block 輸入的面積、功耗與 P/T 差異。
- 第二段：功能問題為已設計 PATTERN 對單錯、可檢出的雙錯與跨 lane 案例的回應；說出注入點在編碼後、寫入前。
- 第三段：貢獻只寫有證據的 RTL 架構與固定條件比較；P4 依已回收的 `N_single=258` 與三版主表收斂文字。V3 不進貢獻。

### 2.1 SHA3-256 and the Serialized C3 Baseline

**Overleaf 檔案：** `sections/02_01_sha3.tex`。

- 第一段：依 FIPS 202 說明 1600-bit state、SHA3-256 的 1088-bit rate、512-bit capacity 與 24 rounds。
- 第二段：以本組 RTL 說明 25 個 64-bit lane、序列化 θ/ρ/π/χ/ι、吸收／padding／輸出；區分演算法結構與 C3 實作選擇。
- **F1：SHA3-256 與 C3 流程圖。** 畫 rate/capacity、message/padding、permutation、256-bit digest、共用 state bank；明示示意圖，不把一輪畫成一次完整 hash。

### 2.2 Hamming Codes, SECDED, and Replay

**Overleaf 檔案：** `sections/02_02_codes.tex`。

- 第一段：Hamming syndrome 定位單錯；額外整體 parity 使 SECDED 能區分單錯與可檢出的雙錯。定義 SEC、DED。
- 第二段：說明單碼字中雙錯只有**偵測**，不是 ECC 直接修正；本組由 replay 使用可信、未損壞的來源重新計算。可信來源及可重試條件寫清楚。
- 第三段：說明 1600-bit 一碼字與 64-bit 多碼字對「兩個不同 lane 各一錯」的不同分類。不要由碼理直接宣稱 RTL 已測遍所有組合。

### 2.3 Related Work and Comparison Scope

**Overleaf 檔案：** `sections/02_03_related.tex`。

- 第一段：整理 ArchHC／ArchTMR_HC 的方法、平台、受保護位置與限制，附原論文引用；可加與主題相關的 SHA3 fault-tolerant 研究，但每條結論查原文。
- 第二段：說明其他研究比較的 FPGA/ASIC、PPA、fault model 或訊息吞吐定義各異，為何本文把主要數值比較限定在 V1/V2 及 V0 基準。
- **R1：相關研究定位表。** 欄位為研究、平台、保護碼／粒度、保護位置、故障回應、本文能否做直接數值比較。ArchHC 欄明列 11 個 parity bits／1611-bit Hamming；本組 V1 的 12 bits／1612-bit SECDED 不能冒稱其重現。

## P2：故障邊界與驗證方法

### 3.4 Fault Response and Protection Boundaries

**Overleaf 檔案：** `sections/03_04_response.tex`。

- 第一段：描述 V1/V2 正常寫入、單 bit syndrome 修正、不可修正狀態觸發 replay；D checkpoint 與 state 碼字功能分開。
- 第二段：依實際 `keccak_lane_ecc.sv` 指出目前 decoder 的輸入由 `data_nxt` 新編碼並套用注入 mask，`ecc_q` 雖儲存但沒有進 decoder 比較；因此本文只論證 PATTERN 所代表的路徑，不能稱儲存暫存器翻轉已受完整保護。
- **F4：故障／replay 流程圖。** 畫 encode→injection→decode→OK/CORRECTED/UNCORR→write/hold/replay；將已驗證的注入點與未驗證的存放期間錯誤分別標示。

### 4.2 Fault Model and RTL Test Matrix

**Overleaf 檔案：** `sections/04_02_fault_model.tex`。

- 第一段：定義故障位置（編碼後 codeword 或 D 路徑）、單／雙 bit、lane 配置、注入時間與預期回應；分清資料位、檢查位、同碼字與跨 lane。
- 第二段：PATTERN 可證明特定測試案例而非普遍 fault coverage；沒有已保存的逐案 log 時不填每案例的額外 cycles 或成功率百分比。
- **R4：故障注入矩陣。** 欄位為 V1/V2、PATTERN/測項、位置、mask 類別、預期 status、預期 replay、可信來源與已保存證據層級。若單一案例未在最新版測過，不寫 PASS。

### 4.3 Functional Verification

**Overleaf 檔案：** `sections/04_03_rtl_verification.tex`。

- 第一段：說明 normal digest 向量、FT、cross-lane、Hamming 單元及 standalone core reference-vector suite 各測什麼。
- 第二段：引用正式 `rtl_latest.json` 的 suite-level PASS；若取得新的正式 01，更新來源 hash 與日期。
- 第三段：說明 135-byte 正常案例可供單 block `N_single`，但故障案例的 replay 拍數不使用它估算。

### 4.5 Gate-Level Verification and Evidence Limits

**Overleaf 檔案：** `sections/04_05_gate_verification.tex`。

- 第一段：說明 02 合成後的對應 netlist/SDF 送 03 進行正常功能 PATTERN；現存 CSV 三版為 `PASS_WITH_SDF_WARNING`，沒有記錄到 timing violation。
- 第二段：SDF 警告代表有 timing check 未完全匹配 cell model；不能稱所有 setup/hold 都做完或晶片 timing signoff。
- 第三段：03 沒有 mapped fault injection、實體佈局、SAIF 或 fault energy 實測；保護功能仍以 01 RTL 指定注入為證據。

## P3：功能結果與限制

### 5.1 Functional and Fault-Test Results

**Overleaf 檔案：** `sections/05_01_verification_results.tex`。

- 第一段：逐版列 V0 normal/core，V1/V2 normal/ft/cross-lane/Hamming/core 的保存 suite-level PASS；不填 V3。
- 第二段：依 PATTERN 的預期行為寫單錯直接修正、雙錯偵測及 replay、跨 lane 差異；分別標「原理」與「已測案例」，沒有逐案 log 時不補造週期數。
- 第三段：指出 03 只驗證正常 digest，不能由 03 PASS 推得 ECC 在 gate level 仍能處理指定故障。
- **F6：故障類別示意圖。** 同一 state 中畫 V1 一碼字與 V2 25 碼字，標示一錯、同 lane 雙錯、不同 lane 各一錯；不用未量測的故障恢復曲線。
- **R6：驗證狀態表。** V0/V1/V2 各列 01 suite、02 OK、03 `PASS_WITH_SDF_WARNING`、證據可支持與不能支持的範圍。

## P4：摘要、文獻與附錄

### Abstract and Keywords

**Overleaf 檔案：** `main.tex` 中的 abstract／keywords。正式單 block 結果已在 [三版主表](../工作站結果/單block正式週期/V012_single_block_10ns.csv)：三版皆 258 cycles，V1/V2 估計 P/T 為 8.428835872／8.075392356 pJ/bit。等 A 完成 5.3 的文字後，摘要一段交代問題、相同 C3 比較條件、V1/V2 結果與限制；不可把這些估計值稱為晶片實測。Keywords 以 SHA-3、SECDED、fault tolerance、hardware cost、replay 等實際內容選 4–5 個。

### Appendix B: RTL Test Inventory

**Overleaf 檔案：** `sections/app_b_tests.tex`。列 00 PATTERN 版本、測項、golden source、注入邊界、suite PASS 摘要、來源指紋和缺少逐案 log 的限制；不放製程庫、netlist、V3 或個資。

### Bibliography

共同 `references.bib` 已建立 ArchHC 與 FIPS 202 條目；B 補充實際引用的原始論文，逐條核對作者、標題、年份、DOI，未引用的條目不以 `\nocite` 強塞入 References。
