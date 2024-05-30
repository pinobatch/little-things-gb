;
; borders used in TRN Stress
;
;
;
macro dborder
  dw (((\1) >> 2) & $0FFF) | (bank(\1) << 12)
endm

section "borderindex", ROM0
borders:
  dborder Tilly_border
  dborder Harmless_border
  dborder Scrapefoot_border
  dborder cocoa_border
  dborder she_bear_border
  dborder Harmless_border
  dborder Harmless_border
  dborder Harmless_border
  dborder Harmless_border
  dborder Harmless_border
  dborder Harmless_border
  dborder Harmless_border
  dborder Harmless_border
  dborder Harmless_border
  dborder Harmless_border
  dborder Harmless_border

;;
; Gets the address and bank of border A
; @param A border ID
; @return A: bank; HL: address
border_get_address::
  add a
  add low(borders + 1)
  ld l, a
  adc high(borders + 1)
  sub l
  ld h, a  ; HL points to high byte of entry in borders
  ld a, [hl-]
  ld l, [hl]
  ld h, a  ; HL points to packed pointer and bank number;
           ; A high nibble is bank num
  swap a
  and $0F  ; A is bank number
  add hl, hl
  add hl, hl  ; HL[13:0] points to offset in bank
  set 6, h
  res 7, h    ; Correct offset to be within ROMX
  ret

section "Tilly_border", ROMX, align[2]
Tilly_border:          incbin "obj/gb/Newell_Tilly.border"
section "Harmless_border", ROMX, align[2]
Harmless_border:       incbin "obj/gb/Pughe_Harmless.border"

; Scrapefoot and cocoa are our 2bpp borders
section "Scrapefoot_border", ROMX, align[2]
Scrapefoot_border:     incbin "obj/gb/Batten_Scrapefoot.border"
section "cocoa_border", ROMX, align[2]
cocoa_border:          incbin "obj/gb/Lowneys_cocoa.border"

section "she_bear_border", ROMX, align[2]
she_bear_border:          incbin "obj/gb/Caldecott_she-bear.border"
