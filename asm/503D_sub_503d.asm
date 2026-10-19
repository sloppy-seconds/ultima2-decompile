# sub_503d — mechanical clean (bulk wave); behavior not yet reviewed
# func 503D..5049  len 000D B  evidence: seed+reko
# seams: video_int10
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_503d:
L_00523d:
        mov    $0x9,%ah
L_00523f:
        mov    $0x1,%cx
L_005242:
        mov    0x23e,%bl
L_005246:
        mov    $0x0,%bh
L_005248:
video_int10:
        int $0x10    # video_int10 seam
