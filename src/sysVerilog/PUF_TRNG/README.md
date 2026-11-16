# FPGA SHA3 與健康監測原始熵源

已完成 SHA3 與健康熵源的獨立驗證，也已完成第四階段同一份 FPGA 電路的功能整合實板驗收：34 次已知訊息、16+1000 批完整流程、9 組原始熵估計與 9 組 RO 重啟評估通過。資料由板上處理器串接，尚未聲稱正式熵信用或認證的 TRNG。

## 組員先看這裡

- [已完成驗證與交付總索引](stage4_trng/verification/README.md)：目前結果、原始證據、限制與可上板檔案。
- [SHA3 功能整合版本](stage4_trng/README.md)與[整合版直接上板步驟](stage4_trng/docs/BOARD_ONLY_STEPS.md)：本次的新階段，使用自己的配對發布包，不與舊版混用。
- [最新整合版實板報告](stage4_trng/captures/board_21600/integrated_20261116/REVIEW.md)：本次原始資料綜合保留估計為 **7.092671 bits／八路樣本**，不是已保證的輸出熵。
- [SHA3 輸出 SP 800-22 初測](stage4_trng/captures/board_21600/sts_pilot_20261116/REVIEW.md)：實際百萬 bits，15 類均適用，188 個子結果中 187 個達門檻，保留 1 個模板低 P 值，未宣稱全項通過。
- [目前健康監測版本與用途](stage3_health/README.md)
- [直接上板流程](stage3_health/docs/BOARD_ONLY_STEPS.md)：使用已配對八檔，不需要自行操作 Vivado。
- [前版健康來源實板分析](stage3_health/captures/board_21600/health_20261111/REVIEW.md)：16 批功能驗收、1000 批復測、9 組非 IID 估計及 9 組 RO 重啟評估。
- [給老師的結果圖與原始輸出](stage3_health/delivery/teacher_evidence_20261111/展示說明.md)
- [SHA3 基礎模組](stage1_sha3/docs/DESIGN.md)：供下一階段整合使用。

本次健康監測版在板號 21600、divider 512 的保留統計估計為 **6.638383 bits/八路樣本**；它不是正式熵信用或認證。RO7 的偏置與時間相關也保留在報告中，沒有刪除較差資料以提高結果。

## 精簡後的資料結構

| 目錄 | 保留內容 |
|---|---|
| stage1_sha3 | 已驗證 SHA3 RTL、驅動、必要回歸測試、建置腳本、板卡定義與配對發布檔 |
| stage2_entropy | 只保留舊版比較基準、門檻重播所需 raw 資料、NIST 工具/版本/授權與其驗證紀錄；舊版 RTL/GUI/參數掃描流程已移除 |
| stage3_health | 現行 RTL、驅動、收集/分析程式、必要驗證、上板檔、原始實驗 ZIP、報告與截圖 |
| stage4_trng | 凍結 SHA3／健康來源、同一份電路的 PS 搬運整合、故障停止、完整系統驗證與新資料收集 |
| cleanup | 此次清理的範圍、數量與完整性核對摘要 |

最新原始資料只保留一份原始 ZIP；重複解壓副本、衍生通道檔與工作用工程已刪除。重新分析時由程式驗證 ZIP 內容並在被忽略的 build/analysis_input 產生暫存，不覆寫原始證據。

目前已配對的發布檔保留在各階段 build/overlay，忽略規則已明確允許它們與精選報告納入版本管理。完整 Vivado 工作工程、IP 複本、編譯快取不納入版本管理；可從保留的 RTL/Tcl 重新產生。

依應用收尾範圍，stage4 功能整合、有限原始資料評估與單條輸出初測均已完成。保留原始資料與未達門檻的子結果，不宣稱輸出全項通過、正式熵信用或 NIST 認證。若未來擴大為產品安全性或低功耗主張，再另行建立對應的驗證計畫。
