`include "./header_ws.vh"

//Control path for reading out & storing output matrix values (for weight/input-stationary flows) from systolic_matmul_fsm
//Notes: traditional_mac is double-buffered so each output is maintained for 2 clk cycles (thus wr_en has 1/2 freq of clk)
//Outputs of traditional_systolic are also staggered by 1 clk cycle. 
//Ex: Clk 1: Col 0 output[1] --> maintained for 2 clks (until clk 3)
//    Clk 2: Col 1 output[1]
//    Clk 3: Col 2 output[1] + Col 0 output[2]
module matmul_output_control
#(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter WORD_SIZE = 16,
    parameter MEM_ACCESS_LATENCY = 2   //Delay for accessing RAM entries
)(
    clk,
    rst,
    stall,
    fsm_rdy,
    fsm_done,
    matmul_fsm_output,
    matmul_output_valid,
    proxy_output_bus,
    proxy_out_valid_bus,
    // output_matrix,
    wr_output_rdy,
    wr_output_done,

    //Signals for writing to memory
    mem_addr,
    mem_wr_en,
    mem_data,

    memout_state_test,
    row_idx,


    // outctrl_test,
    // outctrl_test1
);
    localparam ADDR_WIDTH = $clog2(ROWS*COLS);

    // output logic signed [WORD_SIZE - 1: 0] outctrl_test;
    // output logic signed [WORD_SIZE - 1: 0] outctrl_test1; 

    input clk, rst, stall, fsm_done, fsm_rdy;
    input [COLS-1:0] matmul_output_valid;
    input [COLS-1:0] proxy_out_valid_bus;
    input logic signed [COLS * WORD_SIZE-1:0] matmul_fsm_output;
    input logic signed [COLS * WORD_SIZE-1:0] proxy_output_bus;
    
    // output logic signed [WORD_SIZE - 1:0] output_matrix[ROWS][COLS] = '{default: '0};
    logic signed [WORD_SIZE - 1:0] output_matrix[ROWS][COLS] = '{default: '0};

    logic signed [WORD_SIZE - 1:0] sa_output_matrix[ROWS][COLS] = '{default: '0};

    // assign outctrl_test = output_matrix[0][1];

    logic signed [WORD_SIZE - 1:0] proxy_output_matrix[ROWS][COLS] = '{default: '0};
    // assign outctrl_test1 = proxy_output_matrix[0][1];


    logic [$clog2(ROWS):0] write_count[COLS] = '{default: '0};
    logic [$clog2(ROWS):0] proxy_write_count[COLS] = '{default: '0};
    logic [COLS-1:0] wr_en = '{default: '0};
    
    logic [$clog2(COLS):0] c;
    always @(posedge clk) begin
        for(c = 0; c < COLS; c++) begin
            if(matmul_output_valid[c] && !stall) begin
                wr_en[c] <= ~wr_en[c];   //wr_en[c] serves as timing for when to write to output_matrix col c
            end
            else begin
                wr_en[c] <= 1'b0;
            end
        end
    end

    logic [$clog2(COLS):0] proxy_wr_en_idx;
    logic [COLS-1:0] proxy_wr_en;

    always @(posedge clk) begin
        for(proxy_wr_en_idx=0; proxy_wr_en_idx < COLS; proxy_wr_en_idx = proxy_wr_en_idx+1) begin
            if(rst)
                proxy_wr_en[proxy_wr_en_idx] <= 1'b0;
            else if(proxy_out_valid_bus[proxy_wr_en_idx] && !stall)
                proxy_wr_en[proxy_wr_en_idx] <= ~proxy_wr_en[proxy_wr_en_idx];
            else
                proxy_wr_en[proxy_wr_en_idx] <= 1'b0;
        end
    end

    logic signed [(COLS*WORD_SIZE)-1:0] output_mat_by_row [ROWS-1:0];

    genvar r, c1, proxy_c;
    generate
        for(c1 = 0; c1 < COLS; c1++) begin : write_sa_out_genblk
            always @(posedge clk) begin     
                if(wr_en[c1]) begin     //sa_output_matrix[rows][c1] "clocked" by wr_en[c1]
                    if(matmul_output_valid[c1]) begin
                        write_count[c1] <= write_count[c1]+1'b1;   //Tracks what row of output_matrix we are writing to for col c1
                        sa_output_matrix[write_count[c1]][c1] <= sa_output_matrix[write_count[c1]][c1] + matmul_fsm_output[c1 * WORD_SIZE +: WORD_SIZE];   //Update output matrix
                    end
                end
            end

            for(r = 0; r < ROWS; r=r+1) begin : write_total_out_genblk
                always @(posedge clk) begin
                    if(wr_en != 'b0)
                        output_matrix[r][c1] <= sa_output_matrix[r][c1] + proxy_output_matrix[r][c1];

                end
            end
        end

        for(proxy_c=0; proxy_c < COLS; proxy_c=proxy_c+1) begin : write_proxy_out_genblk
             always @(posedge clk) begin
                if(proxy_wr_en[proxy_c]) begin   //proxy_output "clocked" by proxy_wr_en
                    if(proxy_out_valid_bus[proxy_c]) begin
                        
                        proxy_output_matrix[proxy_write_count[proxy_c]][proxy_c] <= proxy_output_matrix[proxy_write_count[proxy_c]][proxy_c] + proxy_output_bus[proxy_c * WORD_SIZE +: WORD_SIZE];   //Update output matrix
                        proxy_write_count[proxy_c] <= proxy_write_count[proxy_c]+1'b1;   //Tracks what row of output_matrix we are writing to for this proxy
                    end
                end
            end
        end

    endgenerate

    genvar out_r, out_c;
    generate
        for(out_r = 0; out_r < ROWS; out_r=out_r+1) begin : write_out_mat_r_genblk
            //Map output_matrix to unpacked array (inedxed by row) for writing to memory
            for(out_c = 0; out_c < COLS; out_c++) begin : write_out_mat_c_genblk
                assign output_mat_by_row[out_r][(out_c*WORD_SIZE) +: WORD_SIZE] = output_matrix[out_r][out_c];
            end
        end
    endgenerate
    

    //Write output matrix to memory row by row
    enum {IDLE, MEM_WR, MEM_WR_DELAY} mem_output_state;

    output logic [3:0] memout_state_test; //NOTE: revert
    assign memout_state_test = mem_output_state;
    output logic [4:0] row_idx;   //hardcoded for 4x4 matrix
    
    output logic wr_output_rdy, wr_output_done;
    
    output logic [31:0] mem_addr;
    output logic mem_wr_en;
    output logic signed [`MEM_PORT_WIDTH-1:0] mem_data;
    
    logic [2:0] mem_delay;   //Num clk cycles left to stall until memory access value available

    always @(posedge clk) begin
        if(rst) begin
            row_idx <= 0;
            wr_output_rdy <= 1;
            wr_output_done <= 0;
            mem_wr_en <= 0;
            mem_output_state <= IDLE;
        end
        else begin
            case(mem_output_state)
                IDLE: begin
                    row_idx <= 0;
                    wr_output_rdy <= 1;
                    wr_output_done <= 0;
                    mem_wr_en <= 0;
                    if(fsm_done && !fsm_rdy)
                        mem_output_state <= MEM_WR;
                end

                MEM_WR: begin
                    wr_output_rdy <= 0;
                    if(row_idx < ROWS) begin
                        mem_addr <= `OUTPUT_MAT_BASE_ADDR + (row_idx * `MEM_ADDR_INCR);
                        mem_data <= output_mat_by_row[row_idx];
                        mem_wr_en <= 1;
                        row_idx <= row_idx + 1'b1;
                        mem_delay <= MEM_ACCESS_LATENCY-1;

                        mem_output_state <= MEM_WR_DELAY;
                    end
                    else begin
                        wr_output_done <= 1;
                        mem_wr_en <= 0;
                        mem_output_state <= IDLE;
                    end
                end

                MEM_WR_DELAY: begin
                    mem_delay <= mem_delay-1'b1;
                    mem_wr_en <= 0;
                    if((mem_delay) == 'd0) begin
                        mem_output_state <= MEM_WR;
                    end
                end

                default: mem_output_state <= IDLE;
            endcase
        end
    end

endmodule