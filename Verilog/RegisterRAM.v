
module RegisterRAM(input wire clock, input wire write_en, input wire [7:0] address, input wire [7:0] data_in,
    output reg [7:0] data_out);

    integer i;
    initial begin
        for (i=0; i<256; i=i+1) memory[i] = 8'hff;
    end

    reg [7:0] memory[0:255];

    always @(posedge clock) begin
        data_out <= memory[address];
        if (write_en == 1) begin
            memory[address] <= data_in;
        end
    end
endmodule
