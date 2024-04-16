//Source: https://docs.amd.com/r/en-US/ug901-vivado-synthesis/Initializing-Block-RAM-Verilog

module bram_mat #(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter WORD_SIZE = 16
) (clk, we, addr, di, dout);
    localparam NUM_LINES = ROWS*COLS;
    localparam ADDR_WIDTH = $clog2(ROWS*COLS);
    input clk;
    input we;
    input [ADDR_WIDTH-1:0] addr;
    input [WORD_SIZE-1:0] di;
    output [WORD_SIZE-1:0] dout;

    reg [WORD_SIZE-1:0] ram [NUM_LINES-1:0];
    reg [WORD_SIZE-1:0] dout;

    //left_mat must be rotated 90deg right, and each row is its own indep buffer
    initial begin        
        ram[8] = 16'h1; ram[7] = 16'h1; ram[6] = 16'h1;
        ram[5] = 16'h1; ram[4] = 16'h1; ram[3] = 16'h1;
        ram[2] = 16'h1; ram[1] = 16'h1; ram[0] = 16'h1;
    end

    always @(posedge clk) begin
        if (we)
            ram[addr] <= di;
        dout <= ram[addr];
    end

endmodule