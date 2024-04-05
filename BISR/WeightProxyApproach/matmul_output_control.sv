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
    fsm_done,
    matmul_fsm_output,
    matmul_output_valid,
    proxy_output_bus,
    proxy_out_valid_bus,
    output_matrix,

    //Signals for writing to memory
    mem_addr,
    mem_wr_en,
    mem_data
);
    localparam ADDR_WIDTH = $clog2(ROWS*COLS);

    input clk, rst, stall, fsm_done;
    input [COLS-1:0] matmul_output_valid;
    input [COLS-1:0] proxy_out_valid_bus;
    input logic [COLS * WORD_SIZE-1:0] matmul_fsm_output;
    input logic [COLS * WORD_SIZE-1:0] proxy_output_bus;
    
    output logic [WORD_SIZE - 1:0] output_matrix[ROWS][COLS] = '{default: '0};

    logic [WORD_SIZE - 1:0] sa_output_matrix[ROWS][COLS] = '{default: '0};
    logic [WORD_SIZE - 1:0] proxy_output_matrix[ROWS][COLS] = '{default: '0};


    logic [$clog2(ROWS):0] write_count[COLS] = '{default: '0};
    logic [$clog2(ROWS):0] proxy_write_count[COLS] = '{default: '0};
    logic [COLS-1:0] wr_en = '{default: '0};
    
    logic [$clog2(COLS):0] c;
    always @(posedge clk) begin
        // if(rst) begin
        //     for(c = 0; c < COLS; c++) begin
        //         write_count[c] <= 0;
        //         proxy_write_count <= 0;
        //     end
        // end
        // else begin
            for(c = 0; c < COLS; c++) begin
                if(matmul_output_valid[c] && !stall) begin
                    wr_en[c] <= ~wr_en[c];   //wr_en[c] serves as timing for when to write to output_matrix col c
                end
                else begin
                    wr_en[c] <= 1'b0;
                end
            end
        // end
    end

    logic [WORD_SIZE-1:0] output_in;
    logic [WORD_SIZE-1:0] output_read_data;

    logic proxy_wr_en;
    logic [WORD_SIZE-1:0] p_write_data;
    // logic [WORD_SIZE-1:0] test, test_fsm_output;
    always @(posedge clk) begin
        if(rst)
            proxy_wr_en <= 1'b0;
        else if(!stall)
            proxy_wr_en <= ~proxy_wr_en;
    end

    logic [(COLS*WORD_SIZE)-1:0] output_mat_by_row [ROWS-1:0];

    genvar r, c1, proxy_c;
    generate
        for(c1 = 0; c1 < COLS; c1++) begin : write_sa_out_genblk
            always @(posedge wr_en[c1]) begin   //output_matrix[rows][c1] "clocked" by wr_en[c1]
                if(matmul_output_valid[c1]) begin
                    write_count[c1] <= write_count[c1]+1'b1;   //Tracks what row of output_matrix we are writing to for col c1
                    sa_output_matrix[write_count[c1]][c1] <= sa_output_matrix[write_count[c1]][c1] + matmul_fsm_output[c1 * WORD_SIZE +: WORD_SIZE];   //Update output matrix
                    // test_fsm_output <= matmul_fsm_output[c1 * WORD_SIZE +: WORD_SIZE];
                    output_in <= matmul_fsm_output[c1 * WORD_SIZE +: WORD_SIZE];
                end
                else begin
                   
                    output_in <= 'b0;
                end
            end

            for(r = 0; r < ROWS; r=r+1) begin : write_total_out_genblk
                always @(*) begin
                    output_matrix[r][c1] = sa_output_matrix[r][c1] + proxy_output_matrix[r][c1];
                end
            end
        end

        for(proxy_c=0; proxy_c < COLS; proxy_c=proxy_c+1) begin : write_proxy_out_genblk
            always @(posedge proxy_wr_en) begin
            
                if(proxy_out_valid_bus[proxy_c]) begin
                    
                    proxy_output_matrix[proxy_write_count[proxy_c]][proxy_c] <= proxy_output_matrix[proxy_write_count[proxy_c]][proxy_c] + proxy_output_bus[proxy_c * WORD_SIZE +: WORD_SIZE];   //Update output matrix
                    p_write_data <= proxy_output_bus[proxy_c * WORD_SIZE +: WORD_SIZE];
                    // test <= output_matrix[proxy_write_count[proxy_c]][proxy_c] + proxy_output_bus[proxy_c * WORD_SIZE +: WORD_SIZE];
                    proxy_write_count[proxy_c] <= proxy_write_count[proxy_c]+1'b1;   //Tracks what row of output_matrix we are writing to for this proxy
                end
            end
        end

    endgenerate

    genvar out_r, out_c;
    generate
        for(out_r = 0; out_r < ROWS; out_r=out_r+1) begin : write_out_mat_genblk
            //Map output_matrix to unpacked array (inedxed by row) for writing to memory
            for(out_c = 0; out_c < COLS; out_c++) begin
                assign output_mat_by_row[out_r][(out_c*WORD_SIZE) +: WORD_SIZE] = output_matrix[out_r][out_c];
            end
        end
    endgenerate
    

    //Write output matrix to memory row by row
    enum {IDLE, MEM_WR, MEM_WR_DELAY} mem_output_state;
    logic [4:0] row_idx, col_idx;   //hardcoded for 4x4 matrix
    
    output logic [31:0] mem_addr;
    output logic mem_wr_en;
    output logic [`MEM_PORT_WIDTH-1:0] mem_data;
    
    logic [2:0] mem_delay;   //Num clk cycles left to stall until memory access value available

    always @(posedge clk) begin
        if(rst) begin
            row_idx <= 0;
            mem_output_state <= IDLE;
        end
        else begin
            case(mem_output_state)
                IDLE: begin
                    row_idx <= 0;

                    if(fsm_done)
                        mem_output_state <= MEM_WR;
                end

                MEM_WR: begin
                    if(row_idx < ROWS) begin
                        mem_addr <= `OUTPUT_MAT_BASE_ADDR + (row_idx * `MEM_ADDR_INCR);
                        mem_data <= output_mat_by_row[row_idx];
                        mem_wr_en <= 1;
                        row_idx <= row_idx + 1'b1;
                        mem_delay <= MEM_ACCESS_LATENCY-1;

                        mem_output_state <= MEM_WR_DELAY;
                    end
                    else
                        mem_output_state <= IDLE;
                end

                MEM_WR_DELAY: begin
                    mem_delay <= mem_delay-1'b1;
                    if((mem_delay) == 'd0) begin
                        mem_output_state <= MEM_WR;
                    end
                end
            endcase
        end
    end

endmodule