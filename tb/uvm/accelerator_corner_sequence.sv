`include "uvm_macros.svh"
import uvm_pkg::*;

class accelerator_corner_sequence extends uvm_sequence #(accelerator_item);
    localparam int N = `ACCEL_N;
    `uvm_object_utils(accelerator_corner_sequence)

    function new(string name = "accelerator_corner_sequence");
        super.new(name);
    endfunction

    task send_case(
        logic signed [15:0] activation_values [N][N],
        logic signed [15:0] weight_values [N][N]
    );
        accelerator_item item;
        item = accelerator_item::type_id::create("corner_item");
        start_item(item);
        for (int row = 0; row < N; row++) begin
            for (int col = 0; col < N; col++) begin
                item.set_activation(row, col, activation_values[row][col]);
                item.set_weight(row, col, weight_values[row][col]);
            end
        end
        item.calculate_expected();
        finish_item(item);
    endtask

    task body();
        logic signed [15:0] zeros [N][N];
        logic signed [15:0] ones [N][N];
        logic signed [15:0] mixed [N][N];
        logic signed [15:0] identity [N][N];
        logic signed [15:0] maximum [N][N];
        logic signed [15:0] minimum [N][N];

        for (int row = 0; row < N; row++) begin
            for (int col = 0; col < N; col++) begin
                zeros[row][col] = '0;
                ones[row][col] = 16'sd1;
                mixed[row][col] = ((row + col) % 2 == 0) ? 16'sd7 : -16'sd8;
                identity[row][col] = (row == col) ? 16'sd1 : '0;
                maximum[row][col] = 16'sh7fff;
                minimum[row][col] = 16'sh8000;
            end
        end

        send_case(zeros, zeros);
        send_case(ones, ones);
        send_case(mixed, mixed);
        send_case(mixed, identity);
        send_case(maximum, maximum);
        send_case(minimum, maximum);
        send_case(maximum, minimum);
    endtask
endclass
