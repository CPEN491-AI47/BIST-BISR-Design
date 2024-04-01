`include "./header_ws.vh"

//Reference for weight-stationary matmul: https://www.telesens.co/2018/07/30/systolic-architectures/
//Currently implemented based on weight-stationary dataflows

//Control flow for matrix multiplication of left_matrix * top_matrix
module systolic_matmul_fsm
#(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter WORD_SIZE = 16
)(
    clk,
    rst,
    
    //Input matrices
    top_matrix,
    left_matrix,
    start_fsm,
    start_matmul,

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
    output_col_valid   //If output_col_valid[i] == 1, then bottom_out of column i is valid
);

    input clk;
    input rst;   //Active-high reset

    input start_fsm;
    input start_matmul;

    output logic set_stationary;
    output logic fsm_out_select_in;
    output logic stat_bit_in;

    input [ROWS * COLS * WORD_SIZE - 1 : 0] top_matrix;
    input logic [WORD_SIZE:0] left_matrix[ROWS][COLS];
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

    //Note: traditional_mac has 2 regs (double-buffered). Thus it takes 2 clk cycles (1 matmul_cycle = 2 clk cycles) for each PE to produce a bottom_out output
    //So MATMUL has 2 stages for stalling
    enum {INIT, SET_STATIONARY, MATMUL1, MATMUL2, FINISH} state;

    // always_ff @(posedge clk) begin
    //     if(rst) begin
    //         state <= INIT;
    //     end
    // end

    assign matmul_output = bottom_out;   //Matrix multiplication output = bottom_out of systolic: Which part of bottom_out are valid outputs will be set by output_col_valid

    //Control flow for setting stationary regs + Producing matrix multiplication outputs from systolic
    always_ff @(posedge clk) begin
        if(rst) begin
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

                    if(start_fsm)
                        state <= SET_STATIONARY;
                end

                SET_STATIONARY: begin
                    if(stat_op_row > 0) begin
                        top_in_bus = top_matrix[((stat_op_row-1'b1) * COLS) * WORD_SIZE +: (COLS * WORD_SIZE)];
                        stat_op_row <= stat_op_row - 1'b1;
                    end
                    else begin
                        //Set control signals for matmul operation
                        set_stationary <= 1'b0;
                        stat_bit_in <= 1'b1;
                        fsm_out_select_in <= 1'b1;
                        
                        //No more inputs to top
                        top_in_bus = {(COLS * WORD_SIZE){1'b0}};

                        //Setup idx for matmul operation
                        matmul_cycle <= {($clog2(ROWS)+4){1'b0}};
                        
                        if(start_matmul)
                            state <= MATMUL1;
                        // state <= STALL1;
                    end
                end
                
                MATMUL1: begin
                    for(left_in_row = 0; left_in_row < ROWS; left_in_row++) begin
                        if(matmul_cycle < num_op_cycles) begin
                            if(matmul_cycle < left_in_row || matmul_cycle >= (left_in_row + ROWS)) begin
                                curr_cycle_left_in[(left_in_row * WORD_SIZE) +: WORD_SIZE] = `WORD_SIZE'b0;
                            end
                            else begin
                                curr_cycle_left_in[(left_in_row * WORD_SIZE) +: WORD_SIZE] = left_matrix[matmul_cycle-left_in_row][left_in_row];   //Assuming NxN matrices
                            end
                            matmul_cycle <= matmul_cycle + 1'b1;
                        end
                    end

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
                        state <= MATMUL2;
                end

                MATMUL2: begin
                    if(matmul_cycle > ROWS) begin                      
                        output_start <= 1'b0;
                    end
                    state <= MATMUL1;
                end

                //TODO: Fix exit condition to transition to FINISH once matmul complete
                FINISH: begin
                    output_start <= 1'b0;
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
                    if((matmul_cycle+1) > ROWS) begin
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

                    if(total_counter == ROWS) begin
                        output_col_valid[0] <= 1'b0;
                    end

                    if(output_col_valid == 'b0) begin
                        counter_state <= IDLE;
                    end
                    else begin
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

                    if(total_counter == ROWS) begin
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