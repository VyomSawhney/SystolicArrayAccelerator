`include "uvm_macros.svh"
import uvm_pkg::*;

class accelerator_item extends uvm_sequence_item;
    localparam int N = `ACCEL_N;
    localparam int DATA_W = 16;
    localparam int ACC_W = 2 * DATA_W + $clog2(N);

    rand logic signed [N*N*DATA_W-1:0] activation;
    rand logic signed [N*N*DATA_W-1:0] weight;
    logic signed [N*N*ACC_W-1:0] expected;
    logic signed [N*ACC_W-1:0] actual;

    `uvm_object_utils(accelerator_item)

    function new(string name = "accelerator_item");
        super.new(name);
    endfunction

    function void set_activation(int row, int col, logic signed [DATA_W-1:0] value);
        activation[(row * N + col) * DATA_W +: DATA_W] = value;
    endfunction

    function logic signed [DATA_W-1:0] get_activation(int row, int col);
        return activation[(row * N + col) * DATA_W +: DATA_W];
    endfunction

    function void set_weight(int row, int col, logic signed [DATA_W-1:0] value);
        weight[(row * N + col) * DATA_W +: DATA_W] = value;
    endfunction

    function logic signed [DATA_W-1:0] get_weight(int row, int col);
        return weight[(row * N + col) * DATA_W +: DATA_W];
    endfunction

    function void calculate_expected();
        logic signed [ACC_W-1:0] sum;
        logic signed [DATA_W-1:0] act_value;
        logic signed [DATA_W-1:0] weight_value;

        for (int row = 0; row < N; row++) begin
            for (int col = 0; col < N; col++) begin
                sum = '0;
                for (int k = 0; k < N; k++) begin
                    act_value = get_activation(row, k);
                    weight_value = get_weight(k, col);
                    sum += act_value * weight_value;
                end
                expected[(row * N + col) * ACC_W +: ACC_W] = sum;
            end
        end
    endfunction
endclass
