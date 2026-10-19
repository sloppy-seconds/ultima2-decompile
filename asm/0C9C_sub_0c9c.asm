# sub_0c9c — mechanical clean (bulk wave); behavior not yet reviewed
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
