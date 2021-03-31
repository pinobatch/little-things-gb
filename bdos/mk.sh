#!/bin/sh
#
# who needs gnu make for something this simple?
#
# Copyright 2021 Damian Yerrick
# Copying and distribution of this file, with or without
# modification, are permitted in any medium without royalty
# provided the copyright notice and this notice are preserved.
# This file is offered as-is, without any warranty.
#
set -e

inttitle='BDOS TEST'
onebitlist='font_Wasted'

mkdir -p obj/gb
for filename in $onebitlist; do
  rgbgfx -d 1 -o "obj/gb/$filename.1b" "tilesets/$filename.png"
done
rgbasm -h -o "obj/gb/bdos.o" "src/bdos.z80"
rgbasm -h -o "obj/gb/$1.o" "src/$1.z80"
rgblink -o "$1.gb" -p 0xFF -m "$1.map" -n "$1.sym" "obj/gb/bdos.o" "obj/gb/$1.o"
rgbfix -jvt "$inttitle" -p 0xFF "$1.gb"

# to build:
# mk.sh main
# to run:
# wine /path/to/bgb.exe -watch main.gb &
# to make zip:
# zip -9 bdos.zip -@<zip.in
