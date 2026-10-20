# sub_0a5f — mechanical clean (bulk wave); behavior not yet reviewed
# func 0A5F..0A6C  len 000E B  evidence: seed+reko
# calls: L_00135e, L_00135f
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0a5f:
L_000c5f:
        cmp    $0x4,%al
L_000c61:
        jne L_000c66
L_000c63:
        jmp L_00135f
L_000c66:
        cmp    $0x5,%al
L_000c68:
        jne L_000c6d
L_000c6a:
        jmp L_00135e
