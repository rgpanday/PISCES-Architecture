`default_nettype none
`timescale 1ns/1ns

module flexible_register_file (
    input wire clk,
    input wire reset,
    input wire mode_64bit,          // 0 = 8x 8-bit registers, 1 = 1x 64-bit register
    
    // Register addresses (Suppose  we habe 4 registers per thread: R0, R1, R2, R3)
    input wire [1:0] read_reg_s,    // Address for RS
    input wire [1:0] read_reg_t,    // Address for RT
    input wire [1:0] write_reg,     // Address for the goal (ALU_OUT)
    input wire write_enable,        // can we write?

    // Data-ports to the Core and ALU's
    input wire [7:0] alu_out_data [0:7], // Data coming from the 8 ALU's
    output reg [7:0] rs_data [0:7],      // Data to the rs-inputs of the ALU's
    output reg [7:0] rt_data [0:7]       // Data to the rt-inputs of the ALU's
);

    // Physical storage: 8 slices (for the 8 threads). 
    // Eeach slice has 4 registers each 8 bits wide.
    reg [7:0] registers [0:7][0:3]; 

    // -------------------------------------------------------------------------
    // write-LOGIC ( data connections via Muxes)
    // -------------------------------------------------------------------------
    always_comb begin
        for (int i = 0; i < 8; i = i + 1) begin
            if (mode_64bit) begin
                // In 64-bit modus we ignore the thread-identity.
                // We take from the requested register (e.g. R1) áll 8 lices at once.
                rs_data[i] = registers[i][read_reg_s];
                rt_data[i] = registers[i][read_reg_t];
            end else begin
                // In 8-bit modus each ALU (thread i) reads purely from its own slice (i).
                rs_data[i] = registers[i][read_reg_s];
                rt_data[i] = registers[i][read_reg_t];
            end
            // *Note*: In the hardware-wiring these read action ra e mathem. identical,
            // but the data interpretation in the software changes completely !
        end
    end

    // -------------------------------------------------------------------------
    // write-LOGICs (On the clock flank)
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            // put all registers to zero at a reset 
            for (int t = 0; t < 8; t = t + 1) begin
                for (int r = 0; r < 4; r = r + 1) begin
                    registers[t][r] <= 8'b0;
                end
            end
        end else if (write_enable) begin
            for (int i = 0; i < 8; i = i + 1) begin
                if (mode_64bit) begin
                    // write the 64-bit output (distributed over 8 ALU's) 
                    // oat once over all 8  register slices.
                    registers[i][write_reg] <= alu_out_data[i];
                end else begin
                    // write only the data of the individual  active threads.
                    // (checken to the 'thread_enable')
                    registers[i][write_reg] <= alu_out_data[i];
                end
            end
        end
    end

endmodule

