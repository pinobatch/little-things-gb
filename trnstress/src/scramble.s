include "src/hardware.inc"
include "src/global.inc"

def NUM_SCRAMBLES equ 16
export NUM_SCRAMBLES

section "Scramble_select", HRAM
hScrambleToUse:: ds 1

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
  dw null_name, null_proc, null_proc, null_raster
  dw invbgp_name, invbgp_proc, invbgp_proc, null_raster
  dw twobitnam_name, twobitnam_chr, twobitnam_pct, null_raster
  dw twobitbgp_name, twobitbgp_chr, twobitbgp_pct, null_raster
  dw reversetiles_name, reversetiles_proc, reversetiles_proc, null_raster
  dw blk21_name, blk21_proc, blk21_proc, null_raster
  dw nam9c_name, nam9c_proc, nam9c_proc, null_raster
  dw window_name, window_proc, window_proc, null_raster
  dw obj8x8_name, obj8x8_proc, obj8x8_proc, null_raster
  dw obj8x16_name, obj8x16_proc, obj8x16_proc, null_raster
  dw coarse_x_name, coarse_x_proc, coarse_x_proc, null_raster
  dw coarse_y_name, coarse_y_proc, coarse_y_proc, null_raster
  dw alt_coarse_x_name, alt_coarse_x_proc, alt_coarse_x_proc, alt_coarse_x_raster
  dw reverse_y_name, reverse_y_proc, reverse_y_proc, reverse_y_raster
  dw fine_x_name, fine_x_proc, fine_x_proc, null_raster
  dw fine_y_name, fine_y_proc, fine_y_proc, null_raster

; Normal border (null transform) ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

null_name: db "Normal border", 0
null_proc:
  ret
null_raster:
  db low(rSTAT)
  ds 13, $00

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
  ld b, b
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

; name ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

window_name: db "NYA Window tilemap", 0
window_proc:
  ld b, b
  ret

; 8-line objects ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; move right 32 by 80 pixels to object plane

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
  ld b, b
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

; name ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

alt_coarse_x_name: db "NYA Alternating coarse X", 0
alt_coarse_x_proc:
  ld b, b
  ret
alt_coarse_x_raster:
  db low(rSCX)
  db 0, 8, 0, 8, 0, 8, 0, 8, 0, 8, 0, 8, 0


; name ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

reverse_y_name: db "NYA Rows in reverse order", 0
reverse_y_proc:
  ld b, b
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

