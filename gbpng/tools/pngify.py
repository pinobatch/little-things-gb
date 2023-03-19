#!/usr/bin/env python3
"""
PNG inserter for Game Boy and Game Boy Color ROM images

Conditions:
1. Free space at end of ROM must be at least as big as the PNG file
2. Program must not use first 41 bytes (first 5 RSTs or first byte of
   RST $28)
3. Either the GB global checksum at $014E or one PNG chunk's CRC32
   value will be wrong

Copyright 2018, 2023 Damian Yerrick

(insert zlib license here)

"""
import sys
import argparse
from zlib import crc32
import struct

expected_ihdr = bytes.fromhex("89504e470d0a1a0a0000000d49484452")

def parse_argv(argv):
    p = argparse.ArgumentParser()
    p.add_argument("gbfile", help="Game Boy ROM")
    p.add_argument("pngfile", help="PNG image")
    p.add_argument("outfile", help="polyglot file output")
    p.add_argument("-v", "--verbose", action="store_true")
    p.add_argument("-G", "--skip-global-sum", action="store_true",
                   help="skip modifying GB global checksum "
                   "(for compatibility with picky PNG decoders' CRC32 check)")
    return p.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)
    if args.verbose:
        print("args is", args, file=sys.stdout)
    with open(args.gbfile, "rb") as infp:
        gbdata = bytearray(infp.read())
    with open(args.pngfile, "rb") as infp:
        pngdata = infp.read()
    if not pngdata.startswith(expected_ihdr):
        raise ValueError("%s does not have a PNG header" % args.pngfile)
    ihdrdata = pngdata[12:16 + 13]
    ihcalccrc = crc32(ihdrdata) & 0xffffffff
    ihstoredcrc = struct.unpack_from(">I", pngdata, 16 + 13)[0]
    if args.verbose:
        print("pngify.py: note: %s IHDR chunk CRC is %08x; calculated CRC is %08x"
              % (args.pngfile, ihstoredcrc, ihcalccrc), file=sys.stderr)
    if ihcalccrc != ihstoredcrc:
        print("pngify.py: warning: %s PNG header CRC is wrong"
              % args.pngfile, file=sys.stderr)

    trimlen = len(gbdata.rstrip(gbdata[-1:]))
    if args.verbose:
        print("pngify.py: note: %s is %d bytes and appears trimmable to %d bytes"
              % (args.gbfile, len(gbdata), trimlen), file=sys.stderr)
    if len(gbdata) - trimlen - 4 < len(pngdata) - 33:
        raise ValueError(
            "%s is %d bytes and does not fit in %d unused bytes of %s"
            % (args.pngfile, len(pngdata),
               len(gbdata) - trimlen, args.gbfile)
        )

    # Turn the Game Boy program into an ancillary, private, copy-safe
    # chunk "prGm".  That last m is important because it must be
    # lowercase and a no-op so that rst $28 still works.
    gbdata[:33] = pngdata[:33]
    struct.pack_into(">I", gbdata, 33, trimlen - 41)
    gbdata[37:41] = b"prGm"
    gbcrc = crc32(gbdata[37:trimlen]) & 0xffffffff
    struct.pack_into(">I", gbdata, trimlen, gbcrc)
    gbdata[trimlen + 4:trimlen + 4 + len(pngdata) - 33] = pngdata[33:]

    # Correct the ROM's checksum, one of the few big-endian things
    # on a GB.  It causes the prGm chunk's CRC32 to be wrong.
    if not args.skip_global_sum:
        gbdata[0x14E:0x150] = bytes(2)
        checksum = sum(gbdata) & 0xFFFF
        struct.pack_into(">H", gbdata, 0x14E, checksum)
    with open(args.outfile, "wb") as outfp:
        outfp.write(gbdata)

if __name__=='__main__':
    main()
