include "src/hardware.inc"
include "src/global.inc"

section "main", ROM0
main::
  call load_title_screen
  ld a, LCDCF_BGON|LCDCF_BG9800|LCDCF_BLK21|LCDCF_ON
  ldh [rLCDC], a

  call sgb_wait
  call sgb_wait
  call sgb_wait
  call sgb_wait
  call detect_sgb
  ei
  ldh a, [hCapability]
  rra
  jr nc, .skip_load_border
    call sgb_freeze
    call lcd_off
    ld hl, sgb_title_palette
    call sgb_send
    ld hl, title_border
    call sgb_send_border

    call load_title_screen
    ld a, LCDCF_BGON|LCDCF_BG9800|LCDCF_BLK21|LCDCF_ON
    ldh [rLCDC], a
    call sgb_unfreeze
  .skip_load_border:

  ; Title screen
  lb bc, 88, 16
  .no_sgb_slidein_loop:
    push bc
    xor a
    ld [oam_used], a
    ldh a, [hCapability]
    rra
    ld de, title_press_start_labels
    jr c, .use_sgb_title_labels
      ld de, requires_sgb_labels
    .use_sgb_title_labels:
    call draw_title_labels
    call lcd_clear_oam
    rst wait_vblank_run_dma
    ld a, LCDCF_BGON|LCDCF_BG9800|LCDCF_BLK21|LCDCF_OBJON|LCDCF_OBJ16|LCDCF_ON
    ldh [rLCDC], a
    call read_pad
    pop bc
    ld a, b
    sub 2
    cp 8
    jr c, .title_slide_complete
      ld b, a
    .title_slide_complete:
    ldh a, [hNewKeys]
    and PADF_SELECT
    jr z, .not_credits
      call show_credits
      call load_title_screen
      ld a, LCDCF_BGON|LCDCF_BG9800|LCDCF_BLK21|LCDCF_ON
      ldh [rLCDC], a
      lb bc, 8, 16
    .not_credits:
    ldh a, [hCapability]
    rra
    jr nc, .no_sgb_slidein_loop
    ldh a, [hNewKeys]
    and PADF_START
    jr z, .no_sgb_slidein_loop

  ; Title screen is done, and from here on out we know we're on SGB.
  call sgb_freeze
  call lcd_off
  ld hl, sgb_title_palette
  call sgb_send
  ld hl, menu_border
  call sgb_send_border

  ; 1. Clear tiles and tilemap
  ld de, $8800
  ld h, e
  ld bc, $1B00
  call memset
  ld a, %11111100
  ldh [rBGP], a

  ; 4. Draw small text
  ld de, $8800 >> 4
  ld hl, main_menu_labels
  call vwfDrawLabels

  ld a, LCDCF_BGON|LCDCF_BG9800|LCDCF_BLK21|LCDCF_ON
  ldh [rLCDC], a
  call sgb_unfreeze
  .loop:
    call wait_vblank_irq
    call read_pad
    ldh a, [hNewKeys]
    and 0
    jr z, .loop
  




section "load_title_screen", ROM0
load_title_screen:
  call lcd_off

  ; 1. Load the background tilemap
  ld h, $D0
  call clear_scrn0_to_h
  lb bc, 14, 18
  ldxy de, 0, 0
  ld hl, title_cubby_nam
  call load_nam

  ; 2. Load the background tiles
  ld de, title_cubby_pb16
  ld hl, $8D00
  ld b, $180 - $D0
  call pb16_unpack_block

  ; 3. Load object tiles
  ld de, title_letters_pb16
  ld hl, $8000
  ld b, 40
  call pb16_unpack_block

  ; 4. Draw small text
  ld de, $8BC0 >> 4
  ld hl, copr_notice_labels
  call vwfDrawLabels

  ; 5. Set registers other than LCDC
  ld a, %10001101
  ldh [rBGP], a
  ld a, %11010000
  ldh [rOBP0], a
  xor a
  ldh [rSCX], a
  ldh [rSCY], a
  ldh [rIF], a
  inc a
  ldh [rIE], a
  ret

