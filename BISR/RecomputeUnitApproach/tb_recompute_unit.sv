`define WORD_SIZE 16
`define ROWS 3
`define COLS 3

module tb_recompute_unit();
    reg clk = 0;
    reg rst;
    reg [`ROWS-1:0] faultyRowIn;
    reg [`COLS-1:0] faultyColIn;
    reg [`WORD_SIZE-1:0] Weight;
    reg [`WORD_SIZE-1:0] LeftIn;

    wire [`WORD_SIZE-1:0] BottomOut;
    wire [`ROWS-1:0] faultyRowOut;
    wire [`COLS-1:0] faultyColOut;

    recompute_unit #(
        .ROWS(`ROWS),
        .COLS(`COLS),
        .WORD_SIZE(`WORD_SIZE)
    ) recompute_unit_dut(
        .clk(clk),
        .faultyRowIn(faultyRowIn),
        .faultyColIn(faultyColIn),
        .Weight(Weight),
        .LeftIn(LeftIn),

        .BottomOut(BottomOut),
        .faultyRowOut(faultyRowOut),
        .faultyColOut(faultyColOut)
    );

    always #5 clk = ~clk;

    initial begin
        rst = 1;
        faultyRowIn = 1;
        faultyColIn = 1;
        Weight = 3;
        LeftIn = 4;

        #10
        rst = 0;
        faultyRowIn = 1;
        faultyColIn = 1;
        Weight = 3;
        LeftIn = 4;

        #10
        faultyRowIn = 2;
        faultyColIn = 1;
        Weight = 7;
        LeftIn = 8;

        #10
        faultyRowIn = 1;
        faultyColIn = 2;
        Weight = 10;
        LeftIn = 20;
    end

endmodule
