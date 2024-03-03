
`include "./header_ws.vh"   //Enable header_ws for weight-stationary tb
`include "./traditional_mac_stw.v"

// `define ENABLE_FI
// `define ENABLE_STW

module traditional_systolic_stw
#(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter WORD_SIZE = 16

) (
    clk,
    rst,

    ctl_stat_bit_in, 
    ctl_dummy_fsm_op2_select_in,
    ctl_dummy_fsm_out_select_in,
    `ifdef ENABLE_FI
        fault_inject_bus,
    `endif
    `ifdef ENABLE_STW
        STW_mult_op1,
        STW_mult_op2,
        STW_add_op,
        STW_expected,
        STW_test_load_en,
        STW_start,
        STW_complete_out,
        STW_result_mat,
    `endif
    left_in_bus,
    top_in_bus,
    bottom_out_bus,
    right_out_bus
);

input clk;
input rst;

input [ROWS * WORD_SIZE - 1: 0] left_in_bus;
input [COLS * WORD_SIZE - 1: 0] top_in_bus;
output [COLS * WORD_SIZE - 1: 0] bottom_out_bus;
output [ROWS * WORD_SIZE - 1: 0] right_out_bus;

input ctl_stat_bit_in; 
input ctl_dummy_fsm_op2_select_in;
input ctl_dummy_fsm_out_select_in;

`ifdef ENABLE_FI
    input [(ROWS * COLS * 2) - 1:0] fault_inject_bus; //total size = ROWS*COLS*(2bits per mac)
`endif

`ifdef ENABLE_STW
    input [WORD_SIZE-1:0] STW_mult_op1;
    input [WORD_SIZE-1:0] STW_mult_op2;
    input [WORD_SIZE-1:0] STW_add_op;
    input [WORD_SIZE-1:0] STW_expected;
    input STW_test_load_en;
    input STW_start;
    output STW_complete_out;
    output [(ROWS*COLS)-1:0] STW_result_mat; //[COLS-1:0];
    
    wire [(ROWS*COLS)-1:0] STW_complete;
    assign STW_complete_out = &STW_complete;
`endif

wire [ROWS * COLS * WORD_SIZE - 1: 0] hor_interconnect;
wire [COLS * ROWS * WORD_SIZE - 1: 0] ver_interconnect;

genvar r, c;
generate
for (r = 0; r < ROWS; r = r + 1) begin : right_out_genblk
    assign right_out_bus[(r+1) * WORD_SIZE - 1 -: WORD_SIZE] = hor_interconnect[r * COLS * WORD_SIZE + COLS * WORD_SIZE - 1 -: WORD_SIZE];
end 

for (c  = 0; c < COLS; c = c + 1) begin : bottom_out_genblk
    assign bottom_out_bus[(c+1) * WORD_SIZE - 1 -: WORD_SIZE] = ver_interconnect[(ROWS * c + ROWS) * WORD_SIZE - 1 -: WORD_SIZE];
end

