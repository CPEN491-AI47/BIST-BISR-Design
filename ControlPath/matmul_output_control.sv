`include "./header_ws.vh"

//Control path for reading out & storing output matrix values (for weight/input-stationary flows) from systolic_matmul_fsm
//Notes: traditional_mac is double-buffered so each output is maintained for 2 clk cycles (thus wr_en has 1/2 freq of clk)
//Outputs of traditional_systolic are also staggered by 1 clk cycle. 
//Ex: Clk 1: Col 0 output[1] --> maintained for 2 clks (until clk 3)
//    Clk 2: Col 1 output[1]
//    Clk 3: Col 2 output[1] + Col 0 output[2]

//*Update: Modified as to be compatible with OS_Workflow(setup in header file)
module matmul_output_control
#(
    parameter WORD_SIZE = 16
)(
    clk,
    rst,
    matmul_fsm_output,
    matmul_output_valid,
    output_matrix
);

    input clk, rst;
    input [`COLS-1:0] matmul_output_valid;
    input logic [`COLS * WORD_SIZE-1:0] matmul_fsm_output;
    output logic [WORD_SIZE - 1:0] output_matrix[`ROWS][`COLS];

    
    logic [$clog2(`ROWS):0] write_count[`COLS];
    
    logic [`COLS-1:0] wr_en;

    logic [$clog2(`COLS):0] c;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            for(c = 0; c < `COLS; c++) begin
                write_count[c] <= 0;
            end
        end
        else begin
            for(c = 0; c < `COLS; c++) begin
                if(matmul_output_valid[c]) begin
                    wr_en[c] <= ~wr_en[c];   //wr_en[c] serves as timing for when to write to output_matrix col c
                end
                else begin
                    wr_en[c] <= 1'b0;
                end
            end
        end
    end

    genvar c1;
    generate
        for(c1 = 0; c1 < `COLS; c1++) begin
            `ifdef OS_WORKFLOW
            //output matrix contrl for output-stationary workflow 
                always_ff @(posedge clk) begin
                    if(matmul_output_valid[c1]) begin
                        write_count[c1] <= write_count[c1]+1;
                        output_matrix[`COLS-write_count[c1]-1][c1] <= matmul_fsm_output[(c1) * WORD_SIZE +: WORD_SIZE];
                    end
                end
            `else
            //output matrix contrl for weight-stationary workflow 
            //output_matrix[rows][c1] "clocked" by wr_en[c1]
                always_ff @(posedge wr_en[c1]) begin
                    if(matmul_output_valid[c1]) begin
                        write_count[c1] <= write_count[c1]+1;   //Tracks what row of output_matrix we are writing to for col c1
                        output_matrix[write_count[c1]][c1] <= matmul_fsm_output[c1 * WORD_SIZE +: WORD_SIZE];
                    end
                end
            `endif 
        end
    endgenerate

endmodule