`timescale 1ns / 1ps

module systolic_array #(
    parameter DATA_W = 16,
    parameter N = 2,
    parameter ACC_W = 2*DATA_W + $clog2(N)
)(
    input logic clk,
    input logic rst_n,
    input logic load_weight,
    input logic en,
    input logic signed [DATA_W-1:0] weight [N][N],
    input logic signed [DATA_W-1:0] A_in [N],
    output logic signed [ACC_W-1:0] out [N]
    );

    generate
        if (ACC_W < 2*DATA_W + $clog2(N)) begin : gen_invalid_width
            initial $error("ACC_W=%0d too narrow for DATA_W=%0d N=%0d, need %0d", ACC_W, DATA_W, N, 2*DATA_W + $clog2(N));
        end
    endgenerate

    logic signed [DATA_W-1:0] a_link [N][N+1];
    logic signed [ACC_W-1:0] psum_link [N+1][N];

    genvar input_idx;
    genvar row_idx;
    genvar col_idx;
    genvar output_idx;
    generate
        for (input_idx = 0; input_idx < N; input_idx = input_idx + 1) begin : INPUTS
            assign a_link[input_idx][0] = A_in[input_idx];
            assign psum_link[0][input_idx] = '0;
        end

        for (row_idx = 0; row_idx < N; row_idx = row_idx + 1) begin : ROW
            for (col_idx = 0; col_idx < N; col_idx = col_idx + 1) begin : COL
                pe #(
                    .DATA_W(DATA_W),
                    .ACC_W(ACC_W)
                ) e(
                    .clk(clk),
                    .rst_n(rst_n),
                    .load_weight(load_weight),
                    .en(en),
                    .a_in(a_link[row_idx][col_idx]),
                    .weight(weight[row_idx][col_idx]),
                    .psum_in(psum_link[row_idx][col_idx]),
                    .psum_out(psum_link[row_idx+1][col_idx]),
                    .a_out(a_link[row_idx][col_idx+1])
                );
            end
        end

        for (output_idx = 0; output_idx < N; output_idx = output_idx + 1) begin : OUTPUTS
            assign out[output_idx] = psum_link[N][output_idx];
        end
    endgenerate

endmodule
