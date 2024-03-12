
title := sgbears
version := wip
objlist := main ppuclear unpb16 pads sgb bcd v3bears

ifdef COMSPEC
# Assume Windows
DOTEXE:=.exe
PY:=py -3
else
DOTEXE:=
PY:=python3
endif

# Support out-of-PATH RGBDS
RGBASM  := $(RGBDS)rgbasm
RGBLINK := $(RGBDS)rgblink
RGBGFX  := $(RGBDS)rgbgfx
RGBFIX  := $(RGBDS)rgbfix

.PHONY: all default run zip dist clean
default: $(title).gb

# Native tools part #################################################

CC:=gcc
CFLAGS:=-Wall -Wextra -Os
TOOLSDIR:=../common/tools
PNGTOCHR:=$(TOOLSDIR)/pngtochr$(DOTEXE)
PB8:=$(TOOLSDIR)/pb8$(DOTEXE)
.SECONDARY: $(PNGTOCHR) $(PB8)

# Unity build the converter
$(PNGTOCHR): \
  $(TOOLSDIR)/indexedimage.c $(TOOLSDIR)/lodepng.c \
  $(TOOLSDIR)/musl_getopt.c $(TOOLSDIR)/pngto.c
	$(CC) $(CFLAGS) -o $@ $^

$(PNGTOCHR): \
  $(TOOLSDIR)/indexedimage.h $(TOOLSDIR)/lodepng.h $(TOOLSDIR)/musl_getopt.h

$(PB8): $(TOOLSDIR)/pb8.c
	$(CC) $(CFLAGS) -o $@ $^

# Game Boy program part #############################################

obj/gb/%.o: src/%.z80 src/hardware.inc
	$(RGBASM) -h -o $@ $<

obj/gb/%.o: obj/gb/%.z80
	$(RGBASM) -h -o $@ $<

obj/gb/main.o: \
  obj/gb/sgb-playmate.1b obj/gb/menutiles.1b obj/gb/credit.1b.pb16

$(title).gb: $(foreach o,$(objlist),obj/gb/$(o).o)
	$(RGBLINK) -dto $@ -m $(title).map -n $(title).sym $^
	$(RGBFIX) -jsvt "THE THREE BEARS" -l0x33 -kP8 $@

# Graphic conversion ################################################

obj/gb/%.2b: tilesets/%.png
	$(RGBGFX) -o $@ $<

obj/gb/%.h.1b: tilesets/%.png
	$(RGBGFX) -d1 -h -o $@ $<

obj/gb/%.1b: tilesets/%.png
	$(RGBGFX) -d1 -o $@ $<

obj/gb/%.u.2b: tilesets/%.png
	$(RGBGFX) -o $@ $< -ut $(basename $(basename $@)).nam

# Partial workaround for lack of grouped targets in GNU Make pre-4.3
# to break the build if the other file doesn't exist
obj/gb/%.nam: obj/gb/%.u.2b
	test -f $< && test -f $@

obj/gb/%.1b: tilesets/v3/%.png
	rgbgfx -d1 -o $@ $<

# Most compressed files are decompressed in one shot, or two in the
# case of a tileset that is decompressed to $9000 and $8800
%.pb8: $(PB8) %
	$^ -z -l2048 $@
%.pb16: $(PB8) %
	$^ -m2 -z -l2048 $@

# credits is decompressed in a separate shot for each 13x2-tile cel

obj/gb/credit.1b.pb16: $(PB8) obj/gb/credit.1b
	$^ -m2 -z -l208 $@

V3CONV := tools/v3conv.py

obj/gb/v3bears.z80: $(V3CONV) tilesets/v3/palette.txt tilesets/v3/nobears.png tilesets/v3/papa_bear.png tilesets/v3/baby_bear.png tilesets/v3/mama_bear.png
	$(PY) $(V3CONV) -o $@ --palettes $(wordlist 2, $(words $^), $^)

# Packaging part ####################################################

run: $(title).gb
	bgb $<

obj/gb/index.txt: makefile
	echo File ensures directory creation > $@

$(title)-$(version).zip: zip.in $(title).gb README.md obj/gb/index.txt
	zip -9u $@ -@ < $<

dist: $(title)-$(version).zip
zip: $(title)-$(version).zip

clean:
	# Don't remove tools in common folder
	-rm tools/pngtochr$(DOTEXE) tools/pb8$(DOTEXE)
	-rm obj/gb/*.pal obj/gb/*.1b obj/gb/*.2b obj/gb/*.4b obj/gb/*.nam
	-rm obj/gb/*.o obj/gb/*.pb16 obj/gb/*.pb8 obj/gb/*.z80
