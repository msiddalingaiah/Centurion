
from collections import defaultdict

OP_CODES = {
    0x0: 'HLT', 0x1: 'NOP', 0x2: 'SF', 0x3: 'RF', 0x4: 'EI', 0x5: 'DI', 0x6: 'SL', 0x7: 'RL', 0x8: 'CL',
    0x9: 'RSR', 0x0A: 'RI', 0x0B: 'RIM', 0x0C: 'ELO', 0x0D: 'PCX', 0x0E: 'DLY', 0x0F: 'RSYS', 0x10: 'BL',
    0x11: 'BNL', 0x12: 'BF', 0x13: 'BNF', 0x14: 'BZ', 0x15: 'BNZ', 0x16: 'BM', 0x17: 'BP', 0x18: 'BGZ',
    0x19: 'BLE', 0x1A: 'BS1', 0x1B: 'BS2', 0x1C: 'BS3', 0x1D: 'BS4', 0x1E: 'BTM?', 0x1F: 'BEP?', 0x20: 'INR',
    0x21: 'DCR', 0x22: 'CLR', 0x23: 'IVR', 0x24: 'SRR', 0x25: 'SLR', 0x26: 'RRR', 0x27: 'RLR', 0x28: 'INAL',
    0x29: 'DCAL', 0x2A: 'CLAL', 0x2B: 'IVAL', 0x2C: 'SRAL', 0x2D: 'SLAL', 0x2E: '?', 0x2F: '?', 0x30: 'INR',
    0x31: 'DCR', 0x32: 'CLR', 0x33: 'IVR', 0x34: 'SRR', 0x35: 'SLR', 0x36: 'RRR', 0x37: 'RLR', 0x38: 'INAW',
    0x39: 'DCAW', 0x3A: 'CLAW', 0x3B: 'IVAW', 0x3C: 'SRAW', 0x3D: 'SLAW', 0x3E: 'INX', 0x3F: 'DCX',
    0x40: 'ADD', 0x41: 'SUB', 0x42: 'AND', 0x43: 'ORI', 0x44: 'ORE', 0x45: 'XFR', 0x46: '?', 0x47: '??',
    0x48: 'AABL', 0x49: 'SABL', 0x4A: 'NABL', 0x4B: 'XAXL', 0x4C: 'XAYL', 0x4D: 'XABL', 0x4E: 'XAZL',
    0x4F: 'XASL', 0x50: 'ADD', 0x51: 'SUB', 0x52: 'AND', 0x53: 'ORI', 0x54: 'ORE', 0x55: 'XFR', 0x56: '??',
    0x57: '??', 0x58: 'AABW', 0x59: 'SABW', 0x5A: 'NABW', 0x5B: 'XAXW', 0x5C: 'XAYW', 0x5D: 'XABW',
    0x5E: 'XAZW', 0x5F: 'XASW', 0x60: 'LDXW', 0x61: 'LDXW', 0x62: 'LDXW', 0x63: 'LDXW', 0x64: 'LDXW',
    0x65: 'LDXW', 0x66: 'JSYS', 0x67: '??', 0x68: 'STXW', 0x69: 'STXW', 0x6A: 'STXW', 0x6B: 'STXW',
    0x6C: 'STXW', 0x6D: 'STXW', 0x6E: 'LDCC', 0x6F: 'STCC', 0x70: 'JMP', 0x71: 'JMP', 0x72: 'JMP',
    0x73: 'JMP', 0x74: 'JMP', 0x75: 'JMP', 0x76: '??', 0x77: '??', 0x78: '??', 0x79: 'JSR', 0x7A: 'JSR',
    0x7B: 'JSR', 0x7C: 'JSR', 0x7D: 'JSR', 0x7E: 'PUSH', 0x7F: 'POP', 0x80: 'LDAL', 0x81: 'LDAL',
    0x82: 'LDAL', 0x83: 'LDAL', 0x84: 'LDAL', 0x85: 'LDAL', 0x86: '??', 0x87: '??', 0x88: 'LALA',
    0x89: 'LALB', 0x8A: 'LALX', 0x8B: 'LALY', 0x8C: 'LALZ', 0x8D: 'LALS', 0x8E: 'LALC', 0x8F: 'LALP',
    0x90: 'LDAW', 0x91: 'LDAW', 0x92: 'LDAW', 0x93: 'LDAW', 0x94: 'LDAW', 0x95: 'LDAW', 0x96: '??',
    0x97: '??', 0x98: 'LAWA', 0x99: 'LAWB', 0x9A: 'LAWX', 0x9B: 'LAWY', 0x9C: 'LAWZ', 0x9D: 'LAWS',
    0x9E: 'LAWC', 0x9F: 'LAWP', 0xA0: 'STAL', 0xA1: 'STAL', 0xA2: 'STAL', 0xA3: 'STAL', 0xA4: 'STAL',
    0xA5: 'STAL', 0xA6: '??', 0xA7: '??', 0xA8: 'SALA', 0xA9: 'SALB', 0xAA: 'SALX', 0xAB: 'SALY', 0xAC: 'SALZ',
    0xAD: 'SALS', 0xAE: 'SALC', 0xAF: 'SALP', 0xB0: 'STAW', 0xB1: 'STAW', 0xB2: 'STAW', 0xB3: 'STAW',
    0xB4: 'STAW', 0xB5: 'STAW', 0xB6: '??', 0xB7: '??', 0xB8: 'SAWA', 0xB9: 'SAWB', 0xBA: 'SAWX', 0xBB: 'SAWY',
    0xBC: 'SAWZ', 0xBD: 'SAWS', 0xBE: 'SAWC', 0xBF: 'SAWP', 0xC0: 'LDBL', 0xC1: 'LDBL', 0xC2: 'LDBL',
    0xC3: 'LDBL', 0xC4: 'LDBL', 0xC5: 'LDBL', 0xC6: '??', 0xC7: '??', 0xC8: 'LBLA', 0xC9: 'LBLB', 0xCA: 'LBLX',
    0xCB: 'LBLY', 0xCC: 'LBLZ', 0xCD: 'LBLS', 0xCE: 'LBLC', 0xCF: 'LBLP', 0xD0: 'LDBW', 0xD1: 'LDBW',
    0xD2: 'LDBW', 0xD3: 'LDBW', 0xD4: 'LDBW', 0xD5: 'LDBW', 0xD6: '??', 0xD7: '??', 0xD8: 'LBWA', 0xD9: 'LBWB',
    0xDA: 'LBWX', 0xDB: 'LDBW', 0xDC: 'LBWZ', 0xDD: 'LBWS', 0xDE: 'LBWC', 0xDF: 'LBWP', 0xE0: 'STBL',
    0xE1: 'STBL', 0xE2: 'STBL', 0xE3: 'STBL', 0xE4: 'STBL', 0xE5: 'STBL', 0xE6: '??', 0xE7: '??', 0xE8: 'SBLA',
    0xE9: 'SBLB', 0xEA: 'SBLX', 0xEB: 'SBLY', 0xEC: 'SBLZ', 0xED: 'SBLS', 0xEE: 'SBLC', 0xEF: 'SBLP',
    0xF0: 'STBW', 0xF1: 'STBW', 0xF2: 'STBW', 0xF3: 'STBW', 0xF4: 'STBW', 0xF5: 'STBW', 0xF6: '??', 0xF7: '??',
    0xF8: 'SBWA', 0xF9: 'SBWB', 0xFA: 'SBWX', 0xFB: 'SBWY', 0xFC: 'SBWZ', 0xFD: 'SBWS', 0xFE: 'SBWC', 0xFF: 'SBWP'
}

