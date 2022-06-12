
# $scope module CPU6TestBench $end
# $var wire 1 ! writeEnBus $end
# $var wire 8 " data_r2c [7:0] $end

from collections import defaultdict

class SignalDef(object):
    def __init__(self, module, cols):
        self.module = module
        self.size, self.tag, self.name = 0, '', ''
        if len(cols) < 4:
            return
        self.size, self.tag, self.name = cols[2:2+3]

    def isValid(self):
        return self.size != 0

    def getName(self):
        return f'{self.module}.{self.name}'

    def __str__(self):
        return f'{self.getName()} {self.size} {self.tag}'

radixMap = {'b': 2}

class Signal(object):
    def __init__(self, time, sigDef, value):
        self.time = time
        self.sigDef = sigDef
        self.value = value

    def getName(self):
        return self.sigDef.getName()

    def getTag(self):
        return self.sigDef.tag

    def __str__(self):
        return self.value

class VCDFile(object):
    def __init__(self, fname):
        self.signalTagMap = {}
        self.signalMap = {}
        self.signals = []
        with open(fname) as f:
            content = f.read()
        lines = content.split('\n')
        index = 0
        while index < len(lines):
            line = lines[index]
            index += 1
            if line == '$dumpvars':
                break
            cols = line.split()
            if len(cols) > 0:
                if cols[0] == '$scope':
                    module = cols[2]
                if cols[0] == '$var':
                    sd = SignalDef(module, cols)
                    if sd.isValid():
                        self.signalMap[sd.tag] = sd
                        self.signalTagMap[sd.getName()] = sd.tag
        prevTime = -1
        time = 0
        signals = {}
        for tag, df in self.signalMap.items():
            sig = Signal(time, df, -1)
            signals[sig.getTag()] = sig
        while index < len(lines):
            line = lines[index]
            index += 1
            cols = line.split()
            if len(cols) > 0:
                # #5000
                if line[0] == '#':
                    time = int(line[1:])
                    if time != prevTime:
                        if len(signals):
                            self.signals.append(self.copy(signals))
                        prevTime = time
                else:
                    # b101 B"
                    # b101 :"
                    # b1000000000000010000001111111110011011000000000000000000 9
                    # 1$
                    if len(cols) > 1 and cols:
                        valueStr = cols[0]
                        value = -1
                        if 'x' not in valueStr[1:]:
                            value = int(valueStr[1:], radixMap[valueStr[0]])
                        sig = Signal(time, self.signalMap.get(cols[1]), value)
                        signals[sig.getTag()] = sig
                    elif cols[0] != '$end':
                        valueStr = cols[0]
                        # print(valueStr)
                        value = -1
                        if 'x' not in valueStr[0]:
                            value = int(valueStr[0])
                        sig = Signal(time, self.signalMap.get(valueStr[1]), value)
                        signals[sig.getTag()] = sig

    def copy(self, sigs):
        result = {}
        for k, v in sigs.items():
            result[k] = v
        return result

e6Map = {0:'', 1:'RR<-FBus', 2:'RI<-FBus', 3:'', 4:'', 5:'MAR<->WAR', 6:'', 7:'LoadCC'}
k11Map = {0:'', 1:'', 2:'', 3:'Load F11', 4:'R[]<-', 5:'', 6:'WAR.LO<-', 7:'WrBus'}
pcIncMap = {0:'', 1:'PC++'}
d2d3Map = {0:'D=Swap', 1:'D=Reg', 2:'D=MAR.HI', 3:'D=MAR.LO', 4:'', 5:'', 6:'', 7:'', 8:'',
            9:'D=CC', 10:'D=BusIn', 11:'', 12:'', 13:'D=const', 14:'', 15:''}

ALU_SRC_MAP = [['A', 'Q'], ['A', 'B'], ['0', 'Q'], ['0', 'B'], ['0', 'A'], ['D', 'A'], ['D', 'Q'], ['D', '0']]
ALU_OP_MAP = ['{r}+{s}', '{s}-{r}', '{r}-{s}', '{r}|{s}', '{r}&{s}', '(~{r})&{s}', '{r}^{s}', '~({r}^{s})']
ALU_MEM_DEST_MAP = ['', '', 'r{b} = {f}', 'r{b} = {f}', 'r{b} = ({f})>>1', 'r{b} = ({f})>>1', 'r{b} = ({f})<<1', 'r{b} = ({f})<<1']
ALU_Q_DEST_MAP = ['Q = {f}', '', '', '', 'Q >>= 1', '', 'Q <<= 1', '']
ALU_OUT_MAP = ['Y = {f}', 'Y = {f}', 'Y = {a}', 'Y = {f}', 'Y = {f}', 'Y = {f}', 'Y = {f}', 'Y = {f}']


