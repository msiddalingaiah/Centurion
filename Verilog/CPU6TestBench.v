
`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps
`include "CPU6.v"
`include "Clock.v"

module CPU6TestBench;
    initial begin
        $dumpfile("vcd/CPUTestBench.vcd"); 
        $dumpvars(0, CPU6TestBench);
        #60000 $finish;
    end

    wire clock, reset;
    wire [7:0] dataBus;
    wire [15:0] addressBus;
    Clock cg0 (reset, clock);
    CPU6 cpu (reset, clock, dataBus, addressBus);
endmodule
