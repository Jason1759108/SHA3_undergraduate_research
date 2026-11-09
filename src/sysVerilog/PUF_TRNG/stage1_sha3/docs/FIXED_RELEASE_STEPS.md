# Reset 修正版：你接下來要做的事

本文件是 2026-11-09 修正後的上板流程。沿用老師簡報的 Vivado → bit/hwh → PYNQ Jupyter 流程；目前只驗證 SHA3，尚未接入 TRNG 熵源。

目前已發布版本為 `sha3-reset-fixed-20261109T135050Z`；檔案已備妥，不必重新建置。

## 1. 先恢復板子

1. 等管理員確認該板已恢復，必要時由管理員重新上電或重開板上 Linux。瀏覽器重新整理、Restart Kernel 無法保證解除已卡住的硬體匯流排。
2. 確認板號及本次使用時段，沒有別的 notebook 或程式正在操作這張板。
3. 用實驗室原本提供的網址登入，先確認 Jupyter 檔案首頁可開啟。
4. 不再開啟或執行舊資料夾內的 SHA3 notebook。電腦上的舊問題檔已另外保存在 `build/archived_reset_bug`，供追溯。

## 2. 使用修正版五個檔案

Windows 檔案總管開啟：

```text
D:\C++\SHA3_undergraduate_research\src\sysVerilog\PUF_TRNG\stage1_sha3\build\overlay
```

應包含以下五個檔案，全部一起上傳；不要混用以前上傳的檔案。

| 檔案 | 用途 |
|---|---|
| sha3_pynq.bit | 修正 reset 接線後的 FPGA 配置 |
| sha3_pynq.hwh | 同一份硬體的接線、位址與時脈資訊 |
| sha3_pynq.py | 含離線檢查與 DMA 啟停檢查的驅動 |
| SHA3_Bringup.ipynb | 逐步上板測試 |
| release_manifest.json | bit/hwh 的 SHA-256 與完整系統模擬紀錄 |

1. Jupyter 檔案首頁按 **New → Folder**，勾選新資料夾，按 **Rename**，命名例如 `overlays_113511153_sha3_fixed_20261109`。
2. 進入資料夾，按 **Upload**，選取上述五個檔案；逐一按藍色 **Upload** 確認。
3. 確認五個檔案同層，沒有自動加上 `(1)` 等後綴。
4. 雙擊這次新上傳的 `SHA3_Bringup.ipynb`。若有舊 kernel，使用 **Kernel → Restart & Clear Output**。這一步應在板子已恢復、舊工作已結束後進行。
5. 先逐格執行，暫時不要 **Run All**。

## 3. 一格一格測試

點 code cell 後按 **Shift+Enter**。

1. 第一格僅印出 `kernel OK`。應立即完成，左側由 `[*]` 變成數字。若最簡單的 print 都無法執行，先處理 Jupyter/kernel，不要繼續載入硬體。
2. 下一格載入 Python 模組並列出版本。你的既有環境是 PYNQ 2.5、Python 3.6.5；本次已針對這個 API 做相容性檢查。
3. 執行 `validate_artifacts("sha3_pynq.bit")`。這格只讀檔案，檢查 bit/hwh 雜湊、reset 極性、clock、DMA 參數、Stream 與記憶體接線。應列出 `build_id`、25 MHz、DMA 位址等資訊。若失敗，不要往下執行，保留完整錯誤。
4. 執行建立 `Sha3Session` 的一格。正常會依序出現：

   ```text
   1/4 release hashes and hardware wiring checked
   2/4 HWH parsed; downloading overlay
   3/4 overlay downloaded; FCLK0=25.000 MHz; checking DMA startup
   4/4 DMA channels started
   READY ... sha3/sha3_dma ...
   ```

   25 MHz 允許少量顯示誤差。若停住，記錄最後一行及等待時間。DMA 狀態有回應但無法啟動時會逾時；若 PS 的 MMIO 讀取本身卡死，Python 的逾時也可能無法執行，需交由管理員恢復板子。
5. 執行 `abc` 格。FPGA 與 Python 應一致：

   ```text
   3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532
   ```

6. 執行 `self_test(session, rounds=2)`。包含 17 種訊息的兩輪測試，涵蓋空訊息、135/136/137、271/272/273、1000、4096 bytes。預期結尾：

   ```text
   SUCCESS 34 FPGA SHA3-256 comparisons
   ```

7. 執行 `session.close()` 釋放已完成工作的 buffers。
8. 儲存 notebook，並下載保留輸出、板號、日期、版本資訊和 `release_manifest.json`。完成後依實驗室現行規則結束使用。

## 4. 遇到錯誤

