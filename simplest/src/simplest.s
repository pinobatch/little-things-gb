; Simplest picture displayer for 8-bit Game Boy
; Copyright 2025 Damian Yerrick
; SPDX-License-Identifier: Zlib

; Subset of hardware.inc needed to load an image
DEF _VRAM        EQU $8000 ; $8000->$9FFF
DEF _VRAM8000    EQU _VRAM
DEF _VRAM8800    EQU _VRAM+$800   ; CHR RAM block 1
DEF _SCRN0       EQU _VRAM+$1800  ; first tilemap: $9800->$9BFF

DEF rLCDC EQU $FF40  ; LCD Control (R/W)
DEF LCDCF_OFF     EQU %00000000 ; LCD Control Operation
DEF LCDCF_ON      EQU %10000000 ; LCD Control Operation
DEF LCDCF_BG8800  EQU %00000000 ; BG & Window Tile Data Select
DEF LCDCF_BG9800  EQU %00000000 ; BG Tile Map Display Select
DEF LCDCF_BGON    EQU %00000001 ; BG Display

DEF rSCY EQU $FF42  ; Scroll Y (R/W)
DEF rSCX EQU $FF43  ; Scroll X (R/W)
DEF rLY EQU $FF44   ; LCDC Y-Coordinate (R)
DEF rBGP EQU $FF47  ; BG Palette Data (W)

DEF SCRN_Y    EQU 144 ; Height of screen in pixels

; Space for call stack
section "STACK", WRAM0
wStackTop: ds 64
wStackStart:

; Game Boy boot ROM ends at $0100
section "HEADER", ROM0[$0100]
  nop
  jp reset
  ds 76, $00  ; Leave space for RGBFIX to fill in a header

section "CODE", ROM0
reset:
  di
  ld sp, wStackStart

  ; turn LCD off if needed
  ldh a, [rLCDC]
  add a  ; move bit 7 into carry flag
  jr nc, .dont_need_to_turn_lcd_off
  .wait_to_turn_lcd_off:
    ldh a, [rLY]
    cp SCRN_Y
    jr c, .wait_to_turn_lcd_off
  .dont_need_to_turn_lcd_off:

  ; Initialize pertinent portions of the Game Boy hardware
  xor a
  ldh [rLCDC], a  ; Turn LCD off
  ldh [rSCX], a   ; clear scroll position
  ldh [rSCY], a

  ; Load the image
  ld hl, tiles
  ld de, _VRAM8800
  ld bc, tilemap - tiles
  call memcpy
  ;ld hl, tilemap  ; memcpy already left HL pointing to tilemap
  ld de, _SCRN0
  call load_full_nam

  ; Set up display parameters and turn on display
  ld a, %11100100  ; gray ramp with 0=white 3=black
  ldh [rBGP], a
  ld a, LCDCF_ON|LCDCF_BGON
  ldh [rLCDC], a

  ; Room-heater wait loop, in case the emulator developer hasn't
  ; implemented interrupts yet
.forever:
  jr .forever
  
;;
; Copies BC bytes from HL to DE.
memcpy::
  ; Increment B if C is nonzero
  dec bc
  inc b
  inc c
.loop:
  ld a, [hl+]
  ld [de],a
  inc de
  dec c
  jr nz,.loop
  dec b
  jr nz,.loop
  ret

;;
; Copies a 20 column by 18 row tilemap from HL to screen at DE.
load_full_nam::
  ld bc,256*20+18
;;
; Copies a B column by C row tilemap from HL to screen at DE.
load_nam::
  push bc
  push de
  .byteloop:
    ld a,[hl+]
    ld [de],a
    inc de
    dec b
    jr nz, .byteloop

  ; Move to next screen row
  pop de
  ld a,32
  add e
  ld e,a
  jr nc, .no_inc_d
    inc d
  .no_inc_d:

  ; Restore width; do more rows remain?
  pop bc
  dec c
  jr nz, load_nam
  ret

section "RODATA", ROM0
tiles:   incbin "obj/gb/simplest.2bpp"
tilemap: incbin "obj/gb/simplest.nam"
