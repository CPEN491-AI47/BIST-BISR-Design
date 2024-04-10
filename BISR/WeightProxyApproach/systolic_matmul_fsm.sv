`include "./header_ws.vh"

//Reference for weight-stationary matmul: https://www.telesens.co/2018/07/30/systolic-architectures/
//Currently implemented based on weight-stationary dataflows

//Control flow for matrix multiplication of left_matrix * top_matrix
module systolic_matmul_fsm
#(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter WORD_SIZE = 16,
    parameter MEM_ACCESS_LATENCY = 2   //Delay for accessing RAM entries
)(
    clk,
    rst,
    stall,
    
    //Input matrices
    // top_matrix,
    // left_matrix,

    //Start/done signals
    start_fsm,
    bisr_en,
    stw_en,
    fsm_done,
    fsm_rdy,
    wr_output_rdy,
    wr_output_done,
    STW_complete,

    set_stat_start,

    //Output Control Signals
    set_stationary,
    fsm_out_select_in,
    stat_bit_in,

    //Output: top_in & left_in to systolic array @current clk cycle
    top_in_bus,
    curr_cycle_left_in,

    //Input: Outputs from bottom of systolic
    bottom_out,

    //Outputs
    matmul_output,
    output_col_valid,   //If output_col_valid[i] == 1, then bottom_out of column i is valid

    //Addresses/Signals for read/write from RAM
    mem_rd_data,
    mem_addr,
    mem_wr_en
);

    input clk;
    input rst;   //Active-high reset
    

    input start_fsm;
    input wr_output_rdy;
    input wr_output_done;
    input bisr_en;
    input STW_complete;
    output reg stw_en;
    output reg fsm_done;
    output reg fsm_rdy;

    output reg set_stat_start;

    output logic set_stationary;
    output logic fsm_out_select_in;
    output logic stat_bit_in;

    // input [ROWS * COLS * WORD_SIZE - 1 : 0] top_matrix;
    // input logic [WORD_SIZE:0] left_matrix[ROWS][COLS];
    output logic [COLS * WORD_SIZE - 1: 0] top_in_bus;
     
    //curr_cycle_left_in = left_in inputs to systolic for current clock cycle
    //For 2x2 systolic: 
    output logic [ROWS * WORD_SIZE - 1: 0] curr_cycle_left_in;

    input [COLS * WORD_SIZE - 1: 0] bottom_out;
    output logic[COLS * WORD_SIZE-1:0] matmul_output;
    output logic [COLS-1:0] output_col_valid = 0;
    
    logic [$clog2(ROWS):0] stat_op_row;
    logic [$clog2(ROWS)+3:0] num_op_cycles;   //Few extra bits to ensure num_op_cycles captures ((2 * ROWS) - 1) + ROWS + 1
    logic [$clog2(ROWS)+3:0] matmul_cycle;   //1 matmul_cycle = 2 clk cycles due to traditional_mac being double-buffered (see Note below)

    logic output_start;   //Asserted for 1 clk cycle when outputs begin

    logic [$clog2(COLS)-1:0] curr_output_idx;   //Column bottom_out with output for current clk cycle

    logic [$clog2(ROWS):0] left_in_row;
    logic [$clog2(COLS):0] bottom_out_col;

    //Addresses/Signals for read/write from RAM
    output logic [31:0] mem_addr;
    output logic mem_wr_en;
    input logic [`MEM_PORT_WIDTH-1:0] mem_rd_data;
    logic [2:0] mem_delay;   //Num clk cycles left to stall until memory access value available
    output logic stall;

    //Note: traditional_mac has 2 regs (double-buffered). Thus it takes 2 clk cycles (1 matmul_cycle = 2 clk cycles) for each PE to produce a bottom_out output
    //So MATMUL has 2 stages for stalling
    enum {INIT, RUN_STW1, RUN_STW2, RUN_STW3, SET_STATIONARY, READ_TOP_MAT, READ_TOP_MAT2, MATMUL1, MATMUL2, READ_LEFT_MAT, FINISH} state;

    assign matmul_output = bottom_out;   //Matrix multiplication output = bottom_out of systolic: Which part of bottom_out are valid outputs will be set by output_col_valid

    logic set_stat_done;
    //Control flow for setting stationary regs + Producing matrix multiplication outputs from systolic
    always_ff @(posedge clk) begin
        if(rst) begin
            fsm_done <= 0;
            fsm_rdy <= 1;
            set_stat_start <= 0;
            set_stat_done <= 0;
            stall <= 0;
            state <= INIT;
        end
        else begin
            case(state)
                INIT: begin
                    set_stationary <= 1'b1;
                    stat_op_row <= ROWS;
                    fsm_out_select_in <= 1'b0;
                    //For weight-stationary matmul of N*N matrix, requires 2N-1 cycles to read in all vals -> last val read in clk 2N-1
                    //Product using last val must propagate thru ROWS to bottom_out. Thus, estimate that it takes (2N-1)+ROWS cycles to output all products to bottom_out
                    //+1 cycle for leeway
                    num_op_cycles = ((2 * ROWS) - 1) + ROWS + 1;
                    curr_output_idx <= {($clog2(COLS)){1'b0}};

                    output_start <= 1'b0;
                    set_stat_done <= 0;

                    stw_en <= 0;
                    fsm_done <= 0;
                    fsm_rdy <= 1;

                    if(start_fsm && wr_output_rdy) begin
                        set_stat_start <= 1;
                        
                        fsm_rdy <= 0;
                        state <= SET_STATIONARY;
                    end
                end

                RUN_STW1: begin   //1st cycle for STW: Loading stw_regs
                    stw_en <= 1;
                    if(!STW_complete)
                        state <= RUN_STW2;
                end

                RUN_STW2: begin   //2nd cycle for STW: Checking actual vs expected results
                    stw_en <= 0;
                    if(STW_complete) begin
                        stw_en <= 0;
                        state <= MATMUL1;
                    end
                    else 
                        state <= RUN_STW2;
                end

                SET_STATIONARY: begin
                    stw_en <= 0;   //TODO: Check timing
                    set_stat_start <= 1;
                    
                    if(stat_op_row > 0) begin

                        mem_wr_en <= 0;
                        mem_addr <= `TOP_MAT_BASE_ADDR + ((stat_op_row-1'b1)*`MEM_ADDR_INCR);
                        mem_delay <= MEM_ACCESS_LATENCY-1;
                        stall <= 1;
                        state <= READ_TOP_MAT;
                        
                        // top_in_bus = top_matrix[((stat_op_row-1'b1) * COLS) * WORD_SIZE +: (COLS * WORD_SIZE)];
                        // stat_op_row <= stat_op_row - 1'b1;
                    end
                    else begin
                        set_stat_done <= 1;
                        mem_delay <= MEM_ACCESS_LATENCY-1;
                        stall <= 1;
                        
                        // stall <= 0;
                        // set_stat_start <= 0;
                        // //Set control signals for matmul operation
                        // set_stationary <= 1'b0;
                        // stat_bit_in <= 1'b1;
                        // fsm_out_select_in <= 1'b1;
                        
                        // //No more inputs to top
                        // top_in_bus = {(COLS * WORD_SIZE){1'b0}};

                        // //Setup idx for matmul operation
                        // matmul_cycle <= {($clog2(ROWS)+4){1'b0}};
                        
                        // if(bisr_en)
                        //     state <= RUN_STW1;

                        state <= READ_TOP_MAT;

                    end
                end

                READ_TOP_MAT: begin
                    
                    if((mem_delay) == 'd0) begin
                        stall <= 0;
                        stat_op_row <= stat_op_row - 1'b1;
                        top_in_bus <= mem_rd_data;
                        

                        left_in_row <= 0;

                        if(set_stat_done) begin
                            stall <= 0;
                            set_stat_start <= 0;
                            //Set control signals for matmul operation
                            set_stationary <= 1'b0;
                            stat_bit_in <= 1'b1;
                            fsm_out_select_in <= 1'b1;
                            
                            //No more inputs to top
                            top_in_bus <= {(COLS * WORD_SIZE){1'b0}};

                            //Setup idx for matmul operation
                            matmul_cycle <= {($clog2(ROWS)+4){1'b0}};
                            
                            if(bisr_en)
                                state <= RUN_STW1;
                            else
                                state <= MATMUL1;
                        end
                        else
                            state <= SET_STATIONARY;
                    end
                    else
                       mem_delay <= mem_delay-1'b1; 
                end
                
                MATMUL1: begin
                    if(matmul_cycle < num_op_cycles) begin
                        mem_wr_en <= 0;
                        mem_addr <= `LEFT_MAT_BASE_ADDR + (left_in_row * `MEM_ADDR_INCR);
                        mem_delay <= MEM_ACCESS_LATENCY-1;
                        stall <= 1;

                        state <= READ_LEFT_MAT;
                        matmul_cycle <= matmul_cycle + 1'b1;
                        left_in_row <= left_in_row+1'b1;
                    end

                    // for(left_in_row = 0; left_in_row < ROWS; left_in_row++) begin
                    //     if(matmul_cycle < num_op_cycles) begin
                    //         if(matmul_cycle < left_in_row || matmul_cycle >= (left_in_row + ROWS)) begin
                    //             curr_cycle_left_in[(left_in_row * WORD_SIZE) +: WORD_SIZE] = `WORD_SIZE'b0;
                    //         end
                    //         else begin
                    //             curr_cycle_left_in[(left_in_row * WORD_SIZE) +: WORD_SIZE] = left_matrix[matmul_cycle-left_in_row][left_in_row];   //Assuming NxN matrices
                           
                    //         end
                            
                    //         matmul_cycle <= matmul_cycle + 1'b1;
                    //     end
                    // end

                    if(matmul_cycle+1 > ROWS) begin
                        //1st output propagates to r1c0 bottom_out @start of matmul_cycle = ROWS+1
                        //Read outputs
                        if(curr_output_idx == (COLS - 1)) begin
                            curr_output_idx <= {($clog2(COLS)){1'b0}};
                        end
                        else begin
                            curr_output_idx <= curr_output_idx + 1'b1;
                        end

                        if(matmul_cycle == ROWS)
                            output_start <= 1'b1;
                    end
                    
                    if(matmul_cycle >= num_op_cycles)
                        state <= FINISH;                
                    else
                        state <= READ_LEFT_MAT;
                        // state <= MATMUL2;
                end

                MATMUL2: begin
                    if(matmul_cycle > ROWS) begin                      
                        output_start <= 1'b0;
                    end
                    state <= MATMUL1;
                end

                READ_LEFT_MAT: begin
                    mem_delay <= mem_delay-1'b1;
                    if((mem_delay) == 'd0) begin
                        stall <= 0;

                        curr_cycle_left_in <= mem_rd_data;
                        state <= MATMUL2;
                        
                    end
                end

                FINISH: begin
                    fsm_done <= 1;
                    if(wr_output_done) begin
                        
                        fsm_rdy <= 1;
                        output_start <= 1'b0;
                        state <= INIT;
                    end
                end
            endcase
        end
    end

    logic [$clog2(ROWS):0] total_counter;
    enum {IDLE, INIT_VLD_COUNTERS, STALL, OUTPUT, DONE} counter_state;

    logic [$clog2(COLS):0] c;

    //Control flow for setting output valid signals
    always_ff @(negedge clk) begin
        if(output_start) begin
            output_col_valid[0] <= 1'b1;
            total_counter <= 1;
            counter_state <= STALL;
        end
        else begin
            case(counter_state)
                IDLE: counter_state <= IDLE;

                INIT_VLD_COUNTERS: begin
                    if((matmul_cycle+1) > (ROWS+3)) begin
                        output_col_valid[0] <= 1'b1;
                        total_counter <= 1;
                        counter_state <= STALL;
                    end
                end

                STALL: begin
                    //For col > 0: If previous col (column on the left) is valid, then current col will be valid this cycle
                    for(c = 1; c < COLS; c++) begin
                        if(output_col_valid[c-1]) begin
                            output_col_valid[c] <= 2'b1;
                        end
                    end

                    if(total_counter == (ROWS+1)) begin
                        output_col_valid[0] <= 1'b0;
                    end

                    if(output_col_valid == 'b0) begin
                        counter_state <= IDLE;
                    end
                    else if(!stall) begin
                        counter_state <= OUTPUT;
                    end
                    
                end

                OUTPUT: begin
                    //for col > 0: If previous col (column on the left) is valid, then current col will be valid this cycle
                    for(c = 1; c < COLS; c++) begin
                        if(output_col_valid[c-1]) begin
                            output_col_valid[c] <= 2'b1;
                        end
                        else if(!output_col_valid[c-1]) begin
                            output_col_valid[c] <= 2'b0;
                        end
                    end

                    if(total_counter == (ROWS+1)) begin
                        output_col_valid[0] <= 1'b0;
                    end else begin
                        total_counter <= total_counter+1;
                    end

                    //If all cols not longer valid, matmul operation for this input is done
                    if(output_col_valid == 'b0) begin
                        counter_state <= IDLE;
                    end
                    else begin
                        counter_state <= STALL;
                    end
                end
                default: counter_state <= IDLE;
            endcase
        end
    end


endmodule