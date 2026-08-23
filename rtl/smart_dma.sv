`default_nettype none
`timescale 1ns/1ns

module smart_dma #(
    parameter int HBM_BUS_WIDTH = 1024,
    parameter int ADDR_WIDTH = 32
)(
    input wire clk,
    input wire reset,

    // Interface with Host SPARC CPU (Memory-Mapped IO Control Registers)
    input wire dma_trigger,               // Asserted by CPU to start the transfer loop
    input wire [ADDR_WIDTH-1:0] src_addr,  // Source start address in physical HBM space
    input wire [ADDR_WIDTH-1:0] dest_addr, // Target destination address in Shared L3 Cache
    input wire [15:0] transfer_size,      // Total number of 1024-bit blocks to fetch
    output reg dma_busy,                  // Asserted while data pump is active

    // Interface with the 4 External HBM Memory Controllers
    output reg [ADDR_WIDTH-1:0] hbm_read_addr,
    output reg hbm_read_req,
    input wire [HBM_BUS_WIDTH-1:0] hbm_data_in,
    input wire hbm_ready,

    // Interface with the Central 16MB Shared L3 Cache
    output reg [ADDR_WIDTH-1:0] l3_write_addr,
    output reg l3_write_req,
    output reg [HBM_BUS_WIDTH-1:0] l3_data_out
);

    // Finite State Machine (FSM) Declarations
    typedef enum reg [1:0] {
        DMA_IDLE   = 2'b00,
        DMA_FETCH  = 2'b01, // Fetch data packet from HBM stack
        DMA_PIPE   = 2'b10, // Pipeline data directly into L3 (Double Buffering)
        DMA_DONE   = 2'b11
    } dma_state_t;

    dma_state_t current_state, next_state;
    reg [15:0] block_counter;
    reg [HBM_BUS_WIDTH-1:0] internal_buffer; // Internal 1024-bit staging flip-flop row

    // -------------------------------------------------------------------------
    // FSM Control Loop: Autonomous Memory Pipeline Controller
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            current_state   <= DMA_IDLE;
            block_counter   <= 16'b0;
            dma_busy        <= 1'b0;
            hbm_read_req    <= 1'b0;
            l3_write_req    <= 1'b0;
        end else begin
            current_state <= next_state;

            case (current_state)
                DMA_IDLE: begin
                    dma_busy      <= 1'b0;
                    block_counter <= 16'b0;
                    if (dma_trigger) begin
                        dma_busy   <= 1'b1;
                        next_state <= DMA_FETCH;
                    end
                end

                DMA_FETCH: begin
                    // Command the local HBM Controller to execute a Burst Mode Read
                    hbm_read_req  <= 1'b1;
                    hbm_read_addr <= src_addr + (block_counter * 4); // Increment address per block offset
                    
                    if (hbm_ready) begin
                        internal_buffer <= hbm_data_in; // Capture the incoming 1024-bit packet
                        hbm_read_req    <= 1'b0;
                        next_state      <= DMA_PIPE;
                    end
                end

                DMA_PIPE: begin
                    // Flush the captured 1024-bit matrix segment instantly into the L3 Cache
                    l3_write_req  <= 1'b1;
                    l3_write_addr <= dest_addr + (block_counter * 4);
                    l3_data_out   <= internal_buffer;

                    l3_write_req  <= 1'b0; // Immediately deassert to prepare for next cycle
                    block_counter <= block_counter + 1;

                    // Evaluate if the multi-megabyte matrix block transfer is finalized
                    if (block_counter >= transfer_size) begin
                        next_state <= DMA_DONE;
                    end else begin
                        next_state <= DMA_FETCH; // Re-trigger next sequential fetch (Double Buffering)
                    end
                end

                DMA_DONE: begin
                    dma_busy   <= 1'b0;
                    next_state <= DMA_IDLE; // Reset and wait for the next CPU command signal
                end
            endcase
        end
    end

endmodule

