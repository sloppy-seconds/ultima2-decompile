# sub_535a — mechanical clean (bulk wave); behavior not yet reviewed
# func 535A..5370  len 0017 B  evidence: seed+reko
# seams: dos_int21
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_535a:
L_00555a:
        pop    %ds
L_00555b:
        lea    0x245,%dx
L_00555f:
        mov    %cs:0x4f05,%cx
L_005564:
        movw   $0x1,0x253
L_00556a:
        mov    %cs:0x4f04,%ah
L_00556f:
dos_int21:
        int $0x21    # dos_int21 seam
