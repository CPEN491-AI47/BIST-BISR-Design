module systolic_array_top ( clk, resetn, start_fsm, start_matmul, fsm_done,
    iact_clk, iact_rst, iact_we, iact_addr, iact_din, iact_dout,
    wt_clk, wt_rst, wt_we, wt_addr, wt_din, wt_dout,
    oact_clk, oact_rst, oact_we, oact_addr, oact_din, oact_dout );

    parameter ROWS = 4,
              COLS = 4,
              WORD_SIZE = 16,
              NUM_RU = 4,
              INPUT_ADDR_WIDTH = 2;

    input clk;
    input resetn;
    input start_fsm;
    input start_matmul;
    output fsm_done;

    output iact_clk;
    output iact_rst;
    output iact_we;
    output [INPUT_ADDR_WIDTH-1:0] iact_addr;
    output [ROWS*WORD_SIZE-1:0] iact_din;
    input [ROWS*WORD_SIZE-1:0] iact_dout;

    output wt_clk;
    output wt_rst;
    output wt_we;
    output [INPUT_ADDR_WIDTH-1:0] wt_addr;
    output [ROWS*WORD_SIZE-1:0] wt_din;
    input [ROWS*WORD_SIZE-1:0] wt_dout;

    output oact_clk;
    output oact_rst;
    output oact_we;
    output [INPUT_ADDR_WIDTH-1:0] oact_addr;
    output [ROWS*WORD_SIZE-1:0] oact_din;
    input [ROWS*WORD_SIZE-1:0] oact_dout;


    assign iact_clk = clk;
    assign wt_clk = clk;
    assign oact_clk = clk;

    assign iact_rst = ~resetn;
    assign wt_rst = ~resetn;
    assign oact_rst = ~resetn;

endmodule