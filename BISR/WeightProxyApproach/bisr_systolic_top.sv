`include "./header_ws.vh"

module bisr_systolic_top
#(
    parameter ROWS = `ROWS,
    parameter COLS = `COLS,
    parameter WORD_SIZE = `WORD_SIZE
) (
    //Inputs to top module
    clk,
    rst,
    // top_matrix,   //Refactored to grabbing inputs from RAM
    // left_matrix,
    inputs_rdy,

    start_fsm,
    start_matmul,
    fsm_rdy,

    `ifdef ENABLE_STW
    STW_complete,
    STW_result_mat,
    `endif
    
    //Top module outputs
    // output_matrix,

    //Addresses/Signals for read/write from Input RAM
    mem_rd_data,
    mem_addr,
    mem_wr_en,

    //Addresses/Signals for read/write from Output RAM
    output_mem_wr_data,
    output_mem_addr,
    output_mem_wr_en
);
    input clk;
    input rst;   //Active-high reset

    // input [ROWS * COLS * WORD_SIZE - 1 : 0] top_matrix;
    // input logic [WORD_SIZE:0] left_matrix[ROWS][COLS];
    
    input inputs_rdy;   //Input matrices in memory, matmul can begin anytime

    input logic start_fsm, start_matmul;
    output logic fsm_rdy;
    logic fsm_done;
    // assign start_fsm = inputs_rdy;   //NOTE: Double-check if this is always true

    //Systolic control settings
    logic set_stationary;
    logic ctl_dummy_fsm_out_select_in;
    logic ctl_stat_bit_in;

    //Left_in/top_in to systolic for this clk cycle
    logic [ROWS * WORD_SIZE - 1: 0] curr_cycle_left_in;
    logic [COLS * WORD_SIZE - 1: 0] top_in_bus;
    // logic [ROWS * WORD_SIZE - 1: 0] left_in_bus;

    //Input to fsm: Bottom_out outputs from bottom of systolic @current clk cycle
    logic [COLS * WORD_SIZE - 1: 0] sa_curr_bottom_out;  

    //Right_out/bottom_out outputs from systolic for this clk cycle
    logic [ROWS * WORD_SIZE - 1: 0] right_out_bus;
    // logic [COLS * WORD_SIZE - 1: 0] bottom_out_bus;

    //Matmul FSM Outputs
    logic[COLS * WORD_SIZE-1:0] matmul_output;   //Bottom_out of systolic
    logic [COLS-1:0] output_col_valid;   //If output_col_valid[i] == 1, then bottom_out of column i is valid

    //Signals for Fault Injection
    `ifdef ENABLE_FI
        logic [(ROWS * COLS * 2) - 1:0] fault_inject_bus = 0;
        logic [ROWS-1:0] fi_row;   //row to inject fault
        logic [COLS-1:0] fi_col;   //col to inject fault
    `endif

    //Signals for Stop-the-World Self-test/diagnosis
    `ifdef ENABLE_STW
        //STW inputs
        // logic STW_test_load_en;
        // logic [WORD_SIZE-1:0] STW_mult_op1;
        // logic [WORD_SIZE-1:0] STW_mult_op2;
        // logic [WORD_SIZE-1:0] STW_add_op;
        // logic [WORD_SIZE-1:0] STW_expected;
        // logic STW_start;
        //outputs
        output logic STW_complete;
        output logic [(ROWS * COLS)-1:0] STW_result_mat;

        logic stw_en;   //Signal from fsm to run STW

    //    assign {STW_mult_op1, STW_mult_op2, STW_add_op, STW_expected} = {`stw_mult_op1, `stw_mult_op2, `stw_add_op, `stw_expected_out};
    `endif


    //Outputs from Proxy BISR
    `ifdef ENABLE_WPROXY
        logic [COLS-1:0] proxy_out_valid_bus;   //Indicates if proxy of each col has valid output
        logic [(COLS*WORD_SIZE)-1: 0] proxy_output_bus;   //Output bus containing bottom_out of proxy from each col
    `endif

    logic set_stat_start;
    output logic [31:0] mem_addr;
    output logic mem_wr_en;
    input logic [`MEM_PORT_WIDTH-1:0] mem_rd_data;
    logic stall;

    logic wr_output_rdy, wr_output_done;

    systolic_matmul_fsm #(
        .ROWS(ROWS),
        .COLS(COLS),
        .WORD_SIZE(WORD_SIZE),
        .MEM_ACCESS_LATENCY(`MEM_ACCESS_LATENCY)
    ) matmul_fsm (
        .clk(clk),
        .rst(rst),
        .stall(stall),

        .set_stat_start(set_stat_start),

        //Matmul inputs
        // .top_matrix(top_matrix),
        // .left_matrix(left_matrix),

        //Start/done signals for fsm stages
        .start_fsm(start_fsm),
        .start_matmul(start_matmul),
        .stw_en(stw_en),
        .fsm_done(fsm_done),
        .fsm_rdy(fsm_rdy),
        .wr_output_rdy(wr_output_rdy),
        .wr_output_done(wr_output_done),
        .STW_complete(STW_complete),

        //Input: Bottom_out outputs from bottom of systolic @current clk cycle
        .bottom_out(sa_curr_bottom_out),

        //Output Systolic Control signals
        .set_stationary(set_stationary),
        .fsm_out_select_in(ctl_dummy_fsm_out_select_in),
        .stat_bit_in(ctl_stat_bit_in),

        //Output: top_in & left_in to systolic array @current clk cycle
        .top_in_bus(top_in_bus),
        .curr_cycle_left_in(curr_cycle_left_in),

        //Matmul fsm Outputs
        .matmul_output(matmul_output),
        .output_col_valid(output_col_valid),   //If output_col_valid[i] == 1, then bottom_out of column i is valid

        .mem_rd_data(mem_rd_data),
        .mem_addr(mem_addr),
        .mem_wr_en(mem_wr_en)
    );

    // output logic [WORD_SIZE - 1:0] output_matrix[ROWS][COLS];
    // logic [WORD_SIZE - 1:0] output_matrix[ROWS][COLS];
    
    output logic [31:0] output_mem_addr;
    output logic output_mem_wr_en;
    output logic [`MEM_PORT_WIDTH-1:0] output_mem_wr_data;
    

    matmul_output_control #(
        .ROWS(ROWS),
        .COLS(COLS),
        .WORD_SIZE(WORD_SIZE),
        .MEM_ACCESS_LATENCY(`MEM_ACCESS_LATENCY)
    ) matmul_out_dut(
        .clk(clk),
        .rst(rst),
        .stall(stall),
        .fsm_rdy(fsm_rdy),
        .fsm_done(fsm_done),
        .matmul_fsm_output(matmul_output),
        `ifdef ENABLE_WPROXY
            .proxy_output_bus(proxy_output_bus),
            .proxy_out_valid_bus(proxy_out_valid_bus),
        `endif
        .matmul_output_valid(output_col_valid),
        // .output_matrix(output_matrix),
        .wr_output_rdy(wr_output_rdy),
        .wr_output_done(wr_output_done),
        .mem_addr(output_mem_addr),
        .mem_wr_en(output_mem_wr_en),
        .mem_data(output_mem_wr_data)
    );


  `ifdef ENABLE_FI
      localparam NUM_FAULTS = 4;
      logic [(`ROWS*NUM_FAULTS)-1:0] fi_row_arr = {`ROWS'd1, `ROWS'd2, `ROWS'd3, `ROWS'd0};
      logic [(`COLS*NUM_FAULTS)-1:0] fi_col_arr = {`COLS'd0, `COLS'd1, `COLS'd2, `COLS'd3};
  
      initial begin
          for(integer f = 0; f < NUM_FAULTS; f++) begin
                fi_row = fi_row_arr[(f*`ROWS) +: `ROWS];
                fi_col = fi_col_arr[(f*`COLS) +: `COLS];
            //   fi_row = fi_row_arr[f];
            //   fi_col = fi_col_arr[f];
              fault_inject_bus[(fi_col*`ROWS+fi_row)*2 +: 2] = 2'b11;
              $display("Injected fault at col %0d, row %0d", fi_col, fi_row);
          end
      end
  `endif

    
    stw_wproxy_systolic #(
        .ROWS(ROWS),
        .COLS(COLS),
        .WORD_SIZE(WORD_SIZE)
    ) stw_proxy_systolic (
        .clk(clk),
        .rst(rst),
        .stall(stall),

        .set_stat_start(set_stat_start),

        .ctl_stat_bit_in(ctl_stat_bit_in), 
        .ctl_dummy_fsm_op2_select_in(set_stationary),
        .ctl_dummy_fsm_out_select_in(ctl_dummy_fsm_out_select_in),

        `ifdef ENABLE_FI
            .fault_inject_bus(fault_inject_bus),
        `endif

        `ifdef ENABLE_STW
            // .STW_test_load_en(STW_test_load_en),
            // .STW_mult_op1(STW_mult_op1),
            // .STW_mult_op2(STW_mult_op2),
            // .STW_add_op(STW_add_op),
            // .STW_expected(STW_expected),
            // .STW_start(STW_start),
            .STW_complete_out(STW_complete),
            .STW_result_mat(STW_result_mat),
            .stw_en(stw_en),
        `endif
        `ifdef ENABLE_WPROXY
            .proxy_output_bus(proxy_output_bus),
            .proxy_out_valid_bus(proxy_out_valid_bus),
        `endif
        //Left_in/top_in inputs to systolic
        .left_in_bus(curr_cycle_left_in),
        .top_in_bus(top_in_bus),

        //Right_out/bottom_out outputs from systolic
        .bottom_out_bus(sa_curr_bottom_out),
        .right_out_bus(right_out_bus)
    );


     

endmodule