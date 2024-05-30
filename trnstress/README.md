TRN Stress
==========

Testing playground for scrambling VRAM transfer data in a way that
an authentic Super Game Boy can decode and some emulators that take
shortcuts cannot.

Build dependencies: RGBDS, Python 3, Pillow, Bash, Coreutils

Status
------

Most scramblers are done.  Now we need graphics for the slideshow.

- DONE Describe in words each of 15 scrambling methods
- DONE Design the SGB only error message and title screen in GIMP
- DONE Design the menu in GIMP
- DONE Display the SGB only error message, title screen, and credits
- DONE Draw and wire up the scrambler menu
- DONE Validate the raster effect engine
- DONE Code dispatcher and 13 scramblers for 4bpp borders and test
  them on hardware
- DONE Gather 2 low-color images: up to 256 by 224 pixels,
  up to 256 unique 8x8-pixel tiles, up to 3 colors.
- DONE borderconv: option to reserve tiles $7F and $FF
- DONE borderconv: preserve embedded palette for indexed
  images with 16 or fewer colors and play area color 0
- 0/1 TRN frame timing test
- 0/2 Code scramblers for 2bpp borders and test them on hardware
    - [ ] 2bpp via tilemap
    - [ ] 2bpp via BGP
- 3/14 Gather 14 normal images: up to 256 by 224 pixels,
  up to 254 unique 8x8-pixel tiles, up to 3 subpalettes of 15 colors
  each with each tile using one subpalette.  Preferably include
  anthropomorphic bears in mid to late 19th century attire
- 0/1 Automatic slideshow
