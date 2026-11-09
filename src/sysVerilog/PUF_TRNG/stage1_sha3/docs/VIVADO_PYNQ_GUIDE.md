# PYNQ-Z2 SHA-3 第一次上板操作

**2026-11-09 修正版。** 先前 aux reset 常數接錯的原因與舊檔雜湊保存在 [事故紀錄](INCIDENT_RESET_AUDIT.md)。目前上板請優先依照 [修正版逐步操作](FIXED_RELEASE_STEPS.md)，包含板子恢復、五檔上傳、離線檢查及每個 checkpoint。下方保留老師簡報對照與手動建置細節。

本教學對照老師的《2026_DCS_Lab10_FPGA》。使用同樣的 Vivado → 打包 IP → Zynq PS + DMA → bit/hwh → Jupyter 流程，設計名稱改為 SHA-3。以下所有路徑都位於 `D:/C++/SHA3_undergraduate_research/src/sysVerilog/PUF_TRNG/stage1_sha3`。

第一次操作建議先用已建立的專案，逐一查看 Block Design，再執行上板測試。後半部列出從空白專案手動重建的細節。

已附的修正版專案可依第 1–2 節查看。若只要上板，優先依修正版操作使用已完成發布的五個檔案；修改設計後才需要依完整檢查流程重新建置。第一次核心綜合與完整實作可能需要數十分鐘。

## 1. 開啟已準備好的專案

1. 在 Windows 開啟 **Vivado 2025.2**。
2. 若底部看不到 **Tcl Console**，從上方 **Window → Tcl Console** 開啟。
3. 在 Tcl Console 貼上以下一行並按 Enter。大括號完整保留。

   ```tcl
   source {D:/C++/SHA3_undergraduate_research/src/sysVerilog/PUF_TRNG/stage1_sha3/vivado/open_project.tcl}
   ```

4. 等待 Sources 掃描完成。此腳本先載入附帶的 PYNQ-Z2 board files，再開啟 `build/sha3_pynq/sha3_pynq.xpr` 和 `design_1`。
5. 若出現「專案不存在」，在尚未開啟專案的 Vivado session 執行以下命令。它會打包 IP、建立專案與所有接線。

   ```tcl
   source {D:/C++/SHA3_undergraduate_research/src/sysVerilog/PUF_TRNG/stage1_sha3/vivado/create_project.tcl}
   ```

6. 如果專案已開啟且要切換，先用 **File → Close Project**。若視窗要求儲存你自己的修改，依你的需要儲存後再切換。
7. 在 **Sources → Design Sources** 確認 top 是 `design_1_wrapper`。展開後可看到 `design_1`。雙擊 `design_1` 開啟 Diagram。

## 2. 檢查 Block Design

對照講義第 18–30 頁。

1. 圖中應有 `processing_system7_0`、`sha3`、`axi_control`、`axi_memory`、`rst_ps7_0_25M` 與兩個 constant。
2. 雙擊 `sha3` 或點階層左上角的展開符號，確認包含 `sha3_ip` 與 `sha3_dma`。
3. 確認兩條 Stream 接線。

   | 起點 | 終點 | 資料方向 |
   |---|---|---|
   | `sha3_dma/M_AXIS_MM2S` | `sha3_ip/S_AXIS` | DDR 中的訊息送進 SHA-3 |
   | `sha3_ip/M_AXIS` | `sha3_dma/S_AXIS_S2MM` | 狀態與 digest 寫回 DDR |

4. 雙擊 `processing_system7_0`，查看 **PS-PL Configuration**，確認 **M AXI GP0** 及 **S AXI HP0** 啟用。查看 **Clock Configuration → PL Fabric Clocks**，確認 **FCLK_CLK0 = 25 MHz**。按 Cancel 可關閉檢查視窗。
5. 雙擊 `sha3_dma`，確認 simple mode 與兩個通道，完整設定列於本文件第 8 節。此版本 Address Width 為 32，clock 為 25 MHz。
6. 在 Diagram 工具列選 **Regenerate Layout** 整理顯示。
7. 選 **Validate Design**，成功後按 **Ctrl+S**。
8. 如果 Messages 有 warning，打開對應文字閱讀。常見板卡 preset 訊息與本次實際觀察結果列於 [驗證紀錄](VALIDATION.md)。出現 `ERROR` 時，先處理該訊息再繼續。

