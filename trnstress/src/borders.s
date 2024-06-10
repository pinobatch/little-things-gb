;
; borders used in TRN Stress
; Copyright 2024 Damian Yerrick
; SPDX-License-Identifier: Zlib
;
; See docs/image_credits.txt for individual images
;
include "src/global.inc"

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
she_bear_border:       incbin "obj/gb/Caldecott_she-bear.border"

; Credits depend on what borders are present

section "title_labels", ROM0

credits_labels::
  db  16,   8, "Program by Damian Yerrick", LF
  db  24,  16, "pineight.com", LF
  db  16,  24, "Fast 8-bit PRNG by foobles", LF
  db  16,  32, "Cubby character based on a", LF
  db  16,  40, "design by yoeynsf", LF
  db  24,  48, "instagram.com/yoeynsf", LF
  db  16,  56, "Other illustrations by", LF
  db  16,  64, "John D. Batten, Peter Newell,", LF
  db  16,  72, "Walter M. Lowney Co., J. S.", LF
  db  16,  80, "Pughe, Randolph Caldecott,", LF
  db  16,  88, "and [to be added]", LF
  db  16, 128, "B: Back   Start: Menu", 0

copr_notice_labels::
  db  89, 112, "v0.01   ", COPR_SYMBOL, " 2024", LF
  db  89, 120, "Damian Yerrick", LF
  db  89, 128, "Select: credits", 0
