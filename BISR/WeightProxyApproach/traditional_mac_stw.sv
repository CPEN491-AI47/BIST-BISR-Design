
// `include "./header.vh"
`include "./header_ws.vh"   //Enable header_ws for weight-stationary tb
// `define ENABLE_FI
//`define ENABLE_STW
module traditional_mac_stw
#(
    parameter WORD_SIZE = 16
)(
    clk,
    rst,
    stall,   //Do nothing this clk cycle if waiting for memory
    //Control Signals - Used for matmul op + setting stationary operand
    fsm_op2_select_in,  //For set stationary operands: set to 1, For matmul: set to 0
    fsm_out_select_in,  //Output accumulated sum (for IS/WS) or top_in (for OS)
    stat_bit_in,  //Use stationary operand for multiplying with left_in - IS/WS: stat_bit_in = 1 when doing matmul
    `ifdef ENABLE_FI
        fault_inject,
    `endif

    // STW signals
    `ifdef ENABLE_STW
        STW_test_load_en,
        // following signals are loaded into registers with the above load_en signal
        STW_mult_op1,
        STW_mult_op2,
        STW_add_op,
        STW_expected,

        // starts the STW process, if STW_complete is not asserted, nothing happens
        STW_start,
        // active high when STW is complete and is ready for another test
        STW_complete,
        // result is valid until next assertion of STW_start
        STW_result_out,
    `endif

    `ifdef ENABLE_WPROXY
        stationary_operand_reg,
        // proxy_en,   //If 1: that PE can be used as a proxy
        // load_proxy,
    `endif

    left_in,
    top_in, 
    right_out,
    bottom_out,
    
    // stw_en
    // multiplier_out,
    // top_in_reg,
    // left_in_reg,
    // accumulator_reg,
    // adder_out, 
    // mult_op2_mux_out,
    // add_op2_mux_out
);

input clk;
input rst;
input stall;

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

input logic signed [WORD_SIZE - 1: 0] left_in;
input logic signed [WORD_SIZE - 1: 0] top_in;

output logic [WORD_SIZE - 1: 0] right_out;
output logic [WORD_SIZE - 1: 0] bottom_out;

