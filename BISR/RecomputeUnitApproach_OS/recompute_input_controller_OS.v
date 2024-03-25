`include "./header.vh"

`define RU_IDLE 2'b00
`define RU_FEED_INPUT_BUSES 2'b01
`define RU_FINSIH 2'b10
`define RU_WAIT_PROPOGATE 2'b11


module recompute_unit_controller_os 
#(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter WORD_SIZE = 16,
    parameter NUM_RU = 4   //Number of redundant units
    
)(
    input clk,
    input rst,
    //Input matrices -> FIXME: this should change to input buffer(fifo) for later design
    input [ROWS * COLS * WORD_SIZE - 1 : 0] top_matrix,
    input [ROWS * COLS * WORD_SIZE - 1 : 0] left_matrix,
    input [(ROWS*COLS)-1:0] STW_result_mat,
    //input [WORD_SIZE-1:0] systolic_output_reg [COLS-1:0];

    // RU input buses and control signals to RU module
    output reg [NUM_RU-1:0] ru_en,
    output reg [NUM_RU * WORD_SIZE - 1 : 0] ru_top_inputs,
    output reg [NUM_RU * WORD_SIZE - 1 : 0] ru_left_inputs,

    output reg [NUM_RU-1:0] ru_set_stationary,
    output reg [NUM_RU-1:0] ru_fsm_out_sel_in,
    output reg [NUM_RU-1:0] ru_stat_bit_in,
    output reg [NUM_RU-1:0] ru_output_valid,

    //faulty PE's X and Y coordinates mapping RU to output bus
    output reg [($clog2(COLS)*NUM_RU)-1:0] ru_col_mapping,
    //*NOTE*: Needed a register to stored row coordinates of the faulty PE(for OS)
    output reg [($clog2(ROWS)*NUM_RU)-1:0] ru_row_mapping
);  
    localparam NUM_BITS_COLS = $clog2(COLS);
    localparam NUM_BITS_RU = $clog2(NUM_RU);

    // ru_en[NUM_RU-1:0] = {NUM_RU{1'b0}};   //Enable signals for redundant units (1 per col)
    // ru_top_inputs[NUM_RU * WORD_SIZE - 1 : 0] = {COLS*WORD_SIZE{1'b0}};
    // ru_left_inputs[NUM_RU * WORD_SIZE - 1 : 0] = {COLS*WORD_SIZE{1'b0}};
    // output reg [WORD_SIZE - 1 : 0] ru_top_inputs = {WORD_SIZE{1'b0}};
    // output reg [WORD_SIZE - 1 : 0] ru_left_inputs = {WORD_SIZE{1'b0}};

    //For each entry of systolic_ru_mapping: LSB = 0 if RU not used, LSB = 1 if RU used f
    //output reg [NUM_BITS_RU:0] systolic_ru_col_mapping [COLS-1:0];   //COLS entries of size (NUM_BITS_RU+1) each
    //output reg [NUM_BITS_RU:0] systolic_ru_row_mapping [COLS-1:0];   //COLS entries of size (NUM_BITS_RU+1) each

    //output reg [(COLS*(NUM_BITS_RU+1))-1:0] systolic_ru_mapping;

    //Count zeroes in STW_result_mat - this is the number of faults
    reg [NUM_RU-1:0] ru_idx = {NUM_RU{1'b0}};   //Number of faults to fix (max = NUM_RU)
    reg [NUM_RU*2-1:0] ru_state;
    reg [NUM_RU -1 : 0 ] wait_mul = {NUM_RU{1'b0}};

    reg [NUM_BITS_COLS*NUM_RU-1:0] n_cycle = {NUM_BITS_COLS*NUM_RU{1'b0}}; //Number of cycles feeding in input buses 
    reg [NUM_BITS_COLS*NUM_RU-1:0] waitmul = {NUM_BITS_COLS*NUM_RU{1'b0}};  
  
    reg [COLS*ROWS -1 : 0] count_fault = {COLS*ROWS{1'b0}}; //Number of cycles feeding in input buses 
    reg [(ROWS*COLS)-1:0] RU_repair_mat = {COLS*ROWS{1'b0}};

    // always @(posedge rst) begin
    //     ru_idx <= {NUM_RU{1'b0}};   
    //     ru_en <= {NUM_RU{1'b0}};

    //     RU_repair_mat <= {COLS*ROWS{1'b0}};

    //     ru_col_mapping <= {(($clog2(COLS)*NUM_RU)){1'b0}};
    //     ru_row_mapping <= {(($clog2(ROWS)*NUM_RU)){1'b0}};
    // end 

        integer  r, c;
        always @(STW_result_mat, rst) begin
            if(rst)begin
                ru_idx = {NUM_RU{1'b0}};   
                ru_en = {NUM_RU{1'b0}};

                RU_repair_mat = {COLS*ROWS{1'b0}};

                ru_col_mapping = {(($clog2(COLS)*NUM_RU)){1'b0}};
                ru_row_mapping = {(($clog2(ROWS)*NUM_RU)){1'b0}};
            end 
            else begin                 
                    for(c = 0; c < COLS; c=c+1) begin
                        for(r = 0; r < ROWS; r=r+1) begin
                            if(!STW_result_mat[r*(COLS)+c] && !RU_repair_mat[r*(COLS)+c])begin 
                                RU_repair_mat[r*(COLS)+c] = 1'b1; 
                                if(ru_idx < NUM_RU) begin
                                    ru_en[ru_idx] = 1'b1;

                                    ru_col_mapping[(ru_idx*NUM_BITS_COLS) +: NUM_BITS_COLS] = c[NUM_BITS_COLS-1:0];   //genvar c is treated as 32-bit constant int - take value for ru->col mapping
                                    ru_row_mapping[(ru_idx*NUM_BITS_COLS) +: NUM_BITS_COLS] = r[NUM_BITS_COLS-1:0];
                                    ru_idx = ru_idx + !STW_result_mat[(r*COLS)+c];   //Update count_faults according to STW_result_mat
                                
                                end
                            end 
                        end
                    end
                
            end 
        end
    //State machine for enabling settings for RUs according to ru_en - set corresponding RU to SET_STATIONARY or MATMUL mode
    //genvar c;
    always @(posedge clk) begin
        if(rst) begin
            ru_state <= {(NUM_RU*2){1'b0}};
            n_cycle <= {($clog2(COLS)*NUM_RU){1'b0}};
            waitmul <= {($clog2(COLS)*NUM_RU){1'b0}};

        end
    end 

    genvar idx;
    //generate
    for(idx = 0; idx < NUM_RU; idx=idx+1) begin
        always @(posedge clk) begin
            //override below if ru_en is intiliazed/rst is disable
            ru_fsm_out_sel_in[idx] <= 1'b0;
            ru_stat_bit_in[idx] <= 1'b0;
            ru_set_stationary[idx] <= 1'b0;
            ru_output_valid[idx] <= 1'b0;

            ru_left_inputs[(idx*WORD_SIZE) +: WORD_SIZE] <= {WORD_SIZE{1'b0}};
            ru_top_inputs[(idx*WORD_SIZE) +: WORD_SIZE] <= {WORD_SIZE{1'b0}};

            if(ru_en[idx] && !rst)begin 
                case(ru_state[idx*2 +: 2])
                    `RU_IDLE: begin
                        //restart another computation
                        if(ru_en[idx] && !wait_mul[idx]) begin
                            //Settings for RU to set stationary reg for OS workflow
                            ru_left_inputs[(idx*WORD_SIZE) +: WORD_SIZE] <= left_matrix[((ru_col_mapping[(idx*NUM_BITS_COLS) +: NUM_BITS_COLS])*WORD_SIZE) +: WORD_SIZE];
                            ru_top_inputs[(idx*WORD_SIZE) +: WORD_SIZE] <= top_matrix[(((ru_row_mapping[(idx*NUM_BITS_COLS) +: NUM_BITS_COLS])*COLS)*WORD_SIZE) +: WORD_SIZE];
                    
                            n_cycle[idx*NUM_BITS_COLS +: NUM_BITS_COLS] <= n_cycle[idx*NUM_BITS_COLS +: NUM_BITS_COLS] + 1'b1;
                            ru_state[idx*2 +: 2] <= `RU_FEED_INPUT_BUSES;
                        end
                    end
                    `RU_FEED_INPUT_BUSES: begin
                        //Settings for RU to do matmul
                        n_cycle[idx*NUM_BITS_COLS +: NUM_BITS_COLS] <= n_cycle[idx*NUM_BITS_COLS +: NUM_BITS_COLS] + 1'b1;
                        ru_left_inputs[(idx*WORD_SIZE) +: WORD_SIZE] <= left_matrix[(((ru_col_mapping[(idx*NUM_BITS_COLS) +: NUM_BITS_COLS]+`COLS * n_cycle[idx*NUM_BITS_COLS +: NUM_BITS_COLS]))*WORD_SIZE) +: WORD_SIZE];
                        ru_top_inputs[(idx*WORD_SIZE) +: WORD_SIZE] <= top_matrix[(((ru_row_mapping[(idx*NUM_BITS_COLS) +: NUM_BITS_COLS])*COLS + n_cycle[idx*NUM_BITS_COLS +: NUM_BITS_COLS])*WORD_SIZE) +: WORD_SIZE];
                        
                        if(n_cycle[idx*NUM_BITS_COLS +: NUM_BITS_COLS] == `COLS - 1)
                            ru_state[idx*2 +: 2] <= `RU_WAIT_PROPOGATE;    
                    end
                    `RU_WAIT_PROPOGATE:begin
                        ru_left_inputs[(idx*WORD_SIZE) +: WORD_SIZE] <= 0;
                        ru_top_inputs[(idx*WORD_SIZE) +: WORD_SIZE] <= 0;
                        
                        if(wait_mul[idx] == 1'b1)begin
                            ru_output_valid[idx] <= 1'b1;
                            ru_state[idx*2 +: 2] <= `RU_FINSIH;
                            ru_fsm_out_sel_in[idx] <= 1'b1;
                        end
                        else 
                            wait_mul[idx] <= 1'b1;
                    end
                    
                    `RU_FINSIH: begin
                        //ru_output_valid[idx] <= 1'b1;
                        //FIXME: add states to multiple operations
                        //ru_state[idx*2 +: 2] <= `RU_IDLE;
                    end
                    default: ru_state[idx*2 +: 2] <= `RU_IDLE;
                endcase
            end
        end
    end
    //endgenerate

endmodule