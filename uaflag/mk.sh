#!/bin/sh
set -e
"${RGBDS}rgbasm" -hL -o uaflag.o uaflag.z80
"${RGBDS}rgblink" -dtp 0xFF -o uaflag.gb -n uaflag.sym uaflag.o
"${RGBDS}rgbfix" -jvsct "UKRAINE FLAG" -kP8 -l0x33 uaflag.gb
