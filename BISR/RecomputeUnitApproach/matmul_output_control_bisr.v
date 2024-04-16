`include "./header_ws.vh"

//Control path for reading out & storing output matrix values (for weight/input-stationary flows) from systolic_matmul_fsm
//Notes: traditional_mac is double-buffered so each output is maintained for 2 clk cycles (thus wr_en has 1/2 freq of clk)
//Outputs of traditional_systolic are also staggered by 1 clk cycle. 
//Ex: Clk 1: Col 0 output[1] --> maintained for 2 clks (until clk 3)
//    Clk 2: Col 1 output[1]
//    Clk 3: Col 2 output[1] + Col 0 output[2]
module matmul_output_control_bisr_os
#(
    parameter WORD_SIZE = 16
)(
    input clk,
    input rst,
    input [(`ROWS*`COLS)-1:0] STW_result_mat, //[COLS-1:0];

    input [`COLS-1:0] bottom_out_bus,
    input [`COLS-1:0] output_col_valid,

    input [`NUM_RU - 1 :0]ru_output_valid,
    input [`NUM_RU * `WORD_SIZE -1 : 0]rcm_bottom_out,

    input [(NUM_BITS_COLS*NUM_RU)-1:0] ru_col_mapping;
    input [(NUM_BITS_COLS*NUM_RU)-1:0] ru_row_mapping;

    output [WORD_SIZE - 1:0] output_matrix[`ROWS][`COLS];
    output result_ready;
);

    wire [$clog2(`ROWS):0] write_count[`COLS];
    wire [`COLS-1:0] wr_en;
    wire [$clog2(`COLS):0] c;
    wire [$clog2(`NUM_RU):0] ru_c;
    wire [$clog2(`COLS*`ROWS):0] count;

    genvar c1;
    generate
        for(c1 = 0; c1 < `COLS; c1++) begin
            `ifdef OS_WORKFLOW
            //output matrix contrl for output-stationary workflow 
                always @(posedge clk) begin
                    // if output is valid && STW_result_mat is pull down
                    if(ru_output_valid[c1] && STW_result_mat[`COLS-write_count[c1]-1][c1]) begin
                        write_count[c1] <= write_count[c1]+1;
                        output_matrix[`COLS-write_count[c1]-1][c1] <= matmul_fsm_output[(c1) * WORD_SIZE +: WORD_SIZE];
                    end
                end
           `endif
        end
    endgenerate

    always @(*) begin
        for(ru_c = 0; ru_c < `NUM_RU; ru_c ++)begin
            if(ru_output_valid[ru_c] == 1'b1)begin
                output_matrix[ru_row_mapping[ru_c]][ru_col_mapping[ru_c]] = rcm_bottom_out[ru_c];
            end 
        end 
    end

endmodule