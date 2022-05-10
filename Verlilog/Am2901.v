
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
        if (aluSrc == 0) begin
            r = a;
            s = q;
        end if (aluSrc == 1) begin
            r = a;
            s = b;
        end if (aluSrc == 2) begin
            r = 0;
            s = q;
        end if (aluSrc == 3) begin
            r = 0;
            s = b;
        end if (aluSrc == 4) begin
            r = 0;
            s = a;
        end if (aluSrc == 5) begin
            r = din;
            s = a;
        end if (aluSrc == 6) begin
            r = din;
            s = q;
        end if (aluSrc == 7) begin
            r = din;
            s = 0;
        end

        f = 0;
        if (aluOp == 0) begin
            f = r + s + cin;
        end if (aluOp == 1) begin
            f = s + ((~r) & 4'hf) + cin;
        end if (aluOp == 2) begin
            f = r + ((~s) & 4'hf) + cin;
        end if (aluOp == 3) begin
            f = r | s;
        end if (aluOp == 4) begin
            f = r & s;
        end if (aluOp == 5) begin
            f = (~r) + s;
        end if (aluOp == 6) begin
            f = r ^ s;
        end if (aluOp == 7) begin
            f = ~(r ^ s);
        end

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
        if (aluDest == 0) begin
            yout = fvalue;
            qv = fvalue;
            writeQ = 1;
        end if (aluDest == 1) begin
            yout = fvalue;
        end if (aluDest == 2) begin
            yout = a;
            bv = fvalue;
            writeRam = 1;
        end if (aluDest == 3) begin
            yout = fvalue;
            bv = fvalue;
            writeRam = 1;
        end if (aluDest == 4) begin
            yout = fvalue;
            qv = q >> 1;
            bv = fvalue >> 1;
            writeRam = 1;
            writeQ = 1;
        end if (aluDest == 5) begin
            yout = fvalue;
            bv = fvalue >> 1;
            writeRam = 1;
        end if (aluDest == 6) begin
            yout = fvalue;
            qv = q << 1;
            bv = fvalue << 1;
            writeRam = 1;
            writeQ = 1;
        end if (aluDest == 7) begin
            yout = fvalue;
            bv = fvalue << 1;
            writeRam = 1;
        end
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
