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

    if (ACC_W < 2*DATA_W + $clog2(N))
        $error("ACC_W=%0d too narrow for DATA_W=%0d N=%0d, need %0d", ACC_W, DATA_W, N, 2*DATA_W + $clog2(N));

    logic signed [DATA_W-1:0] a_link [N][N+1];
    logic signed [ACC_W-1:0] psum_link [N+1][N];

    for(genvar i = 0; i < N; i++) begin : INPUTS
        assign a_link[i][0] = A_in[i];
        assign psum_link[0][i] = '0;
    end

    for(genvar i = 0; i < N; i++) begin : ROW
        for(genvar j = 0; j < N; j++) begin : COL
            pe #(
                .DATA_W(DATA_W),
                .ACC_W(ACC_W)
            ) e(
                .clk(clk),
                .rst_n(rst_n),
                .load_weight(load_weight),
                .en(en),
                .a_in(a_link[i][j]),
                .weight(weight[i][j]),
                .psum_in(psum_link[i][j]),
                .psum_out(psum_link[i+1][j]),
                .a_out(a_link[i][j+1])
            );
        end
    end

    for(genvar i = 0; i < N; i++) begin : OUTPUTS
        assign out[i] = psum_link[N][i];
    end

endmodule
