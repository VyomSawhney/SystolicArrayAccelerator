`timescale 1ns / 1ps

module accelerator#(
    parameter N = 2,
    parameter DATA_W = 16,
    parameter ACC_W = 2*DATA_W + $clog2(N)
)(
    input logic clk,
    input logic rst_n,
    input logic start,
    input logic signed [DATA_W-1:0] weight [N][N],
    input logic signed [DATA_W-1:0] A_in [N],
    output logic done,
    output logic signed [ACC_W-1:0] out [N]
);
    if (ACC_W < 2*DATA_W + $clog2(N))
        $error("ACC_W=%0d too narrow for DATA_W=%0d N=%0d, need %0d", ACC_W, DATA_W, N, 2*DATA_W + $clog2(N));

    logic load_en;
    logic skew_en;
    logic compute_en;
    logic drain_en;
    logic deskew_en;
    logic signed [DATA_W-1:0] skew_in [N];
    logic signed [DATA_W-1:0] skew_out [N];
    logic signed [ACC_W-1:0] done_skewed [N];
    controller#(
        .N(N)
    ) con(
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .load_weights(load_en),
        .skew_en(skew_en),
        .compute_en(compute_en),
        .drain_en(drain_en),
        .deskew_en(deskew_en),
        .done(done)
    );
    for(genvar i = 0; i<N; i++) begin
        assign skew_in[i] = drain_en ? '0 : A_in[i];
    end
    input_skew_buffer#(
        .DATA_W(DATA_W),
        .N(N)
    ) buff(
        .clk(clk),
        .rst_n(rst_n),
        .en(skew_en),
        .data_in(skew_in),
        .data_out(skew_out)
    );
    systolic_array#(
        .DATA_W(DATA_W),
        .ACC_W(ACC_W),
        .N(N)
    ) array(
        .clk(clk),
        .rst_n(rst_n),
        .en(compute_en),
        .load_weight(load_en),
        .weight(weight),
        .A_in(skew_out),
        .out(done_skewed)
    );
    output_deskew_buffer #(
        .ACC_W(ACC_W),
        .N    (N)
     ) output_deskew_buffer (
        .clk     (clk),
        .rst_n   (rst_n),
        .en      (deskew_en),
        .data_in (done_skewed),
        .data_out(out)
    );
endmodule
