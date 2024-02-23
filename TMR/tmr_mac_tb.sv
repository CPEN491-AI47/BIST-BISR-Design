`include "./traditional_mac.v"
`include "./pe_tmr.v"
`define WORD_SIZE 16
`define ENABLE_FI
module mac_tb();
    //inputs
    logic clk = 1'b0;
    logic rst, fsm_op2_select_in, fsm_out_select_in, stat_bit_in;
    logic [`WORD_SIZE-1:0] left_in;
    logic [`WORD_SIZE-1:0] top_in;
    
    logic [5:0] fault_inject_bus;

    //outputs
    logic [15:0] ref_right_out;
    logic [15:0] ref_bottom_out;

    logic [`WORD_SIZE-1:0] tmr_right_out;
    logic [`WORD_SIZE-1:0] tmr_bottom_out;

    pe_tmr mac_dut(
        .clk(clk),
        .rst(rst),
        .fsm_op2_select_in(fsm_op2_select_in),
        .fsm_out_select_in(fsm_out_select_in),
        .stat_bit_in(stat_bit_in),
        `ifdef ENABLE_FI
            .fault_inject_bus(fault_inject_bus),
        `endif
        .left_in(left_in),
        .top_in(top_in), 
        .right_out(tmr_right_out),
        .bottom_out(tmr_bottom_out)
    );

    traditional_mac mac_ref(
        .clk(clk),
        .rst(rst),
        .fsm_op2_select_in(fsm_op2_select_in),
        .fsm_out_select_in(fsm_out_select_in),
        .stat_bit_in(stat_bit_in),
        `ifdef ENABLE_FI
            .fault_inject(2'b0),
        `endif
        .left_in(left_in),
        .top_in(top_in), 
        .right_out(ref_right_out),
        .bottom_out(ref_bottom_out)
    );

    always #5 clk = ~clk;

    initial begin
        rst = 1'b1;
        @(negedge clk);
        rst = 1'b0;
        fsm_out_select_in = 1'b1;
        fsm_op2_select_in = 1'b1;
        stat_bit_in = 1'b0;
        left_in = `WORD_SIZE'd2;
        top_in = `WORD_SIZE'd3;
        fault_inject_bus = 6'b00_00_01;
        @(negedge clk);
        @(negedge clk);
        $display("left_in: %0d, top_in: %0d", left_in, top_in);
        $display("TMR right_out: %0d, bottom_out: %0d", tmr_right_out, tmr_bottom_out);
        $display("REFERENCE right_out: %0d, bottom_out: %0d", ref_right_out, ref_bottom_out);
        // fault_inject = 3'b0;
        // @(negedge clk);
        // $display("left_in: %0d, top_in: %0d, right_out: %0d, bottom_out: %0d", left_in, top_in, right_out, bottom_out);
        // $display("Settings: out_sel = %0d, op2_sel = %0d, stat_bit = %0d, fault_inject = %0d", fsm_out_select_in, fsm_op2_select_in, stat_bit_in, fault_inject);
        #20 $stop;
    end
endmodule