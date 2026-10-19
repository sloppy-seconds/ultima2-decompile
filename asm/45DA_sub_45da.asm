# sub_45da — mechanical clean (bulk wave); behavior not yet reviewed
# func 45DA..45E8  len 000F B  evidence: seed+reko
# calls: L_0053eb
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_45da:
L_0047da:
        mov    $0x0,%bh
L_0047dc:
        mov    $0x1d,%bl
L_0047de:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0047e0:
        mov    $0x0,%bh
L_0047e2:
        mov    $0x3,%bl
L_0047e4:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_0047e6:
        call L_0053eb
