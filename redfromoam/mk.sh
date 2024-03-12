#!/bin/sh
set -e
romname="redfromoam"
headertitle="RED FROM OAM"

mkdir -p obj/gb
"${RGBDS}rgbgfx" -c embedded -d1 -o obj/gb/chr.2bpp tilesets/chr.png
"${RGBDS}rgbasm" -h -o obj/gb/main.o src/main.asm
"${RGBDS}rgblink" -dt -p 0xFF -o "$romname.gb" -n "$romname.sym" \
  obj/gb/main.o
"${RGBDS}rgbfix" -jv -p 0xFF -t "$headertitle" "$romname.gb"
