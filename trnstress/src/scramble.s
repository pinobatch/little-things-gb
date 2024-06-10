;
; Scrambling methods for TRN Stress
; Copyright 2024 Damian Yerrick
; SPDX-License-Identifier: Zlib
;
include "src/hardware.inc"
include "src/global.inc"

def NUM_SCRAMBLES equ 16
export NUM_SCRAMBLES

;;
; Performs one iteration of an 8-bit pseudorandom number generator
; (PRNG) by foobles.  It acts as a hybrid linear feedback shift
; register (LFSR) and linear congruential generator (LCG) with
; period 256.  Input and output in register A; sets flags like ADC.
; If A < $80: Multiply by 2, XOR with $46, and add $EB
; If A >= $80: Multiply by 2 and add $EC
; <https://foobles.neocities.org/blog/2023-06-06/prng>
macro foobles_prng_iter
  add a
  jr c, .no_eor
    xor $46
  .no_eor:
  adc $eb
endm

section "Scramble_select", HRAM
hScrambleToUse:: ds 1
hRasterToUse:: ds 1

section "Scramble_procs", ROM0

;;
; Scramble the tilemap for a PCT_TRN.
; @param hScrambleToUse index into scrambles struct (0-15)
; @return DE unchanged; B=0; BGP, SCX, SCY, WX, and WY
; may be affected
sgb_scramble_pct::
  ld c, 4
  jr sgb_run_scramble_proc

;;
; Scramble the tilemap for a CHR_TRN.
; @param hScrambleToUse index into scrambles struct (0-15)
; @return DE unchanged; B=0; BGP, SCX, SCY, WX, and WY
; may be affected
sgb_scramble_chr::
  ld c, 2
  fallthrough sgb_run_scramble_proc

;;
; Scramble the tilemap for a VRAM transfer.
; @param hScrambleToUse index into scrambles struct (0-15)
; @param C 2 for CHR_TRN or 4 for PCT_TRN
; @return DE unchanged; B=0; BGP, SCX, SCY, WX, and WY
; may be affected
sgb_run_scramble_proc:
  push de
  ldh a, [hScrambleToUse]
  add a
  add a
  add a
  add c
  calls scrambles
  add low(scrambles)
  ld l, a
  adc high(scrambles)
  sub l
  ld h, a  ; HL = &scrambles.procs[c]
  ld a, [hl+]
  ld h, [hl]
  ld l, a  ; HL = scrambles.procs[c]
  call .jp_hl
  pop de
  ld b, 0
  ret
.jp_hl:
  jp hl

scrambles::
  jumptable
  dw null_name, null_proc, null_proc, 0
  dw invbgp_name, invbgp_proc, invbgp_proc, 0
  dw twobitnam_name, twobitnam_chr, null_proc, 0
  dw twobitbgp_name, twobitbgp_chr, twobitbgp_pct, 0
  dw reversetiles_name, reversetiles_proc, reversetiles_proc, 0
  dw blk21_name, blk21_proc, blk21_proc, 0
  dw nam9c_name, nam9c_proc, nam9c_proc, 0
  dw window_name, window_proc, window_proc, 0
  dw obj8x8_name, obj8x8_proc, obj8x8_proc, 0
  dw obj8x16_name, obj8x16_proc, obj8x16_proc, 0
  dw coarse_x_name, coarse_x_proc, coarse_x_proc, 0
  dw coarse_y_name, coarse_y_proc, coarse_y_proc, 0
  dw alt_coarse_x_name, alt_coarse_x_proc, alt_coarse_x_proc, alt_coarse_x_raster
  dw reverse_y_name, reverse_y_proc, reverse_y_proc, reverse_y_raster
  dw fine_x_name, fine_x_proc, fine_x_proc, 0
  dw fine_y_name, fine_y_proc, fine_y_proc, 0

; Normal border (null transform) ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

null_name: db "Normal border", 0
null_proc:
  ret

; Inverted BGP (colors 3210) ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; XOR tile data with $FF and use BGP to compensate

