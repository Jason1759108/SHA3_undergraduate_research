# 論文共同 Phase 排程與分工

更新日期：2026-10-27。論文全文英文；分工與工作站說明中文。資料準備全部由使用者完成，A/B 只分配寫作、圖表與自己內容修訂。

## 0. 英文論文版型與寫作規範（開始各 Phase 前先採用）

**論文全文使用英文；三份分工文件維持中文。** 本次選用「參照 LNCS 的單欄英文研究論文版型」，參考 `references/Pessl2013PushingTheLimits.pdf`，並核對 Springer 的作者排版說明。選擇原因是該文同屬序列化 SHA-3 硬體與成本研究，且其 1、1.1 層級與本組既有分工編號直接相容。

### 0.1 格式選擇可以調整，不是禁止 APA 或期刊格式

先前的中文工程論文版面已被本節取代。APA、LNCS、IEEE、ACM 或特定期刊格式都可以依實際用途選用；保留 n.n 分工編號不代表永遠不能換版型。若目標版型改用不同編號，保留工作對照表即可。版面、引文樣式與研究內容是可以分別調整的事項。

目前目標是接近公開英文研究論文的呈現方式，因此採用標題、作者與機構、Abstract、Keywords、連續正文、References、Appendices 的文章結構。不另做學位論文式封面、中文摘要、目錄或每章強制換頁。arXiv 的 PDF 指引著重可讀文字、字型與檔案完整性，沒有要求一律採 APA；Word 稿完成後可匯出符合其要求的 PDF。未來若選定期刊或研討會，再套用該出版單位當時的正式範本。

本 Word 是依參考論文與規範重建的可編輯骨架，**不是下載的官方 LNCS 範本，也不表示已投稿或已獲接受**。保留頁尾頁碼方便草稿溝通；Springer 正式製作時的頁碼與頁首規則另依投稿要求處理。

### 0.2 為什麼選這份參考論文

| 本地參考資料 | 觀察與用途 |
| --- | --- |
| `Pessl2013PushingTheLimits.pdf` | LNCS／CHES 論文；單欄、置中題目、1 與 1.1 編號；本次版型主要依據 |
| `An_SHA-3_Hardware_Architecture_against_Failures_Ba.pdf` | Sensors 的 ArchHC 相關論文；適合研究內容參考，但出版社側欄、刊名、出版資訊不適合直接搬到本組未投稿稿件 |
| `Lightweight_Unified_Sha-3Shake_Architecture_with_a.pdf` | 單欄英文預印本；可參考文章組織，但檔內仍有 DOI、會議名稱、CCS 等模板佔位，這些不照抄 |
| `NIST.FIPS.202.pdf`、`Keccak-implementation-3.2.pdf` | 標準與技術報告；保留作技術資料，不作文章版型主要依據 |

### 0.3 本次 Word 的樣式設定

| 項目 | 目前設定 |
| --- | --- |
| 頁面 | A4、單欄；文字區寬 12.2 cm、高 19.3 cm，居中配置；左右邊界 4.4 cm、上下 5.2 cm。此處是重建參考版面的設定 |
| 字體 | 全文 Times New Roman，黑色；數學式使用 Word 公式字型 |
| 論文題目 | 14 pt、粗體、置中；主題與比較範圍分兩段排，構成同一完整題目 |
| 作者／機構 | 作者 10 pt；機構與 email 9 pt；置中；姓名與資訊暫留英文佔位 |
| Abstract／Keywords | 9 pt；Abstract 與 Keywords 不編號；只留位置，尚未填研究內容 |
| 第一層標題 | 例如 1 Introduction；12 pt、粗體、靠左；不強制另起一頁 |
| 第二層標題 | 例如 1.1 Research Background；10 pt、粗體、靠左；沿用分工 n.n |
| 第三層 | 必要時使用 10 pt 粗體的行內標題，標題後接正文；依 LNCS 習慣不另編 1.1.1。目前未新增第三層內容 |
| 內文 | 10 pt、單行、左右對齊；一般段首縮排 0.35 cm；小節第一段與圖表後第一段不縮排 |
| 圖說／表題 | 9 pt；短標題置中，多行標題左右對齊；圖說在下、表題在上 |
| 頁碼 | 全文從 1 起算，頁尾置中；僅供草稿與預印本閱讀，投稿時可依範本移除 |

Word 的 Heading 1／Heading 2 可在導覽窗格中使用。小節編號目前是文字，若重排章節需同步調整；不因換成英文而更動 A／B 工作歸屬。正式稿移除所有英文佔位提示。

### 0.4 圖表、公式與引用

