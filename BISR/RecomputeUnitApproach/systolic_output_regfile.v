module systolic_output_regfile
#(
    parameter COLS = 4,
    parameter WORD_SIZE = 16
) (
    clk,
    rst,
    wr_data,   //input to regfile - same size as bottom_out of systolic module
    wr_idx,   //Index to write to - enables that reg
    systolic_output   //Overall output of systolic operation
);

    input clk, rst;
    input [(COLS*WORD_SIZE)-1:0] wr_data;
    input [COLS-1:0] wr_idx;
    output reg [WORD_SIZE-1:0] systolic_output [COLS-1:0];   //Regfile with COLS entries of size WORD_SIZE each

    genvar i;
    generate
    for(i=0; i<COLS; i=i+1) begin
        always @(posedge clk) begin
            if(rst)
                systolic_output[i] <= {WORD_SIZE{1'b0}};
            else begin
                if(wr_idx == i)
                    systolic_output[i] <= wr_data[(i*WORD_SIZE) +: WORD_SIZE];
            end
        end

    end
        
    endgenerate
    
endmodule