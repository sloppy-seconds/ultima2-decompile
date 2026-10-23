# sub_0c9c — overworld spawner: start a downward free-slot scan at slot 31
# Part of the 0C9A..0E00 spawner cluster; see docs/monster-spawn.md § 11 for the
# reassembled routine, which the bulk-wave fragment split made unreadable in isolation.
# NOTE the operand is the immediate 0x1f, NOT a read of DS:1F. Reading it as a cursor
# load makes the whole cluster look like a per-entity accessor API and hides that it
# is a spawner. See § 11, "The trap that had to be stepped in first".
# provenance: static, reassembled in address order 2026-10-23
# confidence: high for the bytes and the scan shape; the routine name is inferred
# func 0C9C..0CA1  len 0006 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0c9c:
L_000e9c:
        mov    $0x0,%bh
L_000e9e:
        mov    $0x1f,%bl
L_000ea0:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
