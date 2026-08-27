`timescale 1ns / 1ps

module systolic_array_tb#(
    parameter DATA_W = 16,
    parameter N = 2,
    parameter ACC_W = 2*DATA_W + $clog2(N)
);
    logic clk;
    logic rst_n;
    logic load_weight;
    logic en;
    logic signed [DATA_W-1:0] weight [N][N];
    logic signed [DATA_W-1:0] A_in [N];
    logic signed [ACC_W-1:0] out [N];

    int errors = 0;
    
    systolic_array#(
        .DATA_W(DATA_W),
        .N(N),
        .ACC_W(ACC_W)
    ) dut(
        .clk(clk),
        .rst_n(rst_n),
        .load_weight(load_weight),
        .en(en),
        .A_in(A_in),
        .weight(weight),
        .out(out)
    );
    
    always #5 clk = ~clk;
    
    initial begin
        clk = 0;
        rst_n = 0;
        load_weight = 0;
        en = 0;
        weight[0][0] = 1;
        weight[0][1] = 2;
        weight[1][0] = 3;
        weight[1][1] = 4;
        A_in[0] = 0;
        A_in[1] = 0;
    
        @(posedge clk);
        #1;
        if(out[0] == 0 && out[1] == 0)begin
            $display("InitReset: Pass");
        end else begin
            $display("InitReset: Fail");
            errors = errors + 1;
        end
        
        rst_n = 1;
        load_weight = 1;
        @(posedge clk);
        #1;
        if(dut.ROW[0].COL[0].e.weight_reg == 1 &&
           dut.ROW[0].COL[1].e.weight_reg == 2 &&
           dut.ROW[1].COL[0].e.weight_reg == 3 &&
           dut.ROW[1].COL[1].e.weight_reg == 4) begin
            $display("LoadWeights: Pass");
        end else begin
            $display("LoadWeights: Fail");
            errors = errors + 1;
        end
        
        load_weight = 0;
        en = 1;
        A_in[0] = 5;
        A_in[1] = 0;
        @(posedge clk);
        #1;
        
        A_in[0] = 7;
        A_in[1] = 6;
        @(posedge clk);
        #1;
        if(out[0] == 23) begin
            $display("C00 Pass");
        end else begin
            $display("C00 Fail");
            errors = errors + 1;
        end
        
        A_in[0] = 0;
        A_in[1] = 8;
        @(posedge clk);
        #1;
        if(out[0] == 31 && out[1] == 34) begin
            $display("C10/C01 Pass");
        end else begin
            $display("C10/C01 Fail");
            errors = errors + 1;
        end
        
        A_in[0] = 0;
        A_in[1] = 0;
        @(posedge clk);
        #1;
        if(out[0] == 0 && out[1] == 46) begin
            $display("C11/Drain Pass");
        end else begin
            $display("C11/Drain Fail");
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
