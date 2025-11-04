#!/bin/sh
# Simplest build script for simplest picture displayer
# Copyright 2025 Damian Yerrick
# SPDX-License-Identifier: Zlib
set -e
mkdir -p obj/gb
rgbgfx -b 128 -c embedded -o obj/gb/simplest.2bpp -ut obj/gb/simplest.nam tilesets/title_cubby.png
rgbasm -o obj/gb/simplest.o src/simplest.s
rgbasm -o obj/gb/sgb.o src/sgb.s
rgbasm -o obj/gb/pads.o src/pads.s
rgblink -dt -n retention.sym -p 0xFF -o retention.gb obj/gb/simplest.o obj/gb/sgb.o obj/gb/pads.o
rgbfix -jvt "SGB RETENTION" -k "P8" -l 0x33 -p 0xFF retention.gb
