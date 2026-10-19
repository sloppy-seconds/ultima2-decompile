# sub_4f70 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4F70..4F73  len 0004 B  evidence: seed+reko
# seams: key_int16
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4f70:
L_005170:
        mov    $0x0,%ah
L_005172:
key_int16:
        int $0x16    # key_int16 seam
