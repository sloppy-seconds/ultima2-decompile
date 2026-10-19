# sub_4b08 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4B08..4B1A  len 0013 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4b08:
L_004d08:
        mov    0x6(%si),%ax
L_004d0b:
        mov    %ax,0x2(%si)
L_004d0e:
        mov    0x8(%si),%ax
L_004d11:
        mov    %ax,0x4(%si)
L_004d14:
        add    $0x4,%si
L_004d17:
        dec    %dl
L_004d19:
        jne L_004d08
