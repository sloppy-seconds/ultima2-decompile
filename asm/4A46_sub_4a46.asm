# sub_4a46 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4A46..4A4D  len 0008 B  evidence: seed+reko
# seams: video_int10
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4a46:
L_004c46:
        mov    $0xb,%ah
L_004c48:
        mov    $0x0,%bh
L_004c4a:
        mov    $0x0,%bl
L_004c4c:
video_int10:
        int $0x10    # video_int10 seam
