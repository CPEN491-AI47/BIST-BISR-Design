`include "./header_ws.vh"

//Top level block for BISR design
module BISR_STW_systolic
#(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter WORD_SIZE = 16,
    parameter NUM_RU = 4   //Number of redundant units
) (
    clk,
    rst,

    //Systolic Inputs/Outputs
    ctl_stat_bit_in, 
    ctl_dummy_fsm_op2_select_in,
    ctl_dummy_fsm_out_select_in,
    `ifdef ENABLE_FI
        fault_inject_bus,
    `endif
    `ifdef ENABLE_STW
        STW_mult_op1,
        STW_mult_op2,
        STW_add_op,
        STW_expected,
        STW_test_load_en,
        STW_start,
        STW_complete_out,
        STW_result_mat,
    `endif
    left_in_bus,
    top_in_bus,
    bottom_out_bus,
    right_out_bus,

    //Recompute Unit input/Output
    //Input matrices
    top_matrix,
    left_matrix
);

    input clk;
    input rst;

    input [ROWS * WORD_SIZE - 1: 0] left_in_bus;
    input [COLS * WORD_SIZE - 1: 0] top_in_bus;
    output [COLS * WORD_SIZE - 1: 0] bottom_out_bus;
    output [ROWS * WORD_SIZE - 1: 0] right_out_bus;

    input ctl_stat_bit_in; 
    input ctl_dummy_fsm_op2_select_in;
    input ctl_dummy_fsm_out_select_in;

    `ifdef ENABLE_FI
        input [(ROWS * COLS * 2) - 1:0] fault_inject_bus; //total size = ROWS*COLS*(2bits per mac)
    `endif

    `ifdef ENABLE_STW
        input [WORD_SIZE-1:0] STW_mult_op1;
        input [WORD_SIZE-1:0] STW_mult_op2;
        input [WORD_SIZE-1:0] STW_add_op;
        input [WORD_SIZE-1:0] STW_expected;
        input STW_test_load_en;
        input STW_start;
        output STW_complete_out;
        //output wire [(ROWS*COLS)-1:0] STW_result_mat; //[COLS-1:0];
        output wire STW_result_mat[0:ROWS-1][0:COLS-1];
    `endif

    input [ROWS * COLS * WORD_SIZE - 1 : 0] top_matrix;
    input [ROWS * COLS * WORD_SIZE - 1 : 0] left_matrix;

    wire [NUM_RU-1:0] ru_en;   //Enable signals for redundant units (1 per col)
    wire [(NUM_RU * WORD_SIZE)-1 : 0] ru_top_inputs;
    wire [(NUM_RU * WORD_SIZE)-1 : 0] ru_left_inputs;   //ru_left_in also indexed by col, where ru_left_inputs[(c*WORD_SIZE)+:WORD_SIZE] = left_in for RU of col c


    wire [(NUM_RU * WORD_SIZE)-1 : 0] rcm_bottom_out;
    wire [(COLS * WORD_SIZE)-1: 0] systolic_bottom_out;

    reg [(COLS * WORD_SIZE)-1: 0] systolic_output_wr_data;
    //Settings for redundant PEs to set stationary & do matmul
    wire [NUM_RU-1:0] ru_set_stationary;
    wire [NUM_RU-1:0] ru_fsm_out_sel_in;
    wire [NUM_RU-1:0] ru_stat_bit_in;

    localparam NUM_BITS_COLS = $clog2(COLS);
    wire [(NUM_BITS_COLS*NUM_RU)-1:0] ru_col_mapping;

    recompute_unit_controller #(`ROWS, `COLS, `WORD_SIZE) rcm_ctrl(
        .clk(clk),
        .rst(rst),
        .top_matrix(top_matrix),
        .left_matrix(left_matrix),
        .STW_result_mat(STW_result_mat),
        .systolic_output_reg(systolic_output),
        .ru_en(ru_en),
        .ru_top_inputs(ru_top_inputs),
        .ru_left_inputs(ru_left_inputs),
        .ru_set_stationary(ru_set_stationary),
        .ru_fsm_out_sel_in(ru_fsm_out_sel_in),
        .ru_stat_bit_in(ru_stat_bit_in),
        .ru_col_mapping(ru_col_mapping)
    );

    genvar ru_idx;
    generate
    //Assign bottom_out to take either output from RU (if error detected - ru_en == 1) or original systolic
    //FIXME: Continue here - Use ru_col_mapping to correct this
    for(c = 0; c < COLS; c=c+1) begin
        always @(systolic_ru_map_reg[])
        if(systolic_ru_map_reg)
    end
    for(ru_idx = 0; ru_idx < NUM_RU; ru_idx = ru_idx+1) begin
        if(ru_en[ru_idx] && ) begin
            assign bottom_out_bus[(ru_col_map_reg[ru_idx]*WORD_SIZE) +: WORD_SIZE] = 
        end
        else begin
            assign bottom_out_bus[(c*WORD_SIZE) +: WORD_SIZE] = ru_en[c] ? rcm_bottom_out[(c*WORD_SIZE) +: WORD_SIZE] : systolic_bottom_out[(c*WORD_SIZE) +: WORD_SIZE];
        end
    end
    endgenerate

    recompute_module #(`ROWS, `COLS, `WORD_SIZE) rcm (
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
            .STW_complete_out(STW_complete),
            .STW_result_mat(STW_result_mat),
        `endif

        .left_in_bus(left_in_bus),
        .top_in_bus(top_in_bus),
        .bottom_out_bus(systolic_bottom_out),
        .right_out_bus(right_out_bus)
    );
    
    wire [WORD_SIZE-1:0] systolic_output [COLS-1:0];
    systolic_output_regfile #(`COLS, `WORD_SIZE) output_reg (
        .clk(clk),
        .rst(rst),
        .wr_data(systolic_bottom_out),   //Change input if RU en
        .wr_idx({`COLS{STW_complete}}),   //Write as long as STW isn't in progress
        .systolic_output(systolic_output)
    );
endmodule