`timescale 1ns / 1ps

module input_skew_buffer_tb#(
    parameter DATA_W = 16,
    parameter N = 2
);

    logic clk;
    logic rst_n;
    logic en;
    logic signed [DATA_W-1:0] data_in [N];
    logic signed [DATA_W-1:0] data_out [N];

    int errors = 0;
    
    input_skew_buffer dut(
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .data_in(data_in),
        .data_out(data_out)
    );
    
    always #5 clk = ~clk;
    
    initial begin
        clk = 0;
        rst_n = 0;
        en = 0;
        data_in[0] = 0;
        data_in[1] = 0;

        @(posedge clk);
        #1;
        if(data_out[0] == 0 && data_out[1] == 0) begin
            $display("InitReset: Pass");
        end else begin
            $display("InitReset: Fail");
            errors = errors + 1;
        end

        @(negedge clk);
        rst_n = 1;
        en = 1;
        data_in[0] = 1;
        data_in[1] = 2;
        #1;

        if(data_out[0] == 1 && data_out[1] == 0) begin
            $display("First Skew: Pass");
        end else begin
            $display("First Skew: Fail");
            errors = errors + 1;
        end

        @(posedge clk);

        @(negedge clk);
        data_in[0] = 3;
        data_in[1] = 4;
        #1;

        if(data_out[0] == 3 && data_out[1] == 2) begin
            $display("Mid Skew: Pass");
        end else begin
            $display("Mid Skew: Fail");
            errors = errors + 1;
        end

        @(posedge clk);

        @(negedge clk);
        data_in[0] = 0;
        data_in[1] = 0;
        #1;

        if(data_out[0] == 0 && data_out[1] == 4) begin
            $display("Final Skew: Pass");
        end else begin
            $display("Final Skew: Fail");
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
