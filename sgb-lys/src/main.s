include "src/hardware.inc"
include "src/global.inc"

section "risetime_results", HRAM

hRiseADown:    ds 1
hRiseANone:    ds 1
hRiseDownA:    ds 1
hRiseDownNone: ds 1

def MAX_EARLY_PRESSES_TO_DRAW equ 7
def EARLY_PRESSES_TOP_Y equ 8
def EARLY_PRESSES_FRAMES equ 80
def PRESSES_TOP_Y equ 2

section "main", ROM0
main::

  ; Phase 1: Collect early presses of the Start Button for a second.
  ; This runs with timer, vblank, and joypad interrupts turned on.
  call set_interrupts_for_collect
  .collect_early_presses_loop:
    halt
    ldh a, [hPressRingBufferIndex]
    cp MAX_EARLY_PRESSES_TO_DRAW
    call c, collect_press
    ldh a, [hVblanks]
    cp EARLY_PRESSES_FRAMES
    jr c, .collect_early_presses_loop
  call end_interrupts_for_collect

  ; Now that we've provided ample time for Start Button test to run,
  ; detect the Super Game Boy
  call lcd_off
  call load_initial_font
  call detect_sgb

  ; Display initial registers and early press times
  ld hl, initial_regs_labels
  call cls_draw_labels
  ld hl, initial_reg_list
  call draw_regs

  ld hl, initial_no_presses_labels
  ldh a, [hPressRingBufferIndex]
  or a
  jr z, .no_early_presses
    cp MAX_EARLY_PRESSES_TO_DRAW
    jr c, .draw_early_presses_loop
      ld a, MAX_EARLY_PRESSES_TO_DRAW
    .draw_early_presses_loop:
      dec a
      push af
      ld b, a
      add EARLY_PRESSES_TOP_Y
      ld c, a
      call draw_press_b_to_row_c
      pop af
      or a
      jr nz, .draw_early_presses_loop
    ld hl, initial_presses_labels
  .no_early_presses:
  call draw_labels

  ; Measure rise time for A Button
  call read_pad  ; reject held A Button
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

  ; Measure rise time for Down on the Control Pad
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
  ld hl, mash_prompt_labels
  call cls_draw_labels
  call lcd_on
  call set_interrupts_for_collect

  .collect_presses_loop:
    halt
    call collect_press
    jr z, .collect_presses_loop

    ; If Select is pressed, and there are at least 4 presses
    ; (3 previous presses and the Select Button itself), calculate
    ldh a, [rP1]
    and PADF_SELECT
    jr nz, .not_select
      ldh a, [hPressRingBufferIndex]
      cp 4
      jr nc, .calculate_timing
    .not_select:

    ; Otherwise, discard outdated presses and draw the kept ones
    call discard_old_press
    ld b, 0
    .draw_presses_loop:
      ld a, b
      add PRESSES_TOP_Y
      ld c, a
      ldh a, [hPressRingBufferIndex]
      dec a  ; A = last press to draw
      sub b
      push bc
      jr c, .draw_presses_blank
        call draw_press_b_to_row_c
        jr .draw_presses_continue
      .draw_presses_blank:
        call draw_no_press_to_row_c
      .draw_presses_continue:
      pop bc
      inc b
      ld a, b
      cp PRESS_BUFFER_COUNT - 1
      jr c, .draw_presses_loop
    jr .collect_presses_loop

  .calculate_timing:
  call end_interrupts_for_collect

  ; Discard the Select press because it's probably late
  ld hl, hPressRingBufferIndex
  dec [hl]

  ; Collect delta times, calculate AGCDs, and sort them
  xor a
  ldh [rBGP], a
  call calculate_deltas
  call calculate_agcds
  call heapsort_agcds

  ; Use the median of these as the nominal frame length.
  ; Print the results
  call lcd_off

  ; TODO: Divide all deltas by median frame length and print them

  ld hl, todo_labels
  call cls_draw_labels
  call lcd_on

.forever:
  halt
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

; Collecting press times ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;
; Sets up vblank, timer, and joypad interrupts for 
set_interrupts_for_collect:
  ld a, TACF_65KHZ
  ldh [rTAC], a
  ldh [rTMA], a
  ldh [rTIMA], a
  ld a, TACF_65KHZ|TACF_START
  ldh [rTAC], a
  ld a, P1F_GET_BTN
  ldh [rP1], a
  xor a
  ldh [rIF], a
  ld a, IEF_VBLANK|IEF_TIMER|IEF_HILO
  ldh [rIE], a
  reti

end_interrupts_for_collect:
  ld a, IEF_VBLANK|IEF_TIMER
  ldh [rIE], a
  ld a, P1F_GET_NONE
  ldh [rP1], a
  ret

