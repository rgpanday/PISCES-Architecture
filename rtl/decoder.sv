`default_nettype none
`timescale 1ns/1ns

module flexible_decoder (
    // We get a fixed 32-bit RISC-instruction from program-memory
    input wire [31:0] instruction,

    // Besturingssignalen naar de Register File
    output reg [1:0] read_reg_s, // Adress van 1st source register
    output reg [1:0] read_reg_t, // Adress van 2nd source register
    output reg [1:0] write_reg,  // Adres of target register
    output reg write_enable,

    // control signals to  Core % ALU's
    output reg mode_64bit,               
    output reg [1:0] decoded_alu_arithmetic_mux
);

    // RISC-instructions are divided into fixed fields' (bit-ranges)
    // example of our  format:
    // Bits [31:26] -> Opcode (Welke instructie?)
    // Bits [25:24] -> Destination Register (write_reg)
    // Bits [23:22] -> Source Register 1 (read_reg_s)
    // Bits [21:20] -> Source Register 2 (read_reg_t)
    // Bits [19:0]  -> Not used for  ALU (or for immediates)

    wire [5:0] opcode = instruction[31:26];

    always_comb begin
        // Standaardwaarden (to prevent hardware-latches)
        write_enable               = 1'b0;
        mode_64bit                 = 1'b0; // Standaard 8-bit modus
        decoded_alu_arithmetic_mux = 2'b00;
        
        // cut  register-adresses  
        write_reg  = instruction[25:24];
        read_reg_s = instruction[23:22];
        read_reg_t = instruction[21:20];

        case (opcode)
            // -----------------------------------------------------------------
            // STANDARD 8-BIT INSTRUCTIONS (GPU Modus - 8 parallell threads)
            // -----------------------------------------------------------------
            6'b000001: begin // ADD (8-bit)
                write_enable               = 1'b1;
                mode_64bit                 = 1'b0; // 8-bit
                decoded_alu_arithmetic_mux = 2'b00; // ADD code
            end
            6'b000010: begin // SUB (8-bit)
                write_enable               = 1'b1;
                mode_64bit                 = 1'b0; // 8-bit
                decoded_alu_arithmetic_mux = 2'b01; // SUB code
            end

            // -----------------------------------------------------------------
            // NEW 64-BIT INSTRUCTIES (Vector/CPU Modus - 1 large thread)
            // -----------------------------------------------------------------
            6'b001001: begin // ADD64 (New!)
                write_enable               = 1'b1;
                mode_64bit                 = 1'b1; // switch on the Carry-Lookahead chain!
                decoded_alu_arithmetic_mux = 2'b00; // reuse the ADD logic
            end
            6'b001010: begin // SUB64 (Nieuw!)
                write_enable               = 1'b1;
                mode_64bit                 = 1'b1; // switch on the Carry-Lookahead chain!
                decoded_alu_arithmetic_mux = 2'b01; // reuse the SUB logic
            end

            default: begin
                // Andere instructies zoals LOAD, STORE, BRANCH, etc.
                write_enable = 1'b0;
            end
        endcase
    end

endmodule

