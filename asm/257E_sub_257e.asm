# sub_257e — mechanical clean (bulk wave); behavior not yet reviewed
# func 257E..2583  len 0006 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_257e:
L_00277e:
        mov    $0x0,%bh
L_002780:
        mov    $0x20,%bl
L_002782:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
