// 16-bit extended Hamming syndrome sketch. One error corrected, two detected.
// Three or more errors can miscorrect: this is reconstruction, not authentication.
module puf_sketch #(parameter integer RAW_BITS=256)(
    input logic [RAW_BITS-1:0] raw,
    input logic [RAW_BITS/16*5-1:0] helper,
    output logic [RAW_BITS/16*5-1:0] generated_helper,
    output logic [RAW_BITS-1:0] corrected,
    output logic uncorrectable,
    output logic [15:0] corrected_words
);
    localparam integer WORDS=RAW_BITS/16;
    logic [WORDS-1:0] odd_error,bad;
    for(genvar w=0;w<WORDS;w++)begin:g_word
        logic [4:0] syndrome,delta;
        always_comb begin
            syndrome=0;
            for(integer b=0;b<16;b++)begin
                syndrome[4]=syndrome[4]^raw[16*w+b];
                if(b<15)syndrome[3:0]=syndrome[3:0]^(raw[16*w+b] ? 4'(b+1):4'd0);
            end
        end
        assign generated_helper[5*w+:5]=syndrome;
        assign delta=syndrome^helper[5*w+:5];
        assign odd_error[w]=delta[4];
        assign bad[w]=!delta[4] && (delta[3:0]!=0);
        for(genvar b=0;b<16;b++)begin:g_bit
            localparam logic[3:0] COLUMN=(b==15)?4'd0:4'(b+1);
            assign corrected[16*w+b]=raw[16*w+b]^(delta[4] && delta[3:0]==COLUMN);
        end
    end
    assign uncorrectable=|bad;
    always_comb begin
        corrected_words=0;
        for(integer w=0;w<WORDS;w++)corrected_words=corrected_words+16'(odd_error[w]);
    end
endmodule
