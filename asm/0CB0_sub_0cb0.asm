# sub_0cb0 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0CB0..0CB8  len 0009 B  evidence: seed+reko
# calls: L_005417
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0cb0:
L_000eb0:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_000eb2:
        mov    %bl,0x1f
L_000eb6:
        call L_005417