invbgp_name: db "Inverted BGP", 0
invbgp_proc:
  ld hl, $8000
  .chrloop:
    ld a, [hl]
    cpl
    ld [hl+], a
    bit 4, h  ; loop until $9000
    jr z, .chrloop
  ld a, %00011011
  ldh [rBGP], a
  ret

; 2bpp via tilemap ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; For CHR_TRN, shift the tile data around to keep only even-numbered
; tiles, and blank the second half of CHR RAM.  Then shift even
; tilemap entries to the right and FF out odd tilemap entries.
; Do nothing to PCT_TRN.

twobitnam_name: db "2bpp via tilemap", 0
twobitnam_chr:
  ; Keep only even tiles (containing bit planes 0-1)
  ld de, $8010
  .chrtileloop:
    ; calculate source address
    ld l, e
    ld h, d
    add hl, hl
    set 7, h
    .chrbyteloop:
      ld a, [hl+]
      ld [de], a
      inc de
      ld a, l
      and $0F
      jr nz, .chrbyteloop
    bit 3, d  ; was $8800 reached?
    jr z, .chrtileloop

  ; Remove odd tiles
  ld a, d
  ld h, d
  ld l, e
  ld c, e
  .oddloop:
    rst memset_inc
    rrca
    bit 4, h
    jr z, .oddloop

  ld de, $8800
  call memtrash_2k_at_de

  ; Blank tile $FF
  ld hl, $8FF0
  xor a
  ld c, 16
  rst memset_tiny

  ; Adjust the tilemap to compensate
  ld hl, _SCRN0
  ld a, $FF
  .namloop:
    srl [hl]
    inc hl
    ld [hl+], a
    bit 1, h  ; was $9A00 reached?
    jr z, .namloop
  ret


memtrash_9000:
  ld de, $9000
  fallthrough memtrash_2k_at_de

memtrash_2k_at_de:
  ld bc, $800
  ld a, d
  fallthrough memtrash

;;
; Fills BC bytes starting at DE with pseudorandom garbage.
memtrash:
  dec bc
  inc b
  inc c
  .loop
    foobles_prng_iter
    xor b  ; temper with remaining byte count to reduce repetition
    ld [de], a
    xor b
    inc de
    dec c
    jr nz, .loop
    dec b
    jr nz, .loop
  ret

; 2bpp via BGP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; For CHR_TRN, copy odd bytes of even tiles 15 bytes later, then
; clobber all even bytes.  For PCT_TRN, keep only colors 1, 4, and 5,
; and set the other colors to some value that stands out.

def NONO_COLOR equ $001F  ; R=31 G=0 B=0

twobitbgp_name: db "2bpp via BGP", 0
twobitbgp_chr:

  ; Copy bit plane 1 of each tile to bit plane 2
  ld de, $8001
  .chrtileloop:
    ld hl, 15
    add hl, de
    .chrbyteloop:
      ld a, [de]
      inc de
      inc de
      ld [hl+], a
      inc hl
      bit 4, e  ; is bit plane 1 complete?
      jr z, .chrbyteloop
    ld e, l
    ld d, h
    inc e
    bit 4, d  ; has $9001 been reached?
    jr z, .chrtileloop

  ; Trash bit planes 1 and 3
  ld hl, $8001
  ld a, h
  .chrtrashloop:
    ld [hl+], a
    inc hl
    foobles_prng_iter
    bit 4, h  ; has $9001 been reached?
    jr z, .chrtrashloop

  ld a, %01000100  ; turn colors 2 and 3 into 0 and 1
  ldh [rBGP], a    ; disregarding bitplane 0
  ret

twobitbgp_pct:
  ; Save palette colors 2 and 3
  ld hl, $8804
  ld de, $8904
  ld bc, 4
  call memcpy

  ; Trash the rest of the palette by setting it to the no-no color.
  ld b, 48 - 4
  .set_nono_loop:
    ld a, low(NONO_COLOR)
    ld [hl+], a
    ld a, high(NONO_COLOR)
    ld [hl+], a
    dec b
    jr nz, .set_nono_loop

  ; Copy colors 2 and 3 back in as 4 and 5
  ld hl, $8904
  dec d    ; DE = $8808
  ld c, l  ; BC = $0004
  jp memcpy

