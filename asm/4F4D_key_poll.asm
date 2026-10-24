# key_poll — the whole key seam: probe, consume, swallow, arrow-map, upper-case
# name-evidence: 5-byte wrapper: int 16h with ah=1; 23 call sites
# REAL FUNCTION SPAN: runtime 4F4D..4FDE (file 514D..51FE). Phase 3 cut it into 30
#           fragments and handed the tail to neighbours, which is why this header used to
#           describe only the AH=01h probe. Read it in address order; the full trace, every
#           hop re-verified against the bytes on 2026-10-28, is in
#           docs/phase4-implementation.md § "Direction keys: proven, and they are the arrows".
# THE CONTRACT: AH = 0xFF means "a key was consumed", AH = 0x00 means none. Both returns fall
#           into the upper-case tail at L_0051d3, and the no-key path at asm/4F52 jumps PAST
#           the `mov $0xff,%ah` at asm/4FD1 — that one instruction is the whole return value,
#           and a fragment-boundary read misses it.
# WHAT IT DOES, in order:
#           1. AH=01h status probe; no key -> return with AH=0.
#           2. AH=00h consume. AL = character, AH = extended scancode.
#           3. Swallow Ctrl-E/Ctrl-N/Ctrl-W (AL = 0x05/0x0E/0x17) — asm/4F58..asm/4F64.
#              Those are exactly three of the four arrow direction codes, so the swallow is
#              what makes the arrows the only way in. South's code (0x19) is NOT in the list.
#           4. Drain the typeahead buffer: asm/4F69..asm/4F74 loops AH=01h/AH=00h until empty,
#              discarding everything after the first key. A game behaviour, not a harness
#              defect, and the mechanism behind standing hazard 1 in docs/needs-gameplay.md.
#           5. Ctrl-S (0x13) toggles DS:54D (asm/4F7B) instead of returning.
#           6. AL != 0 is an ordinary character — done (asm/4F85). The arrow table is reached
#              only for extended keys, i.e. when AL == 0.
#           7. F1/F0 page-step on DS:74 (asm/4F89, asm/4FA0).
#           8. Arrow table at CS:0x4F09 = `48 0e 50 19 4d 05 4b 17`, scanned backwards from
#              bx=6 step -2 by asm/4FBB..asm/4FCA, matched on AH, mapped byte taken from
#              CS:0x4F0A(bx) at asm/4FCC. Up->0x0E, Down->0x19, Right->0x05, Left->0x17:
#              the control-letter forms of NORTH, SOUTH, EAST, WEST.
#           9. Upper-case a-z with `and $0xdf` (asm/4FD3..asm/4FDB).
# func 4F4D..4F51  len 0005 B  evidence: seed+call+reko
# seams: key_int16
# provenance: live:airport (+59 other harvests), static
#           entry executed in 60 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
key_poll:
L_00514d:
        push   %bx
L_00514e:
        mov    $0x1,%ah
L_005150:
key_int16:
        int $0x16    # key_int16 seam
