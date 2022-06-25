
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
        ttk.Button(self, text='Reset', command=self.reset).grid(column=0, row=0, padx=5, pady=2)
        self.runBtn = ttk.Button(self, text='Run', command=self.run)
        self.runBtn.grid(column=0, row=1, padx=5, pady=2)
        self.stopBtn = ttk.Button(self, text='Stop', command=self.stop, state='disabled')
        self.stopBtn.grid(column=0, row=2, padx=5, pady=2)
        self.stepBtn = ttk.Button(self, text='Step', command=self.step)
        self.stepBtn.grid(column=0, row=3, padx=5, pady=2)
        self.stepNBtn = ttk.Button(self, text='Step #', command=self.stepn)
        self.stepNBtn.grid(column=0, row=4, padx=5, pady=2)
        self.nClocks = ttk.Entry(self, width=5)
        self.nClocks.insert(0, '1')
        self.nClocks.focus()
        self.nClocks.grid(column=1, row=4, padx=5, pady=2, sticky=tk.W)
        self.index = 0

    def timer(self):
        self.winfo_toplevel().after(TIMER_TICK_MS, self.timer)
        if self.running:
            self.step()
        else:
            self.stepBtn.configure(state='normal')
            self.stepNBtn.configure(state='normal')
            self.runBtn.configure(state='normal')
            self.stopBtn.configure(state='disabled')
            self.nClocks.configure(state='normal')

    def updateAll(self):
        for f in self.sigFrames:
            f.doUpdate(self.index)

    def reset(self):
        self.index = 0
        self.updateAll()

    def run(self):
        self.running = True
        self.stepBtn.configure(state='disabled')
        self.stepNBtn.configure(state='disabled')
        self.runBtn.configure(state='disabled')
        self.stopBtn.configure(state='normal')
        self.nClocks.configure(state='disabled')

    def stop(self):
        self.running = False

    def step(self):
        self.index += 1
        self.updateAll()

    def stepn(self):
        try:
            self.inputFrame.setValues()
            n = int(self.nClocks.get())
            while n > 0:
                self.index += 1
                n -= 1
            self.updateAll()
        except ValueError as e:
            msg = f'Count is not an int: {self.nClocks.get()}'
            messagebox.showwarning(title='Input Error', message=msg)

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
        super().__init__(container, text='', font=fontValue, fg='#f00')
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
            ind.grid(column=1, row=row, sticky=tk.W)
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
        self.title('Control Panel')
        #self.geometry('500x200')
        self.resizable(True, True)
        # windows only (remove the minimize/maximize button)
        self.attributes('-toolwindow', True)
        self.columnconfigure(0, weight=1)
        self.columnconfigure(1, weight=2)
        self.columnconfigure(2, weight=2)
        internal = {'μPC':'cpu.uc_rom_address', 'FBus': 'cpu.FBus', 'DPBus': 'cpu.DPBus'}
        outputs = {'MAR': 'cpu.memory_address'}
        internFrame = OutputFrame(self, 'Internal Signals', internal)
        outputFrame = OutputFrame(self, 'Output Signals', outputs)
        navFrame = NavFrame(self, [internFrame, outputFrame])
        navFrame.grid(column=0, row=0, padx=2, pady=2)
        internFrame.grid(column=1, row=0, padx=2, pady=2, sticky=tk.N)
        outputFrame.grid(column=2, row=0, padx=3, pady=2, sticky=tk.N)
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
