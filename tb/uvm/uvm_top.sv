`timescale 1ns/1ps
`include "uvm_macros.svh"

import uvm_pkg::*;

module uvm_top;
    localparam int N = `ACCEL_N;
    localparam int DATA_W = 16;
    localparam int ACC_W = 2 * DATA_W + $clog2(N);

    logic signed [DATA_W-1:0] weight [N][N];
    logic signed [DATA_W-1:0] A_in [N];
    logic signed [ACC_W-1:0] out [N];

    accelerator_if #(.N(N), .DATA_W(DATA_W), .ACC_W(ACC_W)) vif();

    generate
        for (genvar row = 0; row < N; row++) begin : gen_weight_rows
            for (genvar col = 0; col < N; col++) begin : gen_weight_cols
                assign weight[row][col] =
                    vif.weight_flat[(row * N + col) * DATA_W +: DATA_W];
            end
        end
        for (genvar lane = 0; lane < N; lane++) begin : gen_lanes
            assign A_in[lane] = vif.A_in_flat[lane * DATA_W +: DATA_W];
            assign vif.out_flat[lane * ACC_W +: ACC_W] = out[lane];
        end
    endgenerate

    accelerator #(.N(N), .DATA_W(DATA_W), .ACC_W(ACC_W)) dut (
        .clk(vif.clk), .rst_n(vif.rst_n), .start(vif.start),
        .weight(weight), .A_in(A_in), .done(vif.done), .out(out)
    );

    initial begin
        vif.clk = 1'b0;
        forever #5 vif.clk = ~vif.clk;
    end

    initial begin
        uvm_config_db#(virtual accelerator_if #(
            .N(N), .DATA_W(DATA_W), .ACC_W(ACC_W)
        ))::set(null, "*", "vif", vif);
        run_test("accelerator_test");
    end

    accelerator_assertions protocol_assertions (
        .clk(vif.clk), .rst_n(vif.rst_n),
        .start(vif.start), .done(vif.done)
    );
endmodule
