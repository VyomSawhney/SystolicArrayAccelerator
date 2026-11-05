`timescale 1ns/1ps

module accelerator_assertions (
    input logic clk,
    input logic rst_n,
    input logic start,
    input logic done
);
    logic busy;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
        end else begin
            if (start) busy <= 1'b1;
            if (done) busy <= 1'b0;
        end
    end

    start_is_one_cycle:
        assert property (@(posedge clk) disable iff (!rst_n)
            start |=> !start)
        else $error("start must be a one-cycle pulse");

    done_is_one_cycle:
        assert property (@(posedge clk) disable iff (!rst_n)
            done |=> !done)
        else $error("done must be a one-cycle pulse");

    done_requires_active_transaction:
        assert property (@(posedge clk) disable iff (!rst_n)
            done |-> busy)
        else $error("done asserted without an active transaction");

    no_start_while_active:
        assert property (@(posedge clk) disable iff (!rst_n)
            busy |-> !start)
        else $error("start asserted while a transaction is active");
endmodule
