# 測試與波形

完整整合只需編譯 `sim/filelist_puf_axi_ro.f`、指定 top=TESTBED_PUF_AXI_RO；TESTBED_PUF_AXI_RO 實例化 PATTERN_PUF_AXI_RO。PATTERN_PUF_AXI_RO 發送 AXI 交易，ro_wave_model 產生波形，DUT 的真實 counter 計算 count。

## 完整整合 PATTERN_PUF_AXI_RO 的 phase

|phase|輸入動作|預期結果|
|---|---|---|
|1|AW 先到、W 先到、同時到；byte strobe、B/R 暫停與錯誤地址|合法讀寫正確；B/R 等待時保持；非法存取回 SLVERR|
|2|以診斷控制量測 pair 0..319，再量測非法 pair 320|320 組計數/位元正確、完成後 RO 關閉；非法 pair 回 raw BAD_PAIR|
|3|Registration；選 p%5!=0 的 256 組|key 與獨立參考模型相同，helper 與 syndrome 參考相同|
|4|缺 helper；command 3/0x100；255/257 組 bitmap；過短 window/warmup|分別回 MISSING_HELPER、BAD_COMMAND、BAD_BITMAP、BAD_WINDOW/BAD_WARMUP；key/helper 歸零|
|5|正常 Certification；再翻轉 pair 1 的頻率大小關係|正常重建；單 bit 可修正，corrected_words=1|
|6|同一 16-bit 區塊內翻轉 pair 1、2|ECC_UNCORRECTABLE，無 key 輸出|
|7|pair 1 兩側相同頻率；一側停振；兩側超快且量測長窗|分別回 WEAK_PAIR、RO_STOPPED、RO_SATURATED|
|8|運算中改 window，然後 ABORT；再 Certification|修改被拒絕；RO/core 共同重置，bitmap 保留；重建恢復|
|9|運算中全域 reset；再從外部載入原 bitmap/helper|內部配置、key 與序號清零；不重新 Registration 也可重建|

每次 PUF 交易還會檢查序號只增加一次、command 標記、status/error、key/helper valid、整份結果保持不變，以及持有結果時拒絕新 START/配置寫入；最後 CONSUME 才回 ready。

人工 count 核心測試另包含：5 次多數決、每個區塊各 1-bit 修正、2-bit 偵測、3-bit 誤修正限制、helper 改動、後端不接受請求、接受但不回結果、超時後必須共同 reset。ECC 獨立測試共有 4 個無錯誤、64 個單錯誤、480 個雙錯誤案例。

## 建議加到 nWave 的信號

1. `pattern.phase`、`clk`、`reset_n`：辨識測試階段；reset_n=0 是硬體重置。
2. `dut.dev_start`、`dut.command_value`、`dut.dev_ready/dev_busy/dev_done`：一次 START 對應一筆交易。外部 AXI CTRL START 會轉成單拍 dev_start。
3. `dut.measure_req/measure_ready/measure_valid`、`dut.pair_index`：req&&ready 才接受一筆量測；稍後 valid 表示 count 與 measure_status 可讀。
4. `dut.u_measure.state`、`ro_enable`、`selected_ro_a/b`、`dut.count_a/count_b`：先 WARMUP 再 MEASURE；計數的是 /8 後的 ticks，並非每個原始 RO edge。
5. `dut.u_device.sampler.sample_index/ones/selected`：每組 5 次投票；selected 是已完成的 PUF bit 數。
6. `dut.dev_valid/key_valid/helper_valid/key_data/helper_out/corrected_words/status_code/error`：只有 valid 時才解讀結果。Registration 的 helper_valid=1；Certification 的 helper_valid=0。

`status_code`、`command_value`、`error` 使用 typedef enum；支援的波形工具可顯示 enum 名稱。若 VCD 檢視器沒有保留 enum 型別，把 TESTBED_PUF_AXI_RO 的 `status_text/command_text/error_text` 設為 ASCII radix。`pattern.gold_key/gold_helper` 是獨立參考答案，`got_key/got_helper` 是從 AXI 讀回值；`flip_mask/tie_mask/stop_mask/fast_mask` 是模擬故障開關，不是 FPGA port。

一次 START 被接受後，先做 device 與 core 各 320 cycles 的 CHECK_BITMAP，100 MHz 下合計約 6.4 µs。這段時間 busy=1、RO 尚未啟用是正常的，不需再送第二次 START。請把波形時間範圍拉到 µs/ms，或以 measure_req/result_valid 找事件。

CORE COUNT 與 ECC 的 top 分別為 TESTBED_PUF_CORE_COUNT、TESTBED_PUF_ECC_SECDED，不要把三個 top 同時當作一個模擬入口。