## 3. 產生 bitstream 與匯出上板檔案

對照講義第 32–37 頁。可從 GUI 操作，也可使用下面已附檢查與匯出的腳本。

### 使用腳本

1. 在本專案已開啟時，於 Tcl Console 執行。

   ```tcl
   source {D:/C++/SHA3_undergraduate_research/src/sysVerilog/PUF_TRNG/stage1_sha3/vivado/build_bitstream.tcl}
   ```

2. 等待完成。腳本最多同時開兩個建置工作，會執行 synthesis、implementation、write_bitstream。
3. 完成後檢查 `build/reports/timing_summary.rpt`、`utilization.rpt`、`drc.rpt`。腳本檢查最差 setup 和 hold slack，負值時會停止匯出。
4. 成功訊息會指出 `build/overlay/`，其中包含下節的四個上板檔案。

### 使用 GUI

1. 在 Sources 對 `design_1_wrapper` 按右鍵 → **Set as Top**，確認 top 圖示。
2. Flow Navigator 左側選 **Generate Bitstream**。
3. 提示先執行 synthesis/implementation 時選 **Yes**。
4. **Number of jobs** 選 2。這是同時執行工作的數量，可依自己的 RAM 調整。
5. 等待右上角出現 **write_bitstream Complete**。第一次會先建置所有 IP，時間依電腦而異。
6. 成功視窗選 **Open Implemented Design**。
7. **Reports → Timing → Report Timing Summary**，確認設計 timing constraints met，查看 WNS 與 WHS。也查看 **Report Utilization** 和 **Report DRC**。
8. Timing 若未通過，保留報告供定位，優先檢查 SHA-3 的半週期路徑。
9. 先依 [修正版操作第 6 節](FIXED_RELEASE_STEPS.md) 跑完整 BD 模擬及 PYNQ 相容性檢查；通過後才可執行下列匯出命令。只有核心測試通過不足以發布。

   ```tcl
   source {D:/C++/SHA3_undergraduate_research/src/sysVerilog/PUF_TRNG/stage1_sha3/vivado/export_overlay.tcl}
   ```

10. 開啟 Windows 檔案總管，前往 `stage1_sha3/build/overlay/`，應看到以下五個檔案。

   | 檔名 | 用途 |
   |---|---|
   | `sha3_pynq.bit` | FPGA 配置 |
   | `sha3_pynq.hwh` | PS、clock、DMA 位址與 IP 中繼資料 |
   | `sha3_pynq.py` | Python 驅動與比對程式 |
   | `SHA3_Bringup.ipynb` | 可操作的驗證 notebook |
   | `release_manifest.json` | 硬體檔雜湊與完整系統測試紀錄 |

