;;
; Binary to decimal conversion and other calculations related to
; displaying numbers

def WITH_DIV_TEST equ 0

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
; Converts a 24-bit binary value to decimal in about 380 cycles.
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

section "div24by16", ROM0

;;
; Produces a digit of the decimal expansion of proper fraction HL/DE
; by intertwining multiplication by 10 and division by DE.
; Two calls yield a percentage.
; @param HL numerator; must be less than DE
; @param DE denominator
; @return A quotient of of division 10*HL/DE; HL: remainder
pctdigit16::
  ; BCA = HL0 * 0.25
  ld b, h
  ld c, l
  xor a
  sra b
  rr c
  rra
  sra b
  rr c
  rra
  ; HL = HL * 25
  add hl, bc
  ld c, a  ; A is decimal portion of multiplication by HL
  ld b, $1F  ; collects 4 output bits: this and 3 doublings
  jr div24by16.already_doubled

;;
; Divides HLC by DE
; produced correct results with 234567/23456 and 234567/2345
; @param HLC numerator, where HL < DE
; @param DE denominator
; @return A: quotient; HL: remainder; DE unchanged
div24by16::
  ld b, $01  ; collects 8 output bits; when CF set, loop is over
  .bitloop:
    sla c
    rl l
    rl h
  .already_doubled:
    jr c, .yes_greater
    ld a, l
    sub e
    ld a, h
    sbc d
    jr c, .not_greater
    .yes_greater:
      ld a, l
      sub e
      ld l, a
      ld a, h
      sbc d
      ld h, a
      or a  ; clear CF
    .not_greater:
    rl b
    jr nc, .bitloop
  ld a, b
  cpl
  ret

if WITH_DIV_TEST
div_test::
  ld hl, 234567 >> 8
  ld c, low(234567)
  ld de, 2345
  call div24by16  ; expect 100 remainder 67

  ld hl, 23456 >> 8
  ld c, low(23456)
  ld de, 2345
  call div24by16  ; expect 10 remainder 6

  ld hl, 234567 >> 8
  ld c, low(234567)
  ld de, 23456
  call div24by16  ; expect 10 remainder 7

  ld hl, 2323
  ld de, 3366
  call pctdigit16  ; expect 6 remainder 3034
  call pctdigit16  ; expect 9 remainder 46
  ret
endc
