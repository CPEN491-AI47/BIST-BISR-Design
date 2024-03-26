module weight_buffer #(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter NUM_RU = 4,
    parameter WORD_SIZE = 16
)(
    input clk,
    input we,
    input [ROWS-1:0] row[0:NUM_RU-1],
    input [COLS-1:0] col[0:NUM_RU-1],
    input [WORD_SIZE-1:0] weight,
    
    output reg [WORD_SIZE-1:0] q_weight[0:NUM_RU-1]
);
    reg [WORD_SIZE-1:0] buffer[0:ROWS-1][0:COLS-1];

    always @ (posedge clk) begin
        if (we) buffer[row[0]][col[0]] <= weight;
    end

    genvar r;
    generate
        for(r=0; r<NUM_RU-1; r=r+1)
            always @(*)
                q_weight[r] = buffer[row[r]][col[r]];
    endgenerate

endmodule