module game_of_life (
    input logic clk,
    input logic load, // assert to load a row from seed memory
    input logic step, // pulse to advance one generation
    input logic [2:0] load_row, // which row to load (0-7)
    input logic [7:0] load_data, // seed data for that row
    output logic [63:0] grid_flat // live game state, packed: grid_flat[row*8 +: 8]
);

    // Internal unpacked grid and next-generation state
    logic [7:0] grid [0:7];
    logic [7:0] next_grid [0:7];

    // Pack grid into flat output for port compatibility
    assign grid_flat = {grid[7], grid[6], grid[5], grid[4],
                        grid[3], grid[2], grid[1], grid[0]};

    // Compute next generation for all 64 cells
    // For loops are unrolled at synthesis time, producing the same
    // parallel combinational logic as a generate block would
    integer r, c;
    logic [3:0] count;

    always_comb begin
        for (r = 0; r < 8; r++) begin
            for (c = 0; c < 8; c++) begin
                // Count the 8 neighbors using cyclic boundary conditions
                // (r+7)%8 wraps row above, (r+1)%8 wraps row below, same for columns
                count = grid[(r+7)%8][(c+7)%8] + grid[(r+7)%8][c] + grid[(r+7)%8][(c+1)%8]
                      + grid[r][(c+7)%8]                           + grid[r][(c+1)%8]
                      + grid[(r+1)%8][(c+7)%8] + grid[(r+1)%8][c] + grid[(r+1)%8][(c+1)%8];

                // Conway's rules:
                //   alive if exactly 3 neighbors (born or survives)
                //   alive if exactly 2 neighbors AND currently alive (survives)
                //   dead otherwise
                next_grid[r][c] = (count == 4'd3) || (count == 4'd2 && grid[r][c]);
            end
        end
    end

    // Load seed or step to next generation
    always_ff @(posedge clk) begin
        if (load) begin
            grid[load_row] <= load_data;
        end
        else if (step) begin
            grid[0] <= next_grid[0];
            grid[1] <= next_grid[1];
            grid[2] <= next_grid[2];
            grid[3] <= next_grid[3];
            grid[4] <= next_grid[4];
            grid[5] <= next_grid[5];
            grid[6] <= next_grid[6];
            grid[7] <= next_grid[7];
        end
    end

endmodule