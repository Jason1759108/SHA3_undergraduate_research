# 論文共同 Phase 排程與分工

更新日期：2026-11-13。老師確認以 **V1 全 state SECDED 與 V2 lane SECDED 的成本比較**為主軸，V0 是共同基準。V3 不列入論文正文、圖表或主結論。本文的撰稿資料只引用三版相關 RTL 與結果；資料夾中既存的其他專題紀錄不當作本篇證據。

## 0. 共用格式、資料口徑與協作方式

- 全文英文，使用 Overleaf 上的 `IEEEtran` conference 兩欄 LaTeX 版型。這是 IEEE 風格草稿，不表示已投 IEEE 會議。英文標題、摘要、Keywords、References 及附錄都在 [Overleaf 專案模板](../Overleaf_IEEE/)。
- Overleaf 是**唯一的寫作編輯位置**。不在 GitHub 建 A/B 各自的段落工作區；本地分工手冊保留中文。正文每個小節為獨立 `sections/NN_NN_*.tex`，A/B 各編自己的檔，`main.tex` 只維護章節順序、題目與作者。
- 圖與表由 LaTeX 自動編號；內文以 `\label{}`／`\ref{}` 引用。圖說放圖下、表題放表上。F/R 是工作代號，**不是** PDF 內顯示的編號。圖片成品放 Overleaf `figures/`，圖源與資料保存在本地 [工作站結果](../工作站結果/) 或參考資料；無須重複上傳大型 EDA 檔。
- 以 [Overleaf 建立與共編指南](./Overleaf建立與共編指南.md) 建專案並邀請另一位作者。免費方案目前允許專案擁有者邀請一位 collaborator；若權限因帳號方案不同而變動，以 Overleaf 畫面為準。

### 0.1 唯一的 P/T 指標

選固定的 **135-byte SHA3-256 訊息**作單一 block 實驗。135 bytes 是可在一個 136-byte rate block 中完成 padding 的最大有效 payload；136-byte 訊息在目前 PATTERN 中需要第二次 permutation。V0/V1/V2 各自從「輸入被接受」量到「完整 digest 最後一字被 monitor 取樣」；使用同一個 testbench monitor 事件定義。記週期為 `N_single`，clock period 為 10 ns，整顆 SHA3 的 DC 估計功耗為 `P_total`：

`T_single = (135 × 8) / (N_single × 10 ns)`；`P/T = P_total / T_single`，單位為 pJ/有效輸入 bit。

正式三版結果已回收：[單 block 主表](../工作站結果/單block正式週期/V012_single_block_10ns.csv) 與各版兩筆 135-byte 原始週期列。V0/V1/V2 都是 `N_single=258`、`permutations=1`，在 10 ns 下 `T_single=0.418604651 Gbps`。整顆 SHA3 估計 P/T 依序是 **4.819889350、8.428835872、8.075392356 pJ/有效輸入 bit**。V2 比 V1 低約 **4.19%**；三版週期相同，因此差幅來自 10 ns 估計總功耗。**所有論文 P/T、吞吐與能量圖只用這個單 block 口徑**；舊 240-cycle 與 4096-byte P/T 欄僅留在封存 CSV，不帶入正文。來源、公式與限制見 [工作站結果說明](../工作站結果/單block正式週期/README.md)。

### 0.2 證據邊界

- V0/V1/V2 的 10 ns 合成面積、總功耗、slack、01/02/03 狀態與單 block 週期已保存，可填寫主表 R7、F7/F8 與百分比結論；需保留估計功耗和 SDF 警告的文字限定。
- ArchHC 是研究動機，不是 V1 的 RTL 重現；ArchHC 用 1600-bit Hamming，而本組 V1 用 1600-bit SECDED 加 replay。FPGA 與 ASIC 數字不直接排名。
- 本組現有 FT PATTERN 注入的是編碼後、寫入 state 前的指定 codeword／D 路徑故障。V1/V2 的 ECC decoder 目前沒有讀取已儲存的 `ecc_q` 作比較；論文不能稱已驗證「state 暫存器儲存期間 bit 翻轉可被 ECC 修正」。03 gate 是正常功能測試且帶 SDF 警告，不是 mapped fault injection 或實體 signoff。
- 不宣稱最佳頻率、Fmax、fault coverage 百分比、post-layout power 或故障時實測能量。功耗是 DC 估計，沒有實際活動波形。

## 1. 文章題目與章節

**Protection Granularity and Hardware Cost of SECDED in a Serialized SHA3-256 Accelerator**

