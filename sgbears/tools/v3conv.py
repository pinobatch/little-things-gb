#!/usr/bin/env python3
"""
SGB inner+outer image converter

Copyright 2012, 2018, 2019, 2021 Damian Yerrick
License: zlib

"""
import os, sys, argparse
from PIL import Image, ImageDraw, ImageChops
import pilbmp2nes, uniq, pb16

# Argument and palette parsing ######################################

def parse_argv(argv):
    p = argparse.ArgumentParser()
    p.add_argument("--palettes",
                   help="name of palette file")
    p.add_argument("image", nargs="+",
                   help="PNG image files for each border state")
    return p.parse_args(argv[1:])

def hextotuple(color):
    """Translate a hex color (abc, #abc, aabbcc, #aabbcc) to a 3-tuple (r, g, b)"""
    if color.startswith('#'):
        color = color[1:]
    color = color.lower()
    if not all(c in "0123456789abcdef" for c in color):
        raise ValueError("%s is not hexadecimal" % repr(color))
    if len(color) == 3:
        return tuple(17 * int(component, 16) for component in color)
    if len(color) == 6:
        return tuple(int(color[i:i + 2], 16) for i in (0, 2, 4))
    raise ValueError("%s is not a 3- or 6-digit hex value" % color)

def load_palette_file(infp):
    """Load a palette file.

infp is an iterable yielding lines of text, such as an open text file

palette <name>  start a new palette
|               start a new subpalette
#xxx, #xxxxxx   add a color to the palette's last subpalette
//              ignore everything else on the line

Return [(name, subpalettes), ...]
where subpalettes is [[(r, g, b), ...], ...]
"""
    palettes = []
    for linenum, line in enumerate(infp):
        line = line.split("//", 1)[0].strip()  # discard comment
        want = None
        for word in line.split():
            if want == 'palette':
                palettes.append((word, [[]]))
                want = None
            elif word == 'palette':
                want = 'palette'
            elif word == '|':
                palettes[-1][1].append([])
            else:
                palettes[-1][1][-1].append(hextotuple(word))
        if want is not None:
            raise ValueError("unterminated %s" % want)
    return palettes

# Image processing ##################################################

def quantizetopalette(silf, palette, dither=False):
    """Convert an RGB or L mode image to use a given P image's palette.

This is a fork of PIL.Image.Image.quantize() with more
control over whether Floyd-Steinberg dithering is used.
"""

    silf.load()

    # use palette from reference image
    palette.load()
    if palette.mode != "P":
        raise ValueError("bad mode for palette image")
    if silf.mode != "RGB" and silf.mode != "L":
        raise ValueError(
            "only RGB or L mode images can be quantized to a palette"
            )

    # 0 means turn off dithering
    im = silf.im.convert("P", 1 if dither else 0, palette.im)
    return silf._new(im)

def colorround(im, palettes, tilesize, subpalsize):
    """Find the best palette

im -- a Pillow image (will be converted to RGB)
palettes -- list of subpalettes [[(r, g, b), ...], ...]
tilesize -- size in pixels of each tile as (x, y) tuple
subpalsize -- the maximum number of colors in each subpalette to use

Return a 2-tuple (final image, attribute map)
"""
    # Generalized from a function in savtool.py in nesbgeditor

    blockw, blockh = tilesize
    if im.mode != 'RGB':
        im = im.convert('RGB')

    trials, all_colors = [], []
    onetile = Image.new('P', tilesize)
    for p in palettes:
        p = list(p[:subpalsize])
        p.extend([p[0]] * (subpalsize - len(p)))
        all_colors.extend(p)

        # New images default to the full grayscale palette. Unless
        # all 256 colors are overwritten, quantizetopalette() will
        # use the grays.
        p.extend([p[0]] * (256 - len(p)))

        # putpalette() requires the palette to be flattened:
        # [r,g,b,r,g,b,...] not [(r,g,b),(r,g,b),...]
        # otherwise putpalette() raises TypeError:
        # 'tuple' object cannot be interpreted as an integer
        seq = [component for color in p for component in color]
        onetile.putpalette(seq)
        imp = quantizetopalette(im, onetile)

        # For each color area, calculate the difference
        # between it and the original
        impr = imp.convert('RGB')
        diff = ImageChops.difference(im, impr)
        diff = [
            diff.crop((l, t, l + blockw, t + blockh))
            for t in range(0, im.size[1], blockh)
            for l in range(0, im.size[0], blockw)
        ]
        # diff is the overall color difference for each color area
        # of this image, using weights 2, 4, 3 per
        # https://en.wikipedia.org/w/index.php?title=Color_difference&oldid=840435351
        diff = [
            sum(2*r*r+4*g*g+3*b*b for (r, g, b) in tile.getdata())
            for tile in diff
        ]
        trials.append((imp, diff))

    # trials is a list [(imp, [diff, ...]), ...]
    # where imp is a Pillow image converted using each subpalette,
    # and diff is total squared error from quantization of each tile,
    # arranged row-major.  Find the subpalette with the smallest
    # difference for each color area.
    attrs = [
        min(enumerate(i), key=lambda i: i[1])[0]
        for i in zip(*(diff for (imp, diff) in trials))
    ]

    # Calculate the resulting image
    imfinal = Image.new('P', im.size)
    seq = [component for color in all_colors for component in color]
    imfinal.putpalette(seq)
    tilerects = zip(
        ((l, t, l + blockw, t + blockh)
         for t in range(0, im.size[1], blockh)
         for l in range(0, im.size[0], blockw)),
        attrs
    )
    for tilerect, attr in tilerects:
        pbase = attr * subpalsize
        pixeldata = trials[attr][0].crop(tilerect).getdata()
        onetile.putdata(bytes(pbase + b for b in pixeldata))
        imfinal.paste(onetile, tilerect)
    return imfinal, attrs

