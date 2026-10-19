# sub_248b — mechanical clean (bulk wave); behavior not yet reviewed
# func 248B..2494  len 000A B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_248b:
L_00268b:
        nop
L_00268c:
        mov    0x29,%al
L_00268f:
        and    $0x7f,%al
L_002691:
        cmp    $0x2,%al
L_002693:
        jne L_0026b1
