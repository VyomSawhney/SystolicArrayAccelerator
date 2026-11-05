`timescale 1ns / 1ps

module tiled_gemm #(
    parameter int M = 1,
    parameter int K = 1,
    parameter int P = 1,
    parameter int TILE_N = 2,
    parameter int DATA_W = 16,
    parameter int ACC_W = 2 * DATA_W + $clog2((K < 2) ? 2 : K),
    parameter int COUNT_W = $clog2(
        ((M * ((P + TILE_N - 1) / TILE_N) * ((K + TILE_N - 1) / TILE_N)
        * (3 * TILE_N + 8)) < 2) ? 2 :
        (M * ((P + TILE_N - 1) / TILE_N) * ((K + TILE_N - 1) / TILE_N)
        * (3 * TILE_N + 8) + 1))
) (
    input logic clk,
    input logic rst_n,
    input logic start,
    input logic signed [DATA_W-1:0] A [M][K],
    input logic signed [DATA_W-1:0] B [K][P],
    output logic signed [ACC_W-1:0] C [M][P],
    output logic busy,
    output logic done,
    output logic [COUNT_W-1:0] cycle_count,
    output logic [COUNT_W-1:0] active_mac_count
);
    localparam int ROW_TILES = (M + TILE_N - 1) / TILE_N;
    localparam int COL_TILES = (P + TILE_N - 1) / TILE_N;
    localparam int K_TILES = (K + TILE_N - 1) / TILE_N;
    localparam int COUNTER_W = COUNT_W;
    localparam int TILE_INDEX_W = $clog2((M > P ? M : P) + 1);
    localparam int K_INDEX_W = $clog2(K_TILES + 1);
    localparam int FEED_INDEX_W = $clog2(TILE_N + 1);

    generate
        if (TILE_N < 2) begin : gen_invalid_tile
            initial $error("TILE_N must be at least 2");
        end
    endgenerate

    typedef enum logic [3:0] {
        IDLE,
        ISSUE,
        LOAD_WAIT,
        FEED,
        WAIT_DONE,
        COMPLETE
    } state_t;

    state_t state;
    logic [TILE_INDEX_W-1:0] row_base;
    logic [TILE_INDEX_W-1:0] col_base;
    logic [K_INDEX_W-1:0] k_base;
    logic [FEED_INDEX_W-1:0] feed_index;
    logic [COUNTER_W-1:0] total_cycles;
    logic [COUNTER_W-1:0] active_macs;

    logic signed [DATA_W-1:0] tile_weight [TILE_N][TILE_N];
    logic signed [DATA_W-1:0] tile_input [TILE_N];
    logic signed [ACC_W-1:0] tile_output [TILE_N];
    logic signed [ACC_W-1:0] tile_result [TILE_N];
    logic tile_start;
    logic tile_done;

    assign busy = (state != IDLE) && (state != COMPLETE);
    assign done = (state == COMPLETE);
    assign cycle_count = total_cycles;
    assign active_mac_count = active_macs;

    always_comb begin
        tile_start = (state == ISSUE);

        for (int i = 0; i < TILE_N; i++) begin
            tile_input[i] = '0;
            for (int j = 0; j < TILE_N; j++) begin
                tile_weight[i][j] = '0;
            end
        end

        if (state == FEED) begin
            for (int i = 0; i < TILE_N; i++) begin
                if ((row_base < M) && (k_base * TILE_N + i < K)) begin
                    tile_input[i] = A[row_base][k_base * TILE_N + i];
                end
            end
        end

        for (int i = 0; i < TILE_N; i++) begin
            for (int j = 0; j < TILE_N; j++) begin
                if ((k_base * TILE_N + i < K) && (col_base * TILE_N + j < P)) begin
                    tile_weight[i][j] = B[k_base * TILE_N + i][col_base * TILE_N + j];
                end
            end
        end
    end

    accelerator #(
        .N(TILE_N),
        .DATA_W(DATA_W),
        .ACC_W(ACC_W)
    ) tile_accelerator (
        .clk(clk),
        .rst_n(rst_n),
        .start(tile_start),
        .weight(tile_weight),
        .A_in(tile_input),
        .done(tile_done),
        .out(tile_output)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            row_base <= '0;
            col_base <= '0;
            k_base <= '0;
            feed_index <= '0;
            total_cycles <= '0;
            active_macs <= '0;
            for (int lane = 0; lane < TILE_N; lane++) begin
                tile_result[lane] <= '0;
            end
            for (int row = 0; row < M; row++) begin
                for (int col = 0; col < P; col++) begin
                    C[row][col] <= '0;
                end
            end
        end else begin
            if (state != IDLE && state != COMPLETE) begin
                total_cycles <= total_cycles + 1'b1;
            end

            case (state)
                IDLE: begin
                    if (start) begin
                        row_base <= '0;
                        col_base <= '0;
                        k_base <= '0;
                        feed_index <= '0;
                        total_cycles <= '0;
                        active_macs <= '0;
                        for (int row = 0; row < M; row++) begin
                            for (int col = 0; col < P; col++) begin
                                C[row][col] <= '0;
                            end
                        end
                        state <= ISSUE;
                    end
                end

                ISSUE: begin
                    feed_index <= '0;
                    state <= LOAD_WAIT;
                end

                LOAD_WAIT: begin
                    state <= FEED;
                end

                FEED: begin
                    if (feed_index == TILE_N - 1) begin
                        state <= WAIT_DONE;
                    end else begin
                        feed_index <= feed_index + 1'b1;
                    end
                end

                WAIT_DONE: begin
                    for (int lane = 0; lane < TILE_N; lane++) begin
                        tile_result[lane] <= tile_output[lane];
                    end
                    if (tile_done) begin
                        active_macs <= active_macs
                            + ((K - k_base * TILE_N < TILE_N) ?
                                (K - k_base * TILE_N) : TILE_N)
                            * ((P - col_base * TILE_N < TILE_N) ?
                                (P - col_base * TILE_N) : TILE_N);
                        for (int col = 0; col < TILE_N; col++) begin
                            if (col_base * TILE_N + col < P) begin
                                C[row_base][col_base * TILE_N + col] <=
                                    C[row_base][col_base * TILE_N + col] + tile_result[col];
                            end
                        end

                        if (k_base == K_TILES - 1) begin
                            k_base <= '0;
                            if (col_base == COL_TILES - 1) begin
                                col_base <= '0;
                                if (row_base == M - 1) begin
                                    state <= COMPLETE;
                                end else begin
                                    row_base <= row_base + 1'b1;
                                    state <= ISSUE;
                                end
                            end else begin
                                col_base <= col_base + 1'b1;
                                state <= ISSUE;
                            end
                        end else begin
                            k_base <= k_base + 1'b1;
                            state <= ISSUE;
                        end
                    end
                end

                COMPLETE: begin
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
