
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

    def __str__(self):
        return self.value

class VCDFile(object):
    def __init__(self, fname):
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
                    #print(module)
                if cols[0] == '$var':
                    sd = SignalDef(module, cols)
                    #print(sd, sd.isValid())
                    if sd.isValid():
                        self.signalMap[sd.tag] = sd
        prevTime = -1
        time = 0
        signals = {}
        for tag, df in self.signalMap.items():
            sig = Signal(time, df, -1)
            print(df)
            signals[sig.getName()] = sig
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
                        signals[sig.getName()] = sig
                    elif cols[0] != '$end':
                        valueStr = cols[0]
                        # print(valueStr)
                        value = -1
                        if 'x' not in valueStr[0]:
                            value = int(valueStr[0])
                        sig = Signal(time, self.signalMap.get(valueStr[1]), value)
                        signals[sig.getName()] = sig

    def copy(self, sigs):
        result = {}
        for k, v in sigs.items():
            result[k] = v
        return result

e6Map = {0:'', 1:'RR<=FBus', 2:'RI<=FBus', 3:'', 4:'', 5:'MAR<=>WAR', 6:'', 7:'LoadCC'}
k11Map = {0:'', 1:'', 2:'', 3:'Load F11', 4:'', 5:'', 6:'WAR.LO<=', 7:'WrBus'}

class Disassembler(object):
    def __init__(self, signals):
        self.signals = signals

    def disassembleAll(self):
        i = 1
        while i < len(self.signals[1:]):
            sig = self.signals[i]
            i += 1
            print(self.disassembleOne(sig))

    def disassembleOne(self, sig):
        clock = sig['ram.clock']
        addr = sig['cpu.uc_rom_address'].value
        e6 = sig['cpu.e6'].value
        k11 = sig['cpu.k11'].value
        h11 = sig['cpu.h11'].value
        if k11 == 6:
            k11Map[k11] = 'WAR.LO<=RR'
            if e6 == 5:
                k11Map[k11] = 'WAR.LO<=MAR.LO'

        return f'{clock.time} {clock.value} {addr:03x}, {e6Map[e6]} {k11Map[k11]}'

if __name__ == '__main__':
    vcd = VCDFile('vcd/CPUTestBench.vcd')
    dis = Disassembler(vcd.signals)
    dis.disassembleAll()
