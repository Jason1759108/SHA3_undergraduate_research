# PUF256 各板專屬 bitmap/helper：固定 1000 次重建

本套件獨立存放，使用既有的 FPGA bitstream 與各板原始註冊資料。沒有修改 SHA3 專案、PUF RTL、選樣門檻或配對。

## 測試定義

兩板分別使用自己的 bitmap、helper，初始載入一次原 bitstream，之後各執行 **1000 次重建嘗試**。所有硬體拒絕均計入，不自動重試；不重新註冊、不重新篩選、不在測試中途重載 FPGA。每個成功結果都與該板先前的硬體註冊結果比較。主機只負責控制、記錄及比對，量測、多數決和 ECC 均在 FPGA 執行。

- `20100` 原註冊資料：`results_20261112_181403`
- `20200` 原註冊資料：`results_20261112_235911`
- bitstream SHA256：`79346d7855c4a678563e8010083456b762b63bc8a8455388b2c45d4f12b7c7c2`
- 320 組候選、選 256 組，每組五次量測，最低 margin 8。
- FCLK0 100 MHz，window 100000 cycles，warmup 1024 cycles。

這兩份 bitmap 與先前的「共同 bitmap」不同。共同 bitmap 的 49 次拒絕結果仍保存在原雙板比較套件，不會被這次測試覆蓋。

本次測試限於實驗室當時環境。沒有斷電重開、受控溫度或電壓變化測試。重新下載 bitstream 也不等於斷電。

## 檔案

- `03_NOTEBOOK/rebuild_1000.py`：板端固定次數排程及逐筆記錄。
- `04_BOARD`：原 `.bit`、`.hwh`、MMIO driver。
- `04_BOARD/20100`、`04_BOARD/20200`：各板 Notebook、凍結註冊輸入、相同排程程式與檔案 hash。
- `provenance`：先前各板的原始 enrollment、selection、environment、111 次交易及摘要副本，作為本次輸入來源。
- `00_VERIFY/verify_1000.py`：獨立重算輸出 digest、helper syndrome，核對來源、固定輸入、交易順序、1000 筆次數、所有失敗與摘要。
- `00_VERIFY/test_verifier.py`：七項 synthetic 紀錄檢查測試；不是硬體量測。
- `sample_results`：板端匯出的 ZIP、逐筆 JSONL、完成 Notebook、截圖及主機核對結果。

## 板端執行

伺服器資料夾：`puf256_compare_a0981_20261113`。先確認原 bit/HWH/driver 在同一目錄，再上傳對應板子的三個檔案：`rebuild_1000.py`、`own_enrollment_<port>.json`、`PUF256_1000_<port>.ipynb`。開啟 Notebook 執行 Run All，會先驗證輸入與程式 hash，然後載入 FPGA 並測試。

一塊板同時間僅使用一個控制程式。再次執行會建立新的時間戳資料夾；板上日期可能與本地不同，保留原始資料夾名稱。

- [20100 Notebook](http://140.113.201.80:20100/notebooks/puf256_compare_a0981_20261113/PUF256_1000_20100.ipynb)
- [20200 Notebook](http://140.113.201.80:20200/notebooks/puf256_compare_a0981_20261113/PUF256_1000_20200.ipynb)

## 結果判讀

`completed=true` 表示固定排程完成；`passed=true` 另外要求 1000 次全部成功且身份碼一致，以及檔案與時鐘檢查通過。`records_verified=true` 只表示紀錄核對一致，不會把拒絕或身份碼改變當成成功。

每筆 `attempts.jsonl` 包含 attempt、硬體 sequence、command、status、成功時的完整身份碼及 SHA256、是否與註冊相同、修正 word 數、失敗 pair 診斷、耗時，以及 bitmap/helper 暫存器讀回值。失敗時 key 欄位為 null。診斷 pair 是該交易首先回報的失敗配對，不代表其他配對都已量測或通過。

離線驗證（將目錄替換為實際匯出的結果資料夾）：

```powershell
python 00_VERIFY/verify_1000.py sample_results/<port>/<result_directory> --save verification.json
python -m unittest discover -s 00_VERIFY -p test_verifier.py -v
```

測試結論必須閱讀 JSON 的 `passed` 與各項計數；驗證程式正常結束只代表紀錄核對完成。
