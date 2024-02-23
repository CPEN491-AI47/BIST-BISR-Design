`define WORD_SIZE 16
`define ROWS 4
`define COLS 4 

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

    logic [4:0] state, next_state;

    logic [4:0] WAIT_STATE = 5'b00000;
    logic [4:0] CHECK_OUT = 5'b00001;

    logic [4:0] TEST_00 = 5'b00010;
    logic [4:0] TEST_01 = 5'b00011;
    logic [4:0] TEST_02 = 5'b00100;
    logic [4:0] TEST_03 = 5'b00101;

    logic [4:0] TEST_10 = 5'b00110;
    logic [4:0] TEST_11 = 5'b00111;
    logic [4:0] TEST_12 = 5'b01000;
    logic [4:0] TEST_13 = 5'b01001;

    logic [4:0] TEST_20 = 5'b01010;
    logic [4:0] TEST_21 = 5'b01011;
    logic [4:0] TEST_22 = 5'b01100;
    logic [4:0] TEST_23 = 5'b01101;

    logic [4:0] TEST_30 = 5'b01110;
    logic [4:0] TEST_31 = 5'b01111;
    logic [4:0] TEST_32 = 5'b10000;
    logic [4:0] TEST_33 = 5'b10001;

    logic [1:0] counter;
    logic [3:0] ns_count;
    logic [WORD_SIZE-1:0] mac_out;
    logic ready = 0;

    
    always_ff @(clk) begin 
        
        if (rst)
            state <= TEST_00;
        else   
            state <= next_state;

        if (state == WAIT_STATE) begin
            if (counter == 2'b11) begin
                counter = 0;
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
                ns_count = 4'b0001;
                rmac_left_in = left_in_bus[15:0];
                rmac_top_in = top_in_bus[15:0];
                mac_out = ver_interconnect[15:0];
                next_state = WAIT_STATE; 
            end
            
            TEST_01: begin   
                ns_count = 4'b0010;
                rmac_left_in = hor_interconnect[15:0];
                rmac_top_in = top_in_bus[31:16];
                mac_out = ver_interconnect[79:64];
                next_state = WAIT_STATE; 
            end

            TEST_02: begin   
                ns_count = 4'b0011;
                rmac_left_in = hor_interconnect[31:16];
                rmac_top_in = top_in_bus[47:32];
                mac_out = ver_interconnect[143:128];
                next_state = WAIT_STATE; 
            end

            TEST_03: begin   
                ns_count = 4'b0100;
                rmac_left_in = hor_interconnect[47:32];
                rmac_top_in = top_in_bus[63:48];
                mac_out = ver_interconnect[207:192];
                next_state = WAIT_STATE; 
            end

            TEST_10: begin   
                ns_count = 4'b0101;
                rmac_left_in = left_in_bus[31:16];
                rmac_top_in = ver_interconnect[15:0];
                mac_out = ver_interconnect[31:16];
                next_state = WAIT_STATE; 
            end

            TEST_11: begin   
                ns_count = 4'b0110;
                rmac_left_in = hor_interconnect[79:64];
                rmac_top_in = top_in_bus[79:64];
                mac_out = ver_interconnect[95:80];
                next_state = WAIT_STATE; 
            end

            TEST_12: begin   
                ns_count = 4'b0111;
                rmac_left_in = hor_interconnect[95:80];
                rmac_top_in = top_in_bus[143:128];
                mac_out = ver_interconnect[159:144];
                next_state = WAIT_STATE; 
            end
            
            TEST_13: begin   
                ns_count = 4'b1000;
                rmac_left_in = hor_interconnect[111:96];
                rmac_top_in = top_in_bus[207:192];
                mac_out = ver_interconnect[223:208];
                next_state = WAIT_STATE; 
            end

            TEST_20: begin   
                ns_count = 4'b1001;
                rmac_left_in = left_in_bus[47:32];
                rmac_top_in = ver_interconnect[31:16];
                mac_out = ver_interconnect[47:32];
                next_state = WAIT_STATE; 
            end

            TEST_21: begin   
                ns_count = 4'b1010;
                rmac_left_in = hor_interconnect[143:128];
                rmac_top_in = top_in_bus[95:80];
                mac_out = ver_interconnect[111:96];
                next_state = WAIT_STATE; 
            end

            TEST_22: begin   
                ns_count = 4'b1011;
                rmac_left_in = hor_interconnect[159:144];
                rmac_top_in = top_in_bus[159:144];
                mac_out = ver_interconnect[175:160];
                next_state = WAIT_STATE; 
            end

            TEST_23: begin   
                ns_count = 4'b1100;
                rmac_left_in = hor_interconnect[175:160];
                rmac_top_in = top_in_bus[223:208];
                mac_out = ver_interconnect[239:224];
                next_state = WAIT_STATE; 
            end

            TEST_30: begin   
                ns_count = 4'b1101;
                rmac_left_in = left_in_bus[63:48];
                rmac_top_in = ver_interconnect[47:32];
                mac_out = ver_interconnect[63:40];
                next_state = WAIT_STATE; 
            end

            TEST_31: begin   
                ns_count = 4'b1110;
                rmac_left_in = hor_interconnect[207:192];
                rmac_top_in = top_in_bus[111:96];
                mac_out = ver_interconnect[127:112];
                next_state = WAIT_STATE; 
            end

            TEST_32: begin   
                ns_count = 4'b1111;
                rmac_left_in = hor_interconnect[223:208];
                rmac_top_in = top_in_bus[175:160];
                mac_out = ver_interconnect[191:176];
                next_state = WAIT_STATE; 
            end

            TEST_33: begin   
                ns_count = 4'b0000;
                rmac_left_in = hor_interconnect[239:224];
                rmac_top_in = top_in_bus[239:224];
                mac_out = ver_interconnect[255:240];
                next_state = WAIT_STATE; 
            end

            WAIT_STATE: begin 
                if (ready) next_state = CHECK_OUT;
                else next_state = WAIT_STATE;
            end

            CHECK_OUT: begin 
                if (mac_out == rmac_bottom_out) begin 
                    case(ns_count)
                        4'b0000: next_state <= TEST_00;
                        4'b0001: next_state <= TEST_01; 
                        4'b0010: next_state <= TEST_02;
                        4'b0011: next_state <= TEST_03;

                        4'b0100: next_state <= TEST_10;
                        4'b0101: next_state <= TEST_11;
                        4'b0110: next_state <= TEST_12;
                        4'b0111: next_state <= TEST_13;

                        4'b1000: next_state <= TEST_20;
                        4'b1001: next_state <= TEST_21;
                        4'b1010: next_state <= TEST_22;
                        4'b1011: next_state <= TEST_23;

                        4'b1100: next_state <= TEST_30;
                        4'b1101: next_state <= TEST_31;
                        4'b1110: next_state <= TEST_32;
                        4'b1111: next_state <= TEST_33;
                    endcase
                end 
                else
                    fail = 1;
            end

        endcase
    
    end

endmodule
