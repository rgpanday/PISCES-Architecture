`default_nettype none
`timescale 1ns/1ns

module warp_scheduler_v2 (
    input wire clk,
    input wire reset,
    input wire start_signal,
    
    // Status from the memory controller of THIS quadrant
    input wire local_hbm_ready, 
    
    // Output to the 1024 ALU's in THIS quadrant
    output reg [31:0] active_warp_mask, // Which of the  32 warps may NOW compute?
    output reg local_core_enable
);

    // the scheduler keeps up the status of all 32 local warps
    // 0 = ready/wait for the data, 1 = Ready to Execute
    reg [31:0] warp_ready_pool;
    reg [4:0]  current_warp_ptr; // points to the warp whose turn it is now (0 t/m 31)

    // simple hardware-finitestate-machine for Round-Robin scheduling
    always_ff @(posedge clk) begin
        if (reset) begin
            current_warp_ptr  <= 5'b0;
            active_warp_mask  <= 32'b0;
            local_core_enable <= 1'b0;
            warp_ready_pool   <= 32'hFFFFFFFF; // Starts with all warps ready
        end else if (start_signal) begin
            
            // LATENCY HIDING: if the local HBM-controller is busy with fetching data for the 
            // current warp, the scheduler puts that specific warp temporary at 'not ready'
            if (!local_hbm_ready) begin
                warp_ready_pool[current_warp_ptr] <= 1'b0; // Warp must wait
            end else begin
                warp_ready_pool[current_warp_ptr] <= 1'b1; // Data is here, warp may  again
            end

            // ROUND-ROBIN: search for the next available warp in the pool which HAS data
            // this happens in 1 clock cycle via a priority gear shift
            if (warp_ready_pool[(current_warp_ptr + 1) % 32]) begin
                current_warp_ptr <= (current_warp_ptr + 1) % 32;
                
                // Activate exactly the 32 ALU's belonging to this warp
                active_warp_mask <= (32'b1 << current_warp_ptr);
                local_core_enable <= 1'b1;
            end else begin
                // if ALL warps in this quadrant wait fot the data, pause all ALU's
                local_core_enable <= 1'b0;
            end
        end
    end

endmodule

