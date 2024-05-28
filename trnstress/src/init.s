include "src/hardware.inc"
include "src/global.inc"

section "hState", HRAM
hCapability::    ds 1

def STACK_SIZE EQU 64
section "stack", WRAM0, ALIGN[2]
stack_top: ds STACK_SIZE

section "header", ROM0[$0100]
  nop
  jp reset
  ds 76, $00

section "reset", ROM0
reset:
  di
  ld sp, stack_top + STACK_SIZE  ; Set up stack pointer (full descending)

  ; for SGB-only software, get that logo off the screen
  ; sooner rather than later
  xor a
  ldh [rBGP], a
  ldh [hCurKeys], a
  ldh [hVblanks], a
  ldh [hCapability], a
  ldh [rIF], a
  inc a  ; ld a, IEF_VBLANK
  ldh [rIE], a
  ld a,P1F_GET_NONE
  ldh [rP1], a

  ; Copy the sprite DMA routine to HRAM
  ld hl, hramcode_src
  call memcpy_dst_length

  ; prevent bgb with all exceptions on from having a coronary
  call lcd_off
  xor a
  ld hl, _OAMRAM
  ld c, 160
  rst memset_tiny
  ld hl, SOAM
  ld c, 160
  rst memset_tiny
  jp main
  ; At this point, the screen is off, OAM and shadow OAM are empty,
  ; and hCapability is zeroed.  To fill hCapability, call sgb_wait
  ; a few times and then detect_sgb.

; memcpy and friends ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section "memset_tiny",ROM0[$08]
;;
; Writes C bytes of value A starting at HL.
memset_tiny::
  ld [hl+],a
  dec c
  jr nz,memset_tiny
  ret

section "memset_inc",ROM0
;;
; Writes C bytes of value A, A+1, ..., A+C-1 starting at HL.
memset_inc::
  ld [hl+],a
  inc a
  dec c
  jr nz,memset_inc
  ret

section "memset", ROM0
clear_scrn0_to_0::
  ld h, 0
  fallthrough clear_scrn0_to_h
clear_scrn0_to_h::
  ld de,_SCRN0
  fallthrough clear_scrn_de_to_h
clear_scrn_de_to_h::
  ld bc,32*32
  fallthrough memset

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
; Copy a string preceded by a 2-byte address and 2-byte length
; from HL.
; @param HL source address
; @return as memcpy
memcpy_dst_length::
  ld a, [hl+]
  ld e, a
  ld a, [hl+]
  ld d, a
  fallthrough memcpy_pascal16

;;
; Copy a string preceded by a 2-byte length from HL to DE.
; @param HL source address
; @param DE destination address
; @return as memcpy
memcpy_pascal16::
  ld a, [hl+]
  ld c, a
  ld a, [hl+]
  ld b, a
  fallthrough memcpy

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

; If you get an error about scope, upgrade to RGBDS 0.7 or later
stpcpy.continue:
  inc de
;;
; Copies from HL to DE, stopping at a $00 byte
; @param HL source
; @param DE destination
; @return A = 0; DE = pointer to final NUL
stpcpy::
  ld a,[hl+]
  ld [de],a
  or a
  jr nz, .continue
  ret
