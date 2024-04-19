
`include "./header.vh"

module Top_BISR_STW_systolic
#(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter WORD_SIZE = 16,
    parameter NUM_RU = 4   //Number of redundant units
) (
    input clk,
    input rst,

    //Systolic Inputs/Outputs
    input [ROWS * COLS * WORD_SIZE - 1 : 0] top_matrix,
    input [ROWS * COLS * WORD_SIZE - 1 : 0] left_matrix,
    
    `ifdef ENABLE_FI
        input [(ROWS * COLS * 2) - 1:0] fault_inject_bus, //total size = ROWS*COLS*(2bits per mac)
    `endif

    `ifdef ENABLE_STW
        input STW_start,
    `endif

    output matrix_rdy,
    output [(ROWS * COLS * WORD_SIZE) - 1:0] output_matrix

);
    localparam NUM_BITS_COLS = $clog2(COLS);

    wire stat_bit_in;
    wire set_stationary;
    wire fsm_out_select_in;

    wire [ROWS * WORD_SIZE - 1: 0] left_in_bus;
    wire [COLS * WORD_SIZE - 1: 0] top_in_bus;
    

    wire [COLS * WORD_SIZE - 1: 0] bottom_out_bus;
    wire [ROWS * WORD_SIZE - 1: 0] right_out_bus;

    wire [NUM_RU - 1 : 0] ru_output_valid;
    wire [(NUM_RU * WORD_SIZE)-1 : 0] rcm_bottom_out;

    wire [(NUM_BITS_COLS*NUM_RU)-1:0] ru_col_mapping;
    wire [(NUM_BITS_COLS*NUM_RU)-1:0] ru_row_mapping;
    wire [(ROWS*COLS)-1:0] STW_result_mat;

    wire [(COLS * WORD_SIZE - 1): 0] matmul_fsm_output;
    wire [COLS-1:0] output_col_valid;   //If output_col_valid[i] == 1, then bottom_out of column i is valid

    `ifdef ENABLE_STW
        wire [`WORD_SIZE-1:0] STW_mult_op1;
        wire [`WORD_SIZE-1:0] STW_mult_op2;
        wire [`WORD_SIZE-1:0] STW_add_op;
        wire [`WORD_SIZE-1:0] STW_expected;
    `endif
    /*********************************
    Output Stationary Workflow Control
    *********************************/
    workflow_control_os #(WORD_SIZE) workflow_dut (
        .clk(clk),
        .rst(rst),

        .top_matrix(top_matrix),
        .left_matrix(left_matrix),

        .matrix_start(matrix_start),
        .set_stationary(set_stationary),
        .fsm_out_select_in(fsm_out_select_in),
        .stat_bit_in(stat_bit_in),

        .sys_rst(sys_rst),
        .curr_cycle_top_in(top_in_bus),
        .curr_cycle_left_in(left_in_bus),

        .bottom_out(bottom_out_bus),

        .matmul_output(matmul_fsm_output),
        .output_col_valid(output_col_valid)
    );

    /***************************************
    STW_Controller
    ***************************************/
    `ifdef ENABLE_STW
        STW_Controller  #(WORD_SIZE) STW_Controller_dut(
            .clk(clk),
            .rst(rst),
            //STW inputs
            .STW_start(STW_start),
            .STW_complete_out(STW_complete),
            //outputs control signals
            .start(start),
            .STW_test_load_en(STW_test_load_en),
            .STW_mult_op1(STW_mult_op1),
            .STW_mult_op2(STW_mult_op2),
            .STW_add_op(STW_add_op),
            .STW_expected(STW_expected),
            .matrix_start(matrix_start)
        );
    `endif
    /***************************************
    Build-in STW_BISR Systolic Array for OS
    ***************************************/
    BISR_STW_systolic_os #(ROWS, COLS, WORD_SIZE, NUM_RU) systolic_dut (
        .clk(clk),
        .rst(rst),
        .sys_rst(sys_rst),
        .ctl_stat_bit_in(stat_bit_in), 
        .ctl_dummy_fsm_op2_select_in(set_stationary),
        .ctl_dummy_fsm_out_select_in(fsm_out_select_in),

        `ifdef ENABLE_FI
            .fault_inject_bus(fault_inject_bus),
        `endif

        `ifdef ENABLE_STW
            .STW_test_load_en(STW_test_load_en),
            .STW_mult_op1(STW_mult_op1),
            .STW_mult_op2(STW_mult_op2),
            .STW_add_op(STW_add_op),
            .STW_expected(STW_expected),
            .STW_start(start),
            .matrix_start(matrix_start),
            .STW_complete_out(STW_complete),
            .STW_result_mat(STW_result_mat),
        `endif

        .left_in_bus(left_in_bus),
        .top_in_bus(top_in_bus),
        .systolic_bottom_out(bottom_out_bus),
        .right_out_bus(right_out_bus),

        .ru_output_valid(ru_output_valid),
        .rcm_bottom_out(rcm_bottom_out),

        .ru_col_mapping(ru_col_mapping),
        .ru_row_mapping(ru_row_mapping),

        .top_matrix(top_matrix),
        .left_matrix(left_matrix)
    );

    /*************
    Output Matrix 
    *************/
    matmul_output_control_os #(ROWS, COLS, WORD_SIZE, NUM_RU) matmul_out_dut (
        .clk(clk),
        .rst(rst),
        .STW_result_mat(STW_result_mat),
        
        //PE bottom bus & valid signals
        .matmul_fsm_output(bottom_out_bus),
        .output_col_valid(output_col_valid),

        //RU bottom bus & valid signals
        .ru_output_valid(ru_output_valid),
        .rcm_bottom_out(rcm_bottom_out),

        //RU indexes to faulty PE 
        .ru_col_mapping(ru_col_mapping),
        .ru_row_mapping(ru_row_mapping),

        //Output matrix 
        .output_matrix(output_matrix),
        .matrix_rdy(matrix_rdy)
    );

endmodule 