# sub_2619 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2619..261F  len 0007 B  evidence: seed+reko
# provenance: static (bytes) + live:ship-port-boniface — the ship mode was boarded there
#           and the arm's verdicts are the measured ones: it sailed onto water and refused
#           its own dock tile and grass. The 0x80 compare's unreachability is argued from
#           the argument's provenance (map_byte >> 1), not observed.
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# RENAMED 2026-10-29 from sub_2619, with the behaviour: the SHIP arm of asm/253B's
#           travel-mode dispatch. asm/2550 reaches here when [DS:13] == 0x24.
#
#           `mov 0x29,%al ; cmp 0x0 ; je accept`, and asm/2620 follows with `cmp 0x80 ; je
#           accept ; jmp reject`. Note there is NO `and 0x7f` here, unlike every other arm:
#           the compare is on the raw argument.
#
#           The 0x80 is unreachable and the ship is therefore WATER ONLY, with no second
#           passable byte hiding: [DS:29] is the caller's AL, which asm/2423 stores on entry
#           and which every live [DS:14] sample agrees is map_byte >> 1, so the largest
#           value that can arrive is 0xFC >> 1 = 0x7E. Settled by
#           captures/spice86/ship-port-boniface, which also measured the ship refusing its
#           own dock tile and refusing grass. No food is charged on this arm.
sub_2619:
L_002819:
        mov    0x29,%al
L_00281c:
        cmp    $0x0,%al
L_00281e:
        je L_002804