| 章節 | 英文標題 | 負責 |
| --- | --- | --- |
| 1.1 | Research Background | B |
| 1.2 | Motivation from ArchHC | B |
| 1.3 | Research Questions and Contributions | B |
| 2.1 | SHA3-256 and the Serialized C3 Baseline | B |
| 2.2 | Hamming Codes, SECDED, and Replay | B |
| 2.3 | Related Work and Comparison Scope | B |
| 3.1 | Common Baseline and Low-Power Datapath | A |
| 3.2 | Full-State SECDED (V1) | A |
| 3.3 | Lane-Level SECDED (V2) | A |
| 3.4 | Fault Response and Protection Boundaries | B |
| 4.1 | Design Versions and Synthesis Conditions | A |
| 4.2 | Fault Model and RTL Test Matrix | B |
| 4.3 | Functional Verification | B |
| 4.4 | Single-Block Timing and P/T Definition | A |
| 4.5 | Gate-Level Verification and Evidence Limits | B |
| 5.1 | Functional and Fault-Test Results | B |
| 5.2 | Area, Power, and Timing at 10 ns | A |
| 5.3 | Single-Block Throughput and P/T | A |
| 5.4 | Granularity Tradeoffs and Limitations | A |
| 6.1 | Conclusions | A |
| 6.2 | Future Work | A |
| Appendix A | Versions, Sources, and Calculation Details | A |
| Appendix B | RTL Test Inventory | B |

摘要與 Keywords 由 B 在 P4 依已完成結果撰寫；作者與機構由兩人直接填 `main.tex`。段落名稱可在投稿前依老師意見調整，但小節內容與負責人不因 LaTeX 自動編號而改變。

## 2. 圖表工作代號與放置位置

| 工作代號 | 小節 | 內容與證據 | 負責 |
| --- | --- | --- | --- |
| F1 | 2.1 | SHA3-256 rate/state 與序列化流程示意；由標準與 RTL 畫 | B |
| F2 | 3.1 | C3 共用 datapath、lane clock gating 與寫回路徑 | A |
| F3 | 3.2；3.3 引用 | V1 單一 (1612,1600) 與 V2 25 個 (72,64) 編碼器示意 | A |
| F4 | 3.4 | 單錯直接修正、不可修正錯誤 replay 的事件流程；標注注入邊界 | B |
| F5 | 4.4 | 135-byte 單 block 的起訖事件、padding、輸出八字與計時範圍 | A |
| F6 | 5.1 | V1/V2 故障類別與預期回應示意；不畫未保存的逐案波形 | B |
| F7 | 5.2 | V0/V1/V2 的 10 ns 面積與總功耗比較 | A |
| F8 | 5.3 | 用已核對的 258-cycle 單 block 結果畫吞吐與 P/T 比較 | A |
| R1 | 2.3 | ArchHC 與本組比較條件、不同平台及故障範圍 | B |
| R2 | 3.3 | V1/V2 碼字、校驗位元、修正與 replay 條件 | A |
| R3 | 4.1 | 版本、top、10 ns 設定及正式來源 | A |
| R4 | 4.2 | PATTERN 故障位置、bit 數、預期狀態與測試 suite | B |
| R5 | 4.4 | 面積、功耗、`N_single`、吞吐與 P/T 公式／單位 | A |
| R6 | 5.1 | 01 suite PASS、02 OK、03 帶警告通過與限制 | B |
| R7 | 5.3 | 從 `V012_single_block_10ns.csv` 填 V0/V1/V2 的同 10 ns 主結果 | A |

原 F9/F10、R8 及 V3 專屬圖表不進本文；不保留空佔位。每張圖與表在對應個人手冊的小節另有內容要求。

## 3. Phase 與並行分工

| Phase | A | B | 相依關係 |
| --- | --- | --- | --- |
| P1 | 3.1、4.1、4.4；F2/F5、R3/R5。引用已保存的 258-cycle 單 block 計算欄位 | 1.1–1.3、2.1–2.3；F1、R1。整理 ArchHC 與保護模型 | 可獨立開始，正式 `N_single` 已到齊 |
| P2 | 3.2–3.3；F3、R2 | 3.4、4.2–4.3、4.5；F4、R4 | 各編自己的 `.tex`；共同採用同一故障邊界定義 |
| P3 | 5.2–5.4；F7/F8、R7；直接使用已保存的三版主表與各版原始週期列 | 5.1；F6、R6；只用保存的 suite-level 證據 | 可並行；不安排互相驗收 |
| P4 | 6.1–6.2、Appendix A，整合自己的圖表引用 | Abstract、Keywords、Appendix B，整合自己的引用與文獻 | 兩人各自收尾，老師與 AI 做校對 |

原始 RTL、工作站結果與參考文獻仍留本地；Overleaf 專案只放稿件、圖片、表格與 bibliography。不要把製程庫、netlist、個人帳密或大型 sweep 目錄上傳 Overleaf。
