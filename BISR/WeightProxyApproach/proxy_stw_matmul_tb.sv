`include "./header_ws.vh"

module stw_matmul_tb();
    //inputs
    logic clk = 1'b0;
    logic rst = 1'b0;
    logic set_stationary, ctl_dummy_fsm_out_select_in, ctl_stat_bit_in;

    //Note: Matrix multiplication = left_matrix * top_matrix

    //top_matrix ordered col 0 to col `COLS-1, then row 0 to row `ROWS-1 --> left-most entry = entry row 0 col 0
    //Ex. The below 3x3 top_matrix = [1 2 3 7]
    //                               [4 5 6 7]
    //                               [1 8 9 7]
    //                               [6 7 1 8]
    logic [`ROWS * `COLS * `WORD_SIZE - 1 : 0] top_matrix;  // = {`WORD_SIZE'd0, `WORD_SIZE'd1, `WORD_SIZE'd7, `WORD_SIZE'd6, `WORD_SIZE'd3, `WORD_SIZE'd9, `WORD_SIZE'd21, `WORD_SIZE'd1, `WORD_SIZE'd2, `WORD_SIZE'd6, `WORD_SIZE'd0, `WORD_SIZE'd4, `WORD_SIZE'd1, `WORD_SIZE'd3, `WORD_SIZE'd2, `WORD_SIZE'd1};
    logic signed [`WORD_SIZE-1:0]  top_matrix_2d[`ROWS][`COLS] = '{'{-`WORD_SIZE'd5, `WORD_SIZE'd0, `WORD_SIZE'd0, `WORD_SIZE'd1},
                                                     '{`WORD_SIZE'd4, `WORD_SIZE'd8, `WORD_SIZE'd6, `WORD_SIZE'd2},
                                                     '{`WORD_SIZE'd1, `WORD_SIZE'd21, `WORD_SIZE'd9, `WORD_SIZE'd3},
                                                     '{`WORD_SIZE'd6, `WORD_SIZE'd7, `WORD_SIZE'd1, `WORD_SIZE'd1}};

    logic [`WORD_SIZE:0] left_matrix[`ROWS][`COLS] = '{'{`WORD_SIZE'd9, `WORD_SIZE'd4, `WORD_SIZE'd2, `WORD_SIZE'd1},   
                                                     '{`WORD_SIZE'd5, `WORD_SIZE'd12, `WORD_SIZE'd3, `WORD_SIZE'd2},
                                                     '{`WORD_SIZE'd6, `WORD_SIZE'd8, `WORD_SIZE'd7, `WORD_SIZE'd3},
                                                     '{`WORD_SIZE'd7, `WORD_SIZE'd3, `WORD_SIZE'd8, `WORD_SIZE'd4}};
    
    //Set flatten top_matrix_2d into proper 1d format for matmul_fsm
    initial begin
        for(integer r = 0; r < `ROWS; r++) begin
           for(integer c = 0; c < `COLS; c++) begin
                top_matrix[(r*`COLS+c)*`WORD_SIZE +: `WORD_SIZE] = top_matrix_2d[r][c];
                // $write("%d ", top_matrix[(r*`COLS+c)*`WORD_SIZE +: `WORD_SIZE]);
            end
            $write("\n");
        end
    end

    // logic [`ROWS * `COLS * `WORD_SIZE - 1 : 0] top_matrix = {`WORD_SIZE'd9, `WORD_SIZE'd8, `WORD_SIZE'd1, `WORD_SIZE'd6, `WORD_SIZE'd5, `WORD_SIZE'd4, `WORD_SIZE'd3, `WORD_SIZE'd2, `WORD_SIZE'd1};
    //2x2 example
    // logic [`ROWS * `COLS * `WORD_SIZE - 1 : 0] top_matrix = {`WORD_SIZE'd4, `WORD_SIZE'd3, `WORD_SIZE'd2, `WORD_SIZE'd1};

    //2D array for left_matrix for convenience
    //Ex. The below 3x3 left_matrix = [9 4  1]
    //                                [5 12 3]
    //                                [6 8  7]
    // logic [`WORD_SIZE:0] left_matrix[`ROWS][`COLS] = '{'{`WORD_SIZE'd9, `WORD_SIZE'd4, `WORD_SIZE'd1},
    //                                                  '{`WORD_SIZE'd5, `WORD_SIZE'd12, `WORD_SIZE'd3},
    //                                                  '{`WORD_SIZE'd6, `WORD_SIZE'd8, `WORD_SIZE'd7}};


    

    //2x2 Example
    // logic [`WORD_SIZE:0] left_matrix[`ROWS][`COLS] = '{'{`WORD_SIZE'd2, `WORD_SIZE'd1},
    //                                                  '{`WORD_SIZE'd6, `WORD_SIZE'd7}};

    //Expected output:
    //[9 4  1]   [1 2 3]    [32 46  60 ]    
    //[5 12 3] * [4 5 6] =  [74 94  114]
    //[6 8  7]   [7 8 9]    [87 108 129]
    // logic [`WORD_SIZE:0] expected_out[`ROWS][`COLS];
    logic [`WORD_SIZE:0] expected_out[`ROWS][`COLS] = '{'{`WORD_SIZE'd67, `WORD_SIZE'd43, `WORD_SIZE'd81, `WORD_SIZE'd23},   
                                                     '{`WORD_SIZE'd85, `WORD_SIZE'd101, `WORD_SIZE'd173, `WORD_SIZE'd38},
                                                     '{`WORD_SIZE'd80, `WORD_SIZE'd114, `WORD_SIZE'd232, `WORD_SIZE'd43},
                                                     '{`WORD_SIZE'd71, `WORD_SIZE'd94, `WORD_SIZE'd220, `WORD_SIZE'd37}};
    
 
    logic [`ROWS * `WORD_SIZE - 1: 0] left_in_bus;
    logic [`COLS * `WORD_SIZE - 1: 0] top_in_bus;

    `ifdef ENABLE_STW
        //STW inputs
        logic STW_test_load_en;
        logic [`WORD_SIZE-1:0] STW_mult_op1;
        logic [`WORD_SIZE-1:0] STW_mult_op2;
        logic [`WORD_SIZE-1:0] STW_add_op;
        logic [`WORD_SIZE-1:0] STW_expected;
        logic STW_start;
        //outputs
        logic STW_complete;
        logic [(`ROWS * `COLS)-1:0] STW_result_mat; //[`COLS-1:0];
    `endif

    logic err;

    `ifdef ENABLE_FI
        logic [(`ROWS * `COLS * 2) - 1:0] fault_inject_bus = 0;
        logic [`ROWS-1:0] fi_row;   //row to inject fault
        logic [`COLS-1:0] fi_col;   //col to inject fault
    `endif

    integer n_cycle;
    logic start_inputting = 1'b0;

    //outputs
    logic [`ROWS * `WORD_SIZE - 1: 0] right_out_bus;
    logic [`COLS * `WORD_SIZE - 1: 0] bottom_out_bus;

    
    logic [`COLS-1:0] proxy_out_valid_bus;
    logic [(`COLS*`WORD_SIZE)-1: 0] proxy_output_bus;

    // stw_wproxy_systolic #(`ROWS, `COLS, `WORD_SIZE) stw_mac_dut (
    //     .clk(clk),
    //     .rst(rst),
    //     .ctl_stat_bit_in(ctl_stat_bit_in), 
    //     .ctl_dummy_fsm_op2_select_in(set_stationary),
    //     .ctl_dummy_fsm_out_select_in(ctl_dummy_fsm_out_select_in),

    //     `ifdef ENABLE_FI
    //         .fault_inject_bus(fault_inject_bus),
    //     `endif

    //     `ifdef ENABLE_STW
    //         .STW_test_load_en(STW_test_load_en),
    //         .STW_mult_op1(STW_mult_op1),
    //         .STW_mult_op2(STW_mult_op2),
    //         .STW_add_op(STW_add_op),
    //         .STW_expected(STW_expected),
    //         .STW_start(STW_start),
    //         .STW_complete_out(STW_complete),
    //         .STW_result_mat(STW_result_mat),
    //     `endif
    //     `ifdef ENABLE_WPROXY
    //         .proxy_output_bus(proxy_output_bus),
    //         .proxy_out_valid_bus(proxy_out_valid_bus),
    //     `endif
    //     .left_in_bus(left_in_bus),
    //     .top_in_bus(top_in_bus),
    //     .bottom_out_bus(bottom_out_bus),
    //     .right_out_bus(right_out_bus)
    // );

    always #5 clk = ~clk;

    logic signed [`WORD_SIZE - 1:0] output_matrix[`ROWS][`COLS];

    //Inject Faults Randomly/Manually in MAC unit 
    task fault_injection;
        `ifdef ENABLE_FI
            `ifdef ENABLE_RANDOM
                //Inject fault randomly
                $urandom(`SEED);
                fault_inject_bus = $urandom_range({(`ROWS * `COLS * 2){1'b1}},{(`ROWS * `COLS * 2){1'b0}});
                for(integer n = 0; n < (`ROWS * `COLS * 2); n = n+2)begin
                    if(fault_inject_bus[n] == 1'b1)
                        $display("Injected stuck-at %d fault at col %0d, row %0d",fault_inject_bus[n+1], n / ( 2 * `COLS), ((n / 2) % `ROWS));
                end 
            `else
                //Inject faulty MAC manually at array[0,1]
                fi_row = 0;
                fi_col = 2;
                fault_inject_bus[(fi_col*`ROWS+fi_row)*2 +: 2] = 2'b01;
                $display("Injected fault at col %0d, row %0d", fi_col, fi_row);
            `endif
        `endif
    endtask 

    // logic[`COLS * `WORD_SIZE-1:0] matmul_output;
    // logic [`COLS-1:0] output_col_valid;
    // logic start_fsm;
    // logic start_matmul;

    // systolic_matmul_fsm matmul_dut(
    //     .clk(clk),
    //     .rst(rst),
    //     .top_matrix(top_matrix),
    //     .left_matrix(left_matrix),
    //     .start_fsm(start_fsm),
    //     .start_matmul(start_matmul),
    //     .set_stationary(set_stationary),
    //     .fsm_out_select_in(ctl_dummy_fsm_out_select_in),
    //     .stat_bit_in(ctl_stat_bit_in),
    //     .top_in_bus(top_in_bus),
    //     .curr_cycle_left_in(left_in_bus),
    //     .bottom_out(bottom_out_bus),
    //     .matmul_output(matmul_output),
    //     .output_col_valid(output_col_valid)
    // );


    // matmul_output_control matmul_out_dut(
    //     .clk(clk),
    //     .rst(rst),
    //     .matmul_fsm_output(bottom_out_bus),
    //     `ifdef ENABLE_WPROXY
    //         .proxy_output_bus(proxy_output_bus),
    //         .proxy_out_valid_bus(proxy_out_valid_bus),
    //     `endif
    //     .matmul_output_valid(output_col_valid),
    //     .output_matrix(output_matrix)
    // );

    
    logic matmul_output_done, matmul_in_progress;
    logic start_matmul, start_fsm, fsm_rdy;

    logic [31:0] mem_addr;
    logic mem_wr_en;
    logic [`MEM_PORT_WIDTH-1:0] mem_rd_data;

    logic [31:0] output_mem_addr;
    logic output_mem_wr_en;
    logic [`MEM_PORT_WIDTH-1:0] output_mem_wr_data;

    bisr_systolic_top #(`ROWS, `COLS, `WORD_SIZE) systolic_dut (
        .clk(clk),
        .rst(rst),
        // .top_matrix(top_matrix),
        // .left_matrix(left_matrix),
        .inputs_rdy(1'b1),

        .start_fsm(start_fsm),
        .start_matmul(start_matmul),
        .fsm_rdy(fsm_rdy),

        .STW_complete(STW_complete),
        .STW_result_mat(STW_result_mat),

        // .output_matrix(output_matrix),

        .mem_rd_data(mem_rd_data),
        .mem_addr(mem_addr),
        .mem_wr_en(mem_wr_en),

        .output_mem_wr_data(output_mem_wr_data),
        .output_mem_addr(output_mem_addr),
        .output_mem_wr_en(output_mem_wr_en)
    );

    bram_mat #(`ROWS, `COLS, `WORD_SIZE) input_bram (
        .clk(clk),
        .we(mem_wr_en),
        .addr(mem_addr),
        .di(),
        .dout(mem_rd_data)
    );

    bram_mat #(`ROWS, `COLS, `WORD_SIZE) output_bram (
        .clk(clk),
        .we(output_mem_wr_en),
        .addr(output_mem_addr),
        .di(output_mem_wr_data),
        .dout()
    );

    localparam NUM_FAULTS = 4;
    logic [`ROWS-1:0] fi_row_arr[NUM_FAULTS] = {'d1, 'd2, 'd3, 'd0};
    logic [`COLS-1:0] fi_col_arr[NUM_FAULTS] = {'d0, 'd1, 'd2, 'd3};
    integer r, c, curr_output;
    initial begin
        start_fsm = 1;
        start_matmul = 0;
        rst = 1'b1;
        @(negedge clk);
        rst = 1'b0;

        @(negedge clk);
        
        `ifdef ENABLE_FI
            // for(integer f = 0; f < NUM_FAULTS; f++) begin
            //     fi_row = fi_row_arr[f];
            //     fi_col = fi_col_arr[f];
            //     fault_inject_bus[(fi_col*`ROWS+fi_row)*2 +: 2] = 2'b11;
            //     $display("Injected fault at col %0d, row %0d", fi_col, fi_row);
            // end

            // fi_row = 1;
            // fi_col = 1;
            // fault_inject_bus[(fi_col*`ROWS+fi_row)*2 +: 2] = 2'b01;
            // $display("Injected fault at col %0d, row %0d", fi_col, fi_row);
            
            @(negedge clk);
        `endif

        $display("Weight stationary matrix multiplication test");
        $display("Top (weight) Matrix:");
        for(integer r = 0; r < `ROWS; r++) begin
           for(integer c = 0; c < `COLS; c++) begin
                $write("%d ", $signed(top_matrix[(r*`COLS+c)*`WORD_SIZE +: `WORD_SIZE]));
            end
            $write("\n");
        end

        $display("Left (input) Matrix:");
        for(integer r = 0; r < `ROWS; r++) begin
           for(integer c = 0; c < `COLS; c++) begin
                $write("%d ", left_matrix[r][c]);
            end
            $write("\n");
        end

        `ifdef ENABLE_STW
            // STW_test_load_en = 1;
            // STW_start = 0;
            // STW_mult_op1 = `WORD_SIZE'd4;
            // STW_mult_op2 = `WORD_SIZE'd3;
            // STW_add_op = `WORD_SIZE'd1;
            // STW_expected = `WORD_SIZE'd13;
            // @(posedge clk);
            // @(negedge clk);
            // STW_test_load_en = 0;
            // STW_start = 1;
            // @(posedge clk);
            // @(negedge clk);
            // STW_start = 0;
            #50;
            
            $display("Stop-the-World Diagnosis Before: (0 = Fault Found, 1 = No Fault)");
            for(integer r = 0; r < `ROWS; r++) begin
                for(integer c = 0; c < `COLS; c++) begin
                    $write("%d ", STW_result_mat[(c*`ROWS)+r]);
                end
                $write("\n");
            end
        // #30;
        `endif
        start_matmul = 1;
        start_fsm = 1;
        #50
        start_fsm = 0;
        #850

        $display("Expected Output: left_matrix * top_matrix");
        for(integer r = 0; r < `ROWS; r++) begin
           for(integer c = 0; c < `COLS; c++) begin
                $write("%x ", expected_out[r][c]);
            end
            $write("\n");
        end

        $display("Actual Output: left_matrix * top_matrix");
        for(integer r = 0; r < `ROWS; r++) begin
           for(integer c = 0; c < `COLS; c++) begin
                $write("%x ", $signed(output_matrix[r][c]));
            end
            $write("\n");
        end
        `ifdef ENABLE_STW
            // STW_test_load_en = 1;
            // STW_start = 0;
            // STW_mult_op1 = `WORD_SIZE'd4;
            // STW_mult_op2 = `WORD_SIZE'd3;
            // STW_add_op = `WORD_SIZE'd0;
            // STW_expected = `WORD_SIZE'd12;
            // @(posedge clk);
            // @(negedge clk);
            // STW_test_load_en = 0;
            // STW_start = 1;
            // @(posedge clk);
            // @(negedge clk);
            // STW_start = 0;
            #50;

            $display("Stop-the-World Diagnosis After: (0 = Fault Found, 1 = No Fault)");
            for(integer r = 0; r < `ROWS; r++) begin
                for(integer c = 0; c < `COLS; c++) begin
                    $write("%d ", STW_result_mat[(c*`ROWS)+r]);
                end
                $write("\n");
            end
            #15;
        `endif

        $stop;
    end
endmodule