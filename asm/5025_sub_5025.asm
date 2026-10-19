# sub_5025 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5025..5035  len 0011 B  evidence: seed+reko
# seams: video_int10
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5025:
L_005225:
        mov    $0x1,%al
L_005227:
        mov    $0x1400,%cx
L_00522a:
        mov    $0x17,%dh
L_00522c:
        mov    0x31,%dl
L_005230:
        mov    $0x0,%bh
L_005232:
        mov    $0x6,%ah
L_005234:
video_int10:
        int $0x10    # video_int10 seam
