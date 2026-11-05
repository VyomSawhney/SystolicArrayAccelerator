`timescale 1ns/1ps
`ifndef ACCEL_N
    `ifdef ACCEL_N_2
        `define ACCEL_N 2
    `elsif ACCEL_N_3
        `define ACCEL_N 3
    `elsif ACCEL_N_4
        `define ACCEL_N 4
    `elsif ACCEL_N_8
        `define ACCEL_N 8
    `elsif ACCEL_N_16
        `define ACCEL_N 16
    `else
        `define ACCEL_N 2
    `endif
`endif

interface accelerator_if #(
    parameter int N = `ACCEL_N,
    parameter int DATA_W = 16,
    parameter int ACC_W = 2 * DATA_W + $clog2(N)
);
    logic clk;
    logic rst_n;
    logic start;
    logic [N*N*DATA_W-1:0] weight_flat;
    logic [N*DATA_W-1:0] A_in_flat;
    logic done;
    logic [N*ACC_W-1:0] out_flat;
endinterface
