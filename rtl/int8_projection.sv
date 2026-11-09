`timescale 1ns / 1ps

module int8_projection #(
    parameter int M = 2,
    parameter int K = 5,
    parameter int P = 4,
    parameter int TILE_N = 2,
    parameter int ACC_W = 32,
    parameter int COUNT_W = $clog2((M * K * P < 2) ? 2 : M * K * P)
) (
    input logic clk,
    input logic rst_n,
    input logic start,
    input logic signed [7:0] activation [M][K],
    input logic signed [7:0] weight [K][P],
    input logic signed [ACC_W-1:0] bias [P],
    input logic [5:0] requant_shift,
    input logic relu_enable,
    output logic signed [7:0] output_data [M][P],
    output logic busy,
    output logic done,
    output logic [COUNT_W-1:0] useful_macs
);
    localparam int GEMM_COUNT_W = $clog2(
        ((M * ((P + TILE_N - 1) / TILE_N) * ((K + TILE_N - 1) / TILE_N)
        * (3 * TILE_N + 8)) < 2) ? 2 :
        (M * ((P + TILE_N - 1) / TILE_N) * ((K + TILE_N - 1) / TILE_N)
        * (3 * TILE_N + 8) + 1));

    logic signed [ACC_W-1:0] accum [M][P];
    logic signed [ACC_W-1:0] gemm_output [M][P];
    logic gemm_busy;
    logic gemm_done;
    logic [GEMM_COUNT_W-1:0] gemm_cycles;
    logic [GEMM_COUNT_W-1:0] gemm_macs;
    logic postprocess;

    tiled_gemm #(
        .M(M), .K(K), .P(P), .TILE_N(TILE_N),
        .COUNT_W(GEMM_COUNT_W),
        .DATA_W(8), .ACC_W(ACC_W)
    ) gemm (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .A(activation),
        .B(weight),
        .C(gemm_output),
        .busy(gemm_busy),
        .done(gemm_done),
        .cycle_count(gemm_cycles),
        .active_mac_count(gemm_macs)
    );

    assign busy = gemm_busy || postprocess;
    assign done = postprocess;
    assign useful_macs = gemm_macs;

    function automatic logic signed [7:0] quantize(
        input logic signed [ACC_W-1:0] value
    );
        logic signed [ACC_W-1:0] shifted;
        begin
            shifted = value >>> requant_shift;
            if (relu_enable && shifted < 0)
                quantize = 8'sd0;
            else if (shifted > 127)
                quantize = 8'sh7f;
            else if (shifted < -128)
                quantize = -8'sd128;
            else
                quantize = shifted[7:0];
        end
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            postprocess <= 1'b0;
            for (int row = 0; row < M; row++) begin
                for (int col = 0; col < P; col++) begin
                    accum[row][col] <= '0;
                    output_data[row][col] <= '0;
                end
            end
        end else begin
            postprocess <= 1'b0;
            if (gemm_done) begin
                for (int row = 0; row < M; row++) begin
                    for (int col = 0; col < P; col++) begin
                        accum[row][col] <= gemm_output[row][col] + bias[col];
                    end
                end
                postprocess <= 1'b1;
            end else if (postprocess) begin
                for (int row = 0; row < M; row++) begin
                    for (int col = 0; col < P; col++) begin
                        output_data[row][col] <= quantize(accum[row][col]);
                    end
                end
            end
        end
    end
endmodule
