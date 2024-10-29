#!/usr/bin/env python3
"""
MBC1M to MBC1 converter for Game Boy multicart ROMs
Copyright 2024 Damian Yerrick
SPDX-License-Identifier: Zlib
"""
import os, sys, argparse

versionText = """MBC1M to MBC1 0.01
Copyright 2024 Damian Yerrick
Free software under zlib license.  No warranty."""

MBC1M_INNER_BANKSIZE = 256 * 1024
LOGO_OFFSET = 0x0104
LOGO_PREFIX = b'\xCE\xED\x66\x66'
TITLE_OFFSET = 0x0134
TITLE_LENGTH = 15
ROM_SIZE_OFFSET = 0x0148
ROM_SIZE_2_MiB = 0x06
HEADER_SUM_OFFSET = 0x014D
GLOBAL_SUM_OFFSET = 0x014E

def parse_argv(argv):
    p = argparse.ArgumentParser(
        description="Converts an 8 Mbit (1024 KiB) MBC1M ROM for Game Boy to MBC1 format."
    )
    p.add_argument("input",
                   help="path to a ROM image (size 1048576 bytes)")
    p.add_argument("output",
                   help="path to output ROM image")
    p.add_argument("--version", action="store_true",
                   help="print version and copyright notice and exit")

    # Handle --version explicitly to avoid rewrapping by argparse
    if args.version:
        print(versionText)
        sys.exit(1)

    return p.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)
    with open(args.input, "rb") as infp:
        subroms = [infp.read(MBC1M_INNER_BANKSIZE) for i in range(4)]
    for i, rom in enumerate(subroms):
        cmp = rom[LOGO_OFFSET:LOGO_OFFSET + len(LOGO_PREFIX)]
        okay = "OK " if cmp == LOGO_PREFIX else "ERR"
        name = rom[TITLE_OFFSET:TITLE_OFFSET + TITLE_LENGTH]
        name = name.replace(b'\x00', b' ').decode(errors="replace")
        print("ROM %d: %s %s %s" % (i, cmp.hex(), okay, name))

    # Double up each 256 KiB.  Leave odd slots in the output
    # unchanged, and change the first even slot's internal header.
    even_subroms = list(subroms)
    even_subroms[0] = rom0 = bytearray(even_subroms[0])

    # Correct the ROM size to prevent the emulator from
    # mistakenly detecting MBC1M
    rom0[ROM_SIZE_OFFSET] = ROM_SIZE_2_MiB

    # Correct the internal header's checksum
    header_sum = (sum(rom0[TITLE_OFFSET:HEADER_SUM_OFFSET])
                  + HEADER_SUM_OFFSET - TITLE_OFFSET)
    rom0[HEADER_SUM_OFFSET] = -header_sum % 0x100

    # Calculate global checksum over both even and odd slots
    rom0[GLOBAL_SUM_OFFSET:GLOBAL_SUM_OFFSET + 2] = [0, 0]
    global_sum = sum(sum(rom) for rom in subroms)
    global_sum += sum(sum(rom) for rom in even_subroms)
    rom0[GLOBAL_SUM_OFFSET] = (global_sum >> 8) & 0xFF
    rom0[GLOBAL_SUM_OFFSET + 1] = (global_sum >> 0) & 0xFF

    with open(args.output, "wb") as outfp:
        for a, b in zip(even_subroms, subroms):
            outfp.write(a)
            outfp.write(b)

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        main("""
./mbc1tombc1.py /home/pino/develop/emulators/mgba/cinema/gb/mooneye-gb/emulator-only/mbc1/multicart_rom_8Mb/test.gb mbc1out.gb
""".split())
    else:
        main()
