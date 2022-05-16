
module Memory(input wire clock, input wire [15:0] address, input wire write_en, input wire [7:0] data_in,
    output wire [7:0] data_out);

    integer i;
    initial begin
        for (i=0; i<65536; i=i+1) ram_cells[i] = 8'hff;

        // Boot!
        i = 16'hff00;
        ram_cells[i] = 8'h01; i = i+1; // NOP

        ram_cells[i] = 8'h80; i = i+1; // LDAL #01
        ram_cells[i] = 8'h01; i = i+1;

        ram_cells[i] = 8'h01; i = i+1; // NOP
        ram_cells[i] = 8'h20; i = i+1; // INR
        ram_cells[i] = 8'h00; i = i+1;

        //ram_cells[i] = 8'ha1; i = i+1; // STAL
        ram_cells[i] = 8'h71; i = i+1; // JMP
        ram_cells[i] = 8'hff; i = i+1;
        ram_cells[i] = 8'h03; i = i+1;
    end

    reg [7:0] ram_cells[0:65535];

    assign data_out = ram_cells[address]; 

    always @(posedge clock) begin
        if (write_en == 1) begin
            ram_cells[address] = data_in;
        end
    end
endmodule
