`include "uvm_macros.svh"
import uvm_pkg::*;

class accelerator_scoreboard extends uvm_component;
    localparam int N = `ACCEL_N;
    localparam int ACC_W = 2 * 16 + $clog2(N);

    `uvm_component_utils(accelerator_scoreboard)

    uvm_analysis_imp #(accelerator_item, accelerator_scoreboard) analysis_imp;
    int checked;
    int errors;
    int expected_transactions = 1000;

    function new(string name = "accelerator_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        analysis_imp = new("analysis_imp", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_config_db#(int)::get(
            this, "", "expected_transactions", expected_transactions));
    endfunction

    function void write(accelerator_item item);
        checked++;
        for (int col = 0; col < N; col++) begin
            if (item.actual[col * ACC_W +: ACC_W] !==
                item.expected[((N - 1) * N + col) * ACC_W +: ACC_W]) begin
                errors++;
                `uvm_error("MISMATCH", $sformatf(
                    "Transaction %0d lane %0d: expected %0d, got %0d",
                    checked, col,
                    item.expected[((N - 1) * N + col) * ACC_W +: ACC_W],
                    item.actual[col * ACC_W +: ACC_W]))
            end
        end
    endfunction

    function void report_phase(uvm_phase phase);
        if (checked != expected_transactions) begin
            `uvm_error("COUNT", $sformatf(
                "Checked %0d transactions, expected %0d",
                checked, expected_transactions))
        end
        if (errors == 0 && checked == expected_transactions) begin
            `uvm_info("PASS", $sformatf(
                "N=%0d UVM scoreboard passed %0d transactions",
                N, checked), UVM_NONE)
        end
    endfunction
endclass
