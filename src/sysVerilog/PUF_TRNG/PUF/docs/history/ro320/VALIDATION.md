# 本地驗證

2026-11-12，最終 16-bit 飽和計數器版本。

## RTL 數位回歸：PASS

Verilator 5.38，Windows / Zig C++，模擬至約 5 ms，wall time 278.450 秒。完整結果在 `sample_results/simulation.log`。

- AXI AW/W 可獨立抵達、WSTRB、response stall、無效位址。
- 全部 320 組計數與解析預期比較；640-bit enable mask 恰好啟用指定兩個 RO。
- pair/window/warmup 非法值與最小界限。
- 最後一組 pair 319、RO 639 停止振盪及恢復。
- 操作時鎖定 CFG、busy 時拒絕 START、結果保持及 sticky flag 清除。
- ABORT、量測中 reset、重新啟動。
- 16-bit 計數飽和時回報 COUNT_SATURATED，之後可正常量測。

`sample_results/ro_diag.vcd` 為同一次成功執行的 96 個訊號識別碼子集，146,439,343 bytes。只刪除波形訊號與無保留訊號變化的時間列，不修改保留訊號的時間或值；完整訊號可用 `--full-clock-trace` 重新產生。

| pattern.phase | 輸入操作 | 預期 |
|---|---|---|
| 0 | reset | RO 關閉、結果及序號清零 |
| 1 | 暫存器讀寫、分開送 AW/W、WSTRB、response stall、無效位址 | ID/配置正確，非法存取回 SLVERR |
| 2 | pair 0..319，window=1024、warmup=128 | 指定兩個 RO 啟用，計數符合模型，status=OK |
| 3 | 合法最小值及非法 pair/window/warmup | 合法完成；非法對應 BAD_PAIR/BAD_WINDOW/BAD_WARMUP |
| 4 | 停止指定 RO，再解除停止 | ZERO_COUNT；解除後回到 OK |
| 5 | busy 時改 CFG、再送 START、清 sticky | 當前參數不變、重複 START 被拒絕、結果保持 |
| 6 | ABORT、運行中 reset、重新量測 | RO 關閉；reset 清零；之後正常完成 |
| 7 | 1 GHz 故障模型、1 ms 視窗，再恢復模型 | COUNT_SATURATED；恢復後 OK |

## Python：14 項 PASS

`python -m unittest discover -s 00_TESTBED -p "test_*.py"`

- driver 6 項：輸入、busy、timeout、sequence wrap、硬體配置核對及飽和回應。
- screening 5 項：串流統計、分數排序、bitmap／位元順序、不穩定參考排除、候選不足、固定選擇不受 holdout 失敗改動。
- protocol 3 項：模擬 PYNQ 成功流程、驗證區注入翻轉、bitstream SHA256 不符拒絕。獨立 CSV 驗證器同時核對成功及失敗案例。

Python mock 測試不是 FPGA 量測證據。真正實作檢查與板端量測結果分別記錄在 BUILD_RESULTS.md、BOARD_RESULTS.md。

## Methodology 分析與保守性驗證

2026-11-13 完成全部 234 項規則。原生 57 項 Timing 合併呼叫 98 秒完成；完整記錄保留原始 warning 等級。

另以原設定與候選程序各提取 90,456 筆 max、80,216 筆 min 紀錄。max 比較欄位全部相同；min 只有 592 個 RO divider clock-as-data 端點增加 35 ps uncertainty，沒有任何最差端點 slack 變寬鬆。使用者 timing 命令與所有規則啟用值完全相同；候選 routed timing／CDC／640 組 bus-skew／DRC 再次通過。驗證器不把不存在的 datapath-only clock skew 或零 hold uncertainty 當成數字臆造，保留工具的空值語意。

保守性判定可獨立重跑：

```powershell
python 00_TESTBED/compare_methodology_timing.py --reference sample_results/vivado_2026_1/methodology_runtime/reference --candidate sample_results/vivado_2026_1/methodology_runtime/candidate
```

這些數據是靜態時序／工具流程證據；沒有修改或重新程式化已量測的 FPGA。

另外以同一份 DCP 的獨立副本實測建置腳本、自動偵測的 Vivado Python 3.13、兩個 native 子程序及收集流程，最終同樣為 234/234。Timing 呼叫該次為 72 秒，完整保守性比較結果重現。收集步驟支援在重新驗證既有原生結果後續跑；只有所有必要檔案保存成功才寫完成標記。

反向測試將真實 divider hold 紀錄的 slack 改成比原設定寬鬆 1 ps，驗證器明確拒絕。部分規則的小型電路結果也會被完成收集器拒絕，不能拿來替代正式全時脈分析。
