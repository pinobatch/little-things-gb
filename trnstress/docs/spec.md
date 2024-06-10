TRN Stress
==========

Scramble methods
----------------

The automatic test steps through each of these.  The manual test
lets the user choose from a menu.

1. Normal border data
2. Inverted BGP
3. 2bpp via tilemap
4. 2bpp via BGP
5. Tiles in reverse order
6. Tiles at 8800-97FF
7. Tilemap at 9C00
8. Window tilemap
9. 8-line objects
10. 16-line objects
11. Coarse X scroll
12. Coarse Y scroll
13. Alternating coarse X
14. Rows in reverse order
15. Fine X scroll
16. Fine Y scroll

Each scramble has four parts:

1. a label
2. a routine to modify VRAM for CHR_TRN
3. a routine to modify VRAM for PCT_TRN
4. a destination register address and sequence of 13 values to write
   every 8 lines, or NULL to disable

For most, the CHR_TRN and PCT_TRN routines are the same.  For a few,
they are a matched pair.  If the pointer to the value sequence is not
null, enable STAT IRQ and poke into self-modifying code in HRAM.

Some scrambles fill unused video memory with pseudorandom garbage to
make misbehavior more visible.  This is generated using an efficient
[8-bit PRNG] algorithm by foobles that combines attributes of a
linear feedback shift register (LFSR) and a linear congruential
generator (LCG).  It has two rules:

* If seed < $80: Multiply by 2, XOR with $46, and add $EB
* If seed >= $80: Multiply by 2 and add $EC

[8-bit PRNG]: https://foobles.neocities.org/blog/2023-06-06/prng

### Normal border data

The border decoder normally puts tile data in $8000-$8FFF and
tilemap data in $9800-$998F, puts all objects offscreen (OAM filled
with $00), sets palette to identity (BGP=OBP0=$E4), and puts the
window offscreen (WX=WY=$FF).

### Inverted BGP

XOR tile data in VRAM with $FF and reconstitute it by setting BGP to
%00011011.

### 2bpp via tilemap

**PCT_TRN differs.**

Load a 4-color image.  Compact CHR_TRN to make 2bpp tiles consecutive
in VRAM, and arrange the tilemap to expand them to 4bpp for the SGB:
00, FF, 01, FF, 02, FF, 03, FF, ..., 7E, FF, 7F, FF.  Blank tile $FF
and fill tiles $80 through $FE with pseudorandom garbage.
Leave PCT_TRN unchanged.

### 2bpp via BGP

**PCT_TRN differs.**

Load a 4-color image.  Copy tile plane 1 (bytes 32t+2y+1) to plane
2 (bytes 32t+2y+16).  Overwrite planes 1 and 3 (odd bytes in tiles)
with pseudorandom garbage.  Modify PCT_TRN to reorder the palette
to use only colors 0, 1, 4, and 5, and fill other colors with red
to highlight pixels in planes 1 and 3 that slipped through.
Set BGP to %01000100.

### Tiles in reverse order

XOR the tilemap with $FF.  Swap 16-bit units in tile memory front to
back: $8000-$800F with $8FF0-$8FFF, $8010 with $8FE0-$8FEF, etc.

### Tiles at 9000/8800

Set LCDC to use background blocks 2 and 1.  Copy $8000-$87FF to
$9000-$97FF and then overwrite $8000-$87FF with garbage.

### Tilemap at 9C00

Set LCDC to use background tilemap $9C00.  Copy $9800-$9BFF to
$9C00-$9FFF and then overwrite $9800-$9BFF with garbage.

### Window tilemap

In the tilemap, copy the right 4 tiles of rows 2-11 of tilemap $9800
($9850-$9853, $9870-$9873, ..., $9970-$9973) to the top left of rows
0-9 of tilemap $9C00 ($9C00-$9C03, $9C20-$9C23, ..., $9C20-$9C23).
Change each tile in the original tilemap after copying it.
Set WX=128+7 and WY=16.

### 8-line objects

One tile in each of the two CHR_TRN packets must be blank.

Erase columns 16-19 of rows 0-9 of the tilemap to the blank tile.
Write ten rows of objects to OAM: tiles 16-19 at (136, 16),
tiles 36-39 at (136, 24), ..., 196-199 at (136, 88).

### 16-line objects

One tile in each of the two CHR_TRN packets must be blank.

Erase columns 12-19 of rows 0-9 of the tilemap to the blank tile.
Swap tiles 13 and 32, 15 and 34, 17 and 36, 19 and 38, 53 and 72,
55 and 74, ..., and 179 and 198.  Write five rows of objects to OAM:
tiles 12, 32, 14, 34, 16, 36, 18, and 38 at (104, 16), tiles 52, 72,
54, 74, 56, 76, 58, and 78 at (104, 32), ..., 198 at (160, 80).

### Coarse X scroll

Set SCX to 8.  Move the entire tilemap 1 byte later.

### Coarse Y scroll

Set SCY to 8.  Move the entire tilemap 32 bytes later.

### Alternating coarse X

Move the tilemap in rows 1, 3, 5, 7, 9, and 11 one byte later.
Set up STAT write to SCX ($FF43) with values:

    0, 8, 0, 8, 0, 8, 0, 8, 0, 8, 0, 8, 0

### Rows in reverse order

Swap tilemap rows 0 and 12, 1 and 11, 2 and 10, 3 and 9, 4 and 8, and
5 and 7.  Set up STAT write to SCX ($FF43) with values:

    96, 80, 64, 48, 32, 16, 0, 240, 224, 208, 192, 184, 160

### Fine X scroll

Set SCX to 1.  Shift all tile bytes to the right by 1 at 16-byte
stride.  In the tilemap, write the tile number 1 tile more than the
tile number at the right side 1 tile to the right of each row.

### Fine Y scroll

Set SCY to 1.  Shift all tile bytes forward by 2, except shift those
on $8xxE and $8xxF forward by 306.  If the address surpasses $9000,
copy it to the start of the column ($8000-$8131) and continue to the
next column.  In the tilemap, copy the tile number greater than 235
down one.

Additional tests
----------------

beware has requested one additional test: figuring out which rows of
the SGB video output get copied to the work RAM buffer during each of
the four frames after a CHR_TRN or PCT_TRN.

CHR_TRN layout: transparent, black, unused, variable, and digits
0, 1, 2, and 3.  During each frame, replace the variable tile
(tile $03) with a copy of tiles $04, $05, $06, or $07.

PCT_TRN layout: During each frame, fill columns 5 and 26 with tile
number 4, 5, 6, or 7.

Screens
-------

### SGB required

Cubby alone on the screen, with sprite text overlaid

    TRN Stress
    
    Requires
    Super
    Game Boy
    
    v0.01  © 2024
    Damian Yerrick
    Select: credits

### Title

Cubby alone on the screen, legs extending into the border area,
with sprite text overlaid

    TRN Stress  (in border)
    
    Press Start  (flashing)
    
    © 2024
    Damian Yerrick
    Select: credits

### Credits 1

    Program by Damian Yerrick
    pineight.com
    Fast 8-bit PRNG by foobles
    
    Cubby character based on a
    design by yoeynsf
    instagram.com/yoeynsf
    
    < 1/3 >   B: Exit
