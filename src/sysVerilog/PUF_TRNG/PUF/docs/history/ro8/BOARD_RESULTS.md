# PYNQ-Z2 實板 RO 量測結果

獨立 RO 量測套件已在使用者授權的 PYNQ-Z2 實體板上完成部署與量測。原 SHA3／PUF 專案未修改。

後續 10,560 筆讀取與 10 回合 bitstream 重載測試亦已完成，詳見 [RELIABILITY_RESULTS.md](RELIABILITY_RESULTS.md)。下列內容保留最初 256 筆測試的紀錄。

## 環境

- Vivado 2026.1，BASIC 授權，器件 xc7z020clg400-1。
- 課程板子：http://140.113.201.80:20100/，BOARD 環境值 Pynq-Z2。
- PYNQ 2.5、Python 3.6.5、Linux 4.19.0-xilinx-v2019.1。
- FCLK0 實際讀值 100.0 MHz；RO IP 基底位址 0x43C00000。
- 部署版本：04_BOARD/ro_diag.bit；SHA256 c55e1175486feca247a9dc4984acb97bd399f9e4d32afedb2ab5254acaa90312。

## 實測

每組配對 32 次，共 8 組、256 筆；warmup 1024 cycles，window 100000 cycles（1 ms）。CSV 由板上 Notebook 產生後下載，並在本機重新核對筆數、狀態、差值與頻率換算。

全部 256 筆 status=OK，無零計數、無平手。每組的比較位元在這批 32 次樣本中一致率為 100%。這是短期量測結果，不能外推到重開機、溫度或長期誤碼率。

| Pair | 平均 A (MHz) | 平均 B (MHz) | 平均計數差 | 差值標準差 | 比較位元 | 一致率 |
|---:|---:|---:|---:|---:|---:|---:|
| 0 | 178.583 | 177.359 | 153.000 | 1.969 | 1 | 32/32 |
| 1 | 176.417 | 179.643 | -403.312 | 1.590 | 0 | 32/32 |
| 2 | 179.828 | 178.152 | 209.469 | 1.414 | 1 | 32/32 |
| 3 | 179.691 | 178.059 | 203.969 | 1.591 | 1 | 32/32 |
| 4 | 178.649 | 179.237 | -73.531 | 2.165 | 0 | 32/32 |
| 5 | 185.089 | 178.357 | 841.531 | 1.750 | 1 | 32/32 |
| 6 | 178.490 | 178.994 | -62.906 | 1.990 | 0 | 32/32 |
| 7 | 180.742 | 181.579 | -104.625 | 1.596 | 0 | 32/32 |

本批所有 A/B 頻率讀值範圍為 176.248–185.144 MHz，低於目前 500 MHz 的 RO 計數路徑設計假設。計數與差值的單位為除以 8 後的 ticks。

第一組另測三種量測時間，Notebook 的實際輸出如下：

| Window | Count A | Count B | A (MHz) | B (MHz) | 狀態 |
|---:|---:|---:|---:|---:|---|
| 0.1 ms | 2230 | 2215 | 178.400 | 177.200 | OK |
| 1 ms | 22294 | 22142 | 178.352 | 177.136 | OK |
| 10 ms | 223014 | 221487 | 178.411 | 177.190 | OK |

計數約隨 window 等比例增加，頻率估計大致一致。

## Vivado 檢查

- Setup WNS 0.053 ns、Hold WHS 0.067 ns、Pulse-width WPWS 0.500 ns，失敗端點均為 0。
- 16 組 Gray bus skew 最大實際值 2.015 ns，上限 8 ns，最小餘裕 5.985 ns；全部有有效數值，沒有 NA。
- CDC 無 Critical；32 項 CDC-9 Info 為同步重設。
- DRC 無 Error；RO 回授與內部 LUT 時脈有預期警告。Methodology 的 TIMING-2/4/14 各 16 項保留在報告，沒有全域關閉或降級。

## 紀錄位置與結束狀態

- 本地原始資料：[measurements.csv](sample_results/board_20100/measurements.csv)。
- 本機重新計算的摘要：[summary_recomputed.json](sample_results/board_20100/summary_recomputed.json)。
- 實板畫面：[jupyter_measurements.png](sample_results/board_20100/jupyter_measurements.png)。
- 伺服器已保存的完整執行 Notebook：[RO_Diagnostic.ipynb](http://140.113.201.80:20100/notebooks/ro_diag_a0981_20261106/RO_Diagnostic.ipynb)。
- 板上 results 目錄保留原始 CSV 與 JSON；檔名前綴為 20261106T020929_197403Z。板上時鐘與用戶端有差異，請勿據該檔名推算精確實際測試時間。
- Notebook 最後實際輸出 `All ROs disabled; result files retained.`，所有 RO 已停用，PL 保留 RO 診斷 overlay。

尚未進行重新上電、溫度／電壓、長時間與跨板唯一性測試；本實驗沒有接入 Bitmap、ECC、helper 或 SHA3，也沒有宣稱完成 PUF 金鑰系統。
