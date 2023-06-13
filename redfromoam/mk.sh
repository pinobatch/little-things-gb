#!/bin/sh
set -e
romname="redfromoam"
headertitle="RED FROM OAM"

mkdir -p obj/gb
rgbgfx -c embedded -d1 -o obj/gb/chr.2bpp tilesets/chr.png
rgbasm -h -o obj/gb/main.o src/main.asm
rgblink -dt -p 0xFF -o "$romname.gb" -n "$romname.sym" \
  obj/gb/main.o
rgbfix -jv -p 0xFF -t "$headertitle" "$romname.gb"
