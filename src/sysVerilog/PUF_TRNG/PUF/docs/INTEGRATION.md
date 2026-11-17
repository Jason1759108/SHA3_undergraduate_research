# 與其他模組整合

## 固定功能契約

正式硬體：320 組 pair、640 RO；bitmap 320 bit 且恰好 256 個 1。pair p 固定為 RO 2p 與 2p+1；輸出 bit j 對應被選配對依 ID 遞增排序的第 j 組。每組五次量測取多數，任何一次 abs(count_a-count_b)<8 即拒絕整筆。

command 0=Registration：輸入 bitmap，輸出 PUF 256 bit 與 helper 80 bit。command 1=Certification（重建）：輸入原 bitmap/helper/helper_valid，成功輸出 PUF 256 bit；不回 helper。helper 全零也是合法值，不能用數值判斷是否存在。

每 16-bit 區塊有 5-bit syndrome，共 16 區塊；可修正各區塊 1 bit、偵測 2 bit，3 bit 以上可能誤接受。沒有 ID/版本/MAC/雜湊驗證，外部需管理 enrollment 與 bitstream 對應。

## 接法 A：保留已驗證 AXI IP（優先）

`puf_fpga_top` 內含 ro_bank+puf_axi，後者內含 ro_measure+puf_device。接 100MHz s_axi_aclk、active-low s_axi_aresetn 與完整 AXI4-Lite。透過軟體或 AXI master 寫 bitmap/helper/command、START，輪詢 FLAGS+completion sequence，讀結果後 CONSUME。原始配對量測也經 AXI 提供，供外部篩選。

將 PUF 與其他 IP 整合到同一 BD，可從 scripts/vivado/build.tcl 的 package/BD 步驟修改。RO constraint 同樣要納入綜合後 hook，並保持能匹配的 hierarchy；新增 IP 可能造成資源或時序問題，需重建後再量測。

AXI 位址與完整協定見 [REGISTER_MAP](REGISTER_MAP.md)。只允許一個控制者；不能同時由 Notebook 與另一個 master 發命令。

## 接法 B：原生 RTL `puf_device`

此接法適合自己的控制 FSM；`puf_device` 本身不含 RO/Counter。它的量測接口需連到真正後端，不能把原始 RO 接到 clk 或 count 輸入。

|介面|規則|
|---|---|
|clk/rst_n|系統時脈/低有效 reset；100MHz 是實板配置|
|start/ready|ready=1 時在時脈邊緣接受 start；一次脈衝即可。此時鎖存 command/bitmap/helper/helper_valid|
|busy/done|busy 表示操作中，done 是完成脈衝；下游取資料用 result_valid|
|result_valid/result_ready|valid && ready 的邊緣消耗整筆結果；未消耗時結果保持。不要將 key_valid 高的每個週期當成新結果|
|key_valid/key_data|僅成功結果可用；失敗輸出歸零、key_valid=0|
|helper_valid/helper_out|成功 Registration 才有效|
|error/status_code/corrected_words|與整筆結果一起取走；corrected_words 是修正的16-bit區塊數，不是錯誤總bit數|
|measure_req/measure_ready|同時為1的邊緣接受 pair_index；不要重複接收同一請求|
|measure_valid/count_a/count_b/measure_status|在 clk domain 回報對應量測結果；需正確傳播後端錯誤|

參考 `rtl/puf_axi.sv` 的 u_device、u_measure、measure_ready/valid 與 result_status→PUF status 轉換，是目前已驗證的數位連接範例。raw diagnostic 與 PUF 測量共用後端，需仲裁。

直接接真實 ro_measure 時要設定足夠 timeout：puf_device 預設 256 cycles 是快速模型預設；實板 puf_axi 使用 **1100128 cycles**。錯誤地沿用 256 會在 100000-cycle 視窗完成前逾時。逾時後需共同 reset PUF 與後端再繼續，不能只清除核心。

## 未來接 SHA3 或其他下游

上游命令不變；下游在 result_valid && key_valid 時接收 key_data。若下游不能一次接256bit，先把整筆結果鎖存到自己的暫存器，再 CONSUME，接著按約定分段傳送。若不能鎖存，就延後 result_ready，讓資料保持。

本套件建議以 byte j=key_data[8*j +:8]（低byte先）作為輸出序列；AXI 也是低32-bit word先。SHA3 adapter 必須與既有 SHA3 的輸入打包一致，不能只依畫面上的 hex 字串猜順序。實際 adapter 與 SHA3 測試尚未實作。

失敗結果不能送到 SHA3 當有效身份；SHA3 不能修復不一致的 PUF 資料。本核心沒有讓下游辨識被誤修正的不同候選之認證機制。

## 開機與保存

每板只在註冊階段篩選好的配對；保存 bitmap/helper/window/warmup/bitstream/HWH hash。重建固定使用它們，不在失敗時臨時換pair。內部資料易失，不需要舊 command2/3 或 save_req/ack。保護外部註冊資料的完整性由整體系統負責。
