  IF  !DEF(GLOBAL_INC)
def GB_INC EQU 1
include "src/hardware.inc"

def hLocals equ $FF80
def locals_size equ 16
def SCRN_BG equ _SCRN0

;;
; Syntax: ldxy rp, xpos, ypos, mapbase
; Sets a register pair to the address of (x, y) tile coordinates
; within a tilemap.
; @param rp a register pair (BC, DE, HL)
; @param x horizontal distance in tiles from left (0-31)
; @param y vertical distance in tiles from top (0-31)
; @param mapbase start address of 32-cell-wide tilemap:
;   SCRN_BG (default), _SCRN0, _SCRN1, or a virtual tilemap in WRAM.
macro ldxy
  if _NARG < 4
    ld \1, (\3) * SCRN_VX_B + (\2) + SCRN_BG
  else
    ld \1, (\3) * SCRN_VX_B + (\2) + (\4)
  endc
endm

;;
; Syntax: lb rp, hivalue, lovalue
; Loads hivalue into the upper register of a pair (B, D, or H)
; and lovalue into the lower register of the same pair (C, E, or L).
macro lb
  ld \1, low(\2) << 8 | low(\3)
endm

  ENDC