`timescale 1ns/1ps
// Exercise the generated BD, vendor DMA/interconnect/reset, and real SHA-3 RTL.
// The PS VIP models bus transactions and DDR storage, not Linux or DDR training.
`define PS dut.design_1_i.processing_system7_0.inst
module tb_sha3_system;
    `include "sizes.svh"
    localparam [31:0] DMA_BASE = 32'h40400000;
    localparam [31:0] TX_BASE = 32'h10000000;
    localparam [31:0] RX_BASE = 32'h11000000;
    reg ps_clk_drive = 0;
    reg por_drive = 0, srst_drive = 0;
    wire ps_clk = ps_clk_drive;
    wire por_n = por_drive;
    wire srst_n = srst_drive;
    always #10 ps_clk_drive = ~ps_clk_drive;
    reg [31:0] tx [0:TX_WORDS-1];
    reg [31:0] rx [0:CASES*9-1];
    reg [63:0] cases [0:CASES-1];

    design_1_wrapper dut (
        .FIXED_IO_ps_clk(ps_clk), .FIXED_IO_ps_porb(por_n),
        .FIXED_IO_ps_srstb(srst_n)
    );

    task automatic mmio_write(input [31:0] offset, input [31:0] value);
        reg [1:0] response;
        `PS.write_data(DMA_BASE + offset, 4, value, response);
        if (response !== 0) $fatal(1, "AXI write response=%b offset=%h", response, offset);
    endtask

    task automatic mmio_read(input [31:0] offset, output [31:0] value);
        reg [2047:0] data;
        reg [1:0] response;
        `PS.read_data(DMA_BASE + offset, 4, data, response);
        if (response !== 0) $fatal(1, "AXI read response=%b offset=%h", response, offset);
        value = data[31:0];
    endtask

    task automatic start_channels;
        reg [31:0] a, b;
        mmio_read(4, a);
        mmio_read(32'h34, b);
        if ((a & 1) != 1 || (b & 1) != 1) $fatal(1, "DMA must be halted after PL reset");
        mmio_write(0, 1);
        mmio_write(32'h30, 1);
        for (integer i=0; i<100; i++) begin
            mmio_read(4, a); mmio_read(32'h34, b);
            if (((a | b) & 1) == 0) begin
                $display("PASS PS GP0 MMIO responds and both DMA channels start");
                return;
            end
        end
        $fatal(1, "DMA start timeout");
    endtask

    task automatic wait_dma;
        reg [31:0] a, b;
        for (integer i=0; i<20000; i++) begin
            mmio_read(4, a); mmio_read(32'h34, b);
            if (((a | b) & 32'h70) != 0) $fatal(1, "DMA error TX=%h RX=%h", a,b);
            if ((a & b & 2) != 0) begin
                $display("PASS DMA complete TX=%h RX=%h",a,b);
                return;
            end
        end
        $fatal(1, "DMA completion timeout");
    endtask

    task automatic stop_channels;
        reg [31:0] a,b;
        mmio_write(0,0); mmio_write(32'h30,0);
        for (integer i=0; i<100; i++) begin
            mmio_read(4,a); mmio_read(32'h34,b);
            if ((a & b & 1) != 0) begin
                $display("PASS DMA channels halt before PL reconfiguration");
                return;
            end
        end
        $fatal(1,"DMA stop timeout");
    endtask

    task automatic begin_transfer(input integer count);
        for (integer i=0; i<10; i++) observed[i]=32'hdeadbeef;
        write_beats=0; write_responses=0; write_pending=0;
        // Receive is armed first, matching the PYNQ driver.
        mmio_write(32'h48, RX_BASE);
        mmio_write(32'h58, 36);
        mmio_write(32'h18, TX_BASE);
        mmio_write(32'h28, count*4);
        wait_dma();
    endtask

    // Independent byte scoreboard observes the real PS HP0 boundary. It never
    // drives the DUT or fabricates replies. The VIP DDR read model supplies TX;
    // RX is checked here because this Vivado VIP's backdoor storage did not
    // reflect accepted HP0 writes during the initial audit.
    reg [31:0] observed [0:9];
    integer write_beats=0, write_responses=0;
    reg write_pending=0;
    wire hp_clk = dut.design_1_i.processing_system7_0_FCLK_CLK0;
    always @(posedge hp_clk) begin
        if (`PS.S_AXI_HP0_AWVALID && `PS.S_AXI_HP0_AWREADY) begin
            if (write_pending || `PS.S_AXI_HP0_AWADDR !== RX_BASE ||
                `PS.S_AXI_HP0_AWLEN !== 4 || `PS.S_AXI_HP0_AWSIZE !== 3 ||
                `PS.S_AXI_HP0_AWBURST !== 1)
                $fatal(1,"Unexpected HP0 output write address/burst");
            write_pending=1;
        end
        if (`PS.S_AXI_HP0_WVALID && `PS.S_AXI_HP0_WREADY) begin
            if (!write_pending || write_beats>=5 ||
                `PS.S_AXI_HP0_WSTRB !== ((write_beats==4) ? 8'h0f : 8'hff) ||
                `PS.S_AXI_HP0_WLAST !== (write_beats==4))
                $fatal(1,"Unexpected HP0 output beat, strobe, or WLAST");
            for (integer byte_i=0;byte_i<8;byte_i++) begin
                if (`PS.S_AXI_HP0_WSTRB[byte_i]) begin
                    observed[(write_beats*8+byte_i)/4][((write_beats*8+byte_i)%4)*8+:8]
                        = `PS.S_AXI_HP0_WDATA[byte_i*8+:8];
                end
            end
            write_beats=write_beats+1;
        end
        if (`PS.S_AXI_HP0_BVALID && `PS.S_AXI_HP0_BREADY) begin
            if (!write_pending || write_beats!=5 || `PS.S_AXI_HP0_BRESP !== 0)
                $fatal(1,"HP0 output write response failed");
            write_pending=0;
            write_responses=write_responses+1;
        end
    end

    task automatic check_reply(input integer index, input [31:0] error_status);
        reg [31:0] count, expected;
        mmio_read(32'h58, count);
        if (count !== 36 || write_beats != 5 || write_responses != 1 || write_pending)
            $fatal(1,"Incomplete DMA/HP0 output transaction");
        for (integer i=0; i<9; i++) begin
            expected = (index >= 0) ? rx[index*9+i] : ((i==0) ? error_status : 0);
            if (observed[i] !== expected)
                $fatal(1,"HP0 result mismatch case=%0d word=%0d actual=%h expected=%h",
                       index,i,observed[i],expected);
        end
        if (observed[9] !== 32'hdeadbeef) $fatal(1,"DMA wrote past the output buffer");
    endtask

    task automatic run_case(input integer index);
        integer offset,count;
        offset=cases[index][63:32]; count=cases[index][31:0];
        for (integer i=0; i<count; i++) `PS.write_mem(tx[offset+i],TX_BASE+i*4,4);
        // The 32-to-64-bit bridge can fetch a complete final DDR beat.
        // Physical RAM has defined bits; initialize the model's adjacent bytes.
        for (integer i=count; i<count+32; i++) `PS.write_mem(0,TX_BASE+i*4,4);
        begin_transfer(count);
        check_reply(index,0);
        $display("PASS SYSTEM case=%0d TX_words=%0d PS-DDR-DMA-SHA3-HP0",index,count);
    endtask

    task automatic reset_pl;
        `PS.fpga_soft_reset(32'hf);
        repeat(40) @(posedge dut.design_1_i.processing_system7_0_FCLK_CLK0);
        if (dut.design_1_i.sha3.sha3_ip.axis_aresetn !== 0)
            $fatal(1,"PL reset did not assert");
        `PS.fpga_soft_reset(0);
        repeat(250) @(posedge dut.design_1_i.processing_system7_0_FCLK_CLK0);
        if (dut.design_1_i.sha3.sha3_ip.axis_aresetn !== 1 ||
            dut.design_1_i.axi_control.ARESETN !== 1)
            $fatal(1,"BD reset did not release. Inspect aux reset polarity/constant.");
        $display("PASS full BD peripheral and interconnect resets release");
    endtask

    initial begin
        $readmemh("tx.hex",tx); $readmemh("rx.hex",rx); $readmemh("cases.hex",cases);
        #2000;
        por_drive=1; srst_drive=1;
        `PS.set_debug_level_info(0);
        `PS.set_stop_on_error(1);
        reset_pl();
        start_channels();
        for(integer i=0;i<CASES;i++) run_case(i);
        // Malformed header travels through the real DMA and must recover.
        for (integer i=0;i<32;i++) `PS.write_mem(0,TX_BASE+i*4,4);
        `PS.write_mem(32'hffffffff,TX_BASE,4);
        begin_transfer(1);
        check_reply(-1,32'h53480001);
        run_case(1);
        // Reinitialize the complete PL path and verify a fresh transfer.
        stop_channels(); reset_pl(); start_channels(); run_case(1);
        repeat(20) @(posedge dut.design_1_i.processing_system7_0_FCLK_CLK0);
        $display("SUCCESS FULL SYSTEM reset MMIO DDR-read DMA SHA3 HP0-write and recovery");
        $finish;
    end
    initial begin
        #100000000;
        $fatal(1,"Full system timeout: stalled clock, reset, AXI, or DMA");
    end
endmodule
`undef PS
