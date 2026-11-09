`timescale 1ns / 1ps

module int8_projection_tb;
    localparam int M = 2;
    localparam int K = 5;
    localparam int P = 4;
    localparam int ACC_W = 32;

    logic clk;
    logic rst_n;
    logic start;
    logic signed [7:0] activation [M][K];
    logic signed [7:0] weight [K][P];
    logic signed [ACC_W-1:0] bias [P];
    logic [5:0] requant_shift;
    logic relu_enable;
    logic signed [7:0] output_data [M][P];
    logic busy;
    logic done;
    logic [$clog2((M * K * P < 2) ? 2 : M * K * P)-1:0] useful_macs;
    int errors;

    int8_projection #(
        .M(M), .K(K), .P(P), .TILE_N(2), .ACC_W(ACC_W)
    ) dut (.*);

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        start = 1'b0;
        requant_shift = 2;
        relu_enable = 1'b1;
        errors = 0;

        for (int row = 0; row < M; row++)
            for (int k = 0; k < K; k++)
                activation[row][k] = row + k - 2;
        for (int k = 0; k < K; k++)
            for (int col = 0; col < P; col++)
                weight[k][col] = (k == col) ? 8'sd4 : 8'sd1;
        bias = '{8, -8, 200, -200};

        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        wait (done);
        @(posedge clk);
        #1;

        for (int row = 0; row < M; row++) begin
            for (int col = 0; col < P; col++) begin
                logic signed [ACC_W-1:0] expected_acc;
                logic signed [ACC_W-1:0] expected_shifted;
                logic signed [7:0] expected;
                expected_acc = bias[col];
                for (int k = 0; k < K; k++)
                    expected_acc += activation[row][k] * weight[k][col];
                expected_shifted = expected_acc >>> requant_shift;
                if (expected_shifted < 0)
                    expected = 0;
                else if (expected_shifted > 127)
                    expected = 127;
                else
                    expected = expected_shifted[7:0];
                if (output_data[row][col] !== expected) begin
                    $error("output[%0d][%0d]: expected %0d got %0d",
                        row, col, expected, output_data[row][col]);
                    errors++;
                end
            end
        end

        if (useful_macs != M * K * P) begin
            $error("useful MACs: expected %0d got %0d",
                M * K * P, useful_macs);
            errors++;
        end
        if (errors == 0)
            $display("INT8 PROJECTION PASS useful_macs=%0d", useful_macs);
        else
            $fatal(1, "INT8 PROJECTION FAILED with %0d errors", errors);
        #10 $finish;
    end
endmodule
