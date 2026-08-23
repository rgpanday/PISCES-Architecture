`default_nettype none
`timescale 1ns/1ns

module hbm_memory_controller #(
    parameter int HBM_DATA_WIDTH = 1024, // Exactly fitting the HBM-architecture
    parameter int ADDR_WIDTH = 32
)(
    input wire clk,
    input wire reset,

    // Internal Interface (connection to the L3-Cache and System bus)
    input wire l3_read_req,
    input wire l3_write_req,
    input wire [ADDR_WIDTH-1:0] l3_addr,
    input wire [HBM_DATA_WIDTH-1:0] l3_write_data,
    output reg [HBM_DATA_WIDTH-1:0] l3_read_data,
    output reg l3_ready,                // Signal to L3: "Data is ready!"

    // physical External Interface to the HBM-memory chip (the outside world)
    output reg hbm_cmd_ras_n,           // Row Address Strobe
    output reg hbm_cmd_cas_n,           // Column Address Strobe
    output reg hbm_cmd_we_n,            // Write Enable
    output reg [ADDR_WIDTH-1:0] hbm_addr,
    inout wire [HBM_DATA_WIDTH-1:0] hbm_dq // the physical 1024-bit data lines
);

    // Finite State Machine (FSM) to control  DRAM-protocol  
    typedef enum reg [2:0] {
        IDLE        = 3'b000,
        ACTIVATE    = 3'b001, // Open the just row in memory
        READ_WRITE  = 3'b010, // execute the data-transfer
        PRECHARGE   = 3'b011, // close the row again
        REFRESH     = 3'b100  // maintenance cycle for DRAM cells
    } state_t;

    state_t current_state, next_state;
    reg [15:0] refresh_counter;

    // Tri-state buffer logic for the data-bus (read/write over same copper wires)
    reg drive_hbm_bus;
    assign hbm_dq = drive_hbm_bus ? l3_write_data : {HBM_DATA_WIDTH{1'bz}};

    // -------------------------------------------------------------------------
    // REFRESH TIMER: DRAM cells must be refereshed each x microseconds 
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            refresh_counter <= 16'b0;
        end else begin
            refresh_counter <= refresh_counter + 1;
        end
    end

    // -------------------------------------------------------------------------
    // THE TRAFFIC CONTROL PROTOCOL (FSM LOGICA)
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            current_state <= IDLE;
            l3_ready <= 1'b0;
        end else begin
            current_state <= next_state;
            
            // Steer the physical signals on the basis of the status
            case (current_state)
                IDLE: begin
                    l3_ready <= 1'b0;
                    drive_hbm_bus <= 1'b0;
                    hbm_cmd_ras_n <= 1'b1; hbm_cmd_cas_n <= 1'b1; hbm_cmd_we_n <= 1'b1; // no commando
                    
                    // Prioritity rule: must we refresh or does L3 want data?
                    if (refresh_counter > 16'd5000) begin
                        next_state <= REFRESH;
                    end else if (l3_read_req || l3_write_req) begin
                        next_state <= ACTIVATE;
                    end
                end

                ACTIVATE: begin
                    // physical DRAM commando to open the memory row 
                    hbm_cmd_ras_n <= 1'b0; hbm_cmd_cas_n <= 1'b1; hbm_cmd_we_n <= 1'b1;
                    hbm_addr <= l3_addr;
                    next_state <= READ_WRITE;
                end

                READ_WRITE: begin
                    hbm_cmd_ras_n <= 1'b1; hbm_cmd_cas_n <= 1'b0;
                    hbm_addr <= l3_addr;
                    
                    if (l3_write_req) begin
                        hbm_cmd_we_n <= 1'b0;  // write modus
                        drive_hbm_bus <= 1'b1; // Activate output-drivers
                    end else begin
                        hbm_cmd_we_n <= 1'b1;  // read modus
                        l3_read_data <= hbm_dq; // draw the 1024 bits inside at once !
                    end
                    
                    l3_ready <= 1'b1; // tell the L3-cache: "job is done!"
                    next_state <= PRECHARGE;
                end

                PRECHARGE: begin
                    // close off the row so that the chip stays energy efficient and is ready for the next action 
                    hbm_cmd_ras_n <= 1'b0; hbm_cmd_cas_n <= 1'b1; hbm_cmd_we_n <= 1'b0;
                    next_state <= IDLE;
                end

                REFRESH: begin
                    // execute the necessary maintenance cycle
                    hbm_cmd_ras_n <= 1'b0; hbm_cmd_cas_n <= 1'b0; hbm_cmd_we_n <= 1'b1;
                    // Reset the timer after refreshment 
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule

