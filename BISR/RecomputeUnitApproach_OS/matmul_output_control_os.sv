`include "./header.vh"

//Control path for reading out & storing output matrix values (for weight/input-stationary flows) from systolic_matmul_fsm
//Notes: traditional_mac is double-buffered so each output is maintained for 2 clk cycles (thus wr_en has 1/2 freq of clk)
//Outputs of traditional_systolic are also staggered by 1 clk cycle. 
//Ex: Clk 1: Col 0 output[1] --> maintained for 2 clks (until clk 3)
//    Clk 2: Col 1 output[1]
//    Clk 3: Col 2 output[1] + Col 0 output[2]
module matmul_output_control_os
#(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter WORD_SIZE = 16,
    parameter NUM_RU = 4   //Number of redundant units
)(
    input clk,
    input rst,
    input [(ROWS * COLS)-1:0] STW_result_mat, //[COLS-1:0];

    input [COLS * WORD_SIZE-1:0] matmul_fsm_output,
    input [COLS-1:0] output_col_valid,

    input [NUM_RU - 1 :0]ru_output_valid,
    input [NUM_RU * WORD_SIZE -1 : 0]rcm_bottom_out,

    input [($clog2(COLS) * NUM_RU)-1:0] ru_col_mapping,
    input [($clog2(COLS) * NUM_RU)-1:0] ru_row_mapping,

    output reg [(ROWS * COLS * WORD_SIZE) - 1:0] output_matrix,
    output reg matrix_rdy
    //output reg matrix_rdy
);
    //wire [$clog2(ROWS):0] write_count[`COLS];
    localparam NUM_BITS_ROWS = $clog2(ROWS);
    localparam NUM_BITS_COLS = $clog2(COLS);

    reg [NUM_BITS_COLS:0] write_count;

    //output matrix contrl for output-stationary workflow 
            always @(posedge clk) begin
                if(rst)begin
                    write_count <= {NUM_BITS_COLS{1'b0}};    
                    output_matrix <= {ROWS * COLS * WORD_SIZE{1'b0}};
                    //matrix_rdy <= 1'b0;
                end 
                else begin
                    // if output is valid && STW_result_mat is pull down
                    for( integer c1 = 0; c1 < COLS; c1++) begin
                        if( output_col_valid[c1] == 1'b1)begin
                            write_count <= write_count + 1'b1;
                            if(STW_result_mat[(COLS - write_count - 1'b1)*COLS + c1])
                                output_matrix[(((COLS - 1'b1 - write_count) * COLS + c1) * WORD_SIZE) +: WORD_SIZE] <= matmul_fsm_output[((c1) * WORD_SIZE) +: WORD_SIZE];
                        end 
                    end 

                    //Override if RU is valid
                    for( integer ru_idx = 0; ru_idx < NUM_RU; ru_idx = ru_idx + 1)begin
                        if(ru_output_valid[ru_idx] == 1'b1)
                            output_matrix[((ru_row_mapping[ru_idx*NUM_BITS_COLS +: NUM_BITS_COLS]*COLS+ru_col_mapping[ru_idx*NUM_BITS_COLS +: NUM_BITS_COLS]) * WORD_SIZE) +: `WORD_SIZE] <= rcm_bottom_out[ru_idx* WORD_SIZE +: WORD_SIZE];     
                    end 

                    //if no faulty PE identifies, matrix rdy after #ROW of cycles upon output is valid
                    if(STW_result_mat == {{ROWS*COLS}{1'b1}})begin 
                        if(write_count == ROWS - 1'b1)
                            matrix_rdy <= 1'b1;
                        else 
                            matrix_rdy <= 1'b0;
                    end 
                    
                    //else if faulty PE is identified, we wait for ru output to be valid
                    else begin
                        if(ru_output_valid != 0)
                            matrix_rdy <= 1'b1;
                        else 
                            matrix_rdy <= 1'b0; 
                    end 
                end 
        end

    //generate
    //     always @(posedge clk) begin
    //         for( ru_idx = 0; ru_idx < NUM_RU; ru_idx = ru_idx + 1)begin
    //             if(!rst)begin
    //                 if(ru_output_valid[ru_idx] == 1'b1)
    //                     output_matrix[((ru_row_mapping[ru_idx]*COLS+ru_col_mapping[ru_idx]) * WORD_SIZE) +: `WORD_SIZE] <= rcm_bottom_out[ru_idx* WORD_SIZE +: WORD_SIZE]; 
    //             end    
    //          end 
    //     end
    // //endgenerate

    //Check for if output matrix is ready  
    // always @(posedge clk)begin
    //     if(&STW_result_mat) begin
    //         if(output_col_valid)begin

    //         end 
    //     end 

    // end 

endmodule