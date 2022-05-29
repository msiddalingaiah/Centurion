
`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps
`include "CPU6.v"
`include "Clock.v"
`include "Memory.v"

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
        // $readmemh("programs/sjs_4700.txt", ram.ram_cells);
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
