# PYNQ-Z2：320 組獨立 RO 配對診斷

這是獨立上板套件，不引用原 SHA3 或 PUF 系統。320 組候選配對共有 640 個 RO，每次只啟用指定的一對；目的為量測、篩選及驗證固定的 256 組原始比較結果。這個結果尚未經過 ECC、熵估計或 SHA3，不能直接宣稱是 256-bit 安全金鑰。

## 電路

- `01_RTL/ro_bank.sv`：640 個由 5 個 LUT 組成的 RO，配對 p 使用 RO 2p、2p+1。
- `ro_edge_counter.sv`：每個 RO 各自具有 /8 除頻、16-bit 飽和計數器與註冊 Gray 輸出。沒有選擇 RO 時脈的多工器。
- `ro_measure.sv`：每個 RO 各自經過兩級 Gray 同步，再以 10 個資料選擇 bank 與管線取出指定配對。完成 warmup 後記錄基準，固定視窗後取差值。
- `ro_diag_axi.sv`：AXI4-Lite 控制、鎖定量測參數、保存結果及 sticky 完成旗標。
- `ro_diag_top.sv`：連接 RO bank 與控制電路；`ro_lut_cell.sv` 定義單一 RO。

系統時脈 100 MHz；板測 window=100000 cycles（1 ms）、warmup=1024 cycles。頻率為 `count × 8 / 0.001` Hz。A>B 記為 1，A<B 記為 0，相等與硬體錯誤不產生有效位元。計數器飽和時停止計數並回報 `COUNT_SATURATED`，不允許回捲偽裝成低頻。完整介面見 REGISTER_MAP.md。

320 組的第一版 24-bit 計數器雖未超過總 LUT/FF 數量，仍因放置及控制集合分布無法容納，故此階段採用 16-bit 飽和計數器，將最大量測視窗限制為 1 ms。先前的 8/32 組套件保持原狀；失敗診斷保存在 `sample_results/first_placement_failure`。

## 模擬

`00_TESTBED/TESTBED.sv` 連接 DUT、虛擬 RO 波形模型及 `PATTERN.sv`。測試使用波形驅動真正的除頻與計數 RTL，不是直接塞入 count A/B。

```powershell
python 00_TESTBED/run_sim.py --verilator <Verilator路徑> --zig <Zig路徑> --vcd
python -m unittest discover -s 00_TESTBED -p "test_*.py"
```

數位回歸涵蓋全部 320 組、完整 640-bit enable mask、參數錯誤、AXI 行為、忙碌拒絕、停止振盪、abort、量測中 reset，以及飽和後恢復。模擬 RO 的頻率由模型指定，不能用來證明實體 RO 的唯一性與穩定性。飽和測試刻意使用超過實體設計時序假設的 1 GHz 模型以注入故障。

預設 VCD 是完整模擬結果的訊號子集，保留 AXI、phase、狀態、選定 RO A/B、bank 選擇、基準及輸出。以 `--full-clock-trace` 保留所有 RO/計數器細節，檔案可能數 GB。看波形時先看 `pattern.phase`、`dut.u_measure.state/status`、`result_pair`、`ro_enable`、`selected_ro_a/b`、`selected_a/b`、`baseline_a/b`、`count_a/b`、`done_sticky` 與 `sequence_number`。

## 建置及上板

Vivado 2026.1、PYNQ-Z2 `xc7z020clg400-1`。`02_VIVADO/build.tcl` 建立獨立 block design 與實作。實體 RO 刻意保留組合回授，約束只對指定回授與 RO 網路施加必要設定；不全域關閉 DRC 或跨時脈檢查。

