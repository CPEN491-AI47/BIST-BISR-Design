module recompute_module #(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter WORD_SIZE = 16,
    parameter NUM_RU = 4
)(
    input clk,
    input rst,
    input STW_result_mat[0:ROWS-1][0:COLS-1], 
    input [WORD_SIZE-1:0] q_data[0:NUM_RU-1],
    input [WORD_SIZE-1:0] q_weight[0:NUM_RU-1],

    output [ROWS-1:0] dataRow[0:NUM_RU-1],
    output [COLS-1:0] dataCol[0:NUM_RU-1],
    output [ROWS-1:0] weightRow[0:NUM_RU-1],
    output [COLS-1:0] weightCol[0:NUM_RU-1],
    output [WORD_SIZE-1:0] BottomOut[0:NUM_RU-1]
);

    wire start_recomputing;


    recompute_module_controller #(
        .ROWS(ROWS),
        .COLS(COLS),
        .NUM_RU(NUM_RU)
    ) rcm_controller_gen(
        .clk(clk),
        .rst(rst),
        .STW_result_mat(STW_result_mat),

        .start_recomputing(start_recomputing),
        .dataRow(dataRow),
        .dataCol(dataCol),
        .weightRow(weightRow),
        .weightCol(weightCol)
    );

    genvar N;
    generate
        for(N = 0; N<NUM_RU; N=N+1)
            recompute_unit #(
                .WORD_SIZE(WORD_SIZE),
                .ROWS(ROWS),
                .COLS(COLS)
            ) rcm_unit_gen(
                .clk(clk),
                .rst(rst),
                .start(start_recomputing),
                .Weight(q_weight[N]),
                .LeftIn(q_data[N]),

                .BottomOut(BottomOut[N])
            );
    endgenerate

endmodule