;;
; title encoding:
; (X offset, Y offset, letters, $FF)*, $FF
; each letter is DTTTTTTN, where N moves left 4 and D draws 2 tiles
; @param B horizontal offset
; @param C vertical offset
; @param DE pointer to title encoded labels
draw_title_labels:
  ld a, [de]
  cp $FF  ; X=$FF terminates
  ret z
  push bc  ; B = left, C = top
  add b
  ld b, a
  inc de
  ld a, [de]
  add c
  ld c, a
  ld hl, oam_used
  ld l, [hl]  ; seek to next available object
  .charloop:
    inc de
    ld a, [de]
    cp $FE
    jr z, .is_space
    jr nc, .is_end_of_line

    ; Draw left half of glyph
    rra
    jr nc, .no_back_4
      ld a, b
      sub 4
      ld b, a
    .no_back_4:
    ld a, c
    ld [hl+], a
    ld a, b
    ld [hl+], a
    add 8
    ld b, a
    ld a, [de]
    and %01111110
    ld [hl+], a
    xor a
    ld [hl+], a

    ; Draw right half of glyph if needed
    ld a, [de]
    add a
    jr nc, .charloop
    ld a, c
    ld [hl+], a
    ld a, b
    ld [hl+], a
    add 8
    ld b, a
    ld a, [de]
    and %01111110
    add 2
    ld [hl+], a
    xor a
    ld [hl+], a
    jr .charloop
  .is_space:
    ld a, b
    add 4
    ld b, a
    jr .charloop
  .is_end_of_line:
  pop bc  ; restore original offset
  ld a, l
  ld [oam_used], a
  inc de
  jr draw_title_labels

show_credits:
  call lcd_off

  ; 1. Clear tiles and tilemap
  ld de, $8800
  ld h, e
  ld bc, $1B00
  call memset
  ld a, %11111100
  ldh [rBGP], a

  ; 4. Draw small text
  ld de, $8800 >> 4
  ld hl, credits_labels
  call vwfDrawLabels

  ld a, LCDCF_BGON|LCDCF_BG9800|LCDCF_BLK21|LCDCF_ON
  ldh [rLCDC], a
  .loop:
    call wait_vblank_irq
    call read_pad
    ldh a, [hNewKeys]
    and PADF_B|PADF_SELECT|PADF_START
    jr z, .loop
  ret

section "title_screen_data", ROM0
title_cubby_nam:    incbin "obj/gb/title_cubby.nam"
title_cubby_pb16:   incbin "obj/gb/title_cubby.2b.pb16"
title_letters_pb16: incbin "obj/gb/title_letters.2b.pb16"
title_border: incbin  "obj/gb/title.border"

def COPR_SYMBOL = $1A
def LF = $0A
copr_notice_labels:
  db 96, 112, COPR_SYMBOL, " 2024", LF
  db 96, 120, "Damian Yerrick", LF
  db 96, 128, "Select: credits", 0

sgb_title_palette:
  db $00<<3|1
  drgb $FFFFFF, $EF9A49, $9F4A00, $000000
  drgb          $AAAAAA, $555555, $000000
  db $00

; Title letters texts
newcharmap title_labels
  charmap "B",$00
  charmap "G",$02
  charmap "N",$04
  charmap "P",$06
  charmap "R",$08
  charmap "S",$0A
  charmap "T",$0C
  charmap "a",$0E
  charmap "e",$10
  charmap "i",$13
  charmap "m",$95
  charmap "o",$18
  charmap "p",$1A
  charmap "q",$1C
  charmap "r",$1E
  charmap "s",$20
  charmap "t",$22
  charmap "u",$24
  charmap "y",$26
  charmap " ",$FE

requires_sgb_labels:
  db 80, 16, "TRN Stress", $FF
  db 96, 48, "Requires", $FF
  db 116, 64, "Super", $FF
  db 92, 80, "Game Boy", $FF
  db $FF

title_press_start_labels:
  db 72, 88, "Press Start", $FF
  db $FF
setcharmap main

credits_labels:
  db   8,   8, "Credits", LF
  db   8,  16, "More credits!", LF
  db   8,  24, "More credits!", LF
  db   8, 128, "B: Back   Start: Menu", 0


section "main_menu_data", ROM0

main_menu_labels:
  db   8,   8, "Main menu", LF
  db   8,  16, "More menu!", LF
  db   8,  24, "More menu!", LF
  db   8, 128, "Under construction", 0

menu_border: incbin  "obj/gb/menu.border"
