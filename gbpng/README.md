gbpng
=====
Embed a PNG image into a Game Boy ROM

This tool takes a ROM compatible with Game Boy that meets certain
criteria and combines it with a PNG image to make a "polyglot" file,
which is simultaneously a valid ROM and a valid PNG image.  The ROM
can be displayed on a web page or sent through image hosts, and so
long as the server doesn't reencode the image before serving it to
the viewer, the user can run it in a Game Boy emulator.

Building the demo
--------
Install RGBDS, Python, and GNU Make.  Then at a terminal, type
`make all` to build or `make run` to build and run.  For the latter,
`GBEMU=sameboy make run` overrides the default emulator.

Coreutils is needed for the `make clean` target. If you have WSL,
MSYS2, Cygwin, or a GNU/Linux distribution installed, you probably
have Make and Coreutils.

Though the example ROM displays the same pixels as the PNG embedded
into it, this need not be the case.  The example code *does not*
decode the PNG file.  The image is stored in two different
compression formats: PNG and one the GB can decode time-efficiently.
An easy change is to make them different pictures.  The `pngfile`
variable in the makefile controls which PNG gets appended.  The one
displayed when running the program is `tilesets/Sukey.png`; it must
have dimensions of 160x144 pixels, use a 4-color palette from dark
to light (such as black, dark gray, light gray, white), and have no
more than 256 distinct 8x8-pixel characters.

Adding to your own program
--------------------------
The ROM must have enough blank space at the start and end:

- The first 40 bytes (`rst $00` through `rst $20`) must be unused.
  These hold the PNG's 33-byte header and the header of the chunk
  that contains the Game Boy program.  Thus it's unlikely to work
  with proprietary games from the commercial era (1989 through 2001).
- If `rst $28` is used, the instruction at $0028 must be `ld l,l`
  so that the `prGm` chunk can contain the entire program.
- There must be enough unused space at the end of the ROM (detected
  as identical bytes) to hold the entire PNG image minus 29 bytes
  (the PNG's header minus the header CRC).

Once those are taken care of:

    tools/pngify.py gbfile pngfile outfile


Legal
-----
Copyright 2018 Damian Yerrick.

This program is free software distributed under the zlib License.
