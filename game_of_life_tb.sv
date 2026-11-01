`timescale 1ns/1ps
`include "top.sv"

module game_of_life_tb;

    parameter CLK_PERIOD_NS = 83.333; // 12 MHz clock period

    // For simulation: advance GoL generation every frame (~24,372 clock cycles)
    // rather than waiting the hardware default of 12,000,000 cycles (1 second)
    parameter GEN_CYCLES  = 24'd24372;
    parameter IDLE_CYCLES = 12'd1204;
    parameter SEED_FILE   = "seed/glider.mem";

    logic clk = 0;
    logic _48b;

    // Instantiate Top-level Module directly
    top #(
        .SEED_FILE   (SEED_FILE),
        .IDLE_CYCLES (IDLE_CYCLES),
        .GEN_CYCLES  (GEN_CYCLES)
    ) u0 (
        .clk  (clk),
        ._48b (_48b)
    );

    // Break out individual rows (0-7)
    wire [7:0] row0 = u0.grid_flat[7:0];
    wire [7:0] row1 = u0.grid_flat[15:8];
    wire [7:0] row2 = u0.grid_flat[23:16];
    wire [7:0] row3 = u0.grid_flat[31:24];
    wire [7:0] row4 = u0.grid_flat[39:32];
    wire [7:0] row5 = u0.grid_flat[47:40];
    wire [7:0] row6 = u0.grid_flat[55:48];
    wire [7:0] row7 = u0.grid_flat[63:56];

    // 12 MHz clock generation
    always #(CLK_PERIOD_NS / 2.0) clk = ~clk;

    initial begin
        $dumpfile("game_of_life.vcd");
        $dumpvars(0, game_of_life_tb);

        // Wait for seed loading to complete
        @(posedge u0.gol_load); // Wait for loading to start
        @(negedge u0.gol_load); // Wait for loading to finish
        @(posedge clk);         // Allow last row to latch

        for (int gen = 1; gen <= 3; gen++) begin
            @(posedge u0.gol_step);
            @(negedge clk);
            @(posedge clk); // Allow register update
        end
        #500000;
        $finish;
    end

endmodule
