
`include "Am2909.v"
`include "Am2911.v"
`include "Am2901.v"
`include "CodeROM.v"
`include "MapROM.v"

module CPU6(input wire reset, input wire clock, inout wire [7:0] dataBus, output reg [15:0] addressBus);
    initial begin
    end

    /*
     * Rising edge triggered registers
     */
    // Pipeline register
    reg [55:0] pipeline;
    // ALU flags register
    reg alu_zero;

    // 6309 ROM
    wire [7:0] map_rom_address = iDBus;
    wire [7:0] map_rom_data;
    MapROM map_rom(map_rom_address, map_rom_data);

    // Microcode ROM(s)
    wire [10:0] uc_rom_address;
    wire [55:0] uc_rom_data;
    CodeROM uc_rom(uc_rom_address, uc_rom_data);


    // Sequencer shared nets
    wire seq_fe = pipeline[27];
    wire seq_pup = pipeline[28];
    wire seq_zero = !reset;

    /*
     * Am2909/2911 Microsequencers
     */

    // Sequencer 0 (microcode address bits 3:0)
    wire [3:0] seq0_din = pipeline[19:16];
    wire [3:0] seq0_rin = FBus[3:0];
    reg [3:0] seq0_orin;
    wire seq0_s0 = ~pipeline[29];
    wire seq0_s1 = ~pipeline[30];
    wire seq0_cin = 1;
    reg seq0_re;
    wire [3:0] seq0_yout;
    wire seq0_cout;

    Am2909 seq0(clock, seq0_din, seq0_rin, seq0_orin, seq0_s0, seq0_s1, seq_zero, seq0_cin,
        seq0_re, seq_fe, seq_pup, seq0_yout, seq0_cout);

    // Case control
    wire case_ = pipeline[33];
    assign uc_rom_address[3:0] = seq0_yout[3:0];

    // Sequencer 1 (microcode address bits 7:4)
    wire [3:0] seq1_din = pipeline[23:20];
    wire [3:0] seq1_rin = FBus[7:4];
    reg [3:0] seq1_orin;
    wire seq1_s0 = ~pipeline[31];
    reg seq1_s1;
    wire seq1_cin = seq0_cout;
    reg seq1_re;
    wire [3:0] seq1_yout;
    wire seq1_cout;

    Am2909 seq1(clock, seq1_din, seq1_rin, seq1_orin, seq1_s0, seq1_s1, seq_zero, seq1_cin,
        seq1_re, seq_fe, seq_pup, seq1_yout, seq1_cout);

    assign uc_rom_address[7:4] = seq1_yout[3:0];

    // Sequencer 2 (microcode address bits 10:8)
    wire [3:0] seq2_din = pipeline[26:24];
    wire [3:0] seq2_rin;
    wire seq2_s0 = ~pipeline[31];
    wire seq2_s1 = ~pipeline[32];
    wire seq2_cin = seq1_cout;
    wire seq2_re = 1;
    wire [3:0] seq2_yout;
    wire seq2_cout;

    Am2911 seq2(clock, seq2_din, seq2_s0, seq2_s1, seq_zero, seq2_cin, seq2_re, seq_fe,
        seq_pup, seq2_yout, seq2_cout);

    assign uc_rom_address[10:8] = seq2_yout[2:0];

    /*
     * Am2901 bit slice Arithmetic Logic Units (ALUs)
     */
    // ALU shared nets
    wire [3:0] alu_a = pipeline[50:47];
    wire [3:0] alu_b = pipeline[46:43];
    wire [2:0] alu_src = pipeline[36:34];
    wire [2:0] alu_op = pipeline[39:37];
    wire [2:0] alu_dest = pipeline[42:40];

    // ALU 0 (bits 3:0)
    wire [3:0] alu0_din = iDBus[3:0];
    reg alu0_cin;
    wire [3:0] alu0_yout;
    wire alu0_cout;
    wire alu0_f0;
    wire alu0_f3;
    wire alu0_ovr;
    Am2901 alu0(clock, alu0_din, alu_a, alu_b, alu_src, alu_op, alu_dest, alu0_cin,
        alu0_yout, alu0_cout, alu0_f0, alu0_f3, alu0_ovr);

    // Shift/carry select
    wire [1:0] shift_carry = pipeline[52:51];

    // ALU 1 (bits 7:4)
    wire [3:0] alu1_din = iDBus[7:4];
    wire alu1_cin = alu0_cout;
    wire [3:0] alu1_yout;
    wire alu1_cout;
    wire alu1_f0;
    wire alu1_f3;
    wire alu1_ovr;
    Am2901 alu1(clock, alu1_din, alu_a, alu_b, alu_src, alu_op, alu_dest, alu1_cin,
        alu1_yout, alu1_cout, alu1_f0, alu1_f3, alu1_ovr);

    // Enables
    // d2d3 is decoded before pipeline, but outputs are registered.
    wire [3:0] d2d3 = pipeline[3:0];
    wire [1:0] e7 = pipeline[14:13];
    wire [2:0] h11 = pipeline[12:10];
    wire [2:0] k11 = pipeline[9:7];
    wire [2:0] e6 = pipeline[6:4];
    wire [1:0] j13 = pipeline[5:4];

    // Constant (immediate data)
    wire [7:0] constant = ~pipeline[16+7:16];

    // Internal Busses
    reg [7:0] iDBus;
    reg [7:0] FBus;

    // Guideline #3: When modeling combinational logic with an "always" 
    //              block, use blocking assignments.
    always @(*) begin
        alu0_cin = 0;
        if (shift_carry == 0) begin
            alu0_cin = 0;
        end else if (shift_carry == 1) begin
            alu0_cin = 1;
        end else if (shift_carry == 2) begin
            alu0_cin = alu1_cout;
        end else if (shift_carry == 3) begin
            alu0_cin = 0;
        end

        seq0_orin = 0;
        if (case_ == 0) begin
            if (j13 == 0) begin
                seq0_orin[1] = alu_zero;
            end
        end
        seq1_orin = 0;
        if (pipeline[54] == 0) begin
            seq1_s1 = 0;
        end else begin
            seq1_s1 = ~pipeline[32];
        end

        seq0_re = 1;
        seq1_re = 1;
        if (e6 == 6) begin
            seq0_re = 0;
            seq1_re = 0;
        end

        // Datapath muxes
        iDBus = 0;
        FBus = 0;

        if (d2d3 == 13) begin
            iDBus = constant;
        end else if (d2d3 == 10) begin
            iDBus = dataBus;
            // force instruction for testing
            iDBus = 8'h3f;
        end
        FBus[3:0] = alu0_yout;
        FBus[7:4] = alu1_yout;
        if (h11 == 6) begin
            FBus = map_rom_data;
        end
    end

    // Guideline #1: When modeling sequential logic, use nonblocking 
    //              assignments.
    always @(posedge clock) begin
        pipeline <= uc_rom_data;
        alu_zero <= alu0_f0 & alu1_f0;
    end
endmodule
