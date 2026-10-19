# sub_42cb — mechanical clean (bulk wave); behavior not yet reviewed
# func 42CB..42D0  len 0006 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_42cb:
L_0044cb:
        mov    $0x0,%bh
L_0044cd:
        mov    $0x0,%bl
L_0044cf:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
