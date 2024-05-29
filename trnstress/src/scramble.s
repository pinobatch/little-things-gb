include "src/hardware.inc"
include "src/global.inc"

def NUM_SCRAMBLES equ 16
export NUM_SCRAMBLES

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
  dw twobitnam_name, twobitnam_chr, twobitnam_pct, 0
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

; name ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

twobitnam_name: db "NYA 2bpp via tilemap", 0
twobitnam_chr:
  ld b, b
  ret
twobitnam_pct:
  ld b, b
  ret

; name ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

twobitbgp_name: db "NYA 2bpp via BGP", 0
twobitbgp_chr:
  ld b, b
  ret
twobitbgp_pct:
  ld b, b
  ret

; name ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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
  ld b, $08
  ld h, b
  jp memset

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
  ld h, b
  jp memset

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

obj8x8_name: db "NYA 8-line objects", 0
obj8x8_proc:
  ld b, b
  ret

; 16-line objects ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; move right 64 by 80 pixels to object plane

obj8x16_name: db "NYA 16-line objects", 0
obj8x16_proc:
  ld b, b
  ret

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

; name ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fine_x_name: db "NYA Fine X scroll", 0
fine_x_proc:
  ld b, b
  ret

; name ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fine_y_name: db "NYA Fine Y scroll", 0
fine_y_proc:
  ld b, b
  ret

