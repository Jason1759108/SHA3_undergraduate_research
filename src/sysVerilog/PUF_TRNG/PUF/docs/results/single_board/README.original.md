# PYNQ-Z2 獨立 PUF256 套件

本套件把 RO、計數器、PUF 核心、SECDED helper/ECC 與 AXI4-Lite 接到同一個 FPGA 設計。沒有連接原 SHA3 專案，也沒有身分認證運算。

本次模擬與實板驗證已完成，數據與範圍見 [RESULTS.md](RESULTS.md)：288組符合篩選條件、選用256組，111次重建（含10次相同bitstream重載）全部相同。

## 固定架構

```text
Jupyter / PS7 ── AXI 暫存器 ── puf_device ── puf_core
                                  │             │ req/ready/count/valid/status
                             puf_sketch      ro_measure
                                               │
                                      640 個 RO + 各自 counter
```

- 640 個實體 RO，組成 320 組互不共用 RO 的候選配對；bitmap 長度 320，必須選中恰好 256 組。
- 每次只啟用一組的兩個 RO；每個 RO 使用自己的 /8 分頻、16-bit 飽和計數器、registered Gray 與兩級 CDC。
- 依照 pair ID 小到大採樣。每組量測 5 次，以多數決輸出 1 bit；任一次 count 差小於 8 即拒絕該交易。
- 最終輸出 256-bit PUF 資料；每 16 bit 使用 5-bit extended Hamming syndrome，共 80-bit helper。
- bitmap 選中數量採多時脈累加檢查，避免 320-bit 組合 popcount 造成過長時序路徑。檢查期間 busy=1，尚未啟用 RO。
- 100 MHz 系統時脈；預設 warmup=1024 cycles、window=100000 cycles。一次成功交易量測 256×5=1280 次，約 1.3 秒，加上控制開銷。

## 兩種 PUF command

|Command|輸入|成功輸出|
|---|---|---|
|0 Registration|bitmap|256-bit 註冊參考資料、80-bit helper|
|1 Certification|相同 bitmap、註冊 helper、helper_valid=1|256-bit 重建資料、修正的 16-bit 區塊數|

Registration 尚無先前參考值可供 ECC 修正，因此輸出經 5 次投票的參考資料並產生 helper。Certification 會以 helper 修正重新量測的資料；這個名稱在本套件代表「重建」，不代表通過金鑰認證。

每筆交易都由外部傳入 bitmap/helper；內部只有易失暫存器。沒有 save_req/ack、持久化密鑰、版本/ID 驗證或舊系統的 command 2/3。AXI CTRL 的 START、CONSUME、ABORT 與 RAW_START 是介面控制動作，不是額外 PUF command。

## 目錄與檔案

|位置|用途|
|---|---|
|00_TESTBED/TESTBED.sv + PATTERN.sv|完整 AXI→RO 波形→真實計數器→PUF→ECC 模擬|
|00_TESTBED/ro_wave_model.sv|只模擬振盪波形與停振/加速/翻轉；不直接提供 count|
|00_TESTBED/TESTBED_PUF_COUNT.sv + PATTERN_PUF.sv|人工 count 後端，快速測核心、握手、超時與 ECC 限制|
|00_TESTBED/TESTBED_ECC.sv + PATTERN_ECC.sv|獨立 SECDED 測試|
|01_RTL/puf_types.sv|command、error、status enum 與波形用 ASCII 名稱|
|01_RTL/puf_core.sv|bitmap 掃描、重複採樣、margin 檢查、多數決、超時鎖定|
|01_RTL/puf_sketch.sv|產生 helper，解 syndrome 並修正資料|
|01_RTL/puf_device.sv|兩種交易、輸入鎖存、結果 valid/ready、錯誤輸出歸零|
|01_RTL/ro_lut_cell.sv + ro_bank.sv|640 個 LUT 實體環形振盪器|
|01_RTL/ro_edge_counter.sv|每個 RO 的分頻、reset 同步釋放、飽和計數與 Gray 輸出|
|01_RTL/ro_measure.sv|啟用配對、暖機、量測時間窗、CDC 與計數器讀取|
|01_RTL/puf_axi.sv|AXI 暫存器、PUF/診斷後端仲裁與共同 abort/reset|
|01_RTL/puf_fpga_top.sv|實體 RO bank 與 AXI PUF 連接|
|02_VIVADO|PYNQ-Z2 建置、布局/時序/CDC 約束及報告檢查|
|03_NOTEBOOK/puf256.py|PS 端 MMIO 驅動；不在 Python 計算 PUF/ECC|
|03_NOTEBOOK/puf_screening.py|以訓練資料篩選並凍結 256 組配對|
|03_NOTEBOOK/board_validation.py|實板篩選、註冊、重建、重載 bitstream 實驗|
|04_BOARD|通過 routed 檢查後才產生的上傳檔案與來源雜湊|
|sample_results|實際模擬、Vivado、實板證據；以各自結果檔判斷完成狀態|

