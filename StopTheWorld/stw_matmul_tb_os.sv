// All OS workfllow related tb/modules will use same header from the following path
// Modify this if your path is different 
`include "../BIST-BISR-Design/ControlPath/header_ws.vh"

module stw_matmul_tb_os();
    //inputs
    logic clk = 1'b0;
    logic rst = 1'b0;
    logic set_stationary, ctl_dummy_fsm_out_select_in, ctl_stat_bit_in;

    logic [`ROWS * `COLS * `WORD_SIZE - 1 : 0] top_matrix;

    `ifdef OS_WORKFLOW
        logic [`ROWS * `COLS * `WORD_SIZE - 1 : 0] left_matrix; 
    `else
        logic [`WORD_SIZE:0] left_matrix[`ROWS][`COLS];
    `endif

    logic [`WORD_SIZE - 1:0] output_matrix[`ROWS][`COLS];

    logic [`ROWS * `WORD_SIZE - 1: 0] left_in_bus;
    logic [`COLS * `WORD_SIZE - 1: 0] top_in_bus;

    // logic [`WORD_SIZE:0] expected_out[`ROWS][`COLS] = '{'{`WORD_SIZE'd32, `WORD_SIZE'd46, `WORD_SIZE'd60},
    //                                                     '{`WORD_SIZE'd74, `WORD_SIZE'd94, `WORD_SIZE'd114},
    //                                                     '{`WORD_SIZE'd87, `WORD_SIZE'd108, `WORD_SIZE'd129}};

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

    always #5 clk = ~clk;

    task Matrix_Initilization;
        if (`ROWS == 2)begin
            top_matrix = {`WORD_SIZE'd4, `WORD_SIZE'd3, `WORD_SIZE'd2, `WORD_SIZE'd1};
            `ifdef OS_WORKFLOW
                left_matrix = {`WORD_SIZE'd2, `WORD_SIZE'd1,`WORD_SIZE'd6, `WORD_SIZE'd7};
            `else
                 left_matrix = '{'{`WORD_SIZE'd2, `WORD_SIZE'd1},
                                '{`WORD_SIZE'd6, `WORD_SIZE'd7}};
            `endif 
        end 
        else if (`ROWS == 3)begin 
            `ifdef OS_WORKFLOW
                left_matrix = {`WORD_SIZE'd9, `WORD_SIZE'd8, `WORD_SIZE'd7, `WORD_SIZE'd6, `WORD_SIZE'd5, `WORD_SIZE'd4, `WORD_SIZE'd3, `WORD_SIZE'd2, `WORD_SIZE'd1};
            `else
                 left_matrix = '{'{`WORD_SIZE'd9, `WORD_SIZE'd8, `WORD_SIZE'd7},
                                 '{`WORD_SIZE'd6, `WORD_SIZE'd5, `WORD_SIZE'd4},
                                 '{`WORD_SIZE'd3, `WORD_SIZE'd2, `WORD_SIZE'd1}};
            `endif 
            top_matrix = {`WORD_SIZE'd7, `WORD_SIZE'd8, `WORD_SIZE'd6, `WORD_SIZE'd3,`WORD_SIZE'd12, `WORD_SIZE'd5, `WORD_SIZE'd1, `WORD_SIZE'd4,`WORD_SIZE'd9};
        end 
        else begin 
            //4x4 example 
            top_matrix = {`WORD_SIZE'd7, `WORD_SIZE'd2, `WORD_SIZE'd3, `WORD_SIZE'd5,
                        `WORD_SIZE'd4, `WORD_SIZE'd7, `WORD_SIZE'd8, `WORD_SIZE'd6,
                        `WORD_SIZE'd2,`WORD_SIZE'd3, `WORD_SIZE'd12, `WORD_SIZE'd5, 
                        `WORD_SIZE'd5,`WORD_SIZE'd1, `WORD_SIZE'd4, `WORD_SIZE'd9};
            `ifdef OS_WORKFLOW
                left_matrix = {`WORD_SIZE'd7, `WORD_SIZE'd2, `WORD_SIZE'd3, `WORD_SIZE'd5,
                               `WORD_SIZE'd4, `WORD_SIZE'd7, `WORD_SIZE'd8, `WORD_SIZE'd6,
                               `WORD_SIZE'd2,`WORD_SIZE'd3, `WORD_SIZE'd12, `WORD_SIZE'd5,
                               `WORD_SIZE'd5,`WORD_SIZE'd1, `WORD_SIZE'd4, `WORD_SIZE'd9}; 
            `else
                 left_matrix = '{'{`WORD_SIZE'd7, `WORD_SIZE'd2, `WORD_SIZE'd3, `WORD_SIZE'd5},
                                 '{`WORD_SIZE'd4, `WORD_SIZE'd7, `WORD_SIZE'd8, `WORD_SIZE'd6},
                                 '{`WORD_SIZE'd2,`WORD_SIZE'd3, `WORD_SIZE'd12, `WORD_SIZE'd5},
                                '{`WORD_SIZE'd5,`WORD_SIZE'd1, `WORD_SIZE'd4, `WORD_SIZE'd9}}; 
            `endif 
        end 
    endtask
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
                fi_col = 1;
                fault_inject_bus[(fi_col*`ROWS+fi_row)*2 +: 2] = 2'b01;
                $display("Injected fault at col %0d, row %0d", fi_col, fi_row);
            `endif
        `endif
    endtask 
    
    workflow_control #(`WORD_SIZE) workflow_dut(
        //Inputs
        .clk(clk),
        .rst(rst),

        .top_matrix(top_matrix),
        .left_matrix(left_matrix),

        .bottom_out(bottom_out_bus),

        //outputs MAC Controls signals
        .set_stationary(set_stationary),
        .fsm_out_select_in(ctl_dummy_fsm_out_select_in),
        .stat_bit_in(ctl_stat_bit_in),

        //Output left,top in buses
        .curr_cycle_top_in(top_in_bus),
        .curr_cycle_left_in(left_in_bus),

        //Outputs matrix 
        .output_matrix(output_matrix)
    );

    traditional_systolic_stw #(`ROWS, `COLS, `WORD_SIZE) stw_mac_dut (
        .clk(clk),
        .rst(rst),
        .ctl_stat_bit_in(ctl_stat_bit_in), 
        .ctl_dummy_fsm_op2_select_in(set_stationary),
        .ctl_dummy_fsm_out_select_in(ctl_dummy_fsm_out_select_in),

        `ifdef ENABLE_FI
            .fault_inject_bus(fault_inject_bus),
        `endif

        `ifdef ENABLE_STW
            .STW_test_load_en(STW_test_load_en),
            .STW_mult_op1(STW_mult_op1),
            .STW_mult_op2(STW_mult_op2),
            .STW_add_op(STW_add_op),
            .STW_expected(STW_expected),
            .STW_start(STW_start),
            .STW_complete_out(STW_complete),
            .STW_result_mat(STW_result_mat),
        `endif

        .left_in_bus(left_in_bus),
        .top_in_bus(top_in_bus),
        .bottom_out_bus(bottom_out_bus),
        .right_out_bus(right_out_bus)
    );


    integer r, c, curr_output;
    initial begin
        Matrix_Initilization();
        rst = 1'b1;
        @(negedge clk);
        rst = 1'b0;

        @(negedge clk);
        
        `ifdef ENABLE_FI
            fi_row = 0;
            fi_col = 1;
            fault_inject_bus[(fi_col*`ROWS+fi_row)*2 +: 2] = 2'b01;
            $display("Injected fault at col %0d, row %0d", fi_col, fi_row);

            @(negedge clk);
        `endif

        $display("Output stationary matrix multiplication test");
        $display("Top (weight) Matrix:");
        for(integer r = 0; r < `ROWS; r++) begin
           for(integer c = 0; c < `COLS; c++) begin
                $write("%d ", top_matrix[(r*`COLS+c)*`WORD_SIZE +: `WORD_SIZE]);
            end
            $write("\n");
        end

        $display("Left (input) Matrix:");
        for(integer r = 0; r < `ROWS; r++) begin
           for(integer c = 0; c < `COLS; c++) begin
                `ifdef OS_WORKFLOW
                    $write("%d ", left_matrix[(r*`COLS+c)*`WORD_SIZE +: `WORD_SIZE]);
                `else 
                    $write("%d ", left_matrix[r][c]);
                `endif
            end
            $write("\n");
        end
        #200

        // $display("Expected Output: left_matrix * top_matrix");
        // for(integer r = 0; r < `ROWS; r++) begin
        //    for(integer c = 0; c < `COLS; c++) begin
        //         $write("%d ", expected_out[r][c]);
        //     end
        //     $write("\n");
        // end

        $display("Actual Output: left_matrix * top_matrix");
        for(integer r = 0; r < `ROWS; r++) begin
           for(integer c = 0; c < `COLS; c++) begin
                $write("%d ", output_matrix[r][c]);
            end
            $write("\n");
        end
        `ifdef ENABLE_STW
            STW_test_load_en = 1;
            STW_start = 0;
            STW_mult_op1 = `WORD_SIZE'd4;
            STW_mult_op2 = `WORD_SIZE'd3;
            STW_add_op = `WORD_SIZE'd0;
            STW_expected = `WORD_SIZE'd12;
            @(posedge clk);
            @(negedge clk);
            STW_test_load_en = 0;
            STW_start = 1;
            @(posedge clk);
            @(negedge clk);
            STW_start = 0;
            #50;

            $display("Stop-the-World Diagnosis Matrix: (0 = Fault Found, 1 = No Fault)");
            for(integer r = 0; r < `ROWS; r++) begin
                for(integer c = 0; c < `COLS; c++) begin
                    $write("%d ", STW_result_mat[(r*`ROWS)+c]);
                end
                $write("\n");
            end
            #15;
        `endif

        $stop;
    end
endmodule