# sub_0b4d — mechanical clean (bulk wave); behavior not yet reviewed
# func 0B4D..0B5E  len 0012 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0b4d:
L_000d4d:
        incb   0x20
L_000d51:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_000d53:
        mov    %bl,0x27
L_000d57:
        mov    0x197(%di),%al
L_000d5b:
        cmp    $0xfc,%al
L_000d5d:
        jne L_000d62
