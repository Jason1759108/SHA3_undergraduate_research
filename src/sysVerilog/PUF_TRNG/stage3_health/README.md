# 第三階段：啟動與運行健康監測

**實板驗收更新（2026-11-11）：** 板號 21600 的 16 批功能驗收與 1000 批復測已完成；健康狀態正常、RO 關閉、檔案獨立重匯出核對通過。9 組非 IID 統計估計完成，9 組 RO 重啟測試通過；八路聯合重啟後保留估計約 6.638383 bits/樣本。RO7 的相關與偏置仍須保留說明。見 [實板分析報告](captures/board_21600/health_20261111/REVIEW.md)。本輪限定條件的候選驗收可結案，下一步可進行 SHA3 功能整合；沒有宣稱正式熵信用或認證。

本階段是獨立的健康監測候選版本。第二階段的 RTL、Vivado 專案、發布檔與量測資料保留原樣。

流程：八路 RO → 兩級同步 → 暖機 → 1024 點啟動健康檢測 → 1024 點 payload 擷取與持續健康檢測 → 整批合格才允許讀 RAM。無 DMA、無自訂 DDR bus master，尚未接 SHA3。

**目前直接使用已準備好的檔案，不需要練習 Vivado：** 先讀 [直接上板流程與檔案用途](docs/BOARD_ONLY_STEPS.md)，資料包為 `delivery/entropy_health_ready_20261111.zip`，解壓後上傳 board_files 中八檔即可。

GUI 練習教學已移除，保留 Tcl 建置腳本供重建。接線與介面見 [IO／暫存器](docs/IO_AND_REGISTERS.md)，監測假設與來源限制見 [設計與門檻依據](docs/HEALTH_POLICY.md)，實際本機結果見 [驗證紀錄](docs/VALIDATION.md)。

核心新增 `rtl/entropy_health_monitor.sv`；修改版控制器仍叫 `entropy_axi`，但打包 IP 名稱是 **entropy_health_axi**，硬體 ID 是 **0x524F4832（ROH2）**。不能與第二階段的 entropy_ro.bit、entropy_pynq.py 混用。

原始來源第一輪資料統計評估已在第二階段結案；本階段不把舊版約 6.65 bits/八路樣本當成新實作的保證。RCT/APT 門檻使用每通道 H_monitor=0.5 的研究監測假設，沒有因此分配任何正式熵信用。新實作需要依教學作功能驗收與固定設定復測。

`build/overlay` 是已核對的八檔發布版本。完整 Vivado 工程、IP 複本與模擬工作目錄已清除；保留 RTL、Tcl、必要測試、PASS 指紋與精選日誌。重新建置時須重建工程與受影響測試，不能拿歷史 PASS 代替新設計。

## 原始資料與重新分析

最新原始實驗 ZIP 及有輸出的 notebook 保留在 captures/board_21600/health_20261111。解壓副本與衍生通道檔已清除；sim/archive_datasets.py 會從原始 ZIP 校驗並還原十個匯出檔至 build/analysis_input。sim/review_campaign_stats.py 可重算並比對保存的描述性統計；sim/assess_board_capture.py 使用凍結工具作熵評估。NIST 工具版本與來源授權保留在第二階段。

不將實驗原始 ZIP、必要負向/故障回歸測試或精選工具日誌視為可刪的測試垃圾：它們分別支持 6.638 的可追溯性與健康監測的故障行為。
