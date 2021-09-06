
title := sgbears
version := wip
objlist := main ppuclear unpb16 pads sgb

ifdef COMSPEC
# Assume Windows
DOTEXE:=.exe
PY:=py -3
else
DOTEXE:=
PY:=python3
endif

.PHONY: all default run zip dist clean
default: $(title).gb

# Native tools part #################################################

CC:=gcc
CFLAGS:=-Wall -Wextra -Os

PNGTOCHR:=tools/pngtochr$(DOTEXE)
PB8:=tools/pb8$(DOTEXE)

# Unity build the converter
$(PNGTOCHR): \
  tools/indexedimage.c tools/lodepng.c tools/musl_getopt.c \
  tools/pngto.c
	$(CC) $(CFLAGS) -o $@ $^

$(PNGTOCHR): \
  tools/indexedimage.c tools/lodepng.c tools/musl_getopt.c

$(PB8): tools/pb8.c
	$(CC) $(CFLAGS) -o $@ $^

# Game Boy program part #############################################

obj/gb/%.o: src/%.z80 src/hardware.inc
	rgbasm -o $@ $<

obj/gb/main.o: \
  obj/gb/Bears_128.4b.pb16 obj/gb/Bears_128.pal \
  obj/gb/Goldi_hmmm.u.2b.pb16 obj/gb/Goldi_hmmm.nam \
  obj/gb/judgments.2b.pb16 obj/gb/sgb-playmate.h.1b

$(title).gb: $(foreach o,$(objlist),obj/gb/$(o).o)
	rgblink -dto $@ -m $(title).map -n $(title).sym $^
	rgbfix -jsvt "THE THREE BEARS" -l0x33 -kP8 $@

# Graphic conversion ################################################

obj/gb/Bears_128.4b: $(PNGTOCHR) tilesets/Bears_128.png
	$^ -W40 -H128 "-p0,1;2,3" --num-colors 16 -o $@

obj/gb/Bears_128.pal: $(PNGTOCHR) tilesets/Bears_128.png
	$^ -c 0BBBBBGGGGGRRRRR --little -o $@

obj/gb/%.2b: tilesets/%.png
	rgbgfx -o $@ $<

obj/gb/%.h.1b: tilesets/%.png
	rgbgfx -d1 -h -o $@ $<

obj/gb/%.u.2b: tilesets/%.png
	rgbgfx -o $@ $< -ut $(basename $(basename $@)).nam

# Partial workaround for lack of grouped targets in GNU Make pre-4.3
# to break the build if the other file doesn't exist
obj/gb/%.nam: obj/gb/%.u.2b
	test -f $< && test -f $@

# Most compressed files are decompressed in one shot, or two in the
# case of images that get decompressed to $9000 and $8800
%.pb8: $(PB8) %
	$^ -z -l2048 $@
%.pb16: $(PB8) %
	$^ -m2 -z -l2048 $@

# Each bear (order Papa, Cubby, Mama)
# is 40x128 pixels at 4bpp or 2560 bytes
obj/gb/Bears_128.4b.pb16: $(PB8) obj/gb/Bears_128.4b
	$^ -m2 -l2560 $@

# Each judgment (order too early, just right, too late)
# is 40x128 pixels at 4bpp or 2560 bytes
obj/gb/judgments.2b.pb16: $(PB8) obj/gb/judgments.2b
	$^ -m2 -l256 $@


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
	-rm $(PNGTOCHR) $(PB8)
	-rm obj/gb/*.pal obj/gb/*.1b obj/gb/*.2b obj/gb/*.4b obj/gb/*.nam
	-rm obj/gb/*.o obj/gb/*.pb16 obj/gb/*.pb8