# sub_4fa5 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4FA5..4FB2  len 000E B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4fa5:
L_0051a5:
        mov    0x74,%ax
L_0051a8:
        add    $0x200,%ax
L_0051ab:
        cmp    $0x3a00,%ax
L_0051ae:
        ja L_0051b6
L_0051b0:
        mov    %ax,0x74
