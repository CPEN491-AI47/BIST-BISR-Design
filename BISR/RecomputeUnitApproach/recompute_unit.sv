module recompute_unit
    #(parameter WORD_SIZE = 16)(
    input clk,
    input rst,
    input [ROWS-1] faultyRowIn,
    input [COLS-1] faultyColIn,
    input [WORD_SIZE-1:0] Weight,
    input [WORD_SIZE-1:0] TopIn,
    input [WORD_SIZE-1:0] LeftIn,

    output reg [WORD_SIZE-1:0] BottomOut,
    output reg [WORD_SIZE-1:0] RightOut,
    output reg [ROWS-1] faultyRowOut,
    output reg [COLS-1] faultyColOut,
);

    reg [WORD_SIZE-1:0] Accumulator;


    always @(posedge clk, posedge rst) begin
        if(rst) begin
            BottomOut   <= 0;
            RightOut    <= 0;
            Accumulator <= 0;
        end
        else begin
            RightOut    <= LeftIn;
            BottomOut   <= Accumulator;
            Accumulator <= Weight*LeftIn + TopIn;
            faultyRowOut <= faultyRowIn;
            faultyColOut <= faultyColIn;
        end   
    end
    
endmodule