; Tiles in reverse order ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; exchange tile at $8000 with $8FF0, $8010 with $8FE0, etc.
; and use the tilemap to compensate

reversetiles_name: db "Tiles in reverse order", 0
reversetiles_proc:
  ld hl, $9800
  .namloop:
    ld a, [hl]
    cpl
    ld [hl+], a
    bit 2, h  ; loop until $9C00
    jr z, .namloop
  ld hl, $8000
  .chrloop:
    ld a, h
    xor $0F
    ld d, a
    ld a, l
    xor $F0
    ld e, a
    ld b, [hl]
    ld a, [de]
    ld [hl+], a
    ld a, b
    ld [de], a
    bit 3, h  ; loop until $8800
    jr z, .chrloop
  ret

; Tiles at $8800-$97FF ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Background tiles $00-$7F can come from $8000-$87FF or $9000-$97FF.
; Set up for the latter.

blk21_name: db "Tiles at 8800-97FF", 0
blk21_proc:
  ld a, LCDCF_BGON|LCDCF_BLK21|LCDCF_BG9800
  ldh [rLCDC], a
  ld hl, $8000
  ld de, $9000
  ld bc, $0800
  call memcpy
  ld d, $80
  jp memtrash_2k_at_de

; Tilemap at $9C00 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The main tilemap can be at $9800 or $9C00.  Set up for the latter. 

nam9c_name: db "Tilemap at 9C00", 0
nam9c_proc:
  ld a, LCDCF_BGON|LCDCF_BLK01|LCDCF_BG9C00
  ldh [rLCDC], a
  ld hl, $9800
  ld de, $9C00
  ld bc, $300
  call memcpy
  ld d, $98
  ld b, $03
  jp memtrash

; Window tilemap ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; move right 32 pixels at Y=16 through 95 to window

def WINDOW_X equ 128
def WINDOW_Y equ 16
def WINDOW_WIDTH_TILES equ (160 - WINDOW_X) / 8
def WINDOW_HEIGHT_TILES equ (96 - WINDOW_Y) / 8

window_name: db "Window tilemap", 0
window_proc:
  lb bc, WINDOW_WIDTH_TILES, WINDOW_HEIGHT_TILES
  ldxy de, WINDOW_X / 8, WINDOW_Y / 8
  .rowloop:
    push bc
    ld hl, $9C00 - ($9800 + WINDOW_X / 8 + WINDOW_Y / 8 * 32)
    add hl, de
    .tileloop:
      ld a, [de]
      ld [hl+], a
      cpl
      ld [de], a
      inc e
      dec b
      jr nz, .tileloop
    ld a, 32 - WINDOW_WIDTH_TILES
    add e
    ld e, a
    adc d
    sub e
    ld d, a
    pop bc
    dec c
    jr nz, .rowloop
  ld a, WINDOW_X + 7
  ldh [rWX], a
  ld a, WINDOW_Y
  ldh [rWY], a
  ld a, LCDCF_BGON|LCDCF_WINON|LCDCF_BLK01|LCDCF_BG9800|LCDCF_WIN9C00
  ldh [rLCDC], a
  ret

; 8-line objects ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; move top right 32 by 80 pixels to object plane

obj8x8_name: db "8-line objects", 0
obj8x8_proc:
  ; Draw a rectangle of objects
  ld hl, _OAMRAM
  .objloop:
    ; 4 objects per row
    ld a, l  ; L = YYYYXX00
    and %11110000
    ld e, a  ; E = row * 16
    rra
    add 16
    ld [hl+], a  ; Y position
    ld a, l
    and %00001100
    add a
    add 128+8
    ld [hl+], a    ; X position
    ld a, l
    and %11111100  ; A = row * 16 + column * 4
    rra
    rra            ; A = row * 4 + column
    add e          ; A = row * 20 + column
    add 16
    ld [hl+], a    ; tile number
    xor a
    ld [hl+], a
    ld a, l
    cp $A0
    jr c, .objloop

  ; Enable drawing objects
  ld a, LCDCF_BGON|LCDCF_BLK01|LCDCF_BG9800|LCDCF_OBJON|LCDCF_OBJ8
  ldh [rLCDC], a

  ; Blank tile $FF and blank this rectangle in the background plane
  xor a
  ld hl, $8FF0
  ld c, 16
  rst memset_tiny
  dec a
  ld hl, $9B00
  ld c, l
  rst memset_tiny  ; H = $9D00
  dec h
  lb bc, 4, 10
  ldxy de, 16, 0
  jp load_nam

