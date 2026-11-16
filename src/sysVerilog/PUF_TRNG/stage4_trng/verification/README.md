# 已完成驗證與交付索引（2026-11-16）

這是組員閱讀目前成果的入口。原始報告與證據保留在下列固定位置，避免移動後破壞分析程式與既有連結；本目錄集中記錄驗證狀態與清理後檔案指紋。

## 結果總覽

| 驗證範圍 | 已完成的結果 | 完整紀錄 |
|---|---|---|
| RTL（硬體描述）、SHA3 故障修復、AXI 傳輸與完整系統模擬 | unit、normal、ft、axis、system、host 六組離線檢查通過 | [驗證說明](../docs/VALIDATION_RESULT.md)、[發布前結果](../build/final_validation.json)、[原始執行紀錄](../build/results/) |
| FPGA 實體實作 | WNS 3.442 ns、WHS 0.031 ns；8 個 RO 閘與 88 個反相器；保留已審閱警告 | [實作報告](../build/reports/trng_integrated/)、[警告審閱](../build/warning_review.json) |
| 整合版實板功能 | 板號 21600；34 次已知訊息、16+1000 批原始資料與 SHA3 摘要核對；結束時振盪器關閉、兩通道搬運停止 | [實板報告](../captures/board_21600/integrated_20261116/REVIEW.md)、[驗收摘要](../build/board_acceptance_20261116.json) |
| 原始熵源評估（SP 800-90B 工具） | 9 組非 IID 估計與 9 組 RO 重啟評估完成；保留估計 7.092671 bits／八路樣本 | [實板報告與限制](../captures/board_21600/integrated_20261116/REVIEW.md)、[工具原始輸出](../captures/board_21600/integrated_20261116/nist_results/) |
| SHA3 輸出統計初測（SP 800-22 工具） | 3907 批硬體摘要全部核對正確；固定前百萬 bits；15 類適用，188 個子結果中 187 個達門檻、1 個未達 | [初測報告](../captures/board_21600/sts_pilot_20261116/REVIEW.md)、[工具原始輸出](../captures/board_21600/sts_pilot_20261116/analysis/nist_sts/experiments/AlgorithmTesting/) |
| STS 測試工具本身 | 官方未改動 C 原始碼；參考數值、兩種輸入格式與全零反例校驗完成 | [工具校驗](../sts/tools/selftest_result.json)、[來源與建置指紋](../sts/tools/build_provenance.json) |

WNS/WHS 是時序餘裕，正值表示本次對應檢查滿足約束；RO 是環形振盪器。非 IID 表示評估時不先假設樣本彼此獨立且分布相同。RO 重啟是重新啟用振盪器，並非板卡斷電重啟。

## 必須一起呈現的限制

- 唯一未達門檻的是不重疊模板 `110000010`，P=0.004706 < 0.01。保留原始 FAILURE，沒有刪除、放寬門檻或重抽至通過。
- 187/188 是單條序列子結果計數，不是 NIST 多序列通過比例；沒有做多序列 P 值分布或取得認證。
- 先前建議的額外 10 條序列尚未執行。本次只整理已完成證據，不把建議列為通過項目。
- 7.092671 與前版 6.638383 都是 SHA3 之前的原始資料估計；不同布局與資料集的比較不能證明 SHA3 增加物理熵。[數字解釋](../docs/ENTROPY_COMPARISON.md)
- 目前是有健康監測與 FPGA SHA3 的 TRNG 應用原型，由板上處理器串接取樣與雜湊。輸出 256 bits 不表示已證明有完整 256 bits 熵；沒有環境、功耗或產品認證宣稱。

## 組員如何使用

1. 閱讀本頁與兩份實板報告。
2. 實際上板使用 [trng_integrated_ready.zip](../delivery/trng_integrated_ready.zip)，依[直接上板流程](../docs/BOARD_ONLY_STEPS.md)操作。
3. 如需重現單條初測，再搭配 [STS 附加包](../delivery/trng_sts_pilot_addon.zip)與[初測流程](../sts/README.md)。[初測結果分享包](../delivery/trng_sts_pilot_results_20261116.zip)可直接查閱本次工具結果。
4. 原始上板 ZIP、執行過的 notebook、分析結果保留於 [captures/board_21600](../captures/board_21600/)。軟體 SHA3 重算比對與硬體結果一同留存。

## 清理與版本管理

保留 RTL、約束、建置／分析／回歸程式、工具版本與授權、配對上板檔、原始實驗 ZIP、工具原始輸出及必要測試向量。Git 已忽略的 Vivado 工作工程、生成 IP 複本、模擬快取、解壓資料及工具下載／編譯暫存已移至儲存庫根目錄 `.tmp/trng_cleanup_20261116/`，保留原相對路徑，可還原。永久刪除被自動審查拒絕，因此採用可復原隔離；未釋放磁碟空間，部分空目錄可能仍在。這個隔離區不納入 Git。日後可由保留腳本重新產生工程；舊工程已移出原位置，不能直接開啟。

`cleanup_report.json` 記錄本次實際隔離清單與數量；`artifact_inventory.json` 記錄清理後本階段交付檔案 SHA-256。這些是整理時的快照，不會取代原始發布 manifest 或實驗驗證結果。論文等其他目錄的既有修改不在本次整理範圍。沒有執行 Git stage、commit 或 push。
