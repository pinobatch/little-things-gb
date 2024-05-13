#!/bin/sh
set -e

mkdir -p obj/gb
rgbgfx -ut obj/gb/title_cubby.nam -o obj/gb/title_cubby.2b -b 0xD0 -c embedded tilesets/title_cubby.png