; 16-line objects ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; swap tiles 13, 15, 17, and 19 of each row pair with 32, 34, 36,
; and 38, then move right 64 by 80 pixels to object plane

def OBJ16_ROWPAIR_LEN equ 640
def OBJ16_ROWPAIRS_END equ $8000 + 5 * OBJ16_ROWPAIR_LEN

obj8x16_name: db "16-line objects", 0
obj8x16_proc:
  ; In each 2x2-tile group in the upper 64x80, swap the top right and
  ; bottom left tiles
  ld de, $8000 + 13 * 16
  .rowpairloop:
    ld hl, (32 - 13) * 16
    add hl, de
    .byteloop:
      ld c, [hl]
      ld a, [de]
      ld [hl+], a
      ld a, c
      ld [de], a
      inc de
      ld a, e
      and $0F
      jr nz, .byteloop
    ld a, e
    add 16
    ld e, a
    adc d
    sub e
    ld d, a
    ; At right side, tile index modulo 640 should be 21
    ; which implies byte index modulo 128 should be 80
    ld a, e
    and %01110000
    cp 80
    jr nz, .rowpairloop
    ; Move to next row pair
    if low(OBJ16_ROWPAIR_LEN - 128) == 0
      or a
    else
      ld a, low(OBJ16_ROWPAIR_LEN - 128)
      add e
      ld e, a
    endc
    ld a, high(OBJ16_ROWPAIR_LEN - 128)
    adc d
    ld d, a
    ld a, e
    sub low(OBJ16_ROWPAIRS_END)
    ld a, d
    sub high(OBJ16_ROWPAIRS_END)
    jr c, .rowpairloop

  ; Draw a rectangle of objects
  ld hl, _OAMRAM
  .objloop:
    ; 8 objects per row
    ld a, l  ; L = YYYXXX00
    and %11100000
    ld e, a  ; E = row * 32
    rra
    add 16
    ld [hl+], a  ; Y position
    ld a, l
    and %00011100
    add a
    add 96+8
    ld [hl+], a    ; X position
    ld a, l
    and %11111000  ; A = row * 32 + column / 2 * 8
    rra
    rra            ; A = row * 8 + column
    add e          ; A = row * 40 + column / 2 * 2
    bit 2, l
    jr z, .obj_even
      add 20
    .obj_even:
    add 12
    ld [hl+], a    ; tile number
    xor a
    ld [hl+], a
    ld a, l
    cp $A0
    jr c, .objloop

  ; Enable drawing objects
  ld a, LCDCF_BGON|LCDCF_BLK01|LCDCF_BG9800|LCDCF_OBJON|LCDCF_OBJ16
  ldh [rLCDC], a

  ; Blank tile $FF and blank this rectangle in the background plane
  xor a
  ld hl, $8FF0
  ld c, 16
  rst memset_tiny
  dec a
  ld hl, $9B00
  ld c, l
  rst memset_tiny  ; H = $9D00
  dec h
  lb bc, 8, 10
  ldxy de, 12, 0
  jp load_nam

; coarse X scroll ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; move all tilemap entries 1 byte later and compensate with SCX

coarse_x_name: db "Coarse X scroll", 0
coarse_x_proc:
  ld hl, $9800 + 13 * 32 - 12
  .namloop:
    ld a, [hl+]
    ld [hl-], a
    dec hl
    bit 3, h
    jr nz, .namloop
  ld a, 8
  ldh [rSCX], a
  ret

; coarse Y scroll ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; move all tilemap entries 32 bytes later and compensate with SCY

coarse_y_name: db "Coarse Y scroll", 0
coarse_y_proc:
  ld de, $9800 + 13 * 32 - 12
  .namloop:
    ld hl, 32
    add hl, de
    ld a, [de]
    ld [hl], a
    dec de
    bit 3, d
    jr nz, .namloop
  ld a, 8
  ldh [rSCY], a
  ret

