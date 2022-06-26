
`include "Am2909.v"
`include "Am2911.v"
`include "Am2901.v"
`include "CodeROM.v"
`include "MapROM.v"
`include "RegisterRAM.v"

module CPU6(input wire reset, input wire clock, input wire [7:0] dataInBus,
    output reg writeEnBus, output wire [15:0] addressBus, output wire [7:0] dataOutBus);

    integer i;
    initial begin
        cycle_counter = 0;
    end

    assign addressBus = memory_address;
    assign dataOutBus = result_register;

    /*
     * Instrumentation
     */

    wire instruction_start = uc_rom_address_pipe == 11'h101;
    reg [31:0] cycle_counter;
    assign pc_increment = h11 == 5 ? 1 : 0;
    reg [10:0] uc_rom_address_pipe;

    /*
     * Rising edge triggered registers
     */
    // Pipeline register
    reg [55:0] pipeline;
    // ALU flags register
    reg [15:0] work_address;
    reg [15:0] memory_address;
    reg [7:0] register_index;
    reg [7:0] result_register;
    reg [7:0] swap_register;
    reg [7:0] flags_register;
    reg [3:0] condition_codes; // M12
    reg [7:0] bus_read; // A11/A12

    // 6309 ROM
    wire [7:0] map_rom_address = DPBus;
    wire [7:0] map_rom_data;
    MapROM map_rom(map_rom_address, map_rom_data);

    // Microcode ROM(s)
    wire [10:0] uc_rom_address;
    wire [55:0] uc_rom_data;
    CodeROM uc_rom(uc_rom_address, uc_rom_data);

    // Synchronous Register RAM
    wire bit53 = pipeline[53];
    wire reg_low_select = bit53;
    // High/low register select, D10 74LS02 NOR gate
    wire [7:0] reg_ram_addr = { register_index[7:1], ~(reg_low_select | register_index[0]) };
    wire rr_write_en = k11 == 4;
    wire [7:0] reg_ram_data_in = result_register;
    wire [7:0] reg_ram_data_out;
    RegisterRAM reg_ram(clock, rr_write_en, reg_ram_addr, reg_ram_data_in, reg_ram_data_out);

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
    wire [3:0] seq2_din = { 1'b0 , pipeline[26:24] }; // only 3 bits are used
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
    wire alu0_q0_in, alu0_ram0_in, alu0_q3_in, alu0_ram3_in;
    wire alu0_q0_out, alu0_ram0_out, alu0_q3_out, alu0_ram3_out;
    Am2901 alu0(clock, alu0_din, alu_a, alu_b, alu_src, alu_op, alu_dest, alu0_cin,
        alu0_yout, alu0_cout, alu0_f0, alu0_f3, alu0_ovr,
        alu0_q0_in, alu0_ram0_in, alu0_q3_in, alu0_ram3_in,
        alu0_q0_out, alu0_ram0_out, alu0_q3_out, alu0_ram3_out);

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
    wire alu1_q0_in, alu1_ram0_in, alu1_q3_in, alu1_ram3_in;
    wire alu1_q0_out, alu1_ram0_out, alu1_q3_out, alu1_ram3_out;
    Am2901 alu1(clock, alu1_din, alu_a, alu_b, alu_src, alu_op, alu_dest, alu1_cin,
        alu1_yout, alu1_cout, alu1_f0, alu1_f3, alu1_ovr,
        alu1_q0_in, alu1_ram0_in, alu1_q3_in, alu1_ram3_in,
        alu1_q0_out, alu1_ram0_out, alu1_q3_out, alu1_ram3_out);

    assign alu1_q0_in = alu0_q3_out;
    assign alu1_ram0_in = alu0_ram3_out;
    assign alu0_q3_in = alu1_q0_out;
    assign alu0_ram3_in = alu1_ram0_out;

    // TBD H6 mux rotate left, rotate right
    assign alu1_q3_in = 0;
    assign alu1_ram3_in = 0;
    assign alu0_q0_in = 0;
    assign alu0_ram0_in = 0;

    // Decoders
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
    reg [7:0] DPBus;
    reg [7:0] FBus;

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
        case (shift_carry)
            0: alu0_cin = 0;
            1: alu0_cin = 1;
            2: alu0_cin = flags_register[3];
            3: alu0_cin = 0;
        endcase

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

        // 74LS139 (D2), 74LS138 (D3)
        case (d2d3)
            0: DPBus = swap_register;
            1: DPBus = reg_ram_data_out;
            2: DPBus = { ~memory_address[15:12], memory_address[11:8] };
            3: DPBus = memory_address[7:0];
            4: ;
            5: ;
            6: ;
            7: ;
            8: ; // DPBus = translated address hi, 17:11 (17 down), and top 3 bits together
            9: DPBus = { ~condition_codes[3:0], 4'b0000 }; // low nibble is sense switches
            10: DPBus = bus_read; // DPBus = (e7 == 3) ? dataInBus : bus_read;
            11: ; // read ILR (interrupt level register?) H14 4 bits, A8 4 bits current level
            12: ; // read switch 2 other half of dip switches and condition codes?
            13: DPBus = constant;
            14: ;
            15: ;
        endcase

        FBus = { alu1_yout, alu0_yout };
        if (h11 == 6) begin
            FBus = map_rom_data;
        end
    end

    // Guideline #1: When modeling sequential logic, use nonblocking 
    //              assignments.
    always @(posedge clock, posedge reset) begin
        if (reset == 1) begin
            work_address <= 0;
            memory_address <= 0;
            register_index <= 0;
            result_register <= 0;
            swap_register <= 0;
            condition_codes <= 0;
            flags_register <= 0;
            writeEnBus <= 0;
            pipeline <= 56'h42abc618b781c0; // First microcode word. Synth prefers it this way.
            uc_rom_address_pipe <= 0;
        end else begin
            pipeline <= uc_rom_data;
            uc_rom_address_pipe <= uc_rom_address;
            if (instruction_start == 1) begin
                cycle_counter <= 1;
            end else begin
                cycle_counter <= cycle_counter + 1;
            end

            // 74LS138
            case (e6)
                0: ;
                1: result_register <= FBus;
                2: register_index <= FBus; // uC bit 53 might simplify 16 bit register write
                3: ; // load D9
                4: ; // load page table base register
                5: memory_address <= work_address;
                6: ; // load AR on 2909s, see above
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

            // 74LS138 (only half used)            
            case (e7)
                0: ;
                1: ;
                2: flags_register <= { 1'b0, 1'b0, flags_register[0], alu0_cout, alu1_cout, alu1_ovr, alu1_f3, alu0_f0 & alu1_f0 };
                3: bus_read <= dataInBus;
            endcase

            // 74LS138
            case (h11)
                0: ;
                1: ; // Begin bus read cycle
                2: ; // Begin bus write cycle
                3: // Load work_address high byte
                    begin
                        work_address[15:8] <= result_register;
                        if (e6 == 5) begin
                            work_address[15:8] <= memory_address[15:8];
                        end
                    end
                4: work_address <= work_address + 1; // WAR increment
                5: memory_address <= memory_address + 1; // MAR increment
                6: ; // Select FBus source (combinational)
                7: swap_register <= { DPBus[3:0], DPBus[7:4] };
            endcase

            writeEnBus = 0;

            // 74LS138
            case (k11)
                0: ;
                1: ;
                2: ;
                3: ; // enable F11 addressable latch, machine state, bus state, A0-2 on F11 are B1-3 and D input is B0
                4: ;
                5: ;
                6: // Load work_address low byte
                    begin
                        work_address[7:0] <= result_register;
                        if (e6 == 5) begin
                            work_address[7:0] <= memory_address[7:0];
                        end
                    end
                7: writeEnBus <= 1;
            endcase
        end
    end
endmodule
