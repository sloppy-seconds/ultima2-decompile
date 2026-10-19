# sub_5c70 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5C70..5C75  len 0006 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5c70:
L_005e70:
        mov    $0x0,%bh
L_005e72:
        mov    $0x0,%bl
L_005e74:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
