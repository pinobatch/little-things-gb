TRN Stress
==========

Testing playground for scrambling VRAM transfer data in a way that
an authentic Super Game Boy can decode and some emulators that take
shortcuts cannot.

Build dependencies: RGBDS, Python 3, Pillow, Bash, Coreutils

Status
------

Writing scramblers and collecting test graphics

- DONE Describe in words each of 15 scrambling methods
- DONE Design the SGB only error message and title screen in GIMP
- DONE Design the menu in GIMP
- DONE Display the SGB only error message, title screen, and credits
- DONE Draw and wire up the scrambler menu
- DONE Validate the raster effect engine
- 10/14 Code scramblers for 4bpp borders and test them on hardware
    - [X] Dispatch, 2, 5-8, 11-14
    - [ ] 8-line objects
    - [ ] 16-line objects
    - [ ] Fine X scroll
    - [ ] Fine Y scroll
- 0/16 Gather 16 images depicting anthropomorphic bears in mid to
  late 19th century attire.  They can be up to 256 by 224 pixels with
  no more than 256 unique tiles.  Two are 4 color and the rest up to
  16 color.
- 0/1 borderconv: ensure `-c embedded` style behavior for <= 16-color
  indexed PNG images
- 0/2 Code scramblers for 2bpp borders and test them on hardware
    - [ ] 2bpp via tilemap
    - [ ] 2bpp via BGP
