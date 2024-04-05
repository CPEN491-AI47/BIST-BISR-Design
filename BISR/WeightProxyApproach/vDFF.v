module vDFF#(
    parameter WORD_SIZE = 16
) (clk,D,Q, shift_en, stall);
  input clk;
  input [WORD_SIZE-1:0] D;
  input shift_en;
  input stall;
  output [WORD_SIZE-1:0] Q;
  reg [WORD_SIZE-1:0] Q;

  reg [WORD_SIZE-1:0] stalled_out;
  
  reg [3:0] shifter = 4'b0001;
  always @(posedge clk) begin
    if(shift_en && !stall) begin
      // if(shifter[3])
        Q <= stalled_out;
      // shifter <= {shifter[2:0], shifter[3]};
      stalled_out <= D;
    end
    else if(!stall) begin
      Q <= D;
    end
  end
endmodule