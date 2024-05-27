#!/bin/sh
set -e

title=trnstress
inttitle='TRN STRESS'
objlist="init irqhandler main pads ppuclear sgb unpb16 vwfdraw vwflabels"
genobjlist='vwf7_cp144p localvars'
gfxwithnamlist='title_cubby menu_cubby'
gfx2blist='title_letters'
pb16list=''
borderlist='title menu'

mkdir -p obj/gb

# Bespoke conversions
python3 tools/vwfbuild.py tilesets/vwf7_cp144p.png obj/gb/vwf7_cp144p.s

# Generic conversions
for f in $gfxwithnamlist; do
  rgbgfx -ut "obj/gb/$f.nam" -o "obj/gb/$f.2b" "@tilesets/$f.flags" "tilesets/$f.png"
done
for f in $gfx2blist; do
  rgbgfx -o "obj/gb/$f.2b" "@tilesets/$f.flags" "tilesets/$f.png"
done
for f in $gfx2blist $gfxwithnamlist $pb16list; do
  python3 tools/pb16.py "obj/gb/$f.2b" "obj/gb/$f.2b.pb16"
done
for f in $borderlist; do
  python3 tools/borderconv.py "tilesets/${f}_border.png" "obj/gb/$f.border"
done

# Allocate variables
python3 tools/savescan.py -o obj/gb/localvars.s src/*.s

# Assemble
for f in $genobjlist; do
  "${RGBDS}rgbasm" -o "obj/gb/$f.o" -h "obj/gb/$f.s"
done
for f in $objlist; do
  "${RGBDS}rgbasm" -o "obj/gb/$f.o" "src/$f.s"
done
objlisto=$(printf "obj/gb/%s.o " $objlist $genobjlist)

# Build ROM
"${RGBDS}rgblink" -d -o $title.gb -n trnstress.sym -p 0xFF \
  $objlisto
"${RGBDS}rgbfix" -jvsl 0x33 -t "$inttitle" -k "P8" -p 0xFF $title.gb
