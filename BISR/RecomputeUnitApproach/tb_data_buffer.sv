`define WORD_SIZE 16
`define ROWS 3
`define COLS 3
`define NUM_RU 3

module tb_data_buffer();
    reg clk = 0;
    reg we;
    reg [`ROWS-1:0] row[0:`NUM_RU-1];
    reg [`COLS-1:0] col[0:`NUM_RU-1];
    reg [`WORD_SIZE-1:0] data;
    
    wire [`WORD_SIZE-1:0] q_data[0:`NUM_RU-1];

    data_buffer #(
        .ROWS(`ROWS),
        .COLS(`COLS),
        .WORD_SIZE(`WORD_SIZE),
        .NUM_RU(`NUM_RU)
    ) data_buffer_dut(
        .clk(clk),
        .we(we),
        .row(row),
        .col(col),
        .data(data),

        .q_data(q_data)
    );

    always #5 clk = ~clk;

    initial begin
        we = 1;
        row[0] = `ROWS'd0;
        col[0] = `COLS'd0;
        data = `WORD_SIZE'd0;

        #10
        row[0] = `ROWS'd0;
        col[0] = `COLS'd1;
        data = `WORD_SIZE'd1;

        #10
        row[0] = `ROWS'd0;
        col[0] = `COLS'd2;
        data = `WORD_SIZE'd2;

        #10
        row[0] = `ROWS'd1;
        col[0] = `COLS'd0;
        data = `WORD_SIZE'd3;

        #10
        row[0] = `ROWS'd1;
        col[0] = `COLS'd1;
        data = `WORD_SIZE'd4;

        #10
        row[0] = `ROWS'd1;
        col[0] = `COLS'd2;
        data = `WORD_SIZE'd5;

        #10
        row[0] = `ROWS'd2;
        col[0] = `COLS'd0;
        data = `WORD_SIZE'd6;

        #10
        row[0] = `ROWS'd2;
        col[0] = `COLS'd1;
        data = `WORD_SIZE'd7;

        #10
        row[0] = `ROWS'd2;
        col[0] = `COLS'd2;
        data = `WORD_SIZE'd8;

        #30
        we = 0;
        row[0] = `ROWS'd0;
        col[0] = `COLS'd0;

        #10
        row[0] = `ROWS'd0;
        col[0] = `COLS'd1;

        #10
        row[0] = `ROWS'd0;
        col[0] = `COLS'd2;

        #10
        row[0] = `ROWS'd1;
        col[0] = `COLS'd0;

        #10
        row[0] = `ROWS'd1;
        col[0] = `COLS'd1;

        #10
        row[0] = `ROWS'd1;
        col[0] = `COLS'd2;

        #10
        row[0] = `ROWS'd2;
        col[0] = `COLS'd0;

        #10
        row[0] = `ROWS'd2;
        col[0] = `COLS'd1;

        #10
        row[0] = `ROWS'd2;
        col[0] = `COLS'd2;

        #30
        we = 0;
        row[1] = `ROWS'd0;
        col[1] = `COLS'd0;

        #10
        row[1] = `ROWS'd0;
        col[1] = `COLS'd1;

        #10
        row[1] = `ROWS'd0;
        col[1] = `COLS'd2;

        #10
        row[1] = `ROWS'd1;
        col[1] = `COLS'd0;

        #10
        row[1] = `ROWS'd1;
        col[1] = `COLS'd1;

        #10
        row[1] = `ROWS'd1;
        col[1] = `COLS'd2;

        #10
        row[1] = `ROWS'd2;
        col[1] = `COLS'd0;

        #10
        row[1] = `ROWS'd2;
        col[1] = `COLS'd1;

        #10
        row[1] = `ROWS'd2;
        col[1] = `COLS'd2;
    end

endmodule