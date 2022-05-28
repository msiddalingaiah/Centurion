
`include "iCECPU6.v"
`include "Memory.v"
`include "LEDPanel.v"

/*
DEVICE = hx1k (IceBlink40)
CodeRom reg [55:0] memory[0:1023]
reg [7:0] register_ram[0:16]
No memory
Info: Device utilisation:
Info:            ICESTORM_LC:  1140/ 1280    89%
Info:           ICESTORM_RAM:    14/   16    87%
Info:                  SB_IO:     5/  112     4%
Info:                  SB_GB:     4/    8    50%
Info:           ICESTORM_PLL:     0/    1     0%
Info:            SB_WARMBOOT:     0/    1     0%
Timing estimate: 25.12 ns (39.80 MHz)


DEVICE = hx8k (Alchitry Cu)
CodeROM reg [55:0] memory[0:2047]
reg [7:0] register_ram[0:15]
reg [7:0] ram_cells[0:255];
Info: Device utilisation:
Info:            ICESTORM_LC:  5281/ 7680    68%
Info:           ICESTORM_RAM:    27/   32    84%
Info:                  SB_IO:     5/  256     1%
Info:                  SB_GB:     4/    8    50%
Info:           ICESTORM_PLL:     0/    2     0%
Info:            SB_WARMBOOT:     0/    1     0%
Timing estimate: 32.33 ns (30.93 MHz)
 */
module iCE40(input clock, output LED2, output LED3, output LED4, output LED5);
    initial begin
        reset = 1;
    end

    assign { LED2, LED3, LED4, LED5 } = leds[3:0];
    
    reg reset;

    wire writeEnBus;
    wire [7:0] data_c2r, data_r2c;
    wire [15:0] addressBus;
    wire [7:0] leds;
    Memory ram(clock, addressBus, writeEnBus, data_c2r, data_r2c);
    LEDPanel panel(clock, addressBus, writeEnBus, data_c2r, data_r2c, leds);
    iCECPU6 cpu (reset, clock, data_r2c, writeEnBus, addressBus, data_c2r);

	always @ (posedge clock) begin
		if (reset == 1) begin
			reset <= 0;
		end
    end
endmodule
