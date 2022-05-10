
`include "Am2909.v"
`include "Am2911.v"
`include "Am2901.v"
`include "CodeROM.v"
`include "MapROM.v"

module CPU6(input wire reset, input wire clock, inout wire [7:0] dataBus, output reg [15:0] addressBus);
    initial begin
    end

    wire zero;
    assign zero = !reset;

    // 6309 ROM
    wire [7:0] map_rom_address;
    wire [7:0] map_rom_data;
    MapROM map_rom(map_rom_address, map_rom_data);

    // Microcode ROM(s)
    wire [10:0] uc_rom_address;
    wire [55:0] uc_rom_data;
    CodeROM uc_rom(uc_rom_address, uc_rom_data);

    // Pipeline register
    reg [55:0] pipeline;

    // Sequencer shared nets
    wire seq_fe;
    wire seq_pup;
    wire seq_zero;

    // Am2909/2911 Microsequencers
    wire [3:0] seq0_din;
    wire [3:0] seq0_rin;
    reg [3:0] seq0_orin;
    wire seq0_s0;
    wire seq0_s1;
    wire seq0_cin;
    wire seq0_re;
    wire [3:0] seq0_yout;
    wire seq0_cout;
    Am2909 seq0(clock, seq0_din, seq0_rin, seq0_orin, seq0_s0, seq0_s1, seq_zero, seq0_cin,
        seq0_re, seq_fe, seq_pup, seq0_yout, seq0_cout);

    wire [3:0] seq1_din;
    wire [3:0] seq1_rin;
    reg [3:0] seq1_orin;
    wire seq1_s0;
    reg seq1_s1;
    wire seq1_cin;
    wire seq1_re;
    wire [3:0] seq1_yout;
    wire seq1_cout;
    Am2909 seq1(clock, seq1_din, seq1_rin, seq1_orin, seq1_s0, seq1_s1, seq_zero, seq1_cin,
        seq1_re, seq_fe, seq_pup, seq1_yout, seq1_cout);

    wire [3:0] seq2_din;
    wire [3:0] seq2_rin;
    wire seq2_s0;
    wire seq2_s1;
    wire seq2_cin;
    wire seq2_re;
    wire [3:0] seq2_yout;
    wire seq2_cout;
    Am2911 seq2(clock, seq2_din, seq2_s0, seq2_s1, seq_zero, seq2_cin, seq2_re, seq_fe,
        seq_pup, seq2_yout, seq2_cout);

    // ALU shared nets
    wire [3:0] alu_a;
    wire [3:0] alu_b;
    wire [2:0] alu_src;
    wire [2:0] alu_op;
    wire [2:0] alu_dest;

    // Am2901 ALUs
    wire [3:0] alu0_din;
    reg alu0_cin;
    wire [3:0] alu0_yout;
    wire alu0_cout;
    wire alu0_f0;
    wire alu0_f3;
    wire alu0_ovr;
    Am2901 alu0(clock, alu0_din, alu_a, alu_b, alu_src, alu_op, alu_dest, alu0_cin,
        alu0_yout, alu0_cout, alu0_f0, alu0_f3, alu0_ovr);

    wire [3:0] alu1_din;
    wire alu1_cin;
    wire [3:0] alu1_yout;
    wire alu1_cout;
    wire alu1_f0;
    wire alu1_f3;
    wire alu1_ovr;
    Am2901 alu1(clock, alu1_din, alu_a, alu_b, alu_src, alu_op, alu_dest, alu1_cin,
        alu1_yout, alu1_cout, alu1_f0, alu1_f3, alu1_ovr);

    // ALU flags
    reg alu_zero;

    // Internal Busses
    reg [7:0] iDBus;
    reg [7:0] FBus;

    // Constant (immediate data)
    wire [7:0] constant;

    // Enables
    wire [3:0] d2d3;
    wire [1:0] e7;
    wire [2:0] h11;
    wire [2:0] k11;
    wire [2:0] e6;
    wire case_;

    // Shift/carry select
    wire [1:0] shift_carry;

    // Sequencer shared nets
    assign seq_zero = zero;
    assign seq_fe = pipeline[27];
    assign seq_pup = pipeline[28];

    // Sequencer 0
    assign seq0_din = pipeline[19:16];
    assign seq0_rin = map_rom_data[3:0];
    // Case control
    assign case_ = pipeline[33];
    // Guideline #3: When modeling combinational logic with an "always" 
    //              block, use blocking assignments.
    always @(*) begin
        seq0_orin = 0;
        if (case_ == 0) begin
            seq0_orin[1] = alu_zero;
        end
    end
    assign seq0_s0 = ~pipeline[29];
    assign seq0_s1 = ~pipeline[30];
    assign seq0_cin = 1;
    assign seq0_re = 1;
    assign uc_rom_address[3:0] = seq0_yout[3:0];

    // Sequencer 1
    assign seq1_din = pipeline[23:20];
    assign seq1_rin = map_rom_data[7:4];
    assign seq1_s0 = ~pipeline[31];
    always @(*) begin
        seq1_orin = 0;
        if (pipeline[54] == 0) begin
            seq1_s1 = 0;
        end else begin
            seq1_s1 = ~pipeline[32];
        end
    end
    assign seq1_cin = seq0_cout;
    assign seq1_re = 1;
    assign uc_rom_address[7:4] = seq1_yout[3:0];

    // Sequencer 2
    assign seq2_din[2:0] = pipeline[26:24];
    assign seq2_orin = 0;
    assign seq2_s0 = ~pipeline[31];
    assign seq2_s1 = ~pipeline[32];
    assign seq2_cin = seq1_cout;
    assign seq2_re = 1;
    assign uc_rom_address[10:8] = seq2_yout[2:0];

    // ALU shared nets
    assign alu_a = pipeline[50:47];
    assign alu_b = pipeline[46:43];
    assign alu_src = pipeline[36:34];
    assign alu_op = pipeline[39:37];
    assign alu_dest = pipeline[42:40];

    // ALU 0
    assign alu0_din = iDBus[3:0];
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
    end

    // ALU 1
    assign alu1_din = iDBus[7:4];
    assign alu1_cin = alu0_cout;

    // Shift/carry select
    assign shift_carry = pipeline[52:51];

    // Constant (immediate data)
    assign constant = ~pipeline[16+7:16];

    // Enables
    // d2d3 is decoded before pipeline, but outputs are registered.
    assign d2d3 = pipeline[3:0];
    assign e6 = pipeline[6:4];
    assign k11 = pipeline[9:7];
    assign h11 = pipeline[12:10];
    assign e7 = pipeline[14:13];

    // Datapath
    always @(*) begin
        iDBus = 0;
        FBus = 0;

        if (d2d3 == 13) begin
            iDBus = constant;
        end else if (d2d3 == 10) begin
            iDBus = dataBus;
            // force instruction for testing
            iDBus = 8'h01;
        end
    end

    always @(posedge clock) begin
        pipeline <= uc_rom_data;
        alu_zero <= alu0_f0 & alu1_f0;
    end
endmodule
