include "src/hardware.inc"
include "src/global.inc"

section "risetime_results", HRAM

hRiseADown:    ds 1
hRiseANone:    ds 1
hRiseDownA:    ds 1
hRiseDownNone: ds 1

section "main", ROM0
main::
  ld hl, initial_regs_labels
  call cls_draw_labels
  ld hl, initial_reg_list
  call draw_regs

  ; Measure lag for A Button
  call lcd_on
  call wait_A_press
  call wait_vblank_irq
  lb bc, P1F_GET_BTN, P1F_GET_DPAD
  call measure_rise_time
  ldh [hRiseADown], a
  call lcd_off
  ld hl, second_press_prompt_labels
  call cls_draw_labels
  lb bc, P1F_GET_BTN, P1F_GET_NONE
  call measure_rise_time
  ldh [hRiseANone], a

  ; Measure lag for Down on the Control Pad
  call lcd_on
  ld c, PADF_DOWN
  call wait_c_press
  call wait_vblank_irq
  lb bc, P1F_GET_DPAD, P1F_GET_BTN
  call measure_rise_time
  ldh [hRiseDownA], a
  call lcd_off
  ld hl, rise_time_result_labels
  call cls_draw_labels
  lb bc, P1F_GET_DPAD, P1F_GET_NONE
  call measure_rise_time
  ldh [hRiseDownNone], a

  ; Display results
  ld hl, rise_time_reg_list
  call draw_regs
  call lcd_on
  call wait_A_press

  call lcd_off
  ld hl, todo_labels
  call cls_draw_labels
  call lcd_on
  
.forever:
  jr .forever


wait_A_press:
  ld c, PADF_A
;;
; Waits for a button press resulting in a particular state.
; @param C the desired state (union of PADF_* constants)
wait_c_press:
  push bc
  call wait_vblank_irq
  call read_pad
  pop bc
  ld a, [hNewKeys]
  or a
  jr z, wait_c_press
  ld a, [hCurKeys]
  xor c
  jr nz, wait_c_press
  ret

;;
; @param B which side to read (P1F_GET_BTN or P1F_GET_DPAD)
; @param C which side to release (P1F_GET_BTN, P1F_GET_DPAD, or P1F_GET_NONE)
measure_rise_time:
  push bc
  call .precharge_with_buttons
  ld [hl], c
  ld a, [hl]
  ld b, [hl]
  ld c, [hl]
  ld d, [hl]
  ld e, [hl]
  ld h, [hl]
  call .sum_presses_to_l
  pop bc
  push hl

  call .precharge_with_buttons
  ld [hl], c
  nop
  ld a, [hl]
  ld b, [hl]
  ld c, [hl]
  ld d, [hl]
  ld e, [hl]
  ld h, [hl]
  call .sum_presses_to_l
  ld a, P1F_GET_NONE
  ldh [rP1], a
  ld a, l
  pop hl
  add l
  ret

.precharge_with_buttons:
  ; Precharge data lines with held button
  ld hl, rP1
  ld [hl], b
  call .knownret
  ld a, [hl]
  call .knownret
  ret

.sum_presses_to_l:
  ; Count reads where low nibble was not $F
  call .inc_l_if_not_xF
  ld a, b
  call .inc_l_if_not_xF
  ld a, c
  call .inc_l_if_not_xF
  ld a, d
  call .inc_l_if_not_xF
  ld a, e
  call .inc_l_if_not_xF
  ld a, h
  call .inc_l_if_not_xF
  ret

.inc_l_if_not_xF:
  or $F0
  inc a
  ret z
  inc l
.knownret:
  ret
  



; Presentation ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
lcd_on:
  xor a
  ldh [rSCX], a
  ldh [rIF], a
  inc a
  assert IEF_VBLANK == 1
  ldh [rIE], a
  ld a, -4
  ldh [rWY], a
  ldh [rBGP], a
  ldh [rSCY], a
  ld a, LCDCF_ON|LCDCF_BLK21|LCDCF_BG9800|LCDCF_BGON
  ldh [rLCDC], a
  reti

draw_regs:
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

initial_regs_labels:
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
  
  dwxy 1, 9
  db "Press and hold the", 10
  dwxy 1, 10
  db "A Button to begin!", 0

second_press_prompt_labels:
  dwxy 2, 9
  db "Release A, then", 10
  dwxy 1, 10
  db "press Down on the",10
  dwxy 4, 11
  db "Control Pad.", 0

rise_time_result_labels:
  dwxy 1, 2
  db "Measured rise time", 10
  dwxy 0, 4
  db "A to Down:      # us", 10
  dwxy 0, 5
  db "A to none:      # us", 10
  dwxy 0, 6
  db "Down to A:      # us", 10
  dwxy 0, 7
  db "Down to none:   # us", 10
  dwxy 3, 12
  db "Now repeatedly", 10
  dwxy 1, 13
  db "press the A Button.", 0

todo_labels:
  dwxy 0, 0
  db "To do:", 10
  dwxy 0, 1
  db "1.measure P1 rise", 10
  dwxy 2, 2
  db "time by holding A", 10
  dwxy 0, 3
  db "2.measure time", 10
  dwxy 2, 4
  db "between repeated", 10
  dwxy 2, 5
  db "A presses and", 10
  dwxy 2, 6
  db "compare to nominal", 10
  dwxy 2, 7
  db "frame length", 10
  dwxy 0, 8
  db "3.measure time of", 10
  dwxy 2, 9
  db "first Start press", 0

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

rise_time_reg_list:
  db $8E,$01,low(hRiseADown)
  db $AE,$01,low(hRiseANone)
  db $CE,$01,low(hRiseDownA)
  db $EE,$01,low(hRiseDownNone)
  db $00
