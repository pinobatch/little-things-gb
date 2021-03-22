#!/usr/bin/env python3
"""
Floyd fill demo
Copyright 2021 Damian Yerrick
[insert MIT License (Expat variant) here]

Experimental tool to calculate paths through offsets in a struct
using these operations, which are cheap on Game Boy CPU:

flip one bit (cost 2)
add 1 or subtract 1 (cost 1)
reset offset to 0 (cost 1; optional)
jump anywhere using BC (cost 5; optional)
jump anywhere using A (cost 4; optional)
"""

sizeof_actor = 32

USE_LD_L = 0x01
USE_ADD_HL = 0x02
USE_CLOBBER_A = 0x04
methodnames = [
    "1-cycle offset 0 (LD L, C)",
    "Park base address in a register (ADD HL, BC)",
    "Clobber A (LD A, new^old XOR L LD L, A)"
]

def neighbors(l, methods=0):
    """Calculate distance to each of node l's neighbors.

methods is a bitmask of what shortcuts may be used.

Return a dict from neighbor node ID to the distance."""
    out, bit_to_flip = {}, 1

    if methods & USE_CLOBBER_A:
        # LD A, i^l
        # XOR L
        # LD L, A
        out.update((i, 4) for i in range(sizeof_actor) if i != l)
    elif methods & USE_ADD_HL:
        # LD BC, i
        # ADD HL, BC
        out.update((i, 5) for i in range(sizeof_actor) if i != l)
    while bit_to_flip < sizeof_actor:  # SET p, L or RES p, L
        out[l ^ bit_to_flip] = 2
        bit_to_flip <<= 1
    if l > 0: out[l - 1] = 1  # DEC L
    if l + 1 < sizeof_actor: out[l + 1] = 1  # INC L
    if (methods & USE_LD_L) and l != 0:
        out[0] = 1  # LD L, C
    return out

def floyd_fill(methods=0):
    """Find all shortest paths between pairs of elements.

Dijkstra's algorithm finds the shortest path from one node of a
graph to another through a flood fill-like algorithm.  Floyd Fill
generalizes Dijkstra's algorithm to find shortest paths between
all pairs of nodes.

The variable names below differ from those in Wikipedia's article
to spell DIJKstra (Distance from node I through node J to node K).
<https://en.wikipedia.org/wiki/Floyd%E2%80%93Warshall_algorithm>

For each source node i:
    Set the distance from i to other nodes to infinite
    Set the distance from i to i to 0
    For each neighbor j of i with distance d:
        Set the distance from i to j to d
        Set the first step from i to j to j
For each intermediate node j, for each source node i, for each
destination node k:
    If distance i-j-k is lower cost than previous distance i to k:
        Set the distance from i to k to the distance i-j-k
        Set the first step from i to k to the first step from i to j

Return a 2-tuple (bestdist, bestnode) where
- bestdist[i][j] is the distance from node i to node j
- bestnode[i][j] is the first step from node i toward node j
"""

    # Set each node's tentative distance to other nodes to a value
    # greater than the greatest possible distance.
    # On Game Boy, the greatest possible distance is log2(sizeof_actor)*2.
    bestdist = [
        bytearray(0 if i == j else 0xFF for j in range(sizeof_actor))
        for i in range(sizeof_actor)
    ]
    # The ID of the first step through which the bestdist is reached.
    bestnode = [
        bytearray(i if i != j else 0xFF for j in range(sizeof_actor))
        for i in range(sizeof_actor)
    ]

    # distance to all neighbors
    for i in range(sizeof_actor):
        for j, d in neighbors(i, methods).items():
            bestnode[i][j], bestdist[i][j] = j, d

    for j in range(sizeof_actor):
        for i in range(sizeof_actor):
            if i == j: continue
            dij, nij = bestdist[i][j], bestnode[i][j]
            if dij == 0xFF: continue
            for k, djk in enumerate(bestdist[j]):
                if i == k or j == k: continue
                dik, djk = bestdist[i][k], bestdist[j][k]
                dijk = dij + djk
                # If the best distance to K is via J, mark it so
                if dijk < dik:
                    bestdist[i][k], bestnode[i][k] = dijk, nij
                    done = False
    return bestdist, bestnode

def get_method_names(methods):
    for i, mn in enumerate(methodnames):
        if methods & (1 << i): yield mn

def print_dists(bestdist, methods):
    if methods:
        print("Shortcuts used:")
        print("\n".join(get_method_names(methods)))
    else:
        print("No shortcuts used")
    print("Distance matrix")
    print("\n".join(row.hex() for row in bestdist))
    flatdist = b"".join(bestdist)
    totaldist, maxdist = sum(flatdist), max(flatdist)
    print("maximum %d, average %.2f" % (maxdist, totaldist/len(flatdist)))

def compare_dists(bestdist1, methods1, bestdist2, methods2):
    mn1 = "; ".join(get_method_names(methods1)) or "None"
    mn2 = "; ".join(get_method_names(methods2)) or "None"
    print("Comparing A:", mn1)
    print("to B:", mn2)
    impmatrix = [
        "".join(
            "A%d" % (b - a) if a < b else "B%d" % (a - b) if b < a else "--"
            for a, b in zip(arow, brow)
        )
        for arow, brow in zip(bestdist1, bestdist2)
    ]
    print("\n".join(impmatrix))

def demo_baseline():
    methods = 0
    bestdist, bestnode = floyd_fill(methods)
    print("Cycles to move a struct member pointer in HL from member I to member J")
    print("using inc, dec, set, and res, calculated using the Floyd Fill algorithm")
    print_dists(bestdist, methods)

def demo_comparison():
    methods1 = USE_CLOBBER_A
    methods2 = USE_LD_L
    bestdist1, bestnode1 = floyd_fill(methods1)
    print_dists(bestdist1, methods1)
    print()
    bestdist2, bestnode2 = floyd_fill(methods2)
    print_dists(bestdist2, methods2)
    print()
    compare_dists(bestdist1, methods1, bestdist2, methods2)

if __name__=='__main__':
    demo_baseline()
