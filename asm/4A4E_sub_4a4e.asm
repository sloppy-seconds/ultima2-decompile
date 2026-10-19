# sub_4a4e — mechanical clean (bulk wave); behavior not yet reviewed
# func 4A4E..4A55  len 0008 B  evidence: seed+reko
# seams: video_int10
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4a4e:
L_004c4e:
        mov    $0xb,%ah
L_004c50:
        mov    $0x1,%bh
L_004c52:
        mov    $0x1,%bl
L_004c54:
video_int10:
        int $0x10    # video_int10 seam
