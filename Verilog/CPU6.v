
`include "Am2909.v"
`include "Am2911.v"
`include "Am2901.v"
`include "CodeROM.v"
`include "MapROM.v"

module CPU6(input wire reset, input wire clock, input wire [7:0] dataInBus,
    output reg writeEnBus, output wire [15:0] addressBus, output wire [7:0] dataOutBus);

    integer i;
    initial begin
        cycle_counter = 0;
        for (i=0; i<16; i=i+1) register_ram[i] = 8'hff;
        for (i=0; i<2048; i=i+1) ucode_used[i] = 0;
    end

    assign addressBus = memory_address;
    assign dataOutBus = result_register;

    /*
     * Instrumentation
     */

    wire instruction_start = uc_rom_address == 11'h101;
    reg [31:0] cycle_counter;
    wire [7:0] register0 = register_ram[0];
    wire [7:0] register1 = register_ram[1];
    reg pc_increment;
    wire read_enable = h11 == 5;
    reg ucode_used[0:2047];

    /*
     * Rising edge triggered registers
     */
    // Pipeline register
    reg [55:0] pipeline;
    // ALU flags register
    reg alu_zero;
    reg [7:0] work_address_lo;
    reg [7:0] work_address_hi;
    reg [15:0] memory_address;
    reg [7:0] register_index;
    reg [7:0] result_register;
    reg [7:0] swap_register;
    reg [7:0] flags_register;
    reg [3:0] condition_codes; // M12

    // This may or may not exist in hardware, but it solves a problem with instructions after JMP
    reg enable_pc_incr;

    // Register RAM, limit to 16 bytes to reduce iCE40 resource requirements
    reg [7:0] register_ram[0:15];

    // 6309 ROM
    wire [7:0] map_rom_address = DPBus;
    wire [7:0] map_rom_data;
    MapROM map_rom(map_rom_address, map_rom_data);

    // Microcode ROM(s)
    wire [10:0] uc_rom_address;
    wire [55:0] uc_rom_data;
    CodeROM uc_rom(uc_rom_address, uc_rom_data);


    // Sequencer shared nets

    wire seq_fe = pipeline[27] & jsr_;
    wire seq_pup = pipeline[28];
    wire seq_zero = !reset;

    /*
     * Am2909/2911 Microsequencers
     */

    // Sequencer 0 (microcode address bits 3:0)
    wire [3:0] seq0_din = pipeline[19:16];
    wire [3:0] seq0_rin = FBus[3:0];
    reg [3:0] seq0_orin;
    wire seq0_s0 = ~(pipeline[29] & jsr_);
    wire seq0_s1 = ~(pipeline[30] & jsr_);
    wire seq0_cin = 1;
    reg seq0_re;
    wire [3:0] seq0_yout;
    wire seq0_cout;

    Am2909 seq0(clock, seq0_din, seq0_rin, seq0_orin, seq0_s0, seq0_s1, seq_zero, seq0_cin,
        seq0_re, seq_fe, seq_pup, seq0_yout, seq0_cout);

    // Case control
    wire case_ = pipeline[33];

    // Microcode conditional subroutine calls
    reg jsr_;

    // Sequencer 1 (microcode address bits 7:4)
    wire [3:0] seq1_din = pipeline[23:20];
    wire [3:0] seq1_rin = FBus[7:4];
    reg [3:0] seq1_orin;
    wire seq1_s0 = ~(pipeline[31] & jsr_);
    wire seq1_s1 = ~(~(pipeline[54] & ~pipeline[32]) & jsr_);
    wire seq1_cin = seq0_cout;
    reg seq1_re;
    wire [3:0] seq1_yout;
    wire seq1_cout;

    Am2909 seq1(clock, seq1_din, seq1_rin, seq1_orin, seq1_s0, seq1_s1, seq_zero, seq1_cin,
        seq1_re, seq_fe, seq_pup, seq1_yout, seq1_cout);


    // Sequencer 2 (microcode address bits 10:8)
    wire [3:0] seq2_din = pipeline[26:24];
    wire [3:0] seq2_rin;
    wire seq2_s0 = ~(pipeline[31] & jsr_);
    wire seq2_s1 = ~(pipeline[32] & jsr_);
    wire seq2_cin = seq1_cout;
    wire seq2_re = 1;
    wire [3:0] seq2_yout;
    wire seq2_cout;

    Am2911 seq2(clock, seq2_din, seq2_s0, seq2_s1, seq_zero, seq2_cin, seq2_re, seq_fe,
        seq_pup, seq2_yout, seq2_cout);

    assign uc_rom_address = { seq2_yout, seq1_yout, seq0_yout };

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
    wire [3:0] alu0_din = DPBus[3:0];
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
    wire [3:0] alu1_din = DPBus[7:4];
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
    wire [2:0] k9 = pipeline[18:16];
    wire [1:0] j12 = pipeline[17:16];

    // Constant (immediate data)
    wire [7:0] constant = ~pipeline[16+7:16];

    // Internal Busses
    // Register RAM reads from FBus (not certain)
    // Register RAM writes to DPBus
    reg [7:0] DPBus;
    reg [7:0] FBus;
    reg [7:0] RBus;

    // Guideline #3: When modeling combinational logic with an "always" 
    //              block, use blocking assignments.
    always @(*) begin
        jsr_ = 1;
        if (pipeline[15] == 0) begin
            case (k9)
                2: jsr_ = ~register_index[0];
            endcase
        end

        alu0_cin = 0;
        if (shift_carry == 0) begin
            alu0_cin = 0;
        end else if (shift_carry == 1) begin
            alu0_cin = 1;
        end else if (shift_carry == 2) begin
            // really comes from j9, see pipeline[15] above
            alu0_cin = ~alu_zero;
        end else if (shift_carry == 3) begin
            alu0_cin = 0;
        end

        seq0_orin = 0;
        if (case_ == 0) begin
            if (j13 == 0) begin
                seq0_orin[0] = flags_register[1];
                seq0_orin[1] = flags_register[0];
            end
        end
        seq1_orin = 0;

        seq0_re = 1;
        seq1_re = 1;
        if (e6 == 6) begin
            seq0_re = 0;
            seq1_re = 0;
        end

        // Datapath muxes
        DPBus = 0;
        FBus = 0;

        if (d2d3 == 13) begin
            DPBus = constant;
        end else if (d2d3 == 0) begin
            DPBus = swap_register;
        end else if (d2d3 == 1) begin
            DPBus = register_ram[register_index];
        end else if (d2d3 == 2) begin
            // DPBus = address hi, high nibble inverted, this and the next one break simulation!!
            //DPBus <= { ~memory_address[15:12], memory_address[11:8] };
        end else if (d2d3 == 3) begin
            // DPBus = address lo
            //DPBus <= memory_address[7:0];
        end else if (d2d3 == 8) begin
            // DPBus = translated address hi, 17:11 (17 down), and top 3 bits together
        end else if (d2d3 == 9) begin
            // low nibble is sense switches
            DPBus = { ~condition_codes[3:0], 4'b0000 };
        end else if (d2d3 == 10) begin
            DPBus = dataInBus;
        end else if (d2d3 == 11) begin
            // read ILR (interrupt level register?) H14 4 bits, A8 4 bits current level
        end else if (d2d3 == 12) begin
            // read switch 2 other half of dip switches and condition codes?
        end

        FBus = { alu1_yout, alu0_yout };
        if (h11 == 6) begin
            FBus = map_rom_data;
        end

        pc_increment = 0;
        //if (h11 == 1) begin // no good
        //if (h11 == 6) begin // no good!
        if (h11 == 5 && enable_pc_incr) begin // this seems to work, seems complicated
            pc_increment = 1;
        end
        // if (d2d3 == 10 || k11 == 7) begin
        //     pc_increment = 1;
        // end
    end

    // Guideline #1: When modeling sequential logic, use nonblocking 
    //              assignments.
    always @(posedge clock, posedge reset) begin
        if (reset == 1) begin
            alu_zero <= 0;
            work_address_lo <= 0;
            work_address_hi <= 0;
            memory_address <= 0;
            register_index <= 0;
            result_register <= 0;
            swap_register <= 0;
            enable_pc_incr <= 0;
            condition_codes <= 0;
            flags_register <= 0;
        end else begin
            if (ucode_used[uc_rom_address] == 0) begin
                //$display("%03x", uc_rom_address);
                ucode_used[uc_rom_address] <= 1;
            end
            pipeline <= uc_rom_data;
            alu_zero <= alu0_f0 & alu1_f0;
            if (instruction_start == 1) begin
                cycle_counter <= 1;
            end else begin
                cycle_counter <= cycle_counter + 1;
            end
            // PC increment
            if (pc_increment) begin
                memory_address <= memory_address + 1;
            end

            // E6 decoder
            case (e6)
                0: ;
                1: result_register <= FBus;
                2: register_index <= FBus; // uC bit 53 might simplify 16 bit register write
                3: ; // load D9
                4: ; // load page table base register
                5: begin memory_address <= {work_address_hi, work_address_lo}; enable_pc_incr <= !enable_pc_incr; end
                6: ; // load AR on 2909, see above
                7: // load condition code register M12
                    begin
                        // based on table in wiki (j12), condition codes in instructions wiki
                        case (j12)
                            0: begin condition_codes[3] <= condition_codes[0]; condition_codes[2] <= condition_codes[1]; end
                            1: begin condition_codes[3] <= flags_register[0]; condition_codes[2] <= flags_register[1]; end
                            2: condition_codes <= result_register[3:0]; // Not sure
                            3: begin condition_codes[3] <= flags_register[5] & flags_register[0]; condition_codes[2] <= flags_register[1]; end
                            default: ;
                        endcase
                    end
            endcase

            if (k11 == 3) begin
                // enable F11 addressable latch, machine state, bus state
                // A0-2 on F11 are B1-3 and D input is B0
            end
            // k11.4 write register RAM
            if (k11 == 4) begin
                register_ram[register_index] <= result_register;
            end
            if (k11 == 6) begin
                work_address_lo <= result_register;
                if (e6 == 5) begin
                    work_address_lo <= memory_address[7:0];
                end
            end
            writeEnBus = 0;
            // might be a bus write, seems to be true
            if (k11 == 7) begin
                writeEnBus <= 1;
            end
            if (h11 == 3) begin
                work_address_hi <= result_register;
                if (e6 == 5) begin
                    work_address_hi <= memory_address[15:8];
                end
            end
            if (h11 == 5) begin
                enable_pc_incr <= 1;
            end
            if (h11 == 6) begin
                // see above
            end
            if (e7 == 2) begin
                // save condition codes from ALU to J9
                flags_register <= { 1'b0, 1'b0, flags_register[0], alu0_cout, alu1_cout, alu1_ovr, alu1_f3, alu0_f0 & alu1_f0 };
            end
        end
    end
endmodule

/*

TotalSeconds      : 1.0773913
TotalMilliseconds : 1077.3913
4.9 ms simulation time = 220 times slower than hardware Centurion
About 22.75 kHz clock simulated

First instruction is fetched about 40 uS after reset.

Cycle counts

Opcode: 0x01, cycles:     4
Opcode: 0x02, cycles:     5
Opcode: 0x03, cycles:     5
Opcode: 0x04, cycles:     8
Opcode: 0x05, cycles:     8
Opcode: 0x06, cycles:     5
Opcode: 0x07, cycles:     5
Opcode: 0x08, cycles:     5
Opcode: 0x09, cycles:    22
Opcode: 0x0a, cycles:    31
Opcode: 0x0b, cycles:    44
Opcode: 0x0c, cycles:     6
Opcode: 0x0d, cycles:     9
Opcode: 0x0e, cycles: 22722
Opcode: 0x0f, cycles:    42

Opcode: 0x21, cycles:    12

Opcode: 0x38, cycles:     7
Opcode: 0x39, cycles:     7
Opcode: 0x3a, cycles:     6
Opcode: 0x3b, cycles:     7
Opcode: 0x3c, cycles:    10
Opcode: 0x3d, cycles:     8
Opcode: 0x3e, cycles:    10
Opcode: 0x3f, cycles:    10
Opcode: 0x81, cycles:     8
Opcode: 0x83, cycles:    18

 */