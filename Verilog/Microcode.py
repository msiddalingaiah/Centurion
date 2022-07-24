
from collections import defaultdict

ALU_SRC_MAP = [['A', 'Q'], ['A', 'B'], ['0', 'Q'], ['0', 'B'], ['0', 'A'], ['D', 'A'], ['D', 'Q'], ['D', '0']]
ALU_OP_MAP = ['{r}+{s}', '{s}-{r}', '{r}-{s}', '{r}|{s}', '{r}&{s}', '(~{r})&{s}', '{r}^{s}', '~({r}^{s})']
ALU_MEM_DEST_MAP = ['', '', 'r{b}={f}', 'r{b}={f}', 'r{b}=({f})>>1', 'r{b}=({f})>>1', 'r{b}=({f})<<1', 'r{b} =({f})<<1']
ALU_Q_DEST_MAP = ['Q = {f}', '', '', '', 'Q>>=1', '', 'Q<<=1', '']
ALU_OUT_MAP = ['Y={f}', 'Y={f}', 'Y={a}', 'Y={f}', 'Y={f}', 'Y={f}', 'Y={f}', 'Y={f}']

class MicroCode(object):
    def __init__(self):
        with open('roms/CodeROM.txt') as f:
            lines = f.readlines()
            self.code = [int(line, 16) for line in lines]
            self.selects = defaultdict(int)

    def getBits(self, word, start, size):
        return (word >> start) & (~(-1 << size))

    def disassemble(self):
        for addr, word in enumerate(self.code):
            self.disassembleOne(addr, word)
        print()
        print('Mux select distribution')
        for name, value in self.selects.items():
            print(f'{name:3x}: {value}')

    def disassembleOne(self, addr, word):
        if word == 0:
            print(f'{addr:3x} {word:14x} unused')
            return
        seq0_din = self.getBits(word, 16, 4)
        seq0_s = ~self.getBits(word, 29, 2) & 3
        seq1_din = self.getBits(word, 20, 4)
        seq1_s = ~self.getBits(word, 29, 2) & 3 # pipeline 54
        seq2_din = self.getBits(word, 24, 3)
        s0 = ~self.getBits(word, 31, 1) & 1
        p32 = self.getBits(word, 32, 1)
        p54 = self.getBits(word, 54, 1)
        s1 = ~(~(p54 & (~p32 & 1) & 1)) & 1
        seq2_s = s1 << 1 | s0
        case_ = self.getBits(word, 33, 1)
        j13 = self.getBits(word, 20, 2)
        k13 = self.getBits(word, 22, 2)
        dest = (seq2_din << 8) | (seq1_din << 4) | seq0_din
        s1s0 = (seq2_s << 8) | (seq1_s << 4) | seq0_s
        self.selects[s1s0] += 1
        next = addr + 1
        if case_ == 0:
            # flags   zHCVMZ
            if s1s0 == 0x033:
                dest = (next & 0xf00) | (dest & 0x0ff)
            elif s1s0 == 0x233:
                pass # TODO: high nibble is AR (happens once)
            elif s1s0 == 0x233:
                pass # TODO: high nibble is stack (rare case)
            jump = f'jump {dest:3x}'
            if j13 == 0:
                jump = f'switch flags(ZM) jump {dest|0:x}, {dest|1:x}, {dest|2:x}, {dest|3:x}'
            elif j13 == 1:
                jump = f'switch flags(VH) jump {dest|0:x}, {dest|1:x}, {dest|2:x}, {dest|3:x}'
        else:
            fe = self.getBits(word, 27, 1)
            pup = self.getBits(word, 28, 1)
            jump = ''
            if fe == 0:
                if pup == 1:
                    jump = f'push {next:x} '
                elif s1s0 == 0x222:
                    jump = f'ret '
            if s1s0 == 0x333:
                jump = f'{jump}jump {dest:3x}'
            elif s1s0 == 0x111:
                jump = f'{jump}jump AR'
            elif s1s0 == 0x033:
                dest = (next & 0xf00) | (dest & 0x0ff)
                jump = f'{jump}jump {dest:3x}'
            elif s1s0 == 0x133:
                dest = dest & 0x0ff
                jump = f'{jump}jump AR|{dest:3x}'
            elif s1s0 == 0x311:
                dest = dest & 0xf00
                jump = f'{jump}jump {dest:3x}|AR|AR'
            elif s1s0 == 0x300:
                dest = (dest & 0xf00) | (next & 0x0ff)
                jump = f'{jump}jump {dest:3x}'
            elif s1s0 != 0 and s1s0 != 0x222:
                jump = f'{jump}jump somewhere mux: {s1s0:3x}'
        dpBus = self.getDPBus(word)
        aluOp = self.getALUCode(word)
        fBus = self.getFBus(word)
        print(f'{addr:3x}: {dpBus} {aluOp} {fBus} {jump}')

    def getDPBus(self, word):
        d2d3 = self.getBits(word, 0, 4)
        constant = ~self.getBits(word, 16, 8) & 0xff
        if d2d3 == 0:
            return f'D=swap'
        elif d2d3 == 1:
            return f'D=reg_ram'
        elif d2d3 == 2:
            return f'D=mar_hi'
        elif d2d3 == 3:
            return f'D=mar_lo'
        elif d2d3 == 4:
            return f'D=swap'
        elif d2d3 == 5:
            return f'D=reg_ram'
        elif d2d3 == 6:
            return f'D=mar_hi'
        elif d2d3 == 7:
            return f'D=mar_lo'
        elif d2d3 == 8:
            return ''
        elif d2d3 == 9:
            return 'D=CC'
        elif d2d3 == 10:
            return 'D=bus_read'
        elif d2d3 == 11:
            return 'D=ILR?'
        elif d2d3 == 12:
            return 'D=dips?'
        elif d2d3 == 13:
            return f'D={constant:x}'
        elif d2d3 == 14:
            return ''
        elif d2d3 == 15:
            return ''

    def getFBus(self, word):
        h11 = self.getBits(word, 10, 3)
        if h11 == 6:
            return 'F=map_rom'
        return 'F=Y'

    def getALUCode(self, word):
        aluA = self.getBits(word, 47, 4)
        aluB = self.getBits(word, 43, 4)
        aluSrc = self.getBits(word, 34, 3)
        aluOp = self.getBits(word, 37, 3)
        aluDest = self.getBits(word, 40, 3)
        cin = 0
        cout = 0
        r, s = ALU_SRC_MAP[aluSrc]
        if r == 'A':
            r = f'r{aluA}'
        elif r == 'B':
            r = f'r{aluB}'
        if s == 'A':
            s = f'r{aluA}'
        elif s == 'B':
            s = f'r{aluB}'
        f = ALU_OP_MAP[aluOp].format(r=r, s=s)
        mem = ALU_MEM_DEST_MAP[aluDest].format(b=aluB, f=f)
        q = ALU_Q_DEST_MAP[aluDest].format(f=f)
        a = f'r{aluA}'
        y = ALU_OUT_MAP[aluDest].format(f=f, a=a)
        c = ''
        if cout:
            c = 'C'
        if (aluOp == 0 or aluOp == 1 or aluOp == 2) and cin:
            return f'{mem}+{cin} {q} {y}+{cin} {c}'
        return f'{mem} {q} {y} {c}'

if __name__ == '__main__':
    mc = MicroCode()
    mc.disassemble()
