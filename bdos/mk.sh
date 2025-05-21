#!/bin/sh
#
# who needs gnu make for something this simple?
#
# Copyright 2021 Damian Yerrick
# Copying and distribution of this file, with or without
# modification, are permitted in any medium without royalty
# provided the copyright notice and this notice are preserved.
# This file is offered as-is, without any warranty.

# syntax:
# ./mk.sh math
# RGBDS=/path/to/rgbds/bin/ ./mk.sh math

set -e
if [ -z "$1" ]; then
  >&2 echo "$0: no program name given; try $0 progname"
  >&2 echo "    example: \`$0 math\` builds math.gb from src/math.z80"
  exit 1
fi

inttitle='BDOS TEST'
onebitlist='font_Wasted'

mkdir -p obj/gb
for filename in $onebitlist; do
  rgbgfx -d 1 -o "obj/gb/$filename.1b" "tilesets/$filename.png"
done
"${RGBDS}rgbasm" -o "obj/gb/bdos.o" "src/bdos.z80"
"${RGBDS}rgbasm" -o "obj/gb/$1.o" "src/$1.z80"
"${RGBDS}rgblink" -o "$1.gb" -p 0xFF -m "$1.map" -n "$1.sym" "obj/gb/bdos.o" "obj/gb/$1.o"
"${RGBDS}rgbfix" -jvt "$inttitle" -p 0xFF "$1.gb"

# to build:
# ./mk.sh main
# to run:
# wine /path/to/bgb.exe -watch main.gb &
# to make zip:
# zip -9 bdos.zip -@<zip.in
