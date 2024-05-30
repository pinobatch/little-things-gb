include "src/hardware.inc"
include "src/global.inc"

def FRAME_TIMING_SGB_FREEZE equ 0
def FRAME_TIMING_NUM_TILES equ 12
def FRAME_TIMING_VARIABLE_TILE equ 3
def FRAME_TIMING_DIGIT_BASE equ $04
def FRAME_TIMING_NUM_DIGITS equ 8

section "frame_timing", ROM0
frame_timing_pb16: incbin "obj/gb/frame_timing_tiles.4b.pb16"

frame_timing_palette:
  drgb $F785FA,$000000,$AEAEAE,$FFFFFF
  drgb $BD3C30,$BDAC2C,$077704,$4051D0
  .end

frame_timing_labels:
  db 16,  8, "The digit denotes on which", LF
  db 16, 16, "frame the SGB system", LF
  db 16, 24, "software received the data.", LF
  db 28, 48, LEFT_ARROW, " PCT_TRN (tilemap) ", RIGHT_ARROW, LF
  db 40, 56, "CHR_TRN (tiles) ", DOWN_ARROW, 0

run_frame_timing::
  if FRAME_TIMING_SGB_FREEZE
    call sgb_freeze
  endc
  call lcd_off

  ; Set up CHR_TRN manually
  ld de, frame_timing_pb16
  ld hl, $8000
  ld b, 2 * FRAME_TIMING_NUM_TILES
  call pb16_unpack_block
  xor a
  call chr_trn_load_variable_digit  ; Set up for frame 0

  ld hl, $9A00
  xor a
  ld c, 2 * FRAME_TIMING_NUM_TILES
  rst memset_inc
  ld a, 2 * FRAME_TIMING_VARIABLE_TILE
  .chr_trn_nam_loop:
    ld [hl+], a
    inc a
    ld [hl+], a
    dec a
    bit 0, h
    jr z, .chr_trn_nam_loop

  ; rearrange into rectangle
  ld hl, $9A00
  ld de, $9800
  lb bc, 20, 13
  call load_nam

  if FRAME_TIMING_SGB_FREEZE == 0
    ; clear tilemap after transfer area (cosmetic)
    ldxy hl, 20, 12
    xor a
    ld c, a
    rst memset_tiny
  endc

  ; turn the screen on for buffer
  ld a, %11100100
  ldh [rBGP], a
  xor a
  ldh [rSCX], a
  ldh [rSCY], a
  ld a, LCDCF_ON|LCDCF_BGON|LCDCF_BLK01|LCDCF_BG9800
  ldh [rLCDC], a
  ld a, $13 << 3 | 1  ; CHR_TRN
  ld b, 0             ; first half
  call sgb_send_ab_now

  ld a, 1
  .chr_trn_wait_loop:
    push af
    call wait_vblank_irq
    pop af
    push af
    call chr_trn_load_variable_digit
    pop af
    inc a
    cp FRAME_TIMING_NUM_DIGITS
    jr c, .chr_trn_wait_loop

  ; CHR_TRN done; let's do the PCT_TRN
  ; This is 64 bytes wide, 28 bytes tall, plus a palette.
  ; Start with a conventional tilemap. Only 7 rows are needed.
  call lcd_off
  ld hl, $9B00
  ld a, l
  ld c, l
  rst memset_inc

  ; Each PCT_TRN tilemap byte represents 8 by 1 tiles or 64 by 8
  ; pixels of the border.  Make all these aliases of the top left
  ; 64x8-pixel area for rapid updates.
  dec h  ; hl = $9B00
  ld b, 28  ; row count
  xor a
  .pct_lr_tilemap:
    ld [hl+], a
    inc l
    inc l
    ld [hl+], a
    dec b
    jr nz, .pct_lr_tilemap

  ; Alias map is finalized; toss it up into a rectangle
  ld hl, $9B00
  ld de, $9800
  lb bc, 20, 7
  call load_nam
  if FRAME_TIMING_SGB_FREEZE == 0
    ldxy hl, 0, 7
    xor a
    ld c, a
    rst memset_tiny
    rst memset_tiny
  endc

  ; we'll make most of this border 0 (transparent), so clear it and
  ; add a palette
  ld hl, $8000
  ld [hl], l
  inc l
  ld [hl], %00010000  ; vhpccctt
  dec l
  ld bc, 64 * 32 - 2
  ld de, $8002
  call memcpy
  ld hl, frame_timing_palette
  ld bc, frame_timing_palette.end-frame_timing_palette
  call memcpy

  ; The two parts that aren't transparent are the variable digit
  ; and a display of the CHR_TRN result.  Prepare the latter.
  ld hl, $8000 + 8 * 2 + 14 * 64
  ld de, 32  ; end of one row to start of next
  ld b, 0
  .pct_trn_chr_result_loop:
    ld [hl], b
    inc hl
    inc hl
    inc b
    ld a, b
    and $0F
    jr nz, .pct_trn_chr_result_loop
    add hl, de
    bit 7, b
    jr z, .pct_trn_chr_result_loop

  ; xor a ; after and $0F jr nz, A = 0
  call pct_trn_load_variable_digit

  ld a, LCDCF_ON|LCDCF_BGON|LCDCF_BLK01|LCDCF_BG9800
  ldh [rLCDC], a
  ld a, $14 << 3 | 1  ; PCT_TRN
  ld b, 0             ; unused
  call sgb_send_ab_now

  ld a, 1
  .pct_trn_wait_loop:
    push af
    call wait_vblank_irq
    pop af
    push af
    call pct_trn_load_variable_digit
    pop af
    inc a
    cp FRAME_TIMING_NUM_DIGITS
    jr c, .pct_trn_wait_loop

  call lcd_off
  ld de, $8800
  ld bc, $1400
  ld h, e
  call memset
  ld de, $8800 >> 4
  ld hl, frame_timing_labels
  call vwfDrawLabels
  ld a, %11111100
  ldh [rBGP], a
  ld a, LCDCF_ON|LCDCF_BGON|LCDCF_BLK21|LCDCF_BG9800
  ldh [rLCDC], a
  call sgb_unfreeze

  .exit_wait_loop:
    call wait_vblank_irq
    call read_pad
    ld a, [hNewKeys]
    or a
    jr z, .exit_wait_loop
  ret

;;
; Copies a digit tile over the variable tile.
chr_trn_load_variable_digit:
  add FRAME_TIMING_DIGIT_BASE
  add a
  ld l, a
  ld h, high($8000 >> 4)
  add hl, hl
  add hl, hl
  add hl, hl
  add hl, hl
  ld de, $8000 + (FRAME_TIMING_VARIABLE_TILE << 5)
  ld bc, 32
  jp memcpy

;;
; Writes a digit to the part of CHR RAM that's aliased down the left
; and right borders
pct_trn_load_variable_digit:
  add FRAME_TIMING_DIGIT_BASE
  ld hl, $8004
  ld [hl+], a
  inc l
  ld [hl+], a
  inc l
  ld [hl+], a
  inc l
  ld [hl+], a
  ret

sgb_send_ab_now:
  ld hl, wSGBPacketBuffer
  ld [hl+], a
  ld a, b
  ld [hl+], a
  ld c, 16-2
  xor a
  rst memset_tiny
  ld hl, wSGBPacketBuffer
  jp sgb_send_now
