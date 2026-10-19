# sub_5356 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5356..5359  len 0004 B  evidence: seed+reko
# seams: dos_int21
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5356:
L_005556:
        mov    $0x1a,%ah
L_005558:
dos_int21:
        int $0x21    # dos_int21 seam
