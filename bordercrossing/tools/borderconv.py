#!/usr/bin/env python3
"""
Indexed PNG to Super NES converter

Copyright 2022 Damian Yerrick

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"""
import os, sys, argparse, array
from operator import or_
from collections import Counter
from PIL import Image
import solve_overload, pb16

PLAY_AREA_LEFT_COL = 6
PLAY_AREA_TOP_ROW = 5
PLAY_AREA_COLS = 20
PLAY_AREA_ROWS = 18

def im_to_m7_tiles(im):
    pixels = im.tobytes()
    w = im.size[0]
    rowsz = w * 8
    tilerows = [pixels[i:i + rowsz]
                for i in range(0, len(pixels), rowsz)]
    tiles = [
        b''.join(row[tl:tl + 8] for tl in range(l, rowsz, w))
        for row in tilerows
        for l in range(0, w, 8)
    ]
    return tiles

def m7_to_m1_tile(tile):
    out = bytearray()
    for planepair in (0, 2):
        for y in range(0, 64, 8):
            sliver = tile[y:y + 8]
            for bittest in (1 << planepair, 2 << planepair):
                value = 0
                for x, px in enumerate(sliver):
                    if px & bittest: value |= 0x80 >> x
                out.append(value)
    return out

def m7_tile_hflip(tile):
    """Flips a stack of one or more rows of packed 8-bit tiles"""
    return b''.join(tile[i:i + 8][::-1] for i in range(0, len(tile), 8))

def parse_argv(argv):
    p = argparse.ArgumentParser()
    p.add_argument("pngname",
                   help="border image file (must be 256x224 indexed color)")
    p.add_argument("outname",
                   help="converted border file")
    p.add_argument("-v", "--verbose", action="store_true",
                   help="show statistics about conversion")
    return p.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)
    subpalsize = 15
    max_subpals = 3
    first_subpal = 4
    max_tiles = 256

    # Load the image
    with Image.open(args.pngname) as im:
        if im.mode != 'P':
            raise ValueError("expected palette (P) image; got %s" % (im.mode,))
        if im.size != (256, 224):
            raise ValueError("expected 256 by 224 pixels; got %d by %d"
                             % im.size)
        try:
            bgcolor = im.transparency
        except AttributeError:
            bgcolor = None
        tiles = im_to_m7_tiles(im)
        impal = im.getpalette()
        twidth = im.size[0] // 8

    # Use the PNG transparent color, or the most common color in
    # the play area if there isn't one
    if args.verbose:
        print("PNG transparent color is %s"
              % repr(bgcolor), file=sys.stderr)
    if bgcolor is None:
        play_area_colors = Counter(b''.join(
            tile
            for rowleft in range(twidth * PLAY_AREA_TOP_ROW + PLAY_AREA_LEFT_COL,
                                 twidth * (PLAY_AREA_TOP_ROW + PLAY_AREA_ROWS),
                                 twidth)
            for tile in tiles[rowleft:rowleft + PLAY_AREA_COLS]
        ))
        bgcolor = play_area_colors.most_common(1)[0][0]
        if args.verbose:
            print("detected play area color is %s"
                  % repr(bgcolor), file=sys.stderr)

    # Find the set of colors in each tile, then remove color sets
    # that are subsets of a larger color set.  Complexity is O(n^2)
    colorsets = {frozenset(c for c in x if c != bgcolor) for x in tiles}
    colorsets = sorted(colorsets, key=len)
    if args.verbose:
        print("most opaque colors in one tile: %d"
              % len(colorsets[-1]), file=sys.stderr)
    if len(colorsets[-1]) > subpalsize:
        raise ValueError("too many colors in an 8x8-pixel tile: %d (expected %d)"
                         % (len(colorsets[-1]), subpalsize))
    for i, cs in enumerate(colorsets):
        for cs2 in colorsets[i + 1:]:
            if cs.issubset(cs2):
                colorsets[i] = None
                break

    # Pack the remaining color sets into palettes
    job = {"capacity": subpalsize, "tiles": [x for x in colorsets if x]}
    pages = solve_overload.run(job)
    pages.decant()
    subpals = [[bgcolor] + sorted(set().union(*(subpal))) for subpal in pages]
    if len(subpals) > max_subpals:
        raise ValueError("too many subpalettes (%d; expected %d)"
                         % (len(tiles4b), max_subpals))
    if args.verbose:
        print("image contains %d subpalettes"
              % len(subpals), file=sys.stderr)
    isubpals = [{v: k for k, v in enumerate(subpal)} for subpal in subpals]

    # Initialize tileset with only the transparent tile
    tilemap = []
    tiles4b = [bytes(32)]
    seentiles = {bytes(64): 0}
    # Then try to match each tile in the image to an existing tile
    # or one of its vertically or horizontally flipped variants
    for tile in tiles:
        tile_colorset = frozenset(tile)
        palid = None
        for i, sp in enumerate(subpals):
            if tile_colorset.issubset(sp):
                palid = i
                break
        isp = isubpals[palid]
        remaptile = bytes(isp[i] for i in tile)
        try:
            tileid = seentiles[remaptile]
        except KeyError:
            tileid = len(tiles4b)
            tiles4b.append(m7_to_m1_tile(remaptile))
            remaptile_hflip = m7_tile_hflip(remaptile)
            seentiles[remaptile[::-1]] = 0xC000 | tileid
            seentiles[remaptile_hflip[::-1]] = 0x8000 | tileid
            seentiles[remaptile_hflip] = 0x4000 | tileid
            seentiles[remaptile] = tileid
        tilemap.append(((palid + first_subpal) << 10) | tileid)

    if len(tiles4b) > max_tiles:
        raise ValueError("too many distinct tiles (%d; expected %d)"
                         % (len(tiles4b), max_tiles))
    ctiles = b''.join(pb16.pb16(b"".join(tiles4b)))

    btilemap = array.array("H", tilemap)
    if sys.byteorder == 'big': btilemap.byteswap()
    ctilemap = b''.join(pb16.pb16(btilemap.tobytes()))

    if args.verbose:
        print("%d tiles compress to %d bytes; tilemap compresses to %d bytes"
              % (len(tiles4b), len(ctiles), len(ctilemap)),
              file=sys.stderr)

    cramdata = bytearray(32 * len(subpals))
    for y, subpal in enumerate(subpals):
        for x, c in enumerate(subpal):
            r, g, b = impal[c*3:c*3 + 3]
            value = ((r & 0xF8) >> 3) | ((g & 0xF8) << 2) | ((b & 0xF8) << 7)
            addr = x * 2 + y * 32
            cramdata[addr] = value & 0xFF
            cramdata[addr + 1] = value >> 8

    out_parts = [
        bytes([len(tiles4b) - 1]), ctiles,
        ctilemap,
        cramdata
    ]
    with open(args.outname, "wb") as outfp:
        outfp.writelines(out_parts)

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        main("""
./borderconv.py -v ../tilesets/sameboy.png ../obj/gb/sameboy.border
""".split())
    else:
        main()
