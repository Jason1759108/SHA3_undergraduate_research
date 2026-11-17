# PYNQ-Z2 獨立 RO 量測套件

這是獨立實驗，沒有引用或修改 SHA3／PUF 專案。目的為上板量測 RO，尚未產生 PUF 金鑰。第一版有 8 組配對、16 個 RO，每次只啟用一組。已在 Vivado 2026.1 完成綜合、佈局繞線及 bitstream 產生，並於 PYNQ-Z2 實板完成 256 筆量測；可直接上傳的五個檔案放在 `04_BOARD/`。完整結果見 [BOARD_RESULTS.md](BOARD_RESULTS.md)。

後續已完成 8 組各 1,000 次讀取，再重載相同 bitstream 10 回合、每回合各組 32 次，共 10,560 筆，未觀測到翻轉／平手／故障。這是短期與 PL 重配置測試，未包含整板斷電或溫度控制。結果與重跑方式見 [RELIABILITY_RESULTS.md](RELIABILITY_RESULTS.md) 與 `05_RELIABILITY/`。

## 你現在先做什麼

1. 開啟本地 Vivado 的新視窗，先不開原專案，在 Tcl Console 執行 `version -short`，記錄版本。
2. 本套件已附 AMD/Xilinx Board Store 的 PYNQ-Z2 board files，建置腳本會加入專案的搜尋路徑。來源 commit 與雜湊在 `02_VIVADO/board_files/SOURCE.json`，不需改動 Vivado 安裝目錄。使用免費 BASIC 授權時請選 **2026.1 主版本**，2026.1.1 更新版不支援 BASIC。
3. 將整份套件放在獨立且較短的本機路徑，例如 `C:/FPGA/ro_diag`，在 Vivado Tcl Console 執行：

   ```tcl
   source C:/FPGA/ro_diag/02_VIVADO/build.tcl
   ```

   也可在已設定 Vivado 環境的命令列執行：

   ```text
   vivado -mode batch -source 02_VIVADO/build.tcl
   ```

4. 成功後，將 `deploy/<日期時間>/ro_diag.bit`、同資料夾的 `ro_diag.hwh` 與 `03_NOTEBOOK` 裡的 `.ipynb`、`ro_diag.py` 上傳到板上 Jupyter 的同一個新資料夾。依課程的板子借用方式取得使用權限後才載入硬體。
5. 開啟 `RO_Diagnostic.ipynb` 依序執行。第一次先測一組，再測全部 8 組。量測 CSV 與摘要會存在 Notebook 所在資料夾的 `results/`。

`04_BOARD/ro_diag.bit` 與同名 HWH 是目前已檢查的部署組合。新建置會輸出到 `deploy/<日期時間>/`。若 Windows 路徑過長，可先設定環境變數 `RO_DIAG_BUILD_ROOT` 指向較短的獨立工作路徑；目前本機工程位於 `C:/Users/a0981/Documents/Codex/rd/vivado_20261106_222902/project/ro_diag.xpr`。若出錯，保留完整 Vivado log 與 reports，不要用全域關閉 DRC 的方式跳過。

## 檔案與訊號路徑

```text
03_NOTEBOOK/RO_Diagnostic.ipynb + ro_diag.py
    -> ARM/PYNQ MMIO -> AXI4-Lite
01_RTL/ro_diag_top.sv
    -> ro_diag_axi.sv : 暫存器與 AXI 握手
    -> ro_measure.sv : 選配對、暖機、計時、取樣
    -> ro_edge_counter.sv : 每 RO 各自除頻、計數、Gray 編碼
    -> ro_bank.sv / ro_lut_cell.sv : LUT 實體 RO
```

- 配對 `p` 對應 RO `2*p` 與 `2*p+1`。其餘 RO 停止。
- 每個 RO 使用 5 個 LUT 形成環，第一個 LUT 為 enable gate。
- 每個 RO 的 3-bit prescaler 除以 8，再用 24-bit Counter 計數。沒有切換 Counter 時脈的多工器。
- Gray code 經兩級暫存器同步到 100 MHz 系統時脈。暖機完成後記錄起點，經指定 window 取終點，相減得到計數。
- **COUNT_A/B 是除以 8 後的計數**。頻率估計 `count * 8 * 100000000 / window_cycles`，單位 Hz。
- 預設暖機 1024 cycles = 10.24 us；window 100000 cycles = 1 ms。各頻率估計的計數解析度為 8 kHz，邊界同步會造成量化誤差。
- 只對目前這個固定 8-pair 配置提供建置約束。擴充數量、修改 prescaler 或 Counter 寬度時，必須一起修改約束與 driver，不能只改參數。

