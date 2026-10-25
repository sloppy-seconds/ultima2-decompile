# sub_45fc — mechanical clean (bulk wave); behavior not yet reviewed
# func 45FC..4609  len 000E B  evidence: reko
# calls: L_0053eb
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: the first byte is the tail of `mov $0x0,%bh`
#           (`b7 00`) whose opcode is the forced-keep at asm/45FB, and everything after it was
#           read one byte early: `add %dh,-0x74ff(%bp,%di)` swallowed the tail plus the real
#           `mov $0x1,%bl` plus the first byte of `mov %bx,%di`, and the `sti` after it was the
#           second byte of that move. gas encodes `mov $0x1,%bl` exactly, so the marker on 45FB
#           blames gas for a boundary. Found by tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_45fc:
L_0047fc:
        .byte 0x00   # tail of `mov $0x0,%bh` started at asm/45FB
L_0047fd:
        mov    $0x1,%bl
L_0047ff:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_004801:
        mov    $0x0,%bh
L_004803:
        mov    $0x4,%bl
L_004805:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_004807:
        call L_0053eb
