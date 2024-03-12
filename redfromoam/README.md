Red from OAM
============

Test ROM to determine what is read from OAM during DMA

Background
----------

The Game Boy compact video game system (GB) has a display with
160×144 dots and a system on chip (SoC) containing an 8-bit processor
similar to Intel 8080 (CPU) and a custom picture processing unit
(PPU).  For each line of dots on the screen, the PPU reads values
from memory to determine what to draw on that line.  It takes 456 PPU
cycles to produce one line.  During 160 of these cycles, the PPU
sends one dot to the display.  During others, it pauses the stream of
dots while reading memory or resting.  To distinguish PPU cycles from
other clocks in the GB, they are sometimes called "dots" despite that
some are actually delays.

Video memory (VRAM) is an 8 KiB block of memory in the GB.  The first
6 KiB of VRAM holds 384 characters, which are shapes made of 8×8
dots.  The remaining 2 KiB holds a pair of tilemaps, each of which is
a grid of 32×32 cells controlling which character to display at each
position on a 256×256-dot scrollable background plane.

Object attribute memory (OAM) is a 160-byte block of memory in the
GB.  It sets the positions of 40 objects (also called sprites),
which are small rectangles of dots displayed on the screen.  It also
controls which character to use for each object, whether to flip the
character horizontally or vertically, which of two palettes (sets of
gray levels) to use, and whether to draw it in front of or behind
the background plane.

Before rendering each line, the PPU performs OAM scan (also called
mode 2), spending 80 cycles reading X and Y coordinates of all
objects to find up to 10 objects in range to draw on that line.
Afterward, the PPU starts rendering the line (also called mode 3).
During rendering, it fetches tilemap entries and characters for the
background from VRAM.  When the count of rendered dots reaches an
in-range object's X coordinate, the PPU reads the character address
and attributes from OAM and then fetches the character from VRAM.
After rendering the whole line, the PPU enters horizontal blanking
(also called mode 0) in which rests until the start of the next line.

Direct memory access (DMA) refers to methods of copying data from
one device to another faster than the CPU can.  GB has an OAM DMA
function that copies 160 bytes from the cartridge or working memory
(WRAM) to OAM.  This takes 640 PPU cycles, almost a line and a half,
during which the PPU cannot read values from OAM.  Instead, most
revisions of the PPU behave like this if OAM DMA is running:

- During OAM scan, the PPU treats the object as out of range, as if
  its Y coordinate were 255.
- During rendering, it reads whatever pair of bytes the DMA unit is
  working on.  The even byte is treated as a character address, and
  the odd byte is treated as attributes.

Game Boy Advance and very late Game Boy Color systems (CGB E, with
WRAM inside the SoC) behave somewhat differently during OAM scan.

Most games run OAM DMA during vertical blanking, a period between
frames that lasts as long as 10 lines (4560 PPU cycles), such that
it won't affect rendering.

Source: SameBoy v0.15.8 emulator source code, file `Core/display.c`,
functions `add_object_from_index()` and `GB_display_run()` near
`/* Handle objects */`

The test
--------

A text background is drawn in black and white.  Objects are placed on
the control line and the test line.  The objects on the control line
are visible.  The objects on the test line point to a transparent
character, and their character and attribute values get clobbered by
a mid-frame OAM DMA each frame, causing them to be visible.

Game Boy is pregnant; it shows 2 lines.  SameBoy and Gambatte are
pregnant.  Emulicious, bgb, and Mesen are not pregnant; they show
only the control line.

Copyright 2023 Damian Yerrick  
License: zlib
