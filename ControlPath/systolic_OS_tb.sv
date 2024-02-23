`include "./header_ws.vh"

module systolic_tb_os();
    //inputs
    logic clk = 1'b0;
    logic rst, set_stationary, ctl_dummy_fsm_out_select_in, ctl_stat_bit_in;

    //Note: Matrix multiplication = left_matrix * top_matrix

    //top_matrix ordered col 0 to col `COLS-1, then row 0 to row `ROWS-1 --> left-most entry = entry row 0 col 0
    //Ex. The below 3x3 top_matrix = [1 2 3]
    //                               [4 5 6]
    //                               [7 8 9]
    logic [`ROWS * `COLS * `WORD_SIZE - 1 : 0] left_matrix = {`WORD_SIZE'd9, `WORD_SIZE'd8, `WORD_SIZE'd7, `WORD_SIZE'd6, `WORD_SIZE'd5, `WORD_SIZE'd4, `WORD_SIZE'd3, `WORD_SIZE'd2, `WORD_SIZE'd1};
    //2x2 example
    // logic [`ROWS * `COLS * `WORD_SIZE - 1 : 0] top_matrix = {`WORD_SIZE'd4, `WORD_SIZE'd3, `WORD_SIZE'd2, `WORD_SIZE'd1};

    //2D array for left_matrix for convenience
    //Ex. The below 3x3 left_matrix = [9 4  1]
    //                                [5 12 3]
    //                                [6 8  7]
    logic [`ROWS * `COLS * `WORD_SIZE - 1 : 0] top_matrix = {`WORD_SIZE'd7, `WORD_SIZE'd8, `WORD_SIZE'd6, `WORD_SIZE'd3,`WORD_SIZE'd12, `WORD_SIZE'd5, `WORD_SIZE'd1, `WORD_SIZE'd4,`WORD_SIZE'd9};

    //2x2 Example
    // logic [`WORD_SIZE:0] left_matrix[`ROWS][`COLS] = '{'{`WORD_SIZE'd2, `WORD_SIZE'd1},
    //                                                  '{`WORD_SIZE'd6, `WORD_SIZE'd7}};

    //Expected output:
    //[9 4  1]   [1 2 3]    [32 46  60 ]    
    //[5 12 3] * [4 5 6] =  [74 95  114]
    //[6 8  7]   [7 8 9]    [87 108 129]
 
    logic [`ROWS * `WORD_SIZE - 1: 0] left_in_bus;
    logic [`COLS * `WORD_SIZE - 1: 0] top_in_bus;

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

    logic [`ROWS * `WORD_SIZE - 1: 0] checker_right_out_bus;
    logic [`COLS * `WORD_SIZE - 1: 0] checker_bottom_out_bus;

    reg dut_checker_comp_err[`ROWS-1:0][`COLS-1:0];   //array for recording errors found throughout simulation

    traditional_systolic #(`ROWS, `COLS, `WORD_SIZE) systolic_dut(
        .clk(clk),
        .rst(rst),
        .ctl_stat_bit_in(ctl_stat_bit_in), 
        .ctl_dummy_fsm_op2_select_in(set_stationary),
        .ctl_dummy_fsm_out_select_in(ctl_dummy_fsm_out_select_in),
        `ifdef ENABLE_FI
            .fault_inject_bus(fault_inject_bus),
        `endif
        .left_in_bus(left_in_bus),
        .top_in_bus(top_in_bus),
        .bottom_out_bus(bottom_out_bus),
        .right_out_bus(right_out_bus)
    );
    traditional_systolic #(`ROWS, `COLS, `WORD_SIZE) systolic_checker(
        .clk(clk),
        .rst(rst),
        .ctl_stat_bit_in(ctl_stat_bit_in), 
        .ctl_dummy_fsm_op2_select_in(set_stationary),
        .ctl_dummy_fsm_out_select_in(ctl_dummy_fsm_out_select_in),
        `ifdef ENABLE_FI
            .fault_inject_bus({(`ROWS * `COLS * 2){1'b0}}),
        `endif
        .left_in_bus(left_in_bus),
        .top_in_bus(top_in_bus),
        .bottom_out_bus(checker_bottom_out_bus),
        .right_out_bus(checker_right_out_bus)
    );

    always #5 clk = ~clk;

    logic sample_comparator = 0;
    logic test = 0;
    
    //row & col of bottom output to compare
    genvar r_comp, c_comp;   
    generate
        for(r_comp = 0; r_comp < `ROWS; r_comp = r_comp+1) begin
            for(c_comp = 0; c_comp < `COLS; c_comp = c_comp+1) begin
                initial begin
                    automatic logic [`COLS-1:0] checker_count = 0;
                    while(checker_count < (`COLS * `ROWS)) begin   //Only checking bottom_out so check once per col
                        @(posedge sample_comparator)   //Wait until signal that output has propagated to bottom (set by main inital block)
                        //Record incorrect output in row r_comp and column c_comp
                        dut_checker_comp_err[r_comp][c_comp] = (systolic_tb_os.systolic_dut.mac_row_genblk[r_comp].mac_col_genblk[c_comp].rc.u_mac.bottom_out !== systolic_tb_os.systolic_checker.mac_row_genblk[r_comp].mac_col_genblk[c_comp].rc.u_mac.bottom_out);
                        
                        // if(dut_checker_comp_err[r_comp][c_comp] == 1'b1) begin
                        //     $display("Error: Fault detected in row %0d, col %0d", r_comp, c_comp);
                        // end
                        checker_count = checker_count+1;
                    end
                end
            end
        end
    endgenerate

    //Check dut_checker_comp_err for any errors recorded throughout simulation
    task errorCheck;
        integer x, y;
        for(y = 0; y < `ROWS; y = y+1) begin
            for(x = 0; x < `COLS; x = x+1) begin
                if(dut_checker_comp_err[y][x] == 1'b1) begin
                    $display("Error: Incorrect output detected in row %0d, col %0d", y, x);
                end
            end
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

    //Weight/Input Stationary
    task set_stationary_operands;
        for(integer stat_op_row = `ROWS-1; stat_op_row >= 0; stat_op_row--) begin
            @(negedge clk);
            set_stationary = 1'b1;
            top_in_bus = top_matrix[(stat_op_row * `COLS) * `WORD_SIZE +: (`COLS * `WORD_SIZE)];
            @(posedge clk);
        end
        set_stationary = 1'b0;
    endtask

    logic[`COLS * `WORD_SIZE-1:0] matmul_output;
    logic [`COLS-1:0] output_col_valid;

    systolic_matmul_fsm_OS matmul_dut(
        .clk(clk),
        .rst(rst),
        .top_matrix(top_matrix),
        .left_matrix(left_matrix),
        .set_stationary(set_stationary),
        .fsm_out_select_in(ctl_dummy_fsm_out_select_in),
        .stat_bit_in(ctl_stat_bit_in),
        .curr_cycle_top_in(top_in_bus),
        .curr_cycle_left_in(left_in_bus),
        .bottom_out(bottom_out_bus),
        .matmul_output(matmul_output),
        .output_col_valid(output_col_valid)
    );

    logic [`WORD_SIZE - 1:0] output_matrix[`ROWS][`COLS];
    matmul_output_control matmul_out_dut(
        .clk(clk),
        .rst(rst),
        .matmul_fsm_output(bottom_out_bus),
        .matmul_output_valid(output_col_valid),
        .output_matrix(output_matrix)
    );


    integer r, c, curr_output;
    initial begin
        rst = 1'b1;
        @(negedge clk);
        rst = 1'b0;
        
        $display("Weight stationary matrix multiplication test");
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
                $write("%d ", left_matrix[(r*`COLS+c)*`WORD_SIZE +: `WORD_SIZE]);
            end
            $write("\n");
        end
        #300
        $display("Output Matrix: left_matrix * top_matrix");
        for(integer r = 0; r < `ROWS; r++) begin
           for(integer c = 0; c < `COLS; c++) begin
                $write("%d ", output_matrix[r][c]);
            end
            $write("\n");
        end
        $stop;
    end
endmodule