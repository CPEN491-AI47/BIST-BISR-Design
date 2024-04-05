`define WORD_SIZE 16
`define ROWS 4
`define COLS 4 
`define SEED 100

`define stw_mult_op1 `WORD_SIZE'd4
`define stw_mult_op2 `WORD_SIZE'd3
`define stw_add_op `WORD_SIZE'd1
`define stw_expected_out `WORD_SIZE'd13
// `define ENABLE_RANDOM
// `define ENABLE_TMR

`define ENABLE_FI
`define ENABLE_STW
`define ENABLE_WPROXY

`define MEM_ACCESS_LATENCY 2
`define TOP_MAT_BASE_ADDR 32'd0
`define LEFT_MAT_BASE_ADDR 32'd4
`define OUTPUT_MAT_BASE_ADDR 32'd11
`define MEM_PORT_WIDTH `COLS*`WORD_SIZE
`define MEM_ADDR_INCR 1   //Value in which curr_addr+MEM_ADDR_INCR = next addr