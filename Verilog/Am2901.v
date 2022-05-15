
module Am2901(input wire clock, input wire [3:0] din, input wire [3:0] aSel,
    input wire [3:0] bSel, input wire [2:0] aluSrc, input wire [2:0] aluOp,
    input wire [2:0] aluDest, input cin, output reg[3:0] yout, output reg cout,
    output reg fzero, output reg f3, output reg ovr);

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

        case (aluOp)
            0: f = r + s + cin;
            1: f = s + ((~r) & 4'hf) + cin;
            2: f = r + ((~s) & 4'hf) + cin;
            3: f = r | s;
            4: f = r & s;
            5: f = (~r) & s;
            6: f = r ^ s;
            7: f = ~(r ^ s);
            default: f = 0;
        endcase

        cout = f[4];
        fzero = 0;
        if (f[3:0] == 0) begin
            fzero = 1;
        end
        f3 = f[3];

        // TODO: compute ovr
        ovr = 0;
        
        qv = 0;
        bv = 0;
        writeQ = 0;
        writeRam = 0;
        fvalue = f[3:0];

        case (aluDest)
            0: begin yout = fvalue; qv = fvalue; writeQ = 1; end
            1: begin yout = fvalue; end
            2: begin yout = a; bv = fvalue; writeRam = 1; end
            3: begin yout = fvalue; bv = fvalue; writeRam = 1; end
            4: begin yout = fvalue; qv = q >> 1; bv = fvalue >> 1; writeRam = 1; writeQ = 1; end
            5: begin yout = fvalue; bv = fvalue >> 1; writeRam = 1; end
            6: begin yout = fvalue; qv = q << 1; bv = fvalue << 1; writeRam = 1; writeQ = 1; end
            7: begin yout = fvalue; bv = fvalue << 1; writeRam = 1; end
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