## 模擬

在 Linux 工作站進入 `00_TESTBED`：

```sh
make vcs        # 完整整合；輸出 ro_diag.vcd
make vcs-core   # 人工 count 核心回歸
make vcs-ecc    # ECC
make host       # Python 驅動/篩選規則測試
```

也可由套件根目錄執行 `python 00_TESTBED/run_sim.py --mode wave --vcd`，以及 `--mode core`、`--mode ecc`。需安裝 Verilator/C++；Windows 可用 `--verilator PATH --zig PATH` 指定現成工具。完整波形測試較慢，結束後自動保留關鍵信號；已完成的波形會壓縮放在 sample_results/simulation。Verilator 以[官方 tracing 控制](https://verilator.org/guide/latest/control.html)排除重複原始時脈與未選中的底層計數器。詳細階段與看波形方式見 [PATTERN_GUIDE.md](PATTERN_GUIDE.md)。

## FPGA 建置與上板

Vivado Tcl：`source .../02_VIVADO/build.tcl`。Windows 建議先把環境變數 `RO_DIAG_BUILD_ROOT` 設為較短的本地路徑，以免 IP 路徑過長。目標是 `xc7z020clg400-1`，已附 PYNQ-Z2 board files；PS FCLK0=100 MHz、AXI base=0x43C00000、range=4 KiB。

建置不會把 methodology finding 改成 PASS。Windows Vivado 2026.1 的 methodology 流程另開唯讀程序，以 default STA 結果逐 endpoint 比對，確認分析替代設定沒有放寬時序後，才記錄 234 項檢查完成。此替代設定只用在 checkpoint 分析，不用於合成、布局或繞線。請保留已知 vendor finding 的嚴重程度，並審查任何新增 finding。

完成後執行：

```sh
python 02_VIVADO/prepare_deployment.py --build BUILD_FOLDER --deploy DEPLOY_FOLDER
```

它會檢查 routed timing/CDC/DRC/640 組 bus skew，並逐檔核對 Vivado 匯入的 RTL 與本套件相同。將 `04_BOARD` 中檔案放進獨立 Jupyter 資料夾，開啟 `PUF256_Validation.ipynb`。每次重新布局/繞線後必須重新篩選並註冊；只有相同 bitstream 才使用既有的 enrollment 記錄重建。

## 實驗範圍

每個 16-bit 區塊可修正 1-bit 錯誤、偵測 2-bit 錯誤；3-bit 以上可能誤修正而被接受。錯誤 helper 或不同 bitmap 也不保證都能被拒絕。本核心沒有 MAC、簽章或參考雜湊，無法判斷重建結果是不是原註冊值。

256-bit 輸出是 PUF 資料，尚未證明具有 256-bit 熵或均勻性；公開 helper 也會洩漏部分資訊。板端測試只驗證單板、固定 bitstream、當時環境的重現性，沒有驗證跨晶片唯一性、完整溫壓範圍或認證安全性。未來 SHA3 可接在 `puf_device` 的 `result_valid/result_ready/key_valid/key_data` 介面；本階段沒有 SHA3 實作。
