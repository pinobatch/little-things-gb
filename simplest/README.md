Simplest picture displayer
==========================

This program displays an image on the Game Boy in the conceptually
simplest way.  It is not the most space- or time-efficient way.

Some beginning emulator developers, struggling to ensure they have
remotely correct PPU logic, want a demo ROM that they can follow
line-by-line by comparing the state of the emulator to the source
code of the demo.  It should not use interrupts.  It should not use
input.  It should not use compression.  It should not use external
tooling other than a shell script and the components of RGBDS.
It should not use more than one assembly language source code file.

Copyright 2025 Damian Yerrick  
Source code license: zlib  
Using an image by SECricket
