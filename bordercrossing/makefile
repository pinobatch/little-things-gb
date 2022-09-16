#!/usr/bin/env make -f

romname := bordercrossing
headertitle := BORDER CROSSING
borders := bootborder \
  sameboy classic_mac canada mexico Ross_by_Yoey Windows31 Windows98
objs := main title listpicker pakswap sgb pads ppuclear vwf4w  \
  unpb16 popslide fink borderdata
objdir := obj/gb

PY :=
GBEMU ?= sameboy

# Convenience targets
.PHONY: all run clean

all: $(romname).gb

run: $(romname).gb
	$(GBEMU) $<

clean:
	@mkdir -p $(objdir)
	-rm $(objdir)/*
	
# Border conversion
$(objdir)/%.border: tilesets/%.png
	@mkdir -p $(objdir)
	$(PY) tools/borderconv.py $< $@

# UI font and graphic conversion
$(objdir)/fink.z80: tilesets/fink.png
	@mkdir -p $(objdir)
	$(PY) tools/vwf4cv.py -o $@ -W12 -H16 $<

$(objdir)/finkmono.2bpp: tilesets/finkmono.png
	@mkdir -p $(objdir)
	$(PY) tools/pilbmp2nes.py --planes "0,1" -H16 $< $@

$(objdir)/%.nam.sentinel: tilesets/%.png
	@mkdir -p $(objdir)
	rgbgfx -u -d2 -t $(objdir)/$*.nam -o $(objdir)/$*.2bpp $<
	touch $@
$(objdir)/%.2bpp $(objdir)/%.nam: $(objdir)/%.nam.sentinel
	test -f $@

$(objdir)/%.pb16: $(objdir)/%
	$(PY) tools/pb16.py $< $@

# Assembly

$(objdir)/%.o: src/%.z80 src/hardware.inc
	@mkdir -p $(objdir)
	rgbasm -h -o $@ $<
$(objdir)/%.o: $(objdir)/%.z80
	rgbasm -h -o $@ $<

# Incbin dependencies
$(objdir)/main.o: $(objdir)/bootborder.border
$(objdir)/borderdata.o: $(foreach o,$(borders),$(objdir)/$(o).border)
$(objdir)/title.o: $(objdir)/titlepic.2bpp.pb16 $(objdir)/titlepic.nam
$(objdir)/pakswap.o: $(objdir)/finkmono.2bpp.pb16

# Linking
$(objdir)/$(romname).gb.sentinel: $(foreach o,$(objs),$(objdir)/$(o).o)
	rgblink -d -o "$(romname).gb" -n "$(romname).sym" -m "$(romname).map" $^
	touch $@
$(romname).gb: $(objdir)/$(romname).gb.sentinel makefile 
	rgbfix -jsv -k P8 -l 0x33 -m MBC5 -p 0xFF -r 0 -t "$(headertitle)" $@
$(romname).sym $(romname).map: $(objdir)/$(romname).gb.sentinel
	test -f $@