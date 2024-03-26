`define ROWS 3
`define COLS 3
`define NUM_RU 3

module tb_recompute_module_controller();
    reg clk = 0;
    reg rst;
    reg STW_result_mat[0:`ROWS-1][0:`COLS-1];

    wire [`ROWS-1:0] dataRow[`NUM_RU-1:0];
    wire [`COLS-1:0] dataCol[`NUM_RU-1:0];
    wire [`ROWS-1:0] weightRow[`NUM_RU-1:0];
    wire [`COLS-1:0] weightCol[`NUM_RU-1:0];

    recompute_module_controller #(
        .ROWS(`ROWS),
        .COLS(`COLS),
        .NUM_RU(`NUM_RU)
    ) recompute_module_controller_dut(
        .clk(clk),
        .rst(rst),
        .STW_result_mat(STW_result_mat),
        
        .dataRow(dataRow),
        .dataCol(dataCol),
        .weightRow(weightRow),
        .weightCol(weightCol)
    );

    always #5 clk = ~clk;

    initial begin
        rst = 1;

        #30
        rst = 0;
        STW_result_mat[0][0] = 0;
        STW_result_mat[0][1] = 1;
        STW_result_mat[0][2] = 1;
        STW_result_mat[1][0] = 1;
        STW_result_mat[1][1] = 0;
        STW_result_mat[1][2] = 1;
        STW_result_mat[2][0] = 1;
        STW_result_mat[2][1] = 1;
        STW_result_mat[2][2] = 0;
    end

endmodule