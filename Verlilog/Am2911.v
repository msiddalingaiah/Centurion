
module Am2911(input wire clock, input wire [3:0] din,
    input wire s0, input wire s1, input wire zero, input wire cin, input wire re, input wire fe,
    input wire pup, output reg [3:0] yout, output reg cout);

    integer i;
    initial begin
        pc = 0;
        ar = 0;
        sp = 3;
        yout = 0;
        cout = 0;
        mux = 0;
        stackWr = 0;
        for (i=0;i<4;i=i+1) stack[i] = 0;
    end

    reg [3:0] pc;
    reg [3:0] ar;
    reg [1:0] sp, stackAddr;
    reg [3:0] mux;
    reg stackWr;
    reg [3:0] stack[0:3];

    always @(*) begin
        mux = 0;
        if ((s1 == 0) && (s0 == 0)) begin
            mux = pc;
        end
        if ((s1 == 0) && (s0 == 1)) begin
            mux = ar;
        end
        if ((s1 == 1) && (s0 == 0)) begin
            mux = stack[stackAddr];
        end
        if ((s1 == 1) && (s0 == 1)) begin
            mux = din;
        end
        if (zero == 0) begin
            yout = 0;
        end else begin
            yout = mux;
        end
        cout = 0;
        if (yout == 4'hf) begin
            cout = 1;
        end
        
        stackWr = 0;
        if (fe == 0) begin
            stackWr = 0;
            if (pup == 1) begin
                stackWr = 1;
                // Lookahead to pre-increment stack pointer
                stackAddr = sp + 1;
            end else begin
                stackAddr = sp;
            end
        end
    end

    always @(posedge clock) begin
        pc <= yout;
        if (cin == 1) begin
            pc <= yout + 1;
        end
        if (re == 0) begin
            ar <= din;
        end
        if (fe == 0) begin
            if (pup == 1) begin
                sp <= sp + 1;
            end else begin
                sp <= sp - 1;
            end
        end
        if (stackWr == 1) begin
            stack[stackAddr] <= pc;
        end
    end
endmodule
