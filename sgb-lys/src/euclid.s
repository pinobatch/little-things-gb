def AGCD_EPSILON = 512
def WITH_AGCD_TEST equ 0
section "approximate_gcd", ROM0

if WITH_AGCD_TEST
  ld de, 2240
  ld hl, 5537
  jr approximate_gcd
endc

approximate_gcd.sub_hl_de:
  ld a, l
  sub e
  ld l, a
  ld a, h
  sbc d
  ld h, a
;;
; Approximate greatest common divisor algorithm
; 1. If DE > HL, swap the two
; 2. If DE < epsilon, return HL + DE / 2
; 3. Subtract DE from HL and repeat
; Test case: 2240,5537 -> 3297,2240 -> 1057,2240 -> 1183,1057
; -> 126,1057 -> 1120
; @param HL one value
; @param DE the other value
; @return HL: approximate GCD; ADE clobbered; BC unchanged
approximate_gcd::
  ; Swap to make HL > DE
  ld a, e
  sub l
  ld a, d
  sbc h
  jr c, .hl_is_greater
    ; Swap the two to make HL > DE
    ; Intel 8080 and Zilog Z80 use opcode EB to instantly rename
    ; HL to DE and vice versa.  Game Boy CPU lacks that luxury.
    ld a, e
    ld e, l
    ld l, a
    ld a, d
    ld d, h
    ld h, a
  .hl_is_greater:
  ; If the approximation isn't yet good enough, subtract
  ld a, e
  sub low(AGCD_EPSILON)
  ld a, d
  sbc high(AGCD_EPSILON)
  jr nc, .sub_hl_de

  ; The approximation is good enough.
  ; Add half the remainder to the approximation.
  sra d
  rr e
  add hl, de
  ret

; TODO: Calculate delta times
; TODO: Calculate pairwise AGCDs for all delta times
; TODO: Filter AGCDs
; TODO: Heapify kept AGCDs
; TODO: Heap pop n/2 AGCDs to find the median
