`timescale 1ns / 1ps

module accelerator_tb#(
    parameter DATA_W = 16,
    parameter N = 2,
    parameter ACC_W = 2*DATA_W + $clog2(N)
);
    logic clk;
    logic rst_n;
    logic start;
    logic signed [DATA_W-1:0] weight [N][N];
    logic signed [DATA_W-1:0] A_in [N];
    logic done;
    logic signed [ACC_W-1:0] out [N];
    logic signed [DATA_W-1:0] activation [N][N];
    logic signed [ACC_W-1:0] expected [N][N];

    int errors = 0;
    
    accelerator#(
        .N(N),
        .DATA_W(DATA_W),
        .ACC_W(ACC_W)
    ) dut(
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .weight(weight),
        .A_in(A_in),
        .done(done),
        .out(out)
    );

    task automatic compute_ref_matrix(
        input logic signed [DATA_W-1:0] act [N][N],
        input logic signed [DATA_W-1:0] wgt [N][N],
        output logic signed [ACC_W-1:0] golden [N][N]
    );
        int row, col, k;
        logic signed [ACC_W-1:0] sum;

        for (row = 0; row < N; row++) begin
            for (col = 0; col < N; col++) begin
                sum = '0;
                for (k = 0; k < N; k++) begin
                    sum += act[row][k] * wgt[k][col];
                end
                golden[row][col] = sum;
            end
        end
    endtask
    
    always #5 clk = ~clk;
    
    initial begin
        logic signed [DATA_W-1:0] rand_act [N][N];
        logic signed [DATA_W-1:0] rand_wgt [N][N];
        logic signed [ACC_W-1:0] rand_ref [N][N];
        int trial;

        clk = 0;
        rst_n = 0;
        start = 0;

        weight[0][0] = 1;
        weight[0][1] = 2;
        weight[1][0] = 3;
        weight[1][1] = 4;

        for (int row = 0; row < N; row++) begin
            for (int col = 0; col < N; col++) begin
                activation[row][col] = '0;
                expected[row][col] = '0;
            end
        end

        activation[0][0] = 5;
        activation[0][1] = 6;
        activation[1][0] = 7;
        activation[1][1] = 8;

        compute_ref_matrix(activation, weight, expected);

        A_in[0] = activation[0][0];
        A_in[1] = activation[0][1];
        
        @(posedge clk);
        #1;
        if(out[0] == 0 && out[1] == 0)begin
            $display("InitReset: Pass");
        end else begin
            $display("InitReset: Fail");
            errors = errors + 1;
        end
        
        @(negedge clk);
        rst_n = 1;
        start = 1;
        @(negedge clk);
        start = 0;
        
        wait(dut.load_en == 1);
        @(posedge clk);
        #1;
        if(dut.array.ROW[0].COL[0].e.weight_reg == 1 &&
           dut.array.ROW[0].COL[1].e.weight_reg == 2 &&
           dut.array.ROW[1].COL[0].e.weight_reg == 3 &&
           dut.array.ROW[1].COL[1].e.weight_reg == 4) begin
            $display("LoadWeights: Pass");
        end else begin
            $display("LoadWeights: Fail");
            errors = errors + 1;
        end
        
        wait(dut.compute_en == 1);
        @(negedge clk);
        A_in[0] = 5;
        A_in[1] = 6;  
        
        @(posedge clk);
        #1;
        
        @(negedge clk);
        A_in[0] = 7;
        A_in[1] = 8;
        
        @(posedge clk);
        #1;
        if(dut.array.out[0] === expected[0][0]) begin
            $display("C00 Pass");
        end else begin
            $display("C00 Fail expected=%0d got=%0d", expected[0][0], dut.array.out[0]);
            errors = errors + 1;
        end
       
        @(negedge clk);
            A_in[0] = 0;
            A_in[1] = 0;
        
        @(posedge clk);
        #1;
        if(dut.array.out[0] === expected[1][0] &&
           dut.array.out[1] === expected[0][1]) begin
            $display("C10/C01 Pass");
        end else begin
            $display("C10/C01 Fail expected=(%0d,%0d) got=(%0d,%0d)",
                     expected[1][0], expected[0][1], dut.array.out[0], dut.array.out[1]);
            errors = errors + 1;
        end
        
        @(posedge clk);
        #1;
        if(dut.array.out[0] === '0 && dut.array.out[1] === expected[1][1]) begin
            $display("C11/Drain Pass");
        end else begin
            $display("C11/Drain Fail expected=(%0d,%0d) got=(%0d,%0d)",
                     '0, expected[1][1], dut.array.out[0], dut.array.out[1]);
            errors = errors + 1;
        end

        fork
            wait(done == 1);

            begin
                #1000;
                $display("Timeout: done was not asserted");
                errors = errors + 1;
            end
        join_any
        disable fork;

        if(done != 1'b1) begin
            errors = errors + 1;
        end else if(out[0] !== expected[1][0] || out[1] !== expected[1][1]) begin
            $display("Deskewed output: Fail expected=(%0d,%0d) got=(%0d,%0d)",
                     expected[1][0], expected[1][1], out[0], out[1]);
            errors = errors + 1;
        end else begin
            $display("Deskewed output: Pass");
        end

        for (trial = 0; trial < 1000; trial++) begin
            for (int row = 0; row < N; row++) begin
                for (int col = 0; col < N; col++) begin
                    rand_act[row][col] = $signed($urandom_range(-8, 8));
                    rand_wgt[row][col] = $signed($urandom_range(-8, 8));
                end
            end

            for (int row = 0; row < N; row++) begin
                for (int col = 0; col < N; col++) begin
                    weight[row][col] = rand_wgt[row][col];
                    activation[row][col] = rand_act[row][col];
                end
            end

            compute_ref_matrix(activation, weight, rand_ref);

            clk = 0;
            rst_n = 0;
            start = 0;
            for (int i = 0; i < N; i++) begin
                A_in[i] = '0;
            end
            @(posedge clk);
            #1;

            @(negedge clk);
            rst_n = 1;
            start = 1;
            @(negedge clk);
            start = 0;

            wait(dut.load_en == 1);
            @(posedge clk);
            #1;

            for (int row = 0; row < N; row++) begin
                for (int col = 0; col < N; col++) begin
                    A_in[col] = activation[row][col];
                end
                @(posedge clk);
                #1;
            end

            @(negedge clk);
            for (int i = 0; i < N; i++) begin
                A_in[i] = 0;
            end

            fork
                wait(done == 1);
                begin
                    #1000;
                    $display("Random trial %0d: Timeout: done was not asserted", trial);
                    errors = errors + 1;
                end
            join_any
            disable fork;

            if(done != 1'b1) begin
                errors = errors + 1;
            end else if (out[0] !== rand_ref[1][0] || out[1] !== rand_ref[1][1]) begin
                $display("Random trial %0d: FAIL expected=(%0d,%0d) got=(%0d,%0d)",
                         trial, rand_ref[1][0], rand_ref[1][1], out[0], out[1]);
                errors = errors + 1;
                $fatal(1);
            end
        end

        if(errors == 0) begin
            $display("TEST PASSED (deterministic + %0d randomized trials)", trial);
            $finish;
        end else begin
            $display("TEST FAILED (%0d errors)", errors);
            $fatal(1);
        end
    end
endmodule
