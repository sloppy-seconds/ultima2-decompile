# sub_0cb0 — overworld spawner: record the free slot found by the scan into DS:1F
# DS:1F is the spawner's slot cursor, written here from DI after the downward search
# started at 0C9C. Every setter below (0CC0 x, 0CDC y, 0CEE kind) indexes through it.
# Slot 0 is unreachable: the scan is `dec di ; jne`, so it stops at 1 — the same blind
# spot asm/23E6_find_creature_at_cursor.asm documents for its own scan.
# provenance: static, reassembled in address order 2026-10-23
# confidence: high for the bytes; DS:60's role is still inferred — see § 11 open items
# func 0CB0..0CB8  len 0009 B  evidence: seed+reko
# calls: L_005417
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0cb0:
L_000eb0:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_000eb2:
        mov    %bl,0x1f
L_000eb6:
        call L_005417