## 硬體驗證重點

第一個通過條件是全部被測 RO 能讀到非零、合理的計數，而且延長 window 時 count 約等比例增加。兩個 count 很接近是有效量測結果，代表這組未必適合產生穩定位元，不能直接宣稱壞掉。

RO 是非同步的實體振盪電路。時序約束目前以原始週期 >= 2 ns（最高 500 MHz）作設計假設；真實頻率並非由 RTL 的數字指定。若估計頻率接近或超出假設、setup/hold 不通過、CDC/DRC 報告異常，先調整 RO 結構與計數路徑後再評估資料。RO 停止時回傳 `ZERO_COUNT`；非常慢的 RO 也可能需要更長暖機或 window。

腳本只在已知 RO 的回授 net 設定 `ALLOW_COMBINATORIAL_LOOPS`，不降低整個設計的 DRC 等級。LUT 的 LOC/BEL/輸入腳固定配置；高速除頻器與重設釋放暫存器也固定在各自 RO 附近，並禁止額外的全域時脈緩衝。同步器由暫存器直接驅動重設，同步釋放到 Counter 的 recovery/removal 路徑保留時序檢查。路由尚未固定，因此不能以此保證配對對稱、跨 bitstream 一致，或 256-bit PUF 的可靠性與熵。

RO 是刻意設計的 LUT 回授與內部時脈，因此 methodology 報告仍會列出 TIMING-2/4/14 各 16 項 Critical Warning，以及振盪迴路相關警告。這些限定於 16 個 RO；不是一般同步邏輯的時序簽核。最終 STA 的 setup/hold/pulse-width 均通過，16 組 Gray bus skew 均有實際數值且通過，CDC 報告沒有 Critical 項目。TUL 板級 preset 的四個負 DQS-to-CLK 參數也會在建立 PS 時觸發 PSU 警告，本套件保留原廠值，不產生 PS 開機映像或重新初始化 DDR。

每次比較板子、重開機或重複量測時，使用相同 `.bit`、相同實體板子標籤與相同量測參數。更換 bitstream／佈局後要重新量測。Notebook 測得的 bit 與一致率只是初步診斷，不包含 ECC、註冊 helper、SHA3 或硬體身分認證。

## 本地模擬

在 `00_TESTBED` 以 VCS 執行 `make vcs`，或使用 Verilator：

```text
python3 run_sim.py --vcd
```

Windows 可明確提供工具：

```text
python run_sim.py --verilator C:/tools/verilator/bin/verilator_bin.exe --zig C:/tools/zig/zig.exe --build-dir C:/temp/ro_diag_sim --vcd
```

TESTBED 連接 AXI IP、PATTERN 與虛擬 RO 波形。**沒有直接輸入 count**，所有計數皆由 RTL 計數器產生。硬體 LUT 環不在 RTL 模擬 manifest 內，`lut_lint_stubs.sv` 僅供硬體頂層語法檢查，不可放進 Vivado 工程或用於行為測試。

波形 `ro_diag.vcd` 建議看 `pattern.phase`、AXI valid/ready、`ro_enable`、`dut.u_measure.state`、`dut.u_measure.status`、`elapsed`、`count_a/b`、`done_sticky`、`sequence_number`。state/status 為 enum；AXI 傳回數值狀態，由 Python 顯示文字。詳細暫存器見 `REGISTER_MAP.md`，已完成檢查見 `VALIDATION.md`。

## 官方參考

- [PYNQ-Z2 硬體](https://www.amd.com/en/corporate/university-program/aup-boards/pynq-z2.html)
- [PYNQ MMIO](https://pynq.readthedocs.io/en/v3.1/pynq_libraries/mmio.html)
- [載入 Overlay](https://pynq.readthedocs.io/en/v3.1/pynq_overlays/loading_an_overlay.html)
- [AMD LUT2 primitive 與 INIT 定義](https://docs.amd.com/r/en-US/ug953-vivado-7series-libraries/LUT2)
- [AMD ASYNC_REG](https://docs.amd.com/r/2023.1-English/ug901-vivado-synthesis/ASYNC_REG)
