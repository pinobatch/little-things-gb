;
; ROM header for Game Boy
; Copyright 2018 Damian Yerrick
; SPDX-License-Identifier: Zlib
; 
  IF  !DEF(GB_INC)
def GB_INC equ 1

; things left out of hardware.inc ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

def CHRRAM0 EQU $8000  ; Sprite tiles 0-127; BG tiles 0-127 if BG_CHR01 on
def CHRRAM1 EQU $8800  ; Sprite and BG tiles 128-255
def CHRRAM2 EQU $9000  ; BG tiles 0-127 if BG_CHR01 off

def P1F_NONE     EQU $30
def P1F_BUTTONS  EQU $10
def P1F_DPAD     EQU $20

;;
; Syntax: drgb $FF9966 for color #FF9966
; Divides each hex tuplet by 8 and rounds down. 
macro drgb
  dw (\1 & $F80000) >> 19 | (\1 & $00F800) >> 6 | (\1 & $0000F8) << 7
  endm

; global constants and the like ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Allowing different subroutines to share local variables in HRAM
; without having to declare all memory in one file requires an
; allocation strategy using ".rsset".
def hLocals equ $FF80
def locals_size equ 16

  ENDC
