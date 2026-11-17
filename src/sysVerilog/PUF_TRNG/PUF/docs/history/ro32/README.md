# PYNQ-Z2 獨立 32 組 RO 診斷

此套件承接已驗證的 8 組 RO 診斷，擴充為 **32 組配對、64 個 RO**。每次只啟用一對。來源、Vivado 工程、部署檔與實板結果均在獨立目錄；不引用原 PUF／SHA3 專案。

這一階段量測比較位元與穩定性，尚未連接 Bitmap、ECC、helper 或 SHA3，也不輸出密碼學金鑰。

已完成 FPGA 建置與 43,264 筆實板量測：硬體功能 PASS；31／32 組在本批測試內穩定。Pair 10 有 31 次翻轉、44 次平手，完整結果保留在 [BOARD_RESULTS.md](BOARD_RESULTS.md)。最後所有 RO 已停用。實作簽核見 [BUILD_RESULTS.md](BUILD_RESULTS.md)。

## 使用入口

- `00_TESTBED/TESTBED.sv` 引用 `PATTERN.sv` 和人工 RO 波形模型；計數由實際 RTL prescaler／counter／Gray CDC 產生。涵蓋全部 32 組、配對越界、64-bit 啟用遮罩、停止 RO 0／63、AXI 握手與 abort／reset。
- `01_RTL/ro_diag_top.sv` 為 FPGA IP 頂層，64 個各自獨立的計數器，沒有 RO clock mux。
- `02_VIVADO/build.tcl` 建立新的 PYNQ-Z2 專案，綜合、佈局繞線、檢查後輸出 bit/hwh。使用 Vivado 2026.1。設定 `RO_DIAG_BUILD_ROOT` 可指定較短的建置路徑。
- `03_NOTEBOOK/RO32_Diagnostic.ipynb` 為實板操作入口，依序執行。`04_BOARD/` 會整理同一次建置的部署檔與雜湊。

## 實板測試參數

初次量測各組 32 次，共 1,024 筆，建立本版獨立比較參考；之後固定參考，再各組測 1,000 次，並重新載入同一 bitstream 10 回合、每回合各組 32 次。合計 **43,264 筆**，其中 42,240 筆為參考建立後的測試資料。

固定 warmup 1024 cycles、window 100000 cycles（100 MHz 下為 1 ms）。每次載入確認配置、序號歸零、FCLK0=100 MHz。每筆紀錄 count、delta、bit、狀態、序號、回合與單調遞增時間。例外時保存部分資料並嘗試停用 RO。

`functional_pass` 要求完整筆數、無量測故障／例外並成功停用 RO。`repeatability_pass` 另要求 32 組參考樣本完全一致，且後續測試無翻轉或平手。弱配對與失敗不會被刪除或重定義參考；每組的 flips/ties/faults 均保留。這些判定只描述本批短期資料。

## 電路與限制

每個 RO 為 5-LUT 環，先除以 8，再由 24-bit counter 計數；registered Gray code 經兩級同步到系統時脈。COUNT_A/B 為除頻後 ticks，MHz 換算為 `count * 8 * 100 / window_cycles`。比較位元為 A>B；平手或故障為 None。

配對選擇結果另經一級暫存，再進行差值與零值判斷，縮短擴充後的系統時脈路徑。量測起點與終點使用相同暫存延遲，因此 window 的間隔不變。原始 RO domain 使用高有效的兩級同步重設，直接驅動除頻器 CLR，避免在高速 recovery 路徑加入反相 LUT。三個除頻暫存器及各自的 next-state LUT 固定在同一個 Slice 的 B/C/D 位置；RO 第五個 LUT 使用同 Slice 的 A 位置。

64 個 RO 使用固定且不重疊的 LUT／除頻器位置；路由尚未固定，不能據此假定配對完全對稱。時序約束保留 500 MHz 原始 RO 上限假設、8 ns Gray 匯流排最大延遲與偏斜檢查；不使用全域關閉 CDC／DRC 的方式處理問題。實測頻率若達到 500 MHz 會立即停止並要求檢查硬體。

PL 重配置不等於整板斷電。尚須另外驗證溫度／電壓、斷電、跨板唯一性、位元偏差、相關性與熵，才能討論 PUF 金鑰品質。擴充到 320 組仍需重新評估資源、時序與實測，不能線性外推。

## 本機模擬

在 VCS 使用 `00_TESTBED/Makefile`；Verilator 可使用：

```text
python 00_TESTBED/run_sim.py --verilator <verilator_bin.exe> --zig <zig.exe> --build-dir <獨立短路徑> --vcd
python 00_TESTBED/test_driver.py
python 00_TESTBED/test_characterization.py
```

最後一項使用假的 PYNQ／MMIO 驗證測試流程與參考凍結規則，不是實體 RO 量測。暫存器介面見 `REGISTER_MAP.md`。
