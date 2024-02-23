//Enable stuck-at fault injection in each MAC
`define ENABLE_FI

module pe_tmr
#(
    parameter WORD_SIZE = 16
)(
    clk,
    rst,
    
    //Control Signals
    fsm_op2_select_in,
    fsm_out_select_in,
    stat_bit_in,  // Drives selects for WS and IS modes
    `ifdef ENABLE_FI
        fault_inject_bus,
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

    //fault injection config for MACs in TMR PE
    //fault_inject_bus[1:0] = mac0 fault_inject
    //fault_inject_bus[3:2] = mac1 fault_inject
    //fault_inject_bus[5:4] = mac2 fault_inject

    //fault_inject
    //bit 0: 0 = fault injection off, 1 = fault injection on
    //bit 1: 0 = stuck-at-0, 1 = stuck-at-1
    `ifdef ENABLE_FI
        input [5:0] fault_inject_bus; 
    `endif

    input [WORD_SIZE - 1: 0] left_in;
    input [WORD_SIZE - 1: 0] top_in;

    output [WORD_SIZE - 1: 0] right_out;
    output [WORD_SIZE - 1: 0] bottom_out;

    //Output buses for MACs
    //out_bus[WORD_SIZE-1:0]
    wire [(3 * WORD_SIZE) - 1: 0] right_out_bus;  //right_out of all MACs
    wire [(3 * WORD_SIZE) - 1: 0] bottom_out_bus;  //bottom_out of all MACs

    wire [WORD_SIZE - 1: 0] mac0_right;
    wire [WORD_SIZE - 1: 0] mac0_bottom;

    wire [WORD_SIZE - 1: 0] mac1_right;
    wire [WORD_SIZE - 1: 0] mac1_bottom;

    wire [WORD_SIZE - 1: 0] mac2_right;
    wire [WORD_SIZE - 1: 0] mac2_bottom;

    genvar x;
    generate
        for(x = 0; x < 3; x = x+1) begin : tmr_mac_genblk
            traditional_mac tmr_mac(
                clk,
                rst, 
                fsm_op2_select_in,
                fsm_out_select_in,
                stat_bit_in,
                `ifdef ENABLE_FI
                    fault_inject_bus[x*2 +: 2],
                `endif
                left_in,
                top_in, 
                right_out_bus[(x * WORD_SIZE) +: (WORD_SIZE)],
                bottom_out_bus[(x * WORD_SIZE) +: (WORD_SIZE)]
            );
        end
    endgenerate

    assign {mac2_right, mac1_right, mac0_right} = right_out_bus;
    assign {mac2_bottom, mac1_bottom, mac0_bottom} = bottom_out_bus;

    assign bottom_out = ((mac1_bottom == mac0_bottom) || (mac1_bottom == mac0_bottom)) ? mac0_bottom :
                        (((mac2_bottom == mac1_bottom) || (mac0_bottom == mac1_bottom)) ? mac1_bottom :
                        (((mac1_bottom == mac2_bottom) || (mac0_bottom == mac2_bottom)) ? mac2_bottom : {WORD_SIZE{1'b0}}));
    
    assign right_out = ((mac1_right == mac0_right) || (mac1_right == mac0_right)) ? mac0_right :
                        (((mac2_right == mac1_right) || (mac0_right == mac1_right)) ? mac1_right :
                        (((mac1_right == mac2_right) || (mac0_right == mac2_right)) ? mac2_right : {WORD_SIZE{1'b0}}));

endmodule
