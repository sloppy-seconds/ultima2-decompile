# sub_0a6d — mechanical clean (bulk wave); behavior not yet reviewed
# func 0A6D..0A73  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0a6d:
L_000c6d:
        nop
L_000c6e:
        mov    $0x0,%bh
L_000c70:
        mov    $0x1f,%bl
L_000c72:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
