module sha3_pad_domain (
    input  logic [1087:0] msg_in,       
    input  logic [7:0]    msg_length,   // 訊息實際長度，單位：byte，範圍 0~135
    input  logic         block_last,

    input  logic         extra_pad_block,
    input  logic         absorb_en,

    output logic [1087:0] padded_block  
);
    import sha3_pkg::*;

    // Operand isolation：padding 只有 absorb 那一拍會被 XOR 進 state。
    // absorb_en=0 時把 msg 輸入 AND 成 0，避免 Keccak 期間 1088-bit
    // mux 空轉。extra_pad 不走訊息內容。不新增長 clock。
    logic [1087:0] msg_iso;
    assign msg_iso = msg_in & {1088{absorb_en && !extra_pad_block}};

    always_comb begin
        padded_block = '0;

        if (absorb_en) begin
            if (extra_pad_block) begin
                padded_block[7:0]      = 8'h06;
                padded_block[1087-:8]  = 8'h80;
            end
            else if (!block_last) begin
                padded_block = msg_iso;
            end
            else begin
                // Final block.
                for (int unsigned i = 0; i < 136; i++) begin
                    if (i < msg_length)
                        padded_block[i*8 +: 8] = msg_iso[i*8 +: 8];
                    else if (i == msg_length && msg_length < 136)
                        padded_block[i*8 +: 8] = 8'h06;
                    else
                        padded_block[i*8 +: 8] = 8'h00;
                end

                // ★ 修正：只有當這塊有剩餘空間時，才寫入 0x80。
                // 剛好滿 136 bytes 時，交給額外的 extra_pad_block 處理。
                if (msg_length < 136) begin
                    padded_block[1087-:8] = padded_block[1087-:8] | 8'h80;
                end
            end
        end
    end
endmodule