Border Crossing
===============

This is a tool to create your own Super Game Boy border to use in a
Game Boy game.  Load a border, then reset the flash cartridge or
hot-swap to the game you want to play.

A few sample borders are included.  These include the flags of
countries that border GitHub's home country and a few iconic computer
operating systems' window decorations.

How to use
----------

Dirt on connectors can sometimes freeze the SGB while performing a
pak swap.  Clean your cartridges' edge connectors with isopropyl
rubbing alcohol on a cotton swab first.  If the screen freezes,
turn off the Control Deck and try again.

1. Press the Start Button at the title screen.
2. Use the Control Pad to view border titles and choose one.
3. Press the A Button to preview the border.  To view another border,
   press the B Button.
4. Carefully remove the flash cartridge from your Super Game Boy's
   Game Pak slot and firmly insert another game.
5. Some games automatically start when inserted.  Other games show a
   title at the bottom of the screen.  Press the A Button to play.

A game with SGB enhancement will run without enhancement so that it
does not overwrite your chosen border.

How to build
------------

Under Linux, install GNU Make, Coreutils, RGBDS 0.5 or 0.6, Python 3,
and Pillow (Python Imaging Library).  Then run `make`.

Adding borders
--------------

In the present proof of concept, borders must be added in
`src/borderdata.z80` and `makefile`.  A future version may include a
tool to scan a folder for border images, convert them, and pack them
in a ROM.

Border credits:

- Canada and Mexico flag conversions by Damian Yerrick
- "Ross" illustration by yoeynsf
- macOS borders include decorations by Apple Inc.
- Redmond borders include decorations by GitHub's parent company

Legal
-----

Copyright 2022 Damian Yerrick  
License: zlib
