#!/bin/sh
set -e
rgbasm -hL -o uaflag.o uaflag.z80
rgblink -dtp 0xFF -o uaflag.gb -n uaflag.sym uaflag.o
rgbfix -jvsct "UKRAINE FLAG" -kP8 -l0x33 uaflag.gb