def get_op_code(code):
    return OP_CODES.get(code, '')

# $scope module CPU6TestBench $end
# $var wire 1 ! writeEnBus $end
# $var wire 8 " data_r2c [7:0] $end

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
h11Map = {0:'StartBus', 1:'', 2:'', 3:'WAR.HI', 4:'', 5:'', 6:'', 7:''}
e7Map = {0:'', 1:'', 2:'LoadFlags', 3:'BusReg<-Bus', 4:'', 5:'', 6:'', 7:''}

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
            return f'{mem}+{cin} {q} {y}+{cin}'
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
        e7 = self.getSignal(sig, 'cpu.e7').value
        constant = self.getSignal(sig, 'cpu.constant').value
        dataInBus = self.getSignal(sig, 'cpu.dataInBus').value
        map_rom_data = self.getSignal(sig, 'cpu.map_rom_data').value
        reg_ram_data_out = self.getSignal(sig, 'cpu.reg_ram_data_out').value
        register_index = self.getSignal(sig, 'cpu.register_index').value
        register_index = self.getSignal(sig, 'cpu.register_index').value
        FBus = self.getSignal(sig, 'cpu.FBus').value
        DPBus = self.getSignal(sig, 'cpu.DPBus').value
        memory_address = self.getSignal(sig, 'cpu.memory_address').value
        result_register = self.getSignal(sig, 'cpu.result_register').value
        alu0_yout = self.getSignal(sig, 'cpu.alu0_yout').value & 0xf
        alu1_yout = self.getSignal(sig, 'cpu.alu1_yout').value & 0xf
        bus_read = self.getSignal(sig, 'cpu.bus_read').value & 0xf
        alu_out = (alu1_yout << 4) | alu0_yout
        mar_hi = (memory_address >> 8) & 0xff
        mar_lo = memory_address & 0xff

        if k11 == 6:
            k11Map[6] = f'WAR.LO<-RR({result_register:02x})'
            if e6 == 5:
                k11Map[6] = f'WAR.LO<-MAR.LO({mar_lo:02x})'
        if h11 == 3:
            h11Map[3] = f'WAR.HI<-RR({result_register:02x})'
            if e6 == 5:
                h11Map[3] = 'WAR.HI<-MAR.HI({mar_hi:02x})'
        if d2d3 == 1:
            d2d3Map[1] = f'D=R[{register_index:02x}]({reg_ram_data_out:02x})'
        if d2d3 == 10:
            d2d3Map[10] = f'D=bus_read({bus_read:02x})'
        if d2d3 == 13:
            d2d3Map[13] = f'D=const({constant:02x})'
        fbr = f'FBus=Y({alu_out:02x})'
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
        inst = ''
        if addr == 0x104:
            inst = get_op_code(DPBus)
        time = int(clock.time/100)

        comb = f'{time} {addr:03x}: {d2d3Map[d2d3]} {aluCode} {fbr}'
        seq = f'{e6Map[e6]} {k11Map[k11]} {h11Map[h11]} {pcIncMap[pcInc]} {e7Map[e7]}  {inst}'
        return f'{comb}  _||_  {seq}'

if __name__ == '__main__':
    vcd = VCDFile('vcd/CPUTestBench.vcd')
    dis = Disassembler(vcd.signals, vcd.signalTagMap)
    code = dis.disassembleAll()
    with open('vcd/CPUTestBench.txt', 'wt') as f:
        for c in code:
            f.write(f'{c}\n')
