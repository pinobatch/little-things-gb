TRN Stress
==========

Testing playground for scrambling VRAM transfer data in a way that
an authentic Super Game Boy can decode and some emulators that take
shortcuts cannot.

Build dependencies: RGBDS, Python 3, Pillow, Bash, Coreutils

Status
------

Writing code specification and collecting test graphics

- DONE Describe in words each of 15 scrambling methods
- DONE Design the SGB only error message and title screen in GIMP
- DONE Design the menu in GIMP
- 0/1 borderconv: ensure `-c embedded` style behavior for <= 16-color
  indexed PNG images
- 0/3 Display the SGB only error message, title screen, and credits
- 0/1 Display the menu
- 0/1 Validate the STAT scroll engine
- 0/16 Gather 16 images depicting anthropomorphic bears in mid to
  late 19th century attire.  They can be up to 256 by 224 pixels with
  no more than 256 unique tiles.  Two are 4 color and the rest up to
  16 color.
- 0/16 Code the 16 scramblers