- 圖與表都要有名稱，內文先引用，再放圖表；例如 Fig. 5、Table 3。圖置中、圖說在下；表題在表格上方。短圖說與短表題均置中，多行則左右對齊。
- 全文圖連續編為 Fig. 1–10；表連續編為 Table 1–8，不再使用前版「圖 2-1／表 3-1」。F／R 仍是分工工作代號，完全保留。F3、F4 的 (a)、(b) 分圖仍由原負責人製作，另一小節引用即可。
- 圖說和表題的數字已設為 Word SEQ 欄位；新增圖表時用相同標號類型。Ctrl+A、F9 可更新數字；圖說文字及內文交互參照仍需隨內容維護。
- 圖內標示、座標、單位、圖例、表頭和註解都用英文。圖源保留可編輯版本；改編圖或外部資料要有來源。註解使用 Note:；圖字以最終尺寸可讀為準，建議至少 8–9 pt。
- 表格保留可編輯數字與欄位，量與單位寫清楚；不以圖片代替整張結果表。公式使用 Word 公式編輯器，重要公式連續編為 (1)、(2)，式置中、編號靠右。
- 目前採數字引用 [1]、[2]，依首次引用排序，同一來源重用同一號碼；這不代表套用了整套 IEEE 版面。若正式轉投 LNCS，依指定書目樣式與排序要求處理；若改 APA，則整體切換作者年份引用，避免一篇混用兩套。
- 不預填未完成的數據、摘要或參考文獻。骨架中的 figure/table to be inserted 只是工作提示，成稿時刪除。

### 0.5 工作代號與正式圖表號

| 工作代號 | 英文正式編號 | 所屬小節 |
| --- | --- | --- |
| F1 | Fig. 1 | 2.1 |
| F2 | Fig. 2 | 3.1 |
| F3 | Fig. 3 | 3.2；3.3 引用 (b) |
| F4 | Fig. 4 | 4.2；4.3 引用 (b) |
| F5 | Fig. 5 | 4.4 |
| F6 | Fig. 6 | 4.5 |
| F7 | Fig. 7 | 6.2 |
| F8 | Fig. 8 | 6.3 |
| F9 | Fig. 9 | 6.5 |
| F10 | Fig. 10 | 6.6 |
| R1 | Table 1 | 2.4 |
| R2a | Table 2 | 3.4 |
| R2b | Table 3 | 5.1 |
| R3 | Table 4 | 5.3 |
| R4 | Table 5 | 5.5 |
| R5 | Table 6 | 6.1 |
| R6 | Table 7 | 6.4 |
| R7 | Table 8 | 6.6 |

### 0.6 英文題目與中英章節對照

中文題意沿用原規劃；「整體 SECDED」譯為 Full-State SECDED，「奇偶預測局部重算」譯為 Parity Prediction with Local Replay。Theta／Chi／Iota 分別對應 θ／χ／ι。

**Fault-Tolerance Cost Tradeoffs in Serialized SHA3-256 Hardware — A Comparison of Full-State SECDED, Lane-Level SECDED, and Parity Prediction with Local Replay**

以下英文章節已寫入 [Word 骨架](./論文_寫作架構範本.docx)。個人手冊仍以中文說明，依相同 n.n 對應即可；各節編號及圖表對應保留；Phase 與實驗工作依本次分工更新。

| 編號 | 中文題意 | Word 英文標題 |
| --- | --- | --- |
| — | 摘要 | Abstract |
| 1 | 緒論 | Introduction |
| 1.1 | 研究背景 | Research Background |
| 1.2 | ArchHC 出發的研究動機 | Research Motivation Based on ArchHC |
| 1.3 | 粒度與策略研究問題 | Research Questions on Protection Granularity and Strategy |
| 1.4 | 已完成研究貢獻 | Research Contributions |
| 2 | 背景與相關研究 | Background and Related Work |
| 2.1 | SHA3-256／Keccak 結構 | SHA3-256 and the Keccak Structure |
| 2.2 | SECDED 與 parity 原理 | Principles of SECDED and Parity |
| 2.3 | Replay 與可信來源 | Replay and Trusted Sources |
| 2.4 | 相關研究與本研究定位 | Related Work and Positioning of This Study |
| 3 | 基準架構與 SECDED 保護方案 | Baseline Architecture and SECDED Protection Schemes |
| 3.1 | C3 基準架構 | C3 Baseline Architecture |
| 3.2 | 1600-bit SECDED | 1600-bit SECDED |
| 3.3 | Lane SECDED | Lane-Level SECDED |
| 3.4 | 共同與差異設計 | Shared Design Elements and Differences |
| 4 | 奇偶預測與局部重算架構 | Parity Prediction and Local Replay Architecture |
| 4.1 | 現行方案設計目標 | Design Objectives of the Current Scheme |
| 4.2 | θ parity 預測 | Theta Parity Prediction |
| 4.3 | χ／ι parity 預測 | Chi and Iota Parity Prediction |
| 4.4 | 原子提交與控制接線 | Atomic Commit and Control Interconnections |
| 4.5 | Replay 與恢復時序 | Replay and Recovery Timing |
| 4.6 | 保護範圍與設計限制 | Protection Scope and Design Limitations |
| 5 | 實驗方法與評估指標 | Experimental Methods and Evaluation Metrics |
| 5.1 | 版本與合成環境 | Design Versions and Synthesis Environment |
| 5.2 | 功能驗證方法 | Functional Verification Methods |
| 5.3 | 故障模型與注入方法 | Fault Models and Injection Methods |
| 5.4 | 合成有效性與保護保留 | Synthesis Validity and Protection Preservation |
| 5.5 | 評估指標與計算方式 | Evaluation Metrics and Calculation Methods |
| 6 | 實驗結果與討論 | Experimental Results and Discussion |
| 6.1 | 功能與故障結果 | Functional Verification and Fault-Injection Results |
| 6.2 | SECDED 粒度的 PPA 比較 | PPA Comparison of SECDED Protection Granularities |
| 6.3 | SECDED→parity 的策略成本 | Strategy Costs of Moving from SECDED to Parity |
| 6.4 | 最終方案對起始方案 | Comparison of the Final and Initial Schemes |
| 6.5 | 硬體成本與路徑來源 | Sources of Hardware Cost and Critical Paths |
| 6.6 | 恢復延遲、適用情境與限制 | Recovery Latency, Applicable Scenarios, and Limitations |
| 7 | 結論與未來工作 | Conclusions and Future Work |
| 7.1 | 結論 | Conclusions |
| 7.2 | 未來工作 | Future Work |
| — | 參考文獻 | References |
| A | 版本、合成、掃頻與成本來源 | Appendix A  Versions, Synthesis, Clock-Period Sweeps, and Cost Data Sources |
| B | 測試、故障案例與重現方法 | Appendix B  Tests, Fault Cases, and Reproduction Procedures |

