module accelerator_benchmark_top (
    input  logic        CLOCK_50,
    input  logic        RESET_N,
    output logic [63:0] benchmark_checksum,
    output logic        benchmark_done
);
`ifdef BENCH_N
    localparam int N = `BENCH_N;
`else
    localparam int N = 2;
`endif
    localparam int DATA_W = 16;
    localparam int ACC_W = 2 * DATA_W + $clog2(N);
    localparam int PERIOD = 2 * N + 8;
    localparam int PHASE_W = (PERIOD <= 2) ? 1 : $clog2(PERIOD);

    logic [PHASE_W-1:0] phase;
    logic [31:0] lfsr;
    logic start;
    logic done;
    logic signed [DATA_W-1:0] weight [N][N];
    logic signed [DATA_W-1:0] A_in [N];
    logic signed [ACC_W-1:0] out [N];
    logic signed [ACC_W-1:0] out_mix;

    assign start = (phase == '0);
    assign benchmark_done = done;

    always_comb begin
        for (int row = 0; row < N; row++) begin
            for (int col = 0; col < N; col++) begin
                weight[row][col] = $signed(lfsr[DATA_W-1:0]) + row + col;
            end
        end
        for (int lane = 0; lane < N; lane++) begin
            A_in[lane] = $signed(lfsr[DATA_W-1:0]) + lane + phase;
        end

        out_mix = '0;
        for (int lane = 0; lane < N; lane++) begin
            out_mix = out_mix ^ out[lane];
        end
    end

    always_ff @(posedge CLOCK_50 or negedge RESET_N) begin
        if (!RESET_N) begin
            phase <= '0;
            lfsr <= 32'h1;
            benchmark_checksum <= '0;
        end else begin
            if (phase == PERIOD - 1) begin
                phase <= '0;
            end else begin
                phase <= phase + 1'b1;
            end

            lfsr <= {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};
            benchmark_checksum <= benchmark_checksum ^ {{(64-ACC_W){out_mix[ACC_W-1]}}, out_mix} ^ phase;
        end
    end

    accelerator #(
        .N(N),
        .DATA_W(DATA_W),
        .ACC_W(ACC_W)
    ) dut (
        .clk(CLOCK_50),
        .rst_n(RESET_N),
        .start(start),
        .weight(weight),
        .A_in(A_in),
        .done(done),
        .out(out)
    );
endmodule
