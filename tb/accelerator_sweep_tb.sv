`timescale 1ns / 1ps

module accelerator_sweep_tb;
    
    initial begin
        $display("Starting N-sweep verification");
    end
    
    initial begin
        #3000000 begin
            $display("Sweep simulation timeout");
            $finish;
        end
    end
    
    // N=2
    accelerator_tb #(.N(2), .DATA_W(16)) tb_n2_inst ();
    
    // N=3
    accelerator_tb #(.N(3), .DATA_W(16)) tb_n3_inst ();
    
    // N=4
    accelerator_tb #(.N(4), .DATA_W(16)) tb_n4_inst ();
    
    // N=8
    accelerator_tb #(.N(8), .DATA_W(16)) tb_n8_inst ();
    
    // N=16
    accelerator_tb #(.N(16), .DATA_W(16)) tb_n16_inst ();
    
endmodule
