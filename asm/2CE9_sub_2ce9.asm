# sub_2ce9 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2CE9..2CF1  len 0009 B  evidence: seed+reko
# calls: L_005417
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2ce9:
L_002ee9:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_002eeb:
        mov    %bl,0x1f
L_002eef:
        call L_005417
