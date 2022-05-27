
`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps
`include "CPU6.v"
`include "Clock.v"
`include "Memory.v"

module CPU6TestBench;
    initial begin
        $dumpfile("vcd/CPUTestBench.vcd"); 
        $dumpvars(0, CPU6TestBench);
        #500000 $finish;
    end

    wire clock, reset, writeEnBus;
    wire [7:0] data_c2r, data_r2c;
    wire [15:0] addressBus;
    Clock cg0 (reset, clock);
    Memory ram(clock, addressBus, writeEnBus, data_c2r, data_r2c);
    CPU6 cpu (reset, clock, data_r2c, writeEnBus, addressBus, data_c2r);

    always @(posedge clock) begin
        if (writeEnBus == 1) begin
            // Pretend there's a UART here :-)
            if (addressBus == 16'h5a00) $write("%s", data_c2r);
            // A hack to stop simulation
            if (addressBus == 16'h5b00 && data_c2r == 8'h5a) begin
                $display("Simulation terminated by user request.");
                $finish;
            end
        end
    end
endmodule
