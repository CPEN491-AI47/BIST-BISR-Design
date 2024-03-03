`include "./header_ws.vh"

`define RU_IDLE 2'b0
`define RU_SET_STATIONARY 2'b01
`define RU_RUNNING 2'b10


module recompute_unit_controller 
#(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter WORD_SIZE = 16,
    parameter NUM_RU = 4   //Number of redundant units
)(
    clk,
    rst,
    //Input matrices
    top_matrix,
    left_matrix,
    STW_result_mat,
    systolic_output_reg,

    ru_en,
    ru_top_inputs,
    ru_left_inputs,
    ru_set_stationary,
    ru_fsm_out_sel_in,
    ru_stat_bit_in,
    ru_col_mapping
);  
    localparam NUM_BITS_COLS = $clog2(COLS);
    localparam NUM_BITS_RU = $clog2(NUM_RU);
    
    input clk, rst;
    input [ROWS * COLS * WORD_SIZE - 1 : 0] top_matrix;
    input [ROWS * COLS * WORD_SIZE - 1 : 0] left_matrix;
    input [(ROWS*COLS)-1:0] STW_result_mat;
    input [WORD_SIZE-1:0] systolic_output_reg [COLS-1:0];

    output reg [NUM_RU-1:0] ru_en = {NUM_RU{1'b0}};   //Enable signals for redundant units (1 per col)
    output reg [NUM_RU * WORD_SIZE - 1 : 0] ru_top_inputs = {COLS*WORD_SIZE{1'b0}};
    output reg [NUM_RU * WORD_SIZE - 1 : 0] ru_left_inputs = {COLS*WORD_SIZE{1'b0}};
    // output reg [WORD_SIZE - 1 : 0] ru_top_inputs = {WORD_SIZE{1'b0}};
    // output reg [WORD_SIZE - 1 : 0] ru_left_inputs = {WORD_SIZE{1'b0}};

    output reg [NUM_RU-1:0] ru_set_stationary;
    output reg [NUM_RU-1:0] ru_fsm_out_sel_in;
    output reg [NUM_RU-1:0] ru_stat_bit_in;
    output reg [(NUM_BITS_COLS*NUM_RU)-1:0] ru_col_mapping;

    //For each entry of systolic_ru_mapping: LSB = 0 if RU not used, LSB = 1 if RU used f
    output reg [NUM_BITS_RU:0] systolic_ru_mapping [COLS-1:0];   //COLS entries of size (NUM_BITS_RU+1) each
    // output reg [(COLS*(NUM_BITS_RU+1))-1:0] systolic_ru_mapping;

    //Count zeroes in STW_result_mat - this is the number of faults
    reg [NUM_RU-1:0] count_faults = {NUM_RU{1'b0}};   //Number of faults to fix (max = NUM_RU)
    reg [(NUM_RU*2)-1:0] ru_state;

    genvar r, c;
    generate
    for(c = 0; c < COLS; c=c+1) begin
        for(r = 0; r < ROWS; r=r+1) begin
            always @(STW_result_mat or rst) begin
                if(rst) begin
                    count_faults <= {NUM_RU{1'b0}};   //TODO: Rename count_faults to ru_idx
                    ru_en <= {NUM_RU{1'b0}};
                    // ru_col_mapping <= {(NUM_BITS_COLS*){1'b0}};
                    systolic_ru_mapping[c] <= {(NUM_BITS_RU+1){1'b0}};
                end
                else begin            
                    count_faults <= count_faults + !STW_result_mat[(r*COLS)+c];   //Update count_faults according to STW_result_mat

                    //Update ru_en & top/left inputs according to count_faults
                    if(!STW_result_mat[(r*COLS)+c] && count_faults < NUM_RU) begin
                        ru_en[count_faults] <= 1'b1;
                        ru_col_mapping[(count_faults*NUM_BITS_COLS) +: NUM_BITS_COLS] <= c[NUM_BITS_COLS-1:0];   //genvar c is treated as 32-bit constant int - take value for ru->col mapping
                        
                        systolic_ru_mapping[(c*NUM_BITS_RU) +: NUM_BITS_RU] <= {count_faults, 1'b1};

                        ru_left_inputs[(count_faults*WORD_SIZE) +: WORD_SIZE] <= left_matrix[(((r*COLS)+c)*WORD_SIZE) +: WORD_SIZE];
                        
                        if(ru_state[count_faults +: 2] == `RU_SET_STATIONARY)
                            ru_top_inputs[(count_faults*WORD_SIZE) +: WORD_SIZE] <= top_matrix[(((r*COLS)+c)*WORD_SIZE) +: WORD_SIZE];
                        else
                            ru_top_inputs[(count_faults*WORD_SIZE) +: WORD_SIZE] <= systolic_output_reg[c];
                            // ru_top_inputs[(count_faults*WORD_SIZE) +: WORD_SIZE] <= systolic_bottom_out[((r*COLS)+c)*WORD_SIZE +: WORD_SIZE];
                    end
                end
            end
        end
    end
    endgenerate

    //State machine for enabling settings for RUs according to ru_en - set corresponding RU to SET_STATIONARY or MATMUL mode
    genvar c;
    generate
    for(c = 0; c < NUM_RU; c=c+1) begin
        always @(posedge clk) begin
            if(rst) begin
                ru_state <= `RU_IDLE;
            end
            else begin
                case(ru_state)
                    `RU_IDLE: begin
                        if(ru_en[c]) begin
                            //Settings for RU to set stationary reg
                            ru_set_stationary[c] <= 1'b1;
                            ru_fsm_out_sel_in[c] <= 1'b0;
                            ru_stat_bit_in[c] <= 1'b0;
                            ru_state <= `RU_SET_STATIONARY;
                        end
                    end
                    `RU_SET_STATIONARY: begin
                        //Settings for RU to do matmul
                        ru_set_stationary[c] <= 1'b0;
                        ru_fsm_out_sel_in[c] <= 1'b1;
                        ru_stat_bit_in[c] <= 1'b1;
                        ru_state <= `RU_RUNNING;
                    end
                    `RU_RUNNING: begin
                        ru_set_stationary[c] <= 1'b0;
                        ru_fsm_out_sel_in[c] <= 1'b1;
                        ru_stat_bit_in[c] <= 1'b1;
                        ru_state <= `RU_RUNNING;
                    end
                    default: ru_state <= `RU_IDLE;
                endcase
            end
        end
    end
    endgenerate

endmodule