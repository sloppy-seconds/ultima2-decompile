# sub_106d — mechanical clean (bulk wave); behavior not yet reviewed
# func 106D..1077  len 000B B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_106d:
L_00126d:
        mov    $0x0,%bh
L_00126f:
        mov    0x25,%bl
L_001273:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_001275:
        dec    %di
L_001276:
        jns L_00121c
