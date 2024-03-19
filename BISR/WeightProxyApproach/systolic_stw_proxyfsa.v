
`include "./header_ws.vh"   //Enable header_ws for weight-stationary tb
`include "./traditional_mac_stw.v"

// `define ENABLE_FI
// `define ENABLE_STW
`ifdef ENABLE_WPROXY
    `define PROXY_TBD 2'b0
    `define PROXY_SET 2'b01
`endif
module stw_wproxy_systolic
#(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter WORD_SIZE = 16

) (
    clk,
    rst,

    ctl_stat_bit_in, 
    ctl_dummy_fsm_op2_select_in,
    ctl_dummy_fsm_out_select_in,
    `ifdef ENABLE_FI
        fault_inject_bus,
    `endif
    `ifdef ENABLE_STW
        STW_mult_op1,
        STW_mult_op2,
        STW_add_op,
        STW_expected,
        STW_test_load_en,
        STW_start,
        STW_complete_out,
        STW_result_mat,
    `endif
    left_in_bus,
    top_in_bus,
    bottom_out_bus,
    right_out_bus
);

    input clk;
    input rst;

    input [ROWS * WORD_SIZE - 1: 0] left_in_bus;
    input [COLS * WORD_SIZE - 1: 0] top_in_bus;
    output [COLS * WORD_SIZE - 1: 0] bottom_out_bus;
    output [ROWS * WORD_SIZE - 1: 0] right_out_bus;

    input ctl_stat_bit_in; 
    input ctl_dummy_fsm_op2_select_in;
    input ctl_dummy_fsm_out_select_in;

    `ifdef ENABLE_FI
        input [(ROWS * COLS * 2) - 1:0] fault_inject_bus; //total size = ROWS*COLS*(2bits per mac)
    `endif

    `ifdef ENABLE_STW
        input [WORD_SIZE-1:0] STW_mult_op1;
        input [WORD_SIZE-1:0] STW_mult_op2;
        input [WORD_SIZE-1:0] STW_add_op;
        input [WORD_SIZE-1:0] STW_expected;
        input STW_test_load_en;
        input STW_start;
        output STW_complete_out;
        output [(ROWS*COLS)-1:0] STW_result_mat;   //Idx STW_results by col for easier recompute
        
        wire [(ROWS*COLS)-1:0] STW_complete;
        assign STW_complete_out = &STW_complete;
    `endif

    `ifdef ENABLE_WPROXY
        localparam NUM_BITS_ROWS = $clog2(ROWS);

        wire [WORD_SIZE-1:0] rcm_left_in [(ROWS*COLS)-1:0];
        wire [ROWS-1:0] proxy_en [COLS-1:0];   //Enable this PE as a proxy. Index by col bc weights assigned by col - NOTE: use as inputs to left_in mux?
        reg [ROWS-1:0] proxy_map [COLS-1:0];   //Locates which PEs are capable of being a proxy
        reg [2:0] proxy_state;
        reg [NUM_BITS_ROWS-1:0] curr_stationary_row_idx;
        reg set_proxy_en;

        reg [WORD_SIZE-1:0] curr_col_min_weight [COLS-1:0];
        reg [COLS-1:0] load_col_min_weight;

        genvar curr_col;
        generate
            for(curr_col=0; curr_col < COLS; curr_col=curr_col+1) begin
                always @(*) begin
                    if(rst) begin
                        load_col_min_weight[curr_col] = 1'b0;
                    end
                    else begin
                        if(set_proxy_en) begin
                            //if(!ctl_dummy_fsm_out_select_in && ctl_dummy_fsm_op2_select_in) begin  NOTE: <- check if needed
                            if(curr_stationary_row_idx == (ROWS-1'b1)) begin   //First weight in, load as curr_min_weight
                                load_col_min_weight[curr_col] = 1'b1;
                            end
                            else if(top_in_bus[(curr_col+1) * WORD_SIZE - 1 -: WORD_SIZE] < curr_col_min_weight[curr_col]) begin
                                load_col_min_weight[curr_col] = 1'b1;
                            end
                            else begin
                                load_col_min_weight[curr_col] = 1'b0;
                            end
                            //end
                        end
                        else begin
                            load_col_min_weight[curr_col] = 1'b0;
                        end
                    end
                end

                //Update current proxy_map & Record current min weight for comparison
                always @(posedge clk) begin
                    if(rst) begin
                        curr_col_min_weight[curr_col] <= 'b0;
                        proxy_map[curr_col] <= 'b0;
                    end
                    else if(load_col_min_weight[curr_col]) begin
                        curr_col_min_weight[curr_col] <= top_in_bus[(curr_col+1) * WORD_SIZE - 1 -: WORD_SIZE];
                        proxy_map[curr_col] <= 'b0 | (1'b1 << curr_stationary_row_idx);   //Clear prev proxy idx & set new idx
                    end
                end

            end
        endgenerate

        always @(posedge clk) begin   //NOTE: Check if this fsm needs to be in generate (may only need 1 shared amongst all cols)
            if(rst) begin
                proxy_state <= `PROXY_TBD;
                curr_stationary_row_idx <= ROWS;   //FIXME: See if there's a more efficient way to update a onehot proxy_en w/o adding idx of bit
                set_proxy_en <= 1'b0;
            end
            else begin
                case(proxy_state)
                    `PROXY_TBD: begin
                        curr_stationary_row_idx <= ROWS;
                        set_proxy_en <= 1'b0;
                        if(!ctl_dummy_fsm_out_select_in && ctl_dummy_fsm_op2_select_in) begin   //Settings for SET_STATIONARY enabled
                            set_proxy_en <= 1'b1;
                            curr_stationary_row_idx <= curr_stationary_row_idx - 1'b1;

                            if((curr_stationary_row_idx - 1'b1) == 'b0) begin   //This is last cycle of SET_STATIONARY
                                proxy_state <= `PROXY_SET;
                            end
                        end
                        else if(ctl_dummy_fsm_out_select_in && !ctl_dummy_fsm_op2_select_in && ctl_stat_bit_in) begin   //Weight was loaded, moving to matmul stage
                            proxy_state <= `PROXY_SET;
                        end
                        else if (curr_stationary_row_idx == 'b0) begin
                            //NOTE: Check if set_proxy_en still active for this last cycle
                            proxy_state <= `PROXY_SET;
                        end
                    end
                    `PROXY_SET: begin
                        set_proxy_en <= 1'b0;
                        proxy_state <= `PROXY_SET;
                    end
                endcase
            end
        end

    
    `endif

    wire [ROWS * COLS * WORD_SIZE - 1: 0] hor_interconnect;
    wire [COLS * ROWS * WORD_SIZE - 1: 0] ver_interconnect;

    wire [NUM_BITS_ROWS-1:0] rcm_idx_sel [COLS-1:0];
    // wire [ROWS-1:0] proxy_en;
    wire [COLS-1:0] fault_detected;
    wire [WORD_SIZE-1:0] proxy_left_in;
    wire [WORD_SIZE-1:0] rcm_output;

    wire [(ROWS*WORD_SIZE)-1:0] stationary_operand_mat [COLS-1:0];   //Index all stationary operands of all rows in col by col idx
    wire [WORD_SIZE-1:0] rcm_in_weight [COLS-1:0];
    wire [WORD_SIZE-1:0] rcm_top_in [COLS-1:0];

    wire [2:0] col_proxy_settings [COLS-1:0];

    genvar r, c;
    generate
    for (r = 0; r < ROWS; r = r + 1) begin : right_out_genblk
        assign right_out_bus[(r+1) * WORD_SIZE - 1 -: WORD_SIZE] = hor_interconnect[r * COLS * WORD_SIZE + COLS * WORD_SIZE - 1 -: WORD_SIZE];
    end 

    for (c  = 0; c < COLS; c = c + 1) begin : bottom_out_genblk

        assign bottom_out_bus[(c+1) * WORD_SIZE - 1 -: WORD_SIZE] = (fault_detected[c] && c == 1) ? (ver_interconnect[(ROWS * c + ROWS) * WORD_SIZE - 1 -: WORD_SIZE]): ver_interconnect[(ROWS * c + ROWS) * WORD_SIZE - 1 -: WORD_SIZE];
    end

    for (c = 0; c < COLS; c = c+1) begin : rcm_genblk
        multiplexer_Nto1 #(
            .NUM_INPUTS(ROWS),
            .WORD_SIZE(WORD_SIZE)
        ) rcm_stationary_in_mux (
            .input_options_bus(stationary_operand_mat[c]),
            .out_sel(rcm_idx_sel[c]),
            .mux_out(rcm_in_weight[c])
        );

        multiplexer_Nto1 #(
            .NUM_INPUTS(ROWS),
            .WORD_SIZE(WORD_SIZE)
        ) rcm_left_in_mux (
            .input_options_bus(left_in_bus),
            .out_sel(rcm_idx_sel[c]),
            .mux_out(rcm_left_in[c])
        );

        recompute_controller #(
            .ROWS(ROWS),
            .COL_IDX(c),
            .WORD_SIZE(WORD_SIZE)
        ) rcm_ctrl (
            .clk(clk),
            .rst(rst),
            .set_stationary_mode(),
            .matmul_mode(),
            .STW_complete(STW_complete_out),
            .STW_result_mat(STW_result_mat[(c*ROWS) +: ROWS]),   //STW results for this col
            .rcm_idx_sel(rcm_idx_sel[c]),   //Selects idx of weight & bottom_out
            .rcm_in_weight(rcm_in_weight[c]),   //Currently selected weight & bottom_out
            .rcm_in_top(),
            .rcm_in_col_output(bottom_out_bus[(c+1) * WORD_SIZE - 1 -: WORD_SIZE]),
            .proxy_en(proxy_en[c]),
            .rcm_left_in(rcm_left_in[c]),
            .load_proxy(),
            .proxy_matmul(),
            .proxy_settings(col_proxy_settings[c]),
            .fault_detected(fault_detected[c]),
            .proxy_left_in(),
            .rcm_output(),
            .rcm_weight(rcm_top_in[c])
        );
    end
    
    //Added naming for gen blocks and renamed MAC modules for ease of hierarchical reference in tb
    for(r = 0; r < ROWS; r = r+1) begin : mac_row_genblk
        for(c = 0; c < COLS; c = c+1) begin : mac_col_genblk
            localparam VERTICAL_SIGNAL_OFFSET = (c * ROWS + (r+1)) * WORD_SIZE;
            localparam HORIZONTAL_SIGNAL_OFFSET = (r * COLS + (c+1)) * WORD_SIZE;

            if ((r == 0) && (c==0))
            begin : rc
                wire fsm_op2_select_in;
                wire fsm_out_select_in;
                wire stat_bit_in;
                

                
                assign {stat_bit_in, fsm_out_select_in, fsm_op2_select_in} = (fault_detected[c] && proxy_map[c][r]) ? col_proxy_settings[c] : {ctl_stat_bit_in, ctl_dummy_fsm_out_select_in, ctl_dummy_fsm_op2_select_in};
                
                wire [WORD_SIZE-1:0] proxy_stalled_top_in;
                wire [WORD_SIZE-1:0] pe_bottom_out;
                vDFF #(
                    .WORD_SIZE(WORD_SIZE)
                ) proxy_bottom_out_ff (
                    .clk(clk && fault_detected[c] && proxy_map[c][r]),
                    .D(top_in_bus[(c+1) * WORD_SIZE - 1 -: WORD_SIZE]),
                    .Q(proxy_stalled_top_in)
                );
                assign ver_interconnect[VERTICAL_SIGNAL_OFFSET -1 -: WORD_SIZE] = ((fault_detected[c] && proxy_map[c][r])) ? proxy_stalled_top_in : pe_bottom_out;

                wire [WORD_SIZE-1:0] proxy_stalled_left_in;
                wire [WORD_SIZE-1:0] pe_right_out;
                vDFF #(
                    .WORD_SIZE(WORD_SIZE)
                ) proxy_right_out_ff (
                    .clk(clk && fault_detected[c] && proxy_map[c][r]),
                    .D(left_in_bus[(r+1) * WORD_SIZE -1 -: WORD_SIZE]),
                    .Q(proxy_stalled_left_in)
                );
                assign hor_interconnect[HORIZONTAL_SIGNAL_OFFSET -1 -: WORD_SIZE] = ((fault_detected[c] && proxy_map[c][r])) ? proxy_stalled_left_in : pe_right_out;

                wire [WORD_SIZE-1:0] selected_top_in;
                assign selected_top_in = (fault_detected[c] && proxy_map[c][r]) ? rcm_top_in[c] : top_in_bus[(c+1) * WORD_SIZE - 1 -: WORD_SIZE];
                
                wire [WORD_SIZE-1:0] selected_left_in;
                assign selected_left_in = (fault_detected[c] && proxy_map[c][r]) ? rcm_left_in[c] : left_in_bus[(r+1) * WORD_SIZE -1 -: WORD_SIZE];

                // wire [WORD_SIZE-1:0] selected_right_in;
                // assign selected_right_in = (fault_detected[c] && proxy_map[c][r]) ? left_in_bus[(r+1) * WORD_SIZE -1 -: WORD_SIZE] : ;

                wire sel;
                assign sel = fault_detected[c] && proxy_map[c][r];
                wire [WORD_SIZE-1:0] orig_top_in;
                assign orig_top_in = top_in_bus[(c+1) * WORD_SIZE - 1 -: WORD_SIZE];

                traditional_mac_stw #(
                    .WORD_SIZE(WORD_SIZE)
                ) u_mac(
                    .clk(clk),
                    .rst(rst),
                    .fsm_op2_select_in(fsm_op2_select_in),
                    .fsm_out_select_in(fsm_out_select_in),
                    .stat_bit_in(stat_bit_in),
                    `ifdef ENABLE_FI
                        .fault_inject(fault_inject_bus[(c*ROWS+r)*2 +: 2]),
                    `endif
                    `ifdef ENABLE_STW
                        .STW_test_load_en(STW_test_load_en),
                        .STW_mult_op1(STW_mult_op1),
                        .STW_mult_op2(STW_mult_op2),
                        .STW_add_op(STW_add_op),
                        .STW_expected(STW_expected),
                        .STW_start(STW_start),
                        .STW_complete(STW_complete[(r*COLS)+c]),
                        .STW_result_out(STW_result_mat[(c*ROWS)+r]),
                    `endif
                    `ifdef ENABLE_WPROXY
                        .stationary_operand_reg(stationary_operand_mat[c][(r*WORD_SIZE) +: WORD_SIZE]),
                    `endif
                    .left_in(selected_left_in),
                    .top_in(selected_top_in),
                    .right_out(pe_right_out),
                    .bottom_out(pe_bottom_out)
                );


            end
            else if (c==0)
            begin : rc

                localparam TOP_PEER_OFFSET = (c * ROWS + r) * WORD_SIZE;

                wire fsm_op2_select_in;
                wire fsm_out_select_in;
                wire stat_bit_in;
                wire [WORD_SIZE-1:0] selected_top_in;
                
                assign {stat_bit_in, fsm_out_select_in, fsm_op2_select_in} = (fault_detected[c] && proxy_map[c][r]) ? col_proxy_settings[c] : {ctl_stat_bit_in, ctl_dummy_fsm_out_select_in, ctl_dummy_fsm_op2_select_in};
                assign selected_top_in = (fault_detected[c] && proxy_map[c][r]) ? rcm_top_in[c] : ver_interconnect[TOP_PEER_OFFSET -1 -: WORD_SIZE];

                wire [WORD_SIZE-1:0] selected_left_in;
                assign selected_left_in = (fault_detected[c] && proxy_map[c][r]) ? rcm_left_in[c] : left_in_bus[(r+1) * WORD_SIZE -1 -: WORD_SIZE];


                wire [WORD_SIZE-1:0] orig_top_in;
                assign orig_top_in = ver_interconnect[TOP_PEER_OFFSET -1 -: WORD_SIZE];
                wire sel;
                assign sel = fault_detected[c] && proxy_map[c][r];

                wire [WORD_SIZE-1:0] pe_bottom_out;
                // assign ver_interconnect[VERTICAL_SIGNAL_OFFSET -1 -: WORD_SIZE] = (fault_detected[c] && proxy_map[c][r]) ? 'b0 : pe_bottom_out;

                wire [WORD_SIZE-1:0] proxy_stalled_top_in;
                vDFF #(
                    .WORD_SIZE(WORD_SIZE)
                ) proxy_bottom_out_ff (
                    .clk(clk && fault_detected[c] && proxy_map[c][r]),
                    .D(top_in_bus[(c+1) * WORD_SIZE - 1 -: WORD_SIZE]),
                    .Q(proxy_stalled_top_in)
                );
                assign ver_interconnect[VERTICAL_SIGNAL_OFFSET -1 -: WORD_SIZE] = ((fault_detected[c] && proxy_map[c][r])) ? proxy_stalled_top_in : pe_bottom_out;

                wire [WORD_SIZE-1:0] proxy_stalled_left_in;
                wire [WORD_SIZE-1:0] pe_right_out;
                vDFF #(
                    .WORD_SIZE(WORD_SIZE)
                ) proxy_right_out_ff (
                    .clk(clk && fault_detected[c] && proxy_map[c][r]),
                    .D(left_in_bus[(r+1) * WORD_SIZE -1 -: WORD_SIZE]),
                    .Q(proxy_stalled_left_in)
                );
                assign hor_interconnect[HORIZONTAL_SIGNAL_OFFSET -1 -: WORD_SIZE]= ((fault_detected[c] && proxy_map[c][r])) ? proxy_stalled_left_in : pe_right_out;


                traditional_mac_stw #(
                    .WORD_SIZE(WORD_SIZE)
                ) u_mac(
                    .clk(clk),
                    .rst(rst),
                    .fsm_op2_select_in(fsm_op2_select_in),
                    .fsm_out_select_in(fsm_out_select_in),
                    .stat_bit_in(stat_bit_in),
                    `ifdef ENABLE_FI
                        .fault_inject(fault_inject_bus[(c*ROWS+r)*2 +: 2]),
                    `endif
                    `ifdef ENABLE_STW
                        .STW_test_load_en(STW_test_load_en),
                        .STW_mult_op1(STW_mult_op1),
                        .STW_mult_op2(STW_mult_op2),
                        .STW_add_op(STW_add_op),
                        .STW_expected(STW_expected),
                        .STW_start(STW_start),
                        .STW_complete(STW_complete[(r*COLS)+c]),
                        .STW_result_out(STW_result_mat[(c*ROWS)+r]),
                    `endif
                    `ifdef ENABLE_WPROXY
                        .stationary_operand_reg(stationary_operand_mat[c][(r*WORD_SIZE) +: WORD_SIZE]),
                    `endif
                    .left_in(selected_left_in),
                    .top_in(selected_top_in),
                    .right_out(pe_right_out),
                    .bottom_out(pe_bottom_out)
                );
            end
            else if (r==0)
            begin : rc

                localparam LEFT_PEER_OFFSET = (r * COLS + c) * WORD_SIZE;

                wire fsm_op2_select_in;
                wire fsm_out_select_in;
                wire stat_bit_in;
                wire [WORD_SIZE-1:0] selected_top_in;
                
                assign {stat_bit_in, fsm_out_select_in, fsm_op2_select_in} = (fault_detected[c] && proxy_map[c][r]) ? col_proxy_settings[c] : {ctl_stat_bit_in, ctl_dummy_fsm_out_select_in, ctl_dummy_fsm_op2_select_in};
                assign selected_top_in = (fault_detected[c] && proxy_map[c][r]) ? rcm_top_in[c] : top_in_bus[(c+1) * WORD_SIZE - 1 -: WORD_SIZE];

                wire [WORD_SIZE-1:0] selected_left_in;
                assign selected_left_in = (fault_detected[c] && proxy_map[c][r]) ? rcm_left_in[c] : hor_interconnect[LEFT_PEER_OFFSET - 1 -: WORD_SIZE];

                wire [WORD_SIZE-1:0] orig_top_in;
                assign orig_top_in = top_in_bus[(c+1) * WORD_SIZE - 1 -: WORD_SIZE];
                wire sel;
                assign sel = fault_detected[c] && proxy_map[c][r];

                wire [WORD_SIZE-1:0] pe_bottom_out;
                // assign ver_interconnect[VERTICAL_SIGNAL_OFFSET -1 -: WORD_SIZE] = (fault_detected[c] && proxy_map[c][r]) ? 'b0 : pe_bottom_out;
                wire [WORD_SIZE-1:0] proxy_stalled_top_in;
                vDFF #(
                    .WORD_SIZE(WORD_SIZE)
                ) proxy_bottom_out_ff (
                    .clk(clk && fault_detected[c] && proxy_map[c][r]),
                    .D(top_in_bus[(c+1) * WORD_SIZE - 1 -: WORD_SIZE]),
                    .Q(proxy_stalled_top_in)
                );
                assign ver_interconnect[VERTICAL_SIGNAL_OFFSET -1 -: WORD_SIZE] = ((fault_detected[c] && proxy_map[c][r])) ? proxy_stalled_top_in : pe_bottom_out;

                wire [WORD_SIZE-1:0] proxy_stalled_left_in;
                wire [WORD_SIZE-1:0] pe_right_out;
                vDFF #(
                    .WORD_SIZE(WORD_SIZE)
                ) proxy_right_out_ff (
                    .clk(clk && fault_detected[c] && proxy_map[c][r]),
                    .D(hor_interconnect[LEFT_PEER_OFFSET - 1 -: WORD_SIZE]),
                    .Q(proxy_stalled_left_in)
                );
                assign hor_interconnect[HORIZONTAL_SIGNAL_OFFSET -1 -: WORD_SIZE]= ((fault_detected[c] && proxy_map[c][r])) ? proxy_stalled_left_in : pe_right_out;

                traditional_mac_stw #(
                    .WORD_SIZE(WORD_SIZE)
                ) u_mac(
                    .clk(clk),
                    .rst(rst),
                    .fsm_op2_select_in(fsm_op2_select_in),
                    .fsm_out_select_in(fsm_out_select_in),
                    .stat_bit_in(stat_bit_in),
                    `ifdef ENABLE_FI
                        .fault_inject(fault_inject_bus[(c*ROWS+r)*2 +: 2]),
                    `endif
                    `ifdef ENABLE_STW
                        .STW_test_load_en(STW_test_load_en),
                        .STW_mult_op1(STW_mult_op1),
                        .STW_mult_op2(STW_mult_op2),
                        .STW_add_op(STW_add_op),
                        .STW_expected(STW_expected),
                        .STW_start(STW_start),
                        .STW_complete(STW_complete[(r*COLS)+c]),
                        .STW_result_out(STW_result_mat[(c*ROWS)+r]),
                    `endif
                    `ifdef ENABLE_WPROXY
                        .stationary_operand_reg(stationary_operand_mat[c][(r*WORD_SIZE) +: WORD_SIZE]),
                    `endif
                    .left_in(selected_left_in),
                    .top_in(selected_top_in),
                    .right_out(pe_right_out),
                    .bottom_out(pe_bottom_out)
                );

            end
            else
            begin : rc

                localparam TOP_PEER_OFFSET =  (c * ROWS + r)  * WORD_SIZE;
                localparam LEFT_PEER_OFFSET = (r * COLS + c) * WORD_SIZE;

                wire fsm_op2_select_in;
                wire fsm_out_select_in;
                wire stat_bit_in;
                wire [WORD_SIZE-1:0] selected_top_in;
                
                wire [WORD_SIZE-1:0] orig_top_in;
                assign orig_top_in = ver_interconnect[TOP_PEER_OFFSET -1 -: WORD_SIZE];
                wire sel;
                assign sel = fault_detected[c] && proxy_map[c][r];

                assign {stat_bit_in, fsm_out_select_in, fsm_op2_select_in} = (fault_detected[c] && proxy_map[c][r]) ? col_proxy_settings[c] : {ctl_stat_bit_in, ctl_dummy_fsm_out_select_in, ctl_dummy_fsm_op2_select_in};
                assign selected_top_in = (fault_detected[c] && proxy_map[c][r]) ? rcm_top_in[c] : ver_interconnect[TOP_PEER_OFFSET -1 -: WORD_SIZE];

                wire [WORD_SIZE-1:0] selected_left_in;
                assign selected_left_in = (fault_detected[c] && proxy_map[c][r]) ? rcm_left_in[c] : hor_interconnect[LEFT_PEER_OFFSET - 1 -: WORD_SIZE];
                
                wire [WORD_SIZE-1:0] pe_bottom_out;
                // assign ver_interconnect[VERTICAL_SIGNAL_OFFSET -1 -: WORD_SIZE] = (fault_detected[c] && proxy_map[c][r]) ? 'b0 : pe_bottom_out;
                wire [WORD_SIZE-1:0] proxy_stalled_top_in;
                vDFF #(
                    .WORD_SIZE(WORD_SIZE)
                ) proxy_bottom_out_ff (
                    .clk(clk && fault_detected[c] && proxy_map[c][r]),
                    .D(top_in_bus[(c+1) * WORD_SIZE - 1 -: WORD_SIZE]),
                    .Q(proxy_stalled_top_in)
                );
                assign ver_interconnect[VERTICAL_SIGNAL_OFFSET -1 -: WORD_SIZE] = ((fault_detected[c] && proxy_map[c][r])) ? proxy_stalled_top_in : pe_bottom_out;


                wire [WORD_SIZE-1:0] proxy_stalled_left_in;
                wire [WORD_SIZE-1:0] pe_right_out;
                vDFF #(
                    .WORD_SIZE(WORD_SIZE)
                ) proxy_right_out_ff (
                    .clk(clk && fault_detected[c] && proxy_map[c][r]),
                    .D(hor_interconnect[LEFT_PEER_OFFSET - 1 -: WORD_SIZE]),
                    .Q(proxy_stalled_left_in)
                );
                assign hor_interconnect[HORIZONTAL_SIGNAL_OFFSET -1 -: WORD_SIZE]= ((fault_detected[c] && proxy_map[c][r])) ? proxy_stalled_left_in : pe_right_out;

                traditional_mac_stw #(
                    .WORD_SIZE(WORD_SIZE)
                ) u_mac(
                    .clk(clk),
                    .rst(rst),
                    .fsm_op2_select_in(fsm_op2_select_in),
                    .fsm_out_select_in(fsm_out_select_in),
                    .stat_bit_in(stat_bit_in),
                    `ifdef ENABLE_FI
                        .fault_inject(fault_inject_bus[(c*ROWS+r)*2 +: 2]),
                    `endif
                    `ifdef ENABLE_STW
                        .STW_test_load_en(STW_test_load_en),
                        .STW_mult_op1(STW_mult_op1),
                        .STW_mult_op2(STW_mult_op2),
                        .STW_add_op(STW_add_op),
                        .STW_expected(STW_expected),
                        .STW_start(STW_start),
                        .STW_complete(STW_complete[(r*COLS)+c]),
                        .STW_result_out(STW_result_mat[(c*ROWS)+r]),
                    `endif
                    `ifdef ENABLE_WPROXY
                        .stationary_operand_reg(stationary_operand_mat[c][(r*WORD_SIZE) +: WORD_SIZE]),
                    `endif
                    .left_in(selected_left_in),
                    .top_in(selected_top_in),
                    .right_out(pe_right_out),
                    .bottom_out(pe_bottom_out)
                );
            end
        end
    end
    endgenerate

endmodule
