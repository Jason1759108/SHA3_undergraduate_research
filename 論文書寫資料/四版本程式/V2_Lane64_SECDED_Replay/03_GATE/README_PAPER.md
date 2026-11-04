# 03 gate 驗證

正式流程由 `02_SYN/run_sweep.sh` 在每個週期合成完成後建立暫時的 `03_GATE`，沿用工作站 build 的 `make vcs_gate`，載入對應的 netlist 與 SDF。PATTERN 檢查 18 個正常 SHA3 訊息；故障注入由 01 RTL 的 FT、cross-lane 與單元測試檢查。

03 的功能結果、timing violation 與 SDF 警告數寫入 `results/sweep/sweep_summary.csv`，暫存的 03 檔案在寫入後清除。2026-11-04 回收的 10 ns 結果為 `PASS_WITH_SDF_WARNING`，且沒有記錄到 timing violation；此結果仍有 SDF 警告，不能當作完整時序覆蓋證明。
