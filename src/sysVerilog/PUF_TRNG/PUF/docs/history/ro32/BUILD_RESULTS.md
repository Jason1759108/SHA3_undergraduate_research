# 32 組 RO FPGA 建置結果

最終獨立設計已在 Vivado 2026.1 完成綜合、佈局繞線與 bitstream 產生。器件為 `xc7z020clg400-1`，使用隨套件附上的 TUL PYNQ-Z2 board preset。沒有引用原 PUF／SHA3 專案。

| 項目 | 最終結果 |
|---|---:|
| Setup WNS | +0.543 ns |
| Hold WHS | +0.063 ns |
| Pulse-width WPWS | +0.500 ns |
| Setup／Hold／Pulse-width 失敗端點 | 0／0／0 |
| Gray CDC bus skew | 64 組均通過 |
| 最大 bus skew／上限 | 1.820／8.000 ns |
| 最小 skew 餘裕 | +6.180 ns |
| LUT | 3658／53200（6.88%） |
| FF | 7676／106400（7.21%） |

沒有缺少 clock 或未約束的內部端點。CDC 有 64 項 CDC-6 Warning（使用 ASYNC_REG 的 Gray 多位元同步，搭配個別 max-delay／bus-skew 約束），128 項 CDC-9 Info（同步重設），無 Critical CDC。DRC 無 Error 或 Critical Warning。

刻意的 LUT RO 仍會產生 methodology `TIMING-2/4/14` 各 64 項 Critical Warning、`TIMING-23` 64 項 combinational-loop Warning，另有 1 項 LUTAR-1 Warning。這些報告保留，沒有用全域降級或關閉檢查處理。RO 內部時脈的工具警告與上表 routed STA 判定分開記錄，不能據 STA 通過就宣稱已完成 PUF 安全性驗證。

32 組擴充後，選擇／解碼與差值／零值判斷之間加入一級暫存。高速重設改為直接驅動 CLR 的高有效同步訊號。除頻器 next-state LUT 與暫存器固定在同 Slice，避免單條局部繞線成為 500 MHz 上限假設下的失敗路徑。系統時脈 100 MHz、RO 原始最小週期 2 ns、Gray max delay／bus skew 8 ns 皆維持，reset recovery/removal 路徑保留。

## 部署來源

- 工程：`C:/Users/a0981/Documents/Codex/rd32/vivado_20261107_010229/project/ro_diag.xpr`。
- 最終輸出：`deploy/20261107_133950/`，與 `04_BOARD/` 相同。
- 六份 RTL 與 Vivado 實際打包綜合來源逐 byte 核對相符；雜湊及完整檢查值在 `04_BOARD/MANIFEST.json`。
- bit SHA256：`99047d51eb44e487bc9950e619ece6e9fb94fb1d484455e789ad0857118ae666`。
- hwh SHA256：`0c1047742f86b32071ee22744c760b73ba7b73ac34c400ef5e400ffaeac56a06`。
- 實際報告：`sample_results/vivado_2026_1/`；判定入口為 `00_TESTBED/check_reports.py`。

`02_VIVADO/prepare_deployment.py --build <建置目錄> --deploy <輸出目錄>` 會先重新檢查 routed 報告、比對實際綜合來源，再整理 `04_BOARD`。本機整理工具使用 Python 3.12；上板 Notebook／driver 使用 Python 3.6 相容語法。
