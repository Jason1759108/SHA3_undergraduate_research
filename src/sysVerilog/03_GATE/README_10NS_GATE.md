# V3 的 03 gate 測試

`src/sysVerilog` 已同步 2026-11-04 完成四版驗證時的 V3 00/01/02 檔案。把這些檔案覆蓋到工作站原 `~/SHA3` 的對應資料夾後，先在 `00_TESTBED` 執行 `bash run_all_rtl.sh`，再在 `02_SYN` 執行 `bash run_sweep.sh 10 10 1 240`。腳本接受工作站專案名稱 `SHA3`，但此獨立資料夾名稱的相容修改尚未在工作站實測。

02 腳本沿用原 build 的 Makefile、`.synopsys_dc.setup` 和 `01_run_dc`，每次合成後在暫存 03 目錄以原 `make vcs_gate` 載入該次 netlist 與 SDF，跑 18 個正常 SHA3 訊息。`results/sweep/sweep_summary.csv` 記錄 02 數字、完整訊息 P/T、03 是否通過、timing violation 與 SDF 警告數。暫存 netlist、SDF、報告與 03 模擬檔在結果寫入 CSV 後清除。

舊的 `README_true_gate.md` 和 `_manual` 檔案是早期手動診斷流程，與此正式流程分開；它們未用於 2026-11-04 的四版 10 ns 結果。該次 V3 結果在 `論文書寫資料/工作站結果/2026-11-04_四版10ns/`，03 狀態為 `PASS_WITH_SDF_WARNING`，沒有記錄到 timing violation。
