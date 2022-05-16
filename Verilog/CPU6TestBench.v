
`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps
`include "CPU6.v"
`include "Clock.v"
`include "Memory.v"

//module CPU6(input wire reset, input wire clock, input wire [7:0] dataInBus,
//    output wire writeEnBus, output wire [15:0] addressBus, output wire [7:0] dataOutBus);

//module Memory(input wire clock, input wire [15:0] address, input wire write_en, input wire [7:0] data_in,
//    output wire [7:0] data_out);

module CPU6TestBench;
    initial begin
        $dumpfile("vcd/CPUTestBench.vcd"); 
        $dumpvars(0, CPU6TestBench);
        #60000 $finish;
    end

    wire clock, reset, writeEnBus;
    wire [7:0] data_c2r, data_r2c;
    wire [15:0] addressBus;
    Clock cg0 (reset, clock);
    Memory ram(clock, addressBus, writeEnBus, data_c2r, data_r2c);
    CPU6 cpu (reset, clock, data_r2c, writeEnBus, addressBus, data_c2r);
endmodule
