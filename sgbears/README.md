The story so far
----------------

Girl strays from greenway into woods, enters unlocked cottage, eats
their meal, breaks a chair, sleeps in bed.  Residents return from
morning hike and chase her out.  A week later, girl replaces chair
and residents forgive. Over time, youngest befriends girl.

On one play date...

The technical story
-------------------

A Super Game Boy program loads a border by preparing the data in the
Game Boy's video memory and sending two or three bulk data request
packets to the ICD2 bridge chip.  The normal sequence is one or two
`CHR_TRN` (tile data) requests then a `PCT_TRN` (tilemap) request.
Then the SGB system software fades out the current border, copies the
loaded tiles and tilemap from a buffer in Super NES work RAM to VRAM,
and fades it in.  However, one game shaves off fractions of a second
by doing `PCT_TRN` and then managing to squeeze in a `CHR_TRN` before
the fadeout finishes.  [Pan Docs issue #199] claims it's
_Alfred Chicken_.

This test ROM creates a similar situation with these steps:

1. `CHR_TRN` with Papa saying "too early"
2. `PCT_TRN`
3. After a delay, `CHR_TRN` with Cubby saying "just right"
4. After a delay, `CHR_TRN` with Mama saying "too late"

[Pan Docs issue #199]: https://github.com/gbdev/pandocs/issues/199
