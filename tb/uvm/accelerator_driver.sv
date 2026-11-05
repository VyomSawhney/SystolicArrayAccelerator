`include "uvm_macros.svh"
import uvm_pkg::*;

class accelerator_driver extends uvm_driver #(accelerator_item);
    `uvm_component_utils(accelerator_driver)

    virtual accelerator_if #(
        .N(`ACCEL_N), .DATA_W(16), .ACC_W(32 + $clog2(`ACCEL_N))
    ) vif;

    function new(string name = "accelerator_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual accelerator_if #(
            .N(`ACCEL_N), .DATA_W(16), .ACC_W(32 + $clog2(`ACCEL_N))
        ))::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "accelerator_if was not configured for the driver")
        end
    endfunction

    task drive_idle();
        vif.start <= 1'b0;
        vif.weight_flat <= '0;
        vif.A_in_flat <= '0;
    endtask

    task drive_item(accelerator_item item);
        bit completed;
        vif.weight_flat <= item.weight;
        vif.A_in_flat <= '0;

        @(negedge vif.clk);
        vif.start <= 1'b1;
        @(negedge vif.clk);
        vif.start <= 1'b0;

        // The controller spends one cycle in IDLE and one cycle in LOAD.
        repeat (2) @(posedge vif.clk);

        for (int row = 0; row < `ACCEL_N; row++) begin
            @(negedge vif.clk);
            for (int col = 0; col < `ACCEL_N; col++) begin
                vif.A_in_flat[col * 16 +: 16] <=
                    item.activation[(row * `ACCEL_N + col) * 16 +: 16];
            end
            @(posedge vif.clk);
        end

        @(negedge vif.clk);
        vif.A_in_flat <= '0;

        completed = 1'b0;
        repeat (100) begin
            @(posedge vif.clk);
            if (vif.done) begin
                completed = 1'b1;
                break;
            end
        end
        if (!completed) begin
            `uvm_fatal("TIMEOUT", "Accelerator did not assert done within 100 cycles")
        end
    endtask

    task run_phase(uvm_phase phase);
        accelerator_item item;
        drive_idle();
        vif.rst_n <= 1'b0;
        repeat (2) @(posedge vif.clk);
        @(negedge vif.clk);
        vif.rst_n <= 1'b1;

        forever begin
            seq_item_port.get_next_item(item);
            drive_item(item);
            seq_item_port.item_done();
        end
    endtask
endclass
