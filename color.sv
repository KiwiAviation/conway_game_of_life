module color #(
    parameter CLK_FREQ = 12000000,
    parameter TICKS_PER_CYCLE = CLK_FREQ / 6,
    parameter [7:0] BRIGHTNESS = 8'h40
)(
    input logic clk,
    output logic [23:0] current_color
);

    logic [23:0] count = 24'd0;

    // WS2812B 24-bit GRB format: {Green[7:0], Red[7:0], Blue[7:0]}
    localparam [23:0] RED     = { 8'h00,       BRIGHTNESS, 8'h00 };
    localparam [23:0] YELLOW  = { BRIGHTNESS,  BRIGHTNESS, 8'h00 };
    localparam [23:0] GREEN   = { BRIGHTNESS,  8'h00,      8'h00 };
    localparam [23:0] CYAN    = { BRIGHTNESS,  8'h00,      BRIGHTNESS };
    localparam [23:0] BLUE    = { 8'h00,       8'h00,      BRIGHTNESS };
    localparam [23:0] MAGENTA = { 8'h00,       BRIGHTNESS, BRIGHTNESS };

    initial begin
        current_color = RED;
    end

    always_ff @(posedge clk) begin
        if (count >= CLK_FREQ - 1) begin
            count <= 24'd0;
        end else begin
            count <= count + 24'd1;
        end

        if (count < (1 * TICKS_PER_CYCLE)) begin
            current_color <= RED;
        end
        else if (count < (2 * TICKS_PER_CYCLE)) begin
            current_color <= YELLOW;
        end
        else if (count < (3 * TICKS_PER_CYCLE)) begin
            current_color <= GREEN;
        end
        else if (count < (4 * TICKS_PER_CYCLE)) begin
            current_color <= CYAN;
        end
        else if (count < (5 * TICKS_PER_CYCLE)) begin
            current_color <= BLUE;
        end
        else begin
            current_color <= MAGENTA;
        end
    end

endmodule