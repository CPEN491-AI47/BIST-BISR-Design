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
        ram[0] = {16'd1, 16'd0, 16'd0, 16'd5};
        ram[1] = {16'd2, 16'd8, 16'd6, 16'd4};
        ram[2] = {16'd3, 16'd21, 16'd9, 16'd0};
        ram[3] = {16'd0, 16'd7, 16'd1, 16'd6};

        //Left Matrix Starts Here
        ram[4] = {16'd0, 16'd0, 16'd0, 16'd9};
        ram[5] = {16'd0, 16'd0, 16'd4, 16'd5};
        ram[6] = {16'd0, 16'd2, 16'd12, 16'd6};
        ram[7] = {16'd1, 16'd3, 16'd8, 16'd7};
        ram[8] = {16'd2, 16'd7, 16'd3, 16'd0};
        ram[9] = {16'd3, 16'd8, 16'd0, 16'd0};
        ram[10] = {16'd4, 16'd0, 16'd0, 16'd0};
        
        //Output Matrix starts here
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