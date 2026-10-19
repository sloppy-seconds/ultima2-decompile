# sub_0a7c — mechanical clean (bulk wave); behavior not yet reviewed
# func 0A7C..0A82  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0a7c:
L_000c7c:
        mov    0x13,%al
L_000c7f:
        cmp    $0x22,%al
L_000c81:
        jne L_000ca7
