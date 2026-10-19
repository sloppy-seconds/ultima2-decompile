# sub_2578 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2578..257D  len 0006 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2578:
L_002778:
        mov    $0x0,%bh
L_00277a:
        mov    $0xff,%bl
L_00277c:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
