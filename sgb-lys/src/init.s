include "src/hardware.inc"
include "src/global.inc"

section "initial_regs", HRAM

hInitialA::   ds 1
hInitialDIV:: ds 1
hInitialNR52::ds 1
hInitialL::   ds 1
hInitialH::   ds 1
hInitialE::   ds 1
hInitialD::   ds 1
hInitialC::   ds 1
hInitialB::   ds 1
hInitialF::   ds 1
hInitialLY::  ds 1
hInitialSP::  ds 2
hCapability:: ds 1

section "int_state", HRAM
hVblanks: ds 1

section "stack", WRAM0, ALIGN[1]
wStack: ds 64
wStackTop:

section "sgb_buffer", WRAM0
help_line_buffer:: ds 32

section "shadowOAM", WRAM0, ALIGN[8]
wShadowOAM: ds 160
wOAMUsed: ds 1

section "header", ROM0[$0100]
  nop
  jp reset
  ds 76, $00

section "reset", ROM0
reset:
  ldh [hInitialA], a
  ld a, [rDIV]
  ldh [hInitialDIV], a
  ld a, [rLY]
  di
  ld [hInitialSP], sp
  ld sp, hInitialSP
  push af
  push bc
  push de
  push hl
  ld a, [rNR52]
  ldh [hInitialNR52], a
  ld sp, wStackTop

  xor a
  ldh [hCurKeys], a
  ldh [hCapability], a
  ld c, 160
  ld hl, wShadowOAM
  rst memset_tiny
  call lcd_off
  call load_initial_font
  call sgb_wait
  call sgb_wait
  call sgb_wait
  call sgb_wait
  ld b, b
  call detect_sgb
  jp main

section "lcd_off", ROM0
;;
; If LCD is on, busy waits for vblank and turns LCD off
lcd_off:
  ; Skip loop if LCD is already off
  ldh a, [rLCDC]
  add a
  ret nc
  ; wait for LCD to be all the way off
.loop:
  ldh a, [rLY]
  xor 144
  jr nz, .loop
  ldh [rLCDC], a
  ret

section "load_initial_font", ROM0
load_initial_font:
  ; convert 1bpp to 2bpp
  ld de, ascii_1b
  ld hl, $9100
  .loop:
    ld a, [de]
    inc de
    ld [hl+], a
    xor a
    ld [hl+], a
    bit 3, h  ; stop at $9800
    jr z, .loop
  ; make an extra copy of hex digits shifted 2px right
  ld hl, $9100
  ld de, $9000
  .rrloop:
    ld a, [hl+]
    inc l
    rrca
    rrca
    ld [de], a
    inc e
    inc e
    jr nz, .rrloop
  ret

section "ascii_1b", ROM0
ascii_1b: incbin "obj/gb/ascii.1b"

section "stpcpy", ROM0
;;
; Copy from HL to DE, stopping at terminating $00
stpcpy_write:
  ld [de], a
  inc de
stpcpy:
  ld a, [hl+]
  or a
  jr nz, stpcpy_write
  dec hl
  ret

section "bcd8bit", ROM0
;;
; Converts an 8-bit value to 3 binary-coded decimal digits.
; @param A the value
; @return A: tens and ones digits; B[1:0]: hundreds digit;
; B[7:2]: unspecified
bcd8bit_baa::
  swap a
  ld b,a
  and $0F  ; bits 3-0 in A, range $00-$0F
  or a     ; for some odd reason, AND sets half carry to 1
  daa      ; A=$00-$15

  sla b
  adc a
  daa
  sla b
  adc a
  daa      ; A=$00-$63
  rl b
  adc a
  daa
  rl b
  adc a
  daa
  rl b
  ret

section "draw_labels", ROM0
;;
; Draw labels
cls_draw_labels::
  push hl
  ld h, " "
  call clear_scrn0_to_h
  pop hl
