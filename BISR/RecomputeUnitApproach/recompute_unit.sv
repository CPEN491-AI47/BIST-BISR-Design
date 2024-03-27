module recompute_unit #(
    parameter WORD_SIZE = 16,
    parameter ROWS = 4,
    parameter COLS = 4
)(
    input clk,
    input rst,
    input [ROWS-1:0] faultyRowIn,
    input [COLS-1:0] faultyColIn,
    input [WORD_SIZE-1:0] Weight,
    input [WORD_SIZE-1:0] LeftIn,

    output reg [WORD_SIZE-1:0] BottomOut,
    output reg [ROWS-1:0] faultyRowOut,
    output reg [COLS-1:0] faultyColOut
);

    always @(posedge clk, posedge rst) begin
        if(rst) begin
            BottomOut   <= 0;
            faultyRowOut <= 'dx;
            faultyColOut <= 'dx;
        end
        else begin
            BottomOut   <= Weight*LeftIn;
            faultyRowOut <= faultyRowIn;
            faultyColOut <= faultyColIn;
        end   
    end
    
endmodule
