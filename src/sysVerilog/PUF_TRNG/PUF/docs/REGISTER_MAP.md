# AXI4-Lite register map v1.0

Base 0x43C00000；32-bit little-word，4-byte aligned，4 KiB。RW 支援 WSTRB；非法地址、RO 寫入或 active 時修改配置回 SLVERR。WSTRB=0 不改資料。僅允許一個控制程式。

AXI ID/version 只辨識 overlay 暫存器規格，不是裝置身分認證，也不會參與 PUF 密鑰計算。

|Offset|R/W|內容|
|---|---|---|
|000|R|ID=0x50554631 (PUF1)|
|004|R|Version=0x00010000|
|008|W|CTRL；讀回 0|
|00C|R|FLAGS|
|010|RW|Command：0 Registration、1 Certification；其他值 BAD_COMMAND|
|014|RW|window cycles；有效 16..100000，reset=100000|
|018|RW|warmup cycles；有效 64..1000000，reset=1024|
|01C|R|status[7:0]、error[8]|
|020|R|corrected_words[15:0]，成功 Certification 修正的區塊數|
|024|R|PUF completion sequence，32-bit wraparound|
|028|R|result command，鎖存原始 32-bit 請求值|
|02C|R|目前核心 pair index[8:0]；僅供觀察|
|030|RW|helper input valid[0]；全零 helper 也是有效資料|
|034|R|Clock Hz=100000000|
|038|R|Candidate pairs=320|
|03C|R|PUF bits=256|
|040|R|Helper bits=80|
|044|R|Repeats=5|
|048|R|Minimum count margin=8|
|04C|R|Backend timeout cycles=1100128|
|100..124|RW|bitmap 10 words：offset100 對應 bits31:0，124 對應319:288|
|140..148|RW|helper input 3 words；148 只有低16有效|
|180..19C|R|key data 8 words，低 word 先|
|1C0..1C8|R|helper output 3 words；1C8 高16為0|
|200|RW|raw diagnostic pair；有效0..319|
|204 / 208|R|raw count A / B（/8 ticks）|
|20C|R|raw status（與 PUF status 不同編碼，見下方）|
|210|R|raw completion sequence|
|214 / 218 / 21C|R|raw result pair / window / warmup|

## CTRL 與 FLAGS

CTRL low nibble 一次最多一個動作：bit0 START、bit1 CONSUME、bit2 ABORT、bit3 RAW_START。bit4 CLEAR_REJECT 可與其中一項合併；bits31:5 保留。多個動作同時設定回 SLVERR。需 WSTRB[0]=1。

START/RAW_START 僅 ready 時接受，否則設定 sticky rejected；不破壞現有結果。CONSUME 只在 result_valid 時接受。ABORT 同時重置 PUF 核心和 RO 後端、清除輸出/診斷完成/拒絕旗標，保留配置與完成序號。全域 AXI reset / PL reload 另會清除配置與序號。

FLAGS：bit0 ready、bit1 busy、bit2 result_valid、bit3 key_valid、bit4 helper_valid、bit5 rejected、bit6 locked、bit7 raw_active、bit8 raw_done，其餘0。

流程：寫配置 → 記錄 completion sequence → CTRL=17（clear reject+start）→ 等待 result_valid 且序號+1 → 讀整個 packet → CTRL=2 consume → 等 ready。資料在 CONSUME 後仍可保留，但 valid 已無效；下一次 START 或 reset 清除。超時結果 consume 後會 locked，必須 ABORT/全域 reset 才能重新開始。

raw 診斷：寫 pair/window/warmup → CTRL=24 → 等 raw_done 且 raw sequence+1 → 讀204..21C。raw_done 為 sticky，下次 raw/PUF START 清除；raw 結果在下一次 raw 完成或 ABORT 前保持。量測頻率約為 count×8×100MHz/window；不是精密頻率校正。

## PUF status enum

|值|名稱|意義|
|---|---|---|
|0|PUF_OK|成功|
|1|PUF_BAD_COMMAND|command 不是0/1|
|2|PUF_MEASURE_TIMEOUT|後端握手或結果等待超時；需共同reset|
|4|PUF_WEAK_PAIR|同頻/任一次 count 差小於8|
|5|PUF_ECC_UNCORRECTABLE|至少一個區塊的 syndrome 顯示不可修正|
|6|PUF_MISSING_HELPER|Certification 未宣告helper有效|
|7|PUF_BAD_BITMAP|選中數量不等於256|
|8|PUF_BAD_WINDOW|量測時間窗超出範圍|
|9|PUF_BAD_WARMUP|暖機時間超出範圍|
|10|PUF_RO_STOPPED|量測某側沒有ticks，可能停振或窗口太短|
|11|PUF_RO_SATURATED|計數器飽和；count不可當作有效比較|
|12|PUF_BACKEND_FAULT|其他後端錯誤|

error enum：0 PUF_NO_ERROR、1 PUF_ERROR。error=1 時 key/helper/corrected_words 都為0；仍需以 result_valid 解讀錯誤 packet。status3保留未使用。

raw status：0 OK、1 BAD_PAIR、2 BAD_WINDOW、3 BAD_WARMUP、4 ZERO_COUNT、5 COUNT_SATURATED。raw 結果不經 PUF/ECC。
