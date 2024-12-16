#!/usr/bin/env python3
"""
PNG inserter for Game Boy and Game Boy Color ROM images
Copyright 2018, 2024 Damian Yerrick
SPDX-License-Identifier: Zlib

Conditions:
1. Free space at end of ROM must be at least as big as the PNG file
   minus 25 bytes
2. Program must not use first 41 bytes (first 5 RSTs or first byte of
   RST $28)
"""
import sys
import argparse
from zlib import crc32
import struct

versionText = """pngify 0.03a1
Copyright 2024 Damian Yerrick.  Free software under zlib License."""
helpText = """Makes a polyglot of a suitable Game Boy ROM and a PNG image."""
helpEnd = """The ROM must have enough space at the end, must not use RST $00-$20,
and RST $28 must begin with LD L, L if used."""

# All PNG images begin with these 16 bytes: 8 bytes of signature
# followed by the big-endian length and type of the first chunk,
# which is always a 13-byte IHDR.  After these are the IHDR body
# and CRC32.
expected_ihdr = bytes.fromhex("89504e470d0a1a0a0000000d49484452")

# This 8-byte value with half of the maximum byte sum is used
# to calculate the ROM's byte sum before forging its CRC32.
initial_forge = bytes.fromhex("ff00ff00ff00ff00")

def parse_argv(argv):
    p = argparse.ArgumentParser(description=helpText, epilog=helpEnd)
    p.add_argument("--version", action='version', version=versionText)
    p.add_argument("gbfile", help="Game Boy ROM")
    p.add_argument("pngfile", help="PNG image")
    p.add_argument("outfile", help="polyglot file output")
    p.add_argument("-v", "--verbose", action="store_true")
    return p.parse_args(argv[1:])

def forge(value, desired_sum=255*4):
    """Find 4 bytes to extend a data block where new bytes and new CRC bytes add up to 255*4.
    
value -- previous value as calculated with zlib.crc32(data)

Return a 2-tuple (bytes to append, CRC value after appending, number of trials)
"""
    for trial in range(0, 0xFFFFFFFF):
        value_to_pack = ((trial & 0xFFFF) << 16) ^ 0xFFFF ^ trial
        new_bytes = struct.pack("<I", value_to_pack)
        new_crc_value = crc32(new_bytes, value)
        sum_crc_bytes = sum(struct.pack("<I", new_crc_value))
        if sum(new_bytes) + sum_crc_bytes == desired_sum:
            return new_bytes, new_crc_value, trial
    raise ValueError("no balanced extension for CRC %08x")

def test_forge(s=b'hello world'):
    value = crc32(s)
    new_bytes, new_value, trial = forge(value)
    print("%s: crc %08x; new bytes %s; new crc %08x; forged in %d tries"
          % (s, value, new_bytes.hex(), new_value, trial))
    print("new crc is %08x; sum is %d"
          % (crc32(s + new_bytes),
             sum(new_bytes + struct.pack("<I", new_value))))

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
    # Each PNG chunk's CRC covers the chunk type and body, not the
    # length.  A chunk's length is presumed correct if the following
    # chunk's CRC is correct.
    # Perform a coherence check on the input image's IHDR chunk.
    ihcalccrc = crc32(ihdrdata) & 0xffffffff
    ihstoredcrc = struct.unpack_from(">I", pngdata, 16 + 13)[0]
    if args.verbose:
        print("pngify.py: note: %s IHDR chunk CRC is %08x; calculated CRC is %08x"
              % (args.pngfile, ihstoredcrc, ihcalccrc), file=sys.stderr)
    if ihcalccrc != ihstoredcrc:
        print("pngify.py: warning: %s PNG header CRC is wrong"
              % args.pngfile, file=sys.stderr)

    # The 33-byte PNG header consists of a signature (8), IHDR length
    # and type (8), IHDR body (13), and IHDR CRC (4).  Place these at
    # the start of the output ROM.
    png_header_size = 33
    gbdata[:png_header_size] = pngdata[:png_header_size]

    # We'll be putting the Game Boy program in a prGm chunk.
    # It is ancillary, private, and copy-safe.  The last "m" is
    # important because it must be lowercase and a no-op so that
    # rst $28 can still be used (though $00 through $20 cannot).
    prgm_chunk_type = b'prGm'

    # This chunk cover the rest of the ROM prior to the start of the
    # PNG file.  Three things follow the prGm body:  a 4-byte value
    # that forges the prGm's CRC, the prGm's CRC, and the rest of the
    # PNG chunks.  These total the PNG file's size minus 25 bytes.
    space_needed = len(pngdata) - png_header_size + 8
    forge_start = len(gbdata) - space_needed

    # Estimate how much data can safely be trimmed from the ROM's end
    # by counting its last run of constant bytes.
    trimlen = len(gbdata.rstrip(gbdata[-1:]))
    trimmsg = (
        "%s needs %d blank bytes at the end; "
        "%s is %d bytes followed by %d 0x%02x bytes"
        % (args.pngfile, space_needed,
           args.gbfile, trimlen, len(gbdata) - trimlen, gbdata[-1])
    )
    if forge_start < trimlen: raise ValueError(trimmsg)
    if args.verbose:
        print("pngify.py: note: " + trimmsg, file=sys.stderr)
        print("pngify.py: note: forge value and non-IHDR chunks start at offset 0x%x"
              % forge_start, file=sys.stderr)

    # Create the prGm chunk with a temporary forge value and CRC
    # value that have the same byte sum as the actual forge value
    # and CRC value, and add the remaining PNG chunks.

    prgm_body_start, prgm_body_end = png_header_size + 8, forge_start + 4
    struct.pack_into(">I", gbdata, 33, prgm_body_end - prgm_body_start)
    gbdata[prgm_body_start - 4:prgm_body_start] = prgm_chunk_type
    gbdata[forge_start:] = initial_forge + pngdata[png_header_size:]

    # Update the GB ROM header's byte sum.
    gbdata[0x14E:0x150] = bytes(2)
    byte_sum = sum(gbdata) & 0xFFFF
    struct.pack_into(">H", gbdata, 0x14E, byte_sum)
    if args.verbose:
        print("pngify.py: note: new byte sum is 0x%04x"
              % byte_sum, file=sys.stderr)

    # Forge a CRC32 for the prGm chunk.
    # Tested using Project Nayuki's PNG file chunk inspector
    # <https://www.nayuki.io/page/png-file-chunk-inspector>
    prgm_crc = crc32(gbdata[37:forge_start]) & 0xffffffff
    prgm_forge, prgm_new_crc, trial = forge(prgm_crc, sum(initial_forge))
    if args.verbose:
        print("pngify.py: note: prGm CRC32 %08x + forge %s = CRC32 %08x"
              % (prgm_crc, prgm_forge.hex(), prgm_new_crc), file=sys.stderr)
    gbdata[forge_start:forge_start + 4] = prgm_forge
    struct.pack_into(">I", gbdata, forge_start + 4, prgm_new_crc)

    with open(args.outfile, "wb") as outfp:
        outfp.write(gbdata)

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        main("""./pngify.png --version
""".split())
        main("""./pngify.png -v
../gbpng.gb ../tilesets/Sukey.png ../gbpng-test.gb.png
""".split())
    else:
        main()
