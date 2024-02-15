include "src/global.inc"

def AGCD_EPSILON = 512
def WITH_AGCD_TEST equ 0

section "deltacounts", HRAM
hNumDeltas:: ds 1
hNumAGCDs:: ds 1

section "deltas", WRAM0, ALIGN[1]
wDeltasToUse: ds 2 * MAX_DELTA_TIMES
wAGCDs: ds 2 * MAX_AGCDS


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

;;
; Counts ticks between each press and the two before it.
; Rejects presses differing by more than 65536 ticks.
; If there are 3-7 presses in the buffer, this should give 2-6
; consecutive deltas and 0-5 deltas skipping one.
calculate_deltas::
  ldh a, [hPressRingBufferIndex]
  ; there are one fewer than that many
  ld b, 0  ; number of written deltas
  ld c, a
  dec c  ; C is the count of adjacent pairs to use
  ld de, wPresses
  ld hl, wPresses + SIZEOF_PRESS_BUFFER_ENTRY
  jr .after_two_apart
  .do_two_apart:
    ld a, l
    add SIZEOF_PRESS_BUFFER_ENTRY
    ld l, a
    adc h
    sub l
    ld h, a
    call try_append_one_delta
    ld a, e
    add SIZEOF_PRESS_BUFFER_ENTRY
    ld e, a
    adc d
    sub e
    ld d, a
  .after_two_apart:
    call try_append_one_delta
    dec c
    jr nz, .do_two_apart
  ld a, b
  ldh [hNumDeltas], a
  ret

;;
; If AGCD_EPSILON <= [HL] - [DE] < 65536, write the difference
; to row B of  wDeltasToUse and increment B
try_append_one_delta:
  push hl
  push de
  push bc

  ; Trial subtraction: ABC = [HL] - [BC]
  ld a, [de]
  inc de
  ld c, a
  ld a, [hl+]
  sub c
  ld c, a
  ld a, [de]
  inc de
  ld b, a
  ld a, [hl+]
  sbc b
  ld b, a
  ld a, [de]
  ld e, a
  ld a, [hl]
  sbc e

  jr nz, .reject  ; Reject if >= 65536
  ld a, c
  sub low(AGCD_EPSILON)
  ld a, b
  sbc high(AGCD_EPSILON)
  jr nc, .accept  ; Reject if < AGCD_EPSILON
  .reject:
    pop bc
    pop de
    pop hl
    ret
  .accept:

  ; Append BC to the list
  ld d, b
  ld e, c
  pop bc
  ld a, b
  add a
  add low(wDeltasToUse)
  ld l, a
  adc high(wDeltasToUse)
  sub l
  ld h, a
  ld a, e
  ld [hl+], a
  ld [hl], d
  inc b
  pop de
  pop hl
  ret

;;
; Calculates AGCD values of all pairwise combinations of deltas.
calculate_agcds::
  ld b, b
  xor a
  ldh [hNumAGCDs], a
  ld b, a
  .bloop:
    ld c, b
    inc c
    .cloop:
      ld a, b
      add a
      add low(wDeltasToUse)
      ld l, a
      adc high(wDeltasToUse)
      sub l
      ld h, a
      ld e, [hl]
      inc hl
      ld d, [hl]
      ld a, c
      add a
      add low(wDeltasToUse)
      ld l, a
      adc high(wDeltasToUse)
      sub l
      ld h, a
      ld a, [hl+]
      ld h, [hl]
      ld l, a
      call approximate_gcd

      ; Reject if GCD exceeds 5 times epsilon (nominally 2.5 frames)
      ld a, l
      sub low(AGCD_EPSILON * 5)
      ld a, h
      sbc high(AGCD_EPSILON * 5)
      jr nc, .reject

        ; Halve if GCD exceeds 3 times epsilon (nominally 1.5 frames)
        ld a, l
        ld e, a
        sub low(AGCD_EPSILON * 3)
        ld a, h
        ld d, a
        sbc high(AGCD_EPSILON * 3)
        jr c, .no_halve
          sra e
          rr d
        .no_halve:

        ; Append GCD value
        ld hl, hNumAGCDs
        ld a, [hl]
        cp MAX_AGCDS
        ret nc  ; Reject all remaining values if full
        inc [hl]
        add a
        add low(wAGCDs)
        ld l, a
        adc high(wAGCDs)
        sub l
        ld h, a
        ld [hl], e
        inc hl
        ld [hl], d
      .reject:

      ; loop until c == hNumDeltas
      inc c
      ld a, [hNumDeltas]
      cp c
      jr nz, .cloop
    inc b
    ; loop until hNumDeltas - b < 2
    ld a, [hNumDeltas]
    sub b
    cp 2
    jr nc, .bloop
  ret


if 0
;;
; Sorts hNumAGCDs by increasing value
heapsort_agcds::
  ldh a, [hNumAGCDs]
  ld c, a
  sra a
  ret z  ; fewer than 2 elements are sorted
  ld b, a
  .heapify_loop:
    dec b
    call heapsort_sift
    ld a, b
    or a
    jr nz, .loop

  dec c
  .heappop_loop:
    ; Swap first element with last
    ld de, wAGCDs
    ld l, c
    ld h, 0
    add hl, hl
    add hl, de  ; DE points to first element and HL to last
    rept 2
      ld a, [de]
      ld b, a
      ld a, [hl]
      ld [de], a
      ld a, b
      ld [hl+], a
    endr
    ld b, 0
    call heapsort_sift
    dec c
    jr nz, .heappop_loop
  ret

;;
; Ensures element B of the first C elements is not greater than
; elements 2B+1 and 2B+2
heapsort_sift:
  ld a, b
  add a  ; stop if B>127
  ret c
  inc a
  cp c
  ret nc  ; stop if 2B+1 >= c
  
  ld 
  
  ret
endc  
  
; TODO: Heapify kept AGCDs
; TODO: Heap pop n/2 AGCDs to find the median
