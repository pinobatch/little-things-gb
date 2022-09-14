#!/bin/sh
set -e

mkdir -p obj/gb
tools/vwf4cv.py -o obj/gb/fink.z80 -W12 -H16 tilesets/fink.png
tools/borderconv.py -v tilesets/sameboy.png obj/gb/sameboy.border
rgbasm -o obj/gb/fink.o obj/gb/fink.z80
rgbasm -h -o obj/gb/main.o src/main.z80
rgbasm -h -o obj/gb/sgb.o src/sgb.z80
rgbasm -h -o obj/gb/pads.o src/pads.z80
rgbasm -h -o obj/gb/ppuclear.o src/ppuclear.z80
rgbasm -h -o obj/gb/vwf4w.o src/vwf4w.z80
rgbasm -h -o obj/gb/unpb16.o src/unpb16.z80
rgblink -o bordercrossing.gb -n bordercrossing.sym -m bordercrossing.map -d obj/gb/main.o obj/gb/fink.o obj/gb/sgb.o obj/gb/pads.o obj/gb/ppuclear.o obj/gb/vwf4w.o obj/gb/unpb16.o
rgbfix -jsv -k P8 -l 0x33 -m MBC5 -p 0xFF -r 0 -t "BORDER CROSSING" bordercrossing.gb
