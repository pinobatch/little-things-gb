include "src/hardware.inc"
include "src/global.inc"

section "main", ROM0
main::
  call show_title_screen

  ; Title screen is done, and from here on out we know we're on SGB.
  xor a
  ldh [hScrambleToUse], a
  .menu_loop:
    call show_scramble_menu
    ldh [hScrambleToUse], a
    jr .menu_loop
