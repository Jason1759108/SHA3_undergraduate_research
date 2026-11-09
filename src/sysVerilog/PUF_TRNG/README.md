# SHA-3 FPGA 上板與後續 TRNG

**目前狀態（2026-11-09）。** aux reset 接線已在來源與既有 Vivado 專案修正，已重新綜合、實作、產生 bitstream 並完成發布。`stage1_sha3/build/overlay` 現在是修正版五檔；舊檔只保留在 `build/archived_reset_bug` 供追溯。完整 BD 模擬的 36 次比對（輸出於 HP0 介面核對）、核心一般/FT 回歸及 PYNQ 2.5 mock 相容性檢查通過；實板尚待管理員恢復後驗收。

**下一步先讀 [修正版逐步操作](stage1_sha3/docs/FIXED_RELEASE_STEPS.md)**：板子恢復 → 新資料夾上傳五檔 → 逐格執行。無需再手動重建已發布的 bitstream。

目前準備的是第一階段 SHA3-256 overlay，使用 PYNQ-Z2、Vivado 2025.2、Zynq PS 與雙向 AXI DMA。輸入由 Python 提供，輸出與 Python `hashlib.sha3_256()` 比較。

所有第一階段資料位於 `stage1_sha3/`。請依序閱讀以下文件。

1. [詳細操作教學](stage1_sha3/docs/VIVADO_PYNQ_GUIDE.md) 包含開啟已建立專案、檢查接線、產生 bitstream、上傳與執行 notebook，以及從空白專案手動重建的按鈕步驟。
2. [設計與檔案說明](stage1_sha3/docs/DESIGN.md) 說明 FPGA clock-enable 改寫、DMA 封包、檔案清單與後續 TRNG 接入位置。
3. [驗證紀錄](stage1_sha3/docs/VALIDATION.md) 列出本機實際完成的測試與建置結果。

若要在 Vivado 查看設計，可在 Tcl Console 執行以下一行，開啟已建立的 Block Design。

```tcl
source {D:/C++/SHA3_undergraduate_research/src/sysVerilog/PUF_TRNG/stage1_sha3/vivado/open_project.tcl}
```

如果把檔案複製到另一台電腦，依詳細教學先執行 `create_project.tcl`，再開啟生成的專案。
