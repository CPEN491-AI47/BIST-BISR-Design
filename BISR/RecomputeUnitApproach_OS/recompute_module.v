// Columns of recompute units 
`include "./header.vh"   //Enable header_ws for weight-stationary tb
module recompute_module
#(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter WORD_SIZE = 16,
    parameter NUM_RU = 4   //Number of redundant units
)(
    clk,
    rst,
    ru_en,
    ru_top_inputs,
    ru_left_inputs,
    ru_set_stationary,
    ru_fsm_out_sel_in,
    ru_stat_bit_in,
    ru_col_mapping,

    rcm_bottom_out
);

    input clk, rst;
    input [NUM_RU-1:0] ru_en;
    input [NUM_RU * WORD_SIZE - 1 : 0] ru_top_inputs;
    input [NUM_RU * WORD_SIZE - 1 : 0] ru_left_inputs;
    input [NUM_RU-1:0] ru_set_stationary;
    input [NUM_RU-1:0] ru_fsm_out_sel_in;
    input [NUM_RU-1:0] ru_stat_bit_in;

    localparam NUM_BITS_COLS = $clog2(COLS);
    input [(NUM_BITS_COLS*NUM_RU)-1:0] ru_col_mapping;

    output [(NUM_RU*WORD_SIZE)-1:0] rcm_bottom_out;

    reg [NUM_BITS_COLS-1:0] ru_col_map_reg [NUM_RU-1:0];   //Reg file with NUM_RU entries of size NUM_BITS_COLS each

    //Instantiate redundant PEs
    genvar ru_idx;
    generate
    for(ru_idx = 0; ru_idx < NUM_RU; ru_idx=ru_idx+1) begin
         traditional_mac #(
            .WORD_SIZE(WORD_SIZE)
        ) ru_cr (
            .clk(clk),
            .rst(rst),
            .fsm_op2_select_in(ru_set_stationary[ru_idx]),
            .fsm_out_select_in(ru_fsm_out_sel_in[ru_idx]),
            .stat_bit_in(ru_stat_bit_in[ru_idx]),
            `ifdef ENABLE_FI
                .fault_inject(2'b00),
            `endif
            //changing oritentation
            .left_in(ru_left_inputs[(ru_idx+1) * WORD_SIZE -1 -: WORD_SIZE]),
            .top_in(ru_top_inputs[(ru_idx+1) * WORD_SIZE -1 -: WORD_SIZE]),
            .right_out(),   //Redundant units already placed at bottom of systolic: right_out doesn't need to be passed any further
            .bottom_out(rcm_bottom_out[((ru_idx+1)*WORD_SIZE)-1 -: WORD_SIZE])
        );

        //Update RU->col mapping reg file
        // always @(ru_en[ru_idx]) begin   //Clocked by ru_en of corresponding RU
        //     ru_col_map_reg[ru_idx] <= ru_col_mapping[(ru_idx*NUM_BITS_COLS) +: NUM_BITS_COLS]; //FIXME: Continue here - How to use mapping to change bottom_out
        // end
    end
    endgenerate

    // genvar ru_idx;
    // generate
    // for(c = 0; c < COLS; c = c+1) begin
    //     traditional_mac #(
    //         .WORD_SIZE(WORD_SIZE)
    //     ) ru_cr (
    //         .clk(clk),
    //         .rst(rst),
    //         .fsm_op2_select_in(ru_set_stationary[c]),
    //         .fsm_out_select_in(ru_fsm_out_sel_in[c]),
    //         .stat_bit_in(ru_stat_bit_in[c]),
    //         `ifdef ENABLE_FI
    //             .fault_inject(2'b0),
    //         `endif
    //         .left_in(ru_left_inputs[(c*WORD_SIZE) +: WORD_SIZE]),
    //         .top_in(ru_top_inputs[(c*WORD_SIZE) +: WORD_SIZE]),
    //         .right_out(),   //Redundant units already placed at bottom of systolic: right_out doesn't need to be passed any further
    //         .bottom_out(ru_bottom_out[(c*WORD_SIZE) +: WORD_SIZE])
    //     );

    //     //Assign bottom_out to take either output from RU (if error detected - ru_en == 1) or original systolic
    //     assign rcm_bottom_out[(c*WORD_SIZE) +: WORD_SIZE] = ru_en[c] ? ru_bottom_out[(c*WORD_SIZE) +: WORD_SIZE] : systolic_bottom_out[(c*WORD_SIZE) +: WORD_SIZE];
    // end
    // endgenerate

endmodule