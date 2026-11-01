`include "memory.sv"
`include "ws2812b.sv"
`include "controller.sv"
`include "game_of_life.sv"
`include "color.sv"

// game_of_life top level module

module top #(
    parameter SEED_FILE          = "seed/rpentomino.mem",
    parameter [11:0] IDLE_CYCLES = 12'd1204,
    parameter [23:0] GEN_CYCLES  = 24'd12_000_000
)(
    input logic clk, // 12MHz oscillator on iceBlinkPico
    output logic _48b // GPIO pin connected to LED matrix
);

    // off color for LED
    localparam [23:0] OFF_COLOR = 24'h00_00_00;
    
    // Seed memory signals
    logic [7:0] seed_data;       // row data read from seed memory
    logic [2:0] mem_row;         // row address for reading seed memory
    logic [2:0] gol_row;         // row address for writing into GoL grid

    // Game of Life signals
    logic gol_load;              // assert during seed loading
    logic gol_step;              // pulse to advance one generation
    logic [63:0] grid_flat;      // packed live game state from GoL module

    // Display signals
    logic [5:0] pixel;           // current LED (0-63)
    logic [23:0] shift_reg = 24'd0; // 24-bit color data in GRB format
    logic load_sreg;             // load shift register with new pixel color
    logic transmit_pixel;        // active during pixel transmission
    logic shift;                 // shift register left-shift signal
    logic ws2812b_out;           // serial waveform to LED matrix

    // color cycle LED
    logic [23:0] current_color;

    // Read cell directly from GoL register grid
    // pixel[5:3] = row, pixel[2:0] = column
    // grid_flat[row*8 + (7 - col)] since bit 7 = column 0 (leftmost)
    logic cell_alive;
    assign cell_alive = grid_flat[pixel[5:3] * 8 + (7 - pixel[2:0])];

    // Seed memory: loaded once at startup, provides initial grid state
    memory #(
        .INIT_FILE      (SEED_FILE)
    ) u_seed (
        .clk            (clk),
        .read_address   (mem_row),
        .read_data      (seed_data)
    );

    // Game of Life engine
    game_of_life u_gol (
        .clk            (clk), // (input) clock
        .load           (gol_load), // (input) 
        .step           (gol_step), // (input)
        .load_row       (gol_row), // (input)
        .load_data      (seed_data), // (input)
        .grid_flat      (grid_flat) // (output) flattened grid
    );

    // WS2812B output driver
    ws2812b u2 (
        .clk            (clk), // (input) clock
        .serial_in      (shift_reg[23]), // (input) MSB of the shift register
        .transmit       (transmit_pixel), // (input) transmit signal from controller
        .ws2812b_out    (ws2812b_out), // (output) generated signal for LED matrix
        .shift          (shift) // (output) signal to the shift register to perform a left shift
    );

    // Controller
    controller #(
        .IDLE_CYCLES    (IDLE_CYCLES),
        .GEN_CYCLES     (GEN_CYCLES)
    ) u3 (
        .clk            (clk), // (input) clock
        .load_sreg      (load_sreg), // (output) indicate a new value should be loaded into the shift register
        .transmit_pixel (transmit_pixel), // (output) indicate an active transmission of a pixel
        .pixel          (pixel), // (output) the current pixel (0-63)
        .gol_load       (gol_load), // (output) game of life load signal
        .gol_step       (gol_step), // (output) game of life step signal
        .gol_row        (gol_row), // (ouptut) game of life row
        .mem_row        (mem_row)  // (output) seed memory row
    );

    // Color generator
    color u4 (
        .clk            (clk), // (input) clock
        .current_color  (current_color) // (output) color
    );

    always_ff @(posedge clk) begin
        // If the signal to load new data into the shift register is active
        if (load_sreg) begin
            // off/black if dead, moderate brightness green if alive
            shift_reg <= cell_alive ? current_color : OFF_COLOR;
        end
        // If the signal to perform a left shift is active
        else if (shift) begin
            // left shift one value
            shift_reg <= { shift_reg[22:0], 1'b0 };
        end
    end

    // connect the output GPIO pin to the output led matrix signal
    assign _48b = ws2812b_out;

endmodule
