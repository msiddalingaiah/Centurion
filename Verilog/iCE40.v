
`include "CPU6.v"
`include "Memory.v"
`include "LEDPanel.v"
`include "PLL.v"

/*
DEVICE = hx8k (Alchitry Cu)
CodeROM reg [55:0] memory[0:2047]
RegisterRAM reg [7:0] memory[0:255];
reg [7:0] ram_cells[0:255];

Info: Device utilisation:
Info:            ICESTORM_LC:  1143/ 7680    14%
Info:           ICESTORM_RAM:    30/   32    93%
Info:                  SB_IO:     9/  256     3%
Info:                  SB_GB:     5/    8    62%
Info:           ICESTORM_PLL:     1/    2    50%
Info:            SB_WARMBOOT:     0/    1     0%
 */
// Timing estimate: 24.39 ns (40.99 MHz)
// icepll -m -f PLL.v -n PLL -i 100 -o 20
module iCE40(input clock_100MHz, output LED1, output LED2, output LED3, output LED4, output LED5, output LED6, output LED7, output LED8);
    initial begin
        reset = 1;
    end

    assign {LED1, LED2, LED3, LED4, LED5, LED6, LED7, LED8} = leds;
    
    reg reset;

    wire writeEnBus;
    wire [7:0] data_c2r, data_r2c;
    wire [15:0] addressBus;
    wire [7:0] leds;
    wire clock20MHz, locked, clock;

	PLL pll(clock_100MHz, clock20MHz, locked);
    Divide4 div(clock20MHz, clock);
    Memory ram(clock, addressBus, writeEnBus, data_c2r, data_r2c);
    LEDPanel panel(clock, addressBus, writeEnBus, data_c2r, data_r2c, leds);
    CPU6 cpu (reset, clock, data_r2c, writeEnBus, addressBus, data_c2r);

	always @ (posedge clock) begin
		if (reset == 1 && locked == 1) begin
			reset <= 0;
		end
    end
endmodule

module Divide4(input wire clock_in, output wire clock_out);
    reg [1:0] counter;
    assign clock_out = counter[1];
    always @(posedge clock_in) begin
        counter <= counter + 1;
    end
endmodule
