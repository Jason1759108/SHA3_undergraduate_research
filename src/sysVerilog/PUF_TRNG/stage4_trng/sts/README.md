# SHA3 輸出的 NIST SP 800-22 單條序列初測

2026-11-16 實板初測已完成：[完整報告](../captures/board_21600/sts_pilot_20261116/REVIEW.md)。3907 批摘要核對正確，15 類均適用，188 個子結果中 187 個達 P≥0.01；Non-overlapping Template 有 1 個 P=0.004706，原樣保留，不宣稱全部通過。

依本次收尾範圍，固定收集 **3907 個新的 FPGA SHA3 摘要，約 5 分鐘**，測試串接後的前 **1,000,000 bits**。沿用已驗收的 bitstream、健康監測與 SHA3 驅動；不用 Vivado、不改壓縮比例，也不擴增或重複既有輸出。

## 使用者只需做這些

1. 解壓上層 `delivery/trng_sts_pilot_addon.zip`，得到三個檔案：`TRNG_STS_Pilot.ipynb`、`trng_sts_collect.py`、`sts_addon_manifest.json`。
2. 確認登記使用板子，且上一份操作本已完成安全結束。把三檔上傳到**原本放著八個整合版發布檔的同一個 Jupyter 資料夾**。不要更換原本的 `.bit`、`.hwh`、`.py` 或 `release_manifest.json`。
3. 開啟 `TRNG_STS_Pilot.ipynb`，由上往下 Shift+Enter。第一格只檢查檔案；日期格填實際日期與板號；載入格設定同一份電路。
4. 最後的收集格先比對 34 個已知訊息，再收 3907 批，每 128 批更新進度。成功應顯示 `PASS_COLLECTION`、`completed_batches=3907`、`generated_bits=1000192`、`unused_tail_bits=192`。
5. 收集格會自動安全結束。確認 RO enable=0、DMA halted 兩個都是 True。若發生錯誤，保留完整輸出與失敗 ZIP，不自動重抽或再開另一份操作本。
6. Ctrl+S。回 Jupyter 檔案頁，進入 `sts_pilot_results`，一次勾一個本次 ZIP → Download。另以 File → Download as → Notebook (.ipynb) 下載已執行的操作本。
7. 回傳 ZIP 與 Notebook，就能在本機執行 STS。板子上不需要安裝 NIST 工具、編譯器或其他套件。

3907×256=1,000,192 bits。固定取前 1,000,000 bits 是預先指定的測試切分；多出的 192 bits 仍保存在 ZIP，沒有依測試結果挑資料。每批完整 1024-byte raw、32-byte 硬體摘要與健康狀態都保存，可以逐批重算比對。

## 目前工具準備與檢查

- 從 [NIST 官方下載頁](https://csrc.nist.gov/projects/random-bit-generation/documentation-and-software)取得 STS 2.1.2，下載 URL 與 ZIP SHA-256 在 `references/source.json`。
- C 原始碼未修改，以本機 MinGW GCC 建置。來源、模板、執行檔與編譯命令指紋保留在 `tools/build_provenance.json`。來源原有註記完整保留於 `references/upstream`。
- 使用官方附帶的 e 常數 1,000,000-bit 範例，比對 [SP 800-22 附錄 B-2](https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-22r1a.pdf)的 16 個參考數值，容差 0.000002，全部符合。
- ASCII 與實際將使用的 binary 輸入模式，全部子測試 P-values 相同，確認位元讀取順序一致。
- 全零的負向控制確實被 Frequency／Runs 判出低 P 值；不適用的 Random Excursions 兩類保留為 N/A。
- 操作本在模擬 Session 中完整跑完 3907 批；健康失敗、錯誤摘要、raw／輸出竄改均被拒絕。這是軟體驗證，不是本次真實資料的測試結果。

原始工具在正常完成時回傳碼為 **1**；包裝程式核對完成訊息、讀取位元數、15 類輸出與每類子結果數，不把 returncode=1 直接當錯誤，也不僅靠 returncode 判斷成功。

GCC 對原始 `genutils.c` 的內建產生器例程有潛在長度警告，原樣保留在 `tools/compile.log`。此流程使用 file-input，不使用這些內建產生器；檔案輸入計算另以官方範例與負向控制校對。

## 單條初測能與不能說什麼

會嘗試全部 15 類測試，使用官方預設參數及 alpha=0.01。部分測試有多個子結果，例如 Non-overlapping Template 有 148 個 P-values；不會只挑其中最好的一個。

Random Excursions 兩類另要求足夠的回零循環。即使長度達百萬 bits，某些序列仍可能不適用；此時記 **N/A**，不記通過或失敗，不為了得到 PASS 而更換資料。

只有一條序列，所以**不評估多條序列的通過比例或 P-value 均勻分布**。原始 `finalAnalysisReport.txt` 仍完整保存，但它的整體比例／均勻度欄位不能作為這次的總體通過判定；查看包裝後 `pilot_summary.json` 的逐項／逐子結果即可。

多個子測試中偶爾出現低 P 值可能是隨機波動；會保留結果說明，不能直接等同硬體故障，也不能刪除失敗後重測直到通過。SP 800-22 不會產生「7.x bits 熵」的分數，也不能單靠通過它證明密碼學不可預測性或取得 NIST 認證。

## 本機分析

回傳後使用 `review_sts_capture.py` 先核對 ZIP 的版本、3907 批 raw／硬體摘要／健康紀錄與固定切分，再呼叫 `run_sts.py` 跑原始工具。輸出目錄必須是新目錄，避免混用舊結果。

```powershell
python review_sts_capture.py '下載的ZIP路徑' '新的結果資料夾路徑'
```

工具用到這台工作站既有的 `C:/msys64/mingw64/bin` 動態函式庫；不是上傳到板子的檔案。較大的官方原始 ZIP、建置與校對暫存放在 Git 忽略範圍，保留必要來源、執行檔、版本與驗證結果。

本次真實輸出結果及原始工具輸出已保存在 `captures/board_21600/sts_pilot_20261116/`。這次選定的單條約五分鐘初測範圍已完成；沒有以重抽取得全 PASS，也未擴大成多序列或認證測試。
