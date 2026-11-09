# 載入 overlay 後失去回應的檢查

**2026-11-09 修正完成。** 下方是事故當時的記錄。既有專案與上板檔現已重建；目前操作請看 [修正版逐步操作](FIXED_RELEASE_STEPS.md)，測試範圍與限制見 [本次驗證](VALIDATION.md)。舊 bit/hwh 勿再上傳。


檢查日期為 2026-11-08。使用者觀察到 `Sha3Session(...)` 持續忙碌、Interrupt 與 Restart 無法恢復，之後 Jupyter 網址連線逾時，其他板子的網站仍可開啟。

## 已證實的設計錯誤

本機目前匯出的 HWH 與生成的 Reset IP 都包含以下設定。

| 項目 | 值 |
|---|---|
| Reset cell | `/rst_ps7_0_25M` |
| `C_AUX_RESET_HIGH` | `0`，低有效 |
| `aux_reset_in` | 接到 `constant_zero_dout` |
| `peripheral_aresetn` | 連到 DMA 與 SHA-3 reset |
| `interconnect_aresetn` | 連到兩個 AXI interconnect reset |

低有效的 aux reset 接到 0，代表持續要求重設。這是先前提供的建置接線錯誤。正確接法是將這個未使用的低有效輸入接到常數 1，`mb_debug_sys_rst` 則維持常數 0，`dcm_locked` 維持常數 1。aux reset 的有效極性由參數決定。 [AMD PG164](https://docs.amd.com/v/u/en-US/pg164-proc-sys-reset)

這次使用已生成的 `design_1_rst_ps7_0_50M_0_sim_netlist.v`，在 Vivado Simulator 2025.2 驗證兩個相同 Reset IP，分別接 aux=0 及 aux=1。25 MHz clock 下釋放外部 reset 並等待 200 個 cycles，結果如下。

```text
CONFIRMED original AUX=0 holds peripheral_aresetn=0 and interconnect_aresetn=0
CONFIRMED corrected AUX=1 releases both reset outputs to 1
PASS actual generated Reset IP reproduces the fault and validates the connection fix
```

也驗證了修正版本的 aux reset 再次拉低會正常重設，拉高後會正常解除。測試程式與完整日誌位於 `build/reset_audit/tb_reset_audit.sv`、`build/reset_audit/step2.log`。

## 最可能的故障路徑

`Sha3Session.__init__()` 先呼叫 `Overlay(...)`，接著取得 `overlay.sha3.sha3_dma`。PYNQ 2.5 在建立 DMA channel 時即呼叫 `start()`，寫入控制暫存器並持續讀取 running 狀態。這個初始化位於 `hash()` 的五秒 timeout 之前。若 AXI register access 本身無法返回，Python timeout 也無法介入。 [PYNQ 2.5 DMA 原始碼](https://github.com/Xilinx/PYNQ/blob/v2.5/pynq/lib/dma.py)

AXI interconnect 被持續重設時，板上 ARM 對 DMA 暫存器的交易可能無法完成，進而影響 Linux、Jupyter 與網路服務。PYNQ 維護者也說明了無回應的 AXI 存取可能造成系統停住。 [PYNQ 支援說明](https://discuss.pynq.io/t/overlay-loading-problem/3414)

因此，目前把上述 reset 接線錯誤列為最高優先的根因。尚未取得實板 UART/Linux 日誌，也尚未在重啟後以修正版做實板比對，實際當機路徑仍待確認。

目前畫面停在初始化，尚未呼叫 `session.hash(b"abc")`，這段流程也尚未配置訊息 buffers 或設定 DMA 資料搬移長度。SHA-3 訊息 padding、digest 比對與正常資料搬移因而是較後面的排查項目。

## 影響範圍與損害評估

| 層級 | 目前最合理的解釋 | 需要管理者確認的項目 |
|---|---|---|
| FPGA 的 PL 邏輯 | 被配置成讓互連和 DMA 持續處於 reset | 修正後的 reset 釋放、AXI 存取 |
| 同一顆 Zynq 的 ARM/Linux | 可能卡在無法完成的硬體存取，造成板端服務失去回應 | UART、Linux 日誌、完整板子重啟 |
| Jupyter | 執行於板端的 Python/kernel 或服務受影響 | 重啟後能否執行純 Python |
| 實驗室入口／轉送主機 | 單一板子的轉送連線可能逾時；其他板仍可開啟支持入口仍可處理其他連線 | port 21400 對應拓撲與後端狀態 |
| 使用者 Windows 電腦 | 瀏覽器呈現逾時 | 本機一般網路服務是否正常 |

此錯誤本身是數位 reset 極性與接線問題。檢查到的版本使用 25 MHz、只有一個 PL clock，這份 SHA-3 overlay 未包含 RO。未發現修改板上電源設定、驅動外接 GPIO，或抹除開機儲存裝置的程式。現有證據最符合工作中斷、未存輸出遺失與需要完整板子重啟，尚無證據能判定 FPGA、SD 卡或實驗室主機發生永久損壞。硬體最終狀態仍要由管理者重啟後測試。

## 這次修正的範圍

已更正 `vivado/create_project.tcl` 的建置來源，以及操作教學的接線表。這些文字與來源的更正不會回溯修改已生成的 `.bd`、`.bit` 或 `.hwh`。既有專案必須重新接線並完整重建。

已新增 `vivado/check_aux_reset.tcl`，在建置及匯出前核對 aux reset 的有效極性與常數驅動值。唯讀檢查已拒絕現有錯誤專案，獨立記憶體內 BD 的正確接線則通過檢查。紀錄在 `build/reset_audit/connection_check.log`。建置腳本也會在來源過期時重新執行相應 run，匯出腳本會拒絕過期產物。

`python/sha3_pynq.py` 及 `build/overlay/sha3_pynq.py` 已加入 HWH reset 接線預檢，位於 `Overlay(...)` 呼叫之前。已驗證現有錯誤 HWH 會被拒絕，改接 inactive level 的 HWH 測試資料可通過。這能攔住本次已知的 held-reset 問題，實板完整驗證仍需在硬體修正與重建後執行。

本次檢查所保留的使用者硬體檔案 hash 為以下兩筆，兩者仍含原始接線問題。

```text
sha3_pynq.bit  b1cc64c3dec021c7b0fb854e37365f5c69bf190792c40634d907757cf2d96833
sha3_pynq.hwh  d3471bf7a4bacff8a418c0440719fc3b99f9f9751d1a4cf2d248235398577f04
```

管理者恢復板子後，先驗證純 Python 與已知可用的官方範例。修正版經完整重建、匯出後，再分段驗證 HWH 解析、overlay 下載及 DMA 初始化。

## 為什麼先前的驗證沒有攔住

先前 SHA-3/wrapper testbench 直接提供可釋放的 reset，未包含 Zynq Block Design 的 Processor System Reset 和實際常數接線。STA 與 DRC 能通過，也無法單靠那些結果證明一個合法接線的 reset 已解除。此次新增的實際 Reset IP 功能網表測試才重現這個問題。
