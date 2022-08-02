
/**
 * This module implements the CPU6 microcode ROM.
 * Microcode is loaded from a text file, which is synthesizable.
 */
module CodeROM(input wire [10:0] address, output wire [55:0] data);
    reg [55:0] memory[0:2047];
    initial begin
        $readmemh("roms/CodeROM.txt", memory);
    end

    assign data = memory[address];
endmodule
