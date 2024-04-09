
`include "./header_ws.vh"   //Enable header_ws for weight-stationary tb
`include "./traditional_mac_stw.sv"

// `define ENABLE_FI
// `define ENABLE_STW

`ifdef ENABLE_STW
    `define STW_IDLE 2'd0
    `define STW_LOAD 2'd1
    `define STW_RUN 2'd2
`endif

`ifdef ENABLE_WPROXY
    `define PROXY_TBD 2'b0
    `define MEM_RD_DELAY 2'b01
    `define PROXY_SET 2'b10
`endif
module stw_wproxy_systolic
#(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter WORD_SIZE = 16

) (
    clk,
    rst,
    stall,
    
    set_stat_start,

    ctl_stat_bit_in, 
    ctl_dummy_fsm_op2_select_in,
    ctl_dummy_fsm_out_select_in,
    `ifdef ENABLE_FI
        fault_inject_bus,
    `endif
    `ifdef ENABLE_STW
        // STW_mult_op1,
        // STW_mult_op2,
        // STW_add_op,
        // STW_expected,
        // STW_test_load_en,
        // STW_start,
        STW_complete_out,
        STW_result_mat,
        stw_en,
    `endif
    `ifdef ENABLE_WPROXY
        proxy_output_bus,
        proxy_out_valid_bus,
    `endif
    left_in_bus,
    top_in_bus,
    bottom_out_bus,
    right_out_bus
);

    input clk;
    input rst;
    input stall;

    input set_stat_start;

    input logic signed [ROWS * WORD_SIZE - 1: 0] left_in_bus;
    input logic signed [COLS * WORD_SIZE - 1: 0] top_in_bus;
    output logic signed [COLS * WORD_SIZE - 1: 0] bottom_out_bus;
    output logic signed [ROWS * WORD_SIZE - 1: 0] right_out_bus;

    input ctl_stat_bit_in; 
    input ctl_dummy_fsm_op2_select_in;
    input ctl_dummy_fsm_out_select_in;

    `ifdef ENABLE_FI
        input [(ROWS * COLS * 2) - 1:0] fault_inject_bus; //total size = ROWS*COLS*(2bits per mac)
    `endif

    `ifdef ENABLE_STW
        // input [WORD_SIZE-1:0] STW_mult_op1;
        // input [WORD_SIZE-1:0] STW_mult_op2;
        // input [WORD_SIZE-1:0] STW_add_op;
        // input [WORD_SIZE-1:0] STW_expected;
        // input STW_test_load_en;
        // input STW_start;

        //Test cases for Stop-the-World Self-test/Diagnosis
        logic signed [WORD_SIZE-1:0] STW_mult_op1;
        logic signed [WORD_SIZE-1:0] STW_mult_op2;
        logic signed [WORD_SIZE-1:0] STW_add_op;
        logic signed [WORD_SIZE-1:0] STW_expected;
        //Use hardcoded values defined in header file
        assign {STW_mult_op1, STW_mult_op2, STW_add_op, STW_expected} = {`stw_mult_op1, `stw_mult_op2, `stw_add_op, `stw_expected_out};

        reg STW_test_load_en;
        reg STW_start;
        reg stw_loaded;   //STW regs are loaded with pre-defined testcases & ready to proceed w diagnosis
        
        input stw_en;

        output STW_complete_out;
        output [(ROWS*COLS)-1:0] STW_result_mat;   //Idx STW_results by col for easier recompute
        
        wire [(ROWS*COLS)-1:0] STW_complete;
        assign STW_complete_out = &STW_complete;
    `endif

    `ifdef ENABLE_WPROXY
        localparam NUM_BITS_ROWS = $clog2(ROWS);

        logic signed [WORD_SIZE-1:0] rcm_left_in [(ROWS*COLS)-1:0];
        wire [ROWS-1:0] proxy_en [COLS-1:0];   //Enable this PE as a proxy. Index by col bc weights assigned by col - NOTE: use as inputs to left_in mux?
        reg [ROWS-1:0] proxy_map [COLS-1:0];   //Locates which PEs are capable of being a proxy
        reg [2:0] proxy_state;
        reg [NUM_BITS_ROWS:0] curr_stationary_row_idx;
        reg set_proxy_en;

        logic signed [WORD_SIZE-1:0] curr_col_min_weight [COLS-1:0];
        reg [COLS-1:0] load_col_min_weight;

        genvar curr_col;
        generate
            for(curr_col=0; curr_col < COLS; curr_col=curr_col+1) begin : load_col_min_weight_genblk
                //If set_proxy_en: Compare each incoming weight to find smallest to set as Proxy
                always @(*) begin
                    if(rst) begin
                        load_col_min_weight[curr_col] = 1'b0;
                    end
                    else begin
                        if(set_proxy_en) begin
                            if(curr_stationary_row_idx == (ROWS-1)) begin   //First weight in, load as curr_min_weight
                                load_col_min_weight[curr_col] = 1'b1;
                            end
                            else if(top_in_bus[(curr_col+1) * WORD_SIZE - 2 -: (WORD_SIZE-1)] < curr_col_min_weight[curr_col][(WORD_SIZE-1):0]) begin
                                load_col_min_weight[curr_col] = 1'b1;
                            end
                            else begin
                                load_col_min_weight[curr_col] = 1'b0;
                            end
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
                        proxy_map[curr_col] <= 'b0 | (1'b1 << (curr_stationary_row_idx));   //Clear prev proxy idx & set new idx
                    end
                end

            end
        endgenerate

        reg proxy_map_done;
        reg [`MEM_ACCESS_LATENCY:0] mem_delay;
        //Maintains set_proxy_en according to current state of systolic (SET_STATIONARY or MATMUL)
        always @(posedge clk) begin   //NOTE: Check if this fsm needs to be in generate (may only need 1 shared amongst all cols)
            if(rst) begin
                proxy_state <= `PROXY_TBD;
                curr_stationary_row_idx <= (ROWS);   //FIXME: See if there's a more efficient way to update a onehot proxy_en w/o adding idx of bit
                mem_delay <= `MEM_ACCESS_LATENCY-1;
                set_proxy_en <= 1'b0;
                proxy_map_done <= 1'b0;
            end
            else begin
                case(proxy_state)
                    `PROXY_TBD: begin
                        curr_stationary_row_idx <= ROWS;
                        mem_delay <= `MEM_ACCESS_LATENCY-1;
                        set_proxy_en <= 1'b0;
                        if(set_stat_start && !ctl_dummy_fsm_out_select_in && ctl_dummy_fsm_op2_select_in) begin   //Settings for SET_STATIONARY enabled
                            set_proxy_en <= 1'b1;
                            curr_stationary_row_idx <= curr_stationary_row_idx - 1'b1;

                            // if((curr_stationary_row_idx - 1'b1) == 'b0) begin   //This is last cycle of SET_STATIONARY
                            //     proxy_state <= `PROXY_SET;
                            // end
                            // else
                                proxy_state <= `MEM_RD_DELAY;
                        end
                        else if(ctl_dummy_fsm_out_select_in && !ctl_dummy_fsm_op2_select_in && ctl_stat_bit_in) begin   //Weight was loaded, moving to matmul stage
                            set_proxy_en <= 1'b1;
                            proxy_state <= `PROXY_SET;
                        end
                        // else if (curr_stationary_row_idx == 'b0) begin
                        //     //NOTE: Check if set_proxy_en still active for this last cycle
                        //     proxy_state <= `PROXY_SET;
                        // end
                        else begin
                            proxy_state <= `PROXY_TBD;
                        end
                    end

                    `MEM_RD_DELAY: begin
                        
                        if((mem_delay) == 'd0) begin
                            // curr_stationary_row_idx <= curr_stationary_row_idx - 1'b1;
                            proxy_state <= `PROXY_TBD;
                        end
                        else
                            mem_delay <= mem_delay-1'b1;

                        // if((curr_stationary_row_idx) == 'b0) begin   //This is last cycle of SET_STATIONARY
                        //         proxy_state <= `PROXY_SET;
                        //     end
                    end

                    `PROXY_SET: begin
                        proxy_map_done <= 1'b1;
                        set_proxy_en <= 1'b0;
                        proxy_state <= `PROXY_SET;
                    end
                endcase
            end
        end  
    `endif

    `ifdef ENABLE_STW
        reg [1:0] stw_state;
        reg stw_in_progress;
        
        always @(posedge clk) begin
            if(rst) begin
                STW_start <= 0;
                STW_test_load_en <= 0;
                stw_in_progress <= 0;
                stw_loaded <= 0;
                stw_state <= `STW_LOAD;   //Loading of STW regs happens once at start of operation
            end
            else begin
                case(stw_state)
                    `STW_LOAD: begin
                        stw_in_progress <= 1;
                        STW_test_load_en <= 1;
                        stw_loaded <= 0;
                        stw_state <= `STW_IDLE;
                    end

                    `STW_IDLE: begin
                        stw_loaded <= 1;
                        STW_start <= (stw_en && stw_loaded);
                        STW_test_load_en <= 0;
                        stw_in_progress <= 1;

                        if(stw_en && stw_loaded) begin   //Proceed with diagnosis if stw_en and STW regs are ready
                            STW_start <= 1;
                            stw_state <= `STW_RUN;
                        end
                        else
                            stw_state <= `STW_IDLE;
                    end

                    `STW_RUN: begin
                        STW_start <= 0;
                        stw_state <= `STW_IDLE;
                    end

                    default: stw_state <= `STW_LOAD;
                endcase
            end
        end
    `endif

    logic signed [ROWS * COLS * WORD_SIZE - 1: 0] hor_interconnect;
    logic signed [COLS * ROWS * WORD_SIZE - 1: 0] ver_interconnect;

    wire [NUM_BITS_ROWS-1:0] fpe_idx_sel [COLS-1:0];
    // wire [ROWS-1:0] proxy_en;
    wire [COLS-1:0] fault_detected;
    logic signed [WORD_SIZE-1:0] proxy_left_in;
    logic signed [WORD_SIZE-1:0] fpe_output;

    logic signed [(ROWS*WORD_SIZE)-1:0] stationary_operand_mat [COLS-1:0];   //Index all stationary operands of all rows in col by col idx
    logic signed [WORD_SIZE-1:0] fpe_in_weight [COLS-1:0];
    logic signed [WORD_SIZE-1:0] rcm_top_in [COLS-1:0];

    wire [2:0] col_proxy_settings [COLS-1:0];

    output [COLS-1:0] proxy_out_valid_bus;
    output logic signed [(COLS*WORD_SIZE)-1: 0] proxy_output_bus;

    logic signed [(ROWS*WORD_SIZE)-1:0] pe_bottom_out [COLS-1:0];
    wire [NUM_BITS_ROWS-1:0] proxy_idx [COLS-1:0];

    logic signed [WORD_SIZE-1:0] proxy_stalled_top_in [COLS-1:0];
    logic signed [WORD_SIZE-1:0] proxy_stalled_right_out [COLS-1:0];
    logic signed [(ROWS*WORD_SIZE)-1:0] col_idxed_hor_interconnect [COLS-1:0];   //hor_interconnect organized by col
    
    genvar r, c;
    generate
    for (r = 0; r < ROWS; r = r + 1) begin : right_out_genblk
        assign right_out_bus[(r+1) * WORD_SIZE - 1 -: WORD_SIZE] = hor_interconnect[r * COLS * WORD_SIZE + COLS * WORD_SIZE - 1 -: WORD_SIZE];
        
        for(c = 0; c < COLS; c = c+1) begin : col_idx_horinterconnect_genblk
            localparam COLS_NEQ0_LEFT_PEER_OFFSET = (r * COLS + c) * WORD_SIZE;
            assign col_idxed_hor_interconnect[c][(r*WORD_SIZE) +: WORD_SIZE] = hor_interconnect[COLS_NEQ0_LEFT_PEER_OFFSET +: WORD_SIZE];
        end
    end 

    for (c  = 0; c < COLS; c = c + 1) begin : bottom_out_genblk

        assign bottom_out_bus[(c+1) * WORD_SIZE - 1 -: WORD_SIZE] = ver_interconnect[(ROWS * c + ROWS) * WORD_SIZE - 1 -: WORD_SIZE];
    end

    for (c = 0; c < COLS; c = c+1) begin : rcm_genblk
        multiplexer_Nto1 #(
            .NUM_INPUTS(ROWS),
            .WORD_SIZE(WORD_SIZE)
        ) rcm_stationary_in_mux (
            .input_options_bus(stationary_operand_mat[c]),
            .out_sel(fpe_idx_sel[c]),
            .mux_out(fpe_in_weight[c])
        );

        multiplexer_Nto1 #(
            .NUM_INPUTS(ROWS),
            .WORD_SIZE(WORD_SIZE)
        ) rcm_left_in_mux (
            .input_options_bus(left_in_bus),
            .out_sel(fpe_idx_sel[c]),
            .mux_out(rcm_left_in[c])
        );

        priority_encoder #(
            .INPUT_WIDTH(ROWS),
            .ENCODED_VAL(1)
        ) proxy_idx_encoder (
            .rst(rst),
            .data_in(proxy_map[c]),
            .encoded_out(proxy_idx[c])
        );

        multiplexer_Nto1 #(
            .NUM_INPUTS(ROWS),
            .WORD_SIZE(WORD_SIZE)
        ) proxy_output_mux (
            .input_options_bus(pe_bottom_out[c]),
            .out_sel(proxy_idx[c]),
            .mux_out(proxy_output_bus[(c*WORD_SIZE) +: WORD_SIZE])
        );

        logic signed [(ROWS*WORD_SIZE)-1:0] col_top_in;   //Bus with top_in of each row in curr col
        logic signed [WORD_SIZE-1:0] proxy_top_in;
        localparam ROWS_NEQ0_TOP_IN_OFFSET = (c*ROWS)*WORD_SIZE;
        assign col_top_in = {ver_interconnect[ROWS_NEQ0_TOP_IN_OFFSET +: ((ROWS-1)*WORD_SIZE)], top_in_bus[(c+1) * WORD_SIZE - 1 -: WORD_SIZE]};
       
        multiplexer_Nto1 #(
            .NUM_INPUTS(ROWS),
            .WORD_SIZE(WORD_SIZE)
        ) proxy_top_in_mux (
            .input_options_bus(col_top_in),
            .out_sel(proxy_idx[c]),
            .mux_out(proxy_top_in)
        );


        logic signed [(ROWS*WORD_SIZE)-1:0] col_left_in;
        logic signed [WORD_SIZE-1:0] proxy_orig_left_in;

        always @(*) begin
            if(c == 0)
                col_left_in = left_in_bus;
            else 
                col_left_in = col_idxed_hor_interconnect[c];
        end
        
        multiplexer_Nto1 #(
            .NUM_INPUTS(ROWS),
            .WORD_SIZE(WORD_SIZE)
        ) proxy_orig_left_in_mux (
            .input_options_bus(col_left_in),
            .out_sel(proxy_idx[c]),
            .mux_out(proxy_orig_left_in)
        );

        wire [COLS-1:0] proxy_matmul_mode;
        wire [COLS-1:0] proxy_setstationary_mode;
        proxy_controller #(
            .ROWS(ROWS),
            .COL_IDX(c),
            .WORD_SIZE(WORD_SIZE)
        ) proxy_ctrl (
            .clk(clk),
            .rst(rst),
            .stall(stall),
            .set_stationary_mode(proxy_setstationary_mode[c]),
            .matmul_mode(proxy_matmul_mode[c]),
            .STW_complete(STW_complete_out),
            .STW_result_mat(STW_result_mat[(c*ROWS) +: ROWS]),   //STW results for this col
            .fpe_idx_sel(fpe_idx_sel[c]),   //Selects idx of weight & bottom_out
            .fpe_in_weight(fpe_in_weight[c]),   //Currently selected weight & bottom_out
            .fpe_in_top(),
            .fpe_in_col_output(bottom_out_bus[(c+1) * WORD_SIZE - 1 -: WORD_SIZE]),
            .proxy_en(proxy_en[c]),
            .rcm_left_in(rcm_left_in[c]),
            .load_proxy(),
            .proxy_matmul(),
            .proxy_settings(col_proxy_settings[c]),
            .fault_detected(fault_detected[c]),
            .proxy_left_in(),
            .fpe_output(),
            .fpe_weight(rcm_top_in[c]),
            .proxy_top_in(proxy_top_in),
            .proxy_orig_left_in(proxy_orig_left_in),
            .proxy_stalled_top_in(proxy_stalled_top_in[c]),
            .proxy_stalled_right_out(proxy_stalled_right_out[c]),
            .proxy_out_valid(proxy_out_valid_bus[c]),
            .proxy_map_done(proxy_map_done)
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
                                
                assign ver_interconnect[VERTICAL_SIGNAL_OFFSET -1 -: WORD_SIZE] = ((fault_detected[c] && proxy_map[c][r])) ? proxy_stalled_top_in[c] : pe_bottom_out[c][((r+1)*WORD_SIZE)-1 -: WORD_SIZE];

                logic signed [WORD_SIZE-1:0] selected_bottom_out;
                assign selected_bottom_out = ver_interconnect[VERTICAL_SIGNAL_OFFSET -1 -: WORD_SIZE];

                logic signed [WORD_SIZE-1:0] pe_right_out;
                assign hor_interconnect[HORIZONTAL_SIGNAL_OFFSET -1 -: WORD_SIZE] = ((fault_detected[c] && proxy_map[c][r])) ? proxy_stalled_right_out[c] : pe_right_out;

                logic signed [WORD_SIZE-1:0] selected_top_in;
                assign selected_top_in = (fault_detected[c] && proxy_map[c][r]) ? rcm_top_in[c] : top_in_bus[(c+1) * WORD_SIZE - 1 -: WORD_SIZE];
                
                logic signed [WORD_SIZE-1:0] selected_left_in;
                assign selected_left_in = (fault_detected[c] && proxy_map[c][r]) ? rcm_left_in[c] : left_in_bus[(r+1) * WORD_SIZE -1 -: WORD_SIZE];

                wire sel;
                assign sel = fault_detected[c] && proxy_map[c][r];
                logic signed [WORD_SIZE-1:0] orig_top_in;
                assign orig_top_in = top_in_bus[(c+1) * WORD_SIZE - 1 -: WORD_SIZE];

                traditional_mac_stw #(
                    .WORD_SIZE(WORD_SIZE)
                ) u_mac(
                    .clk(clk),
                    .rst(rst),
                    .stall(stall),

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
                    .bottom_out(pe_bottom_out[c][((r+1)*WORD_SIZE)-1 -: WORD_SIZE])
                );

            end
            else if (c==0)
            begin : rc

                localparam TOP_PEER_OFFSET = (c * ROWS + r) * WORD_SIZE;

                wire fsm_op2_select_in;
                wire fsm_out_select_in;
                wire stat_bit_in;
                logic signed [WORD_SIZE-1:0] selected_top_in;
                
                assign {stat_bit_in, fsm_out_select_in, fsm_op2_select_in} = (fault_detected[c] && proxy_map[c][r]) ? col_proxy_settings[c] : {ctl_stat_bit_in, ctl_dummy_fsm_out_select_in, ctl_dummy_fsm_op2_select_in};
                assign selected_top_in = (fault_detected[c] && proxy_map[c][r]) ? rcm_top_in[c] : ver_interconnect[TOP_PEER_OFFSET -1 -: WORD_SIZE];

                logic signed [WORD_SIZE-1:0] selected_left_in;
                assign selected_left_in = (fault_detected[c] && proxy_map[c][r]) ? rcm_left_in[c] : left_in_bus[(r+1) * WORD_SIZE -1 -: WORD_SIZE];


                logic signed [WORD_SIZE-1:0] orig_top_in;
                assign orig_top_in = ver_interconnect[TOP_PEER_OFFSET -1 -: WORD_SIZE];
                wire sel;
                assign sel = fault_detected[c] && proxy_map[c][r];
                
                assign ver_interconnect[VERTICAL_SIGNAL_OFFSET -1 -: WORD_SIZE] = ((fault_detected[c] && proxy_map[c][r])) ? proxy_stalled_top_in[c] : pe_bottom_out[c][((r+1)*WORD_SIZE)-1 -: WORD_SIZE];
                logic signed [WORD_SIZE-1:0] selected_bottom_out;
                assign selected_bottom_out = ver_interconnect[VERTICAL_SIGNAL_OFFSET -1 -: WORD_SIZE];

                logic signed [WORD_SIZE-1:0] pe_right_out;
                assign hor_interconnect[HORIZONTAL_SIGNAL_OFFSET -1 -: WORD_SIZE]= ((fault_detected[c] && proxy_map[c][r])) ? proxy_stalled_right_out[c] : pe_right_out;


                traditional_mac_stw #(
                    .WORD_SIZE(WORD_SIZE)
                ) u_mac(
                    .clk(clk),
                    .rst(rst),
                    .stall(stall),
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
                    .bottom_out(pe_bottom_out[c][((r+1)*WORD_SIZE)-1 -: WORD_SIZE])
                );
            end
            else if (r==0)
            begin : rc

                localparam LEFT_PEER_OFFSET = (r * COLS + c) * WORD_SIZE;

                wire fsm_op2_select_in;
                wire fsm_out_select_in;
                wire stat_bit_in;
                logic signed [WORD_SIZE-1:0] selected_top_in;
                
                assign {stat_bit_in, fsm_out_select_in, fsm_op2_select_in} = (fault_detected[c] && proxy_map[c][r]) ? col_proxy_settings[c] : {ctl_stat_bit_in, ctl_dummy_fsm_out_select_in, ctl_dummy_fsm_op2_select_in};
                assign selected_top_in = (fault_detected[c] && proxy_map[c][r]) ? rcm_top_in[c] : top_in_bus[(c+1) * WORD_SIZE - 1 -: WORD_SIZE];

                logic signed [WORD_SIZE-1:0] selected_left_in;
                assign selected_left_in = (fault_detected[c] && proxy_map[c][r]) ? rcm_left_in[c] : hor_interconnect[LEFT_PEER_OFFSET - 1 -: WORD_SIZE];

                logic signed [WORD_SIZE-1:0] orig_top_in;
                assign orig_top_in = top_in_bus[(c+1) * WORD_SIZE - 1 -: WORD_SIZE];
                wire sel;
                assign sel = fault_detected[c] && proxy_map[c][r];

                assign ver_interconnect[VERTICAL_SIGNAL_OFFSET -1 -: WORD_SIZE] = ((fault_detected[c] && proxy_map[c][r])) ? proxy_stalled_top_in[c] : pe_bottom_out[c][((r+1)*WORD_SIZE)-1 -: WORD_SIZE];

                logic signed [WORD_SIZE-1:0] selected_bottom_out;
                assign selected_bottom_out = ver_interconnect[VERTICAL_SIGNAL_OFFSET -1 -: WORD_SIZE];

                logic signed [WORD_SIZE-1:0] pe_right_out;
                assign hor_interconnect[HORIZONTAL_SIGNAL_OFFSET -1 -: WORD_SIZE]= ((fault_detected[c] && proxy_map[c][r])) ? proxy_stalled_right_out[c] : pe_right_out;

                traditional_mac_stw #(
                    .WORD_SIZE(WORD_SIZE)
                ) u_mac(
                    .clk(clk),
                    .rst(rst),
                    .stall(stall),
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
                    .bottom_out(pe_bottom_out[c][((r+1)*WORD_SIZE)-1 -: WORD_SIZE])
                );

            end
            else
            begin : rc

                localparam TOP_PEER_OFFSET =  (c * ROWS + r)  * WORD_SIZE;
                localparam LEFT_PEER_OFFSET = (r * COLS + c) * WORD_SIZE;

                wire fsm_op2_select_in;
                wire fsm_out_select_in;
                wire stat_bit_in;
                logic signed [WORD_SIZE-1:0] selected_top_in;
                
                logic signed [WORD_SIZE-1:0] orig_top_in;
                assign orig_top_in = ver_interconnect[TOP_PEER_OFFSET -1 -: WORD_SIZE];
                wire sel;
                assign sel = fault_detected[c] && proxy_map[c][r];

                assign {stat_bit_in, fsm_out_select_in, fsm_op2_select_in} = (fault_detected[c] && proxy_map[c][r]) ? col_proxy_settings[c] : {ctl_stat_bit_in, ctl_dummy_fsm_out_select_in, ctl_dummy_fsm_op2_select_in};
                assign selected_top_in = (fault_detected[c] && proxy_map[c][r]) ? rcm_top_in[c] : ver_interconnect[TOP_PEER_OFFSET -1 -: WORD_SIZE];

                logic signed [WORD_SIZE-1:0] selected_left_in;
                assign selected_left_in = (fault_detected[c] && proxy_map[c][r]) ? rcm_left_in[c] : hor_interconnect[LEFT_PEER_OFFSET - 1 -: WORD_SIZE];
                
                assign ver_interconnect[VERTICAL_SIGNAL_OFFSET -1 -: WORD_SIZE] = ((fault_detected[c] && proxy_map[c][r])) ? proxy_stalled_top_in[c] : pe_bottom_out[c][((r+1)*WORD_SIZE)-1 -: WORD_SIZE];

                logic signed [WORD_SIZE-1:0] selected_bottom_out;
                assign selected_bottom_out = ver_interconnect[VERTICAL_SIGNAL_OFFSET -1 -: WORD_SIZE];

                logic signed [WORD_SIZE-1:0] pe_right_out;
                assign hor_interconnect[HORIZONTAL_SIGNAL_OFFSET -1 -: WORD_SIZE] = ((fault_detected[c] && proxy_map[c][r])) ? proxy_stalled_right_out[c] : pe_right_out;

                traditional_mac_stw #(
                    .WORD_SIZE(WORD_SIZE)
                ) u_mac(
                    .clk(clk),
                    .rst(rst),
                    .stall(stall),
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
                    .bottom_out(pe_bottom_out[c][((r+1)*WORD_SIZE)-1 -: WORD_SIZE])
                );

            end
        end
    end
    endgenerate


endmodule