class Disassembler(object):
    def __init__(self, signals, signalTagMap):
        self.signals = signals
        self.signalTagMap = signalTagMap

    def getSignal(self, sig, name):
        tag = self.signalTagMap[name]
        return sig[tag]

    def getALUCode(self, aluA, aluB, aluOp, aluSrc, aluDest, cin):
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
        if (aluOp == 0 or aluOp == 1) and cin == 1:
            return f'{mem}+{cin} {q} {y}'
        return f'{mem} {q} {y}'

    def disassembleAll(self):
        code = []
        i = 0
        while i < len(self.signals):
            sig = self.signals[i]
            i += 1
            if self.getSignal(sig, 'cg0.clock').value == 1:
                instruction_start = self.getSignal(sig, 'cpu.instruction_start').value
                if instruction_start == 1:
                    code.append('')
                code.append(self.disassembleOne(sig))
        return code

    def disassembleOne(self, sig):
        clock = self.getSignal(sig, 'cg0.clock')
        addr = self.getSignal(sig, 'cpu.uc_rom_address').value
        e6 = self.getSignal(sig, 'cpu.e6').value
        k11 = self.getSignal(sig, 'cpu.k11').value
        h11 = self.getSignal(sig, 'cpu.h11').value
        pcInc = self.getSignal(sig, 'cpu.pc_increment').value
        d2d3 = self.getSignal(sig, 'cpu.d2d3').value
        constant = self.getSignal(sig, 'cpu.constant').value
        dataInBus = self.getSignal(sig, 'cpu.dataInBus').value
        map_rom_data = self.getSignal(sig, 'cpu.map_rom_data').value
        reg_ram_data_out = self.getSignal(sig, 'cpu.reg_ram_data_out').value
        register_index = self.getSignal(sig, 'cpu.register_index').value
        register_index = self.getSignal(sig, 'cpu.register_index').value
        FBus = self.getSignal(sig, 'cpu.FBus').value
        memory_address = self.getSignal(sig, 'cpu.memory_address').value
        result_register = self.getSignal(sig, 'cpu.result_register').value

        if k11 == 6:
            k11Map[6] = 'WAR.LO<-RR'
            if e6 == 5:
                k11Map[6] = 'WAR.LO<-MAR.LO'
        if h11 == 3:
            k11Map[6] = 'WAR.HI<-RR'
            if e6 == 5:
                k11Map[6] = 'WAR.HI<-MAR.HI'
        if d2d3 == 1:
            d2d3Map[1] = f'D=R[{register_index:02x}]({reg_ram_data_out:02x})'
        if d2d3 == 10:
            d2d3Map[10] = f'D=Bus({dataInBus:02x})'
        if d2d3 == 13:
            d2d3Map[13] = f'D={constant:02x}'
        fbr = 'FBus=Y'
        if h11 == 6:
            fbr = f'FBus=Map({map_rom_data:02x})'
        if e6 == 1:
            e6Map[1] = f'RR<-FBus({FBus:02x})'
        if e6 == 2:
            e6Map[2] = f'RI<-FBus({FBus:02x})'
        if pcInc == 1:
            pcIncMap[1] = f'PC++({memory_address:04x})'
        if k11 == 4:
            k11Map[4] = f'R[{register_index:02x}]<-RR({result_register:02x})'
        alu_a = self.getSignal(sig, 'cpu.alu_a').value
        alu_b = self.getSignal(sig, 'cpu.alu_b').value
        alu_src = self.getSignal(sig, 'cpu.alu_src').value
        alu_op = self.getSignal(sig, 'cpu.alu_op').value
        alu_dest = self.getSignal(sig, 'cpu.alu_dest').value
        alu0_cin = self.getSignal(sig, 'cpu.alu0_cin').value
        aluCode = self.getALUCode(alu_a, alu_b, alu_op, alu_src, alu_dest, alu0_cin)

        return f'{int(clock.time/100)} {addr:03x}: {d2d3Map[d2d3]} {aluCode} {fbr}  /\\  {e6Map[e6]} {k11Map[k11]} {pcIncMap[pcInc]}'

if __name__ == '__main__':
    vcd = VCDFile('vcd/CPUTestBench.vcd')
    dis = Disassembler(vcd.signals, vcd.signalTagMap)
    code = dis.disassembleAll()
    with open('vcd/CPUTestBench.txt', 'wt') as f:
        for c in code:
            f.write(f'{c}\n')
