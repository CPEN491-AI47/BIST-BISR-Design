`include "./header.vh"

//Matrix Multiplication under Output-Stationary(OS) dataflows
module workflow_control_os
#(
    parameter WORD_SIZE = 16
)(
    input clk,
    input rst, //Active-high reset
    
    //Input matrices,
    //*NOTE*: Different input left_matrix format as to WS Workflow 
    input logic [`ROWS * `COLS * `WORD_SIZE - 1 : 0] top_matrix,
    input logic [`ROWS * `COLS * `WORD_SIZE - 1 : 0] left_matrix,

    //Output Control Signals
    output logic set_stationary,
    output logic fsm_out_select_in,
    output logic stat_bit_in,

    //Output: top_in & left_in to systolic array @current clk cycle
    //*NOTE*: Additional output left_in_bus for OS Workflow 
    output logic [`ROWS * WORD_SIZE - 1: 0] curr_cycle_left_in,
    output logic [`COLS * WORD_SIZE - 1: 0] curr_cycle_top_in,

    //Input: Outputs from bottom of systolic
    input [`COLS * WORD_SIZE - 1: 0] bottom_out,

    //Outputs
    output logic[`COLS * WORD_SIZE-1:0] matmul_output,
    output logic [`COLS-1:0] output_col_valid   //If output_col_valid[i] == 1, then bottom_out of column i is valid
);
    
    //Counter for Column bottom_out in current clk cycle
    logic [$clog2(`COLS):0] curr_output_cycle;  

    //Counter for Column bottom_out in current clk cycle
    logic [$clog2(`COLS):0] waitmul;  
    

    logic [`COLS:0] n_cycle; //Number of cycles feeding in input buses   

    enum {INIT, WAIT_MUL, FEED_INPUT_BUSES, SET_OUTPUT_ENABLE, WAIT_PROPOGATE, OUTPUT, FINISH} state;

    always_ff @(posedge clk) begin
        if(rst) begin
            state <= INIT;
        end
    end

    assign matmul_output = bottom_out;   //Matrix multiplication output = bottom_out of systolic: Which part of bottom_out are valid outputs will be set by output_col_valid

    //Control flow for Feeding in left & top buses + Producing matrix multiplication outputs from systolic
    always_ff @(negedge clk) begin
        case(state)
            INIT: begin
                //Initilizaing control signals inside PE unit
                set_stationary <= 1'b0;
                stat_bit_in <= 1'b0;
                fsm_out_select_in <= 1'b0;
                
                n_cycle <= 1;
                curr_output_cycle <= 0;
                output_col_valid <= 0;
                waitmul <= 1;

                //Initilizaing left & top in bus
                curr_cycle_top_in <= left_matrix[ `WORD_SIZE -1 -: `WORD_SIZE];
                curr_cycle_left_in <= top_matrix[ `WORD_SIZE -1 -: `WORD_SIZE];
                
                state <= FEED_INPUT_BUSES;
            end
            
            FEED_INPUT_BUSES: begin
                //Feeding left & top in bus at each clock cycle
                if(n_cycle < `COLS * 2)begin 
                    n_cycle <= n_cycle + 1;
                    for(integer N_count = 0; N_count <`ROWS; N_count++)begin
                        if(n_cycle >= N_count && (n_cycle - N_count) < `ROWS)begin
                            curr_cycle_top_in[(1+N_count) * `WORD_SIZE -1 -: `WORD_SIZE] <= left_matrix[((n_cycle * `ROWS + 1 - N_count * (`ROWS - 1)) * `WORD_SIZE) -1 -: `WORD_SIZE];
                            curr_cycle_left_in[(N_count+1) * `WORD_SIZE -1 -: `WORD_SIZE] <= top_matrix[((n_cycle + 1 + (`ROWS - 1) * N_count) * `WORD_SIZE) -1 -: `WORD_SIZE];
                        end
                        else begin
                            curr_cycle_top_in[(1+N_count) * `WORD_SIZE -1 -: `WORD_SIZE] <= `WORD_SIZE'd0; 
                            curr_cycle_left_in[(1+N_count) * `WORD_SIZE -1 -: `WORD_SIZE] <= `WORD_SIZE'd0; 
                        end 
                    end
                    state <= FEED_INPUT_BUSES;
                end 
                // End of feeding, reset top & left input bus to zero
                else begin
                    curr_cycle_left_in <= 0;
                    curr_cycle_top_in <= 0;
                    if(waitmul > `COLS)begin
                        state <= SET_OUTPUT_ENABLE;
                        fsm_out_select_in <= 1'b1;
                        output_col_valid <= {`COLS{1'b0}};
                    end 
                    else 
                        waitmul <= waitmul + 1;
                end
            end 
            
            //For OS Workflow, Multiplication results are pushed out from acculmator register by enable fsm_out_select_in
            SET_OUTPUT_ENABLE:begin
                //fsm_out_select_in <= 1'b0;
                output_col_valid <= {`COLS{1'b1}};
                state <= OUTPUT; 
            end
            
            //Outputs are coming up column-wise(output_col_valid set to all valid): 
            //Cycle 1: bottom=[A22, A21, A20]
            //Cycle 2: bottom=[A12, A11, A10]
            //Cycle 3: bottom=[A02, A01, A00]
            OUTPUT: begin
                fsm_out_select_in <= 1'b0;
                if(curr_output_cycle < `ROWS)begin
                    curr_output_cycle <= curr_output_cycle + 1;
                    output_col_valid <= {`COLS{1'b1}};
                    state <= OUTPUT;
                end
                else begin
                    output_col_valid <= {`COLS{1'b0}};
                    state <= FINISH;
                end 
            end
            //TODO: Fix exit condition to transition to FINISH once matmul complete
            FINISH: begin
                output_col_valid <= {`COLS{1'b0}};
                curr_cycle_left_in <= 0;
                curr_cycle_top_in <= 0;
                set_stationary <= 1'b0;
                stat_bit_in <= 1'b0;
                fsm_out_select_in <= 1'b0;
                state <= FINISH;
            end
        endcase
    end 
endmodule