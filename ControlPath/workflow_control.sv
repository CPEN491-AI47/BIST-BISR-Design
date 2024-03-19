`include "./header_ws.vh"
/*
    This module selects for specific control workflows(OS,WS,IS) upon decision made in header file 
    Modules instantiated: systolic_matmul_fsm, systolic_matmul_fsm_os & matmul_output_control
*/
module workflow_control
#(
    parameter WORD_SIZE = 16
)(
        //Inputs
        input clk,
        input rst,

        input logic [`ROWS * `COLS * `WORD_SIZE - 1 : 0] top_matrix,

        `ifdef OS_WORKFLOW
            input logic [`ROWS * `COLS * `WORD_SIZE - 1 : 0] left_matrix,   
        `else
            input logic [WORD_SIZE:0] left_matrix[`ROWS][`COLS],
        `endif 

        input logic [`COLS * WORD_SIZE - 1: 0] bottom_out,

        //outputs MAC Controls signals
        output logic set_stationary,
        output logic fsm_out_select_in,
        output logic stat_bit_in,

        //Output left,top in buses
        output logic [`ROWS * WORD_SIZE - 1: 0] curr_cycle_top_in,
        output logic [`ROWS * WORD_SIZE - 1: 0] curr_cycle_left_in,

        //Outputs matrix 
        output logic [WORD_SIZE - 1:0] output_matrix [`ROWS][`COLS]
    );

    logic [`COLS-1:0] output_col_valid;
    logic[`COLS * `WORD_SIZE-1:0] matmul_output;

    //Select matmul_fsm based on workflow selected, Default as WS_workflow
    `ifdef OS_WORKFLOW
        systolic_matmul_fsm_OS #(`WORD_SIZE) matmul_dut_os(
            //Inputs
            .clk(clk),
            .rst(rst),
            
            .top_matrix(top_matrix),
            .left_matrix(left_matrix),

            .bottom_out(bottom_out),

            //Outputs
            .set_stationary(set_stationary),
            .fsm_out_select_in(fsm_out_select_in),
            .stat_bit_in(stat_bit_in),

            .curr_cycle_top_in(curr_cycle_top_in),
            .curr_cycle_left_in(curr_cycle_left_in),

            .matmul_output(matmul_output),
            .output_col_valid(output_col_valid)
        );
    `else 
        systolic_matmul_fsm #(`WORD_SIZE) matmul_dut(
            //Inputs
            .clk(clk),
            .rst(rst),

            .top_matrix(top_matrix),
            .left_matrix(left_matrix),

            .bottom_out(bottom_out),

            //outputs
            .set_stationary(set_stationary),
            .fsm_out_select_in(fsm_out_select_in),
            .stat_bit_in(stat_bit_in),

            .top_in_bus(curr_cycle_top_in),
            .curr_cycle_left_in(curr_cycle_left_in),

            .matmul_output(matmul_output),
            .output_col_valid(output_col_valid)
        );
    `endif
    
    matmul_output_control #(`WORD_SIZE) matmul_out_dut(
        .clk(clk),
        .rst(rst),
        .matmul_fsm_output(bottom_out),
        .matmul_output_valid(output_col_valid),

        //outputs 
        .output_matrix(output_matrix)
    );

endmodule 