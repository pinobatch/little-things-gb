include "src/hardware.inc"
include "src/global.inc"

def MENU_ITEM_XPOS equ 67
def MENU_ITEM_YPOS equ 8
def vMenuLabelsScratch equ $9A40
def MENU_CUBBY_WIDTH equ 7
def MENU_CUBBY_HEIGHT equ 12
def MENU_CUBBY_X equ 0
def MENU_CUBBY_Y equ 3
def MENU_CUBBY_TILES equ 70
def MENU_DIGITS_TILE_BASE equ $80 - 12
; use a scramble when loading the "Test Cards" border
def MENU_SCRAMBLE_TO_TEST equ 0
def MENU_RASTER_TO_TEST equ 0
def MENU_CURSOR_XPOS equ 44
def MENU_CURSOR_TILE equ $00
def LF equ $0A

section "hCursorY", HRAM
hCursorY:: ds 1

section "main_menu", ROMX,BANK[1]
show_scramble_menu::
  call sgb_freeze
  if MENU_SCRAMBLE_TO_TEST
    ld a, MENU_SCRAMBLE_TO_TEST
    ldh [hScrambleToUse], a
  endc
  ld hl, menu_border
  call sgb_send_border

  xor a
  ld h, a
  ld l, a
  call setup_raster  ; cancel raster from last border

  ; 1. Clear tiles and tilemap
  ld de, $8000
  ld h, e
  ld bc, $1800
  call memset
  ld b, high($300)
  ld h, $7F
  call memset
  ld a, %01101100
  ldh [rBGP], a

  ; 2. Load smaller Cubby
  ld de, menu_cubby_pb16
  ld hl, $8800
  ld b, MENU_CUBBY_TILES
  call pb16_unpack_block
  ld hl, menu_cubby_nam
  ldxy de, MENU_CUBBY_X, MENU_CUBBY_Y
  lb bc, MENU_CUBBY_WIDTH, MENU_CUBBY_HEIGHT
  call load_nam

  ; 3. Draw numeric labels 1-10
  ld de, ($9000 >> 4) + MENU_DIGITS_TILE_BASE
  ld hl, menu_digit_labels
  call vwfDrawLabels
  ; and 11-16
  ldxy hl, (MENU_ITEM_XPOS / 8) - 1, (MENU_ITEM_YPOS) / 8 + 10
  ld de, 33
  ld a, MENU_DIGITS_TILE_BASE + 2
  .numlabels_loop:
    ld [hl-], a
    ld [hl], MENU_DIGITS_TILE_BASE
    add hl, de
    inc a
    cp MENU_DIGITS_TILE_BASE + 2 + (NUM_SCRAMBLES - 10)
    jr c, .numlabels_loop

  ; 4. Draw scramble names at (115, 8i+1)
  lb bc, 15, $80
  ld de, vMenuLabelsScratch
  .scramble_name_rowloop:
    ld a, MENU_ITEM_XPOS
    ld [de], a
    inc de
    ld a, b
    add a
    add a
    add a
    add MENU_ITEM_YPOS
    ld [de], a
    inc de
    ; coincidentally, each element of scrambles has as many bytes
    ; as a tile has scanlines
    sub MENU_ITEM_YPOS  ; A = offset into scrambles
    add low(scrambles)
    ld l, a
    adc high(scrambles)
    sub l
    ld h, a  ; HL = &scrambles[b].name
    ld a, [hl+]
    ld h, [hl]
    ld l, a  ; HL = scrambles[b].name
    call stpcpy  ; append the label
    ld a, LF
    ld [de], a
    inc de
    dec b
    bit 7, b
    jr z, .scramble_name_rowloop

  ; terminate the list of labels with a NUL and do various
  ; other work with A=0
  dec de
  xor a
  ld [de], a
  ldh [rSCX], a
  ldh [rSCY], a
  ld hl, SOAM
  ld c, 160 
  rst memset_tiny

  ; draw the labels
  ld de, ($8800 >> 4) + MENU_CUBBY_TILES
  ld hl, vMenuLabelsScratch
  call vwfDrawLabels
  ld b, 0
  call draw_arrow_cursor

  ; 5. Load object tiles
  call run_dma
  ld a, %11010000
  ldh [rOBP0], a
  ld hl, menu_arrow_tile
  ld de, $8000 + MENU_CURSOR_TILE * 16
  ld bc, 16
  call memcpy

  ld a, LCDCF_BGON|LCDCF_BG9800|LCDCF_BLK21|LCDCF_OBJON|LCDCF_ON
  ldh [rLCDC], a
  call sgb_unfreeze
  .loop:
    call read_pad
    ld b, PADF_UP|PADF_DOWN
    call autorepeat
    ldh a, [hNewKeys]
    ld b, a
    ldh a, [hCursorY]
    bit PADB_DOWN, b
    jr z, .not_down
      inc a
    .not_down:
    bit PADB_UP, b
    jr z, .not_up
      dec a
    .not_up:
    cp NUM_SCRAMBLES
    jr nc, .no_writeback
      ldh [hCursorY], a
    .no_writeback:
    ld b, 0
    call draw_arrow_cursor
    rst wait_vblank_run_dma
    if MENU_RASTER_TO_TEST
      ld a, MENU_RASTER_TO_TEST
      ldh [hScrambleToUse], a
      call setup_raster_for_scramble
    endc
    ld a, IEF_VBLANK|IEF_STAT
    ldh [rIE], a
    ldh a, [hNewKeys]
    and PADF_A|PADF_START
    jr z, .loop

  ; move the arrow forward
  ld b, 0
  .move_arrow_loop:
    push bc
    call draw_arrow_cursor
    rst wait_vblank_run_dma
    pop bc
    ld a, b
    add 4
    ld b, a
    add a
    jr nc, .move_arrow_loop

  ldh a, [hCursorY]
  ret

draw_arrow_cursor:
  ld hl, SOAM
  ldh a, [hCursorY]
  add a
  add a
  add a
  add MENU_ITEM_YPOS + 16
  ld [hl+], a
  ld a, MENU_CURSOR_XPOS + 8
  add b
  ld [hl+], a
  ld a, MENU_CURSOR_TILE
  ld [hl+], a
  xor a
  ld [hl+], a
  ret

menu_digit_labels:
  db  52,  80, "10.", LF
  db  57,   8, "1.", LF
  db  57,  16, "2.", LF
  db  57,  24, "3.", LF
  db  57,  32, "4.", LF
  db  57,  40, "5.", LF
  db  57,  48, "6.", LF
  db  57,  56, "7.", LF
  db  57,  64, "8.", LF
  db  57,  72, "9.", 0

menu_border: incbin  "obj/gb/menu.border"
menu_cubby_nam:    incbin "obj/gb/menu_cubby.nam"
menu_cubby_pb16:   incbin "obj/gb/menu_cubby.2b.pb16"
menu_arrow_tile:
  dw `00000000
  dw `11110000
  dw `13311100
  dw `13333111
  dw `13333331
  dw `13333111
  dw `13311100
  dw `11110000
