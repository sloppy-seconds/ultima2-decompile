# sub_2bc7 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2BC7..2BD3  len 000D B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2bc7:
L_002dc7:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_002dc9:
        mov    %bl,0x20
L_002dcd:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_002dcf:
        cmp    $0x0,%bl
L_002dd2:
        jne L_002dd7
