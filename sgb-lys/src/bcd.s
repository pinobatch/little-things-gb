section "bcd8bit", ROM0
;;
; Converts an 8-bit value to 3 binary-coded decimal digits.
; @param A the value
; @return A: tens and ones digits; B[1:0]: hundreds digit;
; B[7:2]: unspecified
bcd8bit_baa::
  swap a
  ld b,a
  and $0F  ; bits 3-0 in A, range $00-$0F
  or a     ; for some odd reason, AND sets half carry to 1
  daa      ; A=$00-$15

  sla b
  adc a
  daa
  sla b
  adc a
  daa      ; A=$00-$63
  rl b
  adc a
  daa
  rl b
  adc a
  daa
  rl b
  ret

section "bcd24bit", ROM0
;;
; Converts a 24-bit binary value to decimal.
; @param HL pointer to a little-endian value
; @return BCDE value in BCD, A=B, L=0, H unchanged
bcd24bit::
  inc hl
  inc hl
  ld a, [hl-]
  ld b, a
  xor a

  scf
  rl b  ; plant a sentinel bit at the end of B

  ; Get up to 255, output in DA
  .byte2:
    adc a
    daa
    rl d
    sla b  ; once the sentinel bit reaches carry, this byte is over
    jr nz, .byte2

  ; carry flag is set from previous sentinel bit
  ld e, a
  ld a, [hl-]
  rla  ; plant sentinel for middle input
  ld b, a

  ; Get up to 65535, output in CDE
  .byte1:
    ld a, e
    adc a
    daa
    ld e, a
    ld a, d
    adc a
    daa
    ld d, a
    rl c
    sla b
    jr nz, .byte1

  ld b, [hl]
  ld l, 8
  or a

  ; Get up to A777215, output in BCDE
  .byte0:
    rl b
    ld a, e
    adc a
    daa
    ld e, a
    ld a, d
    adc a
    daa
    ld d, a
    ld a, c
    adc a
    daa
    ld c, a
    dec l
    jr nz, .byte0

  ; convert to 16777215
  ld a, b
  adc a
  daa
  ld b, a
  ret
