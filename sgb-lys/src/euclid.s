include "src/global.inc"

def AGCD_EPSILON = 512
def WITH_AGCD_TEST equ 0
def WITH_HEAPSORT_TEST equ 0

section "deltacounts", HRAM
hNumDeltas:: ds 1
hNumAGCDs:: ds 1

section "deltas", WRAM0, ALIGN[1]
wDeltasToUse: ds 2 * MAX_DELTA_TIMES

; calc84maniac suggested aligning wAGCDs to a $0100-byte boundary
; to simplify heap traversal during sorting:
;
;     it's most ideal if you can place the heap in an aligned
;     location where you can shift the LSB directly to move up
;     and down the binary tree
;
; This brought to mind how I traverse the Y and XT subtables
; of shadow OAM on Master System.
section "agcds", WRAM0, ALIGN[8]
wAGCDs: ds 2 * MAX_AGCDS
assert 2 * MAX_AGCDS < $100

section "approximate_gcd", ROM0

if WITH_AGCD_TEST
approximate_gcd_test::
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
        assert low(wAGCDs) == 0
        ld l, a
        ld h, high(wAGCDs)
        ld [hl], e
        inc l
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

;;
; Sorts values in wAGCDs[:hNumAGCDs] by increasing value
heapsort_agcds::
  ldh a, [hNumAGCDs]
  ld c, a
  and $7E  ; A = middle of array in bytes
  ret z  ; fewer than 2 elements are already sorted
  ld h, high(wAGCDs)
  ld l, a  ; HL: pointer to current element
  sla c  ; HC: pointer to end of array

  .heapify_loop:
    dec l
    dec l
    push hl
    call heapsort_sift
    pop hl
    ld a, l
    or a
    jr nz, .heapify_loop

  dec c
  dec c
  .heappop_loop:
    ; C is index of last element. Swap it with the first
    ld hl, wAGCDs
    ld b, h
    ld d, [hl]
    ld a, [bc]
    ld [hl+], a
    ld a, d
    ld [bc], a
    inc c
    ld d, [hl]
    ld a, [bc]
    ld [hl-], a
    ld a, d
    ld [bc], a
    dec c
    ld l, 0
    call heapsort_sift
    dec c
    dec c
    jr nz, .heappop_loop
  ret

;;
; Ensures element at HL not greater than the elements at
; H{2L+2} and H{2L+4}.  Otherwise, swap with greater of the two
; and repeat from there.
; @param C offset in bytes of end of list
heapsort_sift:
  ld b, l  ; index of largest element
  ld e, [hl]
  inc l
  ld d, [hl]  ; DE = value of largest element

  sla l  ; L = 2L+2
  ret c  ; if past $100 then sift is done
  ld a, l
  cp c
  ret nc  ; if past end of list then sift is done
  ld a, e  ; If DE < [2L+2] then set 2L+2 as swap target
  sub [hl]
  inc l
  ld a, d
  sbc [hl]
  jr nc, .lchild_not_greater
    dec l
    ld b, l
    ld e, [hl]
    inc l
    ld d, [hl]
  .lchild_not_greater:

  inc l  ; L = 2L+4; can be a swap target only if within the list
  jr z, .rchild_not_greater  ; if past $100 then skip
  ld a, l
  cp c
  jr nc, .rchild_not_greater  ; if past end of list then skip
  ld a, e  ; If DE < [2L+4] then set 2L+4 as swap target
  sub [hl]
  inc l
  ld a, d
  sbc [hl]
  dec l
  jr nc, .rchild_not_greater
    ld b, l
    ld e, [hl]
    inc l
    ld d, [hl]
    dec l
  .rchild_not_greater:

  ; L = 2L+4, DE = greatest value of 3, HB points to greatest
  ; seek back to first and compare
  dec l
  dec l
  sra l
  dec l  ; L = L
  ld a, l
  xor b
  ret z  ; If head is greatest then sift is done

  ; Move [HL] to [HB] and DE to [HL], then re-sift from HB
  push bc
  ld c, b
  ld b, h
  ld a, [hl]
  ld [bc], a
  ld a, e
  ld [hl+], a
  inc c
  ld a, [hl]
  ld [bc], a
  ld a, d
  ld [hl], a
  pop bc
  ld l, b
  jr heapsort_sift

if WITH_HEAPSORT_TEST
heapsort_test::
  ld a, (geeksforgeeks_test_data.end - geeksforgeeks_test_data)/2
  ld hl, geeksforgeeks_test_data
  call .one_test
  ld a, (actual_test_data.end - actual_test_data)/2
  ld hl, actual_test_data
.one_test:
  ldh [hNumAGCDs], a
  ld de, wAGCDs
  add a
  ld c, a
  ld b, 0
  call memcpy
  ld b, b
  call heapsort_agcds
  ld b, b
  ret

geeksforgeeks_test_data:
  ; dataset from https://www.geeksforgeeks.org/heap-sort/
  dw 12, 11, 13, 5, 6, 7
.end
actual_test_data:
  ; dataset from my SGB
  ; timestamps = [6754, 16890, 23644, 30398, 38269, 46155, 54036]
  dw 1086, 1132, 1151, 1125, 1126, 1127, 1132, 1065, 1080, 1148, 1145, 1120, 1143, 1143, 1126, 1113, 1123, 1123, 1169, 1117, 1128, 1132, 1118, 1127, 1143, 1143, 1126, 1113, 1123, 1123, 1143, 1086, 1075, 1031, 1098
.end

endc
