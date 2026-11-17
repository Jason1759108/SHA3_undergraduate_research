# 驗證紀錄

驗證日期：2026-11-06。套件自包含，未寫入或引用原 SHA3／PUF 專案的來源檔案。

## 已執行

- Verilator 5.38 搭配本地 Zig 0.16.0：完整數位回歸 PASS，模擬至約 195 us。
- 各 RO 以模擬波形輸入，經實際 RTL prescaler、Counter、Gray CDC 與量測控制產生結果。8 組配對皆與依已知週期獨立計算的計數比較，允許 ±2 divided ticks 的邊界量化差。
- AXI AW 先到、W 先到、同時到達；WSTRB 部分寫入與零 strobe；B/R backpressure 保持；無效、唯讀及未對齊位址。
- 配對與 window/warmup 參數錯誤、最小合法值；RO 停止的 ZERO_COUNT 與後續恢復。
- 運行時修改 CFG 不影響本次量測；忙碌 START 被拒絕；完成旗標 sticky、清除與結果保持。
- 中止量測、量測途中外部 reset，以及後續重新量測。
- 硬體頂層的語法／階層 lint 通過。僅此檢查使用 LUT 宣告替身，明確接受已知 feedback 的 UNOPTFLAT 警告，沒有執行零延遲 LUT 環。
- Python driver 5 個 mock-MMIO 測試通過：換算單位、舊 DONE／sequence wrap、輸入驗證與 busy、timeout abort、錯誤 overlay ID。
- Notebook JSON 可讀、所有 Python cell 語法通過；Tcl 腳本由 Tcl interpreter 確認語法區塊完整。

回歸 log 與波形放在 `sample_results/`，波形由人工 RO 模型產生，非實體板子量測。`sample_results/driver_tests.log` 為軟體 mock 測試紀錄。

## Vivado 2026.1 實作已完成

- 器件 `xc7z020clg400-1`，有效 BASIC 授權，官方 TUL PYNQ-Z2 preset。
- IP 打包、Block Design、實際 UNISIM 綜合與佈局繞線完成。六個 RTL 原始檔與實際打包綜合來源逐 byte 相符。
- Setup WNS **0.053 ns**、Hold WHS **0.067 ns**、Pulse-width WPWS **0.500 ns**，失敗端點均為 0；沒有缺少時脈或未約束的內部端點。
- 16 組 Gray bus skew 上限均為 8 ns，最大實際偏斜 **2.015 ns**，最小餘裕 **5.985 ns**。沒有 NA 項目。約束以暫存器 cell 選取，避免 Q-pin path segmentation。
- CDC 為 32 項 CDC-9 Info（ASYNC_REG reset synchronizer），無 Critical 項目。
- DRC 無 Error；保留刻意 RO 回授、gated/fabric clock 等警告。Methodology 的 TIMING-2/4/14 各 16 項為內部 LUT RO 時脈的預期檢查結果，沒有以全域降級或關閉檢查處理。
- 同步重設釋放到 Counter 的 recovery/removal 路徑有納入 STA。AXI reset 的兩個低有效輸入均接 PS FCLK_RESET0_N，並於 BD propagation 後檢查極性。
- Bitstream generation 成功，最終部署檔已整理於 `04_BOARD/`，檔案雜湊在 `04_BOARD/MANIFEST.json`。報告見 `sample_results/vivado_2026_1/`。

本地工程：`C:/Users/a0981/Documents/Codex/rd/vivado_20261106_222902/project/ro_diag.xpr`。只有約束變更時可用 `02_VIVADO/resume.tcl` 接續；RTL 或 Block Design 改變時需完整重建。

## 實板階段

已取得使用者明確授權，於指定課程 Jupyter 伺服器上傳五個部署檔並執行 Notebook。實板為 PYNQ-Z2／PYNQ 2.5／Python 3.6.5，FCLK0 實讀 100 MHz。8 組各 32 次共 256 筆均 OK，無平手，各組在本批比較位元一致率 100%；另測第一組 0.1／1／10 ms window，計數約等比例增加。CSV 已下載並重新核對筆數、狀態、差值、頻率換算與一致率。Notebook 與板上 CSV／JSON 已保存，最後確認全部 RO 停用。

見 [BOARD_RESULTS.md](BOARD_RESULTS.md) 與 `sample_results/board_20100/`。實體頻率與本批短期重複性已有資料；重新上電、溫度／電壓、長時間與跨板唯一性仍未測試。

## 後續重複性與重配置

已再完成 8,000 筆初始量測及 10 回合 PL 重配置後的 2,560 筆量測，共 10,560 筆；每組 1,320 筆均重現前批參考位元，無故障／平手／翻轉。每次載入確認 sequence=0 與 FCLK0=100 MHz。完整 CSV 已本機重算核對，還原 CRLF 後 SHA256 與板上摘要相符。最後成功停用所有 RO。見 [RELIABILITY_RESULTS.md](RELIABILITY_RESULTS.md) 與 `sample_results/reliability_20100/`。未進行實際斷電與環境變化測試；沒有變更 RTL 或重建 bitstream。
