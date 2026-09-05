`timescale 1ns / 1ps


module input_skew_buffer#(
    parameter int DATA_W = 16,
    parameter int N = 2
)(
    input logic clk,
    input logic rst_n,
    input logic en,
    input logic signed [DATA_W-1:0] data_in [N],
    output logic signed [DATA_W-1:0] data_out [N]
    );
    logic signed [DATA_W-1:0] delay_regs [N][N];
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for (int i = 0; i < N; i++) begin
                for (int j = 0; j < N; j++) begin
                    delay_regs[i][j] <= '0;
                end
            end
        end
        else if(en) begin
            for(int i = 1; i < N; i++) begin
                delay_regs[i][0] <= data_in[i];
                
                for(int j = 1; j < i; j++) begin
                    delay_regs[i][j] <= delay_regs[i][j-1];
                end
            end
        end
    end
    
    assign data_out[0] = data_in[0];
    genvar skew_idx;
    generate
        for (skew_idx = 1; skew_idx < N; skew_idx = skew_idx + 1) begin : gen_skew_outputs
            assign data_out[skew_idx] = delay_regs[skew_idx][skew_idx-1];
        end
    endgenerate
    
endmodule
