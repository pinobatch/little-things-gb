#!/bin/sh
set -e
mkdir -p obj/gb
rgbgfx -b 128 -c embedded -o obj/gb/simplest.2bpp -ut obj/gb/simplest.nam tilesets/simplest.png
rgbasm -o obj/gb/simplest.o src/simplest.s
rgblink -dt -n simplest.sym -p 0xFF -o simplest.gb obj/gb/simplest.o
rgbfix -jvt "SIMPLEST" -k "P8" -l 0x33 -p 0xFF simplest.gb
