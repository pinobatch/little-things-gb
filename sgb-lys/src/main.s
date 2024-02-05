include "src/hardware.inc"
include "src/global.inc"

section "main", ROM0
main::
  ld hl, main_labels
  call cls_draw_labels
  call draw_regs
  xor a
  ldh [rSCX], a
  ld a, -4
  ldh [rWY], a
  ldh [rBGP], a
  ldh [rSCY], a
  ld a, LCDCF_ON|LCDCF_BLK21|LCDCF_BG9800|LCDCF_BGON
  ldh [rLCDC], a
.forever:
  jr .forever

draw_regs:
  ld hl, initial_reg_list
  ld d, high(_SCRN0)
  .loop:
    ld a, [hl+]
    or a
    ret z
    ld e, a
    ld a, [hl+]
    cp $80
    jr c, .not_hex
      ld c, a
      ldh a, [c]
      swap a
      and $0F
      ld [de], a
      inc e
      ldh a, [c]
      and $0F
      or $10
      ld [de], a
      jr .loop
    .not_hex:
    cp 1
    jr nz, .not_decimal
      ld a, [hl+]
      ld c, a
      ld a, [c]
      call bcd8bit_baa
      ld c, a
      ld a, b
      and $03
      jr z, .no_hundreds
        or "0"
        ld [de], a
        inc e
        ld a, c
        jr .yes_tens
      .no_hundreds:
      inc e
      ld a, c
      cp $10
      jr c, .no_tens
      .yes_tens:
        ld b, a
        swap a
        and $0F
        or "0"
        ld [de], a
        ld a, b
      .no_tens:
      inc e
      and $0F
      or "0"
      ld [de], a
      jr .loop
    .not_decimal:
    ld b, b
    ret

main_labels:
  dwxy 2, 0
  db "SGB Key IRQ Test",10
  dwxy 0, 1
  db $7F,"2024 Damian Yerrick",10
  dwxy 1, 3
  db "Initial registers",10
  dwxy 0, 4
  db "A F B C D E H L  SP",10
  dwxy 0, 6
  db "LY  DIV NR52 MLT",10
  
  dwxy 0, 9
  db "To do:", 10
  dwxy 0, 10
  db "1.measure P1 rise", 10
  dwxy 2, 11
  db "time by holding A", 10
  dwxy 0, 12
  db "2.measure time", 10
  dwxy 2, 13
  db "between repeated", 10
  dwxy 2, 14
  db "A presses and", 10
  dwxy 2, 15
  db "compare to nominal", 10
  dwxy 2, 16
  db "frame length", 0


initial_reg_list:
  db $A0,low(hInitialA)
  db $A2,low(hInitialF)
  db $A4,low(hInitialB)
  db $A6,low(hInitialC)
  db $A8,low(hInitialD)
  db $AA,low(hInitialE)
  db $AC,low(hInitialH)
  db $AE,low(hInitialL)
  db $B0,low(hInitialSP+1)
  db $B2,low(hInitialSP)
  db $E5,low(hInitialDIV)
  db $E9,low(hInitialNR52)
  db $E0,$01,low(hInitialLY)
  db $EC,$01,low(hCapability)
  db $00
