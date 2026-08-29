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
                @(negedge clk);
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
                    #5000;
                    $display("Random trial %0d: Timeout: done was not asserted", trial);
                    errors = errors + 1;
                end
            join_any
            disable fork;

            if(done != 1'b1) begin
                errors = errors + 1;
            end else begin
                logic check_pass = 1'b1;
                for (int i = 0; i < N; i++) begin
                    if (out[i] !== rand_ref[N-1][i]) begin
                        check_pass = 1'b0;
                        if (i == 0) begin
                            $display("Random trial %0d (N=%0d): FAIL at lane %0d", trial, N, i);
                        end
                    end
                end
                if (!check_pass) begin
                    errors = errors + 1;
                    $fatal(1);
                end
            end
        end

        if(errors == 0) begin
            $display("TEST PASSED (N=%0d, %0d randomized trials)", N, trial);
        end else begin
            $display("TEST FAILED (N=%0d, %0d errors)", N, errors);
        end
    end
endmodule
