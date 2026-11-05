`include "uvm_macros.svh"
import uvm_pkg::*;

class accelerator_test extends uvm_test;
    `uvm_component_utils(accelerator_test)

    accelerator_env env;

    function new(string name = "accelerator_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = accelerator_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        accelerator_sequence test_sequence;
        phase.raise_objection(this);
        test_sequence = accelerator_sequence::type_id::create("test_sequence");
        test_sequence.start(env.agent.sequencer);
        phase.drop_objection(this);
    endtask
endclass

class accelerator_corner_test extends uvm_test;
    `uvm_component_utils(accelerator_corner_test)

    accelerator_env env;

    function new(string name = "accelerator_corner_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_config_db#(int)::set(this, "env.scoreboard", "expected_transactions", 7);
        env = accelerator_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        accelerator_corner_sequence corner_sequence;
        phase.raise_objection(this);
        corner_sequence = accelerator_corner_sequence::type_id::create("corner_sequence");
        corner_sequence.start(env.agent.sequencer);
        phase.drop_objection(this);
    endtask
endclass
