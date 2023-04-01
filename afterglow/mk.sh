#!/bin/sh
set -e

mkdir -p obj/gb
python3 tools/vwfbuild.py tilesets/vwf7.png obj/gb/vwf7.z80
rgbgfx -o obj/gb/chr16.2bpp -Zc embedded tilesets/chr.png
rgbasm -Ho obj/gb/main.o src/main.z80
rgbasm -Ho obj/gb/vwfdraw.o src/vwfdraw.z80
rgbasm -Ho obj/gb/vwflabels.o src/vwflabels.z80
rgbasm -Ho obj/gb/vwf7.o obj/gb/vwf7.z80
rgbasm -Ho obj/gb/pads.o src/pads.z80
rgbasm -Ho obj/gb/ppuclear.o src/ppuclear.z80
rgbasm -Ho obj/gb/sgb.o src/sgb.z80
rgblink -dto afterglow.gb -n afterglow.sym \
  obj/gb/main.o obj/gb/vwfdraw.o obj/gb/vwflabels.o obj/gb/vwf7.o \
  obj/gb/pads.o obj/gb/sgb.o obj/gb/ppuclear.o
rgbfix -jvsl 0x33 -t 'AFTERGLOW' afterglow.gb
