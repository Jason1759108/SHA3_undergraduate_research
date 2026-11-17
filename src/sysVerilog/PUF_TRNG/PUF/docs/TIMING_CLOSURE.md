# PUF256 時序收斂紀錄

第一次完整整合的功能模擬通過，但 Vivado 布局後出現 setup violation。關鍵路徑由 bitmap 暫存器經 320-bit `$countones`、數量比較、狀態/錯誤判斷到 done/state 暫存器；device 與 core 都有相同問題。最差路徑 14 層邏輯、data-path delay 12.016 ns，setup slack -2.249 ns。

修正方式是在兩層各加入 CHECK_BITMAP，鎖存輸入後逐位累加，完成 320 cycles 才比較選中數量。core 的 cursor 也改成符合候選數量的位寬。開始量測前增加約 640 cycles（100 MHz 下約 6.4 µs）；錯誤 bitmap 仍在任何 RO 請求前拒絕，command/bitmap/helper 的交易規則維持一致。功能測試再度通過。

|項目|第一次布局|修正後布局 / 最終繞線|
|---|---|---|
|布局 setup slack|最差報告 -2.249 ns|估計 +0.576 ns|
|LUT|21010|19958（37.52%）|
|Registers|49620|49629（46.64%）|
|最終 routed WNS|未部署|+0.145 ns，0 failing endpoints|
|最終 routed WHS|未部署|+0.061 ns，0 failing endpoints|
|最終 pulse-width slack|未部署|+0.500 ns，0 failing endpoints|
|Gray bus skew|未部署|640 組，最大3.323 ns；8 ns限制，最小裕量4.677 ns|

沒有降低 100 MHz 系統時脈、放寬 RO 2 ns 工程時序假設或 Gray CDC 8 ns 限制；沒有以 asynchronous clock groups 蓋掉 Gray bus 的約束。沒有 critical CDC、severe DRC、missing clock 或 unconstrained internal endpoint。

## Methodology：完成不等於零警告

234 項規則均已啟用並完成；沒有非預期 finding。保留以下 vendor severity：

|Rule|Severity|Count|內容|
|---|---|---|---|
|TIMING-2|Critical Warning|640|RO 內部 LUT 上定義 primary clock|
|TIMING-4|Critical Warning|640|RO 回授時脈樹的 primary-clock redefinition|
|TIMING-14|Critical Warning|640|RO 時脈路徑包含 LUT|
|TIMING-23|Warning|640|RO 的組合回授環|
|LUTAR-1|Warning|1|共同 abort/reset 邏輯驅動非同步 reset|
|ULMTCS-2|Warning|1|每 RO 獨立計數器造成較多 control sets|
|XDCB-1|Warning|1|大量時序 exceptions 的執行時間提醒|

Windows Vivado 2026.1 的 Timing methodology 使用先前 RO320 階段已診斷的分析替代流程：只在新開啟的唯讀 checkpoint 分析程序，於 open_checkpoint 前設定內部參數 `sta.enableClockUncertainty=false`。本次另以原始 default 設定收集 94503 筆 max、84263 筆 min 紀錄，共178766筆；比較所有端點、user XDC 與規則啟用情況，確認沒有放寬端點。640筆 RO feedback hold budget 多出35ps保守預算，因此是 conservative，並非完全 equivalent。此參數未用於合成、布局、繞線或 bitstream 產生。57項 Timing 規則的 vendor call 本次耗時50秒，連同比對所需的紀錄收集另計。

實際原始資料位於 docs/results/single_board/vivado；methodology_status.json、methodology_runtime/conservative_validation.json 與各規則報告記錄詳細結果。final_routed.dcp 是產生此 bitstream 的實際 checkpoint，SHA256：

```text
ed2a6e0a4f76d4fe61824b9ae4fd1baaeff36afb9be6b8c1fe6331d55e1bb4dd
```

功能模擬不能偵測這類實作時序問題。之後修改 RTL，仍需重跑目標 FPGA 的 synthesis/implementation、正式報告檢查與 source-snapshot 核對。重新繞線可能改變 RO 指紋，不能直接沿用此次 bitmap/helper。
