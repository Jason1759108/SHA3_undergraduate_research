# 本次離線結果：2026-11-16

後續更新：本版本已收到並核對實板資料，功能整合驗收與本次新布局有限熵評估通過，詳 [實板分析報告](../captures/board_21600/integrated_20261116/REVIEW.md)。以下保留發布前的離線紀錄，其中 PENDING 表示當時尚未收到實板資料；配對發布檔不因後續分析而修改。

已完成發布前檢查，配對包位於 `delivery/trng_integrated_ready.zip`。實板驗收與新布局熵估計仍為 **PENDING**，沒有把模擬的輸出當成實板結果。

| 檢查 | 結果 |
|---|---|
| 凍結 RTL | 19 檔；來源、IP repo、工程實際產生的 ipshared 複本均相符 |
| SHA3 原本正常 testbed | 18 案例通過 |
| SHA3 parity/replay | 153 個故障模擬案例通過 |
| SHA3 AXI | 34 個標準向量、2 次恢復比對與 3 種錯誤封包回覆通過；含背壓／中途重設 |
| 健康來源控制器 unit | 通過 |
| 實際整合 BD 系統模擬 | 36 次 SHA3 比對，另 2 次完整來源 RAM→DMA→SHA3→HP0 摘要比對；健康故障、中止、拒讀與重設恢復通過 |
| PYNQ 2.5 軟體相容性／故障分支 | 原版解析器與 DMA 程式；41 個應拒絕情境通過；完整 Notebook 及 1000 批匯出在模擬硬體上通過 |
| bitstream | write_bitstream Complete |
| 時脈 | 控制／AXI／SHA3 共同 25 MHz |
| 設定時間 WNS | +3.442 ns，沒有 setup 失敗端點 |
| 保持時間 WHS | +0.031 ns，沒有 hold 失敗端點 |
| LUT | 14035／53200，26.38% |
| 暫存器 | 10465／106400，9.84% |
| Block RAM / DSP | 2 個 BRAM tile／0 DSP |
| 實體 RO | 8 個 NAND LUT2、88 個反相 LUT1，各環長度正確 |
| 同步器 | 16 個 FF，ASYNC_REG 屬性正確 |
| 發布 | 六個不可變檔案指紋、HWH 與模擬相符、八檔 ZIP 內容核對通過 |

## 警告沒有刪除或降低等級

DRC 沒有 Error 或 Critical Warning，但不是零 Warning：

| 項目 | 數量 | 本次檢視 |
|---|---:|---|
| LUTLP-2 組合迴路 | 8 | 只在 entropy_ip 的八路 RO；這些迴路就是振盪器，逐環實體結構另行核對 |
| PDCN-1569 LUT 未使用接腳 | 3 | 廠商 axi_memory 協定轉換 FIFO；與上次已上板 SHA3 報告同類同數，已全新產生 IP／合成，未手改網表 |
| REQP-1839 RAM 非同步控制 | 8 | 廠商 DMA FIFO 與 axi_memory 控制；與上次 SHA3 同類同數。重新設定前先停 DMA；復原後重新驗證，不能假設中途重設仍保留有效資料 |
| RTSTAT-10 無可繞線負載 | 1 組 | 廠商 axi_memory FIFO 的 33 條無負載內部線；與上次 SHA3 同類同數 |
| REQP-181 WRITE_FIRST | 2 advisory | 廠商 DMA 的兩個 FIFO BRAM；保留其標準控制與模擬，不改記憶體模式來隱藏提醒 |

Methodology 報告另有 4 個廠商 axi_memory FIFO 的 LUTAR-1 非同步 reset 提醒、8 個對應 RO 的 TIMING-23，以及 1 個 XDC 搜尋效率提醒。警告與完整原始報告保留於 `build/reports/trng_integrated/`，整理紀錄為 `build/warning_review.json`。發布檢查會核對警告種類、數量及 DRC 指向的模組，出現新類型／數量時不沿用這次的結論。

這些查核表示沒有發現新增而未檢視的警告，不表示已排除所有實體毛刺／重設時序風險。此次實板操作採固定流程：先確認初始狀態、比對已知訊息、比對每個 raw 批次的摘要、錯誤就停，安全停止後才允許重新設定。

## 下一步只需要使用者上板操作

解壓八檔 → 上傳到新資料夾 → 開 `TRNG_Integrated_Bringup.ipynb` → 填板號與實際日期 → 逐格執行 → 下載 16 批 ZIP、1000 批 ZIP 與已執行 Notebook。

取得新 raw 後，才能說明這個整合布局的原始來源品質。此前的 6.638383 bits／八路樣本屬於 stage3，不是這次的保證；輸出 32 bytes 也不是已證明有 256 bits 真實熵。
