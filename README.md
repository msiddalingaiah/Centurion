# Centurion

This directory contains an [HDL](https://en.wikipedia.org/wiki/Hardware_description_language) simulation of the [Centurion Minicomputer](https://github.com/Nakazoto/CenturionComputer/wiki).

The Centurion was an 8-bit minicomputer designed and built by Warrex Computer Corporation, headquartered in Richardson, Texas. The company operated from the mid 1970's into the mid 1980's, delivering approximately 1000 computers to customers in Texas, Oklahoma, and others. The computers were used for accounting and other business functions in medium sized companies.

The Centurion was made of almost entirely TTL MSI logic on a handful of PC boards in a single rack. Earlier models relied on magnetic core memory, later models used MOS memory up to 256 kB. It was technologically similar to the DEC PDP 11 or Data General Nova, but smaller and lower priced. Competition from lower cost microcomputers, particularly the IBM XT and AT in the 1980's, led to decreased sales and the end of the line.

The [Verilog](https://en.wikipedia.org/wiki/Verilog) implementation has been tested with [Icarus Verilog](http://iverilog.icarus.com/), specifically, [Icarus Verilog for Windows](https://bleyer.org/icarus/).

The build process is straightforward:

```
> iverilog -o CPU6TestBench CPU6TestBench.v
> vvp CPU6TestBench
```

The simulation output is saved in the ```Verilog/vcd``` directory. It can be viewed using [GTK Wave](http://gtkwave.sourceforge.net/).
