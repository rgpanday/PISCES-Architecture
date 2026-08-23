`default_nettype none
`timescale 1ns/1ns

module core (
    input wire         clk,
    input wire         reset,
    input wire         mode_64bit,
    input wire [1:0]   decoded_alu_arithmetic_mux,
    
    // 256-bit vectors (32 threads * 8 bits)
    input wire [255:0] alu_rs_data,
    input wire [255:0] alu_rt_data,
    output wire [255:0] alu_out_data
);

    // Intern signals for the Carry-Lookahead chain between the  ALU-blocks
    // We need 4 blocks of 64-bit to reach  256-bit 
    wire [3:0] G; 
    wire [3:0] P; 
    wire [4:0] alu_carries; 

    assign alu_carries[0] = 1'b0; // 1st carry-in is always 0
    
    // Ultrasnelle Carry-Lookahead logica over de bussen heen
    assign alu_carries[1] = mode_64bit ? (G[0] | (P[0] & alu_carries[0])) : 1'b0;
    assign alu_carries[2] = mode_64bit ? (G[1] | (P[1] & alu_carries[1])) : 1'b0;
    assign alu_carries[3] = mode_64bit ? (G[2] | (P[2] & alu_carries[2])) : 1'b0;
    assign alu_carries[4] = mode_64bit ? (G[3] | (P[3] & alu_carries[3])) : 1'b0;

    // -------------------------------------------------------------------------
    // GENERATE LUS: Slices from 256-bit vector for the 4x 64-bit ALU's
    // -------------------------------------------------------------------------
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : cla_alu_array
            
            // We cut the 256-bit bus in exactly 4 pieces of 64 bits [i*64 +: 64]
            flexible_cla_alu inst_alu (
                .rs(alu_rs_data[(i*64) +: 64]),
                .rt(alu_rt_data[(i*64) +: 64]),
                .shamt(6'd5), // Standard shift-amount for the FNSHFT modus
                .carry_in(alu_carries[i]),
                .op(decoded_alu_arithmetic_mux),
                
                .alu_out_part(alu_out_data[(i*64) +: 64]),
                
                .gen_out(G[i]),
                .prop_out(P[i])
            );
            
        end
    endgenerate

endmodule

