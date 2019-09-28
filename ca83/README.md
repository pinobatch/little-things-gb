ca83
====
A framework for assembling a Game Boy ROM with ca65

In 2013, during the development of [lorom-template], I needed an
assembler targeting the SPC700 CPU that the Super NES uses to control
its 8-voice sampler.  This CPU's ISA is similar to that of the better
known 65C02, though it uses different opcodes.  But most SPC700
assemblers I found had either little support for larger projects
(such as not using a linker) or a reputation for silent defects.
So as a proof of concept, I reimplemented [6502 as a macro pack] for
the ca65 assembler in its `.setcpu "none"` mode.  Based on this work,
I asked blargg, who was more familiar with SPC700 than I was, to
implement [SPC700 as a macro pack].

This project demonstrates a macro pack implementing all opcodes of
SM83, an 8-bit architecture created by Sharp and used by the CPU core
of the Game Boy compact video game system's LR35902 system on chip.
It includes almost all instructions of the Intel 8080, with a handful
moved to different opcodes, plus the relative jumps and 0xCB-prefixed
bitwise operations of the Zilog Z80 and some autoincrementing
accesses through HL.  Unlike Z80's IX and IY, SM83 does not include
anything to make struct fields convenient to access.

Building the project in this early state currently requires the
following installed: GNU Make, Python 3, Pillow, cc65, and GCC.

To use:

1. Put the `sm83isa.mac` file where you put your project's include
   files
2. In each source code file, do `.macpack sm83isa`
3. Link with a linker script suitable for your ROM size
4. Inject a header with `tools/gbheader.py`


Copyright 2019 Damian Yerrick  
License: zlib

[lorom-template]: https://github.com/pinobatch/lorom-template
[6502 as a macro pack]: https://forums.nesdev.com/viewtopic.php?f=2&t=10701
[SPC700 as a macro pack]: https://forums.nesdev.com/viewtopic.php?f=12&t=10730
[struct]: https://gbdev.gg8.se/wiki/articles/Struct
