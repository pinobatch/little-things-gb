#!/bin/sh
set -e
mkdir -p build
python3 tools/pitchtable.py > build/pitchtable.asm
rgbgfx -c embedded -o build/bg.2bpp -ut build/bg.nam tilesets/bg.png
rgbasm -o build/pitchtable.o build/pitchtable.asm
rgbasm -o build/audio.o src/audio.asm
rgbasm -o build/main.o src/main.asm
rgbasm -o build/pads.o src/pads.asm
rgblink -o drumkit.gb -n drumkit.sym -dt \
  build/main.o build/pads.o build/audio.o build/pitchtable.o
rgbfix -jvt 'PINO DRUMKIT' -l 0x33 -k 'P8' drumkit.gb
