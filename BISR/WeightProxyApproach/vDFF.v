module vDFF#(
    parameter WORD_SIZE = 16
) (clk,D,Q);
  input clk;
  input [WORD_SIZE-1:0] D;
  output [WORD_SIZE-1:0] Q;
  reg [WORD_SIZE-1:0] Q;
  always @(posedge clk)
    Q <= D;
endmodule