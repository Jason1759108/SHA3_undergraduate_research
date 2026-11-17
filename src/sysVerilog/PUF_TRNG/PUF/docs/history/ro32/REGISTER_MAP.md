# AXI4-Lite 暫存器

基底位址由 HWH 取得，建置腳本指定 `0x43C00000`，範圍 4 KiB。所有 offset 為 byte offset，32-bit 存取、4-byte 對齊。未定義位址、未對齊存取與寫入唯讀暫存器回傳 AXI `SLVERR`。寫入支援 WSTRB。

| Offset | 名稱 | 權限 | 說明 |
|---|---|---|---|
| 0x00 | ID | R | 0x524F4431，ASCII ROD1 |
| 0x04 | VERSION | R | 0x00010000，register-map v1.0 |
| 0x08 | CONTROL | W/R0 | bit0 START、bit1 CLEAR_FLAGS、bit2 ABORT；寫 1 動作，讀回 0 |
| 0x0C | FLAGS | R | bit0 BUSY、bit1 DONE、bit2 START_REJECTED |
| 0x10 | PAIR_CFG | RW | 配對 0..31，預設 0 |
| 0x14 | WINDOW_CFG | RW | 16..1000000 個系統 cycles，預設 100000 |
| 0x18 | WARMUP_CFG | RW | 64..1000000 個系統 cycles，預設 1024 |
| 0x1C | COUNT_A | R | 24-bit 除頻後 ticks，零擴展到 32-bit |
| 0x20 | COUNT_B | R | 同上 |
| 0x24 | DIFF | R | COUNT_A - COUNT_B，32-bit 二補數 |
| 0x28 | STATUS | R | 0 OK、1 BAD_PAIR、2 BAD_WINDOW、3 BAD_WARMUP、4 ZERO_COUNT |
| 0x2C | SEQUENCE | R | 每完成一筆（含參數錯誤）+1，32-bit wrap；ABORT 不增加 |
| 0x30 | RESULT_PAIR | R | 該次量測鎖定的配對 |
| 0x34 | RESULT_WINDOW | R | 該次量測鎖定的 window |
| 0x38 | RESULT_WARMUP | R | 該次量測鎖定的 warmup |
| 0x3C | CLOCK_HZ | R | 100000000，系統時脈設計值 |
| 0x40 | PAIRS | R | 32 |
| 0x44 | DIVISOR | R | 8 |
| 0x48 | COUNTER_BITS | R | 24 |

START 會鎖定三個 CFG，清除 DONE，並開始操作。運行中修改 CFG 只影響下次操作。運行中再次 START 只設 START_REJECTED，不打斷原量測或覆寫原參數。DONE 與 START_REJECTED 都是 sticky，軟體不會因輪詢太慢而漏接完成脈波。

完成後結果保持到下一次 START 或重設。只在 DONE=1 且 SEQUENCE 確認更新後讀取結果。錯誤時不能把 count 當成有效 PUF 資料。

CLEAR_FLAGS 清除 DONE 與 START_REJECTED，保持結果及當前量測。ABORT 優先於其他控制位元，取消當前量測、停掉所有 RO、清除結果與旗標，保留 CFG 與 SEQUENCE。外部 `s_axi_aresetn=0` 則連 CFG、SEQUENCE 也回到預設。這些控制命令屬於**獨立量測工具**，與原 PUF 的 Registration/Certification command 無關。

硬體與軟體限單一控制者。不可同時從兩份 Notebook 操作同一個 IP。
