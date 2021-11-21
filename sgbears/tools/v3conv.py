#!/usr/bin/env python3
import os, sys, argparse
from PIL import Image, ImageDraw, ImageChops
import pilbmp2nes, uniq

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
    im = silf.im.convert("P", 1 if dither else 0, palette.im)
    # the 0 above means turn OFF dithering

    try:
        return silf._new(im)  # Name in Pillow 4+
    except AttributeError:
        return silf._makeself(im)  # Name in Pillow 3-

# This is generalized from savtool.py
def colorround(im, palettes, tilesize, subpalsize):
    """Find the best palette

im -- a Pillow image (will be converted to RGB)
palettes -- list of subpalettes [[(r, g, b), ...], ...]
tilesize -- size in pixels of each tile as (x, y) tuple
subpalsize -- the maximum number of colors in each subpalette to use

Return ?
"""
    # Generalized from a function in savtool.py
    # Once documented, update 240p-test-mini/gameboy/tools/gbcnamtool.py

    blockw, blockh = tilesize
    if im.mode != 'RGB':
        im = im.convert('RGB')

    trials = []
    all_colors = []
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

# Main ##############################################################

def Image_open_load(fp, *a):
    """Open and eagerly load an image file.

Call load() on each image to free system resources associated
with an opened and not loaded image.

Return a Pillow image."""
    im = Image.open(fp)
    im.load()
    return im

def main(argv=None):
    args = parse_argv(argv or sys.argv)
    with open(args.palettes) as infp:
        palettes = load_palette_file(infp)
    print("Loaded palettes")
    print(palettes)
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
    print("inner: %d tiles, %d distinct" % (len(innermap), len(innerchr)))

    outerchr = list(zip(*(
        pilbmp2nes.pilbmp2chr(im, formatTile=snesformat) for im in ims
    )))
    outeruniq = set(outerchr)
    outerequal = [ts[0] for ts in outeruniq if all(t == ts[0] for t in ts)]
    outervary = [ts for ts in outeruniq if not all(t == ts[0] for t in ts)]
    print("outer: %d tiles, %d distinct, %d constant and %d varying"
          % (len(outerchr), len(outeruniq), len(outerequal), len(outervary)))
    

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
