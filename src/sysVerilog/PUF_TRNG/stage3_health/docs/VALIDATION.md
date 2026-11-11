# 第三階段本機驗證紀錄（2026-11-11）

清理更新：完整 Vivado/模擬工作目錄已移除。已核對發布檔、PASS 摘要與精選日誌仍保留；原文工作路徑屬歷史紀錄，不能假設舊工程仍可直接開啟。完整系統最終輸出另保存在 build/results，重新建置需從現行來源產生。

**後續實板紀錄：** 使用者已回傳本版 16 批功能驗收及 1000 批資料。完整性與健康狀態核對通過，9 組非 IID 估計完成、9 組 RO 重啟評估通過，聯合資料保留估計約 6.638383 bits/樣本。見 [實板分析報告](../captures/board_21600/health_20261111/REVIEW.md)。以下保留的是上板前的本機測試紀錄；實板由使用者操作，沒有實板故障注入或正式熵信用聲明。

本次未連線或操作實驗室板子。已完成獨立健康監測參考版本的本機測試、綜合、實作、bitstream 與發布；新版本的物理熵及正常實板驗收仍待操作者執行。

## 實際完成

| 檢查 | 結果與範圍 |
|---|---|
| Monitor 逐樣本對照 | PASS；小參數 3171、預設參數 7559，共 10730 個事件；與 Python 模型核對目前樣本失敗及 sticky masks |
| 門檻計算/基準重播 | PASS；RCT 41、APT 793/1024 的推導及相鄰尾機率；舊版 1000 批重播未觸發，不當作新硬體量測 |
| 控制器 XSim | PASS；AW/W 次序、回應等待、startup 丟棄、完整 RAM、RCT/APT、跨階段 RCT、最後 payload 點失敗、故障鎖存/清除、abort/watchdog/reset/恢復 |
| 實際 BD 系統 XSim | PASS；PS GP0、reset、完整 1024 RAM 比對、啟動 RCT/APT、運行故障、最後樣本失效與恢復；非只測孤立控制器 |
| Host/PYNQ | PASS；原始 PYNQ 2.5 parser、HWH 與 immutable 檔校驗、錯誤 reset/clock 拒絕、batch_valid/startup/count/mask 檢查、失效資料不讀 RAM、timeout abort、明確清故障與恢復 |
| 收集/匯出/notebook | 13 項 PASS、0 skip；以假硬體執行 notebook 實際功能/1000 批/匯出/ZIP 格，並驗證停止、中斷、竄改、關閉失敗、參數界線 |
| Python 相容性 | 板端程式及 notebook 程式格檢查 Python 3.6 語法；沒有以本機 Python 版本代替實板版本測試的聲明 |
| FPGA 實作 | write_bitstream Complete；RO 拓撲、INIT、16 個 ASYNC_REG 同步器、約束與接線核對通過 |
| 發布配對 | 六個不可變檔案 SHA-256、HWH 對應系統模擬、IP 複本 RTL 與測試來源指紋核對通過；notebook 可保存輸出 |

所有 PASS 來源指紋見 build/*_pass.json，總結見 build/final_validation.json；manifest 內也保留本次各項檢查。修改來源或 BD 後必須重跑受影響項目。

## 實作結果

- 25 MHz，WNS=26.982 ns、WHS=0.028 ns，皆非負。
- Slice LUTs=1213，DFF=1011，BRAM=0，DSP=0。
- 8 個 NAND LUT2、88 個反相 LUT1、16 個同步器 DFF 確認存在。
- DRC：0 Error、0 Critical Warning；8 個 LUTLP-2 已允許 RO 組合迴圈警告。
- Methodology：8 個 TIMING-23 RO timing-loop 警告，1 個 XDCB-5 物件搜尋效率警告。
- CDC 報告沒有列出路徑，不解讀為 RO 非同步風險全部通過。RO 無標準來源時脈，亞穩態與物理熵不能靠此報告或數位模擬證明。

報告位於 build/reports/entropy_ref。同步控制路徑時序通過，不等於對刻意形成的 RO 迴圈作傳統同步時序保證。

## 已測與未測的邊界

系統模擬對內部樣本作可重現的 force，以核對控制與健康演算法；RTL 的模擬 RO 是確定性模型。這些刺激都不是物理熵。綜合後的實體 LUT 與同步器另行核對，仍不能取代上板量測。

目前沒有實板故障注入控制腳位，沒有執行任意供電或接線故障。故障處理的本機證據與正常實板驗收要分開報告。沒有接入 SHA3，也沒有給每批資料分配正式熵信用。新實作不能直接繼承第二階段約 6.65 bits/聯合樣本的估計。

最長 divider 4096 的暖機+啟動+payload 取樣約 0.3356 秒，低於 0.8 秒 watchdog。正常 MMIO 仍回應時軟體逾時/abort 有界；失聯時不能保證由 Python 自行復原。

第二階段已發布八路來源的檔案逐一比對保持原樣。

## 發布識別

- build_id：`entropy-health-20261110T172050Z`
- bit SHA-256：`05c49d956ebfc470eccab7b8893ef19d8341d0f1f23d829b0ff1822ec1e4c9d3`
- HWH SHA-256：`4dc8494486efe3b6016c22cc397de805f95cae5afaa659ec0b2f639454c17838`
