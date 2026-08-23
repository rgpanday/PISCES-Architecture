`default_nettype none
`timescale 1ns/1ns

module absolute_chip_top (
    input wire clk,
    input wire reset
); 

    // =========================================================================
    // 1. SYSTEM INTERCONNECT BUS DEFINITIONS (256-BIT SYMMETRY PLANE)
    // =========================================================================
    wire          cpu_dma_trigger;
    wire [31:0]   cpu_dma_src;
    wire [31:0]   cpu_dma_dest;
    wire          dma_system_busy;
    wire          hbm_global_ready;
    wire [1023:0] hbm_global_bus;
    wire [1023:0] l3_global_bus;

    // Auxiliary intercept routing to safeguard empty ports from linter warnings
    wire [31:0] dma_hbm_raddr;
    wire        dma_hbm_rreq;
    wire [31:0] dma_l3_waddr;
    wire        dma_l3_wreq;

    // Interconnect lines mapping to the Central Crossbar / NoC Memory Decoder
    wire [21:0]  l3_dec_addr      = cpu_dma_dest[21:0]; // Slice address boundaries
    wire         l3_dec_read_req  = 1'b0;
    wire         l3_dec_write_req = cpu_dma_trigger;
    wire         l3_dec_is_sparc  = 1'b1;
    wire         cs_code, cs_data, cs_in, cs_out, violation;

    // Static logic anchoring for stable open-bus simulation runs
    assign hbm_global_ready = 1'b1;
    assign hbm_global_bus   = 1024'b0;

    // =========================================================================
    // 2. HARDWARE CORE INSTANTIATIONS (CENTRALIZED PLANE CONFIGURATION)
    // =========================================================================

    // 1. Host Command Processor
    pisc_host_core host_cpu ( 
        .clk(clk), 
        .reset(reset),
        .dma_trigger(cpu_dma_trigger),
        .dma_src_addr(cpu_dma_src),
        .dma_dest_addr(cpu_dma_dest),
        .dma_busy(dma_system_busy)
    );

    // 2. Hardware Enforced Memory Mapping Decoder
    l3_cache_top shared_l3 ( 
        .bus_address(l3_dec_addr),
        .bus_read_req(l3_dec_read_req),
        .bus_write_req(l3_dec_write_req),
        .is_sparc_core(l3_dec_is_sparc),
        .cs_cpu_code(cs_code),
        .cs_cpu_data(cs_data),
        .cs_gpu_input(cs_in),
        .cs_gpu_output(cs_out),
        .access_violation(violation)
    );

    // 3. High-Density Direct Memory Access Pump
    smart_dma matrix_pump (
        .clk(clk),
        .reset(reset),
        .dma_trigger(cpu_dma_trigger),
        .src_addr(cpu_dma_src),
        .dest_addr(cpu_dma_dest),
        .transfer_size(16'd5000),
        .dma_busy(dma_system_busy),
        
        .hbm_read_addr(dma_hbm_raddr), 
        .hbm_read_req(dma_hbm_rreq),
        .hbm_data_in(hbm_global_bus),
        .hbm_ready(hbm_global_ready),
        
        .l3_write_addr(dma_l3_waddr),
        .l3_write_req(dma_l3_wreq),
        .l3_data_out(l3_global_bus)
    );

    // =========================================================================
    // 3. COMPUTE MATRIX GENERATION LUS: 4x4 GRID (16 CLUSTERS = 1024 SIMD ALUS)
    // =========================================================================
    genvar i;
    generate
        // Deploys 16 independent computing matrix zones parallel to the NoC busway
        for (i = 0; i < 16; i = i + 1) begin : gpu_quadrant_blocks
            
            gpu_top #(
                .NUM_CORES(64),       // Prototype scale: 2 cores inseda of 64 per cluster for stable simulation on verilator
                .ALUS_PER_CORE(4)    // Mathematical lock: 4 vector ALU rows = unified 256-bit bus
            ) compute_cluster (
                .clk(clk),
                .reset(reset),
                .vram_bus_data(hbm_global_bus) 
            );

        end
    endgenerate

endmodule

