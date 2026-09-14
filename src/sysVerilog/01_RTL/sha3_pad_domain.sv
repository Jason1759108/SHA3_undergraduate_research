module sha3_pad_domain (
    input  logic [1087:0] msg_in,       
    input  logic [7:0]    msg_length,   // 訊息實際長度，單位：byte，範圍 0~135
    input  logic         block_last,

    input  logic         extra_pad_block,

    output logic [1087:0] padded_block  
);
    import sha3_pkg::*;

    always_comb begin
        padded_block = '0;

        if (extra_pad_block) begin
            padded_block[7:0]      = 8'h06;
            padded_block[1087-:8]  = 8'h80;
        end
        else if (!block_last) begin
            padded_block = msg_in;
        end
        else begin
            // Final block.
            for (int unsigned i = 0; i < 136; i++) begin
                if (i < msg_length)
                    padded_block[i*8 +: 8] = msg_in[i*8 +: 8];
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
endmodule