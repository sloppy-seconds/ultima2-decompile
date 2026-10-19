# sub_0aaa — mechanical clean (bulk wave); behavior not yet reviewed
# func 0AAA..0AB5  len 000C B  evidence: seed+reko
# calls: L_0052ef
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0aaa:
L_000caa:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_000cac:
        mov    %bl,0x29
L_000cb0:
        mov    0x19,%al
L_000cb3:
        call L_0052ef
