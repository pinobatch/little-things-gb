# Makefile for building Game Boy software with 
# Copyright 2019 Damian Yerrick
# (insert zlib license here)

title   := nosuchthing
version := 0.02wip
objlist := \
  header gbmain gbppu gbpb16 gbiur

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

# phony targets

.PHONY: run all dist zip clean

run: $(title).gb $(title).sym
	wine "$(HOME)/.wine/drive_c/Program Files (x86)/bgb/bgb.exe" $<

all: $(title).gb

dist: zip

zip: $(title)-$(version).zip

clean:
	-rm tools/pb8$(DOTEXE) $(objdir)/*.o $(objdir)/*.2b $(objdir)/*.iu
	-rm $(title).dbg $(title).sym

# incbins and other dependencies
$(objdir)/gbmain.o: $(objdir)/NoSuchThingAsNintendo.iu

# Building native tools
.SECONDARY: tools/pb8$(DOTEXE)

tools/%$(DOTEXE): tools/%.c
	$(CC) -static $(CFLAGS) -o $@ $^

# Graphics conversion

# .2b denotes the 2-bit tile format used by Game Boy and
# Game Boy Color, as well as Super NES mode 0 (all planes),
# mode 1 (third plane), and modes 4 and 5 (second plane).
obj/gb/%.2b: tilesets/%.png
	rgbgfx -o $@ $<

obj/gb/%.iu: obj/gb/%.2b
	$(PY) tools/incruniq.py $< $@

%.pb16: tools/pb16.py %
	$(PY) $^ $@

# assembly
$(objdir)/%.o: $(srcdir)/%.z80 $(srcdir)/sm83isa.mac $(srcdir)/gbhardware.inc $(srcdir)/gbglobal.inc
	ca65 -g -o $@ $<

# linking

# Use .INTERMEDIATE to create a serial bottleneck, working around
# GNU Make's inconvenient handling of multiple outputs in parallel
# Thanks to Ivan Zaentsev https://stackoverflow.com/a/47951465/2738262
.INTERMEDIATE: rom_and_dbg
rom_and_dbg: diglot.cfg $(foreach o,$(objlist),$(objdir)/$(o).o)
	ld65 -o $(title).gb --dbgfile $(title).dbg -C $^
	$(PY) tools/gbheader.py -vj -k "mm" -l 0x33 -m 0 -n 0 -p 0xFF -t "CA83DEMO" -r 0 $(title).gb

$(title).dbg $(title).gb: rom_and_dbg
	touch $@

# debug file generation
%.sym: %.dbg
	$(PY) tools/dbgtosym.py $< > $@

# Packaging
$(objdir)/index.txt: makefile
	echo "This file ensures creation of this directory" > $@

# This dependency list approximates "every file in zip.in"
$(title)-$(version).zip: \
  zip.in $(title).gb $(objdir)/index.txt README.md
	$(PY) tools/zipup.py $< $(title) -o $@
	-advzip -z2 $@

