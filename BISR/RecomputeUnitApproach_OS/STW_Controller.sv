`include "./header.vh"

module STW_Controller  
#(
    parameter WORD_SIZE = 16
)(
    input clk,
    input rst,

    //STW inputs
    input logic STW_start,
    input logic STW_complete_out,
    //outputs control signals
    output logic start,
    output logic STW_test_load_en,
    output logic [`WORD_SIZE-1:0] STW_mult_op1,
    output logic [`WORD_SIZE-1:0] STW_mult_op2,
    output logic [`WORD_SIZE-1:0] STW_add_op,
    output logic [`WORD_SIZE-1:0] STW_expected,
    output logic matrix_start
    
    // output logic STW_complete;
    // output logic [(`ROWS * `COLS)-1:0] STW_result_mat; //[`COLS-1:0];
);
    localparam [1:0] STW_IDLE = 2'b00;
    localparam [1:0] STW_LOAD = 2'b01;
    localparam [1:0] STW_RESULT = 2'b10;
    logic [1:0] state;
    always @(posedge clk)begin
        if(rst)begin
            start <= 1'b0;
            STW_test_load_en <= 1'b0;
            STW_mult_op1 <= `WORD_SIZE'd0;
            STW_mult_op2 <= `WORD_SIZE'd0;;
            STW_add_op <= `WORD_SIZE'd0;;
            STW_expected <= `WORD_SIZE'd0;

            matrix_start <= 1'b0;

            state <= STW_IDLE;
        end
        else begin
            case(state)
            STW_IDLE: begin
                matrix_start <= 1'b0;
                if(STW_start)begin
                    STW_test_load_en = 1;
                    start = 0;
                    STW_mult_op1 = `WORD_SIZE'd4;
                    STW_mult_op2 = `WORD_SIZE'd3;
                    STW_add_op = `WORD_SIZE'd0;
                    STW_expected = `WORD_SIZE'd12;

                    state <= STW_LOAD;
                end 
            end 
            STW_LOAD: begin
                STW_test_load_en = 0;
                start = 1;
                state <= STW_RESULT;
            end 
            STW_RESULT: begin
                start = 0;
                if(!STW_complete_out)begin
                    state <= STW_IDLE;
                    matrix_start <= 1'b1;
                end
            end 
            endcase
        end  

    end 
endmodule