`include "./header.vh"

module traditional_mac 
#(
    parameter WORD_SIZE = 16
)(
    clk,
    rst,
    
    //Control Signals - Used for matmul op + setting stationary operand
    fsm_op2_select_in,  //For set stationary operands: set to 1, For matmul: set to 0
    fsm_out_select_in,  //Output accumulated sum (for IS/WS) or top_in (for OS)
    stat_bit_in,  //Use stationary operand for multiplying with left_in - IS/WS: stat_bit_in = 1 when doing matmul
    `ifdef ENABLE_FI
        fault_inject,
    `endif
    left_in,
    top_in, 
    right_out,
    bottom_out
);

input clk;
input rst;

input fsm_op2_select_in;
input fsm_out_select_in;
input stat_bit_in;

//fault_inject
//bit 0: 0 = fault injection off, 1 = fault injection on
//bit 1: 0 = stuck-at-0, 1 = stuck-at-1
`ifdef ENABLE_FI
    input [1:0] fault_inject;
    wire [WORD_SIZE-1:0] stuck_at = (fault_inject[1]) ? {WORD_SIZE{1'b1}} : {WORD_SIZE{1'b0}};
`endif

input [WORD_SIZE - 1: 0] left_in;
input [WORD_SIZE - 1: 0] top_in;

output [WORD_SIZE - 1: 0] right_out;
output [WORD_SIZE - 1: 0] bottom_out;

wire [255:0] tie_low;
assign tie_low = {WORD_SIZE{1'b0}};

reg [WORD_SIZE - 1: 0] stationary_operand_reg;
reg [WORD_SIZE - 1: 0] top_in_reg;
reg [WORD_SIZE - 1: 0] left_in_reg;
reg [WORD_SIZE - 1: 0] accumulator_reg;

wire [WORD_SIZE - 1: 0] multiplier_out;
wire [WORD_SIZE - 1: 0] adder_out; 
wire [WORD_SIZE - 1: 0] mult_op2_mux_out;
wire [WORD_SIZE - 1: 0] add_op2_mux_out;
wire [63:0] mul_raw;

assign right_out = left_in_reg;
assign bottom_out = (fsm_out_select_in == 1'b0) ? {tie_low[WORD_SIZE - 1: 0] | top_in_reg} : accumulator_reg;
assign mul_raw = left_in_reg * mult_op2_mux_out;

`ifdef ENABLE_FI
    //Stuck-at fault injected after multiply and before add
    assign multiplier_out = (fault_inject[0]) ? stuck_at : (mul_raw[47:16]);
    // always @(*) begin
    //     if(fault_inject[0] == 1'b1)
    //         multiplier_out = stuck_at;
    //     else    
    //         multiplier_out = (left_in_reg * mult_op2_mux_out);
    // end 
    
`else
    assign multiplier_out = mul_raw[47:16];
`endif

assign adder_out = multiplier_out + add_op2_mux_out;

assign mult_op2_mux_out = (stat_bit_in == 1'b1) ? stationary_operand_reg : top_in_reg;
assign add_op2_mux_out = (stat_bit_in == 1'b1) ? top_in_reg : accumulator_reg;

always @(posedge clk, posedge rst)
begin
     if(rst == 1'b1)
     begin
        top_in_reg <= tie_low[WORD_SIZE - 1: 0]; 
        left_in_reg <= tie_low[WORD_SIZE - 1: 0]; 
     end
     else
     begin 
        left_in_reg <= left_in;
        top_in_reg <= top_in;
     end
end

always @(posedge clk, posedge rst)
begin
    if(rst == 1'b1)
    begin
        accumulator_reg <= tie_low [WORD_SIZE - 1: 0]; 
        stationary_operand_reg <= tie_low [WORD_SIZE - 1: 0]; 
    end
    else
    begin
        if (fsm_op2_select_in == 1'b1)
        begin
            stationary_operand_reg <= top_in;
        end

        accumulator_reg <= adder_out;
    end
end

endmodule
