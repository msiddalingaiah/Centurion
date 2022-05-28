
module LEDPanel(input wire clock, input wire [15:0] address, input wire write_en, input wire [7:0] data_in,
    output wire [7:0] data_out, output reg [7:0] leds);

    always @(posedge clock) begin
        if (write_en == 1) begin
            if (address == 16'h5c00) begin
                leds <= data_in;
            end
        end
    end
endmodule
