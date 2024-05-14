include "src/hardware.inc"
include "src/global.inc"

section "main", ROM0
main::
  call sgb_wait
  call sgb_wait
  call sgb_wait
  call sgb_wait
  call detect_sgb
  calls vwfPuts
  calls pb16_unpack_block
  jr main

