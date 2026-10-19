# sub_2de4 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2DE4..2DED  len 000A B  evidence: seed+reko
# calls: L_0055b5
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2de4:
L_002fe4:
        and    $0x3,%al
L_002fe6:
        adc    $0x1,%al
L_002fe8:
        mov    %al,0x1f
L_002feb:
        call L_0055b5
