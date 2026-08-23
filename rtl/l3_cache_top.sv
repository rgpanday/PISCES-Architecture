`default_nettype none
`timescale 1ns/1ns

module l3_cache_top (
    input wire [21:0] bus_address,     // 22 bits is enough to adress the 4MB
    input wire bus_read_req,
    input wire bus_write_req,
    input wire is_sparc_core,          // 1 if SPARC uses the bus, 0 if the GPU does this

    // Chip Select signals to the four physical SRAM-memory blocks
    output reg cs_cpu_code,
    output reg cs_cpu_data,
    output reg cs_gpu_input,
    output reg cs_gpu_output,
    
    // security signal
    output reg access_violation         // jumps if there is an illegal memory use 
);

    always_comb begin
        // Standard everything is off
        cs_cpu_code      = 1'b0;
        cs_cpu_data      = 1'b0;
        cs_gpu_input     = 1'b0;
        cs_gpu_output    = 1'b0;
        access_violation = 1'b0;

        // Evaluate the  address zones on basis of the  Memory Map
        if (bus_address >= 22'h000000 && bus_address <= 22'h07FFFF) begin
            // ZONE 1: CPU Code
            cs_cpu_code = bus_read_req || bus_write_req;
            
            // secuity: the GPU should never come in the code of the CPU. 
            // and the CPU cannot overwrite its own code during runtime (Read-Only).
            if (!is_sparc_core || bus_write_req) begin
                access_violation = 1'b1;
            end
        end 
        else if (bus_address >= 22'h080000 && bus_address <= 22'h0FFFFF) begin
            // ZONE 2: CPU Privé Work memory
            cs_cpu_data = bus_read_req || bus_write_req;
            
            // security: the GPU should not be here .
            if (!is_sparc_core) begin
                access_violation = 1'b1;
            end
        end 
        else if (bus_address >= 22'h100000 && bus_address <= 22'h1FFFFF) begin
            // ZONE 3: shared GPU Input Buffer
            cs_gpu_input = bus_read_req || bus_write_req;
            // both CPU and GPU here have free pasaage to the matrices
        end 
        else if (bus_address >= 22'h200000 && bus_address <= 22'h3FFFFF) begin
            // ZONE 4: shared GPU Output Buffer
            cs_gpu_output = bus_read_req || bus_write_req;
            // both CPU and GPU here have free pasaage to the results
        end
    end

endmodule

