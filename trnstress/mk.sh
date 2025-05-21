#!/bin/sh
set -e

title=trnstress
inttitle='TRN STRESS'

objlist="init irqhandler main title menu scramble frame_timing \
  pads ppuclear sgb unpb16 vwfdraw vwflabels"
genobjlist='vwf7_cp144p localvars'
objlistfull='borders'
objlist32k='borders32k'

gfxwithnamlist='title_cubby menu_cubby'
gfx2blist='title_letters'
gfx4blist='frame_timing_tiles'
pb16list=''
borderlist="title menu Batten_Scrapefoot Lowneys_cocoa Newell_Tilly \
  Pughe_Harmless Caldecott_she-bear"

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
for f in $gfx4blist; do
  python3 tools/pilbmp2nes.py --planes "0,1;2,3" "tilesets/$f.png" "obj/gb/$f.4b"
done
for f in $gfx2blist $gfxwithnamlist $pb16list; do
  python3 tools/pb16.py "obj/gb/$f.2b" "obj/gb/$f.2b.pb16"
done
for f in $gfx4blist; do
  python3 tools/pb16.py "obj/gb/$f.4b" "obj/gb/$f.4b.pb16"
done
for f in $borderlist; do
  python3 tools/borderconv.py --skip-7f "tilesets/${f}_border.png" "obj/gb/$f.border"
done

# Allocate variables
objlist_save=$(printf "src/%s.s " $objlist $objlistfull)
objlist_o=$(printf "obj/gb/%s.o " $objlist $objlistfull $genobjlist)
objlist32k_o=$(printf "obj/gb/%s.o " $objlist $objlist32k $genobjlist)
python3 tools/savescan.py -o obj/gb/localvars.s $objlist_save

# Assemble
for f in $genobjlist; do
  "${RGBDS}rgbasm" -o "obj/gb/$f.o" "obj/gb/$f.s"
done
for f in $objlist $objlistfull $objlist32k; do
  "${RGBDS}rgbasm" -o "obj/gb/$f.o" "src/$f.s"
done

# Build ROM
"${RGBDS}rgblink" -d -o $title.gb -n $title.sym -p 0xFF \
  $objlist_o
"${RGBDS}rgbfix" -jvsl 0x33 -m "MBC5" -t "$inttitle" -k "P8" -p 0xFF $title.gb
"${RGBDS}rgblink" -dt -o $title-32k.gb -n $title-32k.sym -p 0xFF \
  $objlist32k_o
"${RGBDS}rgbfix" -jvsl 0x33 -t "$inttitle" -k "P8" -p 0xFF $title-32k.gb
