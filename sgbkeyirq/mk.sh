#!/bin/sh
set -e
mkdir -p obj/gb
rgbgfx -o obj/gb/ascii.1b -c embedded -d1 tilesets/ascii.png
rgbasm -o obj/gb/init.o src/init.s
rgbasm -o obj/gb/bcd.o src/bcd.s
rgbasm -o obj/gb/euclid.o src/euclid.s
rgbasm -o obj/gb/main.o src/main.s
rgbasm -o obj/gb/sgb.o src/sgb.s
rgbasm -o obj/gb/pads.o src/pads.s
rgblink -dto sgbkeyirq.gb -n sgbkeyirq.sym -p 0xFF \
  obj/gb/init.o obj/gb/bcd.o obj/gb/euclid.o obj/gb/main.o obj/gb/sgb.o obj/gb/pads.o
rgbfix -jvsl 0x33 -t "SGB KEY IRQ" -k "P8" -p 0xFF sgbkeyirq.gb
