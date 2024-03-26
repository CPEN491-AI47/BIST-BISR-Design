module recompute_module_controller#(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter NUM_RU = 4
)(
    input clk,
    input rst,
    input STW_result_mat[0:ROWS-1][0:COLS-1],

    output reg [ROWS-1:0] dataRow[NUM_RU-1:0],
    output reg [COLS-1:0] dataCol[NUM_RU-1:0],
    output reg [ROWS-1:0] weightRow[NUM_RU-1:0],
    output reg [COLS-1:0] weightCol[NUM_RU-1:0]
);
    reg [NUM_RU-1:0] count_faults = 0;
    reg [ROWS-1:0] faultyRow[NUM_RU-1:0];
    reg [COLS-1:0] faultyCol[NUM_RU-1:0];

    reg [2:0] state;
    reg [COLS-1:0] i = 0;

    parameter idle = 3'd0;
    parameter doRecomputing1 = 3'd1;
    parameter doRecomputing2 = 3'd2;

    genvar r, c, N;
    generate
        for(N=0; N<NUM_RU; N=N+1)
            for(c=0; c<COLS; c=c+1)
                for(r=0; r<ROWS; r=r+1)
                    always @(*)
                        if(rst)begin
                            faultyRow[N] <= 'dx;
                            faultyCol[N] <= 'dx;
                        end
                        else if(!STW_result_mat[r][c]) begin
                            faultyRow[N] <= r;
                            faultyCol[N] <= c;
                        end
    endgenerate

    genvar f;
    generate
        for(f=0; f<ROWS; f=f+1)
            always @(posedge clk, posedge rst)
                if(rst) begin
                    state <= idle;
                end
                else
                    case(state)
                        idle: begin
                            dataRow[f] <= 'dx;
                            dataCol[f] <= 'dx;
                            weightRow[f] <= 'dx;
                            weightCol[f] <= 'dx;
                            state <= doRecomputing1;
                        end
                        doRecomputing1: begin
                            dataRow[f] <= faultyRow[f]; 
                            dataCol[f] <= 0;
                            weightRow[f] <= faultyRow[f];
                            weightCol[f] <= faultyCol[f];
                            i <= i + 1;
                            state <= doRecomputing2;
                        end
                        doRecomputing2: begin
                            dataRow[f] <= faultyRow[f]; 
                            dataCol[f] <= dataCol[f] + 1;
                            weightRow[f] <= faultyRow[f];
                            weightCol[f] <= faultyCol[f];
                            i <= i + 1;
                            if(i<COLS) state <= doRecomputing2;
                            else state <= idle;
                        end
                    endcase
    endgenerate

endmodule