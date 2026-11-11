# FPGA SHA3 與健康監測原始熵源

目前已完成兩個子系統的獨立驗證：SHA3 計算電路，以及具啟動檢查、RCT/APT 的八路 RO 候選熵源。尚未整合為完整 TRNG。

## 組員先看這裡

- [目前健康監測版本與用途](stage3_health/README.md)
- [直接上板流程](stage3_health/docs/BOARD_ONLY_STEPS.md)：使用已配對八檔，不需要自行操作 Vivado。
- [最新實板分析](stage3_health/captures/board_21600/health_20261111/REVIEW.md)：16 批功能驗收、1000 批復測、9 組非 IID 估計及 9 組 RO 重啟評估。
- [給老師的結果圖與原始輸出](stage3_health/delivery/teacher_evidence_20261111/展示說明.md)
- [SHA3 基礎模組](stage1_sha3/docs/DESIGN.md)：供下一階段整合使用。

本次健康監測版在板號 21600、divider 512 的保留統計估計為 **6.638383 bits/八路樣本**；它不是正式熵信用或認證。RO7 的偏置與時間相關也保留在報告中，沒有刪除較差資料以提高結果。

## 精簡後的資料結構

| 目錄 | 保留內容 |
|---|---|
| stage1_sha3 | 已驗證 SHA3 RTL、驅動、必要回歸測試、建置腳本、板卡定義與配對發布檔 |
| stage2_entropy | 只保留舊版比較基準、門檻重播所需 raw 資料、NIST 工具/版本/授權與其驗證紀錄；舊版 RTL/GUI/參數掃描流程已移除 |
| stage3_health | 現行 RTL、驅動、收集/分析程式、必要驗證、上板檔、原始實驗 ZIP、報告與截圖 |
| cleanup | 此次清理的範圍、數量與完整性核對摘要 |

最新原始資料只保留一份原始 ZIP；重複解壓副本、衍生通道檔與工作用工程已刪除。重新分析時由程式驗證 ZIP 內容並在被忽略的 build/analysis_input 產生暫存，不覆寫原始證據。

目前已配對的發布檔保留在各階段 build/overlay，忽略規則已明確允許它們與精選報告納入版本管理。完整 Vivado 工程、IP 複本、編譯快取不保留，需重新建置時從保留的 RTL/Tcl 產生。

下一步是將健康來源與 SHA3 放入同一個新 overlay，驗證資料傳送、雜湊結果與故障時禁止有效輸出。現在沒有接 SHA3，也未聲明輸出可用於正式密碼學用途。