wire [255:0] tie_low;
assign tie_low = {WORD_SIZE{1'b0}};

`ifdef ENABLE_WPROXY
    output logic signed [WORD_SIZE - 1: 0] stationary_operand_reg;
    // input load_proxy;
    // input proxy_en; 
`else
    logic signed [WORD_SIZE - 1: 0] stationary_operand_reg;
`endif
logic signed [WORD_SIZE - 1: 0] top_in_reg;
logic signed [WORD_SIZE - 1: 0] left_in_reg;
logic signed [WORD_SIZE - 1: 0] accumulator_reg;

logic signed [WORD_SIZE - 1: 0] adder_out; 
logic signed [WORD_SIZE - 1: 0] mult_op2_mux_out;
logic signed [WORD_SIZE - 1: 0] add_op2_mux_out;

`ifdef ENABLE_STW
    input logic signed [WORD_SIZE-1:0] STW_mult_op1;
    input logic signed [WORD_SIZE-1:0] STW_mult_op2;
    input logic signed [WORD_SIZE-1:0] STW_add_op;
    input logic signed [WORD_SIZE-1:0] STW_expected;
    input STW_test_load_en;
    input STW_start;
    output logic STW_complete;
    output logic STW_result_out = 1'b1;

    logic signed [WORD_SIZE-1:0] STW_mult_op1_reg;
    logic signed [WORD_SIZE-1:0] STW_mult_op2_reg;
    logic signed [WORD_SIZE-1:0] STW_add_op_reg;
    logic signed [WORD_SIZE-1:0] STW_expected_reg;

    // FSM for STW
    parameter STW_IDLE = 'h0;
    parameter STW_RUNNING ='h1;
    parameter REPAIR ='h2;

    reg stw_en;
    reg [1:0] state;
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            STW_complete <= 'b1;
            stw_en <= 'b0;
            STW_result_out <= 1'b1;
            state <= STW_IDLE;
        end else begin
            case (state)
                STW_IDLE: begin
                    if (STW_start) begin
                        STW_complete <= 'b0;
                        stw_en <= 'b1;

                        state <= STW_RUNNING;
                    end
                end
                STW_RUNNING: begin
                    STW_complete <= 1'b0;
                    stw_en <= 'b1;
                    STW_result_out <= (STW_expected_reg == adder_out);

                    state <= REPAIR;
                end
                REPAIR: begin   //Wait 1 cycle for proxy controller to load weight if this PE was chosen as proxy
                    STW_complete <= 1'b1;
                    stw_en <= 'b0;
                    state <= STW_IDLE;
                end
                default: begin
                    stw_en <= 'b0;

                    state <= STW_IDLE;
                end
            endcase
        end
    end

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            STW_expected_reg <= 'd0;
            STW_mult_op1_reg <= 'd0;
            STW_mult_op2_reg <= 'd0;
            STW_add_op_reg <= 'd0;
        end
        else if (STW_test_load_en) begin
            STW_expected_reg <= STW_expected;
            STW_mult_op1_reg <= STW_mult_op1;
            STW_mult_op2_reg <= STW_mult_op2;
            STW_add_op_reg <= STW_add_op;
        end
    end

`endif

assign right_out = left_in_reg;

`ifdef ENABLE_WPROXY
    // assign bottom_out = (STW_result_out == 0) ? top_in_reg : ((fsm_out_select_in == 1'b0) ? {tie_low[WORD_SIZE - 1: 0] | top_in_reg} : accumulator_reg);   //Enable bypassing if STW detected a fault
    assign bottom_out = (fsm_out_select_in == 1'b0) ? {tie_low[WORD_SIZE - 1: 0] | top_in_reg} : accumulator_reg;
`else
    assign bottom_out = (fsm_out_select_in == 1'b0) ? {tie_low[WORD_SIZE - 1: 0] | top_in_reg} : accumulator_reg;
`endif

logic signed [WORD_SIZE - 1: 0] multiplier_out;  //TODO: Remove
`ifdef ENABLE_STW
    logic signed [WORD_SIZE - 1: 0] stw_multiplier_reg;

    always @(negedge clk) begin
        if (stw_en) begin
            stw_multiplier_reg <= STW_mult_op1_reg * STW_mult_op2_reg;
        end
       
    end

`endif

logic signed [31:0] mul_fixed_out;
mul_fixed32 multiplier_fixed32 (
    .a(left_in_reg),
    .b(mult_op2_mux_out),
    .out(mul_fixed_out)
);
`ifdef ENABLE_FI
    // wire [WORD_SIZE - 1: 0] multiplier_out;
    //Stuck-at fault injected after multiply and before add
    `ifdef ENABLE_STW
        
        // assign multiplier_out = (fault_inject[0]) ? stuck_at : (stw_en ? stw_multiplier_reg : left_in_reg * mult_op2_mux_out);
        assign multiplier_out = (fault_inject[0]) ? stuck_at : (stw_en ? stw_multiplier_reg : mul_fixed_out);
    `else
        // assign multiplier_out = (fault_inject[0]) ? stuck_at : left_in_reg * mult_op2_mux_out;
        assign multiplier_out = (fault_inject[0]) ? stuck_at : mul_fixed_out;
    `endif
`elsif ENABLE_STW
    // assign multiplier_out = stw_en ? stw_multiplier_reg : left_in_reg * mult_op2_mux_out;
    assign multiplier_out = stw_en ? stw_multiplier_reg : mul_fixed_out;
`else

    // assign multiplier_out = left_in_reg * mult_op2_mux_out;
    assign multiplier_out = mul_fixed_out;
`endif

`ifdef ENABLE_STW
    assign adder_out = multiplier_out + (stw_en ? STW_add_op_reg : add_op2_mux_out);
`else
    assign adder_out = multiplier_out + add_op2_mux_out;
`endif

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

`ifdef ENABLE_WPROXY
    if(!stall) begin
        left_in_reg <= left_in;
        top_in_reg <= top_in;
    end
`elsif ENABLE_STW   //If STW enabled, override left_in_reg, top_in_reg
    // stop updating the input registers while we run STW, this would allow us to continue execution with the last cycle's values.
    // This also requires that the inputs not change at the beginning of the SA.
    if (!stw_en) begin
        left_in_reg <= left_in;
        top_in_reg <= top_in;
    end
`else
    left_in_reg <= left_in;
    top_in_reg <= top_in;
`endif 
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
        if (fsm_op2_select_in == 1'b1 && !stall)
        begin
            stationary_operand_reg <= top_in;
        end

`ifdef ENABLE_STW
        if (!stw_en && !stall) begin
            accumulator_reg <= (STW_result_out == 0) ? top_in_reg : adder_out;
        end
`else
    if(!stall)
        accumulator_reg <= (STW_result_out == 0) ? top_in_reg : adder_out;
`endif
    end
end

endmodule
