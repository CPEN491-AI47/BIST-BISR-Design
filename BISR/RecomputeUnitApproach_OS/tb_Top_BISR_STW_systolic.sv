`include "./header.vh"

module tb_Top_BISR_STW_systolic();
    //inputs
    logic clk = 1'b0;
    logic rst = 1'b0;

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

    //input matrixs 
    logic [`ROWS * `COLS * `WORD_SIZE - 1 : 0] top_matrix;
    `ifdef OS_WORKFLOW
        logic [`ROWS * `COLS * `WORD_SIZE - 1 : 0] left_matrix; 
    `else
        logic [`WORD_SIZE:0] left_matrix[`ROWS][`COLS];
    `endif 

    //outputs matrix 
    logic [(`ROWS * `COLS * `WORD_SIZE) - 1:0] output_matrix;
    logic [`WORD_SIZE:0] output_matrix_2D [`ROWS][`COLS];
    logic matrix_rdy;

    ////////////////////////////////////////////////////////////////////////////////////
    /*
          Make testcases selections in header file 
        - Matrix_Initilization(Option array size for 2x2, 3x3, 4x4 -This is hard-coded)
        - fault_injection(Option for random fault/manmual fault injection)
    */
    ////////////////////////////////////////////////////////////////////////////////////
    task Matrix_Initilization;
        if(`ROWS == 28)begin
            $urandom(`SEED);
            //fault_inject_bus = $urandom_range({(`ROWS * `COLS * 2){1'b1}},{(`ROWS * `COLS * 2){1'b0}});
            for (integer i = 0; i < `ROWS; i = i+1) begin
                for (integer j = 0; j < `COLS; j = j+1) begin
                    top_matrix[((i*`COLS+j)*`WORD_SIZE) +: `WORD_SIZE] = $urandom_range({16'b0000_0000_0000_1111},{16'b0000_0000_0000_0000});
                    left_matrix[((i*`COLS+j)*`WORD_SIZE) +: `WORD_SIZE] = $urandom_range({16'b0000_0000_0000_1111},{16'b0000_0000_0000_0000});
                end
            end
        end 
        else if (`ROWS == 2)begin
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
                fault_inject_bus[(fi_col*`ROWS+fi_row)*2 +: 2] = 2'b11;
                $display("Injected fault at col %0d, row %0d", fi_col, fi_row);
                fi_row = 2;
                fi_col = 2;
                fault_inject_bus[(fi_col*`ROWS+fi_row)*2 +: 2] = 2'b11;
                $display("Injected fault at col %0d, row %0d", fi_col, fi_row);
                fi_row = 3;
                fi_col = 3;
                fault_inject_bus[(fi_col*`ROWS+fi_row)*2 +: 2] = 2'b11;
                $display("Injected fault at col %0d, row %0d", fi_col, fi_row);
                fi_row = 1;
                fi_col = 1;
                fault_inject_bus[(fi_col*`ROWS+fi_row)*2 +: 2] = 2'b11;
                $display("Injected fault at col %0d, row %0d", fi_col, fi_row);
            `endif
        `endif
    endtask 

    task matrix_conversion;
        for (integer row = 0; row < `ROWS; row = row+1) begin
            for (integer col = 0; col < `COLS; col = col+1) begin
                output_matrix_2D[row][col] = output_matrix[((row*`COLS+col)*`WORD_SIZE) +: `WORD_SIZE];
            end
        end
    endtask
    ////////////////////////////////////////////////////////////////////////////////////
    /*
       Module Instantiation 
    */
    ////////////////////////////////////////////////////////////////////////////////////

    Top_BISR_STW_systolic #(`ROWS, `COLS, `WORD_SIZE, `NUM_RU) Top_BISR_STW_systolic_dut (
        .clk(clk),
        .rst(rst),

        .top_matrix(top_matrix),
        .left_matrix(left_matrix),
    
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
        `endif

        .output_matrix(output_matrix),
        .matrix_rdy(matrix_rdy)
    );

    ////////////////////////////////////////////////////////////////////////////////////
    /*
       Output display 
    */
    ////////////////////////////////////////////////////////////////////////////////////
    always #5 clk = ~clk;
    integer r, c, curr_output;
    initial begin
        Matrix_Initilization();
        rst = 1'b1;
        @(negedge clk);
        rst = 1'b0;
        @(negedge clk);
        
        fault_injection();
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

        wait(Top_BISR_STW_systolic_dut.output_col_valid != 0);
        for (integer cycle = 0; cycle <= `COLS - 1; cycle ++)begin
            @(negedge clk);
        end 

        matrix_conversion();
        $display("Fault injected Output Matrix: left_matrix * top_matrix");
        for(integer r = 0; r < `ROWS; r++) begin
           for(integer c = 0; c < `COLS; c++) begin
                $write("%d ", output_matrix_2D[r][c]);
            end
            $write("\n");
        end

        //Start STW
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
                    $write("%d ", Top_BISR_STW_systolic_dut.STW_result_mat[(r*`ROWS)+c]);
                end
                $write("\n");
            end
            #15;
        `endif

        @(posedge Top_BISR_STW_systolic_dut.ru_output_valid);
        @(posedge clk);
        @(posedge clk);

        matrix_conversion();
        $display("BISR Output Matrix: left_matrix * top_matrix");
        for(integer r = 0; r < `ROWS; r++) begin
           for(integer c = 0; c < `COLS; c++) begin
                $write("%d ", output_matrix_2D[r][c]);
            end
            $write("\n");
        end

        $stop;
    end
endmodule