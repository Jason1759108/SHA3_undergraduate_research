# 接線與暫存器

## 外部介面

頂層仍是 `entropy_axi`；新增健康監測是內部電路，不需另外拉出線。

| 介面/訊號 | 方向（對自訂 IP） | 連到哪裡 | 意義 |
|---|---|---|---|
| s_axi | slave | axi_control/M00_AXI | 處理器的控制與 RAM 讀取介面 |
| s_axi_aclk | input | processing_system7_0/FCLK_CLK0 | 25 MHz 控制時脈 |
| s_axi_aresetn | input | rst_ps7_0_25M/peripheral_aresetn | 低有效重設，0 時重設 |

AXI 介面展開後的 AW 是寫地址、W 是寫資料、B 是寫回應、AR 是讀地址、R 是讀資料。VALID 表示提供者有資料，READY 表示接收者能接收。接粗的 s_axi 介面線即可，不要逐一手拉所有 AXI 訊號。

## 實際系統接線清單

| 起點 | 終點 |
|---|---|
| processing_system7_0/M_AXI_GP0 | axi_control/S00_AXI |
| axi_control/M00_AXI | entropy_ip/s_axi |
| processing_system7_0/FCLK_CLK0 | processing_system7_0/M_AXI_GP0_ACLK |
| 同上 | axi_control/ACLK、S00_ACLK、M00_ACLK |
| 同上 | entropy_ip/s_axi_aclk、rst_ps7_0_25M/slowest_sync_clk |
| processing_system7_0/FCLK_RESET0_N | rst_ps7_0_25M/ext_reset_in |
| constant_one/dout | rst_ps7_0_25M/aux_reset_in、dcm_locked |
| constant_zero/dout | rst_ps7_0_25M/mb_debug_sys_rst |
| rst_ps7_0_25M/interconnect_aresetn | axi_control/ARESETN、S00_ARESETN、M00_ARESETN |
| rst_ps7_0_25M/peripheral_aresetn | entropy_ip/s_axi_aresetn |

constant_one 是 1-bit 數值 1；constant_zero 是 1-bit 數值 0。ext/aux reset 都是低有效，未使用的 aux 接 1；不能接 0。dcm_locked 接 1 表示使用的來源時脈可用，debug reset 接 0。

## 位址與狀態

基底位址 `0x43C00000`，範圍 64K。以下為相對位移。除了 CONTROL/DIVIDER，其餘暫存器唯讀；未對齊或無效位址回 SLVERR（存取錯誤），不使 AXI 等待無限延長。

| 位移 | 名稱 | 定義 |
|---:|---|---|
| 0x00 | CONTROL | 寫 1 START、2 ABORT、4 CLEAR；故障後需明確 CLEAR |
| 0x04 | STATUS | bit0 busy、1 done、2 alarm、3 aborted、4 watchdog、5 startup_active、6 startup_ok、7 batch_valid |
| 0x08 | COUNT | payload 已寫入數，故障時只是診斷，不表示 RAM 可讀 |
| 0x0C | CAPACITY | 1024 |
| 0x10 | DIVIDER | 預設 512，允許 16..4096；完整 16-bit 設定，忙碌中拒絕修改 |
| 0x14 | ID | 0x524F4832，ASCII ROH2 |
| 0x18 | VERSION | 0x00020000 |
| 0x20 | RO_ENABLE | 0/1；完成、故障、中止、reset 後應為 0 |
| 0x24 | WARMUP | 1024 控制時脈週期 |
| 0x28 | RCT_C | 41 |
| 0x2C | WATCHDOG | 20000000 控制時脈週期 |
| 0x30 | FAULT_MASK | RCT/APT 通道遮罩 OR，bit k 對應 RO k |
| 0x34 | RCT_MASK | 每路重複檢測失敗紀錄 |
| 0x38 | APT_MASK | 每路比例檢測失敗紀錄 |
| 0x3C | STARTUP_SAMPLES | 1024 |
| 0x40 | OBSERVED | 實際監測點數，成功應為 2048 |
| 0x44 | APT_WINDOW | 1024 |
| 0x48 | APT_C | 793 |
| 0x4C | STARTUP_SEEN | 已通過的啟動樣本數，成功為 1024 |
| 0x1000..0x1FFC | SAMPLE_RAM | 每字低 8 bits 為八路原始 payload，其餘 24 bits 為 0 |

正常完成 STATUS=194=0xC2：done、startup_ok、batch_valid。這與舊版正常 STATUS=2 不同，必須使用新版驅動。

RAM 只有 batch_valid=1 才可讀，啟動中、忙碌中、故障後、abort 後、reset 後均拒絕。沒有對外熵有效訊號或 AXI Stream；目前的 batch_valid 只代表整批通過本版健康監測，不能解讀為密碼學熵認證。
