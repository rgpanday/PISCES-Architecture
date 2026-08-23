`default_nettype none
`timescale 1ns/1ns

// BEHAVIORELE STUB VOOR DE SPARC CPU (64-BIT HOST)
module sparc_core (
    input wire clk,
    input wire reset,

    // Besturingslijnen naar de Smart DMA (Memory-Mapped IO)
    output reg dma_trigger,
    output reg [31:0] dma_src_addr,
    output reg [31:0] dma_dest_addr,
    input wire dma_busy
);

    // Simpele state machine om de acties van het OS na te bootsen
    typedef enum reg [1:0] {
        CPU_RESET = 2'b00,
        CPU_IDLE  = 2'b01,
        CPU_LAUNCH_GPU = 2'b10,
        CPU_WAIT       = 2'b11
    } cpu_state_t;

    cpu_state_t current_state;

    always_ff @(posedge clk) begin
        if (reset) begin
            current_state <= CPU_RESET;
            dma_trigger   <= 1'b0;
            dma_src_addr  <= 32'h0;
            dma_dest_addr <= 32'h0;
        end else begin
            case (current_state)
                CPU_RESET: begin
                    current_state <= CPU_IDLE;
                end

                CPU_IDLE: begin
                    // Nabootsen van C-code: Bereid een 256-bit matrix-transformatie voor
                    dma_src_addr  <= 32'h10000000; // Startlocatie Matrix in HBM
                    dma_dest_addr <= 32'h00400000; // Doellocatie in L3 Cache (Zone 3)
                    dma_trigger   <= 1'b1;         // Trek aan de deurbel van de DMA!
                    current_state <= CPU_LAUNCH_GPU;
                end

                CPU_LAUNCH_GPU: begin
                    dma_trigger   <= 1'b0; // Deurbelsignaal direct weer laten vallen
                    current_state <= CPU_WAIT;
                end

                CPU_WAIT: begin
                    if (!dma_busy) begin
                        // De DMA heeft de data verplaatst, de GPU-kwadranten rekenen nu parallel!
                        // De CPU is klaar met zijn host-taak voor deze run.
                        current_state <= CPU_IDLE; 
                    end
                end
            endcase
        end
    end

endmodule

