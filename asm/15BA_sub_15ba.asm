# sub_15ba — mechanical clean (bulk wave); behavior not yet reviewed
# func 15BA..15C7  len 000E B  evidence: seed+reko
# calls: L_001ce0, L_00204f
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_15ba:
L_0017ba:
        nop
L_0017bb:
        mov    0x4a,%al
L_0017be:
        cmp    $0x2,%al
L_0017c0:
        jne L_0017c5
L_0017c2:
        jmp L_00204f
L_0017c5:
        jmp L_001ce0
