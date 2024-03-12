#!/usr/bin/make -f
#
# Makefile for Libbet and the Magic Floor
# Copyright 2014-2018 Damian Yerrick
#
# Copying and distribution of this file, with or without
# modification, are permitted in any medium without royalty
# provided the copyright notice and this notice are preserved.
# This file is offered as-is, without any warranty.
#

# Used in the title of the zipfile and .gb executable
title:=firstwhite
version:=0.02

# Space-separated list of asm files without .z80 extension
# (use a backslash to continue on the next line)
objlist := header init main ppuclear unpb16

# To override the emulator:
# GBEMU=mgba-qt make
ifdef COMSPEC
  ifndef GBEMU
    GBEMU := start ""
  endif
  PY := py -3
else
  ifndef GBEMU
    GBEMU := sameboy
  endif
  PY := python3
endif

# Support out-of-PATH RGBDS
RGBASM  := $(RGBDS)rgbasm
RGBLINK := $(RGBDS)rgblink
RGBGFX  := $(RGBDS)rgbgfx
RGBFIX  := $(RGBDS)rgbfix

.SUFFIXES:
.PHONY: run all dist zip

run: $(title).gb
	$(GBEMU) $<
all: $(title).gb

clean:
	-rm obj/gb/*.z80 obj/gb/*.o obj/gb/*.chrgb obj/gb/*.pb16
	-rm obj/gb/*.nam

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
	git ls-files | grep -e "^[^.0]" > $@
	echo $(title).gb >> $@
	echo zip.in >> $@

obj/gb/index.txt: makefile
	echo "Files produced by build tools go here. (This file's existence forces the unzip tool to create this folder.)" > $@

# The ROM

objlisto = $(foreach o,$(objlist),obj/gb/$(o).o)

$(title).gb: $(objlisto)
	$(RGBLINK) -p 0xFF -m$(title).map -n$(title).sym -o$@ $^
	$(RGBFIX) -p 0xFF -v $@

obj/gb/%.o: src/%.z80 src/hardware.inc src/global.inc
	$(RGBASM) -h -o $@ $<

obj/gb/%.o: obj/gb/%.z80
	$(RGBASM) -h -o $@ $<

# Files that will be included with incbin

obj/gb/main.o: \
  obj/gb/youremulatorsucks.u.chrgb.pb16 obj/gb/youremulatorsucks.nam.pb16

# Graphics conversion

# .chrgb (CHR data for Game Boy) denotes the 2-bit tile format
# used by Game Boy and Game Boy Color, as well as Super NES
# mode 0 (all planes), mode 1 (third plane), and modes 4 and 5
# (second plane).
obj/gb/%.chrgb: tilesets/%.png
	rgbgfx -o $@ $<

# Unique tiles and tilemap
obj/gb/%.u.chrgb: obj/gb/%.chrgb
	$(PY) tools/uniq.py $< $@ $(<:.chrgb=.nam)

# workaround for Make's multi-output parallelism failure
obj/gb/%.nam: obj/gb/%.u.chrgb
	touch $@

%.pb16: tools/pb16.py %
	$(PY) $^ $@
