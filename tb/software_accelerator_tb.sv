`timescale 1ns / 1ps

module software_accelerator_tb;
    localparam int M = 3;
    localparam int K = 5;
    localparam int P = 4;
    localparam int DATA_W = 16;
    localparam int ACC_W = 35;

    logic clk;
    logic rst_n;
    logic [3:0] avs_address;
    logic avs_write;
    logic avs_read;
    logic [31:0] avs_writedata;
    logic [31:0] avs_readdata;
    logic dma_in_valid;
    logic dma_in_ready;
    logic signed [DATA_W-1:0] dma_in_data;
    logic dma_out_ready;
    logic dma_out_valid;
    logic dma_out_last;
    logic signed [ACC_W-1:0] dma_out_data;
    logic signed [DATA_W-1:0] a_values [M][K];
    logic signed [DATA_W-1:0] b_values [K][P];
    int errors;

    software_accelerator #(
        .M(M), .K(K), .P(P), .TILE_N(2),
        .DATA_W(DATA_W), .ACC_W(ACC_W)
    ) dut (.*);

    always #5 clk = ~clk;

    task automatic write_reg(input logic [3:0] address, input logic [31:0] data);
        @(negedge clk);
        avs_address = address;
        avs_writedata = data;
        avs_write = 1'b1;
        @(negedge clk);
        avs_write = 1'b0;
    endtask

    task automatic send_input(input logic signed [DATA_W-1:0] value);
        while (!dma_in_ready) @(posedge clk);
        @(negedge clk);
        dma_in_data = value;
        dma_in_valid = 1'b1;
        @(negedge clk);
        dma_in_valid = 1'b0;
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        avs_address = '0;
        avs_write = 1'b0;
        avs_read = 1'b0;
        avs_writedata = '0;
        dma_in_valid = 1'b0;
        dma_in_data = '0;
        dma_out_ready = 1'b0;
        errors = 0;

        for (int row = 0; row < M; row++)
            for (int k = 0; k < K; k++)
                a_values[row][k] = row + k - 2;
        for (int k = 0; k < K; k++)
            for (int col = 0; col < P; col++)
                b_values[k][col] = 2 * k - col + 1;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        write_reg(4'h5, 32'd1);
        for (int index = 0; index < M * K; index++)
            send_input(a_values[index / K][index % K]);

        write_reg(4'h5, 32'd2);
        for (int index = 0; index < K * P; index++)
            send_input(b_values[index / P][index % P]);

        write_reg(4'h0, 32'd1);
        wait (dut.compute_done_seen);

        write_reg(4'h5, 32'd3);
        dma_out_ready = 1'b1;
        for (int index = 0; index < M * P; index++) begin
            if (!dma_out_valid) begin
                $error("Missing output at index %0d", index);
                errors++;
            end else begin
                logic signed [ACC_W-1:0] expected;
                expected = '0;
                for (int k = 0; k < K; k++)
                    expected += a_values[index / P][k] * b_values[k][index % P];
                if (dma_out_data !== expected) begin
                    $error("Output %0d expected %0d got %0d",
                        index, expected, dma_out_data);
                    errors++;
                end
            end
            if (index != M * P - 1) begin
                @(posedge clk);
                @(negedge clk);
            end
        end

        if (errors == 0)
            $display("SOFTWARE SUBSYSTEM PASS cycles=%0d macs=%0d",
                dut.compute_cycles, dut.compute_macs);
        else
            $fatal(1, "SOFTWARE SUBSYSTEM FAILED with %0d errors", errors);
        #10 $finish;
    end
endmodule
