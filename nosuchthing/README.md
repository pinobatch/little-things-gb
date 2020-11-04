No Such Thing
=============

**This folder is not fully functional.**
Development of the Game Gear side of the ROM is pending expansion
of ca83.

In 1990, Nintendo placed print ads clarifying how to refer to
its products by their trademarks.  For example, it's not accurate
to call the Nintendo Entertainment System (NES) a "Nintendo".
The ad's headline was "There's no such thing as a Nintendo."

Fast-forward to the late 2010s, when the Internet meme community
rediscovered this ad and made parodies titled "There's no such
thing as Nintendo."  These were meant to jokingly imply that
Nintendo and its products never existed in the first place, and
anyone who believes otherwise must be a victim of mass delusion.

This 1K tech demo for Game Boy displays "There's no such thing as
Nintendo" with Mario drawn as a shadow.  It's meant for inclusion
in a ROM for Sega Master System or Game Gear as a humorous error
message that the game is running on the wrong emulator or flash cart.
Alternatively, should Nintendo's legal department start to attack
fan-made content even more intensely than it did in the 2010s,
the demo can represent a farewell to the homebrew scene with
a hint of _damnatio memoriae_ toward the alleged bully.

Checksum
--------
The tricky part of a GB/SMS polyglot is making both checksums
correct.  Only the export SMS refuses to boot a ROM with an incorrect
checksum, not the GG or Japanese SMS.  The GB checks only the
checksum of the header, not the overall checksum.  Emulators still
warn for a wrong checksum, making the ROM as a whole look suspicious.

* SMS checksum is the sum mod 65536 of all bytes outside $7FF0-$7FFF,
  stored in little endian at $7FFA.  The size of checksummed data
  can be and often is smaller than the actual game size.
* GB checksum is the sum mod 65536 of all bytes outside $014E-$014F,
  stored in big endian at $014E.  Licensed games include the entire
  ROM in the checksum.

* ["ROM Header" on SMS Power!](https://www.smspower.org/Development/ROMHeader)
* ["The Cartridge header" in Pan Docs](https://gbdev.io/pandocs/#the-cartridge-header)

Copyright 2020 Damian Yerrick  
Distributed under the zlib License

