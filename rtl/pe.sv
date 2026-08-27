`timescale 1ns / 1ps

module pe #(
    parameter int DATA_W = 16,
    parameter int ACC_W = 32
)(
    input logic clk,
    input logic rst_n,
    input logic load_weight,
    input logic en,
    input logic signed [DATA_W-1:0] weight,
    input logic signed [ACC_W-1:0] psum_in,
    input logic signed [DATA_W-1:0] a_in,
    output logic signed [ACC_W-1:0] psum_out,
    output logic signed [DATA_W-1:0] a_out
);
    if (ACC_W < 2*DATA_W)
        $error("ACC_W=%0d too narrow for DATA_W=%0d, need %0d", ACC_W, DATA_W, 2*DATA_W);

    logic signed [DATA_W-1:0] weight_reg;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            psum_out <= '0;
            a_out <= '0;
            weight_reg <= '0;
        end
        else if(load_weight) begin
            weight_reg <= weight;
        end
        else if(en) begin
            a_out <= a_in;
            psum_out <= (a_in*weight_reg) + psum_in;
        end
    end
endmodule