- 檔案檢查失敗：重新上傳這個 release 的五個檔案到新資料夾；不要手動改 manifest 讓它通過。
- 有 traceback：保留全文與最後一個檢查點，先停止後續 cell。
- DMA transfer timeout，但 kernel 仍能執行：本次 driver 會保留 buffers。在你仍獨占板子的前提下，可執行 `session.reset()`。它先清除兩個 DMA 的 RS 並確認 Halted，成功後才重新下載 overlay。若 stop timeout，會保留 buffers 並停止恢復，不要強制 freebuffer 或重複重新下載。
- 連最簡單的 print 都卡住，或網站無法連線：交由管理員確認板上 Linux/供電/網路及轉發服務；不要只靠 Restart Kernel 重複嘗試硬體。
- 新 kernel 並不代表先前硬體工作已停止；故障後先確認板子已恢復，再依本文件重新開始。

## 5. 若你想在 Vivado 查看修正

這次提供的 `build/overlay` 完成發布後即可使用，不必為了上板再手動接線。

1. 開啟 Vivado 2025.2，在 **Window → Tcl Console** 顯示底部主控台。
2. 執行：

   ```tcl
   source {D:/C++/SHA3_undergraduate_research/src/sysVerilog/PUF_TRNG/stage1_sha3/vivado/open_project.tcl}
   ```

3. **Sources → Design Sources → design_1** 雙擊開啟 Diagram。
4. 查看 reset IP：`C_AUX_RESET_HIGH=0` 時，`aux_reset_in` 接 `constant_one/dout`；`dcm_locked` 也接 1；`mb_debug_sys_rst` 接 0；PS FCLK_RESET0_N 接 ext_reset_in。FCLK0 為 25 MHz。
5. 查看 `sha3` 階層內兩條 Stream：DMA MM2S → SHA3 S_AXIS、SHA3 M_AXIS → DMA S2MM。
6. 看報告可用 **Flow Navigator → Implementation → Open Implemented Design**。即使成功彈窗已關閉也能從這裡開啟。接著 **Reports → Timing → Report Timing Summary**，查看 WNS/WHS；其他報告在 `build/reports`。

## 6. 本機重跑完整檢查及重新發布

若沒有修改來源，已附的驗證紀錄可直接查看。若修改 BD/RTL，請重新執行；不能將舊 PASS 當成新設計結果。

PowerShell：

```powershell
Set-Location 'D:\C++\SHA3_undergraduate_research\src\sysVerilog\PUF_TRNG\stage1_sha3'
python verify_baseline.py
python sim/run_sim.py
python sim/run_sim.py --suite normal
python sim/run_sim.py --suite ft
```

在 Vivado Tcl Console，既有專案可執行以下兩行；若是從空白重建，先參考原教學的 create_project 步驟。repair 腳本會修正既有 reset 線並重新產生目標。

```tcl
source {D:/C++/SHA3_undergraduate_research/src/sysVerilog/PUF_TRNG/stage1_sha3/vivado/repair_existing_project.tcl}
source {D:/C++/SHA3_undergraduate_research/src/sysVerilog/PUF_TRNG/stage1_sha3/vivado/prepare_system_sim.tcl}
```

PowerShell 執行實際 vendor IP 完整 BD 模擬與 PYNQ 2.5 相容性檢查：

```powershell
python sim/run_system_sim.py
python sim/check_host.py
```

最後回到 Vivado：

```tcl
source {D:/C++/SHA3_undergraduate_research/src/sysVerilog/PUF_TRNG/stage1_sha3/vivado/build_bitstream.tcl}
```

它會在需要時重新綜合/實作，檢查 timing，確認完整系統測試的 HWH 與待發布檔案一致，然後建立五個上板檔案。完整模擬未通過時，不會發布。過程可能花數分鐘至數十分鐘；詳細日誌在 build 之下。

## 7. 驗證能保證到哪裡

完整 BD 模擬包含實際 SHA3 RTL、AMD AXI DMA/interconnect/reset，以及 PS VIP 的 GP0 讀寫與 DDR 輸入模型，輸出在 HP0 介面獨立逐 byte 核對；可以提前抓到本次「reset 一直有效」這種原本核心測試漏掉的問題。vendor VIP 的儲存 backdoor 在初次測試未反映 HP0 寫入，故本次並未把它列為 DDR 回讀驗證通過。測試也未執行板上 Linux、實際 DDR 訓練、實體供電/網路，且 PYNQ 軟體檢查以模擬 MMIO/記憶體取代實板。因此不能承諾 100% 上板一定成功，必須以上述實板 abc 和 34 次比對作最後驗收。
