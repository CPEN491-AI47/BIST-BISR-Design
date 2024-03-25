`include "./header.vh"
`include "./traditional_mac.v"

module traditional_systolic
#(
    parameter ROWS = 32,
    parameter COLS = 32,
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
            
            traditional_mac #(
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
                .left_in(left_in_bus[(r+1) * WORD_SIZE -1 -: WORD_SIZE]),
                .top_in(top_in_bus[(c+1) * WORD_SIZE - 1 -: WORD_SIZE]),
                .right_out(hor_interconnect[HORIZONTAL_SIGNAL_OFFSET - 1 -: WORD_SIZE]),
                .bottom_out(ver_interconnect[VERTICAL_SIGNAL_OFFSET -1 -: WORD_SIZE])
            );

        end
        else if (c==0)
        begin : rc

            localparam TOP_PEER_OFFSET = (c * ROWS + r) * WORD_SIZE;

            traditional_mac #(
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
                .left_in(left_in_bus[(r+1) * WORD_SIZE -1 -: WORD_SIZE]),
                .top_in(ver_interconnect[TOP_PEER_OFFSET -1 -: WORD_SIZE]),
                .right_out(hor_interconnect[HORIZONTAL_SIGNAL_OFFSET -1 -: WORD_SIZE]),
                .bottom_out(ver_interconnect[VERTICAL_SIGNAL_OFFSET -1 -: WORD_SIZE])
            );
        end
        else if (r==0)
        begin : rc

            localparam LEFT_PEER_OFFSET = (r * COLS + c) * WORD_SIZE;

            traditional_mac #(
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
            
            traditional_mac #(
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
