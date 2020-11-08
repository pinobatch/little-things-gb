.ifndef GB_INC
GB_INC = 1

; things left out of hardware.inc ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

CHRRAM0 = $8000  ; Sprite tiles 0-127; BG tiles 0-127 if BG_CHR01 on
CHRRAM1 = $8800  ; Sprite and BG tiles 128-255
CHRRAM2 = $9000  ; BG tiles 0-127 if BG_CHR01 off

P1F_NONE     = $30
P1F_BUTTONS  = $10
P1F_DPAD     = $20

SGB_NONE = $00
SGB_SUPPORT = $03
REGION_J = $00
REGION_UE = $01

;;
; Syntax: drgb $FF9966 for color #FF9966
; Divides each hex tuplet by 8 and rounds down. 
.macro drgb colorvalue
  .word (colorvalue & $F80000) >> 19 | (colorvalue & $00F800) >> 6 | (colorvalue & $0000F8) << 7
.endmacro

; global constants and the like ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Allowing different subroutines to share local variables in HRAM
; without having to declare all memory in one file requires an
; allocation strategy using ".rsset".
.global hLocals
locals_size = 16
SCRN_TMP = $9800+640

; ca65 doesn't autoimport by default, and I don't remember any syntax
; analogous to PAAMAYIM_NEKUDOTAYIM to both define and export a label
.global GB_busy_wait_vblank, GB_load_nam
.global GB_unpack_iu_file, GB_pb16_unpack_block

.endif

