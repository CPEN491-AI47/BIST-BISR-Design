module recompute_unit #(
    parameter WORD_SIZE = 16,
    parameter ROWS = 4,
    parameter COLS = 4
)(
    input clk,
    input rst,
    input start,
    input [WORD_SIZE-1:0] Weight,
    input [WORD_SIZE-1:0] LeftIn,

    output reg [WORD_SIZE-1:0] BottomOut
);

    always @(posedge clk, posedge rst) begin
        if(rst | (!start)) begin
            BottomOut   <= 0;
        end
        else begin
            BottomOut   <= Weight*LeftIn;
        end   
    end
    
endmodule
