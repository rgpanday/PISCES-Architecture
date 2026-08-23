`default_nettype none
`timescale 1ns/1ns

module gpu_top #(
    parameter int NUM_CORES = 2,
    parameter int ALUS_PER_CORE = 4
)(
    input wire clk,
    input wire reset,
    input wire [1023:0] vram_bus_data
);

    // Forceer de vectorbreedte hard op de V3 256-bit standaard (4 * 64)
    localparam int VECTOR_WIDTH = 256;

    wire         mode_64bit = 1'b0;
    wire [1:0]   decoded_mux = 2'b00;
    
    wire [255:0] alu_rs;
    wire [255:0] alu_rt;
    wire [255:0] alu_out;

    // Trek veilig 256 bits uit de brede 1024-bit HBM snelweg
    assign alu_rs = vram_bus_data[255:0];
    assign alu_rt = vram_bus_data[511:256];

    genvar c;
    generate
        for (c = 0; c < NUM_CORES; c = c + 1) begin : core_instantiation_block
            
            core independent_sm (
                .clk(clk),
                .reset(reset),
                .mode_64bit(mode_64bit),
                .decoded_alu_arithmetic_mux(decoded_mux),
                .alu_rs_data(alu_rs),
                .alu_rt_data(alu_rt),
                .alu_out_data(alu_out)
            );
            
        end
    endgenerate

endmodule

