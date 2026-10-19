# sub_52ef — mechanical clean (bulk wave); behavior not yet reviewed
# func 52EF..52F5  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_52ef:
L_0054ef:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_0054f1:
        mov    $0x8,%bx
L_0054f4:
        .byte 0x2b,0xf3  # forced-kept: gas re-encodes 'sub    %bx,%si' differently
