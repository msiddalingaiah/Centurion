
module Memory(input wire clock, input wire [15:0] address, input wire write_en, input wire [7:0] data_in,
    output wire [7:0] data_out);

    initial begin
        $readmemh("programs/blink.txt", ram_cells);
    end

    reg [7:0] ram_cells[0:255];

    wire [7:0] mapped_address = address[7:0];
    assign data_out = ram_cells[mapped_address]; 

    always @(posedge clock) begin
        if (write_en == 1 && address[15:8] == 8'hff) begin
            ram_cells[mapped_address] <= data_in;
        end
    end
endmodule
