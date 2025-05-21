#!/bin/sh
set -e

mkdir -p obj/gb
python3 tools/vwfbuild.py tilesets/vwf7.png obj/gb/vwf7.z80
rgbgfx -o obj/gb/chr16.2bpp -Zc embedded tilesets/chr.png
rgbasm -o obj/gb/main.o src/main.z80
rgbasm -o obj/gb/vwfdraw.o src/vwfdraw.z80
rgbasm -o obj/gb/vwflabels.o src/vwflabels.z80
rgbasm -o obj/gb/vwf7.o obj/gb/vwf7.z80
rgbasm -o obj/gb/pads.o src/pads.z80
rgbasm -o obj/gb/ppuclear.o src/ppuclear.z80
rgbasm -o obj/gb/sgb.o src/sgb.z80
rgbasm -o obj/gb/bcd.o src/bcd.z80
rgblink -dto afterglow.gb -n afterglow.sym -m afterglow.map -p 0xff \
  obj/gb/main.o obj/gb/vwfdraw.o obj/gb/vwflabels.o obj/gb/vwf7.o \
  obj/gb/pads.o obj/gb/sgb.o obj/gb/ppuclear.o obj/gb/bcd.o
rgbfix -jvscl 0x33 -t 'AFTERGLOW' -p 0xff afterglow.gb
