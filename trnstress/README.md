TRN Stress
==========

Testing playground for scrambling VRAM transfer data in a way that
an authentic Super Game Boy accessory can decode and some emulators
that take shortcuts cannot.

Build dependencies: RGBDS, Python 3, Pillow, Bash, Coreutils

Scrambling
----------

The ROM contains 15 different scrambling methods.  These apply
various transformations to the tile set and map border data that
the Game Boy program transfers to the SGB.  These involve changing
the tile data and tilemap in GB video memory (VRAM), the background
palette register (`BGP`), objects (also called sprites), the window
(commonly used for status bars), and the scroll position.

Each method changes the video memory in a specific way and changes
something else to reverse the effect.  This causes the GB system on
chip (SoC) to produce exactly the same pixels as if no scrambling
had happened.  An emulator that renders the complete image during a
transfer will not be affected.  An emulator that takes shortcuts,
such as snooping the GB's video memory, may display a corrupt border.

See [spec](docs/spec.md) for details.

Frame timing
------------

During each frame, the GB SoC produces 160 by 144 pixels, and the
ICD2 bridge chip in the SGB turns this into 5760 bytes' worth of
tile data.  The SGB spends most of its time forwarding this data to
the Super NES video memory for display on screen.  When the GB sends
a packet to the SGB requesting a transfer, the SGB reads the first
4096 bytes from a later frame, usually the first or second frame
after the request.

There was a hypothesis that the SGB reads the transfer data over the
course of several frames, such as 1024 bytes from each of the next
four frames.  This turned out not to be the case.  There's a delay
before the transfer that varies from 1 to 3 frames depending on how
busy the SGB is with other things.

Results
-------

bgb 1.6.2, SameBoy 0.16.3, Mesen 2 2024-05-13, and BizHawk 2.9.1
Gambatte correctly display all 16 borders and a plausible frame
timing result (often `1[1]1`, sometimes `2[1]2`).

KiGB 2.05 and mGBA 0.11-721-237d502 correctly display everything but
BGP tests.

VisualBoyAdvance 1.7, VisualBoyAdvance-M 2.1.8, and no$gmb have
trouble with anything involving BGP, window, objects, or scrolling.
In addition, VBA 1.7 and no$gmb hide the portion of the border that
overlays the play area.  In frame timing, all three show 0 frames of
delay, meaning they read the screen on the same frame during which
the program sends the transfer packet.

Goomba Color 12-14-14 shows "This emulator is junior league!" on
the title screen.  This error happens when the CPU does not make
a relative jump (`jr` instruction) from low ROM to HRAM.

Status
------

Scramblers are finished.  Now we collect art for the slide show.

- Gather 11 more images: up to 256 by 224 pixels, up to 254 unique
  8x8-pixel tiles, up to 3 subpalettes of 15 colors with each tile
  using colors from one subpalette.  Preferably include
  anthropomorphic bears in mid to late 19th century attire.
- Automatic slide show
- Give beware a 32K ROM reduced to 40 iterations

Legal
-----

© 2024 Damian Yerrick

This is free software with no warranty.  Permission is granted to
distribute the software subject to the zlib License.

See also [Image credits](docs/image_credits.txt)
