include "src/hardware.inc"
include "src/global.inc"

section "main", ROM0
main::
  ld a, bank(show_title_screen)
  ld [rROMB0], a
  call show_title_screen
  xor a
  ldh [hCursorY], a

  ; Title screen is done, and from here on out we know we're on SGB.
  .menu_loop:
    ; Select a border and scramble to use with it
    xor a
    ldh [hScrambleToUse], a
    ld a, bank(show_scramble_menu)
    ld [rROMB0], a
    call show_scramble_menu

    cp NUM_SCRAMBLES
    jr c, .is_scramble
      call run_frame_timing
      jr .menu_loop
    .is_scramble:

    ; Load this border with this scramble
    ldh [hScrambleToUse], a
    call border_get_address
    ld [rROMB0], a
    call sgb_send_border

    ; Show a blank screen behind the border until a key is pressed
    xor a
    ldh [rBGP], a
    ld a, LCDCF_ON
    ldh [rLCDC], a
    call sgb_unfreeze
    .waitloop:
      call wait_vblank_irq
      call read_pad
      ldh a, [hNewKeys]
      or a
      jr z, .waitloop

    jr .menu_loop
