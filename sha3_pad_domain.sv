module sha3_pad_domain (
    input  logic [1079:0] msg_in,       
    input  logic [7:0]    msg_length,   // 訊息實際長度，單位：byte，範圍 0~135
    output logic [1087:0] padded_block  
);
    import sha3_pkg::*;

    always_comb begin
        for (int i = 0; i < 136; i++) begin
            if (i < msg_length) begin
                padded_block[i*8 +: 8] = msg_in[i*8 +: 8];
            end else if (i == msg_length) begin
                padded_block[i*8 +: 8] = 8'h06;
            end else begin
                padded_block[i*8 +: 8] = 8'h00;
            end

            if (i == 135) begin
                padded_block[i*8 +: 8] |= 8'h80;
            end
        end
    end
endmodule