`timescale 1ns/1ps
// Default full-flow test uses oscillator waveforms, not synthetic counts.
module TESTBED_PUF;
    import puf_types::*;
    logic clk,rst_n,start,helper_in_valid,ready,busy,done,result_valid,result_ready;
    logic key_valid,helper_valid;
    puf_command_t command;
    puf_error_t error;
    puf_status_t status;
    logic[319:0] bitmap_in,flip_mask,unstable_mask;
    logic[79:0] helper_in,helper_out;
    logic[255:0] key_data;
    logic[15:0] corrected_count;
    logic[7:0] phase;
    /* verilator tracing_off */
    wire[639:0] ro_signals,ro_enable;
    logic[639:0] stop_mask;
    /* verilator tracing_on */
    logic[255:0] command_text,error_text,status_text;
    assign command_text=puf_command_ascii(command);
    assign error_text=puf_error_ascii(error);
    assign status_text=puf_status_ascii(status);
    puf_ro_top dut(.clk,.rst_n,.start,.command,.bitmap_in,.helper_in,.helper_in_valid,
        .ro_signals,.ro_enable,.ready,.busy,.done,.result_valid,.result_ready,
        .key_valid,.helper_valid,.key_data,.helper_out,.error,.status_code(status),.corrected_words(corrected_count));
    ro_array_model model(.enable(ro_enable),.flip_mask,.unstable_mask,.stop_mask,.ro(ro_signals));
    wire req=dut.req,mready=dut.mready,mvalid=dut.mvalid;
    wire[8:0] pair_index=dut.pair_index;
    wire[15:0] ca=dut.count_a,cb=dut.count_b;
    wire selected_ro_a=dut.backend.ro_a,selected_ro_b=dut.backend.ro_b;
    wire counter_reset_n=dut.backend.counter_rst_n;
    PATTERN_PUF_WAVE u_PATTERN(.*);
    always @(dut.backend.selected_pair)if(rst_n&&counter_reset_n)
        $fatal(1,"RO selection changed while counters active");
    always @(negedge clk)if(rst_n)begin
        if($countones(ro_enable)!=0&&$countones(ro_enable)!=2)$fatal(1,"RO enable must select one pair");
    end
    initial begin
`ifndef NO_DUMP
        $dumpfile("puf_sim.vcd");
        $dumpvars(0,clk,rst_n,start,command,command_text,error,error_text,status,status_text,
            phase,ready,busy,done,result_valid,result_ready,key_valid,helper_valid,key_data,helper_in,helper_out,
            corrected_count,bitmap_in,req,mready,mvalid,pair_index,ca,cb,selected_ro_a,selected_ro_b,counter_reset_n,
            dut.backend.state,dut.backend.selected_pair,dut.core.state);
`endif
    end
endmodule
