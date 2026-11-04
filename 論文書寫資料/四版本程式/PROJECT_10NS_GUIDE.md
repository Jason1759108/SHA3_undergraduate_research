# 四版本專題驗證包

此資料夾是四版的正式工作站 overlay。每版先用工作站的 `build` 建立 `00_TESTBED`、`01_RTL`、`02_SYN`、`03_GATE` 專案，再覆蓋本包同名檔案；工作站原有的製程設定與未包含在 overlay 的 build 檔案要保留。`SERIAL320_four_compact.zip` 只是相同內容的傳輸包。

2026-11-04 回收的四版工作站結果放在 `../工作站結果/2026-11-04_四版10ns/`。四版 `rtl_latest.json` 都是 `PASS`；10 ns CSV 的 02 `status` 都是 `OK`，03 `gate_03_status` 都是 `PASS_WITH_SDF_WARNING`，`gate_03_pass=YES`，`gate_03_timing_violation=NO`。這些是 10 ns 結果，尚未進行密集掃頻。SDF 警告數可在各版 CSV 查到；`PASS_WITH_SDF_WARNING` 不是無警告。

## 工作站上重新驗證

在 `~/SHA3_undergraduate_research/project_run` 中建立四個空專案，各執行一次 `build <版本名稱>`。把 ZIP 解開後，依序執行：

```bash
cp -a SERIAL320/V0_C3_NoFT/. V0_C3_NoFT/
cp -a SERIAL320/V1_State1600_SECDED_Replay/. V1_State1600_SECDED_Replay/
cp -a SERIAL320/V2_Lane64_SECDED_Replay/. V2_Lane64_SECDED_Replay/
cp -a SERIAL320/V3_LaneParity_LocalReplay/. V3_LaneParity_LocalReplay/
cp SERIAL320/check_serial320_10ns.sh .
cp SERIAL320/collect_compact_results.py .
bash check_serial320_10ns.sh
```

`[ALL_FOUR_10NS_PASS]` 表示四版的 01、10 ns 02 及對應 03 都通過。每版保留 `rtl_latest.json` 和 `results/sweep/sweep_summary.csv`。CSV 前 11 欄沿用原 `sweep_dc.sh` 的 1088 bit／240 cycle 比較口徑；新增 4096 byte 訊息的實測週期、完整 SHA3 吞吐量和 P/T，以及 03 狀態。功耗是 DC 的估計值。

02/03 每次只使用一個 `_work` 暫存區，取得 CSV 後清除 netlist、SDF、報告及模擬檔；下次執行會覆寫同版 CSV。固定 `check_logs` 也會覆寫。四版結果可用 `python collect_compact_results.py <輸出.zip>` 打包成八個小檔案。請勿把工具產生的整個工作目錄加入版控。
