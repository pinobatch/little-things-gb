#!/usr/bin/make -f
#
# Makefile for No Such Thing ROM
# Copyright 2014-2020 Damian Yerrick
#
# Copying and distribution of this file, with or without
# modification, are permitted in any medium without royalty
# provided the copyright notice and this notice are preserved.
# This file is offered as-is, without any warranty.
#

# Used in the title of the zipfile and .gb executable
title:=nosuchthing
version:=wip

# Space-separated list of asm files without .z80 extension
# (use a backslash to continue on the next line)
objlist := header main ppuclear unpb16 uniur
pngfile := tilesets/NoSuchThingAsNintendo.png

ifdef COMSPEC
  ifndef GBEMU
    GBEMU := start ""
  endif
  PY := py -3
else
  ifndef GBEMU
    GBEMU := ~/.wine/drive_c/Program\ Files\ \(x86\)/bgb/bgb.exe
  endif
  PY := python3
endif

.SUFFIXES:
.PHONY: run all dist zip

run: $(title).gb
	$(GBEMU) $<
all: $(title).gb

clean:
	-rm obj/gb/*.z80 obj/gb/*.o obj/gb/*.iu obj/gb/*.chrgb

# Packaging

dist: zip
zip: $(title)-$(version).zip

# The zipfile depends on every file in zip.in, but as a shortcut,
# mention only files on which the ROM doesn't itself depend.
$(title)-$(version).zip: zip.in $(title).gb \
  README.md CHANGES.txt obj/gb/index.txt
	$(PY) tools/zipup.py $< $(title)-$(version) -o $@
	-advzip -z3 $@

# Build zip.in from the list of files in the Git tree
zip.in: makefile
	git ls-files | grep -e "^[^.]" > $@
	echo $(title).gb.png >> $@
	echo zip.in >> $@

obj/gb/index.txt: makefile
	echo "Files produced by build tools go here. (This file's existence forces the unzip tool to create this folder.)" > $@

# The ROM

objlisto = $(foreach o,$(objlist),obj/gb/$(o).o)

$(title).gb: $(objlisto)
	rgblink -p 0xFF -m$(title).map -n$(title).sym -o$@ $^
	rgbfix -p 0xFF -v $@

obj/gb/%.o: obj/gb/%-dedent.z80 src/hardware.inc src/global.inc
	rgbasm -o $@ $<

obj/gb/%.o: obj/gb/%.z80
	rgbasm -o $@ $<

obj/gb/%-dedent.z80: src/%.z80
	$(PY) tools/bgrdedent.py -o $@ $<

# Files that will be included with incbin

obj/gb/main.o: obj/gb/NoSuchThingAsNintendo.iu

# Graphics conversion

# .chrgb (CHR data for Game Boy) denotes the 2-bit tile format
# used by Game Boy and Game Boy Color, as well as Super NES
# mode 0 (all planes), mode 1 (third plane), and modes 4 and 5
# (second plane).
obj/gb/%.chrgb: tilesets/%.png
	rgbgfx -o $@ $<

obj/gb/%.iu: obj/gb/%.chrgb
	$(PY) tools/incruniq.py $< $@

%.pb16: tools/pb16.py %
	$(PY) $^ $@
