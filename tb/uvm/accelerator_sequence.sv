`include "uvm_macros.svh"
import uvm_pkg::*;

class accelerator_sequence extends uvm_sequence #(accelerator_item);
    `uvm_object_utils(accelerator_sequence)

    function new(string name = "accelerator_sequence");
        super.new(name);
    endfunction

    task body();
        accelerator_item item;
        repeat (1000) begin
            item = accelerator_item::type_id::create("item");
            start_item(item);
            if (!item.randomize()) begin
                `uvm_fatal("RANDFAIL", "Could not randomize accelerator transaction")
            end
            for (int index = 0; index < `ACCEL_N * `ACCEL_N; index++) begin
                item.activation[index * 16 +: 16] = $urandom_range(16) - 8;
                item.weight[index * 16 +: 16] = $urandom_range(16) - 8;
            end
            item.calculate_expected();
            finish_item(item);
        end
    endtask
endclass
