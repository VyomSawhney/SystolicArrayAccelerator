`include "uvm_macros.svh"
import uvm_pkg::*;

class accelerator_monitor extends uvm_component;
    `uvm_component_utils(accelerator_monitor)

    virtual accelerator_if #(
        .N(`ACCEL_N), .DATA_W(16), .ACC_W(32 + $clog2(`ACCEL_N))
    ) vif;
    uvm_analysis_port #(accelerator_item) analysis_port;

    function new(string name = "accelerator_monitor", uvm_component parent = null);
        super.new(name, parent);
        analysis_port = new("analysis_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual accelerator_if #(
            .N(`ACCEL_N), .DATA_W(16), .ACC_W(32 + $clog2(`ACCEL_N))
        ))::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "accelerator_if was not configured for the monitor")
        end
    endfunction

    task run_phase(uvm_phase phase);
        accelerator_item item;
        int capture_delay;
        int row_count;

        forever begin
            @(posedge vif.clk);
            if (!vif.rst_n) begin
                capture_delay = 0;
                row_count = 0;
            end else if (vif.start) begin
                item = accelerator_item::type_id::create("observed_item");
                item.weight = vif.weight_flat;
                capture_delay = 2;
                row_count = 0;
            end else if (capture_delay > 0) begin
                capture_delay--;
            end else if (row_count < `ACCEL_N && item != null) begin
                for (int col = 0; col < `ACCEL_N; col++) begin
                    item.set_activation(
                        row_count, col, vif.A_in_flat[col * 16 +: 16]);
                end
                row_count++;
            end

            if (vif.done && item != null) begin
                item.actual = vif.out_flat;
                item.calculate_expected();
                analysis_port.write(item);
                item = null;
                row_count = 0;
            end
        end
    endtask
endclass