//Added naming for generate blocks and renamed MAC modules for ease of hierarchical reference in tb
for(r = 0; r < ROWS; r = r+1) begin : mac_row_genblk
    for(c = 0; c < COLS; c = c+1) begin : mac_col_genblk
        localparam VERTICAL_SIGNAL_OFFSET = (c * ROWS + (r+1)) * WORD_SIZE;
        localparam HORIZONTAL_SIGNAL_OFFSET = (r * COLS + (c+1)) * WORD_SIZE;

        if ((r == 0) && (c==0))
        begin : rc
            
            pe_stw #(
                .WORD_SIZE(WORD_SIZE)
            ) u_mac(
                .clk(clk),
                .rst(rst),
                .fsm_op2_select_in(ctl_dummy_fsm_op2_select_in),
                .fsm_out_select_in(ctl_dummy_fsm_out_select_in),
                .stat_bit_in(ctl_stat_bit_in),
                `ifdef ENABLE_FI
                    .fault_inject(fault_inject_bus[(c*ROWS+r)*2 +: 2]),
                `endif
                `ifdef ENABLE_STW
                    .STW_test_load_en(STW_test_load_en),
                    .STW_mult_op1(STW_mult_op1),
                    .STW_mult_op2(STW_mult_op2),
                    .STW_add_op(STW_add_op),
                    .STW_expected(STW_expected),
                    .STW_start(STW_start),
                    .STW_complete(STW_complete[(r*COLS)+c]),
                    .STW_result_out(STW_result_mat[(r*COLS)+c]),
                `endif
                .left_in(left_in_bus[(r+1) * WORD_SIZE -1 -: WORD_SIZE]),
                .top_in(top_in_bus[(c+1) * WORD_SIZE - 1 -: WORD_SIZE]),
                .right_out(hor_interconnect[HORIZONTAL_SIGNAL_OFFSET - 1 -: WORD_SIZE]),
                .bottom_out(ver_interconnect[VERTICAL_SIGNAL_OFFSET -1 -: WORD_SIZE])
            );

        end
        else if (c==0)
        begin : rc

            localparam TOP_PEER_OFFSET = (c * ROWS + r) * WORD_SIZE;

            pe_stw #(
                .WORD_SIZE(WORD_SIZE)
            ) u_mac(
                .clk(clk),
                .rst(rst),
                .fsm_op2_select_in(ctl_dummy_fsm_op2_select_in),
                .fsm_out_select_in(ctl_dummy_fsm_out_select_in),
                .stat_bit_in(ctl_stat_bit_in),
                `ifdef ENABLE_FI
                    .fault_inject(fault_inject_bus[(c*ROWS+r)*2 +: 2]),
                `endif
                `ifdef ENABLE_STW
                    .STW_test_load_en(STW_test_load_en),
                    .STW_mult_op1(STW_mult_op1),
                    .STW_mult_op2(STW_mult_op2),
                    .STW_add_op(STW_add_op),
                    .STW_expected(STW_expected),
                    .STW_start(STW_start),
                    .STW_complete(STW_complete[(r*COLS)+c]),
                    .STW_result_out(STW_result_mat[(r*COLS)+c]),
                `endif
                .left_in(left_in_bus[(r+1) * WORD_SIZE -1 -: WORD_SIZE]),
                .top_in(ver_interconnect[TOP_PEER_OFFSET -1 -: WORD_SIZE]),
                .right_out(hor_interconnect[HORIZONTAL_SIGNAL_OFFSET -1 -: WORD_SIZE]),
                .bottom_out(ver_interconnect[VERTICAL_SIGNAL_OFFSET -1 -: WORD_SIZE])
            );
        end
        else if (r==0)
        begin : rc

            localparam LEFT_PEER_OFFSET = (r * COLS + c) * WORD_SIZE;

            pe_stw #(
                .WORD_SIZE(WORD_SIZE)
            ) u_mac(
                .clk(clk),
                .rst(rst),
                .fsm_op2_select_in(ctl_dummy_fsm_op2_select_in),
                .fsm_out_select_in(ctl_dummy_fsm_out_select_in),
                .stat_bit_in(ctl_stat_bit_in),
                `ifdef ENABLE_FI
                    .fault_inject(fault_inject_bus[(c*ROWS+r)*2 +: 2]),
                `endif
                `ifdef ENABLE_STW
                    .STW_test_load_en(STW_test_load_en),
                    .STW_mult_op1(STW_mult_op1),
                    .STW_mult_op2(STW_mult_op2),
                    .STW_add_op(STW_add_op),
                    .STW_expected(STW_expected),
                    .STW_start(STW_start),
                    .STW_complete(STW_complete[(r*COLS)+c]),
                    .STW_result_out(STW_result_mat[(r*COLS)+c]),
                `endif
                .left_in(hor_interconnect[LEFT_PEER_OFFSET - 1 -: WORD_SIZE]),
                .top_in(top_in_bus[(c+1) * WORD_SIZE - 1 -: WORD_SIZE]),
                .right_out(hor_interconnect[HORIZONTAL_SIGNAL_OFFSET -1 -: WORD_SIZE]),
                .bottom_out(ver_interconnect[VERTICAL_SIGNAL_OFFSET -1 -: WORD_SIZE])
            );
        end
        else
        begin : rc

            localparam TOP_PEER_OFFSET =  (c * ROWS + r)  * WORD_SIZE;
            localparam LEFT_PEER_OFFSET = (r * COLS + c) * WORD_SIZE;
            
            pe_stw #(
                .WORD_SIZE(WORD_SIZE)
            ) u_mac(
                .clk(clk),
                .rst(rst),
                .fsm_op2_select_in(ctl_dummy_fsm_op2_select_in),
                .fsm_out_select_in(ctl_dummy_fsm_out_select_in),
                .stat_bit_in(ctl_stat_bit_in),
                `ifdef ENABLE_FI
                    .fault_inject(fault_inject_bus[(c*ROWS+r)*2 +: 2]),
                `endif
                `ifdef ENABLE_STW
                    .STW_test_load_en(STW_test_load_en),
                    .STW_mult_op1(STW_mult_op1),
                    .STW_mult_op2(STW_mult_op2),
                    .STW_add_op(STW_add_op),
                    .STW_expected(STW_expected),
                    .STW_start(STW_start),
                    .STW_complete(STW_complete[(r*COLS)+c]),
                    .STW_result_out(STW_result_mat[(r*COLS)+c]),
                `endif
                .left_in(hor_interconnect[LEFT_PEER_OFFSET - 1 -: WORD_SIZE]),
                .top_in(ver_interconnect[TOP_PEER_OFFSET -1 -: WORD_SIZE]),
                .right_out(hor_interconnect[HORIZONTAL_SIGNAL_OFFSET -1 -: WORD_SIZE]),
                .bottom_out(ver_interconnect[VERTICAL_SIGNAL_OFFSET -1 -: WORD_SIZE])
            );
        end
    end
end
endgenerate

endmodule
