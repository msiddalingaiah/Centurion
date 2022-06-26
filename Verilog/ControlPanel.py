
import tkinter as tk
from tkinter import ttk
from tkinter import messagebox

from parse_vcd import *

TIMER_TICK_MS = 500

class NavFrame(ttk.LabelFrame):
    def __init__(self, container, sigframes):
        super().__init__(container, text='Navigate')
        self.sigFrames = sigframes
        self.running = False
        self.index = 0
        tk.Label(self, text='Cycle', font=('Consolas', 12)).grid(column=0, row=0, sticky=tk.E)
        self.cycle = tk.Label(self, text='0', font=('Digital-7 Mono', 20), fg='#0000ff')
        self.cycle.grid(column=1, row=0, sticky=tk.E)

        ttk.Button(self, text='Reset', command=self.reset).grid(column=0, row=1, padx=5, pady=2)
        self.runBtn = ttk.Button(self, text='Run', command=self.run)
        self.runBtn.grid(column=0, row=2, padx=5, pady=2)
        self.stopBtn = ttk.Button(self, text='Stop', command=self.stop, state='disabled')
        self.stopBtn.grid(column=0, row=3, padx=5, pady=2)

        self.prevBtn = ttk.Button(self, text='Prev', command=self.prev)
        self.prevBtn.grid(column=0, row=4, padx=5, pady=2)

        self.nextBtn = ttk.Button(self, text='Next', command=self.next)
        self.nextBtn.grid(column=0, row=5, padx=5, pady=2)
        self.stepNBtn = ttk.Button(self, text='Step #', command=self.stepn)
        self.stepNBtn.grid(column=0, row=6, padx=5, pady=2)
        self.nClocks = ttk.Entry(self, width=5)
        self.nClocks.insert(0, '1')
        self.nClocks.focus()
        self.nClocks.grid(column=1, row=6, padx=5, pady=2, sticky=tk.W)

    def timer(self):
        self.winfo_toplevel().after(TIMER_TICK_MS, self.timer)
        if self.running:
            self.next()
        else:
            self.prevBtn.configure(state='normal')
            self.nextBtn.configure(state='normal')
            self.stepNBtn.configure(state='normal')
            self.runBtn.configure(state='normal')
            self.stopBtn.configure(state='disabled')
            self.nClocks.configure(state='normal')

    def updateAll(self):
        self.cycle.config(text = str(self.index))
        for f in self.sigFrames:
            f.doUpdate(self.index)

    def reset(self):
        self.index = 0
        self.updateAll()

    def run(self):
        self.running = True
        self.prevBtn.configure(state='disabled')
        self.nextBtn.configure(state='disabled')
        self.stepNBtn.configure(state='disabled')
        self.runBtn.configure(state='disabled')
        self.stopBtn.configure(state='normal')
        self.nClocks.configure(state='disabled')

    def stop(self):
        self.running = False

    def prev(self):
        if self.index > 0:
            self.index -= 1
            self.updateAll()

    def next(self):
        self.index += 1
        self.updateAll()

    def stepn(self):
        try:
            n = int(self.nClocks.get())
            while n > 0:
                self.index += 1
                n -= 1
            self.updateAll()
        except ValueError as e:
            msg = f'Count is not an int: {self.nClocks.get()}'
            messagebox.showwarning(title='Input Error', message=msg)

ALU_SRC_MAP = [['A', 'Q'], ['A', 'B'], ['0', 'Q'], ['0', 'B'], ['0', 'A'], ['D', 'A'], ['D', 'Q'], ['D', '0']]
ALU_OP_MAP = ['{r}+{s}', '{s}-{r}', '{r}-{s}', '{r}|{s}', '{r}&{s}', '(~{r})&{s}', '{r}^{s}', '~({r}^{s})']
ALU_MEM_DEST_MAP = ['', '', 'r{b}={f}', 'r{b}={f}', 'r{b}=({f})>>1', 'r{b}=({f})>>1', 'r{b}=({f})<<1', 'r{b} =({f})<<1']
ALU_Q_DEST_MAP = ['Q = {f}', '', '', '', 'Q>>=1', '', 'Q<<=1', '']
ALU_OUT_MAP = ['Y={f}', 'Y={f}', 'Y={a}', 'Y={f}', 'Y={f}', 'Y={f}', 'Y={f}', 'Y={f}']

