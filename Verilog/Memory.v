
module Memory(input wire clock, input wire [15:0] address, input wire write_en, input wire [7:0] data_in,
    output wire [7:0] data_out);

    integer i;
    initial begin
        for (i=0; i<65536; i=i+1) ram_cells[i] = 8'h01; // All NOP

        // Boot!
        i = 16'hff00;
        ram_cells[i] = 8'h01; i = i+1; // NOP

        ram_cells[i] = 8'h01; i = i+1; // NOP

        ram_cells[i] = 8'h80; i = i+1; // LDAL #01
        ram_cells[i] = 8'h01; i = i+1;

        ram_cells[i] = 8'h01; i = i+1; // NOP
        ram_cells[i] = 8'h20; i = i+1; // INR
        ram_cells[i] = 8'h00; i = i+1;

        //ram_cells[i] = 8'h71; i = i+1; // JMP
        //ram_cells[i] = 8'hff; i = i+1;
        //ram_cells[i] = 8'h05; i = i+1;

        // Hellorld!
        ram_cells[i] = 8'h80; i = i+1; // LDAL #48 (H)
        ram_cells[i] = 8'h48; i = i+1;

        ram_cells[i] = 8'ha1; i = i+1; // STAL
        ram_cells[i] = 8'h5a; i = i+1;
        ram_cells[i] = 8'h00; i = i+1;


        ram_cells[i] = 8'h80; i = i+1; // LDAL #65 (e)
        ram_cells[i] = 8'h65; i = i+1;

        ram_cells[i] = 8'ha1; i = i+1; // STAL
        ram_cells[i] = 8'h5a; i = i+1;
        ram_cells[i] = 8'h00; i = i+1;


        ram_cells[i] = 8'h80; i = i+1; // LDAL #6c (l)
        ram_cells[i] = 8'h6c; i = i+1;

        ram_cells[i] = 8'ha1; i = i+1; // STAL
        ram_cells[i] = 8'h5a; i = i+1;
        ram_cells[i] = 8'h00; i = i+1;


        ram_cells[i] = 8'h80; i = i+1; // LDAL #6c (l)
        ram_cells[i] = 8'h6c; i = i+1;

        ram_cells[i] = 8'ha1; i = i+1; // STAL
        ram_cells[i] = 8'h5a; i = i+1;
        ram_cells[i] = 8'h00; i = i+1;


        ram_cells[i] = 8'h80; i = i+1; // LDAL #6f (o)
        ram_cells[i] = 8'h6f; i = i+1;

        ram_cells[i] = 8'ha1; i = i+1; // STAL
        ram_cells[i] = 8'h5a; i = i+1;
        ram_cells[i] = 8'h00; i = i+1;


        ram_cells[i] = 8'h80; i = i+1; // LDAL #72 (r)
        ram_cells[i] = 8'h72; i = i+1;

        ram_cells[i] = 8'ha1; i = i+1; // STAL
        ram_cells[i] = 8'h5a; i = i+1;
        ram_cells[i] = 8'h00; i = i+1;


        ram_cells[i] = 8'h80; i = i+1; // LDAL #6c (l)
        ram_cells[i] = 8'h6c; i = i+1;

        ram_cells[i] = 8'ha1; i = i+1; // STAL
        ram_cells[i] = 8'h5a; i = i+1;
        ram_cells[i] = 8'h00; i = i+1;


        ram_cells[i] = 8'h80; i = i+1; // LDAL #64 (d)
        ram_cells[i] = 8'h64; i = i+1;

        ram_cells[i] = 8'ha1; i = i+1; // STAL
        ram_cells[i] = 8'h5a; i = i+1;
        ram_cells[i] = 8'h00; i = i+1;


        ram_cells[i] = 8'h80; i = i+1; // LDAL #21 (!)
        ram_cells[i] = 8'h21; i = i+1;

        ram_cells[i] = 8'ha1; i = i+1; // STAL
        ram_cells[i] = 8'h5a; i = i+1;
        ram_cells[i] = 8'h00; i = i+1;


        ram_cells[i] = 8'h80; i = i+1; // LDAL #0a (\n)
        ram_cells[i] = 8'h0a; i = i+1;

        ram_cells[i] = 8'ha1; i = i+1; // STAL
        ram_cells[i] = 8'h5a; i = i+1;
        ram_cells[i] = 8'h00; i = i+1;

        //ram_cells[i] = 8'h00; i = i+1; // HLT

        ram_cells[i] = 8'h80; i = i+1; // LDAL #0a (\n)
        ram_cells[i] = 8'h5a; i = i+1;

        ram_cells[i] = 8'ha1; i = i+1; // STAL
        ram_cells[i] = 8'h5b; i = i+1;
        ram_cells[i] = 8'h00; i = i+1;
    end

    reg [7:0] ram_cells[0:65535];

    assign data_out = ram_cells[address]; 

    always @(posedge clock) begin
        if (write_en == 1) begin
            ram_cells[address] <= data_in;
            // Pretend there's a UART here :-)
            if (address == 16'h5a00) $write("%s", data_in);
            // A hack to stop simulation
            if (address == 16'h5b00 && data_in == 8'h5a) begin
                $display("Simulation terminated by user request.");
                $finish;
            end
        end
    end
endmodule
