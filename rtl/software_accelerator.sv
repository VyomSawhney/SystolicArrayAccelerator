`timescale 1ns / 1ps

module software_accelerator #(
    parameter int M = 3,
    parameter int K = 5,
    parameter int P = 4,
    parameter int TILE_N = 2,
    parameter int DATA_W = 16,
    parameter int ACC_W = 2 * DATA_W + $clog2((K < 2) ? 2 : K),
    parameter int ADDR_W = 4
) (
    input logic clk,
    input logic rst_n,

    input logic [ADDR_W-1:0] avs_address,
    input logic avs_write,
    input logic avs_read,
    input logic [31:0] avs_writedata,
    output logic [31:0] avs_readdata,

    input logic dma_in_valid,
    output logic dma_in_ready,
    input logic signed [DATA_W-1:0] dma_in_data,
    input logic dma_out_ready,
    output logic dma_out_valid,
    output logic dma_out_last,
    output logic signed [ACC_W-1:0] dma_out_data
);
    localparam int A_WORDS = M * K;
    localparam int B_WORDS = K * P;
    localparam int C_WORDS = M * P;
    localparam int A_COUNT_W = $clog2((A_WORDS < 2) ? 2 : A_WORDS);
    localparam int B_COUNT_W = $clog2((B_WORDS < 2) ? 2 : B_WORDS);
    localparam int C_COUNT_W = $clog2((C_WORDS < 2) ? 2 : C_WORDS);
    localparam int OUT_COUNT_W = $clog2((C_WORDS < 2) ? 2 : C_WORDS);
    localparam int COUNT_W = $clog2(
        ((M * ((P + TILE_N - 1) / TILE_N) * ((K + TILE_N - 1) / TILE_N)
        * (3 * TILE_N + 8)) < 2) ? 2 :
        (M * ((P + TILE_N - 1) / TILE_N) * ((K + TILE_N - 1) / TILE_N)
        * (3 * TILE_N + 8) + 1));

    localparam logic [ADDR_W-1:0] REG_CONTROL = 'h0;
    localparam logic [ADDR_W-1:0] REG_STATUS = 'h1;
    localparam logic [ADDR_W-1:0] REG_DIMS = 'h2;
    localparam logic [ADDR_W-1:0] REG_CYCLES = 'h3;
    localparam logic [ADDR_W-1:0] REG_MACS = 'h4;
    localparam logic [ADDR_W-1:0] REG_DMA_MODE = 'h5;
    localparam logic [ADDR_W-1:0] REG_DMA_DATA_IN = 'h6;
    localparam logic [ADDR_W-1:0] REG_DMA_DATA_OUT = 'h7;
    localparam logic [ADDR_W-1:0] REG_DMA_DATA_OUT_HI = 'h8;

    typedef enum logic [1:0] {DMA_IDLE, DMA_LOAD_A, DMA_LOAD_B, DMA_OUTPUT} dma_state_t;
    dma_state_t dma_state;

    logic signed [DATA_W-1:0] a_buffer [M][K];
    logic signed [DATA_W-1:0] b_buffer [K][P];
    logic signed [ACC_W-1:0] c_buffer [M][P];
    logic signed [ACC_W-1:0] c_flat [C_WORDS];

    logic compute_start;
    logic compute_busy;
    logic compute_done;
    logic [31:0] compute_cycles;
    logic [31:0] compute_macs;
    logic [COUNT_W-1:0] engine_cycles;
    logic [COUNT_W-1:0] engine_macs;
    logic compute_done_seen;
    logic [A_COUNT_W-1:0] a_index;
    logic [B_COUNT_W-1:0] b_index;
    logic [OUT_COUNT_W-1:0] out_index;
    logic bus_in_valid;
    logic signed [DATA_W-1:0] bus_in_data;
    logic bus_out_ready;
    logic dma_in_valid_int;
    logic signed [DATA_W-1:0] dma_in_data_int;
    logic dma_out_ready_int;

    assign dma_in_ready = (dma_state == DMA_LOAD_A) || (dma_state == DMA_LOAD_B);
    assign dma_out_valid = (dma_state == DMA_OUTPUT);
    assign dma_out_last = dma_out_valid && (out_index == C_WORDS - 1);
    assign dma_out_data = c_flat[out_index];
    assign dma_in_valid_int = dma_in_valid || bus_in_valid;
    assign dma_in_data_int = bus_in_valid ? bus_in_data : dma_in_data;
    assign bus_out_ready = avs_read && (avs_address == REG_DMA_DATA_OUT_HI);
    assign dma_out_ready_int = dma_out_ready || bus_out_ready;

    always_comb begin
        avs_readdata = '0;
        if (avs_read) begin
            case (avs_address)
                REG_STATUS: begin
                    avs_readdata[0] = compute_busy;
                    avs_readdata[1] = compute_done_seen;
                    avs_readdata[2] = (dma_state == DMA_LOAD_A);
                    avs_readdata[3] = (dma_state == DMA_LOAD_B);
                    avs_readdata[4] = dma_out_valid;
                end
                REG_DIMS: begin
                    avs_readdata[7:0] = M;
                    avs_readdata[15:8] = K;
                    avs_readdata[23:16] = P;
                    avs_readdata[31:24] = TILE_N;
                end
                REG_CYCLES: avs_readdata = compute_cycles;
                REG_MACS: avs_readdata = compute_macs;
                REG_DMA_MODE: avs_readdata = dma_state;
                REG_DMA_DATA_OUT: avs_readdata = dma_out_data[31:0];
                REG_DMA_DATA_OUT_HI: begin
                    avs_readdata = '0;
                    avs_readdata[ACC_W-32-1:0] = dma_out_data[ACC_W-1:32];
                end
                default: avs_readdata = '0;
            endcase
        end
    end

    tiled_gemm #(
        .M(M), .K(K), .P(P), .TILE_N(TILE_N),
        .DATA_W(DATA_W), .ACC_W(ACC_W)
    ) compute_engine (
        .clk(clk),
        .rst_n(rst_n),
        .start(compute_start),
        .A(a_buffer),
        .B(b_buffer),
        .C(c_buffer),
        .busy(compute_busy),
        .done(compute_done),
        .cycle_count(engine_cycles),
        .active_mac_count(engine_macs)
    );

    assign compute_cycles = engine_cycles;
    assign compute_macs = engine_macs;

    always_comb begin
        for (int row = 0; row < M; row++) begin
            for (int col = 0; col < P; col++) begin
                c_flat[row * P + col] = c_buffer[row][col];
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dma_state <= DMA_IDLE;
            compute_start <= 1'b0;
            compute_done_seen <= 1'b0;
            a_index <= '0;
            b_index <= '0;
            out_index <= '0;
            bus_in_valid <= 1'b0;
            bus_in_data <= '0;
        end else begin
            compute_start <= 1'b0;
            bus_in_valid <= 1'b0;

            if (avs_write && avs_address == REG_DMA_DATA_IN) begin
                bus_in_valid <= 1'b1;
                bus_in_data <= avs_writedata[DATA_W-1:0];
            end

            if (avs_write && avs_address == REG_CONTROL) begin
                if (avs_writedata[1]) begin
                    compute_done_seen <= 1'b0;
                    out_index <= '0;
                end
                if (avs_writedata[0] && !compute_busy &&
                    dma_state == DMA_IDLE) begin
                    compute_start <= 1'b1;
                    compute_done_seen <= 1'b0;
                end
            end

            if (avs_write && avs_address == REG_DMA_MODE) begin
                case (avs_writedata[1:0])
                    2'd1: begin
                        dma_state <= DMA_LOAD_A;
                        a_index <= '0;
                    end
                    2'd2: begin
                        dma_state <= DMA_LOAD_B;
                        b_index <= '0;
                    end
                    2'd3: begin
                        dma_state <= DMA_OUTPUT;
                        out_index <= '0;
                    end
                    default: dma_state <= DMA_IDLE;
                endcase
            end

            if (dma_state == DMA_LOAD_A && dma_in_valid_int) begin
                a_buffer[a_index / K][a_index % K] <= dma_in_data_int;
                if (a_index == A_WORDS - 1) begin
                    dma_state <= DMA_IDLE;
                end else begin
                    a_index <= a_index + 1'b1;
                end
            end

            if (dma_state == DMA_LOAD_B && dma_in_valid_int) begin
                b_buffer[b_index / P][b_index % P] <= dma_in_data_int;
                if (b_index == B_WORDS - 1) begin
                    dma_state <= DMA_IDLE;
                end else begin
                    b_index <= b_index + 1'b1;
                end
            end

            if (compute_done) begin
                compute_done_seen <= 1'b1;
            end

            if (dma_state == DMA_OUTPUT && dma_out_ready_int) begin
                if (out_index == C_WORDS - 1) begin
                    dma_state <= DMA_IDLE;
                end else begin
                    out_index <= out_index + 1'b1;
                end
            end
        end
    end
endmodule
