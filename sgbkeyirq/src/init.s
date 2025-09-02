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
hVblanks:: ds 1
hTimerMid: ds 1
hTimerHi: ds 1
hPressTimeLo:: ds 1
hPressTimeMid:: ds 1
hPressTimeHi:: ds 1
hPressOccurred:: ds 1
hPressRingBufferIndex:: ds 1

section "presses", WRAM0, ALIGN[2]
wPresses:: ds PRESS_BUFFER_COUNT * SIZEOF_PRESS_BUFFER_ENTRY

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

  ; Everything is all nice and saved now.  We can initialize the
  ; test's state machine.
  xor a
  ldh [rBGP], a  ; blank the Nintendo logo without turning off LCD
  ldh [hCurKeys], a
  ldh [hCapability], a  ; to fill later during SGB detection
  ldh [hVblanks], a
  ldh [hTimerMid], a
  ldh [hTimerHi], a
  ldh [hPressOccurred], a
  ldh [hPressRingBufferIndex], a
  ldh [rTAC], a
  ldh [rTIMA], a
  ld c, 160
  ld hl, wShadowOAM
  rst memset_tiny
  ld c, PRESS_BUFFER_COUNT * SIZEOF_PRESS_BUFFER_ENTRY
  ld hl, wPresses
  rst memset_tiny

  jp main

section "lcd_off", ROM0
;;
; If LCD is on, busy waits for vblank and turns LCD off
lcd_off::
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
load_initial_font::
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

section "draw_labels", ROM0
;;
; Draw labels
cls_draw_labels::
  push hl
  ld h, ' '
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
    cp ' '
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

; apparently the busy wait is used by the SGB driver's freeze and
; unfreeze routines; I'll need to see if it's even necessary
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
; Source and destination may overlap if DE < HL.
; @param HL source address
; @param DE destination address
; @param BC byte count
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


SECTION "timer_handler", ROM0[$0050]
; Called when TIMA wraps
timer_handler:
  push af
  ldh a, [hTimerMid]
  add 1
  ldh [hTimerMid], a
  ldh a, [hTimerHi]
  adc 0
  ldh [hTimerHi], a
  pop af
  reti

SECTION "joy_handler", ROM0[$0060]
; Untested!
joy_handler:
  push af
  ldh a, [rTIMA]  ; initial TIMA read
  ldh [hPressTimeLo], a
  add a  ; save bit 7 of the timer value
  ldh a, [hTimerHi]
  ldh [hPressTimeHi], a
  ldh a, [hTimerMid]
  ldh [hPressTimeMid], a

  ; If TIMA wrapped in the roughly 12-cycle window between the button
  ; press and the initial TIMA read, the timer interrupt won't have
  ; incremented rTimerMid and rTimerHi yet.  If TIMA bit 7 was true
  ; in the initial read, this won't have happened.
  jr c, .wrapDidNotOccur

  ; If a timer interrupt occurred since the start of the joypad
  ; interrupt handler, the timer bit in IF will be true.  (It can't
  ; have wrapped from FF to 00 after the initial read because that
  ; would have caused the initial read to have bit 7 true.)
  ldh a, [rIF]
  and IEF_TIMER
  jr z, .wrapDidNotOccur
    ldh a, [hPressTimeMid]
    add 1
    ldh [hPressTimeMid], a
    ldh a, [hPressTimeHi]
    adc 0
    ldh [hPressTimeHi], a
  .wrapDidNotOccur:

  ld a, 1
  ldh [hPressOccurred], a
  pop af
  reti