`bit` 與 `hwh` 必須來自同一次 build，且具有相同檔名前綴。PYNQ 會用 hwh 解析時脈和 IP。 [PYNQ overlay 說明](https://pynq.readthedocs.io/en/latest/overlay_design_methodology/overlay_design.html)

## 4. 登記板子並上傳

對照講義第 39–42 頁。

1. 先依實驗室現行規則登記 PYNQ-Z2 使用時段，記錄板號。講義提供的舊時段與登入資訊需以實驗室目前公告為準。
2. 確認連上實驗室允許使用的網路或 VPN。
3. 在瀏覽器開啟該板的 Jupyter 網址。講義第 40 頁採「伺服器位址加板號對應 port」的方式，依目前分配的資訊登入。
4. 在 Jupyter 檔案頁建立自己的資料夾，例如 `overlays_113511153_sha3`，進入該資料夾。
5. 按 **Upload**，選取 `build/overlay/` 裡的五個檔案，再確認上傳。
6. 確認五個檔案位在同一層，且 hwh 檔名是 `sha3_pynq.hwh`。
7. 雙擊 `SHA3_Bringup.ipynb` 開啟。

此流程使用板上既有的 PYNQ Python 環境。記錄 notebook 印出的 PYNQ 版本。遠端 overlay 由網路上傳後下載到 PL，Windows 端只需要完成 Vivado 建置。

## 5. 逐格執行 notebook 與故障處理

請依 [修正版逐步操作第 3–4 節](FIXED_RELEASE_STEPS.md) 執行。目前 notebook 已增加 kernel 單獨測試、版本列印、離線檢查、四個載入 checkpoint，再進行 abc 與 34 次比對。舊版直接下載 overlay 的 cell 順序已不適用。

DMA timeout 後，driver 會保留 buffers；`session.reset()` 先確認 DMA 已 Halted 才重載。stop timeout 或 MMIO 無回應時，交由管理員恢復板子，不能靠新 kernel 保證硬體已停止。

## 7. 本機重新跑模擬

在 Windows PowerShell 執行以下命令。可從開始功能表開啟 PowerShell，將整行路徑加上引號。

```powershell
Set-Location 'D:\C++\SHA3_undergraduate_research\src\sysVerilog\PUF_TRNG\stage1_sha3'
python verify_baseline.py
python sim/run_sim.py
python sim/run_sim.py --suite normal
python sim/run_sim.py --suite ft
```

若 Vivado 安裝在另一個位置，每次測試加上 `--vivado-bin '你的/Vivado/bin'`。預設是目前的 `D:/VIVADO/2025.2/Vivado/bin`。

預期 AXI 測試結尾為 `SUCCESS SHA3 AXI vectors, stalls, malformed packets and reset`，normal 為 18 cases，ft 為 153 parity/replay cases。完整日誌分別在 `build/simulation/`、`build/regression_normal/`、`build/regression_ft/`。原本的 cross-lane testbench 另附在 baseline 供追溯，其對 unpacked array 元素使用 force/release 的方式受 XSIM 限制，這份 runner 提供已驗證可執行的三組測試。

## 8. 從空白專案手動重建

這一節對照老師簡報，供你理解與重建每一個步驟。可用另一個 Vivado 視窗，在獨立的 `build/manual/` 目錄操作。

### 8.1 板卡與 RTL 專案，講義第 4–12 頁

1. 在 Tcl Console 執行下列命令，讓這個 Vivado session 找到已附的 board files。

   ```tcl
   set_param board.repoPaths {D:/C++/SHA3_undergraduate_research/src/sysVerilog/PUF_TRNG/stage1_sha3/third_party/board_files}
   ```

2. **File → Project → New** 或歡迎頁 **Create Project**。
3. Project name 填 `sha3_pack_manual`，Location 指向 `stage1_sha3/build/manual_ip/`。按 Next。
4. 選 **RTL Project**。按 Next，進入 **Add Sources**。
5. 加入 `rtl/core/` 的所有 `.sv` 及 `rtl/sha3_axis_top.sv`。File Type 確認為 SystemVerilog。
6. Compile Order 中確認 `sha3_pkg.sv` 在其他核心模組之前。也可讓 **Update Compile Order** 自動排序。
7. Default Part 切換 **Boards**，搜尋 `pynq`，選 `pynq-z2`。其晶片應為 `xc7z020clg400-1`。
8. Finish。Sources 裡對 `sha3_axis_top` 按右鍵 → **Set as Top**。

### 8.2 打包 IP，講義第 13–16 頁

1. **Tools → Create and Package New IP**。
2. Next → **Package your current project**。
3. IP 存放位置填 `stage1_sha3/build/ip_repo_manual/sha3_axis_top`，Next → Finish。
4. 在 **Package IP → Identification** 設 Vendor 為 `research.local`、Library 為 `user`、Name 為 `sha3_axis_top`、Version 為 `1.0`。
5. **Ports and Interfaces** 確認有 `S_AXIS`、`M_AXIS`、`axis_aclk`、`axis_aresetn`。若需要修正介面，對 port 或介面按右鍵選 Add/Edit Bus Interface，使用 AXI4-Stream 介面定義。

   | 介面 | 模式 | 映射的訊號 |
   |---|---|---|
   | `S_AXIS` | Slave | TDATA=s_axis_tdata、TKEEP=s_axis_tkeep、TVALID=s_axis_tvalid、TREADY=s_axis_tready、TLAST=s_axis_tlast |
   | `M_AXIS` | Master | TDATA=m_axis_tdata、TKEEP=m_axis_tkeep、TVALID=m_axis_tvalid、TREADY=m_axis_tready、TLAST=m_axis_tlast |
   | `axis_aclk` | Clock | 關聯 S_AXIS 與 M_AXIS，關聯 reset 為 axis_aresetn |
   | `axis_aresetn` | Reset | Active Low |

6. Review and Package → **Package IP**。關閉打包專案。

### 8.3 建立 overlay 專案與 PS，講義第 17–20 頁

1. 建立另一個 RTL Project，Name 填 `sha3_pynq`，Location 選 `stage1_sha3/build/manual/`，Board 同樣選 PYNQ-Z2。
2. **Settings → IP → Repository → ＋**，加入 `stage1_sha3/build/ip_repo_manual`，Apply → OK。
3. Flow Navigator → **Create Block Design**，名稱 `design_1`。
4. Diagram 按 **＋**，搜尋 **ZYNQ7 Processing System**，加入。
5. 點 **Run Block Automation**，勾選 **Apply Board Preset**，將 DDR、FIXED_IO 設為外部介面，按 OK。
6. 雙擊 PS → **PS-PL Configuration**，開啟 M_AXI_GP0 和 S_AXI_HP0。
7. **Clock Configuration → PL Fabric Clocks**，啟用 FCLK_CLK0，設 **25 MHz**。保留套用的 PYNQ-Z2 DDR/PS 板卡設定。按 OK。

### 8.4 加入 DMA 和 SHA-3，講義第 21–29 頁

1. Diagram 按 **＋** → **AXI Direct Memory Access**。
2. 雙擊 DMA，設定下表。

   | 設定 | 值 |
   |---|---|
   | Enable Scatter Gather Engine | 關閉 |
   | Enable Micro DMA | 關閉 |
   | Read Channel / MM2S | 啟用 |
   | Write Channel / S2MM | 啟用 |
   | Buffer Length Register Width | 26 |
   | Address Width | 32 |
   | 兩側 Memory Map Data Width | 32 |
   | 兩側 Stream Data Width | 32 |
   | 兩側 Max Burst Size | 16 |
   | Allow Unaligned Transfers / DRE | 關閉 |

3. **＋** → 搜尋 `sha3_axis_top` → 加入。
4. 選取 SHA-3 IP，在 Block Properties 名稱改為 `sha3_ip`；DMA 改為 `sha3_dma`。
5. 拖曳 DMA `M_AXIS_MM2S` 至 SHA-3 `S_AXIS`。
6. 拖曳 SHA-3 `M_AXIS` 至 DMA `S_AXIS_S2MM`。
7. 按住 Ctrl 同時選取兩者，右鍵 **Create Hierarchy**，命名 `sha3`。

### 8.5 控制與 DDR 資料接線，講義第 26–30 頁

可先用 Run Connection Automation，選共同的 PS FCLK_CLK0，將 DMA 的控制端接 GP0、memory masters 接 HP0。完成後逐一核對下面的接線。手動重建時可加入兩個 **AXI Interconnect**。

1. `axi_control` 設 Slave interfaces=1、Master interfaces=1。
2. `axi_memory` 設 Slave interfaces=2、Master interfaces=1。
3. 依下表拖曳介面。

   | 起點 | 終點 |
   |---|---|
   | PS `M_AXI_GP0` | `axi_control/S00_AXI` |
   | `axi_control/M00_AXI` | `sha3/sha3_dma/S_AXI_LITE` |
   | `sha3/sha3_dma/M_AXI_MM2S` | `axi_memory/S00_AXI` |
   | `sha3/sha3_dma/M_AXI_S2MM` | `axi_memory/S01_AXI` |
   | `axi_memory/M00_AXI` | PS `S_AXI_HP0` |

4. 若階層邊界阻擋跨層拖曳，可進入 `sha3` 後將 DMA 的三個 memory/control 介面建立對應的 hierarchy interface pins，再回上層連接。已附的 Tcl 會自動建立這些階層穿越連線。
5. 新增 **Processor System Reset**，命名 `rst_ps7_0_25M`。
6. 新增兩個 **Constant**，一個輸出 1，另一個輸出 0。
7. 完成下列 clock 與 reset 接線。Run Connection Automation 建立的 reset 和 interconnect 可能採不同名稱，以訊號角色核對。

   | 訊號來源 | 所有目的端 |
   |---|---|
   | PS `FCLK_CLK0` | PS `M_AXI_GP0_ACLK`、PS `S_AXI_HP0_ACLK`、DMA `s_axi_lite_aclk`、`m_axi_mm2s_aclk`、`m_axi_s2mm_aclk`、SHA-3 `axis_aclk`、reset `slowest_sync_clk` |
   | PS `FCLK_CLK0` | 兩個 interconnect 的 `ACLK`、所有使用中的 `Sxx_ACLK` 與 `Mxx_ACLK` |
   | PS `FCLK_RESET0_N` | reset `ext_reset_in`，低有效極性由連線傳遞 |
   | Constant 1 | reset `dcm_locked` 及低有效的 `aux_reset_in` |
   | Constant 0 | reset `mb_debug_sys_rst` |
   | reset `peripheral_aresetn` | DMA `axi_resetn`、SHA-3 `axis_aresetn` |
   | reset `interconnect_aresetn` | 兩個 interconnect 的 `ARESETN`、所有使用中的 `Sxx_ARESETN` 與 `Mxx_ARESETN` |

8. 打開 **Address Editor → Assign All**。確認 PS 可看到 DMA 的控制暫存器，DMA MM2S 和 S2MM 的 address space 都可看到 HP0 DDR。自動專案的 DMA 控制基址為 `0x40400000`。
9. **Regenerate Layout → Validate Design → Ctrl+S**。

### 8.6 HDL wrapper 與 bitstream，講義第 32–37 頁

1. Sources 對 `design_1` 按右鍵 → **Create HDL Wrapper**。
2. 選 **Let Vivado manage wrapper and auto-update** → OK。
3. 對 `design_1_wrapper` 按右鍵 → **Set as Top**。
4. 回到本文件第 3 節產生 bitstream、檢查 timing，再匯出及上板。

## 9. 與老師講義的對照

| 講義 | 本專案 |
|---|---|
| 第 6 頁 PYNQ-Z2 | 相同板型，附 board files |
| 第 8–12 頁 Sobel design | `rtl/core/` 加 `sha3_axis_top.sv` |
| 第 13–16 頁打包 IP | `research.local:user:sha3_axis_top:1.0` |
| 第 18–20 頁 Zynq PS | Board preset、GP0、HP0、FCLK0 |
| 第 21–25 頁 DMA/Stream | 雙向 simple DMA，32-bit Stream |
| 第 28–29 頁 sobel 階層 | `sha3/sha3_ip` 與 `sha3/sha3_dma` |
| 第 32–37 頁 wrapper/bit/hwh | 自動建置、檢查與匯出至 `build/overlay/` |
| 第 39–45 頁預約/Jupyter | 依實驗室現行規則執行自己的 SHA-3 notebook |

本次為 bring-up 選用 25 MHz、DMA Address Width 32 和 jobs=2。後續可依 timing、板卡環境與主機資源調整這三項，並重新產生匹配的 bit/hwh。
