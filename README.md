# Centurion

This directory contains an [HDL](https://en.wikipedia.org/wiki/Hardware_description_language) simulation of the [Centurion Minicomputer](https://github.com/Nakazoto/CenturionComputer/wiki).

The Centurion was an 8-bit minicomputer designed and built by Warrex Computer Corporation, headquartered in Richardson, Texas. The company operated from the mid 1970's into the mid 1980's, delivering approximately 1000 computers to customers in Texas, Oklahoma, and others. The computers were used for accounting and other business functions in medium sized companies.

The Centurion was made of almost entirely TTL MSI logic on a handful of PC boards in a single rack. Earlier models relied on magnetic core memory, later models used MOS memory up to 256 kB. It was technologically similar to the DEC PDP 11 or Data General Nova, but smaller and lower priced. Competition from lower cost microcomputers, particularly the IBM XT and AT in the 1980's, led to decreased sales and the end of the line.

The [Verilog](https://en.wikipedia.org/wiki/Verilog) implementation has been tested with [Icarus Verilog](http://iverilog.icarus.com/), specifically, [Icarus Verilog for Windows](https://bleyer.org/icarus/).

The build process is straightforward:

```
> cd Verilog
> iverilog -o CPU6TestBench CPU6TestBench.v
> vvp CPU6TestBench
```

The simulation output is saved in the ```Verilog/vcd``` directory. It can be viewed using [GTK Wave](http://gtkwave.sourceforge.net/).

The CPU6 is an interesting design. It is based on the [AMD Am2900](https://en.wikipedia.org/wiki/AMD_Am2900) family of bit slice devices. The entire CPU fits on a single board, using two Am2901s to make an 8-bit ALU. The control unit is [microcoded](https://en.wikipedia.org/wiki/Microcode), using 2 Am2909 microsequencers, and 1 Am2911 microsequencer with a 1024 word x 56-bit microprogram stored in seven EPROMs. It is typical of minicomputers of that era. Discrete CPUs based on the Am2900 family were soon superceded by fully integrated VLSI CPUs, such as the [Intel 8086](https://en.wikipedia.org/wiki/Intel_8086), [Motorola 68000](https://en.wikipedia.org/wiki/Motorola_68000), and numerous others.

Below is a sample microcode execution trace. The marker shows the beginning of the very first instruction after reset. It executes a NOP (no operation) and then DLY (delay 4.5 ms).

![DCX Instruction](images/NOP_DLY.png "DCX Instruction Execution")

Below is the CPU data path with enables for busses and registers. The enables are controlled by the microcode word at the output of the pipeline register.

![Data path](images/Datapath.png "Data path")

### Links

 * [Schematics](https://github.com/Meisaka/CenMiniCom)
 * [Schematics and Microcode](https://github.com/sjsoftware/centurion-cpu6)
 