;;
; Collect a press
; @return ZF false if a press occurred
collect_press::
  ld a, [hPressOccurred]
  or a
  ret z

  ; Get a pointer to this press
.try_reread:
  ldh a, [hPressRingBufferIndex]
  cp PRESS_BUFFER_COUNT
  jr c, .no_wrap
    xor a
  .no_wrap:
  ld [hPressRingBufferIndex], a
  rept LOG_SIZEOF_PRESS_BUFFER_ENTRY
    add a
  endr
  add low(wPresses)
  ld l, a
  adc high(wPresses)
  sub l
  ld h, a
  xor a
  ldh [hPressOccurred], a
  ldh a, [hPressTimeLo]
  ld [hl+], a
  ldh a, [hPressTimeMid]
  ld [hl+], a
  ldh a, [hPressTimeHi]
  ld [hl], a
  ; If another press occurred within the same 100 or so cycles
  ; due to switch bounce, the read bytes might be inconsistent.
  ; Discard this press and reread until it settles.
  ldh a, [hPressOccurred]
  or a
  jr nz, .try_reread

  ld hl, hPressRingBufferIndex
  inc [hl]
  ret

;;
; If the last 2 presses are more than a second apart, discard all but
; the last.  If there are more than N-1 presses, discard the oldest.
discard_old_press:
  ldh a, [hPressRingBufferIndex]
  sub 2  ; Previous press index A; current press index A+1
  ret c  ; Do nothing if only 1 press in buffer

  rept LOG_SIZEOF_PRESS_BUFFER_ENTRY
    add a
  endr
  add low(wPresses)
  ld e, a
  adc high(wPresses)
  sub e
  ld d, a
  ld hl, SIZEOF_PRESS_BUFFER_ENTRY
  add hl, de  ; DE: previous press; HL: latest press
  ld a, [de]
  ld b, a
  ld a, [hl+]
  sub b
  inc de
  ld a, [de]
  ld b, a
  ld a, [hl+]
  sbc b
  inc de
  ld a, [de]
  ld b, a
  ld a, [hl]
  sbc b
  jr z, .diff_less_than_1s
    ; It's been more than a second.  Move this press to the start
    ; of the buffer.
    ld a, [hl-]
    ld [wPresses+2], a
    ld a, [hl-]
    ld [wPresses+1], a
    ld a, [hl]
    ld [wPresses+0], a
    ld a, 1
    ldh [hPressRingBufferIndex], a
    ret
  .diff_less_than_1s:

  ; If full, drop the oldest press
  ldh a, [hPressRingBufferIndex]
  cp PRESS_BUFFER_COUNT
  ret c
  dec a
  ldh [hPressRingBufferIndex], a
  ld hl, wPresses + SIZEOF_PRESS_BUFFER_ENTRY
  ld de, wPresses
  ld bc, SIZEOF_PRESS_BUFFER_ENTRY * (PRESS_BUFFER_COUNT - 1)
  jp memcpy

; Measuring rise time ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;
; @param B which side to read (P1F_GET_BTN or P1F_GET_DPAD)
; @param C which side to release (P1F_GET_BTN, P1F_GET_DPAD, or P1F_GET_NONE)
measure_rise_time:
  ; Measure once even
  push bc
  call .precharge_P1_with_B
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

  ; Measure once odd
  call .precharge_P1_with_B
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

.precharge_P1_with_B:
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
  ; fall through
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

;;
; Draws row B of the press buffer to row C (0-15) of the screen
draw_press_b_to_row_c:
  ld a, b
  rept LOG_SIZEOF_PRESS_BUFFER_ENTRY
    add a
  endr
  add 2  ; point at high byte
  add low(wPresses)
  ld l, a
  adc high(wPresses)
  sub l
  ld h, a
  ; fall through

;;
; Draws 24-bit number at [HL] to row C (0-15) of the screen
; 01234567890123456789
;     hhhhhhdddddddd
draw_24bit_to_row_c:
  ; calculate destination address in VRAM
  call seek_vram_row_c

  ld a, [hl-]
  call hblank_put_a
  ld a, [hl-]
  call hblank_put_a
  ld a, [hl]
  call hblank_put_a
  push de
  call bcd24bit
  ld h, d
  ld l, e
  pop de  ; retrieve address
  push hl  ; save low 4 digits of binary to decimal result

  ; Print digits
  ld l, " "  ; L becomes "0" after printing a nonzero digit 
  ld a, b
  ld h, c
  call .pr2dig
  ld a, h
  call .pr2dig
  pop bc
  ld a, b
  ld h, c
  call .pr2dig
  ; force the last digit to be 0
  ld a, h
  swap a
  and $0F
  or l
  ld b, a
  ld a, h
  and $0F
  or "0"
  ld c, a
  jr hblank_put_bc

