# sub_35f3 — mechanical clean (bulk wave); behavior not yet reviewed
# func 35F3..35FF  len 000D B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_35f3:
L_0037f3:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_0037f5:
        mov    %bl,0x20
L_0037f9:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_0037fb:
        cmp    $0x0,%bl
L_0037fe:
        jne L_003803
