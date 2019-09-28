gbpng
=====
Embed a PNG image into a Game Boy ROM

The ROM has to meet these guidelines:

- The first 40 bytes (`rst $00` through `rst $20`) must be unused.
  These hold the PNG's 33-byte header and the header of the chunk
  that contains the Game Boy program.
- If `rst $28` is used, the instruction at $0028 must be `ld l,l`
  so that the `prGm` chunk can contain the entire program.
- There must be enough unused space at the end of the ROM (detected
  as identical bytes) to hold the entire PNG image minus 29 bytes
  (the PNG's header minus the header CRC).

Though the example ROM displays the same pixels as the PNG embedded
into it, this need not be the case.  The example code *does not*
decode the PNG file.  The image is stored in two different
compression formats: PNG and one the GB can decode time-efficiently.

Legal
-----
Copyright 2018 Damian Yerrick.

This program is free software distributed under the zlib License.