來源：[本地主要版型參考](../參考資料/參考論文/Pessl2013PushingTheLimits.pdf)、[Springer 作者指引與 Word／LaTeX 範本](https://link.springer.com/series/558/information-for-authors-and-editors)、[Springer 作者排版規範](https://cms-resources.apps.public.k8s.springernature.io/springer-cms/rest/v1/content/27852130/data/Instructions%20for%20Authors%20PDF)、[arXiv PDF 提交說明](https://info.arxiv.org/help/submit_pdf.html)。

## 1 研究主軸與資料完成條件

V1→V2 回答 SECDED 保護粒度；V2→V3 回答包含 checkpoint、預測與 replay 的整體策略取捨；V1→V3 回答最終方案相對起始對照的成本。V0 是無保護基準。V1 是本組對照，不能稱 ArchHC 重現。四版資料從零完整重跑，不依賴歷史通過保證。

主結果採 full SHA3 的面積、vectorless 功耗、4096-byte 端到端吞吐及估計 energy/bit；附加 standalone core 的獨立合成成本及 rate-based 吞吐。保留 full-power/core-throughput 舊式比值作補充，不能當完整訊息實測能量。

資料準備只需依 [工作站操作與資料說明](./工作站操作與資料說明.md) 對每版執行一次 RTL 總流程、一次雙範圍掃頻。所有必要檢查通過後，以新 logs／CSV／netlist／reports 撰寫此範圍的論文。失敗則依明確 log 修復重跑；「跑過指令」不等於通過。沒有安排 SAIF、mapped fault injection 或永久故障實驗，也不作相應主張。

## 2 Phase 與並行方式

| Phase | A | B | 依賴 |
| --- | --- | --- | --- |
| P1 | 3.1、5.1、5.5；F2、R2b、R4 | 1.1、1.2、1.3、2.1、2.2、2.3、2.4；F1、R1 | 可與使用者跑資料並行；兩人可各自做完再往下 |
| P2 | 3.2、3.3、3.4、4.1、4.4；F3、F5、R2a | 4.2、4.3、4.5、4.6、5.2、5.3、5.4；F4、F6、R3 | 各自依 RTL 與本次方法寫作，不等待另一人 |
| P3 | 6.2、6.3、6.4、6.5；F7、F8、F9、R6 | 6.1、6.6；F10、R5、R7 | 等使用者交付全套有效結果後，各自完成 |
| P4 | 7.1、7.2、附錄 A；自己的數據敘述修訂 | 1.4、Abstract、附錄 B；按節號整併全文 | 使用同一批最終結果；整併需兩人交稿，非互相審查 |

P1–P3 不要求兩人同時開始或完成；A 先做完等待 B 交稿也可以。老師與 AI 負責審查，沒有 A 主／B 輔、相互校驗或互改圖表任務。詳細每一個 n.n 的段落內容與 F/R 要求分別寫在個人手冊。

## 3 儲存方式

| 資料 | 位置 |
| --- | --- |
| 四版可直接複製的 00/01/02 | `四版本程式/V*/` |
| 全部工作站回傳資料 | `工作站結果/V*/results/` 與 `rtl_latest.json` |
| 原論文、歷史參考、方法查核 | `參考資料/`；歷史數字不併入新主結果 |
| A 正文與圖表 | `personA工作空間/段落/`、`圖表/` |
| B 正文與圖表 | `personB工作空間/段落/`、`圖表/` |
| 說明與英文 Word 骨架 | `分工說明與模板/` |
| 合併稿 | `論文定稿/` |

不再建立 T01–T12、活動檔交換、單次 mapped 任務或分 Phase 的空白資料夾。完整原始輸出由執行腳本自動建立，作者不需再手填版本索引與 run manifest。
