
module Am2901(input wire clock, input wire [3:0] din, input wire [3:0] aSel,
    input wire [3:0] bSel, input wire [2:0] aluSrc, input wire [2:0] aluOp,
    input wire [2:0] aluDest, input cin, output reg[3:0] yout, output reg cout,
    output reg fzero, output reg f3, output reg ovr,
    input wire q0_in, input wire ram0_in, input wire q3_in, input wire ram3_in,
    output reg q0_out, output reg ram0_out, output reg q3_out, output reg ram3_out);

    integer i;
    initial begin
        for (i=0;i<16;i=i+1) regs[i] = 0;
        q = 0;
    end

    reg [3:0] regs[0:15];
    reg [3:0] q;
    reg [4:0] f;
    reg writeRam;
    reg writeQ;

    reg [3:0] a;
    reg [3:0] b;
    reg [3:0] r;
    reg [3:0] s;
    reg [3:0] qv;
    reg [3:0] bv;
    reg [3:0] fvalue;
    reg [3:0] p, g;
    reg c3, c4;

    always @(*) begin
        a = regs[aSel];
        b = regs[bSel];
        r = 0;
        s = 0;

        case (aluSrc)
            0: begin r = a; s = q; end
            1: begin r = a; s = b; end
            2: begin r = 0; s = q; end
            3: begin r = 0; s = b; end
            4: begin r = 0; s = a; end
            5: begin r = din; s = a; end
            6: begin r = din; s = q; end
            7: begin r = din; s = 0; end
            default: ;
        endcase

        p = r | s;
        g = r & s;

        case (aluOp)
            0: ;
            1: begin p = (~r) | s; g = (~r) & s; end
            2: begin p = r | (~s); g = r & (~s); end
            3: ;
            4: ;
            5: begin p = (~r) | s; g = (~r) & s; end
            6: ;
            7: ;
        endcase

        c4 = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0]) | (p[3] & p[2] & p[1] & p[0] & cin);
        c3 = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) | (p[2] & p[1] & p[0] & cin);

        ovr = 0;

        case (aluOp)
            0: begin f = r + s + cin; ovr = c3 ^ c4; end
            1: begin f = s + ((~r) & 4'hf) + cin; ovr = c3 ^ c4; end
            2: begin f = r + ((~s) & 4'hf) + cin; ovr = c3 ^ c4; end
            3: begin f = r | s; ovr = (~(p[3]&p[2]&p[1]&p[0])) | cin; end
            4: begin f = r & s; ovr = g[3]|g[2]|g[1]|g[0] | cin; end
            5: begin f = (~r) & s; ovr = g[3]|g[2]|g[1]|g[0] | cin; end
            6: begin f = r ^ s; end
            7: begin f = ~(r ^ s); end
        endcase

        cout = f[4];
        fzero = 0;
        if (f[3:0] == 0) begin
            fzero = 1;
        end
        f3 = f[3];
        
        qv = 0;
        bv = 0;
        writeQ = 0;
        writeRam = 0;
        fvalue = f[3:0];

        q0_out = q[0];
        ram0_out = fvalue[0];
        q3_out = q[3];
        ram3_out = fvalue[3];

        case (aluDest)
            0: begin yout = fvalue; qv = fvalue; writeQ = 1; end
            1: begin yout = fvalue; end
            2: begin yout = a; bv = fvalue; writeRam = 1; end
            3: begin yout = fvalue; bv = fvalue; writeRam = 1; end
            4: begin yout = fvalue; qv = { q3_in, q[3:1] }; bv = { ram3_in, fvalue[3:1] }; writeRam = 1; writeQ = 1; end
            5: begin yout = fvalue; bv = { ram3_in, fvalue[3:1] }; writeRam = 1; end
            6: begin yout = fvalue; qv = { q[2:0], q0_in }; bv = { fvalue[2:0], ram0_in }; writeRam = 1; writeQ = 1; end
            7: begin yout = fvalue; bv = { fvalue[2:0], ram0_in }; writeRam = 1; end
        endcase
    end

    always @(posedge clock) begin
        if (writeQ == 1) begin
            q <= qv;
        end
        if (writeRam == 1) begin
            regs[bSel] <= bv;
        end
    end
endmodule