draw_labels::
  ld a, [hl+]
  ld e, a
  ld a, [hl+]
  ld d, a
  .charloop:
    ld a, [hl+]
    or a
    ret z
    cp " "
    jr c, draw_labels
    ld [de], a
    inc e
    jr .charloop

SECTION "vblank_handler", ROM0[$0040]
  push af
  ldh a, [hVblanks]
  inc a
  ldh [hVblanks], a
  pop af
  reti

SECTION "wait_vblank_irq", ROM0
;;
; Waits for the vblank ISR to increment the count of vertical blanks.
; Will lock up if DI, vblank IRQ off, or LCD off.
; Clobbers A, HL
wait_vblank_irq::
  ld hl, hVblanks
  ld a, [hl]
.wait:
  halt
  cp [hl]
  jr z, .wait
  ret

SECTION "busy_wait_vblank", ROM0

;;
; Waits for forced blank (rLCDC bit 7 clear) or vertical blank
; (rLY >= 144).  Use before VRAM upload or before clearing rLCDC bit 7.
busy_wait_vblank::
  ; If rLCDC bit 7 already clear, we're already in forced blanking
  ldh a,[rLCDC]
  rlca
  ret nc

  ; Otherwise, wait for LY to become 144 through 152.
  ; Most of line 153 is prerender, during which LY reads back as 0.
.wait:
  ldh a, [rLY]
  cp 144
  jr c, .wait
  ret

SECTION "wait_not_vblank", ROM0

;;
; Busy-wait for being out of vblank.  Use this for game loop timing
; if interrupts aren't in use yet.
wait_not_vblank::
  ldh a, [rLY]
  cp 144
  jr nc, wait_not_vblank
  ret

SECTION "memset", ROM0

clear_scrn0_to_0::
  ld h, 0
clear_scrn0_to_h::
  ld de,_SCRN0
  ld bc,32*32
;;
; Writes BC bytes of value H starting at DE.
memset::
  ; Increment B if C is nonzero
  dec bc
  inc b
  inc c
  ld a, h
.loop:
  ld [de],a
  inc de
  dec c
  jr nz,.loop
  dec b
  jr nz,.loop
  ret

section "memcpy", ROM0

;;
; Copies BC bytes from HL to DE.
; @return A: last byte copied; HL at end of source;
; DE at end of destination; B=C=0
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

section "memset_tiny",ROM0[$30]
;;
; Writes C bytes of value A starting at HL.
memset_tiny::
  ld [hl+],a
  dec c
  jr nz,memset_tiny
  ret

;;
; Writes C bytes of value A, A+1, ..., A+C-1 starting at HL.
memset_inc::
  ld [hl+],a
  inc a
  dec c
  jr nz,memset_inc
  ret

section "hramcode", ROM0
;;
; The routine gets copied to high RAM.  While OAM DMA is running,
; both ROM and WRAM are inaccessible; only HRAM is readable.
; But unlike on the NES, the CPU continues to fetch and execute
; instructions.  So a program needs to run 160 mcycles' worth of
; code from HRAM until this finishes.  Thus to present a display
; list, the program will call run_dma, not hramcode_start.
hramcode_start:
  ld a, wShadowOAM >> 8
  ldh [rDMA],a
  ld a, 40
.loop:
  dec a
  jr nz, .loop
  ret
hramcode_end:

SECTION "rom_ppuclear", ROM0

;;
; Moves sprites in the display list from wShadowOAM+[oam_used] through
; wShadowOAM+$9C offscreen by setting their Y coordinate to 0, which is
; completely above the screen top (16).
lcd_clear_oam::
  ; Destination address in shadow OAM
  ld hl, wOAMUsed
  ld a, [hl]
  and $FC
  ld l, a

  ; iteration count
  rrca
  rrca
  add 256 - 40
  ld c, a

  xor a
.rowloop:
  ld [hl+], a
  inc l
  inc l
  inc l
  inc c
  jr nz, .rowloop
  ret
