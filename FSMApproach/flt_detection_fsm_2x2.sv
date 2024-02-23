`define WORD_SIZE 16
`define ROWS 2
`define COLS 2 

module flt_fsm
#(
    parameter ROWS = 32,
    parameter COLS = 32,
    parameter WORD_SIZE = 16
)(
    clk,
    rst,

    ctl_stat_bit_in, 
    ctl_dummy_fsm_op2_select_in,
    ctl_dummy_fsm_out_select_in,

    left_in_bus,
    top_in_bus,
    bottom_out_bus,
    right_out_bus,

    fail
); 

    input clk;
    input rst;

    input ctl_stat_bit_in; 
    input ctl_dummy_fsm_op2_select_in;
    input ctl_dummy_fsm_out_select_in;

    input [ROWS * WORD_SIZE - 1: 0] left_in_bus;
    input [COLS * WORD_SIZE - 1: 0] top_in_bus;
    output [COLS * WORD_SIZE - 1: 0] bottom_out_bus;
    output [ROWS * WORD_SIZE - 1: 0] right_out_bus;

    output fail;

    reg fail = 0;

    wire [ROWS * COLS * WORD_SIZE - 1: 0] hor_interconnect;
    wire [COLS * ROWS * WORD_SIZE - 1: 0] ver_interconnect;

    reg [WORD_SIZE - 1: 0] rmac_left_in;
    reg [WORD_SIZE - 1: 0] rmac_top_in;
    wire [WORD_SIZE - 1: 0] rmac_right_out;
    wire [WORD_SIZE - 1: 0] rmac_bottom_out;

    fsm_systolic #(`ROWS, `COLS, `WORD_SIZE) SA (
        clk,
        rst,

        ctl_stat_bit_in, 
        ctl_dummy_fsm_op2_select_in,
        ctl_dummy_fsm_out_select_in,
        left_in_bus,
        top_in_bus,
        bottom_out_bus,
        right_out_bus,

        rmac_left_in,
        rmac_top_in,
        rmac_right_out,
        rmac_bottom_out,

        hor_interconnect,
        ver_interconnect
    );

    logic [2:0] state, next_state;
    logic [2:0] WAIT_STATE = 3'b000;
    logic [2:0] CHECK_OUT = 3'b001;
    logic [2:0] TEST_00 = 3'b010;
    logic [2:0] TEST_01 = 3'b011;
    logic [2:0] TEST_10 = 3'b100;
    logic [2:0] TEST_11 = 3'b101;
    logic [1:0] counter;
    logic [1:0] ns_count;
    logic [WORD_SIZE-1:0] mac_out;
    logic ready = 0;
    
    always_ff @(clk) begin 
        if (rst)
            state <= TEST_00;
        else   
            state <= next_state;

        if (state == WAIT_STATE) begin
            if (counter == 2'b11) begin
                counter <= 0;
                ready <= 1;
            end
            else begin 
                counter <= counter + 1;
                ready <= 0;
            end
        end
    end

    always_comb begin
        case(state)
            TEST_00: begin   
                ns_count = 2'b01;
                rmac_left_in = left_in_bus[15:0];
                rmac_top_in = top_in_bus[15:0];
                mac_out = ver_interconnect[15:0];
                next_state = WAIT_STATE;
            end
            TEST_01: begin 
                ns_count = 2'b10;
                rmac_left_in = hor_interconnect[15:0];
                rmac_top_in = top_in_bus[31:16];
                mac_out = ver_interconnect[47:32];
                next_state = WAIT_STATE;
            end
            TEST_10: begin 
                ns_count = 2'b11;
                rmac_left_in = left_in_bus[31:16];
                rmac_top_in = ver_interconnect[15:0];
                mac_out = ver_interconnect[31:16];
                next_state = WAIT_STATE;
            end
            TEST_11: begin 
                ns_count = 2'b00;
                rmac_left_in = hor_interconnect[47:32];
                rmac_top_in = top_in_bus[47:32];
                mac_out = ver_interconnect[63:48];
                next_state = WAIT_STATE;
            end 
            WAIT_STATE: begin 
                if (ready) next_state = CHECK_OUT;
                else next_state = WAIT_STATE;
            end
            CHECK_OUT: begin 
                if (mac_out == rmac_bottom_out) begin 
                    case(ns_count)
                        2'b00: next_state = TEST_00; 
                        2'b01: next_state = TEST_01;
                        2'b10: next_state = TEST_10;
                        2'b11: next_state = TEST_11;
                    endcase
                end
                else
                    fail = 1;
            end
        endcase
    end



endmodule
