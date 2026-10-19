# sub_4a3e — mechanical clean (bulk wave); behavior not yet reviewed
# func 4A3E..4A45  len 0008 B  evidence: seed+call+reko
# seams: video_int10
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4a3e:
L_004c3e:
        push   %ax
L_004c3f:
        push   %bx
L_004c40:
        mov    $0x0,%ah
L_004c42:
        mov    $0x4,%al
L_004c44:
video_int10:
        int $0x10    # video_int10 seam
