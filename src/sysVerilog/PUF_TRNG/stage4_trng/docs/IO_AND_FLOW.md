# 介面與控制流程

此版本已自動完成接線；此表供組員理解與檢查，不需要重新手接。

| 起點 | 終點 | 用途 |
|---|---|---|
| PS M_AXI_GP0 | axi_control S00_AXI | 處理器存取控制暫存器 |
| axi_control M00_AXI | sha3/sha3_dma S_AXI_LITE | DMA 控制，位址 0x40400000、範圍 64 KiB |
| axi_control M01_AXI | entropy_ip s_axi | 熵源控制及 RAM，位址 0x43C00000、範圍 64 KiB |
| DMA M_AXIS_MM2S | sha3_ip S_AXIS | 訊息送入 SHA3；32-bit 資料、握手、最後一拍標誌 |
| sha3_ip M_AXIS | DMA S_AXIS_S2MM | 一個狀態字加八個摘要字，總共 36 bytes |
| DMA M_AXI_MM2S / M_AXI_S2MM | axi_memory S00 / S01 | 從 DDR 讀訊息、寫回摘要 |
| axi_memory M00_AXI | PS S_AXI_HP0 | FPGA 存取 PS 主記憶體的通道 |
| PS FCLK_CLK0 | 全部 AXI、SHA3、熵源與 reset 時脈 | 同一個 25 MHz 控制時脈 |
| PS FCLK_RESET0_N | rst_ps7_0_25M ext_reset_in | 低有效外部重設 |
| constant_one | aux_reset_in、dcm_locked | 低有效輔助重設保持未觸發、時脈鎖定條件成立 |
| constant_zero | mb_debug_sys_rst | 關閉除錯重設要求 |
| peripheral_aresetn | 熵源、SHA3、DMA reset | 同步解除的低有效周邊重設 |
| interconnect_aresetn | 兩組 AXI Interconnect reset | 匯流排重設 |

AXI 是處理器與周邊的匯流排規格；AXI Stream 是連續資料介面。MM2S 表示記憶體到串流；S2MM 表示串流到記憶體。`_n` 通常表示 0 才觸發，接錯會讓電路一直停在重設。

健康來源沿用 ROH2 介面：0x00 控制（1 開始、2 中止、4 清狀態）、0x04 狀態、0x08 樣本數、0x10 divider、0x14 ID=0x524F4832、0x20 RO enable、0x30/34/38 故障遮罩、0x40 observed、0x4C startup_seen、0x1000..0x1FFC 樣本 RAM。每個 32-bit 字低八位是同一個時刻的八路取樣，高位必須為零。

RCT 是重複次數檢查：單路連續相同值達 41 次就失敗。APT 是比例檢查：以每個 1024 樣本視窗的第一個值為參考符號，出現次數達 793 就失敗。兩者跨啟動與保留資料持續監測；不是完整的不可預測性證明。來源使用的 0.5 bits/單路門檻設計假設仍非已驗證的熵下界。

每批先暖機 1024 個時脈週期，再丟棄 1024 個啟動樣本，成功後才保留 1024 個樣本。預設 divider=512：每隔 512 個 25 MHz 週期取一次八路資料。預設整段取樣約 42 ms，不含 Python 搬運與 SHA3 時間；中止、故障或完成都關閉 RO。硬體另有 20,000,000-cycle 看門狗，避免來源無限工作。

每 136 bytes 封成一塊：一個 32-bit header（低八位長度，bit8 表示最後一塊），再接 34 個 little-endian 資料字，不足補零。1024-byte raw 批次封成 8 塊、280 個字。FPGA SHA3 使用標準 SHA3-256 domain/padding，預期回覆狀態字 0x53480000，再接 32-byte digest。回覆錯誤或長度不是 36 bytes 都不交付結果。

保護由正常應用程式與熵源 RAM 存取控制共同構成；它不防止有權限的其他程式覆寫電路或直接操作 DMA。板上應維持單一使用者、單一 Session。

SHA3 保留 `FT_ENABLE=1` 的 parity/replay（奇偶檢查／重做修復）核心。正式上板版本的錯誤注入輸入維持關閉，沒有新增讓使用者注入故障的 AXI 暫存器，也未匯出修復次數。因此這次的實板驗收能確認正常資料計算與端到端比對；153 次故障修復證據來自 RTL 模擬，不能說已在真實 FPGA 上做了同樣的物理故障注入。
