# sub_47de — mechanical clean (bulk wave); behavior not yet reviewed
# func 47DE..47E0  len 0003 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_47de:
L_0049de:
        mov    $0x20,%al
L_0049e0:
        .byte 0xe8  # forced-kept: stop-trunc call   0x55f4