def get_bitreverse():
    """Get a lookup table for horizontal flipping."""
    br = bytearray([0x00, 0x80, 0x40, 0xC0])
    for v in range(6):
        bit = 0x20 >> v
        br.extend(x | bit for x in br)
    return br

# Export formatting #################################################

def color_tuple_to_bgr5(rgb):
    r, g, b = rgb
    return (
        (b & 0xF8) << (10 - 3) | (g & 0xF8) << (5 - 3) | (r & 0xF8) >> 3
    )

def subpalette_to_bgr5(row, subpalsize=4):
    """Convert the first 4 color tuples in a list to 5 bits per channel"""
    row = [color_tuple_to_bgr5(x) for x in list(row)[:subpalsize]]
    if len(row) < subpalsize:
        row.extend([row[0]] * (subpalsize - len(row)))
    return row

def subpalette_to_asm(row, subpalsize=4):
    """Convert the first 4 color tuples in a list to a DW statement"""
    return "  dw " + ",".join("$%04x" % x
                              for x in subpalette_to_bgr5(row, subpalsize))

def subpalette_to_bin(row, subpalsize=4):
    out = bytearray()
    for i in subpalette_to_bgr5(row, subpalsize):
        out.append(i & 0xFF)
        out.append(i >> 8)
    return out

def pb16lines(data):
    """Compress data with PB16 and print it in assembly language.

data -- a byteslike or other iterable over ints 0-255

return ([db_statement, ...], bytecount)
each db_statement contains one PB16 packet, representing 8
decompressed bytes, and lacks following \n
"""
    lines, bytecount = [], 0
    for packet in pb16.pb16(data):
        lines.append("  db " + ",".join("$%02x" % (b,) for b in packet))
        bytecount += len(packet)
    return lines, bytecount

# Main ##############################################################