Gray CDC 使用 `set_max_delay -datapath_only` 與 bus-skew 限制。不能為了縮短分析時間直接加入涵蓋相同路徑的 asynchronous clock groups，因為 clock groups 優先級較高，會覆蓋 max-delay 約束。參考 [AMD UG903](https://docs.amd.com/r/en-US/ug903-vivado-using-constraints/Recommended-Asynchronous-Clock-Groups-Constraints)。大量時脈的 methodology 分析可能是此套件建置中耗時最長的步驟。

只有 routed timing、640 組 Gray bus skew、CDC、DRC 檢查通過，且實際匯入的 RTL 與本套件逐位元組一致，才執行 `02_VIVADO/prepare_deployment.py` 產生 `04_BOARD`。MANIFEST.json 記錄檔案及來源 SHA256。正式建置結果另見 BUILD_RESULTS.md。

`build.tcl`／`resume.tcl` 先保存 `final_routed.dcp`、正式報告及 bitstream，再執行 `methodology_separate.tcl`。非 Timing 規則逐條執行；Windows Vivado 2026.1 的 Timing 階段使用隨附 Python 啟動獨立參考／候選程序，完整比較端點時序後才接受分析繞法。進度見 `reports/methodology_checks/progress.tsv` 與 `reports/methodology_runtime/*/state.json`，全部完成才寫 COMPLETE.txt。沒有關閉規則或更改 CDC 例外。

2026-11-13 已完成 **234/234** 規則，保留 LUT RO 的 TIMING-2/4/14 各 640 個 Critical Warning 與 TIMING-23 的 640 個 Warning。分析使用內部參數的範圍、17 萬筆時序紀錄的保守性驗證與其他三個 Warning，見 BUILD_RESULTS.md、METHODOLOGY_DIAGNOSIS.md；不是零警告 PASS。

單獨接續 methodology 時，設定 `RO_DIAG_EXISTING_BUILD` 為含 `final_routed.dcp` 的建置目錄，再以 Vivado batch 執行 `02_VIVADO/methodology_separate.tcl`。可用 `RO_DIAG_PYTHON` 指定 Python 3.11 以上；預設使用 Vivado 安裝目錄隨附的 Python，不需另裝套件。診斷用縮小時脈／jitter 實驗在 `00_TESTBED/methodology_diagnostics`，不屬於 FPGA 實作約束。

上傳 `04_BOARD` 的六個檔案至同一個 Jupyter 資料夾，開啟 RO320_Diagnostic.ipynb。主程式會替換該板目前的 PL 設計，整個量測期間僅允許一個程式控制此 IP。第一個程式 cell 執行量測，第二個只產生報告和 ZIP，不會再次量測。

## 固定篩選流程

1. 每組 32 次建立參考，10,240 筆。初始參考必須全部有效且一致。
2. 每組再讀取 1000 次，320,000 筆。候選必須無 fault、tie、flip。
3. 依最小 `abs(A-B)/(A+B)` 由大至小排序，再以最小絕對差與 pair ID 決定同分順序，選取前 256 組並凍結 bitmap。少於 256 組時明確回報不完整，不補入不合格配對。
4. 凍結後重新載入同一份 bitstream 10 回合，每回合每組讀 32 次，共 102,400 筆。全部 320 組仍會被量測，但只依事先凍結的 256 組判定選定結果是否通過，不用驗證資料重新挑選。
5. 共 432,640 筆。CSV 逐組寫入，記憶體只保留統計值。每回合留下 32 個原始 256-bit 比較向量，總計 320 個。

bitmap 是 320-bit，bit p 對應 pair p。比較向量按照選定 pair ID 遞增，第一組放 bit 0。資料保存 reference/selection SHA256、篩選時的 CSV prefix SHA256 與凍結時間。`00_TESTBED/verify_board_results.py` 使用獨立整數統計及分數排序重新讀取 CSV，核對篩選、bitmap、驗證結果與檔案雜湊。

這個流程可驗證同一板、同一 bitstream 在本次環境下的重複與重載穩定性。不同板間唯一性、完全斷電重開、溫度／電壓範圍、長期老化及密碼學安全性仍需各自的實驗。
