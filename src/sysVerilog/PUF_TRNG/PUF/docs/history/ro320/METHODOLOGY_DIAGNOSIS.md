# Timing methodology 執行時間診斷

診斷日期：2026-11-12～13。Vivado 2026.1，獨立 RO320 套件。

## 已確認的現象與原因範圍

57 項 `TIMING-1..57` 共用時序前處理；在這個步驟尚未返回時，不能把它們記成通過或違反。原設計有 641 個 primary clocks（640 個 RO 與一個 SYS）及 640 個 /8 generated clocks，共 1,281 個時脈。

原生取樣顯示，一個執行緒持續使用約一個 CPU 核心。堆疊包含 `HASTUtil::ensureTimingForDRC`、clock uncertainty 的計算／約束產生流程，以及 `HASCConstrMgr::unloadConstr`。這支持高成本發生在工具的共用時脈／時序約束前處理，而不是等待使用者輸入或先讀到 57 個 RTL 錯誤。取樣使用本機 module/export 符號；沒有 vendor 私有 PDB，因此不能從最近符號的大位移推定精確原始碼或演算法複雜度。

## 可重現對照

| 電路／變體 | 時脈數 | TIMING-1 結果 |
|---|---:|---|
| 完整原始 routed 電路 | 1,281 | 90 秒分析時限內未返回 |
| 同一實體電路，只保留前 64 個 RO 的時脈定義 | 129 | 10.158 秒 |
| 小型 counter 電路，無 PUF 控制器、Gray CDC、RO 回授或 reset 例外 | 1,281 | 90 秒分析時限內未返回 |
| 同一個 128-RO 小型電路，只保留 64 個 RO 時脈 | 129 | 2.309 秒 |
| 同一個 128-RO 小型電路，全部時脈 | 257 | 12.660 秒 |
| 257 時脈，完全相同的約束 reset/reload | 257 | 11.306 秒 |
| 257 時脈，jitter 歸零的隔離實驗 | 257 | 19.454 秒；不作正式檢查依據 |

同一小電路的時脈數約加倍，時間約增加 5.5 倍，證實這個區間的成本不是線性成長。這不是完整規模的精確時間預測，也不證明某個固定的 O(N^k) 演算法。

完整 1,281 時脈的短時限實驗另測試 RO-only asynchronous groups、RO feedback stop propagation、保留原數值的明確 input jitter、pair-only logical exclusivity，仍未在各自 90～120 秒分析時限內返回。16 執行緒執行全部 57 項也未在 600 秒內返回。這些結果僅代表時限內未返回；不能據此宣稱其最終結果或精確加速比。部分對照與長時間工作重疊，記憶體競爭也是限制。

## 完成結果與資料保全

原設定的長時間呼叫持續分析 4,501.594 秒仍未返回；在替代分析通過保守性驗證後停止。來源一直是原封不動的 `final_routed.dcp`，SHA256：

`f33aba2f090b6f5fe2af0e7475aa228a27141c746b20e8f4614e90cd0533567f`

進一步讀取與原子堆疊取樣，定位到 `HASCConstrMgr::unloadConstr` 的逐項搜尋迴圈。當時清單有 **1,646,181** 筆；1,281²=1,640,961，數量與大量 clock-pair 資料的規模吻合。這是對瓶頸位置與規模的觀察，不是 vendor 原始碼的完整證明。略過二進位時序快取並完整重載原 XDC，仍會進入相同迴圈，不能單純歸因於損壞快取。

獨立程序在載入 STA 之前設定內部參數 `sta.enableClockUncertainty=false` 後，全部 57 項 native methodology 在 **98 秒**返回。設定在載入後才改，沒有相同改善。此參數名稱不能作為「實際 uncertainty 已消失」或「一定安全」的證據；是否能接受，由下面的數據決定。

原設定與候選使用相同 DCP，且輸出的全部使用者 timing 命令、234 項規則啟用值完全相同。比較 170,672 筆最差端點紀錄：

- 90,456 筆 max 的 slack、uncertainty、arrival/required time、data delay、skew、CPR、時脈、例外及 corner 比較欄位全部相同。
- 80,216 筆 min 沒有任何端點的最差 slack 變寬鬆。592 筆 divider[2] clock-as-data feedback 額外承受 0.035 ns uncertainty，591 筆 slack 收緊，1 筆不變；163 筆因而改由另一條路徑成為最差來源。其他紀錄相同。
- setup WNS +0.112 ns、hold WHS +0.059 ns、pulse WPWS +0.500 ns；640 組 skew 上限 8 ns，最大 2.975 ns；missing clocks、unconstrained internal endpoints、critical CDC、severe DRC 均維持原結果。

因此結果是 **保守性通過，並非數值完全等價**。沒有用減少時脈、刪除使用者約束、切斷 CDC 路徑、關閉規則或降低警告等級的方式宣稱完成。部署 bitstream、路由與板測資料沒有改動。

這是針對 Vivado 2026.1 與本 immutable routed checkpoint 驗證過的內部參數繞法，不是 AMD 官方修補。它只用於獨立 methodology 程序，不套用到 synthesis、route 或使用者全域初始化。每次新建置都要重新跑原設定參考與完整端點比較；不符合目前的嚴格條件，就拒絕完成。各步驟順序執行，避免兩個大型模型同時占用記憶體。

實際完成狀態、規則覆蓋與原始嚴重等級見 `sample_results/vivado_2026_1/methodology_status.json` 與 `methodology_checks`：**234/234，complete_with_findings**。TIMING-2/4/14 各 640 個 Critical Warning、TIMING-23 的 640 個 Warning，以及 LUTAR-1、ULMTCS-2、XDCB-1 各一個 Warning 都保留。完整 native 報告、原設定／候選資料和 `conservative_validation.json` 在 `methodology_runtime`。

`02_VIVADO/run_methodology.py` 接續原生非 Timing 檢查，順序啟動原設定參考及候選，交由 `00_TESTBED/compare_methodology_timing.py` 比較。`finalize_methodology.py` 會拒絕部分規則、小型電路、變更使用者約束、非正常返回或不夠保守的結果；核對成功才寫 Timing DONE 與 COMPLETE。

AMD 說明 uncertainty 包含 computed jitter、phase error 與額外 user uncertainty；小電路測試 jitter 數值的目的僅是隔離成因，並不據此刪除正式裕量：[UG906 Clock Uncertainty](https://docs.amd.com/r/en-US/ug906-vivado-design-analysis/Clock-Uncertainty)。跨時脈例外有優先級，直接加入 SYS↔RO clock groups 會覆蓋 Gray max-delay，因此沒有採用：[AMD CDC constraints](https://docs.amd.com/r/en-US/ug1387-acap-hardware-ip-platform-dev-methodology/Defining-Clock-Groups-and-CDC-Constraints)。
