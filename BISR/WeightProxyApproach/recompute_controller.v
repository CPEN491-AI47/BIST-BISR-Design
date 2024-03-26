`define SET_PROXY 3'b0
`define PROXY_COMPUTE 3'b01
`define SET_PROXY2 3'b010

//Control recomputing for 1 col
module recompute_controller
#(
    parameter ROWS = 4,
    parameter COL_IDX = 0,   //Col that this controller is responsible for
    parameter WORD_SIZE = 16

) (
    clk,
    rst,
    set_stationary_mode,
    matmul_mode,
    STW_complete,
    STW_result_mat,   //STW results for this col
    rcm_idx_sel,   //Selects idx of weight & bottom_out
    rcm_in_weight,   //Currently selected weight & bottom_out
    rcm_in_top,
    rcm_in_col_output,
    proxy_en,
    load_proxy,
    proxy_matmul,
    proxy_settings,
    rcm_left_in,
    fault_detected,
    proxy_left_in,
    rcm_output,
    rcm_weight,
    proxy_out_valid
);

    localparam ROW_WIDTH = $clog2(ROWS);

    input clk, rst;
    input set_stationary_mode;
    input matmul_mode;
    input STW_complete;
    input [ROWS-1:0] STW_result_mat;

    input [WORD_SIZE-1:0] rcm_in_weight;
    input [WORD_SIZE-1:0] rcm_in_top;
    input [WORD_SIZE-1:0] rcm_in_col_output;

    output [ROW_WIDTH-1:0] rcm_idx_sel;
    output [ROWS-1:0] proxy_en;
    output fault_detected;
    output reg [WORD_SIZE-1:0] proxy_left_in;
    // output reg [WORD_SIZE-1:0] proxy_top_in;
    output reg [WORD_SIZE-1:0] rcm_output;

    wire [ROW_WIDTH-1:0] priority_fault_idx;
    output reg [WORD_SIZE-1:0] rcm_weight;
    output reg [2:0] proxy_settings;   //From msb <- lsb: {stat_bit_in, fsm_out_select_in, fsm_op2_select_in}
    output reg proxy_out_valid;

    //TODO: Try using onehot as index (may be less logic)
    priority_encoder #(
        .INPUT_WIDTH(ROWS)
    ) fault_idx_encoder (
        .rst(rst),
        .data_in(STW_result_mat),
        .encoded_out(priority_fault_idx)
    );
    
    assign fault_detected = ~(&STW_result_mat);   //If STW_results is all 1, then fault_det = 0
    assign proxy_en = fault_detected ? ('b1 << priority_fault_idx) : 'b0;
    assign rcm_idx_sel = priority_fault_idx;

    reg [2:0] rcm_state;
    output reg load_proxy;
    output reg proxy_matmul;
    input [WORD_SIZE-1:0] rcm_left_in;

    // assign proxy_out_valid = (proxy_left_in != 'b0);

    //Regs to keep timing of left_in & top_in
    always @(posedge clk) begin
        if(rst) begin
            proxy_left_in <= 'b0;
            proxy_out_valid <= 'b0;
        end
        else begin
            proxy_left_in <= rcm_left_in;
            proxy_out_valid <= (proxy_left_in != 'b0);
        end
    end

    //TODO: Reset assigned proxy when next weights loaded in?
    always @(posedge clk) begin
        if(rst) begin
            proxy_settings <= 3'b0;
            load_proxy <= 1'b0;
            proxy_matmul <= 1'b0;
            rcm_weight <= 'b0;
            rcm_state <= `SET_PROXY;
        end
        else begin
            case(rcm_state)
                `SET_PROXY: begin
                    if(fault_detected) begin
                        rcm_weight <= rcm_in_weight;
                        proxy_settings <= {3'b001};   //For loading stationary: !fsm_out_select_in && fsm_op2_select_in
                        load_proxy <= 1'b1;
                        proxy_matmul <= 1'b0;
                        rcm_state <= `SET_PROXY2;
                    end
                    else begin
                        load_proxy <= 1'b0;
                        rcm_weight <= 'b0;
                        proxy_matmul <= 1'b0;
                        proxy_settings <= 3'b0;
                    end
                end
                `SET_PROXY2: begin
                    rcm_weight <= rcm_in_weight;
                    proxy_settings <= {3'b001};
                    rcm_state <= `PROXY_COMPUTE;
                end

                `PROXY_COMPUTE: begin
                    rcm_weight <= 'b0;
                    proxy_matmul <= 1'b1;
                    proxy_settings <= {3'b110};   //For matmul: ctl_dummy_fsm_out_select_in && !ctl_dummy_fsm_op2_select_in && ctl_stat_bit_in
                end
            endcase
        end
    end

endmodule