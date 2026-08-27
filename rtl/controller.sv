`timescale 1ns / 1ps

module controller#(
    parameter N = 2
)(
    input logic clk,
    input logic rst_n,
    input logic start,
    output logic load_weights,
    output logic skew_en,
    output logic compute_en,
    output logic drain_en,
    output logic deskew_en,
    output logic done
);
    localparam int drain_cycles = 2*(N-1);
    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        COMPUTE,
        DRAIN,
        DONE
    } state_t;

    state_t state;
    logic [$clog2(N+1)-1:0] compute;
    logic [$clog2(drain_cycles+1)-1:0] drain;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= IDLE;
            load_weights <= 0;
            skew_en <= 0;
            done <= 0;
            compute <= '0;
            drain <= '0;
            compute_en <= 0;
            drain_en <= 0;
            deskew_en <= 0;
        end
        else begin
            unique case (state)
                IDLE: begin
                    if(start) begin
                        state <= LOAD;
                    end else begin
                        state <= IDLE;
                    end

                    done <= 0;
                    load_weights <= 0;
                    skew_en <= 0;
                    compute_en <= 0;
                    drain_en <= 0;
                    deskew_en <= 0;
                end

                LOAD: begin
                    load_weights <= 1;
                    compute_en <= 0;
                    drain_en <= 0;
                    skew_en <= 0;
                    deskew_en <= 0;
                    state <= COMPUTE;
                    done <= 0;
                end

                COMPUTE: begin
                    done <= 0;
                    drain_en <= 0;
                    load_weights <= 0;
                    skew_en <= 1;
                    compute_en <= 1;
                    deskew_en <= 1;
                    if(compute == N-1) begin
                        compute <= 0;
                        state <= DRAIN;
                    end else begin
                        state <= COMPUTE;
                        compute <= compute + 1;
                    end
                end

                DRAIN: begin
                    done <= 0;
                    drain_en <= 1;
                    load_weights <= 0;
                    skew_en <= 1;
                    compute_en <= 1;
                    deskew_en <= 1;
                    if(drain == drain_cycles-1) begin
                        drain <= 0;
                        state <= DONE;
                    end else begin
                        state <= DRAIN;
                        drain <= drain + 1;
                    end
                end

                DONE: begin
                    compute_en <= 0;
                    drain_en <= 0;
                    skew_en <= 0;
                    load_weights <= 0;
                    deskew_en <= 0;
                    done <= 1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    load_weights <= 0;
                    skew_en <= 0;
                    compute_en <= 0;
                    drain_en <= 0;
                    deskew_en <= 0;
                    done <= 0;
                    compute <= '0;
                    drain <= '0;
                end
            endcase
        end
    end
endmodule
