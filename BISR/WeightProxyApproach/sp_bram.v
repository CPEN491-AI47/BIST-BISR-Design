//Source: https://docs.amd.com/r/en-US/ug901-vivado-synthesis/Initializing-Block-RAM-Verilog
`include "./header_ws.vh"
module bram_mat #(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter WORD_SIZE = 16
) (clk, we, addr, di, dout);
    localparam NUM_LINES = 15;
    localparam ADDR_WIDTH = 32;  //$clog2(ROWS*COLS);
    input clk;
    input we;
    input [ADDR_WIDTH-1:0] addr;
    input [`MEM_PORT_WIDTH-1:0] di;
    output [`MEM_PORT_WIDTH-1:0] dout;

    reg [`MEM_PORT_WIDTH-1:0] ram [NUM_LINES-1:0];
    reg [`MEM_PORT_WIDTH-1:0] dout;

    //For top matrix:
    //Left_matrix:
    initial begin        
        //Top Matrix Starts Here
        //Top Matrix:
        //[5 0 0  1]
        //[4 6 8  2]
        //[0 9 21 3]
        //[6 1 7  0]
        ram[0] = {16'd1, 16'd0, 16'd0, 16'd5};
        ram[1] = {16'd2, 16'd8, 16'd6, 16'd4};
        ram[2] = {16'd3, 16'd21, 16'd9, 16'd0};
        ram[3] = {16'd0, 16'd7, 16'd1, 16'd6};

        //Left Matrix Starts Here
        //Original Left Matrix:
        //[9 4  2 1] -> 1st set of inputs
        //[5 12 3 2] -> 2nd set of inputs
        //[6 8  7 3]
        //[7 3  8 4]
        //Staggered Left Matrix (formatted for input to SA)
        //[9 0  0 0]
        //[5 4  0 0]
        //[6 12 2 0]
        //[7 8  3 1]
        //[0 3  7 2]
        //[0 0  8 3]
        //[0 0  0 4]
        ram[4] = {16'd0, 16'd0, 16'd0, 16'd9};
        ram[5] = {16'd0, 16'd0, 16'd4, 16'd5};
        ram[6] = {16'd0, 16'd2, 16'd12, 16'd6};
        ram[7] = {16'd1, 16'd3, 16'd8, 16'd7};
        ram[8] = {16'd2, 16'd7, 16'd3, 16'd0};
        ram[9] = {16'd3, 16'd8, 16'd0, 16'd0};
        ram[10] = {16'd4, 16'd0, 16'd0, 16'd0};
        
        //Output Matrix starts here
        //Expected Output (hex) (standard matrix form)
        //00043 0002b 00051 00017 
        //00055 00065 000ad 00026 
        //00050 00072 000e8 0002b 
        //00047 0005e 000dc 00025

        //Expected Output (Arranged in RAM)
        // 002500dc005e0047
        // 002b00e800720050
        // 002600ad00650055
        // 00170051002b0043
        ram[11] = {16'd0, 16'd0, 16'd0, 16'd0};
        ram[12] = {16'd0, 16'd0, 16'd0, 16'd0};
        ram[13] = {16'd0, 16'd0, 16'd0, 16'd0};
        ram[14] = {16'd0, 16'd0, 16'd0, 16'd0};
    end

    always @(posedge clk) begin
        if (we)
            ram[addr] <= di;
        dout <= ram[addr];
    end

endmodule