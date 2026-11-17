# 320 組 RO 實板篩選與固定 256 組驗證

2026-11-12，PYNQ-Z2（Jupyter port 20100）。**432,640 筆量測完成；固定 256 組的獨立重載驗證 PASS，本機獨立驗算 PASS。**

本實驗為獨立 RO 診斷，不引用原 SHA3／PUF 系統，輸出是原始 RO 比較候選。

| 階段 | 讀取安排 | 筆數 | 結果 |
|---|---|---:|---|
| 初始參考 | 每組 32 次 | 10,240 | 308/320 組全部有效且一致 |
| 篩選 | 每組 1000 次 | 320,000 | 302/320 組符合條件 |
| 凍結 | 依最小正規化差值排序選 256 組 | — | 在任何 holdout 前保存 bitmap、參考值及 CSV prefix SHA256 |
| 獨立重載驗證 | 同一 bitstream 重載 10 回合，每回合每組 32 次 | 102,400 | 固定 256 組 PASS，不重新選配對 |

固定 256 組共 **81,920 次位元讀取：0 翻轉、0 相等、0 硬體錯誤**。10 回合 × 32 個重建向量，共 **320 個 256-bit 向量全部與凍結參考一致**。全部 432,640 筆硬體 status fault 為 0，結束後已 ABORT 關閉所有 RO。

量測 window=100000 cycles（1 ms）、warmup=1024 cycles、系統 FCLK0=100 MHz、每個 RO /8、16-bit 飽和計數。頻率範圍 **157.504–188.288 MHz**，低於建置使用的 500 MHz 上界假設。實際量測耗時 835.004 秒（約 13 分 55 秒）。

## 固定選擇及資料順序

320-bit bitmap，bit p 選 pair p（pair p 使用 RO 2p、2p+1）：

```
fbfedffdd96ffffdbf7bbf7eb7eedfdebefffe7ff5b7bb1f7be7fbfdbff7effb3efd5fdd61cfdebf
```

位元向量按照 selected_pairs 遞增：第 j 組放候選 bit j。完整 selected_pairs、40-byte little-endian bitmap、參考候選在 `sample_results/board_20261112/data/selection.json`。本階段介面為獨立的 320-bit bitmap。

選定配對在篩選資料中的最小正規化差值為 **712.666 ppm**，最小絕對差值為 **33 ticks**。參考候選包含 106 個 1、150 個 0；這些單板數據不能用來宣稱有 256-bit 熵。

## 保留未選配對的問題

| 資料 | 硬體 fault | A=B 次數 | 翻轉次數（有參考值者） |
|---|---:|---:|---:|
| 初始參考 | 0 | 159 | — |
| 篩選 | 0 | 4,715 | 3,716 |
| 全部 320 組 holdout | 0 | 1,373 | 1,073 |
| 固定 256 組 holdout | 0 | 0 | 0 |

Pair 133、142、153、155 沒有可定義的初始參考位元，其 flips 為 null，未列入翻轉總數；不能把 null 當成 0 次翻轉。

篩選不合格的 18 組：6、25、26、33、37、62、66、133、142、153、155、167、205、222、231、238、285、289。另外 46 組雖合格，但排名未進前 256。未選配對在 holdout 中的問題沒有被刪除、補值或用來更換選定配對。逐組數據見 summary.json 與 analysis_metrics.json。

## 獨立驗算與證據

完整 ZIP 的 bytes、SHA256、CRC 及七個平面檔名均已核對。驗證器重新讀取全部 CSV，使用獨立的整數統計與 Fraction 排序核對初始參考、training-only 排名、bitmap、凍結時序、CSV prefix hash、每次重載的 sequence／參數、320 個向量及最終判定。

- 本機驗證：`data/verification.json`，verified=true。
- 原始 CSV SHA256：`5182a356f5b45e2efcb7ef033f8d1a77bf6ebe43a0893bfeabc360c4bfdbe3d0`。
- 板端 ZIP SHA256：`2190b16d4319d8588493c940f68eaad98a51e894f8b94a0566cd21706f67c49d`。
- 原始 ZIP：`sample_results/board_20261112/raw_board_bundle.zip`。
- 圖表：`sample_results/board_20261112/data/characterization.png`。
- Notebook 畫面：`sample_results/board_20261112/notebook_pass.png`。
- 已保存的 Notebook：[RO320_Diagnostic](http://140.113.201.80:20100/notebooks/ro320_diag_a0981_20261112/RO320_Diagnostic.ipynb)。

板端時鐘與本機日期不一致，板端目錄沿用實際生成的時間戳；實驗耗時、列順序與凍結時間使用 monotonic time，並已核對。

## 結論的範圍

此結果支持這塊板、這份固定 bitstream、這次環境下，事先凍結的 256 組可重複讀取並通過 10 次 PL 重載。尚未測試完全斷電重開、溫度／電壓範圍、跨板唯一性及長期老化，也未驗證熵、ECC 或 SHA3 擷取。

正式 routed timing / CDC / DRC / bus-skew 已通過。2026-11-13 另外完成 234/234 methodology 規則，保留刻意 LUT RO 的原始警告，分析繞法經完整端點保守性驗證，詳見 BUILD_RESULTS.md。這次補做檢查沒有更動已上板的 bitstream 或本次量測資料，也不代表完整密碼學金鑰系統通過。
