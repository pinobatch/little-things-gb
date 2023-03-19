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
  (the PNG's header minus the header CRC).  If you have [OptiPNG],
  consider `optipng -strip all image.png` to remove unnecessary
  chunks from the image.

Once those are taken care of:

    tools/pngify.py gbfile pngfile outfile

By default, the `prGm` chunk containing the Game Boy program has a
correct global checksum at $014E in the Game Boy header to silence
warnings in some Game Boy emulators.  This causes the CRC32 value to
be incorrect, which may make the image unreadable in PNG decoders
that reject an entire file for a single incorrect CRC32 value in
an otherwise ignored chunk.  (Reports of picky decoders would be
appreciated.)  To work around this, use `pngify.py --skip-global-sum`
to prioritize the CRC32 over the GB header global checksum.

[OptiPNG]: https://optipng.sourceforge.net/

Future possibilities
--------------------
I'm interested in seeing proofs of concept to add support for other
consoles' ROM image formats.  Here are some exercises for the reader:

**Super NES:** The program has to avoid enough of the last few banks
as well as the first 41 bytes.  Fortunately, these bytes have no
special meaning on a Super NES; have your linker configuration avoid
them.  Then correct the SNES checksum instead of a GB checksum.

**Genesis:** The first 41 bytes overlap the reset vector (at $0005)
and the handlers for the first few exceptions: bus error, address
error, illegal instruction, divide by zero, bounds check, trap on
overflow, privilege violation, and trace.  If your program doesn't
use these, you may be able to build a linker script for an entry
point at address $0A1A0A (or $021A0A for 2 to 4 Mbit ROMs).

**Master System and Game Gear:** Appears tricky.  The CPU starts at
$0000 executing the PNG header, treating the width, height, and CRC32
of the `IHDR` chunk as opcodes.  Maxim in the SMS Power community
suggested making an `IHDR` of size 24 bytes instead of 13 to turn
its size into a `jr` instruction.  A nonstandard size for `IHDR`
may cause some decoders to reject an image.  And even if decoders
tolerate oversize `IHDR`, a ROM intended for 50-pin machines would
need to use a mapper so that the `TMR SEGA` block can specify that
the checksum applies only to the first 32 KiB.

**NES:** Not possible; PNG header overlaps iNES header.

**GBA:** Not possible; PNG header overlaps initial jump and
compressed logo.

Legal
-----
Copyright 2018, 2023 Damian Yerrick.

This program is free software distributed under the zlib License.
