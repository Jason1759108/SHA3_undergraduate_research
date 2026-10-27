# 本機流程檢查

2026-10-27。四版全套適用 RTL suite 以 Windows Verilator 5.48.0 distribution
（runtime banner 5.49）及 MinGW GCC C++20 實際編譯、模擬通過。
每版子目錄保留 compile/build/simulation logs、latency.csv 與當時的摘要。
全部目前交付的 .sv 與已測本機副本逐檔相同比對通過。

四版：4096-byte 端到端 7575 cycles、31 permutations、standalone core 241 cycles。
V1 新增 Hamming1600 14508 checks；V1/V2/V3 跨 lane 各 6 案例。
V3 原 153 FT cases 包含 2 個預期盲點案例，不是 153 個成功恢復案例。

本機來源在 ASCII 路徑的副本測試，以避開 Windows Verilator Unicode 路徑限制。
摘要的絕對路徑是本機驗證位置；不要把這些摘要複製成工作站 rtl_latest.json。
V0/V3 的 case_results 匯出功能是在回歸後補入的報告功能；已測 SV 不變。
工作站仍要重新跑總流程，會產生正式 CSV 與來源雜湊。

不包含 VCS/DC 真實結果。flow_checks 是腳本與合成報告 parser 的模擬資料檢查，
只能證明程式處理邏輯，不能當作 ASIC 面積、功耗或 timing 結果。
