`include "uvm_macros.svh"
import uvm_pkg::*;

class accelerator_env extends uvm_env;
    `uvm_component_utils(accelerator_env)

    accelerator_agent agent;
    accelerator_scoreboard scoreboard;

    function new(string name = "accelerator_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = accelerator_agent::type_id::create("agent", this);
        scoreboard = accelerator_scoreboard::type_id::create("scoreboard", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        agent.monitor.analysis_port.connect(scoreboard.analysis_imp);
    endfunction
endclass
