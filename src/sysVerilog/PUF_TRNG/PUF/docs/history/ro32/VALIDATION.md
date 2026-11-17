# 32 組獨立診斷檢查紀錄

## 數位回歸

最終 RTL 由 Verilator 5.38／Zig 編譯並執行，模擬至 509 us，完整回歸 PASS。所有 32 組的計數均與波形週期推算值比較（允許邊界量化差 ±2 除頻 ticks）。第 31 組使用 RO 62／63，另外停止第 63 號 RO 驗證 ZERO_COUNT，解除故障後能恢復。

同時涵蓋完整 64-bit enable 遮罩、僅啟用選定兩個 RO、AXI 獨立 AW／W、WSTRB、回應 backpressure、無效地址、參數上下限、運行中修改 CFG、忙碌 START、結果保持、abort、量測途中 reset 與後續恢復。`sample_results/ro_diag.vcd` 是人工 RO 波形驅動實際 RTL 計數器的結果，並非實板波形。

Python driver 的 5 個 mock-MMIO 測試通過，包含第 31 組、越界配對與拒絕誤用 8 組 overlay。實板量測流程另有 3 個假的 PYNQ／MMIO 測試：完整 43,264 筆流程與清理、參考凍結後的故意翻轉、部署檔雜湊改變時在配置 FPGA 前拒絕。

## 時序判定

`00_TESTBED/check_reports.py <reports目錄>` 以實際 routed 報告判定：setup／hold／pulse-width 無失敗端點、64 組 Gray bus skew 有數值且通過、無缺少 clock 或未約束內部端點、無 Critical CDC、無嚴重 DRC。檢查過的失敗版本也能被此工具拒絕，不能用數位模擬 PASS 取代 FPGA 時序簽核。

本次縮小後的失敗路徑及判定分別保存在 `sample_results/first_route_failure/`、`pipeline_route/`、`reset_route/`。前者有 74 個 setup／recovery 失敗端點；加入選擇暫存級後，100 MHz 系統運算路徑餘裕為 +1.339 ns，剩餘 36 個端點屬於 RO reset recovery；移除重設反相 LUT 後，只剩除頻器一條局部繞線路徑 −0.009 ns。後續將 next-state LUT 與除頻暫存器置於同一 Slice，保留原時脈與 CDC 限制再檢查。

最終實作與實板結果分別列於 `BUILD_RESULTS.md` 與 `BOARD_RESULTS.md`，失敗版本未作為部署檔。

最終局部放置版本已通過：WNS +0.543 ns、WHS +0.063 ns、WPWS +0.500 ns；64 組 Gray bus skew 均有數值且通過，最大 1.820 ns，最小餘裕 +6.180 ns。無失敗端點、Critical CDC 或嚴重 DRC。六份 RTL 與實際綜合來源逐 byte 相符，部署雜湊已保存。詳見 `BUILD_RESULTS.md`。

## 實板結果

已在指定 port 20100 的獨立目錄上傳五個部署檔並執行。共 43,264 筆完整量測、初始配置後再重載同一 bitstream 10 回合。功能判定 PASS；31 組在本批後續讀取中穩定，Pair 10 出現 31 次翻轉與 44 次平手，因此全 32 組的重複性判定 FAIL。沒有量測故障。原始 CSV 雜湊與板上紀錄相同，已由 `verify_board_results.py` 獨立重算並核對。最後停用所有 RO，Notebook 已保存。見 `BOARD_RESULTS.md`。
