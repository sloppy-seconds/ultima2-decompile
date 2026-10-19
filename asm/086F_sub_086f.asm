# sub_086f — mechanical clean (bulk wave); behavior not yet reviewed
# func 086F..0879  len 000B B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_086f:
L_000a6f:
        nop
L_000a70:
        mov    $0x100,%sp
L_000a73:
        mov    0x4a,%al
L_000a76:
        cmp    $0x4,%al
L_000a78:
        jb L_000a7d
