`include "./header.vh"

//Top level block for BISR design
//Modules Initatied: recompute_unit_controller
//                   recompute_module
//                   traditional_systolic_stw
//                   systolic_output_regfile
module BISR_STW_systolic_os
#(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter WORD_SIZE = 16,
    parameter NUM_RU = 4   //Number of redundant units
) (
    input clk,
    input rst,
    input sys_rst,

    //Systolic Inputs/Outputs
    input ctl_stat_bit_in, 
    input ctl_dummy_fsm_op2_select_in,
    input ctl_dummy_fsm_out_select_in,

    `ifdef ENABLE_FI
        input [(ROWS * COLS * 2) - 1:0] fault_inject_bus, //total size = ROWS*COLS*(2bits per mac)
    `endif

    `ifdef ENABLE_STW
        input [WORD_SIZE-1:0] STW_mult_op1,
        input [WORD_SIZE-1:0] STW_mult_op2,
        input [WORD_SIZE-1:0] STW_add_op,
        input [WORD_SIZE-1:0] STW_expected,
        input STW_test_load_en,
        input STW_start,
        input matrix_start,
        output STW_complete_out,
        output wire [(ROWS*COLS)-1:0] STW_result_mat, //[COLS-1:0];
    `endif

    input [ROWS * WORD_SIZE - 1: 0] left_in_bus,
    input [COLS * WORD_SIZE - 1: 0] top_in_bus,

    output [COLS * WORD_SIZE - 1: 0] systolic_bottom_out,
    output [ROWS * WORD_SIZE - 1: 0] right_out_bus,
    
    //Additional Ru Outputs bus & valid states  
    output [NUM_RU - 1 : 0] ru_output_valid,
    output [(NUM_RU * WORD_SIZE)-1 : 0] rcm_bottom_out,
    //Recompute Unit coordinates
    output [($clog2(COLS)*NUM_RU)-1:0] ru_col_mapping,
    output [($clog2(COLS)*NUM_RU)-1:0] ru_row_mapping,
    //Input matrices
    input [ROWS * COLS * WORD_SIZE - 1 : 0] top_matrix,
    input [ROWS * COLS * WORD_SIZE - 1 : 0] left_matrix
);
    localparam NUM_BITS_COLS = $clog2(COLS);
    wire [NUM_RU-1:0] ru_en;   //Enable signals for redundant units (1 per col)
    wire [(NUM_RU * WORD_SIZE)-1 : 0] ru_top_inputs;
    wire [(NUM_RU * WORD_SIZE)-1 : 0] ru_left_inputs;   //ru_left_in also indexed by col, where ru_left_inputs[(c*WORD_SIZE)+:WORD_SIZE] = left_in for RU of col c
    wire systoli_rst;

    //reg [(COLS * WORD_SIZE)-1: 0] systolic_bottom_out;

    reg [(COLS * WORD_SIZE)-1: 0] systolic_output_wr_data;
    //Settings for redundant PEs to set stationary & do matmul
    wire [NUM_RU-1:0] ru_set_stationary;
    wire [NUM_RU-1:0] ru_fsm_out_sel_in;
    wire [NUM_RU-1:0] ru_stat_bit_in;
    recompute_unit_controller_os #(ROWS, COLS, WORD_SIZE, NUM_RU) rcm_os(    //Number of redundant units
        .clk(clk),
        .rst(rst),
        //Input matrices
        .top_matrix(top_matrix),
        .left_matrix(left_matrix),
        
        .matrix_start(matrix_start),
        .STW_result_mat(STW_result_mat),
        //input [WORD_SIZE-1:0] systolic_output_reg [COLS-1:0];

        .ru_en(ru_en),
        .ru_top_inputs(ru_top_inputs),
        .ru_left_inputs(ru_left_inputs),

        .ru_set_stationary(ru_set_stationary),
        .ru_fsm_out_sel_in(ru_fsm_out_sel_in),
        .ru_stat_bit_in(ru_stat_bit_in),
        .ru_output_valid(ru_output_valid),

        .ru_col_mapping(ru_col_mapping),
        //Needed a register to stored row coordinates of the faulty PE
        .ru_row_mapping(ru_row_mapping)

    );  

    recompute_module #(ROWS, COLS, WORD_SIZE, NUM_RU) rcm (
        .clk(clk),
        .rst(rst),
        .ru_en(ru_en),
        .ru_top_inputs(ru_top_inputs),
        .ru_left_inputs(ru_left_inputs),
        .ru_set_stationary(ru_set_stationary),
        .ru_fsm_out_sel_in(ru_fsm_out_sel_in),
        .ru_stat_bit_in(ru_stat_bit_in),
        .ru_col_mapping(ru_col_mapping),
        .rcm_bottom_out(rcm_bottom_out)
    );

    //Instantiate systolic array with STW
    traditional_systolic_stw #(ROWS, COLS, WORD_SIZE) stw_systolic (
        .clk(clk),
        .rst(rst),
        .sys_rst(sys_rst),
        .ctl_stat_bit_in(ctl_stat_bit_in), 
        .ctl_dummy_fsm_op2_select_in(ctl_dummy_fsm_op2_select_in),
        .ctl_dummy_fsm_out_select_in(ctl_dummy_fsm_out_select_in),

        `ifdef ENABLE_FI
            .fault_inject_bus(fault_inject_bus),
        `endif

        `ifdef ENABLE_STW
            .STW_test_load_en(STW_test_load_en),
            .STW_mult_op1(STW_mult_op1),
            .STW_mult_op2(STW_mult_op2),
            .STW_add_op(STW_add_op),
            .STW_expected(STW_expected),
            .STW_start(STW_start),
            .STW_complete_out(STW_complete_out),
            .STW_result_mat(STW_result_mat),
        `endif

        .left_in_bus(left_in_bus),
        .top_in_bus(top_in_bus),
        .bottom_out_bus(systolic_bottom_out),
        .right_out_bus(right_out_bus)
    );
    
    wire [WORD_SIZE-1:0] systolic_output [COLS-1:0];
endmodule