def main(argv=None):
    args = parse_argv(argv or sys.argv)
    with open(args.palettes) as infp:
        palettes = load_palette_file(infp)
    dpalettes = dict(palettes)

    # Making a Pillow palette image requires a single RGB sequence
    # that is flattened and extended to 256*3 ints
    seq = [component for color in dpalettes["outer"][0] for component in color]
    seq.extend(seq[:3] * (256 - len(seq) // 3))
    outerpalim = Image.new("P", (160, 144), 0)
    outerpalim.putpalette(seq)

    # To simplify conversion, use only one 15-color palette for the
    # whole border.  Otherwise, this step would have to interleave
    # 256x8-pixel rows for colorround() to find the best palette for
    # all four images.
    ims, innerim, has_err = [], None, False
    for filename in args.image:
        with Image.open(filename) as inim:
            if inim.size != (256, 224):
                print("%s: unexpected image size %d by %d"
                      % (filename, inim.size[0], inim.size[1]),
                      file=sys.stderr)
                has_err = True
                continue
            im = inim.convert("RGB")
            innerim = innerim or im.crop((48, 40, 48+160, 40+144))
            im = quantizetopalette(im, outerpalim)
        im.paste(outerpalim, (48, 40))
        ims.append(im)
    if has_err:
        exit(1)

    # To simplify SGB packet loading, the Game Boy program doesn't
    # actually use the attrs output.  Instead, it hardcodes a
    # 24x32-pixel area in the clothes palette whose top left is at
    # (40, 104) in GB space (or (96, 144) in Super NES space).
    # Instead, we store two bare tilemaps.
    innerim, attrs = colorround(innerim, dpalettes["inner"], (8, 8), 4)

    gbformat = lambda x: pilbmp2nes.formatTilePlanar(x, "0,1")
    snesformat = lambda x: pilbmp2nes.formatTilePlanar(x, "0,1;2,3")
    innerchr = pilbmp2nes.pilbmp2chr(innerim, formatTile=gbformat)
    innerchr, innermap = uniq.uniq(innerchr)

    # A Super Game Boy border can contain up to 256 unique tiles,
    # one of which must be transparent so that the 160x144-pixel
    # playfield can show through.  A program sends the border
    # in three transfers: CHR_TRN 0 for tiles 0-127, CHR_TRN 1
    # for tiles 128-255, and PCT_TRN for the tilemap and palette.
    # SGBears sends the tiles specific to each partner in CHR 0
    # and the common tiles in CHR 1.
    outerchr = list(zip(*(
        pilbmp2nes.pilbmp2chr(im, formatTile=snesformat) for im in ims
    )))

    # Blank tile followed by other tiles in order of appearance
    outerequal = [(bytes(32),)*4]
    outerequal.extend(ts for ts in outerchr if all(t == ts[0] for t in ts))
    outervary = [ts for ts in outerchr if not all(t == ts[0] for t in ts)]
    outerequal, _ = uniq.uniq(outerequal)
    outervary, _ = uniq.uniq(outervary)
    outer_tstoid = {ts: 128 + i for i, ts in enumerate(outerequal)}
    outer_tstoid.update((ts, i) for i, ts in enumerate(outervary))
    outermap = [outer_tstoid[ts] for ts in outerchr]
    outerequal = [ts[0] for ts in outerequal]

    # Each tile can be flipped horizontally or vertically by setting
    # bits in odd bytes of PCT_TRN.  If so, the tilemap data in the
    # ROM needs to store which tiles are flipped.
    # Pino tried horizontal flipping to save tiles in CHR 1.
    # It cut 100 tiles to 84, which he deemed not enough to justify
    # the decoding complexity.  Had flipping cut tiles from over
    # 128 to under 128, it would have been worth it to keep common
    # tiles from spilling into CHR 0.
    if False:
        bitrevlut = get_bitreverse()
        outerflip = {bytes(bitrevlut[b] for b in t): t for t in outerequal}
        outerequal_modflip = [
            t for t in outerequal if outerflip.get(t, t) <= t
        ]
        print(";outer: %d constant remain distinct modulo flip"
              % (len(outerequal_modflip)))

    # Write SGB palette and attribute
    out = []
    out.append("Bears_pf_sgb_packets::  ; 32 bytes")
    out.append("  db $01  ; PAL01: set playfield colors 0, 1, 2, 3, 5, 6, 7")
    out.append(subpalette_to_asm(dpalettes["inner"][0], 4))
    out.append(subpalette_to_asm(dpalettes["inner"][1][1:], 3))
    out.append("  db $00  ; end PAL01")
    # as mentioned earlier, this is hardcoded
    out.append("  db $21, 2  ; ATTR_BLK: draw rectangles")
    out.append("  db %101, %00000011  ; change outside to 0 and inside to 1")
    out.append("  db 40/8, 104/8, 55/8, 127/8  ; left, top, right, bottom")
    out.append("  ds 8, $00  ; pad to 16 bytes")
    out.append("  db $00  ; end of sgb palettes")

    # Write playfield tiles and tilemap
    lines, pf_chr_bytes = pb16lines(b"".join(innerchr))
    out.append("Bears_pf_pb16::  ; %d bytes" % (1 + pf_chr_bytes,))
    out.append("  db %d  ; Playfield tile count" % (len(innerchr) % 256,))
    out.extend(lines)
    out.append("Bears_pf_tilemap::  ; 360 bytes")
    out.append("  ; starts at 128 because BG CHR is at 9000/8800")
    out.extend("  db " + ",".join("%3d" % ((t + 128) % 256,)
                                  for t in innermap[i:i + 20])
               for i in range(0, len(innermap), 20))

    # Export common border tiles
    lines, border_chr1_bytes = pb16lines(b"".join(outerequal))
    out.append("Bears_border_chr1_pb16::  ; %d bytes" % (1 + border_chr1_bytes,))
    out.append("  db %d  ; Border common tile count" % (len(outerequal),))
    out.extend(lines)

    for i, (filename, tiles) in enumerate(zip(args.image, zip(*outervary))):
        lines, bear_bytes = pb16lines(b"".join(tiles))
        out.append("Bears_border_chr0_%d_pb16::  ; %s, %d bytes"
                   % (i, os.path.basename(filename), 1 + bear_bytes,))
        out.append("  db %d  ; Tile count for this state" % (len(tiles),))
        out.extend(lines)

    # Export border tilemap and palette (for PCT_TRN)
    lines, border_map_bytes = pb16lines(outermap)
    out.append("Bears_border_tilemap_pb16::  ; %d bytes" % border_map_bytes)
    out.extend(lines)    
    out.append("Bears_border_palette::  ; 32 bytes")
    out.append(subpalette_to_asm(dpalettes["outer"][0], 16))
    out.append("Bears_border_palette_end::")

    print("\n".join(out))

    print(";inner: %d tiles, %d distinct" % (len(innermap), len(innerchr)))
    print(";outer: %d tiles, %d distinct, %d constant and %d varying"
          % (len(outerchr), len(outerequal) + len(outervary),
             len(outerequal), len(outervary)))

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        main(r"""
./v3conv.py
--palettes ../tilesets/v3/palette.txt
../tilesets/v3/nobears.png
../tilesets/v3/papa_bear.png
../tilesets/v3/baby_bear.png
../tilesets/v3/mama_bear.png
""".split())
    else:
        main()
