;
; borders used in 32K build of TRN Stress
; Copyright 2024 Damian Yerrick
; SPDX-License-Identifier: Zlib
;
; See docs/image_credits.txt for individual images
;
include "src/global.inc"

section "borderindex", ROM0
borders:
  dw Harmless_border
  dw Harmless_border
  dw cocoa_border
  dw cocoa_border
  dw Harmless_border
  dw Harmless_border
  dw Harmless_border
  dw Harmless_border
  dw Harmless_border
  dw Harmless_border
  dw Harmless_border
  dw Harmless_border
  dw Harmless_border
  dw Harmless_border
  dw Harmless_border
  dw Harmless_border

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
  ld h, a  ; HL points to border
  xor a
  ret

Harmless_border:       incbin "obj/gb/Pughe_Harmless.border"
cocoa_border:          incbin "obj/gb/Lowneys_cocoa.border"

; Credits depend on what borders are present

section "title_labels", ROM0

credits_labels::
  db  16,   8, "Program by Damian Yerrick", LF
  db  24,  16, "pineight.com", LF
  db  16,  24, "Fast 8-bit PRNG by foobles", LF
  db  16,  40, "Cubby character based on a", LF
  db  16,  48, "design by yoeynsf", LF
  db  24,  56, "instagram.com/yoeynsf", LF
  db  16,  72, "Other illustrations by", LF
  db  16,  80, "Walter M. Lowney Co.", LF
  db  16,  88, "and J. S. Pughe", LF
  db  16, 128, "B: Back   Start: Menu", 0

copr_notice_labels::
  db 136, 104, "32K", LF
  db  89, 112, "v0.01   ", COPR_SYMBOL, " 2024", LF
  db  89, 120, "Damian Yerrick", LF
  db  89, 128, "Select: credits", 0
