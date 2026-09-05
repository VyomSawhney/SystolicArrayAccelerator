module de1_soc_top (
    input  logic       CLOCK_50,
    input  logic [3:0] KEY,
    output logic [9:0] LEDR
);
    localparam int N = 2;
    localparam int DATA_W = 16;
    localparam int ACC_W = 2 * DATA_W + $clog2(N);

    logic rst_n;
    logic start;
    logic start_seen;
    logic [3:0] demo_cycle;
    logic signed [DATA_W-1:0] weight [N][N];
    logic signed [DATA_W-1:0] A_in [N];
    logic done;
    logic signed [ACC_W-1:0] out [N];

    assign rst_n = KEY[0];

    // Convert the active-low pushbutton into a one-cycle start pulse.
    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            start_seen <= 1'b0;
            demo_cycle <= '0;
        end else begin
            if (!KEY[1] && !start_seen) begin
                start_seen <= 1'b1;
                demo_cycle <= '0;
            end else begin
                start_seen <= KEY[1] ? 1'b0 : start_seen;
                if (demo_cycle < 4'd7)
                    demo_cycle <= demo_cycle + 1'b1;
            end
        end
    end

    assign start = !KEY[1] && !start_seen;

    assign weight[0][0] = 16'sd1;
    assign weight[0][1] = 16'sd2;
    assign weight[1][0] = 16'sd3;
    assign weight[1][1] = 16'sd4;
    // Demonstration activation matrix: [1 2; 3 4], followed by drain zeros.
    assign A_in[0] = (demo_cycle < 4'd3) ? 16'sd1 :
                     (demo_cycle == 4'd3) ? 16'sd3 : '0;
    assign A_in[1] = (demo_cycle < 4'd3) ? 16'sd2 :
                     (demo_cycle == 4'd3) ? 16'sd4 : '0;

    accelerator #(
        .N(N),
        .DATA_W(DATA_W),
        .ACC_W(ACC_W)
    ) dut (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .start(start),
        .weight(weight),
        .A_in(A_in),
        .done(done),
        .out(out)
    );

    assign LEDR[0] = done;
    assign LEDR[9:1] = out[0][8:0];
endmodule
