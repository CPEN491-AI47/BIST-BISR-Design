module data_buffer #(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter NUM_RU = 4,
    parameter WORD_SIZE = 16
)(
    input clk,
    input we,
    input [ROWS-1:0] row[0:NUM_RU-1],
    input [COLS-1:0] col[0:NUM_RU-1],
    input [WORD_SIZE-1:0] data,
    
    output reg [WORD_SIZE-1:0] q_data[0:NUM_RU-1]
);
    reg [WORD_SIZE-1:0] buffer[0:ROWS-1][0:COLS-1];

    always @ (posedge clk) begin
        if (we) buffer[row[0]][col[0]] <= data;
    end

    genvar r;
    generate
        for(r=0; r<NUM_RU-1; r=r+1)
            always @(*)
                q_data[r] = buffer[row[r]][col[r]];
    endgenerate
endmodule
