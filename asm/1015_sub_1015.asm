# sub_1015 — mechanical clean (bulk wave); behavior not yet reviewed
# func 1015..101B  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_1015:
L_001215:
        nop
L_001216:
        mov    $0x0,%bh
L_001218:
        mov    $0x1f,%bl
L_00121a:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
