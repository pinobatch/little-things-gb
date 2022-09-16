Border Crossing
===============

This is a tool to create your own Super Game Boy border to use in a
Game Boy game.  Load a border, then reset the flash cart or pak-swap
to the game you want to play.

A few sample borders are included.  These include the flags of
countries that border GitHub's home country and a few iconic computer
operating systems' window decorations.

How to use
----------

Dirt on connectors can sometimes freeze the SGB while performing a
pak swap.  Clean your cartridges' edge connectors with isopropyl
rubbing alcohol on a cotton swab first.

1. Press the Start Button at the title screen.
2. Use the Control Pad to view border titles and choose one.
3. Press the A Button to preview the border.  To view another border,
   press the B Button.
4. Carefully remove the flash cartridge from your Super Game Boy's
   Game Pak slot and insert another game.
5. Some games automatically start when inserted.  Other games display
   the game title at the bottom.  Press the A Button to play.

Adding borders
--------------

In the present proof of concept, borders must be added in
`src/borderdata.z80` and `makefile`.  A future version may include a
tool to convert scan a folder for borders and pack them in a ROM.

Border credits:

- Canada and Mexico flag conversions by Damian Yerrick
- "Ross" illustration by yoeynsf
- macOS borders include decorations by Apple Inc.
- Redmond borders include decorations by GitHub's parent company

Legal
-----

Copyright 2022 Damian Yerrick  
License: zlib
