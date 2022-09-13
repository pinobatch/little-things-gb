#!/usr/bin/env python3
import os, sys, argparse
from PIL import Image

descriptionStart = """
Converts a 2bpp proportional font to a format using 4x1-pixel slivers.
"""
descriptionEnd = """
All glyphs' advance width must be a multiple of 4.
"""

def parse_argv(argv):
    p = argparse.ArgumentParser()
    p.add_argument("imagename", help="name of PNG image")
    p.add_argument("-W", "--width", type=int, default=None,
                   help="maximum width of each glyph")
    p.add_argument("-H", "--height", type=int, default=16,
                   help="height of each row of glyphs")
    p.add_argument("-o", "--output", default='-',
                   help="name of output asm file for RGBASM")
    args = p.parse_args(argv[1:])
    if args.width is None: args.width = args.height
    if args.width < 4:
        p.error("width %d not positive" % args.width)
    if args.height < 1:
        p.error("height %d not positive" % args.height)
    if args.width % 4 != 0:
        p.error("width %d not multiple of 4" % args.width)
    return args

def rgbasm_bytearray(s):
    s = ['  db ' + ','.join("$%02x" % ch for ch in s[i:i + 16])
         for i in range(0, len(s), 16)]
    return '\n'.join(s)

def vwf4read(im, tilewidth, tileheight):
    pixels = im.load()
    (w, h) = im.size
    (xparentColor, sepColor) = im.getextrema()
    glyphs = []
    for yt in range(0, h, tileheight):
        for xt in range(0, w, tilewidth):
            # step 1: find the glyph width
            glyph_width = tilewidth
            for x in range(tilewidth):
                if pixels[x + xt, yt] == sepColor:
                    glyph_width = x
                    break
            # step 2: pull out pixels
            cols = []
            for col in range(xt, xt + glyph_width, 4):
                thiscol = bytearray()
                cols.append(thiscol)
                for y in range(yt, yt + tileheight):
                    thisbyte = 0
                    for x in range(col, col + 4):
                        thisbyte <<= 1
                        p = pixels[x, y]
                        thisbyte |= ((2 & p) >> 1) | ((1 & p) << 4)
                    thiscol.append(thisbyte)
            glyphs.append(cols)
    return glyphs

def pack_glyph(cols):
    out = bytearray()
    ZEROBYTE= b"\x00"
    for col in cols:
        col = col.rstrip(ZEROBYTE)  # trim trailing zeroes
        if len(col) == 0:  # each column has to have something in it
            out.append(0)
            out.append(0)
            continue
        leading0 = len(col) - len(col.lstrip(ZEROBYTE))
        del col[:leading0]  # trim leading zeroes
        out.append((leading0 << 4) | ((len(col) - 1) << 0))
        out.extend(col)
    out.append(0xFF)  # FF terminator
    return out

def main(argv=None):
    args = parse_argv(argv or sys.argv)
    with Image.open(args.imagename) as im:
        glyphs = vwf4read(im, args.width, args.height)
    glyphdata = [pack_glyph(cols) for cols in glyphs]
    total_glyphdata = sum(len(x) for x in glyphdata)

    lines = ["; generated using vwf4cv.py %s" % args.imagename,
             "; starts: %d (%d bytes); glyphs: %d bytes; total %d bytes"
             % (len(glyphdata), len(glyphdata) * 2, total_glyphdata,
                len(glyphdata) * 2 + total_glyphdata),
             'section "vwf4_glyphdata", ROM0, ALIGN[1]',
             "vwf4_glyphstarts::"]
    lines.extend("  dw vwf4_glyph%2x" % (c + 0x20,)
                 for c in range(len(glyphdata)))
    for c, glyph in enumerate(glyphdata):
        lines.append("vwf4_glyph%2x:  ; %s" % (c + 0x20, chr(c + 0x20)))
        lines.append(rgbasm_bytearray(glyph))

    lines.append("")
    lines = '\n'.join(lines)
    if args.output == '-':
        sys.stdout.write(lines)
    else:
        with open(args.output, "w", encoding="utf-8") as outfp:
            outfp.write(lines)

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        main("""
./vwf4cv.py -W12 -H16 ../tilesets/fink.png
""".split())
    else:
        main()
