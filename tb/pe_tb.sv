`timescale 1ns / 1ps


module pe_tb;
    logic clk;
    logic rst_n;
    logic load_weight;
    logic en;
    logic signed [15:0] weight;
    logic signed [31:0] psum_in;
    logic signed [15:0] a_in;
    logic signed [31:0] psum_out;
    logic signed [15:0] a_out;

    int errors = 0;
    
    pe dut(
    .clk(clk),
    .rst_n(rst_n),
    .en(en),
    .load_weight(load_weight),
    .weight(weight),
    .psum_in(psum_in),
    .psum_out(psum_out),
    .a_in(a_in),
    .a_out(a_out)
    );
   
    always #5 clk = ~clk;
    
    initial begin
        clk = 0;
        rst_n = 0;
        load_weight = 0;
        weight = 0;
        psum_in = 0;
        a_in = 0;
        en = 0;
        
        #3;
        if(a_out == 0 && psum_out == 0) begin
            $display("InitReset: Pass");
        end else begin
            $display("InitReset: Fail");
            errors = errors + 1;
        end
        rst_n = 1;
        en = 1;
        weight = 4;
        load_weight = 1;
        a_in = 5;
        psum_in = 1;
        @(posedge clk)
        #1;
        load_weight = 0;
        @(posedge clk)
        #1;
        if(a_out == 5 && psum_out == 21) begin
            $display("Load&Compute: Pass");
        end else begin
            $display("Load&Compute: Fail a_out=%0d psum_out=%0d", a_out, psum_out);
            errors = errors + 1;
        end
        
        if(errors == 0) begin
            $display("TEST PASSED");
            $finish;
        end else begin
            $display("TEST FAILED (%0d errors)", errors);
            $fatal(1);
        end
    end
   
endmodule
