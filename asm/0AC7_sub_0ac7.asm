# sub_0ac7 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0AC7..0AD2  len 000C B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0ac7:
L_000cc7:
        mov    $0x0,%bh
L_000cc9:
        mov    0x29,%bl
L_000ccd:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_000ccf:
        cmp    $0x20,%al
L_000cd1:
        jae L_000cfc
