`default_nettype none
`timescale 1ns/1ns

module flexible_cla_alu (
    input wire [63:0] rs,           // Expanded to 64-bit for Funnel Shift support
    input wire [63:0] rt,           // Expanded to 64-bit for Funnel Shift support
    input wire [5:0]  shamt,        // Shift amount input (ranges from 0 to 63)
    input wire        carry_in,
    input wire [1:0]  op,
    output reg [63:0] alu_out_part, // Expanded to 64-bit vector lane
    output wire       gen_out,
    output wire       prop_out
);

    // Instruction Opcodes
    localparam FNSHFT = 2'b11;

    // Virtually concatenate the two 64-bit registers into a continuous 128-bit bitstream
    wire [127:0] combined_string = {rs, rt}; 

    // Carry-Lookahead Status Signals
    assign gen_out  = ((rs + rt) > 64'hFFFFFFFFFFFFFFFF);
    assign prop_out = ((rs + rt) == 64'hFFFFFFFFFFFFFFFF);

    always_comb begin
        // Default assignment to prevent accidental hardware latch generation
        alu_out_part = 64'b0;
        
        case (op)
            FNSHFT: begin
                // Generalized dynamic Funnel Shift execution for 64-bit vector plane
                alu_out_part = combined_string[(63 + shamt) -: 64]; 
                // INTUITION: By shifting the 128-bit window dynamically, the trailing bits 
                // of string 1 and leading bits of string 2 merge seamlessly in 1 clock cycle.
            end
            default: begin
                // Standard 64-bit fallback addition with zero-extended carry_in
                alu_out_part = rs + rt + {63'b0, carry_in};
            end
        endcase
    end

endmodule

