# Makefile for building Game Boy software with 
# Copyright 2019 Damian Yerrick
# (insert zlib license here)

title   := nosuchthing
version := 0.02wip
gbobjlist := \
  header gbmain gbppu gbpb16 gbiur
ggobjlist := \
  start

gbobjdir := obj/gb
gbsrcdir := src
ggobjdir := obj/gg
ggsrcdir := src/gg
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

ggrun: $(title).gg $(title).sym
	"$(HOME)/develop/meka/meka/meka" $<

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
$(gbobjdir)/%.2b: tilesets/%.png
	rgbgfx -o $@ $<

$(gbobjdir)/%.iu: $(gbobjdir)/%.2b
	$(PY) tools/incruniq.py $< $@

%.pb16: tools/pb16.py %
	$(PY) $^ $@

# assembly
$(gbobjdir)/%.o: $(gbsrcdir)/%.z80 $(gbsrcdir)/sm83isa.mac $(gbsrcdir)/gbhardware.inc $(gbsrcdir)/gbglobal.inc
	ca65 -g -o $@ $<
$(ggobjdir)/%.o: $(ggsrcdir)/%.z80 $(ggsrcdir)/z80isa.mac
	ca65 -g -o $@ $<

# linking

# Use .INTERMEDIATE to create a serial bottleneck, working around
# GNU Make's inconvenient handling of multiple outputs in parallel
# Thanks to Ivan Zaentsev https://stackoverflow.com/a/47951465/2738262
.INTERMEDIATE: rom_and_dbg
objlisto := \
  $(foreach o,$(gbobjlist),$(gbobjdir)/$(o).o) \
  $(foreach o,$(ggobjlist),$(ggobjdir)/$(o).o)
rom_and_dbg: diglot.cfg $(objlisto)
	ld65 -o $(title).gb --dbgfile $(title).dbg -C $^
	$(PY) tools/gbheader.py -vj -k "mm" -l 0x33 -m 0 -n 0 -p 0xFF -t "FOR GAME GEAR" -r 0 $(title).gb

$(title).dbg $(title).gb: rom_and_dbg
	touch $@

$(title).gg: $(title).gb
	ln $< $@

# debug file generation
%.sym: %.dbg
	$(PY) tools/dbgtosym.py $< > $@

# Packaging
$(gbobjdir)/index.txt: makefile
	echo "This file ensures creation of this directory" > $@

$(ggobjdir)/index.txt: makefile
	echo "This file ensures creation of this directory" > $@

# This dependency list approximates "every file in zip.in"
$(title)-$(version).zip: \
  zip.in $(title).gb $(gbobjdir)/index.txt $(ggobjdir)/index.txt README.md
	$(PY) tools/zipup.py $< $(title) -o $@
	-advzip -z2 $@