.pr2dig:
  ld c, a
  swap a
  and $0F
  jr z, .pr2dig_hi_zero
    ld l, "0"
  .pr2dig_hi_zero:
  or l
  ld b, a
  ld a, c
  and $0F
  jr z, .pr2dig_lo_zero
    ld l, "0"
  .pr2dig_lo_zero:
  or l
  ld c, a
  jr hblank_put_bc

;;
; Waits for mode 0 or 1, then writes nibbles of A to [DE]
; @return DE incremented by 2, B high nibble, C low nibble
hblank_put_a::
  ld c, a
  swap a
  and $0F
  ld b, a
  ld a, c
  and $0F
  or $10
  ld c, a
  ; fallthrough

;;
; Waits for mode 0 or 1, then writes characters B and C to [DE]
; @return DE incremented by 2, BCHL unchanged
hblank_put_bc::
  di
  .safewait:
    ldh a, [rSTAT]
    bit 1, a
    jr nz, .safewait
  ld a, b
  ld [de], a
  inc e
  ld a, c
  ld [de], a
  ei
  inc e
  ret

seek_vram_row_c:
  ld a, c
  add a
  add a
  add a
  inc a  ; indent by 4
  ld e, a
  ld d, _SCRN0>>10
  add a
  rl d
  add a
  rl d
  ld e, a
  ret

draw_no_press_to_row_c:
  call seek_vram_row_c
  lb bc, " ", " "
  ld l, 7
  .loop:
    call hblank_put_bc
    dec l
    jr nz, .loop
  ret


section "labels", ROM0

initial_regs_labels:
  dwxy 2, 0
  db "SGB Key IRQ Test",10
  dwxy 0, 1
  db $7F,"2024 Damian Yerrick",10
  dwxy 0, 3
  db "SGB    AFNNNN SP",10
  dwxy 0, 4
  db "BCNNNN DENNNN HL",10
  dwxy 0, 5
  db "LY     DIV NN NR52NN",10
  dwxy 1, 15
  db "Press and hold the", 10
  dwxy 1, 16
  db "A Button to begin!", 0

initial_reg_list:
  db $69,low(hInitialA)
  db $6B,low(hInitialF)
  db $70,low(hInitialSP+1)
  db $72,low(hInitialSP)
  db $82,low(hInitialB)
  db $84,low(hInitialC)
  db $89,low(hInitialD)
  db $8B,low(hInitialE)
  db $90,low(hInitialH)
  db $92,low(hInitialL)
  db $A2,$01,low(hInitialLY)
  db $AB,low(hInitialDIV)
  db $B2,low(hInitialNR52)
  db $62,$01,low(hCapability)
  db $00

initial_no_presses_labels:
  dwxy 0, 7
  db "TIP: To see early",10
  dwxy 0, 8
  db "press times, enable",10
  dwxy 0, 9
  db "slow motion or mash",10
  dwxy 0, 10
  db "the Start Button as",10
  dwxy 0, 11
  db "this tool loads.",0

initial_presses_labels:
  dwxy 0, 7
  db "Early press times:",0

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
  dwxy 1, 4
  db "A to Down:    # us", 10
  dwxy 1, 5
  db "A to none:    # us", 10
  dwxy 1, 6
  db "Down to A:    # us", 10
  dwxy 1, 7
  db "Down to none: # us", 10
  dwxy 3, 12
  db "Now repeatedly", 10
  dwxy 1, 13
  db "press the A Button.", 0

rise_time_reg_list:
  db $8D,$01,low(hRiseADown)
  db $AD,$01,low(hRiseANone)
  db $CD,$01,low(hRiseDownA)
  db $ED,$01,low(hRiseDownNone)
  db $00

mash_prompt_labels:
  dwxy 3, 0
  db "Keep mashing A!", 10
  dwxy 2, 10
  db "Select:calculate", 0

todo_labels:
  dwxy 0, 0
  db "Median period:",10
  dwxy 0, 1
  db "Quartiles:    0-",10
  dwxy 3, 3
  db "Delta   Frame",10
  dwxy 7, 4
  db "0    0.00",10
  dwxy 0, 9
  db "To do:", 10
  dwxy 0, 11
  db "1.display time", 10
  dwxy 2, 12
  db "between repeated", 10
  dwxy 2, 13
  db "button presses", 10
  dwxy 2, 14
  db "and compare to", 10
  dwxy 2, 15
  db "nominal video", 10
  dwxy 2, 16
  db "frame length", 0