; Alternating coarse X ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Shift rows 1, 3, 5, 7, 9, and 11 right by 1 byte and compensate
; with a raster effect on SCX

alt_coarse_x_name: db "Alternating coarse X", 0
alt_coarse_x_proc:
  ldxy hl, 20, 1
  lb bc, 20, 6
  .rowloop:
    push bc
    .byteloop:
      dec hl
      ld a, [hl+]
      ld [hl-], a
      dec b
      jr nz, .byteloop
    ld a, 64 + 20
    ld [hl], a
    add l
    ld l, a
    adc h
    sub l
    ld h, a
    pop bc
    dec c
    jr nz, .rowloop
  ret
alt_coarse_x_raster:
  db low(rSCX)
  db 0, 8, 0, 8, 0, 8, 0, 8, 0, 8, 0, 8, 0


; name ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

reverse_y_name: db "Rows in reverse order", 0
reverse_y_proc:
  ldxy hl, 0, 0
  ldxy de, 0, 12
  lb bc, 20, 6
  .rowloop:
    push bc
    .byteloop:
      ld c, [hl]
      ld a, [de]
      ld [hl+], a
      ld a, c
      ld [de], a
      inc de
      dec b
      jr nz, .byteloop
    ; move HL to next row and DE to previous row
    ld a, l
    add 32-20
    ld l, a
    adc h
    sub l
    ld h, a
    ld a, e
    sub 32+20
    ld e, a
    jr nc, .no_borrow_d
      dec d
    .no_borrow_d:

    pop bc
    dec c
    jr nz, .rowloop
  ret
reverse_y_raster:
  db low(rSCY)
  db 96, 80, 64, 48, 32, 16, 0, -16, -32, -48, -64, -80, -96

; Fine X scroll ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Shift tile data to right by 1 bit; use SCX to compensate

fine_x_name: db "Fine X scroll", 0
fine_x_proc:
  ld hl, $8000
  ld de, 16

  ; Shift entire pattern table right by 1 bit
  .fine_y_loop:
    xor a
    .byteloop:
      rla
      rr [hl]
      rra
      add hl, de
      bit 4, h
      jr z, .byteloop
    res 4, h  ; stay in blocks 0 and 1
    or [hl]
    ld [hl+], a  ; set that last bit and move onto the next fine Y
    bit 4, l
    jr z, .fine_y_loop

  ; Add nametable column to show the last pixel on each tile row
  ld e, 32
  ldxy hl, 20, 0
  ld a, l
  .right_column_loop:
    ld [hl], a
    add hl, de
    add 20
    jr nc, .right_column_loop
  ldxy hl, 16, 12
  ld [hl], d  ; write $00 to the right of tile $FF

  ; Compensate for shift with scroll
  ld a, 1
  ldh [rSCX], a
  ret

; Fine Y scroll ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Shift tile data down by 1 row; use SCY to compensate

def FINE_Y_END equ $8140

fine_y_name: db "Fine Y scroll", 0
fine_y_proc:
  ld hl, $8000
  .xloop:
    push hl
    ld de, 320 - 16
    .yloop:
      ; move tile data down by 2 bytes (1 line)
      ld a, c
      ld c, [hl]
      ld [hl+], a
      ld a, b
      ld b, [hl]
      ld [hl+], a
      ; if at end of tile move to next tile
      ld a, l
      and $0F
      jr nz, .yloop
      add hl, de
      bit 4, h
      jr z, .yloop
    ; Wrap the last row of tile data to the top of the row
    pop hl
    ld a, c
    ld [hl+], a
    ld a, b
    ld [hl-], a
    ; Move to next column
    ld de, 16
    add hl, de
    ld a, l
    sub low(FINE_Y_END)
    ld a, h
    sbc high(FINE_Y_END)
    jr c, .xloop

  ; Add last nametable row
  xor a
  ldxy hl, 0, 13
  ld c, 16
  rst memset_inc
  ldxy hl, 16, 12
  ld c, 4
  rst memset_inc
  ld a, 1
  ldh [rSCY], a
  ret
