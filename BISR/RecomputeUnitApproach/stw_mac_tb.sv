`include "./traditional_mac_stw.v"

`define WORD_SIZE 16
//`define ENABLE_FI
`define ENABLE_STW

module mac_stw_tb();
    //inputs
    logic clk = 0;
    logic rst = 0; 

    //Systolic inputs
    logic fsm_op2_select_in;
    logic fsm_out_select_in; 
    logic stat_bit_in;
    logic [`WORD_SIZE-1:0] left_in;
    logic [`WORD_SIZE-1:0] top_in;

    //STW inputs
    logic STW_test_load_en;
    logic [`WORD_SIZE-1:0] STW_mult_op1;
    logic [`WORD_SIZE-1:0] STW_mult_op2;
    logic [`WORD_SIZE-1:0] STW_add_op;
    logic [`WORD_SIZE-1:0] STW_expected;
    logic STW_start;
    
    logic fault_inject;
    
    //outputs
    logic [15:0] right_out;
    logic [15:0] bottom_out;
    logic STW_complete;
    logic STW_result_out;

    traditional_mac_stw #(.WORD_SIZE(16)) stw_mac_dut (
        .clk(clk),
        .rst(rst),
        .fsm_op2_select_in(fsm_op2_select_in),  
        .fsm_out_select_in(fsm_out_select_in), 
        .stat_bit_in(stat_bit_in),  

        `ifdef ENABLE_FI
            .fault_inject(fault_inject),
        `endif

        `ifdef ENABLE_STW
            .STW_test_load_en(STW_test_load_en),
            .STW_mult_op1(STW_mult_op1),
            .STW_mult_op2(STW_mult_op2),
            .STW_add_op(STW_add_op),
            .STW_expected(STW_expected),
            .STW_start(STW_start),
            .STW_complete(STW_complete),
            .STW_result_out(STW_result_out),
        `endif

        .left_in(left_in),
        .top_in(top_in), 
        .right_out(right_out),
        .bottom_out(bottom_out)
    );

    always #5 clk = ~clk;

    initial begin
        rst = 1;
        @(posedge clk);
        @(negedge clk);
        rst = 0;
        @(negedge clk);
        fsm_op2_select_in = 0; 
        fsm_out_select_in = 0; 
        stat_bit_in = 0;

        STW_test_load_en = 1;
        STW_start = 0;
        fault_inject = 1'b0;
        STW_mult_op1 = `WORD_SIZE'd2;
        STW_mult_op2 = `WORD_SIZE'd3;
        STW_add_op = `WORD_SIZE'd0;
        STW_expected = `WORD_SIZE'd6;

        left_in = `WORD_SIZE'd3;
        top_in = `WORD_SIZE'd3;
        @(negedge clk);
        STW_test_load_en = 0;
        STW_start = 1;
        @(negedge clk);

        STW_start = 0;
        #50;
        @(negedge clk);
        $display("left_in: %0d, top_in: %0d", left_in, top_in);
        $display("right_out: %0d, bottom_out: %0d", right_out, bottom_out);
        #20;
        $stop;
    end

endmodule