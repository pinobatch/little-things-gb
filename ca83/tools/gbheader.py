#!/usr/bin/env python3
"""
Header


"""
import argparse
import os
import sys

versionText = """gbheader 0.01
Copyright 2019 Damian Yerrick
License: same as zlib"""

# When the Game Boy is turned on, it displays an image at 0x104-0x133
# to diagnose poor contact with the cartridge.  If it matches a
# stored copy in the boot ROM, and the sum of bytes at 0x0134-0x014C
# in the header matches a checksum at 0x014D, it assumes the data and
# address buses are clean and runs the game.  Otherwise, it freezes
# to protect the data in the cartridge's battery-backed SRAM.
diagnostic_image = (
    b"\xCE\xED\x66\x66\xCC\x0D\x00\x0B\x03\x73\x00\x83\x00\x0C\x00\x0D\x00\x08\x11\x1F\x88\x89\x00\x0E"
    b"\xDC\xCC\x6E\xE6\xDD\xDD\xD9\x99\xBB\xBB\x67\x63\x6E\x0E\xEC\xCC\xDD\xDC\x99\x9F\xBB\xB9\x33\x3E"
)

def parse_fix_spec(fix_spec):
    fix_spec = set(fix_spec)
    unrecog = "".join(sorted(fixspec.difference("ghl")))
    if unrecog:
        raise ValueError("unrecognized fix_spec letters: %s" % unrecog)
    return fix_spec

def parse_game_id(game_id):
    game_id = game_id.encode("ascii")
    if len(game_id) != 4:
        raise ValueError("game ID length not 4: %s" % game_id.decode("ascii"))
    return game_id

def parse_publisher(name):
    name = name.encode("ascii")
    if len(name) != 2:
        raise ValueError("publisher ID length not 2: %s" % name.decode("ascii"))
    return name

def parse_title(name):
    name = name.strip().encode("ascii")
    if len(name) > 15:
        raise ValueError("title too long: %s" % name.decode("ascii"))
    return name + b"\0" * (15 - len(name))

def parse_byte_value(tnum):
    if tnum.startswith('$'):
        num = int(tnum[1:], 16)
    elif tnum.startswith('0x'):
        num = int(tnum[2:], 16)
    else:
        num = int(tnum, 10)
    if not 0x00 <= num <= 0xFF:
        raise ValueError("byte value not 0-255: %s" % tnum)
    return num

def parse_argv(argv):
    p = argparse.ArgumentParser()
    p.add_argument("-C", "--gbc-only",
                   dest="gbcmode", action='store_const', const=0xC0,
                   help="mark as Game Boy Color exclusive (0x143=0xC0)")
    p.add_argument("-c", "--gbc",
                   dest="gbcmode", action='store_const', const=0x80,
                   help="mark as Game Boy Color dual mode (0x143=0x80)")
    p.add_argument("-f", "--fix", metavar="fix_spec",
                   type=parse_fix_spec, default=set(),
                   help="fix header values (l: logo; h: header checksum; "
                   "g: global checksum")
    p.add_argument("-i", "--game-id", type=parse_game_id,
                   help="set game ID at 0x13F to 4 characters")
    p.add_argument("-j", "--not-japan",
                   dest="region", action='store_const', const=0x01,
                   help="set region to not-Japan (0x14A=0x01)")
    p.add_argument("-k", "--publisher", type=parse_publisher,
                   help="set publisher at 0x144 to 2 characters "
                   "and clear old publisher (0x14B=0x33)")
    p.add_argument("-l", "--old-publisher", type=parse_byte_value,
                   help="set old publisher at 0x14B (ignored with -k or -s)")
    p.add_argument("-m", "--mapper", "--mbc", metavar="mbc_type",
                   type=parse_byte_value,
                   help="set mapper type at 0x147")
    p.add_argument("-n", "--rom-version", metavar="rom_version",
                   type=parse_byte_value,
                   help="set ROM version at 0x14C")
    p.add_argument("-p", "--pad-with", metavar="pad_value",
                   type=parse_byte_value,
                   help="pad to power of 2 with this value and adjust "
                   "ROM size at 0x148")
    p.add_argument("-r", "--ram-size", metavar="ram_size",
                   type=parse_byte_value,
                   help="set RAM size at 0x148")
    p.add_argument("-s", "--sgb",
                   dest="sgbmode", action='store_const', const=0x03,
                   help="set SGB mode (0x146=0x03) "
                   "and clear old publisher (0x14B=0x33)")
    p.add_argument("-t", "--title", type=parse_title,
                   help="set title at 0x134 to up to 15 characters "
                   "(up to 11 if using -i)")
    p.add_argument("-V", "--version", action="version",
                   version=versionText)
    p.add_argument("-v", "--fix-all",
                   dest="fix", action='store_const', const=set("ghl"),
                   help="same as --fix ghl")
    p.add_argument("file",
                   help="path of a Game Boy ROM image whose header to overwrite")
    return p.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)
    with open(args.file, "rb") as infp:
        rom = bytearray(infp.read())

    # Apply chosen fixes
    if args.old_publisher is not None:
        rom[0x14B] = args.old_publisher
    if args.title is not None:
        assert len(args.title) == 15
        rom[0x134:0x143] = args.title
    if args.game_id is not None:
        assert len(args.game_id) == 4
        rom[0x13F:0x143] = args.game_id
    if args.old_publisher is not None:
        rom[0x14B] = args.old_publisher
    if args.publisher is not None:
        assert len(args.publisher) == 2
        rom[0x144:0x146] = args.publisher
        rom[0x14B] = 0x33
    if args.rom_version is not None:
        rom[0x14C] = args.rom_version
    if args.gbcmode is not None:
        rom[0x143] = args.gbcmode
    if args.sgbmode:
        rom[0x146] = 0x03
        rom[0x14B] = 0x33
    if args.mapper is not None:
        rom[0x147] = args.mapper
    if args.ram_size is not None:
        rom[0x148] = args.ram_size
    if args.region is not None:
        rom[0x14A] = args.region
    if args.pad_with is not None:
        log2_rom_size = max(15, len(rom).bit_length() - 1)
        if len(rom) != 1 << log2_rom_size:
            log2_rom_size += 1
            pad_amount = (1 << log2_rom_size) - len(rom)
            rom.extend(bytes([args.pad_width]) * pad_amount)
        rom[0x148] = log2_rom_size - 15
    if 'h' in args.fix:
        headersum = sum(rom[0x134:0x14D]) + 0x14D - 0x134
        rom[0x14D] = -headersum % 0x100
    if 'l' in args.fix:
        assert len(diagnostic_image) == 48
        rom[0x104:0x134] = diagnostic_image
    if 'g' in args.fix:
        rom[0x14E] = rom[0x14F] = 0
        allsum = sum(rom) % 0x10000
        rom[0x14E] = allsum >> 8
        rom[0x14F] = allsum & 0xFF

    # And write out the ROM
    with open(args.file, "wb") as outfp:
        outfp.write(rom)

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        import shlex
##        main(["./gbheader.py", "--help"])
        main(shlex.split("""
./gbheader.py -vj -k "mm" -l 0x33 -m 0 -n 0 -p 0xFF -t "CA83DEMO" -r 0
../ca83.gb
"""))
    else:
        main()
