# Vivado 建置結果

2026-11-12，Vivado 2026.1、PYNQ-Z2 xc7z020clg400-1。RTL 為 320 pairs / 640 RO / 16-bit 飽和計數器。

正式 routed timing / CDC / DRC / bus-skew 檢查 **PASS**，bitstream 已產生並上板。

| 項目 | 最終結果 |
|---|---|
| Setup WNS / failing endpoints | +0.112 ns / 0 |
| Hold WHS / failing endpoints | +0.059 ns / 0 |
| Pulse width WPWS / failing endpoints | +0.500 ns / 0 |
| Gray CDC buses | 640，全部通過 8 ns skew 限制 |
| 最大 bus skew / 最小 slack | 2.975 ns / +5.025 ns |
| Missing clocks / unconstrained internal endpoints | 0 / 0 |
| Critical CDC / severe DRC | 無 / 無 |
| LUT / FF | 17,909 / 47,456，33.66% / 44.60% |
| Unique control sets | 2,614 |

CDC 的 640 個 CDC-6 warning 為刻意使用的 Gray 多位元同步器，配合逐組 max-delay 與 bus-skew 檢查；1,280 個 CDC-9 info 為 reset 同步器。這不代表所有工具訊息都為零。

建置目錄：`C:/Users/a0981/Documents/Codex/rd320/vivado_20261112_153532`。最終 bitstream 來自 `finish_from_physopt.tcl` 的獨立繞線與檢查流程，不沿用先前中途的時序估算。六個 RTL 檔已與實際匯入的 IP source 逐 byte 比較一致。

final_routed.dcp SHA256：`f33aba2f090b6f5fe2af0e7475aa228a27141c746b20e8f4614e90cd0533567f`。bit/hwh/driver/helper/Notebook 雜湊見 `04_BOARD/MANIFEST.json`。

## Methodology：234/234 完成，保留原始警告

2026-11-13 已完成剩下的 57 項 `TIMING-1..57`，加上先前的 177 項非 Timing，合計 **234/234**。Timing 規則合併呼叫的原生報告時間為 98 秒；該程序連同完整路徑及正式報告檢核共 319.213 秒，不含另一個原設定參考程序。

卡住的位置已定位至 Vivado 的 clock uncertainty 約束產生／清理流程。原生取樣觀察到約 1,646,181 筆內部約束，以及逐項搜尋的卸載迴圈；本設計有 1,281 個時脈。縮小時脈數量可重現大幅加速；移除 PUF 控制器、Gray CDC 與 RO 回授後，大量時脈仍可重現延遲。原設定完整分析持續運算 4,501.594 秒仍未返回，之後在保守替代分析驗證成功後停止。詳見 METHODOLOGY_DIAGNOSIS.md。

| 規則 | 原始等級 | 數量 | 說明 |
|---|---|---:|---|
| TIMING-2 | Critical Warning | 640 | LUT 輸出作為刻意建立的 RO primary clock |
| TIMING-4 | Critical Warning | 640 | 在 RO clock tree 中建立 primary clock 邊界 |
| TIMING-14 | Critical Warning | 640 | RO 的 LUT 位於 clock tree |
| TIMING-23 | Warning | 640 | 刻意保留的 RO 組合回授 |
| LUTAR-1 | Warning | 1 | reset 邏輯含 LUT |
| ULMTCS-2 | Warning | 1 | 控制集合使用量 |
| XDCB-1 | Warning | 1 | 大型 reset 例外的執行時間提示 |

沒有 Error 或非預期的規則違反；**完成不等於零警告 PASS**。上述等級沒有被調降，也沒有套用全域 waiver。

## 分析繞法與驗證範圍

僅在獨立、唯讀的 methodology 程序載入同一份 routed checkpoint **之前**，設定 Vivado 內部參數 `sta.enableClockUncertainty=false`，避開有問題的資料重建流程。這不是 AMD 官方修補，也不是建議用於 synthesis、route 或全域初始化的設定；不能只因為它加速就接受結果。

接受門檻是另一個完全使用原始預設值的參考程序，與候選程序逐項比較：

- 兩邊來源 DCP SHA256 相同，1,281 個時脈完整；所有使用者 timing 命令及 234 個規則啟用值相同。
- 90,456 筆 max（setup/recovery）紀錄的比較欄位全部相同。
- 80,216 筆 min（hold/removal）紀錄沒有任何端點的最差 slack 變寬鬆。592 筆 divider clock-as-data feedback 加上 0.035 ns uncertainty；其中 591 筆 slack 收緊，1 筆最差 slack 不變。其餘紀錄相同。
- 候選的 routed setup/hold/pulse、640 組 Gray max-delay／bus-skew、CDC、DRC 均通過；上表 WNS、WHS、WPWS 與 bus-skew 結果維持原值。

因此記為 **conservative=true、equivalent=false**。這份證據驗證本 checkpoint 上的檢查結果至少同樣保守，沒有宣稱旗標在所有設計上等價。每次新建置都要重新比較，失敗不寫 Timing DONE／COMPLETE。

完整數據、原生報告及 proof 在 `sample_results/vivado_2026_1/methodology_runtime`；目前狀態在 `methodology_status.json`。`04_BOARD/MANIFEST.json` 的 `complete_at_prepare=false` 是上傳當時的實驗輸入，保留不回改；目前完成狀態由上述獨立結果記錄。

`build.tcl`／`resume.tcl` 先保存 routed DCP、正式報告及 bitstream，再執行 `methodology_separate.tcl`。Windows Vivado 2026.1 的 Timing 階段會透過 `run_methodology.py` 順序執行參考、候選與保守性驗證，使用 Vivado 隨附 Python；其他環境保留原生分析流程。這沒有禁用任何 methodology 規則。

24-bit 第一版的放置失敗，以及未採用的 feedback／reset 例外分批實驗保留為歷史診斷，沒有改入部署 RTL、正式 timing 命令或既有 bitstream。
