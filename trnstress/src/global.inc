
  IF  !DEF(GLOBAL_INC)
def GLOBAL_INC equ 1

; call graph annotation ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

macro fallthrough
  assert (\1) == @
endm

macro calls
endm

macro tailcalls
endm

macro jumptable
endm

macro local
endm

; things left out of hardware.inc ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

def CHRRAM0 EQU $8000  ; Sprite tiles 0-127; BG tiles 0-127 if BG_CHR01 on
def CHRRAM1 EQU $8800  ; Sprite and BG tiles 128-255
def CHRRAM2 EQU $9000  ; BG tiles 0-127 if BG_CHR01 off

;;
; Syntax: drgb $FF9966, $996633 for colors #FF9966 and #996633
; Divides each hex tuplet by 8 and rounds down. 
macro drgb
  REPT _NARG
    dw (\1 & $F80000) >> 19 | (\1 & $00F800) >> 6 | (\1 & $0000F8) << 7
    shift 1
  ENDR
endm

;;
; Syntax: ldxy rp, xpos, ypos[, mapbase]
; Sets a register pair to the address of (x, y) tile coordinates
; within a tilemap.
; @param rp a register pair (BC, DE, HL)
; @param x horizontal distance in tiles from left (0-31)
; @param y vertical distance in tiles from top (0-31)
; @param mapbase start address of 32-cell-wide tilemap:
;   SCRN_BG (default), _SCRN0, _SCRN1, or a virtual tilemap in WRAM.
macro ldxy
  if _NARG < 4
    ld \1, (\3) * SCRN_VX_B + (\2) + _SCRN0
  else
    ld \1, (\3) * SCRN_VX_B + (\2) + (\4)
  endc
endm

;;
; Syntax: dwxy xpos, ypos[, mapbase]
; Writes an X, Y position within a tilemap as a 16-bit address.
macro dwxy
  if _NARG < 3
    dw (\2) * SCRN_VX_B + (\1) + _SCRN0
  else
    dw (\2) * SCRN_VX_B + (\1) + (\3)
  endc
endm

;;
; Syntax: lb rp, hivalue, lovalue
; Loads hivalue into the upper register of a pair (B, D, or H)
; and lovalue into the lower register of the same pair (C, E, or L).
macro lb
  ld \1, low(\2) << 8 | low(\3)
endm

; cp144p ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

def LF equ $0A
def A_BUTTON_SYMBOL equ $1C
def B_BUTTON_SYMBOL equ $1C
def COPR_SYMBOL equ $1A
def RIGHT_ARROW equ $1C
def LEFT_ARROW equ $1D
def UP_ARROW equ $1E
def DOWN_ARROW equ $1F
def DPAD_SYMBOL equ $7F

endc
