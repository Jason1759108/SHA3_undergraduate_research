`timescale 1ns/1ps
module tb_sha3_axis;
    `include "sizes.svh"
    reg clk = 0;
    always #20 clk = ~clk;
    reg rst_n = 0;
    reg [31:0] s_data = 0;
    reg [3:0] s_keep = 15;
    reg s_valid = 0, s_last = 0, m_ready = 0;
    wire s_ready, m_valid, m_last;
    wire [31:0] m_data;
    wire [3:0] m_keep;
    reg [31:0] tx [0:TX_WORDS-1];
    reg [31:0] rx [0:CASES*9-1];
    reg [63:0] cases [0:CASES-1];
    integer cycle = 0;

    sha3_axis_top dut (
        .axis_aclk(clk), .axis_aresetn(rst_n),
        .s_axis_tdata(s_data), .s_axis_tkeep(s_keep), .s_axis_tvalid(s_valid),
        .s_axis_tready(s_ready), .s_axis_tlast(s_last),
        .m_axis_tdata(m_data), .m_axis_tkeep(m_keep), .m_axis_tvalid(m_valid),
        .m_axis_tready(m_ready), .m_axis_tlast(m_last)
    );
    always @(posedge clk) cycle <= cycle + 1;

    task automatic send_word(input [31:0] data, input last, input [3:0] keep);
        repeat (cycle % 3) @(negedge clk);
        @(negedge clk);
        s_data = data; s_last = last; s_keep = keep; s_valid = 1;
        do @(posedge clk); while (!s_ready);
        @(negedge clk); s_valid = 0;
    endtask

    task automatic receive_reply(input integer test_index, input [31:0] status);
        reg [31:0] held;
        reg held_last;
        for (integer word_index = 0; word_index < 9; word_index++) begin
            wait (m_valid);
            @(negedge clk);
            held = m_data;
            held_last = m_last;
            repeat (2 + word_index % 4) begin
                @(negedge clk);
                if (!m_valid || m_data !== held || m_last !== held_last)
                    $fatal(1, "Output changed during backpressure");
                if (s_ready) $fatal(1, "Input accepted before reply drained");
            end
            if (m_keep !== 15 || m_last !== (word_index == 8))
                $fatal(1, "Output framing mismatch");
            if (test_index >= 0) begin
                if (held !== rx[test_index*9+word_index])
                    $fatal(1, "Digest mismatch case=%0d word=%0d actual=%h expected=%h",
                           test_index, word_index, held, rx[test_index*9+word_index]);
            end else if (held !== ((word_index == 0) ? status : 32'b0))
                $fatal(1, "Error reply mismatch");
            m_ready = 1;
            @(negedge clk); m_ready = 0;
        end
    endtask

    task automatic run_case(input integer index);
        integer offset, count;
        offset = cases[index][63:32];
        count = cases[index][31:0];
        fork
            begin
                for (integer i = 0; i < count; i++)
                    send_word(tx[offset+i], i == count-1, 15);
            end
            receive_reply(index, 0);
        join
        $display("PASS SHA3 AXI case=%0d words=%0d", index, count);
    endtask

    initial begin
        $readmemh("tx.hex", tx);
        $readmemh("rx.hex", rx);
        $readmemh("cases.hex", cases);
        repeat (4) @(negedge clk);
        rst_n = 1;
        for (integer i = 0; i < CASES; i++) run_case(i);

        send_word(32'h189, 1, 15); // Invalid block length and early TLAST.
        receive_reply(-1, 32'h53480001);
        send_word(32'h103, 0, 15);
        send_word(32'h00636261, 1, 15); // Early TLAST in payload.
        receive_reply(-1, 32'h53480002);
        send_word(32'h100, 0, 7); // Bad keep, then drain the rest of the packet.
        send_word(0, 1, 15);
        receive_reply(-1, 32'h53480001);
        run_case(1);

        // Reset in the middle of a packet, then reuse the core.
        send_word(32'h103, 0, 15);
        send_word(32'h00636261, 0, 15);
        @(negedge clk); rst_n = 0;
        repeat (4) @(negedge clk);
        rst_n = 1;
        run_case(1);
        $display("SUCCESS SHA3 AXI vectors, stalls, malformed packets and reset");
        $finish;
    end
    initial begin
        #100000000;
        $fatal(1, "Global timeout");
    end
endmodule
