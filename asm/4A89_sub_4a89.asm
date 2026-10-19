# sub_4a89 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4A89..4AA5  len 001D B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4a89:
L_004c89:
        mov    %cs:0x48dc(%bx),%ax
L_004c8e:
        mov    %ax,%es
L_004c90:
        mov    (%si),%ax
L_004c92:
        mov    %ax,%es:(%di)
L_004c95:
        mov    0x2(%si),%ax
L_004c98:
        mov    %ax,%es:0x2(%di)
L_004c9c:
        add    $0x4,%si
L_004c9f:
        add    $0x2,%bx
L_004ca2:
        dec    %dl
L_004ca4:
        jne L_004c89
