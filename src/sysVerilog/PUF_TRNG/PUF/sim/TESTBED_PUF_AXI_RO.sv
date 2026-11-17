// Full integration testbench: AXI4-Lite -> modeled RO waves -> real counters/CDC -> PUF -> SECDED.
`timescale 1ns/1ps
module TESTBED_PUF_AXI_RO;
    wire clk,reset_n;
    wire [11:0] awaddr,araddr;
    wire awvalid,awready,wvalid,wready,bvalid,bready,arvalid,arready,rvalid,rready;
    wire [31:0] wdata,rdata;
    wire [3:0] wstrb;
    wire [1:0] bresp,rresp;
    wire [639:0] ro_clocks,ro_enable,stop_mask,fast_mask;
    wire [319:0] flip_mask,tie_mask;
    puf_axi dut(.s_axi_aclk(clk),.s_axi_aresetn(reset_n),
        .s_axi_awaddr(awaddr),.s_axi_awprot(3'b0),.s_axi_awvalid(awvalid),.s_axi_awready(awready),
        .s_axi_wdata(wdata),.s_axi_wstrb(wstrb),.s_axi_wvalid(wvalid),.s_axi_wready(wready),
        .s_axi_bresp(bresp),.s_axi_bvalid(bvalid),.s_axi_bready(bready),
        .s_axi_araddr(araddr),.s_axi_arprot(3'b0),.s_axi_arvalid(arvalid),.s_axi_arready(arready),
        .s_axi_rdata(rdata),.s_axi_rresp(rresp),.s_axi_rvalid(rvalid),.s_axi_rready(rready),
        .ro_clocks,.ro_enable);
    ro_wave_model model(.enable(ro_enable),.stop_mask,.fast_mask,.flip_mask,.tie_mask,.ro(ro_clocks));
    PATTERN_PUF_AXI_RO pattern(.clk,.reset_n,.awaddr,.araddr,.awvalid,.wvalid,.bready,.arvalid,.rready,
        .wdata,.wstrb,.awready,.wready,.bvalid,.arready,.rvalid,.bresp,.rresp,.rdata,
        .enable(ro_enable),.stop_mask,.fast_mask,.flip_mask,.tie_mask);
    // Compact traces still show the real simulated inputs of the selected pair.
    wire selected_ro_a=(dut.u_measure.result_pair<320)?ro_clocks[10'(dut.u_measure.result_pair*2)]:1'b0;
    wire selected_ro_b=(dut.u_measure.result_pair<320)?ro_clocks[10'(dut.u_measure.result_pair*2+1)]:1'b0;
    wire [255:0] status_text=puf_types::puf_status_ascii(dut.status_code);
    wire [255:0] command_text=puf_types::puf_command_ascii(dut.command_value);
    wire [255:0] error_text=puf_types::puf_error_ascii(dut.error);
    initial if($test$plusargs("vcd")) begin $dumpfile("puf_axi_ro.vcd"); $dumpvars(0,TESTBED_PUF_AXI_RO); end
endmodule
