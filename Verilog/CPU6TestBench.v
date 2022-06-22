
`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps
`include "CPU6.v"
`include "Clock.v"

module Memory(input wire clock, input wire [15:0] address, input wire write_en, input wire [7:0] data_in,
    output reg [7:0] data_out);

    reg [7:0] ram_cells[0:255];

    wire [7:0] mapped_address = address[7:0];

    always @(*) begin
        case (address)
            16'hfd00: data_out = 8'h71; // Reset vector, JMP 1000
            16'hfd01: data_out = 8'h10;
            16'hfd02: data_out = 8'h00;
            default: data_out = ram_cells[mapped_address];
        endcase
    end

    always @(posedge clock) begin
        if (write_en == 1 && address[15:8] == 8'h01) begin
            ram_cells[mapped_address] <= data_in;
        end
    end
endmodule

module CPU6TestBench;
    initial begin
        $dumpfile("vcd/CPUTestBench.vcd");
        $dumpvars(0, CPU6TestBench);
        $write("hellorld: ");
        $readmemh("programs/hellorld.txt", ram.ram_cells);
        sim_end = 0; #0 reset = 0; #50 reset = 1; #200 reset = 0;
        wait(sim_end == 1);
        $write("bnz_test: ");
        $readmemh("programs/bnz_test.txt", ram.ram_cells);
        sim_end = 0; #0 reset = 0; #50 reset = 1; #200 reset = 0;
        wait(sim_end == 1);
        $write("alu_test: ");
        $readmemh("programs/alu_test.txt", ram.ram_cells);
        sim_end = 0; #0 reset = 0; #50 reset = 1; #200 reset = 0;
        wait(sim_end == 1);
        // $readmemh("programs/sjs_4700.txt", ram.ram_cells);
        // sim_end = 0; #0 reset = 0; #50 reset = 1; #200 reset = 0;
        // $readmemh("programs/blink.txt", ram.ram_cells);
        // sim_end = 0; #0 reset = 0; #50 reset = 1; #200 reset = 0;
        // #200000 $finish;
        $display("All done!");
        $finish;
    end

    reg [8*64:1] ramfile;
    wire writeEnBus;
    wire [7:0] data_c2r, data_r2c;
    wire [15:0] addressBus;
    wire clock;
    Clock cg0 (clock);
    Memory ram(clock, addressBus, writeEnBus, data_c2r, data_r2c);
    reg reset;
    CPU6 cpu (reset, clock, data_r2c, writeEnBus, addressBus, data_c2r);
    reg sim_end;

    always @(posedge clock) begin
        if (writeEnBus == 1) begin
            // Pretend there's a UART here :-)
            if (addressBus == 16'h5a00) $write("%s", data_c2r);
            // A hack to stop simulation
            if (addressBus == 16'h5b00 && data_c2r == 8'h5a) begin
                sim_end <= 1;
            end
        end
    end
endmodule

/*

TotalSeconds      : 1.0773913
TotalMilliseconds : 1077.3913
4.9 ms simulation time = 220 times slower than hardware Centurion
About 22.75 kHz clock simulated

First instruction is fetched about 40 uS after reset.

Cycle counts

Opcode: 0x01, cycles:     4
Opcode: 0x02, cycles:     5
Opcode: 0x03, cycles:     5
Opcode: 0x04, cycles:     8
Opcode: 0x05, cycles:     8
Opcode: 0x06, cycles:     5
Opcode: 0x07, cycles:     5
Opcode: 0x08, cycles:     5
Opcode: 0x09, cycles:    22
Opcode: 0x0a, cycles:    31
Opcode: 0x0b, cycles:    44
Opcode: 0x0c, cycles:     6
Opcode: 0x0d, cycles:     9
Opcode: 0x0e, cycles: 22725
Opcode: 0x0f, cycles:    42

Opcode: 0x21, cycles:    12

Opcode: 0x38, cycles:     7
Opcode: 0x39, cycles:     7
Opcode: 0x3a, cycles:     6
Opcode: 0x3b, cycles:     7
Opcode: 0x3c, cycles:    10
Opcode: 0x3d, cycles:     8
Opcode: 0x3e, cycles:    10
Opcode: 0x3f, cycles:    10
Opcode: 0x81, cycles:     8
Opcode: 0x83, cycles:    18

 */
