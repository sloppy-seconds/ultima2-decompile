# sub_0cc0 — overworld spawner: store mon_x[DS:1F] and mirror it to staging DS:23
# Entered only from asm/0CB9_sub_0cb9.asm (`cmp al,0x3f ; jb`), so the value arriving
# here has already passed a < 64 bounds check; a coordinate outside the sector exits
# at 0DAF instead. This is a PLACEMENT store, not movement: nothing here computes a new
# coordinate, it stores one a caller supplied. CP5's creature-AI hunt passed through here
# and stopped — see docs/monster-spawn.md § 11, "What this rules out".
# Consequence for instrumentation: a MEMORY_WRITE breakpoint on a fixed slot offset
# (DS:137+n) will miss these writes whenever DS:1F holds a different n. Break on the
# execution address instead.
# provenance: static, reassembled in address order 2026-10-23
# confidence: high
# func 0CC0..0CD1  len 0012 B  evidence: seed+reko
# calls: L_005417
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0cc0:
L_000ec0:
        mov    $0x0,%bh
L_000ec2:
        mov    0x1f,%bl
L_000ec6:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_000ec8:
        mov    %al,0x137(%di)
L_000ecc:
        mov    %al,0x23
L_000ecf:
        call L_005417
