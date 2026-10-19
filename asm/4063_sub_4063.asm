# sub_4063 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4063..406D  len 000B B  evidence: seed+reko
# calls: L_0055f4
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4063:
L_004263:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_004265:
        mov    %bl,0x20
L_004269:
        mov    $0x8d,%al
L_00426b:
        call L_0055f4
