`include "./header_ws.vh"

//Control path for reading out & storing output matrix values (for weight/input-stationary flows) from systolic_matmul_fsm
//Notes: traditional_mac is double-buffered so each output is maintained for 2 clk cycles (thus wr_en has 1/2 freq of clk)
//Outputs of traditional_systolic are also staggered by 1 clk cycle. 
//Ex: Clk 1: Col 0 output[1] --> maintained for 2 clks (until clk 3)
//    Clk 2: Col 1 output[1]
//    Clk 3: Col 2 output[1] + Col 0 output[2]
module matmul_output_control
#(
    parameter WORD_SIZE = 16
)(
    clk,
    rst,
    matmul_fsm_output,
    matmul_output_valid,
    proxy_output_bus,
    proxy_out_valid_bus,
    output_matrix
);
    localparam ADDR_WIDTH = $clog2(`ROWS*`COLS);

    input clk, rst;
    input [`COLS-1:0] matmul_output_valid;
    input [`COLS-1:0] proxy_out_valid_bus;
    input logic [`COLS * WORD_SIZE-1:0] matmul_fsm_output;
    input logic [`COLS * WORD_SIZE-1:0] proxy_output_bus;
    
    output logic [WORD_SIZE - 1:0] output_matrix[`ROWS][`COLS] = '{default: '0};

    logic [ADDR_WIDTH-1:0] ram_addr;
    logic ram_we;

    logic [$clog2(`ROWS):0] write_count[`COLS] = '{default: '0};
    logic [$clog2(`ROWS):0] proxy_write_count[`COLS] = '{default: '0};
    logic [`COLS-1:0] wr_en = '{default: '0};
    
    logic [$clog2(`COLS):0] c, r;
    always_ff @(posedge clk) begin
        // if(rst) begin
        //     for(c = 0; c < `COLS; c++) begin
        //         write_count[c] <= 0;
        //         proxy_write_count <= 0;
        //     end
        // end
        // else begin
            for(c = 0; c < `COLS; c++) begin
                if(matmul_output_valid[c]) begin
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
    logic [WORD_SIZE-1:0] test, test_fsm_output;
    always_ff @(posedge clk) begin
        if(rst)
            proxy_wr_en <= 1'b0;
        else
            proxy_wr_en <= ~proxy_wr_en;
    end

    genvar c1, proxy_c;
    generate
        for(c1 = 0; c1 < `COLS; c1++) begin
            always_ff @(posedge wr_en[c1]) begin   //output_matrix[rows][c1] "clocked" by wr_en[c1]
                if(matmul_output_valid[c1]) begin
                    write_count[c1] <= write_count[c1]+1'b1;   //Tracks what row of output_matrix we are writing to for col c1
                    output_matrix[write_count[c1]][c1] <= output_matrix[write_count[c1]][c1] + matmul_fsm_output[c1 * WORD_SIZE +: WORD_SIZE];   //Update output matrix
                    test_fsm_output <= matmul_fsm_output[c1 * WORD_SIZE +: WORD_SIZE];
                    ram_we <= 1'b1;
                    ram_addr <= ((write_count[c1]*`COLS) + c1);
                    output_in <= matmul_fsm_output[c1 * WORD_SIZE +: WORD_SIZE];
                end
                else begin
                    ram_we <= 1'b0;
                    output_in <= 'b0;
                end
            end
        end

        for(proxy_c=0; proxy_c < `COLS; proxy_c=proxy_c+1) begin
            always_ff @(posedge proxy_wr_en) begin
            
                if(proxy_out_valid_bus[proxy_c]) begin
                    
                    output_matrix[proxy_write_count[proxy_c]][proxy_c] <= output_matrix[proxy_write_count[proxy_c]][proxy_c] + proxy_output_bus[proxy_c * WORD_SIZE +: WORD_SIZE];   //Update output matrix
                    p_write_data <= proxy_output_bus[proxy_c * WORD_SIZE +: WORD_SIZE];
                    test <= output_matrix[proxy_write_count[proxy_c]][proxy_c] + proxy_output_bus[proxy_c * WORD_SIZE +: WORD_SIZE];
                    proxy_write_count[proxy_c] <= proxy_write_count[proxy_c]+1'b1;   //Tracks what row of output_matrix we are writing to for this proxy
                end
            end
        end
    endgenerate

endmodule