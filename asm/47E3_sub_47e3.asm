# sub_47e3 — mechanical clean (bulk wave); behavior not yet reviewed
# func 47E3..47EA  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_47e3:
L_0049e3:
        inc    %di
L_0049e4:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_0049e6:
        cmp    $0x7,%bl
L_0049e9:
        jb L_0049b4
