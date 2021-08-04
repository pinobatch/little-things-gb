# Makefile for building Game Boy software with 
# Copyright 2019-2021 Damian Yerrick
# (insert zlib license here)

title   := tearing
version := wip
objlist := \
  main

objdir := obj/gb
srcdir := src
imgdir := tilesets

CA65 := ca65
LD65 := ld65

# Flags for native tools written in C
CC := gcc
CFLAGS := -std=gnu99 -Wall -Wextra -DNDEBUG -Os

# Flags that vary between Windows and POSIX build environments
ifdef COMSPEC
PY:=py -3
DOTEXE:=.exe
else
PY:=python3
DOTEXE:=
endif

PNGTOCHR := ../common/tools/pngtochr$(DOTEXE)

# phony targets

.PHONY: run all dist zip clean

run: $(title).gb $(title).sym
	bgb $<

all: $(title).gb

dist: zip

zip: $(title)-$(version).zip

clean:
	-rm $(objdir)/*.o $(objdir)/*.2b $(objdir)/*.iu
	-rm $(title).dbg $(title).sym

# incbins and other dependencies
$(objdir)/main.o: \
  $(objdir)/movingtiles16x16.2b \
  $(objdir)/stilltiles16x16.2b

# Building native tools
.SECONDARY: $(PNGTOCHR)

$(PNGTOCHR): \
  ../common/tools/indexedimage.c ../common/tools/lodepng.c \
  ../common/tools/musl_getopt.c ../common/tools/pngto.c
	$(CC) -s $(CFLAGS) -o $@ $^

# Graphics conversion

# .2b denotes the 2-bit tile format used by Game Boy and
# Game Boy Color, as well as Super NES mode 0 (all planes),
# mode 1 (third plane), and modes 4 and 5 (second plane).
$(objdir)/%16x16.2b: tilesets/%.png $(PNGTOCHR)
	$(PNGTOCHR) -o $@ "-p0,1" -W16 -H16 $<

# assembly
$(objdir)/%.o: $(srcdir)/%.z80 $(srcdir)/hardware.inc
	rgbasm -h -Wall -o $@ $<

# linking

# Use .INTERMEDIATE to create a serial bottleneck, working around
# inconvenient handling of multiple outputs in parallel in GNU Make.
# (Though Make 4.3 introduced grouped targets, Ubuntu LTS is on 4.2.)
# Thanks to Ivan Zaentsev https://stackoverflow.com/a/47951465/2738262
.INTERMEDIATE: rom_and_dbg
objlisto := \
  $(foreach o,$(objlist),$(objdir)/$(o).o)
rom_and_dbg: $(objlisto)
	rgblink -dt -o $(title).gb -n $(title).sym  $^
	rgbfix -jv -t "TEARING DEMO" -k "P8" $(title).gb

$(title).sym $(title).gb: rom_and_dbg
	touch $@

# Packaging
$(objdir)/index.txt: makefile
	echo "This file ensures creation of this directory" > $@

# This dependency list approximates "every file in zip.in"
$(title)-$(version).zip: \
  zip.in $(title).gb $(objdir)/index.txt README.md
	$(PY) ../common/tools/zipup.py $< $(title) -o $@
	-advzip -z2 $@

