`timescale 1ns / 1ps

module tiled_gemm_case #(
    parameter int M = 3,
    parameter int K = 5,
    parameter int P = 4,
    parameter int TILE_N = 2,
    parameter int DATA_W = 16,
    parameter int ACC_W = 2 * DATA_W + $clog2((K < 2) ? 2 : K),
    parameter int COUNT_W = $clog2(
        ((M * ((P + TILE_N - 1) / TILE_N) * ((K + TILE_N - 1) / TILE_N)
        * (3 * TILE_N + 8)) < 2) ? 2 :
        (M * ((P + TILE_N - 1) / TILE_N) * ((K + TILE_N - 1) / TILE_N)
        * (3 * TILE_N + 8) + 1))
) (
    output logic finished
);
    logic clk;
    logic rst_n;
    logic start;
    logic signed [DATA_W-1:0] A [M][K];
    logic signed [DATA_W-1:0] B [K][P];
    logic signed [ACC_W-1:0] C [M][P];
    logic busy;
    logic done;
    logic [COUNT_W-1:0] cycle_count;
    logic [COUNT_W-1:0] active_mac_count;
    int errors;
    int measured_cycles;

    tiled_gemm #(
        .M(M), .K(K), .P(P), .TILE_N(TILE_N),
        .DATA_W(DATA_W), .ACC_W(ACC_W)
    ) dut (.*);

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        start = 1'b0;
        finished = 1'b0;
        errors = 0;
        measured_cycles = 0;

        for (int row = 0; row < M; row++) begin
            for (int k = 0; k < K; k++) begin
                A[row][k] = row + k - 2;
            end
        end
        for (int k = 0; k < K; k++) begin
            for (int col = 0; col < P; col++) begin
                B[k][col] = 2 * k - col + 1;
            end
        end

        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        while (!done) begin
            @(posedge clk);
            if (busy) begin
                measured_cycles++;
            end
        end
        #1;
        for (int row = 0; row < M; row++) begin
            for (int col = 0; col < P; col++) begin
                logic signed [ACC_W-1:0] expected;
                expected = '0;
                for (int k = 0; k < K; k++) begin
                    expected += A[row][k] * B[k][col];
                end
                if (C[row][col] !== expected) begin
                    $error("TILE_N=%0d mismatch C[%0d][%0d]: expected %0d got %0d",
                        TILE_N, row, col, expected, C[row][col]);
                    errors++;
                end
            end
        end
        if (active_mac_count != M * K * P) begin
            $error("TILE_N=%0d active MAC count: expected %0d got %0d",
                TILE_N, M * K * P, active_mac_count);
            errors++;
        end
        if (cycle_count != measured_cycles) begin
            $error("TILE_N=%0d cycle count: expected measured %0d got %0d",
                TILE_N, measured_cycles, cycle_count);
            errors++;
        end
        if (errors == 0) begin
            $display("TILED GEMM PASS M=%0d K=%0d P=%0d TILE_N=%0d cycles=%0d",
                M, K, P, TILE_N, cycle_count);
        end else begin
            $fatal(1, "TILED GEMM FAILED with %0d errors", errors);
        end
        finished = 1'b1;
    end
endmodule

module tiled_gemm_tb;
    logic done_n2;
    logic done_n4;
    logic done_n8;

    tiled_gemm_case #(.TILE_N(2)) n2 (.finished(done_n2));
    tiled_gemm_case #(.TILE_N(4)) n4 (.finished(done_n4));
    tiled_gemm_case #(.TILE_N(8)) n8 (.finished(done_n8));

    initial begin
        wait (done_n2 && done_n4 && done_n8);
        $display("TILED GEMM PARAMETER SWEEP PASSED");
        #10 $finish;
    end
endmodule
