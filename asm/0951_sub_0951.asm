# sub_0951 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0951..0954  len 0004 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: the first two bytes are the displacement of
#           `cmp 0x26e,%al` (`3a 06 6e 02`) whose first two bytes are the forced-keep at
#           asm/094F; `outsb` and `add 0x21(%di),%dh` were that displacement plus the real `jne`
#           read from the wrong offset. gas encodes the cmp exactly, so the marker on 094F blames
#           gas for a boundary. Found by tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0951:
L_000b51:
        .byte 0x6e, 0x02   # tail of `cmp 0x26e,%al` started at asm/094F
L_000b53:
        jne L_000b76
