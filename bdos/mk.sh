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

title=bdos
inttitle='BDOS TEST'
objlist='bdos main'
onebitlist='font_Wasted'

mkdir -p obj/gb
for filename in $onebitlist; do
  rgbgfx -d 1 -o "obj/gb/$filename.1b" "tilesets/$filename.png"
done
for filename in $objlist; do
  rgbasm -h -o "obj/gb/$filename.o" "src/$filename.z80"
done
objlisto=$(printf "obj/gb/%s.o " $objlist)
rgblink -o "$title.gb" -p 0xFF -m "$title.map" -n "$title.sym" $objlisto
rgbfix -jvt "$inttitle" -p 0xFF "$title.gb"

# to run:
# bgb -watch bdos.gb &
# to make zip:
# zip -9 bdos.zip -@<zip.in
