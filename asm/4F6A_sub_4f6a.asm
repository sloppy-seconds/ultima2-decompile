# sub_4f6a — mechanical clean (bulk wave); behavior not yet reviewed
# func 4F6A..4F6D  len 0004 B  evidence: seed+reko
# seams: key_int16
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4f6a:
L_00516a:
        mov    $0x1,%ah
L_00516c:
key_int16:
        int $0x16    # key_int16 seam
