//pe_stw is a traditional_mac_stw with bypassing option for self-repair

`include "./header.vh"   //Enable header_ws for weight-stationary tb

module pe_stw
#(
    parameter WORD_SIZE = 16
)(
    clk,
    rst,
    
    //Control Signals - Used for matmul op + setting stationary operand
    fsm_op2_select_in,  //For set stationary operands: set to 1, For matmul: set to 0
    fsm_out_select_in,  //Output accumulated sum (for IS/WS) or top_in (for OS)
    stat_bit_in,  //Use stationary operand for multiplying with left_in - IS/WS: stat_bit_in = 1 when doing matmul
    `ifdef ENABLE_FI
        fault_inject,
    `endif

    // STW signals
    `ifdef ENABLE_STW
        STW_test_load_en,
        // following signals are loaded into registers with the above load_en signal
        STW_mult_op1,
        STW_mult_op2,
        STW_add_op,
        STW_expected,
        // starts the STW process, if STW_complete is not asserted, nothing happens
        STW_start,
        // active high when STW is complete and is ready for another test
        STW_complete,
        // result is valid until next assertion of STW_start
        STW_result_out,
    `endif

    left_in,
    top_in, 
    right_out,
    bottom_out
);

    input clk;
    input rst;
    input fsm_op2_select_in;
    input fsm_out_select_in;
    input stat_bit_in;
    `ifdef ENABLE_FI
        input [1:0] fault_inject;
    `endif

    `ifdef ENABLE_STW
        input [WORD_SIZE-1:0] STW_mult_op1;
        input [WORD_SIZE-1:0] STW_mult_op2;
        input [WORD_SIZE-1:0] STW_add_op;
        input [WORD_SIZE-1:0] STW_expected;
        input STW_test_load_en;
        input STW_start;
        output STW_complete;
        output STW_result_out;
    `endif

    input [WORD_SIZE - 1: 0] left_in;
    input [WORD_SIZE - 1: 0] top_in;

    output [WORD_SIZE - 1: 0] right_out;
    output [WORD_SIZE - 1: 0] bottom_out;  //bottom_out of this pe

    wire [WORD_SIZE - 1: 0] bottom_out_mac;   //bottom_out of tradition_mac_stw - only selected if !bypass_en
    wire [WORD_SIZE - 1: 0] right_out_mac;
    assign bottom_out = !STW_result_out ? top_in : bottom_out_mac;   //bypass if STW detected error (result_out = 0)
    assign right_out = !STW_result_out ? left_in : right_out_mac;

    traditional_mac_stw mac_stw(
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
        .right_out(right_out_mac),
        .bottom_out(bottom_out_mac)
    );

endmodule
