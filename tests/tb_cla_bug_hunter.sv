`timescale 1ns/1ns

module tb_cla_bug_hunter;

    // Testbench signalen
    reg clk;
    reg reset;
    reg mode_64bit;
    reg [1:0] op;
    
    // In- en uitgangen voor de 8 gekoppelde ALU's (64 bits totaal)
    reg [7:0] test_rs [0:7];
    reg [7:0] test_rt [0:7];
    wire [7:0] sim_out [0:7];

    // Connectie met de interne Core module die we eerder hebben ontworpen
    core uut (
        .clk(clk),
        .reset(reset),
        .mode_64bit(mode_64bit),
        .decoded_alu_arithmetic_mux(op),
        .alu_rs_data(test_rs),
        .alu_rt_data(test_rt),
        .alu_out_data(sim_out)
    );

    // Klokgenerator (1 GHz, elke 0.5ns een omslag)
    always #0.5 clk = ~clk;

    // Simulatieverloop
    initial begin
        // Initialisatie
        clk = 0;
        reset = 1;
        mode_64bit = 1; // We testen specifiek de 64-bit CLA modus
        op = 2'b00;     // ADD instructie
        
        // Zet alle inputs standaard op 0
        for (int i = 0; i < 8; i++) begin
            test_rs[i] = 8'h00;
            test_rt[i] = 8'h00;
        end
        
        #2;
        reset = 0; // Systeem is stabiel en actief
        #1;

        // =====================================================================
        // TEST RUN 1: De "Cascade Test" (Bug Hunter)
        // =====================================================================
        // We stoppen 0x00000000000000FF in RS (verdeeld over de 8 slices)
        test_rs[0] = 8'hFF; // Laagste byte
        test_rs[1] = 8'h00;
        test_rs[2] = 8'h00;
        test_rs[3] = 8'h00;
        test_rs[4] = 8'h00;
        test_rs[5] = 8'h00;
        test_rs[6] = 8'h00;
        test_rs[7] = 8'h00; // Hoogste byte

        // We stoppen 0x0000000000000001 in RT
        test_rt[0] = 8'h01; // Laagste byte
        
        #1; // Wacht tot de combinatorische logica (CLA) zich stabiliseert

        // INSPECTIE VIA DE SIMULATOR CONSOLE
        $display("[SIM] Tijd: %0t ns", $time);
        $display("[SIM] Inputs klaar. Verwachte output: ALU[0]=00, ALU[1]=01, rest=00");
        $display("[SIM] Werkelijke ALU Outputs:");
        for (int i = 7; i >= 0; i--) begin
            $display("      ALU [%0d]: 0x%h", i, sim_out[i]);
        end

        // Geautomatiseerde Bug-Check
        if (sim_out[0] == 8'h00 && sim_out[1] == 8'h01 && sim_out[2] == 8'h00) begin
            $display("[RESULTAAT] SUCCESS: De Carry-Lookahead heeft de bit correct en direct doorgegeven!");
        end else begin
            $display("[RESULTAAT] ERROR !!! BUG GEVONDEN IN CLA LOGICA !!!");
            $display("            De carry is onderweg gestrand.");
        end

        $finish;
    end

endmodule

