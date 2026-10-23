# sub_0cb0 — store DS:1F from DI, after a downward scan for a zero mon_type slot
# Part of the 0C9A..0E00 cluster; see docs/monster-spawn.md § 11 for the reassembly AND
# for the live check that downgraded its naming.
# WHAT IS PROVEN: the bytes, and that the preceding scan walks slots 31..1 looking for a
# zero mon_type. WHAT IS NOT: that DS:1F is a slot cursor owned by this code. Live, after
# a session with real turn activity, DS:1F read 120 — impossible as a slot index in a
# 32-slot table — and this cluster's mon_x store was never executed. DS:1F is shared
# scratch with 20+ writers; this is one of them.
# Slot 0 is unreachable from the scan (`dec di ; jne` stops at 1), the same blind spot
# asm/23E6_find_creature_at_cursor.asm documents for its own scan.
# provenance: static reassembly 2026-10-23, live-disproved same day
# confidence: high for the bytes; LOW for the subsystem naming
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
