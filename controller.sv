
module controller #(
    parameter [11:0] IDLE_CYCLES = 12'd1204,
    parameter [23:0] GEN_CYCLES  = 24'd12_000_000
)(
    input logic clk, 
    output logic load_sreg, 
    output logic transmit_pixel, 
    output logic [5:0] pixel,
    output logic gol_load,         // assert during seed loading
    output logic gol_step,         // pulse to advance one GoL generation
    output logic [2:0] gol_row,    // row being written into GoL
    output logic [2:0] mem_row     // row being read from seed memory
);

    // Main states
    localparam [1:0] LOAD_SEED      = 2'b00;
    localparam [1:0] TRANSMIT_FRAME = 2'b01;
    localparam [1:0] IDLE           = 2'b10;

    // Sub-states within TRANSMIT_FRAME
    localparam [2:0] READ_CH_VALS   = 3'b001;
    localparam [2:0] LOAD_SREG      = 3'b010;
    localparam [2:0] TRANSMIT_PIXEL = 3'b100;

    // Number of clock cycles needed to transmit one pixel. The WS2812B protocol specifies 24-bits of color data for each pixel. In the WS2812B implementation, we use 15 cycles for each bit. Therefore each of the 24 bits will require 15 cycles, giving the total number of cycles as: 24*15=360
    localparam [8:0] TRANSMIT_CYCLES = 9'd360;

    logic [1:0] state = LOAD_SEED;
    logic [1:0] next_state;

    logic [2:0] transmit_phase = READ_CH_VALS; // TRANSMIT_FRAME substate, start in READ_CH_VALS
    logic [2:0] next_transmit_phase;

    logic [5:0] pixel_counter = 6'd0;
    logic [8:0] transmit_counter = 9'd0;
    logic [11:0] idle_counter = 12'd0;
    logic [3:0] load_counter = 4'd0;      // counts 0-8 for pipelined seed loading
    logic [23:0] gen_counter = 24'd0;      // generation timer

    logic transmit_pixel_done;
    logic idle_done;
    logic load_done;
    logic gen_timer_done;

    assign transmit_pixel_done = (transmit_counter == TRANSMIT_CYCLES - 1);
    assign idle_done = (idle_counter == IDLE_CYCLES - 1);
    assign load_done = (load_counter == 4'd8);
    assign gen_timer_done = (gen_counter == GEN_CYCLES - 1);

    // State and phase update on negedge
    always_ff @(negedge clk) begin
        state <= next_state;
        transmit_phase <= next_transmit_phase;
    end

    // Next state logic
    always_comb begin
        next_state = state;
        unique case (state)
            LOAD_SEED:
                // After loading all 8 rows, begin displaying
                if (load_done)
                    next_state = TRANSMIT_FRAME;
            TRANSMIT_FRAME:
                // After all 64 pixels transmitted, go idle
                if ((pixel_counter == 6'd63) && (transmit_pixel_done))
                    next_state = IDLE;
            IDLE:
                // After idle period, start next frame
                if (idle_done)
                    next_state = TRANSMIT_FRAME;
            default:
                next_state = LOAD_SEED;
        endcase
    end

    // Transmit phase logic
    always_comb begin
        next_transmit_phase = READ_CH_VALS;
        if (state == TRANSMIT_FRAME) begin
            case (transmit_phase)
                READ_CH_VALS:
                    // Move to next state after a single cycle
                    next_transmit_phase = LOAD_SREG;
                LOAD_SREG:
                    // Move to next state after a single cycle
                    next_transmit_phase = TRANSMIT_PIXEL;
                TRANSMIT_PIXEL:
                    // Move back to READ_CH_VALS once transmitting pixel is complete
                    next_transmit_phase = transmit_pixel_done ? READ_CH_VALS : TRANSMIT_PIXEL;
            endcase
        end
    end

    // Load counter: cycles through rows 0-7 during LOAD_SEED
    always_ff @(negedge clk) begin
        if (state == LOAD_SEED) begin
            load_counter <= load_counter + 1;
        end
    end

    // Pixel counter
    always_ff @(negedge clk) begin
        if ((state == TRANSMIT_FRAME) && transmit_pixel_done) begin
            pixel_counter <= pixel_counter + 1;
        end
    end

    // Increment the transmit counter
    always_ff @(negedge clk) begin
        if (transmit_phase == TRANSMIT_PIXEL) begin
            transmit_counter <= transmit_counter + 1;
        end
        else begin
            transmit_counter <= 9'd0;
        end
    end

    // Increment the idle counter
    always_ff @(negedge clk) begin
        if (state == IDLE) begin
            idle_counter <= idle_counter + 1;
        end
        else begin
            idle_counter <= 12'd0;
        end
    end

    // Generation timer: counts continuously, pulses step once per second
    always_ff @(negedge clk) begin
        if (state == LOAD_SEED) begin
            gen_counter <= 24'd0;
        end
        else if (gen_timer_done) begin
            gen_counter <= 24'd0;
        end
        else begin
            gen_counter <= gen_counter + 1;
        end
    end

    // Output assignments
    assign pixel = pixel_counter;
    assign mem_row  = (load_counter < 4'd8) ? load_counter[2:0] : 3'd0;
    assign gol_row  = (load_counter > 4'd0) ? (load_counter[2:0] - 3'd1) : 3'd0;
    assign gol_load = (state == LOAD_SEED) && (load_counter >= 4'd1) && (load_counter <= 4'd8);
    assign gol_step = gen_timer_done && (state != LOAD_SEED);

    assign load_sreg = (transmit_phase == LOAD_SREG);
    assign transmit_pixel = (transmit_phase == TRANSMIT_PIXEL);

endmodule
