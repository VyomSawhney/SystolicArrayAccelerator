`timescale 1ns / 1ps


module output_deskew_buffer#(
    parameter int ACC_W = 32,
    parameter int N = 2
)(
    input logic clk,
    input logic rst_n,
    input logic en,
    input logic signed [ACC_W-1:0] data_in [N],
    output logic signed [ACC_W-1:0] data_out [N]
);

    logic signed [ACC_W-1:0] delay_regs [N][N];
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for (int i = 0; i < N; i++) begin
                for (int j = 0; j < N; j++) begin
                    delay_regs[i][j] <= '0;
                end
            end
        end
        else if(en) begin
            for(int i = 0; i < N-1; i++) begin
                delay_regs[i][0] <= data_in[i];
                
                for(int j = 1; j < N-1-i; j++) begin
                    delay_regs[i][j] <= delay_regs[i][j-1];
                end
            end
        end
    end
    
    assign data_out[N-1] = data_in[N-1];
    for(genvar y = 0; y<N-1; y++) begin
        assign data_out[y] = delay_regs[y][N-2-y];
    end


endmodule