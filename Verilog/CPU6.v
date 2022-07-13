
`include "Am2909.v"
`include "Am2911.v"
`include "Am2901.v"
`include "CodeROM.v"
`include "MapROM.v"
`include "RegisterRAM.v"

`ifdef TRACE_I
    `include "Instructions.v"
`endif

module CPU6(input wire reset, input wire clock, input wire [7:0] dataInBus,
    output reg writeEnBus, output wire [15:0] addressBus, output wire [7:0] dataOutBus);

    initial begin
        cycle_counter = 0;
    end

    assign addressBus = memory_address;
    assign dataOutBus = bus_write;

    /*
     * Instrumentation
     */

    wire instruction_start = uc_rom_address_pipe == 11'h101;
    reg [31:0] cycle_counter;
    assign pc_increment = h11 == 5 ? 1 : 0;
    reg [10:0] uc_rom_address_pipe;

    `ifdef TRACE_I
        Instructions inst_map();
    `endif

    /*
     * Rising edge triggered registers
     */
    // Microcode pipeline F5/H5/J5/K5/L5/M5 74LS377, E5/D5 74LS174
    reg [55:0] pipeline;
    // work_address B2/C2/B5/C5 74LS669
    reg [15:0] work_address;
    // memory_address B1/C1/B6/C6 74LS669
    reg [15:0] memory_address;
    // register_index C13 74LS377
    reg [7:0] register_index;
    // result_register C9 74LS377
    reg [7:0] result_register;
    // swap_register C12/C11 74LS173
    reg [7:0] swap_register;
    // flags_register J9 74LS378
    reg [7:0] flags_register;
    // condition_codes M12 74LS378
    reg [3:0] condition_codes;
    // bus_read, bus_write A11/A12 Am2907
    reg [7:0] bus_read, bus_write;
    // interrupt_level D9 74LS378
    reg [7:0] interrupt_level;
    // write delay
    reg writEnDelayed;

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
    // High/low register select, C14 74LS157 mux, D10 74LS02 NOR gate
    wire [3:0] reg_addr_hi = pipeline[55] ? interrupt_level[7:4] : register_index[7:4];
    wire [7:0] reg_ram_addr = { reg_addr_hi, register_index[3:1], ~(reg_low_select | register_index[0]) };
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

    // F9 Am2901 ALU 0 (bits 3:0)
    wire [3:0] alu0_din = DPBus[3:0];
    reg alu0_cin;
    wire [3:0] alu0_yout;
    wire alu0_cout;
    wire alu0_f0;
    wire alu0_f3;
    wire alu0_ovr;
    reg alu0_q0_in;
    wire alu0_ram0_in, alu0_q3_in, alu0_ram3_in;
    wire alu0_q0_out, alu0_ram0_out, alu0_q3_out, alu0_ram3_out;
    Am2901 alu0(clock, alu0_din, alu_a, alu_b, alu_src, alu_op, alu_dest, alu0_cin,
        alu0_yout, alu0_cout, alu0_f0, alu0_f3, alu0_ovr,
        alu0_q0_in, alu0_ram0_in, alu0_q3_in, alu0_ram3_in,
        alu0_q0_out, alu0_ram0_out, alu0_q3_out, alu0_ram3_out);

    // F7 Am2901 ALU 1 (bits 7:4)
    wire [3:0] alu1_din = DPBus[7:4];
    wire alu1_cin = alu0_cout;
    wire [3:0] alu1_yout;
    wire alu1_cout;
    wire alu1_f0;
    wire alu1_f3;
    wire alu1_ovr;
    wire alu1_q0_in, alu1_ram0_in, alu1_q3_in;
    wire alu1_q0_out, alu1_ram0_out, alu1_q3_out, alu1_ram3_out;
    reg alu1_ram3_in;
    Am2901 alu1(clock, alu1_din, alu_a, alu_b, alu_src, alu_op, alu_dest, alu1_cin,
        alu1_yout, alu1_cout, alu1_f0, alu1_f3, alu1_ovr,
        alu1_q0_in, alu1_ram0_in, alu1_q3_in, alu1_ram3_in,
        alu1_q0_out, alu1_ram0_out, alu1_q3_out, alu1_ram3_out);

    wire alu_i7 = alu_dest[1];

    assign alu1_q0_in = alu0_q3_out;
    assign alu1_ram0_in = alu0_ram3_out;
    assign alu0_q3_in = alu1_q0_out;
    assign alu0_ram3_in = alu1_ram0_out;

    assign alu1_q3_in = alu0_ram0_out;
    assign alu0_ram0_in = alu1_q3_out;

    // Decoders
    // d2d3 is decoded before pipeline, but outputs are registered.
    wire [3:0] d2d3 = pipeline[3:0];
    wire [1:0] e7 = pipeline[14:13];
    wire [2:0] h11 = pipeline[12:10];
    wire [2:0] k11 = pipeline[9:7];
    wire [2:0] e6 = pipeline[6:4];

    // Muxes

    // J10 Link/carry mux 74LS151
    wire j10_enable = pipeline[21];
    wire [2:0] j10 = pipeline[24:22];
    reg cc_l;

    // J11 Fault/overflow mux 74LS151
    wire j11_enable = pipeline[18];
    wire [2:0] j11 = { flags_register[2], pipeline[20:19] };
    reg cc_f;

    // J12 Minus/sign mux 74LS153
    wire [1:0] j12 = pipeline[17:16];
    reg cc_m, cc_v;

    // F6 ALU carry in mux 74LS153 (half used)
    // H6 ALU shift mux
    wire [1:0] f6h6 = pipeline[52:51];

    // K9 JSR mux 74151
    wire k9_enable = pipeline[15];
    wire [2:0] k9 = pipeline[18:16];

    // J13 OR0/OR1 mux 74LS153
    wire [1:0] j13 = pipeline[21:20];

    // K13 OR2/OR3 mux 74LS153
    wire [1:0] k13 = pipeline[23:22];

    // Constant (immediate data)
    wire [7:0] constant = ~pipeline[16+7:16];

    // Internal Busses
    reg [7:0] DPBus;
    reg [7:0] FBus;


    // Guideline #3: When modeling combinational logic with an "always" 
    //              block, use blocking assignments.
    always @(*) begin
        jsr_ = 1; // Inverted output
        if (k9_enable == 0) begin
            case (k9)
                0: ; // Bus busy
                1: jsr_ = register_index[0] | register_index[4];
                2: jsr_ = ~register_index[0];
                3: ; // NOT.MEM
                4: ; // DMA?
                5: ; // DMA interrupt active
                6: ; // Parity error
                7: ; // Interrupt
            endcase
        end

        // Carry in
        alu0_cin = 0;
        case (f6h6)
            0: alu0_cin = 0;
            1: alu0_cin = 1;
            2: alu0_cin = flags_register[3];
            3: alu0_cin = 0;
        endcase

        // Rotate
        alu1_ram3_in = 0;
        alu0_q0_in = 0;
        if (alu_i7 == 0) begin
            // Right shift
            case (f6h6)
                0: alu1_ram3_in = alu1_f3;
                1: alu1_ram3_in = flags_register[3];
                2: alu1_ram3_in = alu0_q0_out;
                3: alu1_ram3_in = alu1_cout;
            endcase
        end else begin
            // Left shift
            case (f6h6)
                0: alu0_q0_in = 0;
                1: alu0_q0_in = flags_register[3];
                2: alu0_q0_in = alu1_f3;
                3: alu0_q0_in = 1;
            endcase
        end

        cc_l = 0;
        if (j10_enable == 0) begin
            case (j10)
                0: cc_l = condition_codes[3];
                1: cc_l = ~condition_codes[3];
                2: cc_l = flags_register[3];
                3: cc_l = 0;
                4: cc_l = result_register[4];
                5: cc_l = alu1_ram3_in;
                6: cc_l = alu_i7 ? alu1_q3_out : alu0_ram0_out;
                7: cc_l = alu0_q0_in;
            endcase
        end

        cc_f = 0;
        if (j11_enable == 0) begin
            case (j11)
                0: cc_f = result_register[5];
                1: cc_f = 1;
                2: cc_f = condition_codes[2];
                3: cc_f = 0;
                4: cc_f = result_register[5];
                5: cc_f = 1;
                6: cc_f = condition_codes[2];
                7: cc_f = 1;
            endcase
        end

        cc_m = 0;
        cc_v = 0;
        case (j12)
            0: begin cc_m = condition_codes[1]; cc_v = 0; end
            1: begin cc_m = flags_register[1]; cc_v = flags_register[0]; end
            2: begin cc_m = result_register[6]; cc_v = result_register[7]; end
            3: begin cc_m = flags_register[1]; cc_v = flags_register[0] & flags_register[5]; end
        endcase

        seq0_orin = 0;
        if (case_ == 0) begin
            case (j13)
                0: begin seq0_orin[0] = flags_register[1]; seq0_orin[1] = flags_register[0]; end
                1: begin seq0_orin[0] = flags_register[4]; seq0_orin[1] = flags_register[2]; end
                2: ; // OR0 = PA18; OR1 = BAD.PG;
                3: ; // Not used
            endcase
            case (k13)
                0: seq0_orin[3] = condition_codes[3]; // OR2 = INT.EN;
                1: ; // OR2 = LVL15.Q; OR3 = INTR.Q;
                2: ; // OR2 = E10.6.Q; OR3 = DMA13.Q;
                3: ; // Not used
            endcase
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
            4: DPBus = swap_register;
            5: DPBus = reg_ram_data_out;
            6: DPBus = { ~memory_address[15:12], memory_address[11:8] };
            7: DPBus = memory_address[7:0];
            8: ; // DPBus = translated address hi, 17:11 (17 down), and top 3 bits together
            9: DPBus = { ~condition_codes[0], ~condition_codes[1], ~condition_codes[2], ~condition_codes[3], 4'b0000 }; // low nibble is sense switches
            10: DPBus = bus_read; // DPBus = (e7 == 3) ? dataInBus : bus_read;
            11: DPBus = 8'h0f; // read ILR (interrupt level register?) { A8 4 bits, H14 4 bits }
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
            writEnDelayed <= 0;
            pipeline <= 56'h42abc618b781c0; // First microcode word. Synth prefers it this way.
            uc_rom_address_pipe <= 0;
            interrupt_level <= 0;
            bus_read <= 0;
            bus_write <= 0;
        end else begin
            pipeline <= uc_rom_data;
            uc_rom_address_pipe <= uc_rom_address;
            if (instruction_start == 1) begin
                cycle_counter <= 1;
            end else begin
                cycle_counter <= cycle_counter + 1;
            end

            `ifdef TRACE_I
                if (uc_rom_address_pipe == 11'h103) begin
                    $display("%x F:%x C:%x A:%x%x B:%x%x X:%x%x Y:%x%x Z:%x%x S:%x%x C:%x%x | %x%s",
                        memory_address-1, flags_register, condition_codes,
                        reg_ram.memory[1], reg_ram.memory[0],
                        reg_ram.memory[3], reg_ram.memory[2],
                        reg_ram.memory[5], reg_ram.memory[4],
                        reg_ram.memory[7], reg_ram.memory[6],
                        reg_ram.memory[9], reg_ram.memory[8],
                        reg_ram.memory[11], reg_ram.memory[10],
                        reg_ram.memory[13], reg_ram.memory[12],
                        DPBus, inst_map.instruction_map[DPBus]);
                end
            `endif
            `ifdef TRACE_UC
                if (jsr_ == 0) begin
                    $display("        uC %x JSR %x%x%x", uc_rom_address_pipe, seq2_din, seq1_din, seq0_din);
                end
                if (seq0_orin != 0) begin
                    $display("        uC %x OR %x -> %x", uc_rom_address_pipe, seq0_orin, uc_rom_address | seq0_orin);
                end
                if (k11 == 3) begin
                    $display("        uC F11.%d <= %d", alu_b[3:1], alu_b[0]);
                end
            `endif
            `ifdef TRACE_WR
                if (writeEnBus == 1) begin
                    $display("    WR %x %x", memory_address, bus_write);
                end
            `endif
            `ifdef TRACE_RD
                if (e7 == 3) begin
                    $display("    RD %x %x", memory_address, dataInBus);
                end
            `endif

            // 74LS138
            case (e6)
                0: ;
                1: result_register <= FBus;
                2: register_index <= FBus; // uC bit 53 might simplify 16 bit register write
                3: interrupt_level <= FBus; // load D9
                4: ; // load page table base register
                5: memory_address <= work_address;
                6: ; // load AR on 2909s, see above
                7: condition_codes <= { cc_l, cc_f, cc_m, cc_v } ; // load condition code register M12
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

            writeEnBus <= writEnDelayed;
            writEnDelayed <= 0;

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
                7: begin bus_write <= FBus; writEnDelayed <= 1; end
            endcase
        end
    end
endmodule
