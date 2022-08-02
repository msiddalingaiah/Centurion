
// `define TRACE_I // trace instructions
// `define TRACE_WR // trace bus writes
// `define TRACE_RD // trace bus reads
// `define TRACE_UC // trace microcode

`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps
`include "CPU6.v"
`include "Clock.v"

/**
 * This file contains a test bench for the CPU6.
 * It includes two RAM banks and one ROM.
 * Writing to the MUX UART prints to the console.
 */
module Memory(input wire clock, input wire [18:0] address, input wire write_en, input wire [7:0] data_in,
    output reg [7:0] data_out);

    reg [7:0] rom_cells[0:8191];
    reg [7:0] ram_cells[0:4095];
    reg [7:0] low_ram_cells[0:4095];

    integer i;
    initial begin
        for (i=0; i<4096; i=i+1) ram_cells[i] = 8'h00;
        for (i=0; i<4096; i=i+1) low_ram_cells[i] = 8'h00;
    end

    wire rom_select = address[18:13] == 4;
    wire ram_select = address[18:12] == 7'hb;
    wire low_ram_select = address[18:12] == 0;
    wire [12:0] low13 = address[12:0];
    wire [11:0] low12 = address[11:0];

    always @(*) begin
        data_out = 0;
        case (address)
            19'h3fd00: data_out = 8'h71; // Reset vector, JMP 8001
            19'h3fd01: data_out = 8'h80;
            19'h3fd02: data_out = 8'h01;
            19'h3f200: data_out = 8'h02; // Diag MUX 0 status
            19'h3f110: data_out = 8'h0d; // Diag DIP switches
            default:
                begin
                    if (rom_select) data_out = rom_cells[low13];
                    if (ram_select) data_out = ram_cells[low12];
                    if (low_ram_select) data_out = low_ram_cells[low12];
                end
        endcase
    end

    always @(posedge clock) begin
        if (write_en) begin
            if (ram_select) ram_cells[low12] <= data_in;
            if (low_ram_select) low_ram_cells[low12] <= data_in;
        end
    end
endmodule

module CPU6TestBench;
    initial begin
        $dumpfile("vcd/CPUTestBench.vcd");
        $dumpvars(0, CPU6TestBench);

        $write("hellorld: ");
        $readmemh("programs/hellorld.txt", ram.rom_cells);
        sim_end = 0; #0 reset = 0; #50 reset = 1; #200 reset = 0;
        wait(sim_end == 1);

        $write("bnz_test: ");
        $readmemh("programs/bnz_test.txt", ram.rom_cells);
        sim_end = 0; #0 reset = 0; #50 reset = 1; #200 reset = 0;
        wait(sim_end == 1);

        $write("alu_test: ");
        $readmemh("programs/alu_test.txt", ram.rom_cells);
        sim_end = 0; #0 reset = 0; #50 reset = 1; #200 reset = 0;
        wait(sim_end == 1);

        // $readmemh("programs/diag.txt", ram.rom_cells);
        // sim_end = 0; #0 reset = 0; #50 reset = 1; #200 reset = 0;
        // #17000000 $finish;

        // $readmemh("programs/inst_test.txt", ram.rom_cells);
        // sim_end = 0; #0 reset = 0; #50 reset = 1; #200 reset = 0;
        // #4100000 $finish;

        // $readmemh("programs/cylon.txt", ram.rom_cells);
        // sim_end = 0; #0 reset = 0; #50 reset = 1; #200 reset = 0;

        // $readmemh("programs/blink.txt", ram.rom_cells);
        // sim_end = 0; #0 reset = 0; #50 reset = 1; #200 reset = 0;

        $display("All done!");
        $finish;
    end

    reg [8*64:1] ramfile;
    wire writeEnBus;
    wire [7:0] data_c2r, data_r2c;
    wire [18:0] addressBus;
    wire clock;
    Clock cg0(clock);
    Memory ram(clock, addressBus, writeEnBus, data_c2r, data_r2c);
    reg reset;
    CPU6 cpu(reset, clock, data_r2c, writeEnBus, addressBus, data_c2r);
    reg sim_end;
    wire [7:0] cc = data_c2r & 8'h7f;

    always @(posedge clock) begin
        if (writeEnBus == 1) begin
            // Pretend there's a UART here :-)
            if (addressBus == 19'h3f201) begin
                if ((cc >= 32) || (cc == 9) || (cc == 10) || (cc == 13)) begin
                    $write("%s", cc);
                end
            end
            // A hack to stop simulation
            if (addressBus == 19'h3f900 && data_c2r == 8'h01) begin
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

01 NOP 4
05 DI 8
3A CLAW 6
22 CLR 11
a1 STAL 18
b1 STAW 22
90 LDAW 12
5f XASW 8
81 LDAL 18
c1 LDBL 18
c0 LDBL 8
99 LAWB 19
42 AND 11
40 ADD 11
58 AABW 9
49 SABL 8
3d SLAW 8
71 JMP 14
14 BZ 9 (branch not taken)
15 BNZ 18 (branch taken)

 */
