# sub_5371 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5371..5378  len 0008 B  evidence: seed+reko
# seams: dos_int21
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5371:
L_005571:
        lea    0x245,%dx
L_005575:
        mov    $0x10,%ah
L_005577:
dos_int21:
        int $0x21    # dos_int21 seam
