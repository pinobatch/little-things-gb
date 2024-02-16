#!/usr/bin/env python3
"""
SGB Euclid
Program to estimate period of a process given subset of noisy timestamps

Copyright 2024 Damian Yerrick
SPDX-License-Identifier: FSFAP
"""

"""Background

The system software of the Super Game Boy (SGB) accessory reads
the controller once per vertical blanking period and forwards
button states to the Game Boy (GB) system on chip.  This quantizes
the time when button states can change, and the program running
on the Game Boy can measure this.

The frame period, or the duration from the xtart of one vblank to
the next, depends on the model.  Ideal timer periods in units of
64 T-states (nominally 1/65536 second) rounded to a whole tick:

- NTSC SGB: 1117
- PAL SGB: 1330
- NTSC SGB2: 1090

SGB processing order varies a bit depending on other ongoing tasks.
In addition, the GB sees state changes only when the user actually
presses a button, or about one in 8-12 frames.  Estimation of
frame period must account for these sparse, noisy observations.

Another attempt:
https://math.stackexchange.com/q/1834472/93170
"""

def get_agcd(diff1, diff2, epsilon):
    """Calculate approximate greatest common divisor using Euclid's algorithm."""
    while diff1 > epsilon and diff2 > epsilon:
        if diff1 > diff2:
            diff1 -= diff2
        else:
            diff2 -= diff1
    return max(diff1, diff2) + min(diff1, diff2) // 2

def hexdump_agcds(agcds):
    print("dw " + ", ".join(str(x) for x in agcds))
    for i in range(0, len(agcds), 8):
        print("|".join(
            " ".join("%02X %02X" % (x & 0xFF, x >> 8)
                     for x in agcds[j:j + 4])
            for j in range(i, min(len(agcds), i + 8), 4)))

def calc_likely_period(timestamps, ideal_period, print_agcds=False):
    """Find the period from observed timestamps.

Model:
- Increasing observed timestamps of a nearly periodic event
- Only a fraction of the timestamps were observed
- Each observation has a small amount of error
- The actual period is somewhat close to ideal_period
"""
    # Calculate difference of each timestamp with the two after it
    # producing 2*n-3 difference samples
    all_diffs = [
        upper - lower
        for i, lower in enumerate(timestamps)
        for upper in timestamps[i + 1:i + 3]
    ]
    if print_agcds:
        print("all_diffs:")
        print(" ".join("%04X" % d for d in all_diffs))

    # For each of the (n-2)(2n-3) pairs of differences, calculate
    # the AGCD with epsilon half of an ideal period
    agcds = [
        get_agcd(lower, upper, ideal_period//2)
        for i, lower in enumerate(all_diffs)
        for upper in all_diffs[i + 1:]
    ]

    if print_agcds:
        print("unfiltered_agcds:")
        hexdump_agcds(agcds)

    # Discard AGCDs exceeding 2.5 ideal periods and halve those
    # exceeding 1.5
    halve_threshold = 3 * ideal_period // 2
    discard_threshold = 5 * ideal_period // 2
    agcds = [
        x // 2 if x > halve_threshold else x for x in agcds
        if x < discard_threshold
    ]

    # Take the median of what's left
    if print_agcds:
        print("unsorted_agcds:")
        hexdump_agcds(agcds)
    agcds.sort()

    if print_agcds:
        print("sorted_agcds:")
        hexdump_agcds(agcds)
    return agcds[len(agcds) // 2]

IDEAL_FRAME_PERIOD = 70224//64
timestamps = [6754, 16890, 23644, 30398, 38269, 46155, 54036]
median = calc_likely_period(timestamps, IDEAL_FRAME_PERIOD)
print("median period: %d" % median)
print(" ts   since0  frame")
print("\n".join(
    "%5d  %5d %6.2f"
    % (t, t-timestamps[0], (t-timestamps[0])/median)
    for t in timestamps
))