class ALUFrame(ttk.LabelFrame):
    def __init__(self, container, title):
        super().__init__(container, text=title)
        self.app = container
        fontName = ('Consolas', 12)
        self.aluLabel = tk.Label(self, text='', font=fontName)
        self.aluLabel.grid(column=0, row=0, sticky=tk.E)
        self.doUpdate(0)

    def doUpdate(self, index):
        alu_a = self.app.getSignal(index, 'cpu.alu_a').value
        alu_b = self.app.getSignal(index, 'cpu.alu_b').value
        alu_src = self.app.getSignal(index, 'cpu.alu_src').value
        alu_op = self.app.getSignal(index, 'cpu.alu_op').value
        alu_dest = self.app.getSignal(index, 'cpu.alu_dest').value
        alu0_cin = self.app.getSignal(index, 'cpu.alu0_cin').value
        aluCode = self.getALUCode(alu_a, alu_b, alu_op, alu_src, alu_dest, alu0_cin).strip()
        self.aluLabel.config(text = f'{aluCode:25s}')

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

class SignalIndicator(tk.Canvas):
    def __init__(self, container, signalName, w=15, h=15):
        super().__init__(container, width=w, height=h)
        self.signalName = signalName

    def doUpdate(self, signal):
        w = self.winfo_width()-3
        h = self.winfo_height()-3
        if signal.value:
            self.create_oval(2, 2, w, h, fill='#0f0', outline='#000')
        else:
            self.create_oval(2, 2, w, h, fill='#fff', outline='#000')

class VectorIndicator(tk.Label):
    def __init__(self, container, signalName, size):
        # TrueType font from https://www.fontspace.com/digital-7-font-f7087
        fontValue = ('Digital-7 Mono', 20)
        super().__init__(container, text='', font=fontValue, fg='#ff0000')
        digits = (size+3) >> 2
        self.format = f'%0{digits}X'
        self.signalName = signalName

    def doUpdate(self, signal):
        self.config(text = self.format % signal.value)

class OutputFrame(ttk.LabelFrame):
    def __init__(self, container, title, outputs):
        super().__init__(container, text=title)
        self.app = container
        self.indicators = []
        fontName = ('Consolas', 12)
        row = 0
        for label, signalName in outputs.items():
            tk.Label(self, text=label, font=fontName).grid(column=0, row=row, sticky=tk.E)
            ind = None
            signal = container.getSignal(0, signalName)
            if len(signal) == 1:
                ind = SignalIndicator(self, signalName)
            else:
                ind = VectorIndicator(self, signalName, len(signal))
            self.indicators.append(ind)
            ind.grid(column=1, row=row, sticky=tk.E)
            row += 1
        self.doUpdate(0)

    def doUpdate(self, index):
        for ind in self.indicators:
            signal = self.app.getSignal(index, ind.signalName)
            ind.doUpdate(signal)

class App(tk.Tk):
    def __init__(self, signals, signalTagMap):
        super().__init__()
        self.signals = signals
        self.signalTagMap = signalTagMap
        self.title('CPU6 Simulation Replay')
        #self.geometry('500x200')
        self.resizable(True, True)
        # windows only (remove the minimize/maximize button)
        self.attributes('-toolwindow', True)
        self.columnconfigure(0, weight=1)
        self.columnconfigure(1, weight=2)
        self.columnconfigure(2, weight=2)
        internal = {'μPC':'cpu.uc_rom_address', 'FBus': 'cpu.FBus', 'DPBus': 'cpu.DPBus',
            'Result':'cpu.result_register', 'Flags':'cpu.flags_register', 'Swap':'cpu.swap_register',
            'Reg. Index':'cpu.register_index', 'Work Address': 'cpu.work_address',
            'ALU 1 Q':'alu1.q', 'ALU 0 Q':'alu0.q' }
        external = {'Bus Address': 'cpu.memory_address', 'Data In':'cpu.dataInBus', 'Data Out':'cpu.dataOutBus',
            'Write En':'cpu.writeEnBus'}
        internFrame = OutputFrame(self, 'Internal Signals', internal)
        aluFrame = ALUFrame(self, 'ALU')
        outputFrame = OutputFrame(self, 'Output Signals', external)
        navFrame = NavFrame(self, [internFrame, outputFrame, aluFrame])
        navFrame.grid(column=0, row=0, padx=2, pady=2)
        internFrame.grid(column=1, row=0, padx=2, pady=2, sticky=tk.NW)
        aluFrame.grid(column=1, row=1, padx=2, pady=2, sticky=tk.N)
        outputFrame.grid(column=2, row=0, padx=3, pady=2, sticky=tk.NW)
        # Assert reset after 500 ms
        self.after(500, navFrame.reset)
        self.after(TIMER_TICK_MS, navFrame.timer)

    def getSignal(self, index, name):
        tag = self.signalTagMap[name]
        sig = self.signals[index]
        return sig[tag]

if __name__ == '__main__':
    vcd = VCDFile('vcd/CPUTestBench.vcd')
    signals = []
    clockTag = vcd.signalTagMap['cg0.clock']
    for sig in vcd.signals:
        if sig[clockTag].value == 1:
            signals.append(sig)
    app = App(signals, vcd.signalTagMap)
    app.mainloop()
