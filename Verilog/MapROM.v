
module MapROM(input wire [7:0] address, output wire [7:0] data);
    reg [7:0] memory[0:255];
    initial begin
        $readmemh("roms/CPU-6309.txt", memory);
    end

    assign data = memory[address];
endmodule
