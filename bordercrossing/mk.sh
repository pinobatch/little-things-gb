#!/bin/sh
set -e

mkdir -p obj/gb
tools/vwf4cv.py -o obj/gb/fink.z80 -W12 -H16 tilesets/fink.png
