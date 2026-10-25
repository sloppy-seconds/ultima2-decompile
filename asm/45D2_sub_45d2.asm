# sub_45d2 — mechanical clean (bulk wave); behavior not yet reviewed
# func 45D2..45D9  len 0008 B  evidence: reko
# calls: L_00528c
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: the first two bytes are the tail of the moffs form
#           `mov 0x61,%al` (`a0 61 00`) whose opcode is the forced-keep at asm/45D1; gas encodes
#           that instruction exactly, so the marker on 45D1 blames gas for a boundary. The four
#           mnemonics this file showed were the tail plus `clc` and `adc $0x13,%al` read from the
#           wrong offset. Found by tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_45d2:
L_0047d2:
        .byte 0x61, 0x00   # tail of `mov 0x61,%al` (moffs `a0 61 00`) started at asm/45D1
L_0047d4:
        clc
L_0047d5:
        adc    $0x13,%al
L_0047d7:
        call L_00528c
