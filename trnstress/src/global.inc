
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
; Syntax: drgb $FF9966 for color #FF9966
; Divides each hex tuplet by 8 and rounds down. 
macro drgb
  dw (\1 & $F80000) >> 19 | (\1 & $00F800) >> 6 | (\1 & $0000F8) << 7
endm

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

endc
