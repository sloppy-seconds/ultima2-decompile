# sub_4660 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4660..466E  len 000F B  evidence: seed+reko
# calls: L_0053eb
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4660:
L_004860:
        mov    $0x0,%bh
L_004862:
        mov    $0x1f,%bl
L_004864:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_004866:
        mov    $0x0,%bh
L_004868:
        mov    $0x5,%bl
L_00486a:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_00486c:
        call L_0053eb
